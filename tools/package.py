"""Build and verify a launcher ZIP without test tools or game content."""
import hashlib
import json
from pathlib import Path
import zipfile

mod = Path(__file__).resolve().parents[1]
manifest = json.loads((mod / 'manifest.json').read_text(encoding='utf-8'))
name = f"{manifest['id']}-{manifest['version']}"
out = mod.parent / (name + '.zip')
files = ['main.lua', 'port.lua', 'manifest.json', 'README.md', 'CHANGELOG.md', 'mod.card', 'LICENSE']
with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as archive:
    for file in files:
        archive.write(mod / file, 'GSBall/' + file)
with zipfile.ZipFile(out) as archive:
    assert archive.testzip() is None
    assert set(archive.namelist()) == {'GSBall/' + file for file in files}
    assert json.loads(archive.read('GSBall/manifest.json')) == manifest
    for file in files:
        assert archive.read('GSBall/' + file) == (mod / file).read_bytes()
digest = hashlib.sha256(out.read_bytes()).hexdigest()
checksum = mod.parent / (name + '.sha256')
checksum.write_text(f'{digest}  {out.name}\n', encoding='utf-8')
print(f'Verified {out.name}: {out.stat().st_size} bytes, {len(files)} files')
print('SHA256: ' + digest)
