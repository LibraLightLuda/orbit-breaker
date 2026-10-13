"""Validate current feedback evidence, then package for the existing guarded promotion."""
from pathlib import Path
import hashlib
import json
import re
import shutil
import zipfile

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / 'build/candidate'
QA = ROOT / 'artifacts/feedback-candidate'
READY = ROOT / 'artifacts/feedback-ready'
GENERATION = 'feedback-20261013'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()

def dump(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))

def checked_log(path):
    value = path.read_text(encoding='utf-8-sig', errors='replace')
    assert not re.search(r'(?im)\b(?:SCRIPT ERROR|ERROR|Parse Error):', value), path
    return value

def passed(path, tag):
    value = checked_log(path)
    match = re.search(re.escape(tag) + r' SELF-CHECK: (\d+) / (\d+) assertions passed', value)
    assert match and match[1] == match[2], path
    return int(match[1])

assert not READY.exists(), 'Inspect existing staging before retrying'
build_log = checked_log(QA / 'full-build.log')
assert 'Candidate exported.' in build_log
groups = [{'name': m[1], 'passed': int(m[2])} for m in re.finditer(r'(?m)^([A-Z0-9 ]+) SELF-CHECK: (\d+) / \2 assertions passed', build_log)]
support = re.search(r'SUPPORT TESTS: (\d+) checks, 0 failures', build_log)
assert support and len(groups) == 21, groups
groups.append({'name': 'SUPPORT', 'passed': int(support[1])})
feedback = passed(QA / 'feedback-native.log', 'MOBILEFEEDBACK')
notes = QA / 'release-notes.md'
notes.write_text(notes.read_text(encoding='utf-8').replace('2024개', f'{feedback}개'), encoding='utf-8')
mobile = passed(QA / 'mobile-native.log', 'MOBILE')
art = passed(QA / 'art.log', 'ART')
checked_log(QA / 'render.log')
render = read(ROOT / 'artifacts/candidate/render-results.json')
assert len(render) == 16
native = read(QA / 'native-release.json')
assert native['exit'] == 0 and native['profile_unchanged']
assert sha(BUILD / 'OrbitBreaker.exe') == native['executable_sha256']
for path, digest in native['source_hashes'].items():
    assert sha(ROOT / path) == digest, path
browser = read(QA / 'browser-status.json')
assert browser['complete'] and not browser['errors']
previous = sha(ROOT / 'build/current/OrbitBreaker.exe')
guide = '''ORBIT BREAKER 3.18.3 / MOBILE FEEDBACK
공개 플레이: https://libralightluda.github.io/orbit-breaker/
Windows: OrbitBreaker.exe 실행. Web: HTTP 서버에서 index.html 실행.
모바일: 드래그 이동. 0.3초 이상, 48 화면 픽셀 이상 끌었다 놓은 방향으로 돌진.
단일 탭은 스킬을 소비하지 않습니다. 0.24초 내 가까운 위치 두 번 탭: 오버드라이브.
짧은 드래그는 이동만 하며 화면 스킬 버튼도 계속 사용할 수 있습니다.
가로/세로 모두 메인·출격 준비·강화 선택을 스크롤 없이 볼 수 있습니다.
화면 밖 파츠/아이템은 가장자리 화살표·아이콘·거리·남은 시간으로 안내합니다.
데스크톱: 마우스/WASD 이동, 좌클릭/Space 돌진, 우클릭/E 오버드라이브.
게임 규칙·밸런스·저장·고스트 호환 유지. 물리 휴대폰/Safari/저사양 성능은 미검증.
'''
(BUILD / 'PLAY-KO.txt').write_text(guide, encoding='utf-8')
for platform in ['Windows', 'Web']:
    members = [BUILD / 'OrbitBreaker.exe'] if platform == 'Windows' else sorted((BUILD / 'web').rglob('*'))
    members.append(BUILD / 'PLAY-KO.txt')
    with zipfile.ZipFile(BUILD / f'OrbitBreaker-3.18.3-{platform}.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
        for path in members:
            if path.is_file():
                archive.write(path, path.relative_to(BUILD / 'web') if path.is_relative_to(BUILD / 'web') else path.name)
    with zipfile.ZipFile(BUILD / f'OrbitBreaker-3.18.3-{platform}.zip') as archive:
        assert archive.testzip() is None
hashes = {p.relative_to(BUILD).as_posix(): sha(p) for p in sorted(BUILD.rglob('*')) if p.is_file() and p.name != 'SHA256.txt'}
(BUILD / 'SHA256.txt').write_text(''.join(f'{digest}  {name}\n' for name, digest in hashes.items()), encoding='utf-8')
shutil.copytree(QA, READY / 'feedback')
# Curate only this run's fresh render evidence from the existing render runner.
for path in ROOT.joinpath('artifacts/candidate').iterdir():
    if path.name in ['uiux', 'small', 'items', 'events', 'expedition', 'expedition-small', 'feedback315', 'feedback317'] or path.name.startswith(('viewport-', 'feedback318-')):
        if path.is_dir(): shutil.copytree(path, READY / path.name)
    if path.name in [case['name'] + '.log' for case in render] + ['render-results.json']:
        shutil.copy2(path, READY / path.name)
production = {p.relative_to(ROOT).as_posix(): sha(p) for folder in ['scripts', 'assets'] for p in ROOT.joinpath(folder).rglob('*') if p.is_file() and p.suffix not in ['.import', '.uid']}
production.update({name: sha(ROOT / name) for name in ['project.godot', 'main.tscn', 'export_presets.cfg', 'tools/web_shell.html']})
dump(READY / 'release-hashes.json', hashes)
dump(READY / 'production-source-hashes.json', production)
verification = {'version': '3.18.3', 'generation': GENERATION, 'local_validation_complete': True, 'promotion': 'pending',
    'previous_executable_sha256': previous, 'native_release': native, 'automated_groups': len(groups), 'automated_passed': sum(g['passed'] for g in groups),
    'feedback_native_checks': feedback, 'mobile_native_checks': mobile, 'art_checks': art, 'render_cases': len(render), 'render_passed': sum(r['passed'] for r in render),
    'browser': browser, 'public_publication': 'pending', 'physical_mobile_device': False,
    'limitations': ['Physical phone, Safari, low-end hardware, long human play not checked', 'Previously blocked scratch paths not retried'],
    'source_and_player_data': 'preserved'}
dump(READY / 'automated-results.json', groups)
dump(READY / 'verification.json', verification)
dump(READY / 'evidence-hashes.json', {p.relative_to(READY).as_posix(): sha(p) for p in sorted(READY.rglob('*')) if p.is_file() and p.name not in ['evidence-hashes.json', 'verification.json']})
print(json.dumps({k: verification[k] for k in ['automated_groups', 'automated_passed', 'feedback_native_checks', 'mobile_native_checks', 'art_checks', 'render_passed']}))
