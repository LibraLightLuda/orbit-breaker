"""Final motion release gates; keeps the verified current generation untouched."""
from pathlib import Path
import hashlib, json, re, subprocess

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'artifacts/candidate/motion'
GODOT = 'D:/Antigravity/GodotGameProject/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe'
OUT.mkdir(parents=True, exist_ok=True)
status = {'complete': False, 'steps': []}
def source_hashes():
    files = list((ROOT / 'scripts').glob('*.gd')) + list((ROOT / 'assets').rglob('*')) + [ROOT / 'project.godot', ROOT / 'export_presets.cfg', ROOT / 'main.tscn', ROOT / 'icon.svg']
    return {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in files if p.is_file() and p.suffix != '.import'}
source_before = source_hashes()

def run(name, args, pattern=None, timeout=300):
    print(name, flush=True)
    log = OUT / (name + '.log')
    with log.open('w', encoding='utf-8') as stream:
        result = subprocess.run(args, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, timeout=timeout)
    text = log.read_text(encoding='utf-8-sig', errors='replace')
    assert result.returncode == 0 and not re.search(r'(?im)\b(?:SCRIPT ERROR|ERROR|Parse Error):', text), name
    if pattern:
        assert re.search(pattern, text), name
    status['steps'].append({'name': name, 'log': log.relative_to(ROOT).as_posix(), 'passed': True, 'exit': 0})
    (OUT / 'final-gates.json').write_text(json.dumps(status, indent=2), encoding='utf-8')

run('final-import', [GODOT, '--headless', '--path', str(ROOT), '--editor', '--quit'])
for script in ['test_replay_world', 'test_feedback_v317', 'test_viewport']:
    run('final-' + script, [GODOT, '--headless', '--path', str(ROOT), '--script', f'res://tests/{script}.gd'], r'SELF-CHECK: (\d+) / \1 assertions passed')
for script in ['verify_motion', 'verify_uiux', 'verify_art']:
    run('final-' + script, ['powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', f'tools/{script}.ps1'], timeout=600)
run('final-web-qa-export', ['python', 'tools/build_art_web_qa.py'], 'Local QA Web export complete')
run('final-native-mixed', [GODOT, '--path', str(ROOT / 'art_source/web_qa_project'), '--resolution', '1600x900', '--audio-driver', 'Dummy', '--', '--mixed'], 'orbit-art-web-stress')
run('final-native-input-soak', [GODOT, '--path', str(ROOT), '--resolution', '1600x900', '--audio-driver', 'Dummy', '--script', 'res://tests/art_release_input.gd', '--', '--soak'], r'RELEASE INPUT SELF-CHECK: (\d+) / \1 assertions passed', timeout=780)
for preset, target in [('Windows Desktop', 'build/candidate/OrbitBreaker.exe'), ('Web', 'build/candidate/web/index.html')]:
    run('final-export-' + preset.split()[0], [GODOT, '--headless', '--path', str(ROOT), '--export-release', preset, str(ROOT / target)])
profile = Path.home() / 'AppData/Roaming/OrbitBreaker/profile'
def profile_hashes():
    return {p.relative_to(profile).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in profile.rglob('*') if p.is_file()}
before = profile_hashes()
exe = ROOT / 'build/candidate/OrbitBreaker.exe'
run('final-native-release', [str(exe), '--resolution', '1600x900', '--quit-after', '180'])
assert before == profile_hashes(), 'Native release changed player profile'
assert source_before == source_hashes(), 'Production source changed during final validation'
status.update(complete=True, profile_unchanged=True, source_hashes=source_before, executable_sha256=hashlib.sha256(exe.read_bytes()).hexdigest().upper())
(OUT / 'final-gates.json').write_text(json.dumps(status, indent=2), encoding='utf-8')
print('Final native motion gates and both exports passed. Browser gates remain separate.', flush=True)
