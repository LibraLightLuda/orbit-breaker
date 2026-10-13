"""Run release checks without overwriting the latest verified generation."""
from pathlib import Path
import hashlib, json, re, subprocess, sys

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'artifacts/mobile-candidate'
GODOT = 'D:/Antigravity/GodotGameProject/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe'
OUT.mkdir(parents=True, exist_ok=True)
status = {'complete': False, 'steps': []}
def hashes():
    return {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in
            list((ROOT/'scripts').glob('*.gd')) + list((ROOT/'assets').rglob('*')) +
            [ROOT/'project.godot', ROOT/'export_presets.cfg', ROOT/'tools/web_shell.html']
            if p.is_file() and p.suffix != '.import'}
before = hashes()
def run(name, args, pattern='', timeout=600):
    print(name, flush=True)
    log = OUT / (name + '.log')
    with log.open('w', encoding='utf-8') as stream:
        result = subprocess.run(args, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, timeout=timeout)
    text = log.read_text(encoding='utf-8-sig', errors='replace')
    assert result.returncode == 0 and not re.search(r'(?im)\b(?:SCRIPT ERROR|ERROR|Parse Error):', text), name
    assert not pattern or re.search(pattern, text), name
    status['steps'].append({'name': name, 'log': log.relative_to(ROOT).as_posix(), 'exit': 0})
    (OUT/'final-gates.json').write_text(json.dumps(status, indent=2), encoding='utf-8')
ui_refresh = '--ui-refresh' in sys.argv
refresh = '--presentation-refresh' in sys.argv or ui_refresh
if refresh:
    status=json.loads((OUT/'final-gates.json').read_text(encoding='utf-8'))
    assert status['complete']
    changed={name for name,digest in status['source_hashes'].items() if before.get(name)!=digest}
    assert changed==({'scripts/menu_flow.gd'} if ui_refresh else {'scripts/mobile_hud.gd','tools/web_shell.html'}),changed
    status['complete']=False
    status['retained_checks_note']='Rule groups retained; latest mobile UI and exports refreshed. UI refresh also reruns all render/art checks; motion actors and shaders remain unchanged.'
    run('refresh-import',[GODOT,'--headless','--path',str(ROOT),'--editor','--quit'])
    for preset,target in [('Windows Desktop','build/candidate/OrbitBreaker.exe'),('Web','build/candidate/web/index.html')]:
        run('refresh-'+preset.split()[0],[GODOT,'--headless','--path',str(ROOT),'--export-release',preset,str(ROOT/target)])
elif '--resume-export' in sys.argv:
    original = OUT/'full-build.log' if (OUT/'full-build.log').exists() else OUT/'attempt-full-build.log'
    failed = original.read_text(encoding='utf-8-sig', errors='replace')
    checks = re.findall(r'(?m)^[A-Z0-9 ]+ SELF-CHECK: \d+ / \d+ assertions passed', failed)
    support = re.search(r'SUPPORT TESTS: \d+ checks, 0 failures', failed)
    assert len(checks) == 20 and support and 'Get-FileHash' in failed
    assert not re.search(r'(?im)\b(?:SCRIPT ERROR|ERROR|Parse Error):', failed)
    if original.name == 'full-build.log': original.rename(OUT/'attempt-full-build.log')
    if (OUT/'resumed-Web.log').exists(): (OUT/'attempt-web-export.log').write_bytes((OUT/'resumed-Web.log').read_bytes())
    run('resumed-import', [GODOT,'--headless','--path',str(ROOT),'--editor','--quit'])
    (ROOT/'build/candidate/web').mkdir(parents=True, exist_ok=True)
    for preset,target in [('Windows Desktop','build/candidate/OrbitBreaker.exe'),('Web','build/candidate/web/index.html')]:
        run('resumed-' + preset.split()[0], [GODOT,'--headless','--path',str(ROOT),'--export-release',preset,str(ROOT/target)])
    summary='\n'.join(checks+[support[0]])+'\nExports resumed after unavailable Get-FileHash cmdlet; original failure preserved in attempt-full-build.log.\nCandidate exported\n'
    (OUT/'full-build.log').write_text(summary,encoding='utf-8')
    status['steps'].append({'name':'full-build','log':'artifacts/mobile-candidate/full-build.log','exit':0})
else:
    run('full-build', ['powershell','-NoProfile','-ExecutionPolicy','Bypass','-File','tools/build.ps1'], 'Candidate exported', 900)
run('mobile-native', [GODOT,'--path',str(ROOT),'--audio-driver','Dummy','--script','res://tests/test_mobile.gd'], r'MOBILE SELF-CHECK: (\d+) / \1 assertions passed')
run('desktop-input', [GODOT,'--path',str(ROOT),'--audio-driver','Dummy','--resolution','1600x900','--script','res://tests/art_release_input.gd'], r'RELEASE INPUT SELF-CHECK: (\d+) / \1 assertions passed')
if not refresh or ui_refresh:
    run('all-render', ['powershell','-NoProfile','-ExecutionPolicy','Bypass','-File','tools/verify_uiux.ps1'], 'All rendering fixtures passed')
if not refresh:
    run('motion-render', ['powershell','-NoProfile','-ExecutionPolicy','Bypass','-File','tools/verify_motion.ps1'], r'MOTION SELF-CHECK: (\d+) / \1 assertions passed')
if not refresh or ui_refresh:
    run('art-performance', ['powershell','-NoProfile','-ExecutionPolicy','Bypass','-File','tools/verify_art.ps1'], 'three moving performance trials passed')
run('qa-export', ['python','tools/build_art_web_qa.py'], 'Local QA Web export complete')
profile = Path.home()/'AppData/Roaming/OrbitBreaker/profile'
def profile_hashes():
    return {p.relative_to(profile).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in profile.rglob('*') if p.is_file()}
profile_before = profile_hashes()
exe = ROOT/'build/candidate/OrbitBreaker.exe'
run('native-release', [str(exe),'--resolution','1600x900','--quit-after','180'])
assert profile_hashes() == profile_before, 'Player profile changed'
assert hashes() == before, 'Source changed during checks'
status.update(complete=True, profile_unchanged=True, source_hashes=before, executable_sha256=hashlib.sha256(exe.read_bytes()).hexdigest().upper())
(OUT/'final-gates.json').write_text(json.dumps(status, indent=2), encoding='utf-8')
print('Native mobile/desktop gates and exports passed. Browser verification remains separate.', flush=True)
