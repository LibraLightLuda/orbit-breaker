"""Verify and package the combat expansion before guarded local promotion."""
from pathlib import Path
import hashlib
import json
import math
import re
import shutil
import subprocess
import sys
import statistics
import time
import zipfile

ROOT = Path(__file__).resolve().parents[1]
QA = ROOT / 'artifacts/clarity-work'
BUILD = ROOT / 'build/candidate'
READY = ROOT / 'artifacts/clarity-ready'
GENERATION = 'clarity-20261016'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def dump(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def log(path):
    raw = path.read_bytes()
    return raw.decode('utf-16' if raw.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8-sig', errors='replace')


def profile():
    folder = Path.home() / 'AppData/Roaming/OrbitBreaker/profile'
    return {str(p.relative_to(folder)): sha(p) for p in folder.rglob('*') if p.is_file()}


def source_hashes(root=ROOT):
    sources = {}
    for base in ['scripts', 'assets', 'tests', 'tools']:
        for path in (root / base).rglob('*'):
            if path.is_file() and path.suffix not in ['.uid', '.pyc']:
                sources[path.relative_to(root).as_posix()] = sha(path)
    for name in ['project.godot', 'main.tscn', 'export_presets.cfg', 'icon.svg']:
        sources[name] = sha(root / name)
    for name in ['art_source/clarify_assets.py', 'art_source/prepare_assets.py', 'art_source/clarity-manifest.json']:
        if (root / name).is_file():
            sources[name] = sha(root / name)
    return sources


def validate_build(receipt, root=ROOT):
    sources = source_hashes(root)
    if receipt.get('complete') is not True or sources != receipt.get('source_hashes'):
        raise ValueError('Sources changed after validation began; rebuild the candidate')
    build = root / 'build/candidate'
    outputs = receipt.get('outputs', {})
    if not {'OrbitBreaker.exe', 'web/index.pck', 'web/index.html'} <= outputs.keys():
        raise ValueError('Build receipt is missing required exports')
    for name, digest in outputs.items():
        path = (build / name).resolve()
        if not path.is_relative_to(build.resolve()) or sha(path) != digest:
            raise ValueError('Export changed after validation: ' + name)
    return sources


def validate_performance(report):
    medians = []
    for name in ['baseline', 'current']:
        trials = report.get(name)
        if not isinstance(trials, list) or len(trials) < 3:
            raise ValueError('Three measured performance trials are required: ' + name)
        for trial in trials:
            if not isinstance(trial, dict):
                raise ValueError('Invalid performance trial: ' + name)
            value = trial.get('p95_ms')
            if type(value) not in [int, float] or not math.isfinite(value) or value <= 0:
                raise ValueError('Invalid p95 measurement: ' + name)
            counts = [trial.get('samples', 0), trial.get('min_enemies', trial.get('enemies', 0)), trial.get('min_shots', trial.get('shots', 0)), trial.get('gems', 0)]
            if any(type(count) not in [int, float] or not math.isfinite(count) for count in counts) or counts[0] < 300 or counts[1] < 240 or counts[2] < 240 or counts[3] != 300:
                raise ValueError('Performance fixture did not sustain the required load')
        medians.append(statistics.median(trial['p95_ms'] for trial in trials))
    if medians[1] > medians[0] * 1.10:
        raise ValueError('Measured p95 regression exceeds ten percent')
    return {**report, 'p95_change_percent': (medians[1] / medians[0] - 1) * 100, 'within_10_percent': True}


def main():
    if '--snapshot' in sys.argv:
        QA.mkdir(parents=True, exist_ok=True)
        dump(QA / 'baseline.json', {'previous_executable_sha256': sha(ROOT / 'build/current/OrbitBreaker.exe'), 'profile': profile(), 'source_hashes': source_hashes()})
        print('Previous normal executable and player profile recorded.')
        sys.exit(0)

    baseline = read(QA / 'baseline.json')
    assert profile() == baseline['profile'], 'Player profile changed during verification'
    receipt = read(BUILD / 'candidate-validation.json')
    sources = validate_build(receipt)
    assert sources == baseline['source_hashes'], 'Sources changed after the pre-test snapshot'

    if '--native' in sys.argv:
        with (QA / 'native-release.log').open('w', encoding='utf-8') as output:
            process = subprocess.Popen([str(BUILD / 'OrbitBreaker.exe'), '--audio-driver', 'Dummy', '--resolution', '960x540'], cwd=BUILD, stdout=output, stderr=subprocess.STDOUT)
            time.sleep(4)
            code = '$p=Get-Process -Id ' + str(process.pid) + '; if (-not $p.MainWindowHandle) { exit 1 }; $p.MainWindowTitle; if (-not $p.CloseMainWindow()) { exit 2 }'
            close = subprocess.run(['powershell', '-NoProfile', '-Command', code], capture_output=True, timeout=15)
            assert close.returncode == 0, close.stderr.decode(errors='replace')
            exit_code = process.wait(timeout=20)
        text = log(QA / 'native-release.log')
        assert exit_code == 0 and not re.search(r'(?im)\b(?:SCRIPT ERROR|ERROR|Parse Error):', text), text
        assert profile() == baseline['profile']
        validate_build(receipt)
        dump(QA / 'native-release.json', {'exit': exit_code, 'window_created': True, 'profile_unchanged': True, 'executable_sha256': sha(BUILD / 'OrbitBreaker.exe'), 'build_receipt_sha256': sha(BUILD / 'candidate-validation.json'), 'scope': 'actual exported executable startup and normal OS close'})
        print('Final Windows executable launched and closed normally; player profile unchanged.')
        sys.exit(0)

    assert sha(ROOT / 'build/current/OrbitBreaker.exe') == baseline['previous_executable_sha256'], 'Previous normal release changed'
    text = log(QA / 'full-build.log')
    assert 'Candidate exported.' in text and not re.search(r'(?im)\b(?:SCRIPT ERROR|ERROR|Parse Error):', text), 'Build gate incomplete'
    groups = list({name.strip(): {'name': name.strip(), 'passed': int(passed)} for name, passed, total in re.findall(r'([A-Z0-9 ]+) SELF-CHECK: (\d+) / (\d+) assertions passed', text) if passed == total}.values())
    assert len(groups) >= 24 and any(g['name'] == 'COMBAT' for g in groups), groups
    render_text = log(QA / 'combat-render.log')
    match = re.search(r'COMBAT UI SELF-CHECK: (\d+) / (\d+) assertions passed', render_text)
    assert match and match[1] == match[2] and not re.search(r'(?im)\b(?:SCRIPT ERROR|ERROR|Parse Error):', render_text)
    native = read(QA / 'native-release.json')
    assert native['executable_sha256'] == sha(BUILD / 'OrbitBreaker.exe') and native['exit'] == 0
    assert native['build_receipt_sha256'] == sha(BUILD / 'candidate-validation.json'), 'Native check used a different build receipt'
    browser = read(QA / 'browser-status.json')
    assert browser['passed'] and browser['errors'] == 0
    dump(QA / 'performance.json', validate_performance(read(QA / 'performance.json')))
    assert not READY.exists(), 'Inspect existing staging before replacing it'

    (BUILD / 'PLAY-KO.txt').write_text('ORBIT BREAKER 3.19 — 전투 확장\n\nOrbitBreaker.exe 실행. 이동: 마우스/WASD. 돌진: 좌클릭/Space. 오버드라이브: 우클릭/E. ESC 정지, TAB 도감.\n전용 진화 이후 2개 전술 중 선택. 보스 공격 3회 뒤 코어 노출. 08:50 최종 작전 선택, 10:00 붕괴 종료.\n모바일: 드래그 이동, 길게 드래그 후 놓아 돌진, 두 번 탭 오버드라이브 및 하단 버튼.\n저장: %APPDATA%/OrbitBreaker/profile/. 기존 기록과 고스트 보존.\nWeb은 web/index.html을 로컬 HTTP 서버에서 열어 실행. 공개 사이트는 이번 로컬 세대와 다를 수 있습니다.\n', encoding='utf-8')
    for name, files in [('OrbitBreaker-Windows.zip', [BUILD / 'OrbitBreaker.exe', BUILD / 'PLAY-KO.txt']), ('OrbitBreaker-Web.zip', sorted((BUILD / 'web').glob('*')) + [BUILD / 'PLAY-KO.txt'])]:
        with zipfile.ZipFile(BUILD / name, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
            for path in files:
                if path.is_file():
                    archive.write(path, path.relative_to(BUILD).as_posix())
        with zipfile.ZipFile(BUILD / name) as archive:
            assert archive.testzip() is None
            for path in files:
                if path.is_file(): assert hashlib.sha256(archive.read(path.relative_to(BUILD).as_posix())).hexdigest().upper() == sha(path)
    hashes = {p.relative_to(BUILD).as_posix(): sha(p) for p in BUILD.rglob('*') if p.is_file() and p.name != 'SHA256.txt'}
    (BUILD / 'SHA256.txt').write_text('\n'.join(f'{digest}  {name}' for name, digest in sorted(hashes.items())) + '\n', encoding='utf-8')
    hashes['SHA256.txt'] = sha(BUILD / 'SHA256.txt')
    READY.mkdir()
    for name in ['full-build.log', 'combat.log', 'combat-render.log', 'native-release.log', 'native-release.json', 'browser-status.json', 'baseline.json', 'performance.json', 'replay-performance.json']:
        path = QA / name
        if path.is_file(): shutil.copy2(path, READY / name)
    shutil.copytree(QA / 'screens', READY / 'screens')
    sources = validate_build(receipt)
    shutil.copy2(BUILD / 'candidate-validation.json', READY / 'candidate-validation.json')
    dump(READY / 'production-source-hashes.json', sources)
    dump(READY / 'previous-retention.json', read(ROOT / 'artifacts/current/retention-status.json'))
    dump(READY / 'release-hashes.json', hashes)
    dump(READY / 'automated-results.json', groups)
    dump(READY / 'verification.json', {'version': '3.19', 'generation': GENERATION, 'promotion': 'pending', 'local_validation_complete': True, 'previous_executable_sha256': baseline['previous_executable_sha256'], 'groups': groups, 'combat_render_checks': int(match[1]), 'native_release': native, 'browser': browser, 'profile_unchanged': True, 'limits': ['No physical phone/Safari/low-end certification', 'No long human balance acceptance', 'No public publication in this generation']})
    dump(READY / 'evidence-hashes.json', {p.relative_to(READY).as_posix(): sha(p) for p in READY.rglob('*') if p.is_file() and p.name not in ['verification.json', 'evidence-hashes.json']})
    assert profile() == baseline['profile']
    print(json.dumps({'generation': GENERATION, 'groups': len(groups), 'checks': sum(g['passed'] for g in groups), 'render': int(match[1]), 'exe_sha256': hashes['OrbitBreaker.exe'], 'pck_sha256': hashes['web/index.pck']}, ensure_ascii=False))


if __name__ == '__main__':
    main()
