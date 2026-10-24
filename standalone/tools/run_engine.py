import argparse
from pathlib import Path
import subprocess

ROOT=Path(__file__).resolve().parents[1]

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--log',default='engine.log')
    parser.add_argument('arguments',nargs=argparse.REMAINDER)
    args=parser.parse_args()
    extra=args.arguments[1:] if args.arguments[:1]==['--'] else args.arguments
    engine=ROOT/'runtime/godot.windows.editor.x86_64.exe'
    result=subprocess.run([str(engine),'--path',str(ROOT/'game')]+extra,capture_output=True,
        timeout=180,creationflags=subprocess.CREATE_NO_WINDOW)
    output=result.stdout+result.stderr
    (ROOT/'.cache'/args.log).write_bytes(output)
    decoded=output.decode('utf-8',errors='replace')
    print('Exit:',result.returncode)
    for line in decoded.splitlines():
        if any(word in line for word in ('ERROR','SCRIPT','Parse','WARNING','FRONTLINE','Error')):
            print(line)
    raise SystemExit(result.returncode)
