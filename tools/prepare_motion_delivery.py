"""Package the checked motion candidate and curate evidence. Never promote or delete."""
from pathlib import Path
import hashlib
import json
import re
import shutil
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / 'build/candidate'
EVIDENCE = ROOT / 'artifacts/candidate'
MOTION = EVIDENCE / 'motion'
READY = ROOT / 'artifacts/motion-ready'
GENERATION = 'motion-20261013'
PREVIOUS_SHA = '15D4D4098BD767B8B8D63C5550749387DC57FC091651285BCB7BA5F37FF77939'
BASE_COMMIT = 'c8d88d9ec1ffce61cb7d6fff68569e3bc3bee3d9'


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def dump(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def log_text(path):
    text = path.read_text(encoding='utf-8-sig', errors='replace')
    require(not re.search(r'(?im)\b(?:SCRIPT ERROR|ERROR|Parse Error):', text), f'Error in {path}')
    return text


def checked(path, tag):
    match = re.search(re.escape(tag) + r' SELF-CHECK: (\d+) / (\d+) assertions passed', log_text(path))
    require(match is not None and match[1] == match[2], f'Incomplete check: {path}')
    return int(match[1])


def performance(trials, full_loop=False):
    require(len(trials) == 3, 'Three performance trials required')
    for trial in trials:
        require(trial['p95_ms'] <= 16.7 and trial['p99_ms'] <= 25, f'Performance gate: {trial}')
        require(trial.get('enemies', trial.get('min_enemies', 0)) >= 240, 'Enemy stress count')
        require(trial.get('shots', trial.get('min_shots', 0)) >= 240 and trial['gems'] == 300, 'Particle stress count')
        if full_loop:
            require(trial['elapsed_advanced'] and trial['ghost_frames'] >= 30, 'Full-loop stress did not advance')
            require(trial['samples'] >= 300, 'Insufficient stress samples')
    if full_loop:
        require(sum(t['over_33_3ms'] for t in trials) <= 1, 'Repeated long frames require review')


def main():
    require(not READY.exists(), 'motion-ready already exists; inspect the prior preparation before retrying')
    require(sha(ROOT / 'build/current/OrbitBreaker.exe') == PREVIOUS_SHA, 'Previous normal release changed')
    for name, digest in read(ROOT / 'artifacts/current/release-hashes.json').items():
        require(sha(ROOT / 'build/current' / name) == digest.upper(), f'Previous release: {name}')
    gates = read(MOTION / 'final-gates.json')
    require(gates['complete'] and gates['profile_unchanged'] and gates['steps'], 'Final execution gates incomplete')
    require(gates['executable_sha256'].upper() == sha(BUILD / 'OrbitBreaker.exe'), 'Final run used a different EXE')
    require(gates.get('source_hashes'), 'Final execution source hashes missing')
    for name, digest in gates['source_hashes'].items():
        require(sha(ROOT / name) == digest.upper(), f'Production changed after final execution: {name}')
    step_logs = []
    for step in gates['steps']:
        require(step.get('exit', step.get('exit_code')) == 0, f'Failed/unrecorded step: {step}')
        path = (ROOT / step['log']).resolve()
        require(path.is_relative_to(EVIDENCE), f'Gate log is not candidate evidence: {path}')
        log_text(path)
        step_logs.append(path)

    text = log_text(MOTION / 'build.log')
    automated = [{'name': m[1], 'passed': int(m[2]), 'total': int(m[3])} for m in re.finditer(
        r'(?m)^([A-Z0-9 ]+) SELF-CHECK: (\d+) / (\d+) assertions passed', text)]
    support = re.search(r'SUPPORT TESTS: (\d+) checks, (\d+) failures', text)
    require(support is not None and int(support[2]) == 0, 'Support tests incomplete')
    automated.append({'name': 'SUPPORT', 'passed': int(support[1]), 'total': int(support[1])})
    require(len(automated) == 20 and sum(r['passed'] for r in automated) == 2546 and
            all(r['passed'] == r['total'] for r in automated), 'Full build regression totals changed')
    render = read(EVIDENCE / 'render-results.json')
    require(len(render) == 16, 'All 16 render cases required')
    for row in render:
        text = log_text(EVIDENCE / (row['name'] + '.log'))
        match = re.search(r'SELF-CHECK: (\d+) / (\d+) assertions passed', text)
        require(match is not None and int(match[1]) == int(match[2]) == row['passed'], f'Render log: {row}')
    require(checked(EVIDENCE / 'art/art-test.log', 'ART') == 325, 'Art checks')
    require(checked(MOTION / 'final-native-input-soak.log', 'RELEASE INPUT') == 34, 'Fresh native input/soak required')
    motion = read(MOTION / 'motion-results.json')
    require(motion['failures'] == 0 and checked(MOTION / 'motion.log', 'MOTION') == motion['checks'], 'Motion checks')
    require(sum(c['frames'] for c in motion['clips']) == 576, 'Motion film coverage')
    for clip in motion['clips']:
        for index in range(clip['frames']):
            require((MOTION / f"{clip['name']}-{index:03d}.webp").is_file(), 'Missing motion frame')
    windows = read(EVIDENCE / 'art/final/moving-performance.json')
    performance(windows)
    native_reports = [json.loads(line) for line in log_text(MOTION / 'final-native-mixed.log').splitlines()
                      if line.startswith('{') and 'orbit-art-web-stress' in line]
    require(len(native_reports) == 1 and native_reports[0]['profile'] == 'mixed', 'Native mixed report missing')
    performance(native_reports[0]['results'], True)
    web = read(MOTION / 'web-final.json')
    require(isinstance(web, list) and sorted(r['profile'] for r in web) == ['mixed', 'tank'], 'Final Web profiles')
    for report in web:
        require(report['kind'] == 'orbit-art-web-stress', 'Web report kind')
        performance(report['results'], True)

    allowed = {'main.gd', 'item_catalog.gd', 'item_icon.gd', 'ui_glyph.gd', 'export_presets.cfg',
               'project.godot', 'test_viewport.gd', 'menu_flow.gd', 'test_uiux.gd', 'test_feedback_v317.gd'}
    protected = [r for r in read(ROOT / 'art_source/baseline/hashes.json') if Path(r['Path']).name not in allowed]
    require(len(protected) == 58, 'Protected baseline coverage changed')
    for row in protected:
        require(sha(Path(row['Path'])) == row['Hash'].upper(), f"Protected baseline changed: {row['Path']}")
    old_scripts = subprocess.check_output(['git', 'ls-tree', '-r', '--name-only', BASE_COMMIT, '--', 'scripts'], cwd=ROOT, text=True).splitlines()
    old_scripts = [p for p in old_scripts if p != 'scripts/main.gd']
    require(len(old_scripts) == 25, 'Existing script contract coverage changed')
    for name in old_scripts:
        before = subprocess.check_output(['git', 'show', BASE_COMMIT + ':' + name], cwd=ROOT).replace(b'\r\n', b'\n')
        require((ROOT / name).read_bytes().replace(b'\r\n', b'\n') == before, f'Gameplay contract changed: {name}')
    equality_path = EVIDENCE / 'art/web-stress/source-equality.json'
    for name, digest in read(equality_path).items():
        require(sha(ROOT / name) == digest.upper(), f'Web QA source drift: {name}')

    files = set(step_logs)
    files.update(EVIDENCE / (r['name'] + '.log') for r in render)
    files.add(EVIDENCE / 'render-results.json')
    files.add(EVIDENCE / 'art/art-test.log')
    files.update(EVIDENCE.glob('*.png'))
    for directory in EVIDENCE.iterdir():
        if directory.is_dir() and (directory.name in {'small', 'uiux', 'items', 'events', 'expedition', 'expedition-small', 'feedback315', 'feedback317'} or
                                   directory.name.startswith(('viewport-', 'feedback318-'))):
            files.update(p for p in directory.rglob('*') if p.is_file() and p.suffix in {'.png', '.json', '.log'})
    for folder in ['art/final', 'art/release-input']:
        files.update(p for p in (EVIDENCE / folder).rglob('*') if p.is_file() and p.suffix in {'.png', '.json', '.log'})
    names = ['final-gates.json', 'motion-results.json', 'motion.log', 'build.log', 'web-final.json', 'web-play-status.json', 'web-qa-console.json',
             'final-native-mixed.log', 'final-native-input-soak.log', 'protected-contracts.json', 'index.html']
    files.update(MOTION / n for n in names)
    files.update(MOTION.glob('final-*.log'))
    files.update(MOTION.glob('web-final*.png'))
    files.update(MOTION.glob('web-play*.png'))
    for clip in motion['clips']:
        files.update(MOTION.glob(clip['name'] + '-*.webp'))
        files.update(MOTION.glob(clip['name'] + '-*.png'))
    files.add(equality_path)
    # Keep comparison measurements/provenance, never the old executable QA Web payload.
    for name in ['web-previous-generation.json', 'web-baseline/source-equality.json']:
        if (MOTION / name).is_file():
            files.add(MOTION / name)
    for path in files:
        require(path.is_file() and not path.is_symlink(), f'Missing or linked evidence: {path}')
    projected = {('artifacts/current/' + p.relative_to(EVIDENCE).as_posix()) for p in files}
    rows = read(ROOT / 'art_source/worklist.json')
    require(len(rows) == 125 and all(r['status'] == 'implemented-render-verified' for r in rows), 'Asset matrix incomplete')
    for row in rows:
        for name in row['evidence']:
            require(name in projected if name.startswith('artifacts/current/') else (ROOT / name).is_file(),
                    f'Worklist evidence needs current-generation mapping: {name}')

    guide = '''ORBIT BREAKER 3.18 / MOTION 2026-10-13
Windows: OrbitBreaker.exe를 실행하세요.
이번 모션 개편은 로컬 검증본입니다. 공개 v3.18.1/Pages는 이전 art-20261012 세대입니다.
Web: 압축을 풀고 HTTP 서버에서 index.html을 여세요. file://로 직접 열면 동작하지 않습니다.
저장소에서: python -m http.server 8765 --bind 127.0.0.1 --directory build/current/web
그 다음 http://127.0.0.1:8765/index.html 에 접속하세요.
이동: 마우스 / WASD / 방향키. 돌진: 좌클릭 / Space. 오버드라이브: 우클릭 / E.
TAB: 도감. ESC: 일시정지. F11: 전체 화면. 강화: 1/2/3 또는 선택 버튼.
기존 게임 규칙·밸런스·저장·고스트 형식은 유지합니다. 랭킹은 기기/브라우저 로컬입니다.
Windows 기록: %APPDATA%/OrbitBreaker/profile/. Windows와 Web 저장소는 별개입니다.
출처: 자체 Blender/SVG/Imagegen 아트. 폰트/Godot 출처는 게임 제작 정보에서 확인하세요.
검증: RTX4070 Ti Windows 및 내장 Chromium. 저사양/다른 브라우저/사람의 미적 수용은 미확인입니다.
'''
    allowed_build_names = {'OrbitBreaker.exe', 'web', 'PLAY-KO.txt', 'SHA256.txt',
                           'OrbitBreaker-3.18-Motion-Windows.zip', 'OrbitBreaker-3.18-Motion-Web.zip'}
    require(all(p.name in allowed_build_names for p in BUILD.iterdir()), 'Unexpected candidate payload; inspect before packaging')
    (BUILD / 'PLAY-KO.txt').write_text(guide, encoding='utf-8')
    packages = {'OrbitBreaker-3.18-Motion-Windows.zip': [BUILD / 'OrbitBreaker.exe', BUILD / 'PLAY-KO.txt'],
                'OrbitBreaker-3.18-Motion-Web.zip': sorted(p for p in (BUILD / 'web').rglob('*') if p.is_file()) + [BUILD / 'PLAY-KO.txt']}
    for name, members in packages.items():
        with zipfile.ZipFile(BUILD / name, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
            for path in members:
                archive.write(path, path.relative_to(BUILD / 'web').as_posix() if path.is_relative_to(BUILD / 'web') else path.name)
        with zipfile.ZipFile(BUILD / name) as archive:
            require(archive.testzip() is None, f'ZIP integrity: {name}')
            for path in members:
                member = path.relative_to(BUILD / 'web').as_posix() if path.is_relative_to(BUILD / 'web') else path.name
                require(archive.read(member) == path.read_bytes(), f'ZIP bytes: {name}/{member}')
    hashes = {p.relative_to(BUILD).as_posix(): sha(p) for p in sorted(BUILD.rglob('*')) if p.is_file() and p.name != 'SHA256.txt'}
    (BUILD / 'SHA256.txt').write_text(''.join(f'{h}  {p}\n' for p, h in hashes.items()), encoding='utf-8')
    READY.mkdir()
    for path in sorted(files):
        target = READY / path.relative_to(EVIDENCE)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, target)
    dump(READY / 'automated-results.json', automated)
    dump(READY / 'release-hashes.json', hashes)
    production = {p.relative_to(ROOT).as_posix(): sha(p) for p in
                  list((ROOT / 'scripts').rglob('*')) + list((ROOT / 'assets').rglob('*')) +
                  [ROOT / 'project.godot', ROOT / 'export_presets.cfg', ROOT / 'icon.svg']
                  if p.is_file() and p.suffix != '.import'}
    for name, digest in gates['source_hashes'].items():
        path = (ROOT / name).resolve()
        require(path.is_relative_to(ROOT), f'Final source manifest escaped project: {name}')
        production[path.relative_to(ROOT).as_posix()] = digest.upper()
    dump(READY / 'production-source-hashes.json', production)
    verification = {'version': '3.18', 'generation': GENERATION, 'promotion': 'pending', 'local_validation_complete': True,
                    'previous_executable_sha256': PREVIOUS_SHA, 'native_release': gates,
                    'automated_groups': len(automated), 'automated_passed': sum(r['passed'] for r in automated),
                    'render_cases': len(render), 'render_passed': sum(r['passed'] for r in render), 'art_passed': 325,
                    'motion_checks': motion['checks'], 'motion_frames': 576, 'soak_passed': 34, 'soak_minutes': 10,
                    'protected_hashes': 58, 'existing_script_contracts': 25, 'base_commit': BASE_COMMIT,
                    'matrix_rows': 125, 'art_resources': 95, 'branding_resources': 2,
                    'windows_performance': windows, 'windows_mixed_performance': native_reports[0]['results'],
                    'web_performance': web, 'pck_bytes': (BUILD / 'web/index.pck').stat().st_size,
                    'validation_scope': 'Build20 groups preceded final presentation optimizations; final motion, render, art, input/soak, exports and runtime separately checked.',
                    'public_publication': 'Not performed for motion-20261013; public v3.18.1 remains art-20261012',
                    'limitations': ['Native hardware clicks, low-end hardware, Safari/Firefox and human aesthetic acceptance not checked',
                                    'Previously blocked scratch cleanup not retried; retained paths listed in retention-status.json']}
    dump(READY / 'verification.json', verification)
    dump(READY / 'evidence-hashes.json', {p.relative_to(READY).as_posix(): sha(p) for p in sorted(READY.rglob('*'))
                                      if p.is_file() and p.name != 'verification.json'})
    print(f'Prepared {GENERATION}: {len(files)} curated evidence files; current release untouched. Promotion remains separate.')


if __name__ == '__main__':
    main()
