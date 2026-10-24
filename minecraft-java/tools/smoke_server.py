"""Verify the installed server, public status protocol, and owned-process save/stop shortcut."""
import json
import re
import socket
import subprocess
import time
from resolve import ROOT
from server_status import status


def main():
    server=ROOT/'server'
    if not re.search(r'^\s*eula\s*=\s*true\s*$',(server/'eula.txt').read_text(),re.M):
        raise RuntimeError('Accept the Minecraft EULA before running the server smoke check.')
    with socket.socket() as probe:
        probe.bind(('0.0.0.0',25565))
    lock=json.loads((ROOT/'downloads.lock.json').read_text())
    arguments=[str(ROOT/'runtime/java17/bin/java.exe'),'-Xms1G','-Xmx4G',
        '-Dfrontline.root='+str(server),
        '@libraries/net/minecraftforge/forge/1.20.1-'+lock['forge']+'/win_args.txt','nogui']
    console_log=ROOT/'.cache/production-smoke-console.log'
    with console_log.open('wb') as output:
        process=subprocess.Popen(arguments,cwd=server,stdin=subprocess.PIPE,stdout=output,
            stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
        (server/'frontline.pid').write_text(str(process.pid))
        try:
            deadline=time.monotonic()+240
            while time.monotonic()<deadline:
                if process.poll() is not None: raise RuntimeError('Installed server exited before ready')
                if 'FRONTLINE_READY' in console_log.read_text(encoding='utf-8',errors='replace'):
                    listing=status()
                    assert listing['players']['max']==8,listing['players']
                    assert '1.20.1' in listing['version']['name'],listing['version']
                    break
                time.sleep(0.5)
            else: raise RuntimeError('Installed server startup timed out')
            stopped=subprocess.run(['powershell','-NoProfile','-ExecutionPolicy','Bypass','-File',
                str(ROOT/'tools/launch.ps1'),'-Mode','Stop'],capture_output=True,text=True,timeout=45,check=True)
            assert 'save and stop' in stopped.stdout,stopped.stdout
            assert process.wait(timeout=45)==0
            log=(server/'logs/latest.log').read_text(encoding='utf-8',errors='replace')
            assert 'All dimensions are saved' in log
            report={'passed':True,'installed_forge_server':'1.20.1-'+lock['forge'],
                'server_list_protocol':'passed-over-real-tcp-25565','max_players':listing['players']['max'],
                'authenticated_players':listing['players']['online'],
                'network_login':'not-tested-no-licensed-accounts-available',
                'stop_shortcut':'owned-process-checked; all dimensions saved; exit code 0'}
            (ROOT/'.cache/production-smoke.json').write_text(json.dumps(report,indent=2)+'\n')
            print(json.dumps(report,indent=2),flush=True)
        finally:
            if process.poll() is None:
                try: process.stdin.write(b'stop\n');process.stdin.flush();process.wait(timeout=30)
                except (OSError,subprocess.TimeoutExpired): process.terminate();process.wait(timeout=15)


if __name__=='__main__': main()
