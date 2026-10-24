"""Three real Godot processes: a dedicated server and two ENet clients, no accounts."""
import json
from pathlib import Path
import subprocess
import time

ROOT=Path(__file__).resolve().parents[1]
ENGINE=ROOT/'runtime/godot.windows.editor.x86_64.exe'


def main():
    run=ROOT/'test-runs'/time.strftime('%Y%m%d-%H%M%S')
    run.mkdir(parents=True)
    processes={}; handles=[]; sequences={}; checks=[]
    def snapshot(role):
        try:return json.loads((run/(role+'.json')).read_text(encoding='utf-8'))
        except (OSError,ValueError):return {}
    def wait_for(label,predicate,timeout=35):
        deadline=time.monotonic()+timeout
        while time.monotonic()<deadline:
            for role,process in processes.items():
                if process.poll() is not None:
                    raise RuntimeError(role+' exited; see '+str(run/(role+'.log')))
            try:
                if predicate():
                    checks.append({'name':label,'passed':True})
                    print('PASS',label,flush=True)
                    return
            except (KeyError,TypeError,IndexError):pass
            time.sleep(0.1)
        raise TimeoutError(label+'; reports: '+str(run))
    def command(role,action,**values):
        sequences[role]=sequences.get(role,0)+1
        value=dict(sequence=sequences[role],action=action,**values)
        path=run/(role+'.command.json')
        temporary=path.with_suffix('.new')
        temporary.write_text(json.dumps(value))
        temporary.replace(path)
        deadline=time.monotonic()+4
        while time.monotonic()<deadline:
            if snapshot(role).get('command_sequence')==sequences[role]:return
            time.sleep(0.03)
        raise TimeoutError(role+' did not acknowledge '+action)
    def launch(role,arguments):
        output=(run/(role+'.log')).open('wb');handles.append(output)
        args=[str(ENGINE),'--headless','--path',str(ROOT/'game'),'--max-fps','60','--']+arguments+[
            '--port','28315','--qa','--mode','READY','--name','QA-'+role,'--world',str(run/'world.sqlite'),
            '--qa-output',str(run/(role+'.json')),'--qa-command',str(run/(role+'.command.json'))]
        processes[role]=subprocess.Popen(args,stdout=output,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
    try:
        launch('server',['--server'])
        wait_for('dedicated_server_without_account',lambda:snapshot('server').get('server') is True,25)
        launch('alice',['--join','127.0.0.1'])
        launch('bob',['--join','127.0.0.1'])
        wait_for('two_real_enet_clients_connected',lambda:len(snapshot('server').get('connected_peers',[]))==2)
        wait_for('two_players_replicated_to_both_clients',lambda:all(len(snapshot(r).get('players',{}))==2 for r in ['alice','bob']))
        wait_for('terrain_streamed_and_players_grounded',lambda:all(snapshot(r).get('grounded') and snapshot(r).get('editable') for r in ['alice','bob']),50)
        command('alice','teleport',x=0,y=40.9,z=-12)
        command('alice','place',x=-2,y=41,z=-12,block=12)
        wait_for('client_block_placement_replicates_to_server_and_other_client',lambda:all(snapshot(r).get('test_block')==27 for r in ['server','alice','bob']))
        command('alice','place',x=-2,y=41,z=-12,block=0)
        wait_for('client_mining_replicates_to_server_and_other_client',lambda:all(snapshot(r).get('test_block')==0 for r in ['server','alice','bob']))
        command('server','mode',value='COOP')
        wait_for('cooperative_wave_six_armed_enemies',lambda:len(snapshot('server').get('actors',[]))==6,12)
        wait_for('enemies_replicated_to_both_clients',lambda:all(len(snapshot(r).get('actors',[]))==6 for r in ['alice','bob']))
        command('alice','teleport',x=0,y=40.9,z=0)
        wait_for('npc_fire_damages_a_real_network_player',lambda:snapshot('server').get('counters',{}).get('player_damage',0)>0,20)
        alice_id=str(snapshot('alice')['peer'])
        old_ammo=snapshot('server')['players'][alice_id]['ammo']
        actor=snapshot('alice')['actors'][0]['id']
        for _ in range(8):
            command('alice','shoot',actor=actor)
            time.sleep(0.12)
        wait_for('client_tacz_style_rifle_hits_enemy',lambda:snapshot('server').get('counters',{}).get('npc_hits',0)>0)
        wait_for('enemy_death_awards_score',lambda:snapshot('server')['players'][alice_id]['kills']>0)
        assert snapshot('server')['players'][alice_id]['ammo']<old_ammo
        command('alice','reload')
        wait_for('server_authoritative_reload_completes',lambda:snapshot('server')['players'][alice_id]['ammo']==30,8)
        command('server','mode',value='PVP')
        wait_for('pvp_clears_coop_enemies',lambda:snapshot('server').get('mode')=='PVP' and not snapshot('server').get('actors'))
        command('alice','teleport',x=-3,y=40.9,z=0)
        command('bob','teleport',x=3,y=40.9,z=0)
        time.sleep(3.3)
        bob_id=int(snapshot('bob')['peer'])
        for _ in range(7):
            command('alice','shoot_player',peer=bob_id)
            time.sleep(0.13)
        wait_for('pvp_player_kill_awards_score',lambda:snapshot('server')['players'][alice_id]['kills']>0)
        wait_for('network_player_respawns_with_loadout',lambda:snapshot('server')['players'][str(bob_id)]['hp']==100,8)
        command('alice','place',x=-2,y=41,z=-12,block=12)
        wait_for('world_change_ready_for_persistence',lambda:snapshot('server').get('test_block')==27)
        command('server','save')
        time.sleep(1)
        for role in ['alice','bob']:
            command(role,'quit')
            processes[role].wait(timeout=10)
        command('server','quit')
        processes['server'].wait(timeout=15)
        assert (run/'world.sqlite').stat().st_size>0
        checks.append({'name':'world_written_and_processes_stop_cleanly','passed':True})
        report={'passed':True,'checks':checks,'transport':'Godot ENet UDP; dedicated server + two independent client processes',
            'external_accounts':'none','internet_authentication_services':'none','test_scope':'one physical computer, loopback network',
            'run':run.name}
        (ROOT/'reports/network-integration.json').write_text(json.dumps(report,indent=2)+'\n')
        print(json.dumps(report,indent=2),flush=True)
        return 0
    finally:
        for role,process in processes.items():
            if process.poll() is None:
                try:
                    command(role,'quit');process.wait(timeout=10)
                except Exception:
                    process.terminate();process.wait(timeout=10)
        for handle in handles:handle.close()
        print('Artifacts:',run,flush=True)


if __name__=='__main__':raise SystemExit(main())
