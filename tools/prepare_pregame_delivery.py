"""Package the verified pregame UI generation for guarded local promotion."""
from pathlib import Path
import hashlib
import json
import re
import shutil
import subprocess
import sys
import time
import zipfile

ROOT = Path(__file__).resolve().parents[1]
QA = ROOT / 'artifacts/pregame-candidate'
READY = ROOT / 'artifacts/pregame-ready'
BUILD = ROOT / 'build/candidate'
GENERATION = 'pregame-20261014'


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def dump(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def profile():
    directory = Path.home() / 'AppData/Roaming/OrbitBreaker/profile'
    return {p.relative_to(directory).as_posix(): sha(p) for p in directory.rglob('*') if p.is_file()}


if '--snapshot' in sys.argv:
    sources = read(ROOT / 'artifacts/current/production-source-hashes.json')
    for name in ['project.godot', 'export_presets.cfg', 'tools/web_shell.html']:
        sources[name] = ''
    dump(QA / 'baseline.json', {
        'previous_executable_sha256': sha(ROOT / 'build/current/OrbitBreaker.exe'),
        'source_hashes': {name: sha(ROOT / name) for name in sources},
        'profile': profile(),
    })
    print('Known-good release, production sources and player profile recorded.')
    sys.exit(0)

if '--native-check' in sys.argv:
    before = profile()
    executable = BUILD / 'OrbitBreaker.exe'
    with (QA / 'native-release.log').open('w', encoding='utf-8') as output:
        process = subprocess.Popen([str(executable), '--audio-driver', 'Dummy', '--resolution', '960x540'], cwd=BUILD, stdout=output, stderr=subprocess.STDOUT)
        time.sleep(5)
        close = subprocess.run(['powershell', '-NoProfile', '-Command', f'$p=Get-Process -Id {process.pid}; if (-not $p.MainWindowHandle) {{ exit 1 }}; $p.MainWindowTitle; if (-not $p.CloseMainWindow()) {{ exit 2 }}'], capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=10)
        assert close.returncode == 0, close.stderr
        exit_code = process.wait(timeout=20)
    log = (QA / 'native-release.log').read_text(encoding='utf-8', errors='replace')
    assert exit_code == 0 and not re.search(r'(?im)\b(?:SCRIPT ERROR|ERROR|Parse Error):', log), log
    assert profile() == before
    dump(QA / 'native-release.json', {'exit': exit_code, 'executable_sha256': sha(executable), 'profile_unchanged': True, 'window_created': True, 'scope': 'exported executable startup and normal OS close; detailed UI acceptance covered separately'})
    print('Exported Windows executable startup and profile preservation passed.')
    sys.exit(0)

if '--finalize-docs' in sys.argv:
    current = ROOT / 'artifacts/current'
    verified = read(current / 'verification.json')
    assert verified['generation'] == GENERATION and verified['promotion'] == 'local-current'
    retention = read(current / 'retention-status.json')
    assert retention['single_verified_release_generation']
    executable_hash = sha(ROOT / 'build/current/OrbitBreaker.exe')
    pck_hash = sha(ROOT / 'build/current/web/index.pck')
    passed = verified['pregame']['checks']
    result = f'''# 최신 로컬 검증 결과: 3.18.3 / {GENERATION} (2026-10-14)

[시작 전 모바일 UI 검수 보고](PREGAME_MOBILE_REPORT.md). 메인·출격 준비·기록·도감·도움말·설정·라이선스의 가로/세로 흐름을 개선했다. 고정 탭·복귀·출격과 페이지 이동으로 세로 스크롤 없이 선택한다. 카드 밖으로 분리되던 긴 조건을 같은 카드에 묶고, 이름 입력 포커스와 선택을 회전 후 복원한다. 진행 중 UI는 이번 검수에서 제외했다.

기존 회귀 3,100개와 시작 전 실제 렌더 {passed:,}개를 통과했다. 8개 콘텐츠 크기, 기본 화면 상태 120개와 전체 페이지, 기록 8개·랭킹 10개, 실제 Viewport 터치·hit test·화면 경계·고정 메뉴 겹침·회전 상태를 검사했다. Windows 내보낸 EXE 창 생성·정상 종료/exit 0·오류 없음, 실제 프로필 해시 불변을 확인했다. Chromium Web의 최종 검수 범위는 `browser-status.json`을 따른다.

최신 로컬본은 `build/current`, 대응 증거는 `artifacts/current`, 게시용 복사본은 `web/`다. Windows SHA-256 `{executable_hash}`, Web PCK `{pck_hash}`. 기존 정상본 보존 → 후보 검사·내보내기·실행·해시 → 교체 → 이전 세대 정리 순서를 지켰다. 과거 정책 차단 임시 자료는 재시도하지 않았으며 `retention-status.json`에 남긴다. 공개 사이트/릴리즈/push는 수행하지 않았다.

실물 휴대폰·Safari/iOS·소프트 키보드/IME 실기기·노치/주소창의 기기별 동작은 미검증이다. 아래 결과는 과거 세대 기록이다.

---

'''
    validation = ROOT / 'docs/VALIDATION_V3.md'
    old = validation.read_text(encoding='utf-8-sig')
    assert GENERATION not in old
    validation.write_text(result + old, encoding='utf-8')
    authority = ROOT / 'docs/SURVIVAL_V3.md'
    old = authority.read_text(encoding='utf-8-sig')
    position = old.index('\n## ')
    rule = '\n## 시작 전 모바일 UI 흐름 (2026-10-14)\n\n메인부터 출격 직전의 기록·도감·도움말·설정·라이선스는 가로/세로에서 선택·복귀·출격을 세로 스크롤 없이 조작한다. 공간이 부족한 정보는 고정 탭·복귀 버튼과 이전/다음 페이지로 나누며, 낮은 가로 아이템 목록은 눌러 등급별 상세를 연다. 회전 시 이름 입력 포커스·커서와 기체/전장/난이도 선택을 보존한다. 전투 중 UI·규칙·밸런스·저장·고스트는 이번 변경 범위에서 제외한다. 검증은 PREGAME_MOBILE_REPORT.md와 VALIDATION_V3.md를 따른다.\n'
    authority.write_text(old[:position] + rule + old[position:], encoding='utf-8')
    policy = ROOT / 'docs/ARTIFACT_RETENTION.md'
    old = policy.read_text(encoding='utf-8-sig').replace('## 현재 최신 로컬본 (2026-10-14)', '## 이전 로컬본: audio-20261014 (2026-10-14)', 1)
    position = old.index('\n## ')
    policy.write_text(old[:position] + f'\n## 현재 최신 로컬본: {GENERATION} (2026-10-14)\n\n3.18.3 시작 전 UI 세대. `build/current`·`artifacts/current`·`web/`가 대응한다. Windows SHA-256 `{executable_hash}`. 후보 검증 후 guarded promotion으로 교체했다. 이전 배포본·증거는 정리하고 기존 정책 차단 자료는 최종 retention-status/file-inventory에 기록한다. 공개 게시하지 않았다.\n' + old[position:], encoding='utf-8')
    report = ROOT / 'docs/PREGAME_MOBILE_REPORT.md'
    report.write_text(report.read_text(encoding='utf-8') + f'\n## 최종 결과\n\n로컬 최신 세대 `{GENERATION}`. 기존 회귀 3,100개, 시작 전 렌더 {passed:,}개 통과. Windows 정상 창 생성/종료, Web 최종 확인과 프로필 불변 성공. 공개 미게시. 상세 수치와 보관 상태는 최신 검증 명세를 따른다.\n', encoding='utf-8')
    print('Current-generation rules, validation and retention documentation updated.')
    sys.exit(0)

baseline = read(QA / 'baseline.json')
assert sha(ROOT / 'build/current/OrbitBreaker.exe') == baseline['previous_executable_sha256']
assert profile() == baseline['profile'], 'Player profile changed'
previous_sources = read(ROOT / 'artifacts/current/production-source-hashes.json')
changed_sources = [name for name, digest in previous_sources.items() if sha(ROOT / name) != digest.upper()]
assert set(changed_sources) <= {'scripts/main.gd', 'scripts/menu_flow.gd', 'export_presets.cfg'}, changed_sources
for name, digest in baseline['source_hashes'].items():
    assert sha(ROOT / name) == digest, name
log = (QA / 'full-build.log').read_text(encoding='utf-8-sig', errors='replace')
assert 'Candidate exported.' in log
assert not re.search(r'(?im)\b(?:SCRIPT ERROR|ERROR|Parse Error):', log)
groups = [{'name': m[1], 'passed': int(m[2])} for m in re.finditer(r'(?m)^([A-Z0-9 ]+) SELF-CHECK: (\d+) / \2 assertions passed', log)]
support = re.search(r'SUPPORT TESTS: (\d+) checks, 0 failures', log)
assert support and len(groups) == 23
groups.append({'name': 'SUPPORT', 'passed': int(support[1])})
assert read(QA / 'results.json')['failures'] == 0
browser = read(QA / 'browser-status.json')
assert browser['complete'] and not browser['errors']
native = read(QA / 'native-release.json')
assert native['exit'] == 0 and native['executable_sha256'] == sha(BUILD / 'OrbitBreaker.exe')
assert not READY.exists(), 'Inspect existing promotion staging first'
(BUILD / 'PLAY-KO.txt').write_text('''ORBIT BREAKER 3.18.3 / PREGAME UI / 2026-10-14
Windows: OrbitBreaker.exe 실행. Web: HTTP 서버에서 index.html 실행.
모바일 시작 전 메뉴: 가로/세로 대응, 스크롤 대신 이전/다음 페이지.
복귀·도감 탭·출격 선택은 화면 안의 터치 버튼으로 조작합니다.
설정 음량 슬라이더와 이름 입력, 현재 선택은 화면 회전 시 유지됩니다.
게임 규칙·저장·고스트·전투 UI 유지. 기존 오디오 작업 포함.
공개 사이트에는 이번 로컬 UI 세대를 게시하지 않았습니다.
실물 휴대폰·Safari/iOS·소프트 키보드 실기기 동작은 미검증입니다.
''', encoding='utf-8')
for platform in ['Windows', 'Web']:
    members = [BUILD / 'OrbitBreaker.exe'] if platform == 'Windows' else list((BUILD / 'web').glob('*'))
    members.append(BUILD / 'PLAY-KO.txt')
    archive_path = BUILD / f'OrbitBreaker-3.18.3-Pregame-{platform}.zip'
    with zipfile.ZipFile(archive_path, 'w', zipfile.ZIP_DEFLATED) as archive:
        for p in members:
            if p.is_file(): archive.write(p, p.name)
    with zipfile.ZipFile(archive_path) as archive:
        assert archive.testzip() is None
hashes = {p.relative_to(BUILD).as_posix(): sha(p) for p in BUILD.rglob('*') if p.is_file() and p.name != 'SHA256.txt'}
(BUILD / 'SHA256.txt').write_text(''.join(f'{digest}  {name}\n' for name, digest in hashes.items()), encoding='utf-8')
shutil.copytree(QA, READY)
dump(READY / 'core-preservation.json', {'changed_production_files': changed_sources, 'other_production_files_unchanged': True, 'profile_unchanged': True})
dump(READY / 'previous-retention.json', read(ROOT / 'artifacts/current/retention-status.json'))
dump(READY / 'release-hashes.json', hashes)
dump(READY / 'production-source-hashes.json', baseline['source_hashes'])
dump(READY / 'automated-results.json', groups)
dump(READY / 'verification.json', {
    'version': '3.18.3', 'generation': GENERATION, 'promotion': 'pending',
    'local_validation_complete': True, 'previous_executable_sha256': baseline['previous_executable_sha256'],
    'native_release': native, 'automated_groups': len(groups), 'automated_passed': sum(g['passed'] for g in groups),
    'pregame': read(QA / 'results.json'), 'browser': browser, 'profile_unchanged': True,
    'public_publication': 'not_requested', 'physical_mobile_device': False,
    'limitations': ['Pregame UI only; combat UI excluded', 'Physical phones, Safari/iOS and native soft keyboard behavior unverified', 'Earlier blocked scratch paths not retried'],
})
dump(READY / 'evidence-hashes.json', {p.relative_to(READY).as_posix(): sha(p) for p in READY.rglob('*') if p.is_file() and p.name not in ['evidence-hashes.json', 'verification.json']})
print(json.dumps({'groups': len(groups), 'passed': sum(g['passed'] for g in groups), 'hash': native['executable_sha256']}))
