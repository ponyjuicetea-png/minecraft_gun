"""Run native TaCZ/NPC integration checks in a disposable, loopback-only server."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
from resolve import ROOT
from server_status import status


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--reuse-world',type=Path,help='Copy a prior stopped QA run world and gun pack, preserving its artifacts.')
    options=parser.parse_args()
    accepted=ROOT/'server/eula.txt'
    if not accepted.exists() or not re.search(r'^\s*eula\s*=\s*true\s*$',accepted.read_text(),re.M):
        raise RuntimeError('Minecraft EULA has not been accepted. This test does not accept terms automatically.')
    lock=json.loads((ROOT/'downloads.lock.json').read_text())
    run=ROOT/'test-runs'/time.strftime('%Y%m%d-%H%M%S')
    run.mkdir(parents=True)
    shutil.copytree(ROOT/'server/libraries',run/'libraries',copy_function=os.link)
    shutil.copytree(ROOT/'server/mods',run/'mods')
    shutil.copytree(ROOT/'server/config',run/'config')
    shutil.copyfile(accepted,run/'eula.txt')
    if options.reuse_world:
        previous=options.reuse_world.resolve()
        if not previous.is_relative_to((ROOT/'test-runs').resolve()):
            raise RuntimeError('Reuse source must be a previous run in this project test-runs directory.')
        for name in ('qa-world','tacz'):
            if (previous/name).exists(): shutil.copytree(previous/name,run/name)
    properties=(ROOT/'server/server.properties').read_text()+'\nserver-ip=127.0.0.1\nserver-port=25566\nlevel-name=qa-world\nview-distance=4\nsimulation-distance=4\n'
    (run/'server.properties').write_text(properties,encoding='utf-8')
    arguments=[str(ROOT/'runtime/java17/bin/java.exe'),'-Xms1G','-Xmx4G','-Dfrontline.qa=true',
        '@libraries/net/minecraftforge/forge/1.20.1-'+lock['forge']+'/win_args.txt','nogui']
    with (run/'console.log').open('wb') as output:
        process=subprocess.Popen(arguments,cwd=run,stdout=output,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
        try:
            deadline=time.monotonic()+240
            status_verified=False
            while time.monotonic()<deadline:
                if not status_verified:
                    try:
                        listing=status(port=25566)
                        (run/'server-status.json').write_text(json.dumps(listing,indent=2),encoding='utf-8')
                        status_verified=True
                    except (OSError,ValueError,ConnectionError): pass
                report=run/'qa-results.json'
                if report.exists():
                    result=json.loads(report.read_text())
                    print(json.dumps(result,indent=2,ensure_ascii=False),flush=True)
                    (ROOT/'test-runs/latest.txt').write_text(str(run))
                    process.wait(timeout=30)
                    return 0 if result['passed'] else 1
                if process.poll() is not None: raise RuntimeError('Native server exited before results; see '+str(run/'console.log'))
                time.sleep(0.3)
            raise RuntimeError('Native server test timed out; see '+str(run/'console.log'))
        finally:
            if process.poll() is None:
                (run/'frontline-stop-request').write_text('stop')
                try: process.wait(timeout=15)
                except subprocess.TimeoutExpired: process.terminate();process.wait(timeout=15)
            print('Test artifacts:',run,flush=True)


if __name__=='__main__':sys.exit(main())
