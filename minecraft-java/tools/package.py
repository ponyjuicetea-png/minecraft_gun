"""Package only authored code/configuration and verified upstream download references."""
import hashlib
import json
from pathlib import Path
import shutil
import struct
import zipfile

ROOT = Path(__file__).resolve().parents[1]
JAR = 'frontline-operations-1.20.1-1.0.0.jar'


def nbt_string(value):
    encoded = value.encode('utf-8')
    return struct.pack('>H', len(encoded)) + encoded


def server_list():
    # Vanilla servers.dat is an uncompressed NBT compound, not a gzip stream.
    entry = (b'\x08' + nbt_string('name') + nbt_string('Frontline - Local host')
             + b'\x08' + nbt_string('ip') + nbt_string('127.0.0.1:25565') + b'\x00')
    return b'\x0a\x00\x00\x09' + nbt_string('servers') + b'\x0a' + struct.pack('>i', 1) + entry + b'\x00'


def main():
    lock = json.loads((ROOT/'downloads.lock.json').read_text(encoding='utf-8'))
    addon = ROOT/'addon'/JAR
    addon.parent.mkdir(exist_ok=True)
    shutil.copyfile(ROOT/'build/libs'/JAR, addon)
    templates = ROOT/'templates'
    (templates/'client/config').mkdir(parents=True, exist_ok=True)
    (templates/'client/shaderpacks').mkdir(parents=True, exist_ok=True)
    shutil.copyfile(ROOT/'server/server.properties', templates/'server.properties')
    # Acceptance and account/profile data must never propagate to another user.
    (templates/'eula.txt').write_text('# Review https://www.minecraft.net/eula before accepting.\neula=false\n', encoding='utf-8')
    shutil.copyfile(ROOT/'server/config/tacz_npc-common.toml', templates/'tacz_npc-common.toml')
    for relative in ('options.txt', 'config/oculus.properties', 'config/tacz_npc-common.toml'):
        shutil.copyfile(ROOT/'client'/relative, templates/'client'/relative)
    shader = next(mod for mod in lock['mods'] if mod['side'] == 'shader')
    settings = shader['filename'] + '.txt'
    shutil.copyfile(ROOT/'client/shaderpacks'/settings, templates/'client/shaderpacks'/settings)
    (templates/'client/servers.dat').write_bytes(server_list())
    if not (ROOT/'client/servers.dat').exists():
        shutil.copyfile(templates/'client/servers.dat', ROOT/'client/servers.dat')

    files = [path for path in ROOT.iterdir() if path.is_file()
             and path.name != 'PACKAGE-SHA256.json'
             and (path.suffix in ('.cmd', '.gradle', '.properties', '.md', '.json')
                  or path.name in ('gradlew', 'gradlew.bat', 'LICENSE', '.gitignore'))]
    for directory in ('addon', 'src', 'gradle', 'templates', 'tools', 'licenses', 'reports'):
        files += [path for path in (ROOT/directory).rglob('*')
                  if path.is_file() and '__pycache__' not in path.parts and path.suffix != '.pyc']
    files = sorted(set(files))
    manifest = {path.relative_to(ROOT).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
                for path in files}
    (ROOT/'PACKAGE-SHA256.json').write_text(json.dumps(manifest, indent=2)+'\n', encoding='utf-8')
    files = [path for path in files if path.name != 'PACKAGE-SHA256.json'] + [ROOT/'PACKAGE-SHA256.json']
    output = ROOT/'dist/Frontline-Minecraft-Java-Installer.zip'
    output.parent.mkdir(exist_ok=True)
    with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in files:
            archive.write(path, 'Frontline-Minecraft-Java/'+path.relative_to(ROOT).as_posix())
    with zipfile.ZipFile(output) as archive:
        assert archive.testzip() is None
        assert b'eula=false' in archive.read('Frontline-Minecraft-Java/templates/eula.txt')
        assert not any(part in name.split('/') for name in archive.namelist()
                       for part in ('runtime', '.cache', 'server', 'client', 'test-runs')
                       if not name.startswith('Frontline-Minecraft-Java/templates/'))
    digest = hashlib.sha256(output.read_bytes()).hexdigest()
    output.with_suffix('.zip.sha256').write_text(digest+'  '+output.name+'\n', encoding='ascii')
    print(json.dumps({'archive': str(output), 'bytes': output.stat().st_size,
                      'files': len(files), 'sha256': digest}, indent=2))


if __name__ == '__main__':
    main()
