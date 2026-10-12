"""Finalize verified local art evidence and authority documents without rebuilding the product."""
from pathlib import Path
import hashlib,json,shutil,subprocess,urllib.request

root=Path(__file__).resolve().parents[1]
current=root/'artifacts/current'; art=current/'art'
def read(p): return (root/p).read_text(encoding='utf-8-sig')
def data(p): return json.loads(read(p))
def write(p,s): (root/p).write_text(s,encoding='utf-8')
def dump(p,o): write(p,json.dumps(o,ensure_ascii=False,indent=2)+'\n')
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest().upper()

# Documentation and QA may change; the verified production package must not.
production=data('artifacts/current/production-source-hashes.json')
for p,h in production.items(): assert sha(root/p)==h.upper(),p
hashes=data('artifacts/current/release-hashes.json')
for p,h in hashes.items(): assert sha(root/'build/current'/p)==h.upper(),p
for p in (root/'build/current/web').iterdir():
    if p.is_file(): assert p.read_bytes()==(root/'web'/p.name).read_bytes(),p.name
with urllib.request.urlopen('http://127.0.0.1:8765/build/current/web/index.pck') as response:
    assert response.status==200
    assert hashlib.sha256(response.read()).hexdigest().upper()==hashes['web/index.pck']

web=data('artifacts/candidate/art/web-performance.json')[0]
assert web['kind']=='orbit-art-web-stress' and len(web['results'])==3
for t in web['results']:
    assert t['elapsed_advanced'] and t['ghost_frames']>=30
    assert t['enemies']>=240 and t['shots']>=240 and t['gems']==300
    assert t['p95_ms']<=16.7 and t['p99_ms']<=25
assert sum(t['over_33_3ms'] for t in web['results'])<=1
native=data('artifacts/candidate/art/final/moving-performance.json')
assert len(native)==3 and all(t['p95_ms']<=16.7 and t['p99_ms']<=25 for t in native)
memory=data('artifacts/current/art/memory-comparison.json')
assert all(t['elapsed_advanced'] and t['ghost_frames']>=25 for k in ['current','baseline'] for t in memory[k])
shutil.copytree(root/'artifacts/candidate/art',art,dirs_exist_ok=True)
v=data('artifacts/current/verification.json')
v.update(windows_performance=native,web_performance=web['results'],memory_comparison='art/memory-comparison.json',web_http_sha256_verified=True,
    resume_cause='User confirmed five-hour usage limit; no product crash inferred',full_loop_includes=['model','render','HUD','ghost capture'],
    web_over_33_3ms_total=sum(t['over_33_3ms'] for t in web['results']))
dump('artifacts/current/verification.json',v)
runtime=data('artifacts/current/art/runtime-status.json')
for step in runtime['steps']: step['log']=step['log'].replace('artifacts/candidate/','artifacts/current/')
runtime['steps'][0]['log']='artifacts/current/art/final-render.log'
runtime['full_loop_validation']='verification.json and art/memory-comparison.json; production hashes unchanged after promotion'
dump('artifacts/current/art/runtime-status.json',runtime)
if (art/'soak-status.json').exists():
    attempt=data('artifacts/current/art/soak-status.json')
    attempt['superseded_by']='release-input-soak.log; 34/34 passed, runtime-status complete'
    dump('artifacts/current/art/superseded-input-harness-attempt.json',attempt)
    (art/'soak-status.json').unlink()
helper=root/'art_source/complete_worklist.py'
helper.write_text(helper.read_text(encoding='utf-8').replace('artifacts/candidate/','artifacts/current/'),encoding='utf-8')
subprocess.run(['python',str(helper)],cwd=root,check=True)
rows=data('art_source/worklist.json')
assert len(rows)==125 and all(r['status']=='implemented-render-verified' for r in rows)
for row in rows:
    for p in row['evidence']: assert (root/p).is_file(),p
write('web/.gdignore','')

wp='/'.join(str(t['p95_ms']) for t in native)
bp='/'.join(str(t['p95_ms']) for t in web['results'])
bn='/'.join(str(t['p99_ms']) for t in web['results'])
texture_delta=memory['current'][0]['texture_bytes']-memory['baseline'][0]['texture_bytes']
static_delta=memory['current'][0]['static_memory_bytes']-memory['baseline'][0]['static_memory_bytes']
metrics=f'''- 자동 검사 **2,546/2,546**(20묶음), 실제 화면 회귀 **2,532/2,532**(16사례), 아트 계약·렌더 **325/325**, native 입력 **14/14**, 10분 자연 전투·신/구 고스트 **34/34** 통과.
- 1600×900 Windows/RTX4070 Ti/Compatibility 통합 전투: 준비60 + 측정300표본×3회, p95 **{wp}ms**, p99 10.600~11.015ms, 최대18.653ms. 모델·렌더·HUD·고스트 캡처 포함, Dummy 오디오로 음소거.
- 내장 Chromium/WebGL 통합 전투: 준비60 + 측정360표본×3회, p95 **{bp}ms**, p99 **{bn}ms**. 최종 브라우저의 논리 viewport 1280×1261, draw call 1065~1076. 적243·탄240·경험치300, 합성 최대 설치물. 전투 시간 진행과 고스트35프레임을 각 회 검증했다. 총1080표본 중33.3ms 초과1회(최대39.8ms), 나머지 두 회 최대26.0/24.5ms. 반복적인 초과는 없었으나 단발 지연을 숨기지 않는다. 브라우저 스케줄링 포함 수치다.
- 동일 QA 장면/논리1280×720의 이전 Git 소스 대조: 기존 p95 27.919/29.439/29.275ms, 새 그래픽9.524/9.951/9.811ms. 텍스처16,092,791→70,726,227bytes(**+{texture_delta:,}bytes, 약{texture_delta/1048576:.1f}MiB**). Godot static 할당99,743,581→98,920,374bytes({static_delta:+,.0f}bytes). 현재 전체 텍스처 약67.5MiB, 1600×900 아트 검사에서는68.1MiB로128MiB 예산 이내. static은 전체 프로세스 RSS가 아니며 Web static의0은 측정 불가로 취급한다.
- Web PCK **14,252,700bytes**, 기존6,943,544 대비+7,309,156bytes. Web 전체 파일 증가7,329,208bytes로 신규 다운로드20MiB 예산 이내.
- 보호된 원본 소스/fixture **59개 해시 동일**. 모델·콘텐츠·저장·고스트·업적·오디오 코드 유지. 기존 메뉴 흐름의 작은 화면 배치는 정보 누락을 고치기 위해 수정하고 회귀했다. 실제 사용자 프로필3파일의 실행 전후 해시 동일.
- 최종 Windows Release180프레임 종료0, 정확한 실행 파일 SHA 검증. 실제 exe 제목 캡처와 PE 아이콘 추출 확인. Web 실제 메뉴·출격·전투·일시정지·도감·강화 및 로딩/오류 화면 확인. Windows 하드웨어 클릭 검증과 native 엔진 입력 하네스는 구분한다.
'''
limitations='''- Windows Computer Use의 FrameArrived/window 캡처가2회 시간 초과했다. 좌표를 추측해 조작하지 않았으며, 실제 exe 실행/엔진 movie 캡처와 같은 Godot 버전의 입력 하네스로 검증했다. OS 하드웨어 직접 조작을 완료했다고 주장하지 않는다.
- 일부 정상 종료 로그에 기존2 ObjectDB 인스턴스 경고가 남는다. 추가 QA는 스크립트를 두 번 붙여 오디오 객체를 고아로 만들던 문제를 고쳐 오류 없이 종료했다. 진단 실패 로그는 원인 기록으로 남겼다.
- 저사양 실제 장치·Safari/Firefox·사람의 장시간 플레이/미적 수용·실제 오디오 청취는 확인하지 않았다. 자체 시각 평가4/5는 상용 등급 인증이나 사용자 승인이 아니다.
- 공개 GitHub/Pages에는 이번 그래픽 버전을 게시하지 않았다. 기존 공개3.18과 로컬 art-20261012는 서로 다른 실행 파일 세대다.
- 계획 조사 Temp `C:\\Users\\home\\AppData\\Local\\Temp\\orbit-breaker-art-review-20261012`는 과거 자동 승인 검토의 `blocked by policy`로 삭제가 실행되지 않았다. 우회/재시도하지 않았으며 임시 정리 잔여로 명시한다.
'''
release=f'''최신 로컬 세대는 **3.18 / art-20261012**다. `build/current/OrbitBreaker.exe`, Windows/Web ZIP, `build/current/web`와 `web/`, 대응 증거 `artifacts/current`가 최종본이다.

Windows SHA-256: `{hashes['OrbitBreaker.exe']}`. Web PCK: `{hashes['web/index.pck']}`.

기존 정상 실행 파일·해시·안내·증거를 retiring에 먼저 보존하고 후보 검증/내보내기/실행/해시 일치를 확인한 뒤 교체했다. 교체 후 이전 세대와 임시 백업을 정리했다. 최신 한 세대 정책을 지키며 원본 계획·제작 소스·미커밋 변경·플레이어 데이터는 보존했다. 최종 목록은 `artifacts/current/file-inventory.json`, `release-hashes.json`, `retention-status.json`, `verification.json`이다.
'''
report=read('docs/ART_IMPLEMENTATION_REPORT.md')
report=report.replace('최종 10분 실행·고스트 검사와 로컬 후보 승격은 진행 중이며, 아래 완료된 제작과 미완료 검증을 구분한다.','전체125개 제작 대상 적용과 최종 통합 검증·로컬 승격을 완료했다. 아래 구현 완료와 미확인 한계를 구분한다.')
report=report.replace('별도로 앱 아이콘을 교체했다.','별도로 앱 아이콘/SVG와 부트 PNG 2개를 교체하고 Windows PE 아이콘도 확인했다.')
report=report.replace('네 기체 조합 I/II','네 조합 I/II')
report=report.replace('| 움직임 | 검증 진행 중. 모델 시각을 사용하는 위험·보스와 pause 픽셀 동일성은 통과. 10분 자연 전투/고스트 검토 뒤 확정 |','| 움직임 | 4/5. 위험·보스의 모델 시각, pause 픽셀 동일성, 10분 자연 전투와 신/구 고스트 재생·배속·seek 확인 |')
report=report.replace('| 기술 품질 | 성능·알파/크기·실행 검사 통과. 최종 장시간 검사 및 배포 파일 대응 확인 뒤 확정 |','| 기술 품질 | 4/5. 알파 padding·최소 크기·전체 사용처·통합 성능·장시간 실행·배포 파일 대응 확인 |')
report=report.split('## 검증 결과와 한계')[0]+f'''## 검증 결과

{metrics}
## 배포와 재개 기록

{release}

중단 원인은 사용자 확인에 따라5시간 사용량 한도 소진이다. 제품 크래시로 추정하지 않는다. 기존 완료 단계는 재제작하지 않았고 최종 통합 성능 계측·메모리 비교·경로/문서 정합성을 마무리했다. `ART_RESUME_STATUS.md`와 `art_source/worklist.json`이 최종 체크포인트다. 생산 파일 해시는 승격 당시와 동일하다.

## 남은 한계

{limitations}
'''
write('docs/ART_IMPLEMENTATION_REPORT.md',report)
write('docs/VALIDATION_V3.md',f'''# ORBIT BREAKER 3.18 — art-20261012 최종 로컬 검증

2026-10-12. 게임 규칙은 [SURVIVAL_V3](SURVIVAL_V3.md), 아트 결정/제작 비교/실제 화면 평가는 [구현 보고서](ART_IMPLEMENTATION_REPORT.md),125개 행의 상태는 `art_source/worklist.json`을 따른다.

## 적용 범위

세라믹·흑연 기체, 흑요석·적색 코어의 침공체,3전장의 깊은 우주 표면, 물리 장비·모듈·드롭·FX,61개 벡터 도해를 전체 메뉴·전투·신/구 관전에 적용했다.95개 아트 리소스와2개 브랜딩 리소스다. Blender와Imagegen의 실제 Godot A/B를 거쳐 주 기체 제작 방식을 변경했다. 정확한 판정 경계·계기·기능 기호는 절차적 표현을 유지한다. 작은 강화 메뉴의 선택 카드/조건 스크롤과 로더 오류 표면까지 확인했다.

## 실제 검증

{metrics}
자동 검사는 게임 기능과 데이터 보호를 검증한다. 실제 렌더/움직임 검토는 별도이며 기체3종·적7종·3전장·12진화·36보급등급·6위험의 예고/작용·작은 메뉴·정지/배속/seek 증거를 확인했다. 자체6개 품질 축은 각4/5, 관찰된 치명 결함0이다. 테스트 통과나 이미지 생성만으로 미술 품질을 판정하지 않았다.

## 배포·보관

{release}

## 미확인/잔여

{limitations}
''')
matrix=read('docs/ART_ASSET_MATRIX.md').replace('**승인 후 구현 진행 중**','**125개 전체 적용·실제 렌더 검증 완료 / 로컬 art-20261012**').replace('현재 제작·연결 뒤 실제 렌더/기능 검증 중이며 전체 완료 판정은 보류한다.','125개 실제 제작 행 모두 `implemented-render-verified`다. 자산95개와 브랜딩2개를 전체 사용처에 연결했다. 최종 제작법·의도적 기능 도형·증거는 worklist와 [구현 보고서](ART_IMPLEMENTATION_REPORT.md)를 따른다. 사람의 미적 수용은 별도 미확인 항목이다.')
write('docs/ART_ASSET_MATRIX.md',matrix)
for p in ['docs/ART_DIRECTION_PLAN.md','docs/ART_REFERENCE_REVIEW.md']:
    original=read(p)
    note='\n> 2026-10-12 구현 완료: 승인 방향을 유지해 전체125개 대상을 적용하고 로컬 art-20261012를 검증·승격했다. 실제 Blender/Imagegen 전투 비교 결과 주 기체는 Imagegen, 정밀 장비는 Blender, 시스템 정보는 SVG로 제작했다. 최종 근거와 한계는 [구현 보고서](ART_IMPLEMENTATION_REPORT.md)를 따른다. 아래는 승인 당시 설계/조사 기록이며 원본은 `art_source/baseline/`에 보존했다.\n'
    if '> 2026-10-12 구현 완료:' not in original: original=original.replace('\n','\n'+note,1)
    write(p,original)
survival=read('docs/SURVIVAL_V3.md')
if '## art-20261012 표현 개편' not in survival:
    survival+='''\n## art-20261012 표현 개편 (게임 규칙 유지)

기체/적의 장갑·코어·실물 장비와3전장 표면,61개 정보 도해를 전체 메뉴·전투·관전에 공유한다. 새 외관은 판정/스탯/난수/시간/입력/저장/고스트 형식을 바꾸지 않는다. 위험선·반경·활동 경계·계기·상태/방향 기호는 실제 모델 좌표를 따른다. 상단/보조 패널12%, 획득 알림 배경6%·글자60%, 일시정지28px와 기존 ESC를 유지한다. 강화 조건이 많은 카드는 제한된 스크롤을 사용하고 작은 메뉴에서 카드와 선택 버튼을 한 쌍으로 배치한다. 표현의 완료 근거는 ART_IMPLEMENTATION_REPORT.md와 VALIDATION_V3.md다.
'''
write('docs/SURVIVAL_V3.md',survival)
retention=read('docs/ARTIFACT_RETENTION.md').split('## 현재 최신본')[0]
write('docs/ARTIFACT_RETENTION.md',retention+'## 현재 최신본 (2026-10-12)\n\n'+release+'\n계획 조사 Temp 삭제 차단은 배포 세대 정리와 구분한다. 공개 사이트는 기존3.18이며 이번 로컬 아트 세대는 게시하지 않았다.\n')
resume=read('docs/ART_RESUME_STATUS.md')
write('docs/ART_RESUME_STATUS.md',f'''# Orbit Breaker 그래픽 개편 — 최종 재개 체크포인트

2026-10-12. **로컬 구현·검증·승격 완료**. 사용자 확인 중단 원인:5시간 사용량 한도. 제품 크래시를 확인한 것은 아니다. 기존 미커밋 변경과 완성 자산을 유지했다.

{release}

전체125개 행 완료,95개 아트+2개 브랜딩. 자동2546/렌더2532/아트325/native입력14/10분자연전투·신구고스트34 통과. 통합 Windows p95 {wp}ms, Web p95 {bp}ms. Web1080표본 중33.3ms 초과1회. `verification.json`, `art/memory-comparison.json`, `art/runtime-status.json`이 정확한 수치/증거다.

추가 계측의 QA 장면은 main 스크립트를 두 번 초기화해 SoundBank 객체가 남던 문제를 수정했다. 이전 소스의 `_draw_enemy` 인자가 하나인 차이는 비교 fixture에만 반영했다. 두 비교 모두 실제 시간 진행/고스트 캡처와 오류 없는 종료를 확인했다. 게임 생산 코드/최신 실행 파일은 바꾸지 않았다.

재개 시 `production-source-hashes.json`, `release-hashes.json`과 실제 파일을 먼저 비교한다. 모든 체크포인트가 완료되어 있으므로 제작/빌드/승격을 자동 재실행하지 않는다. `integrate.py`는1회 마이그레이션 기록이다. 기존 `promote_art_release.ps1`는 이전 세대 SHA를 보호하는 이번 전환용이며 현재본에 무작정 재실행하지 않는다. 새 생산 변경이 생기면 영향받는 검증·내보내기부터 새 후보를 만든다.

잔여 한계는 [최종 보고서](ART_IMPLEMENTATION_REPORT.md)에 구분했다. Temp 정리는 blocked by policy, Windows OS 직접 클릭/저사양/다른 브라우저/사람 평가/공개 게시를 완료 처리하지 않았다.

---
## 중단 전 과정 기록 (최종 상태 아님)

{resume}
''')
source=read('art_source/README.md')
source+='''\nFinal local delivery: `artifacts/current/verification.json` and `worklist.json` (125 verified rows). Source hashes match the promoted product. `finish_art_records.py` finalizes documentation/evidence only; it requires successful supplemental candidate QA evidence. `prepare_art_delivery.py` / `promote_art_release.ps1` are the completed generation transition and must not be rerun against current without reviewing their previous-generation guards.

Shared projectile textures and grouped trails reduce draw calls; rotated actors use textured primitives. These preserve collision radii and model behavior. `create_brand_splash.gd` reproduces the boot PNG from the custom SVG. Small upgrade menus retain all conditions and associate each choice button with its card. The full-loop fixture includes main physics/HUD/ghost capture; memory comparison uses archived baseline source with a QA-only signature adapter. No scratch QA project is shipped or retained after validation.
'''
write('art_source/README.md',source)
dump('artifacts/current/art/final-records-status.json',{'complete':True,'cause':'five-hour usage limit (user confirmed)','production_hashes_unchanged':True,'release_hashes_unchanged':True,'rows':len(rows),'web_http_sha256_verified':True,'remaining':'reported platform/human/Temp limitations; no unimplemented matrix rows'})
print('Final records and 125 row evidence paths verified; production and release bytes unchanged.')
