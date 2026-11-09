"""Launch both projects concurrently and prove source/data isolation (Python stdlib)."""
from pathlib import Path
import hashlib, json, os, shutil, subprocess, tempfile

root = Path(__file__).resolve().parents[2]
original = root / 'visual-attention-reaction'
abstract = Path(__file__).resolve().parents[1]

def hashes(folder):
    return {str(p.relative_to(folder)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in folder.rglob('*') if p.is_file()}

before = hashes(original)
data_root = Path(os.environ.get('XDG_DATA_HOME', Path.home() / '.local/share'))
original_data = data_root / 'godot/app_userdata/Visual Attention & Reaction'
saved_before = hashes(original_data)
config = abstract.joinpath('project.godot').read_text()
assert 'config/name="Abstract Visual Attention & Reaction"' in config
assert 'config/custom_user_dir_name="abstract-visual-attention-reaction"' in config
assert 'config/use_custom_user_dir=true' in config
for path in abstract.glob('*.gd'):
    source = path.read_text()
    assert '../visual-attention-reaction' not in source
    assert 'app_userdata/Visual Attention & Reaction' not in source
assert not any(p.is_symlink() for p in abstract.rglob('*'))
engine = shutil.which('godot')
assert engine and subprocess.check_output([engine, '--version'], text=True).startswith('4.7.2.')
folders = [abstract]
if original.joinpath('project.godot').is_file():
    folders.insert(0, original)
else:
    print('SKIP: optional sibling comparison (visual-attention-reaction is not installed).')
with tempfile.TemporaryDirectory(prefix='abstract-independent-') as temp:
    # Isolate runtime log files; neither launch starts or saves a session.
    jobs = [subprocess.Popen([engine, '--headless', '--path', str(folder),
              '--log-file', str(Path(temp) / (folder.name + '.log')), '--quit-after', '120'],
              stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
            for folder in folders]
    assert all(job.poll() is None for job in jobs), 'Both processes run simultaneously'
    for job in jobs:
        output, _ = job.communicate(timeout=30)
        assert job.returncode == 0 and 'ERROR' not in output, output
assert hashes(original) == before, 'Original source/cache unchanged'
assert hashes(original_data) == saved_before, 'Original saved data unchanged'
print('PASS: Godot 4.7.2, independent launch/storage, no shared files; any installed sibling project and saved data unchanged.')
