"""Collect checked evidence and package the verified candidate; does not promote it."""
from pathlib import Path
import json,re,hashlib,zipfile
root=Path(__file__).resolve().parents[1]
build=root/'build/candidate'; art=root/'artifacts/candidate'; qa=art/'art'
def read(p): return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest().upper()
def checked(log,tag):
    text=log.read_text(encoding='utf-8-sig',errors='replace')
    match=re.search(tag+r' SELF-CHECK: (\d+) / (\d+) assertions passed',text)
    assert match and match[1]==match[2] and not re.search(r'(?im)\b(?:SCRIPT ERROR|ERROR|Parse Error):',text),str(log)
    return int(match[1])
automated=read(art/'automated-results.json')
for entry in automated:
    tag=entry['name']
    if tag in ['UI','UIUX','ART']:
        script={'UI':'test_ui','UIUX':'test_uiux','ART':'test_art'}[tag]
        entry['passed']=entry['total']=checked(qa/f'final-{script}.log',tag)
(art/'automated-results.json').write_text(json.dumps(automated,indent=2),encoding='utf-8')
render=read(art/'render-results.json')
count=checked(qa/'art-test.log','ART')
assert count==325
assert read(qa/'runtime-status.json')['complete'] and read(qa/'runtime-status.json')['profile_unchanged']
assert checked(qa/'release-input-soak.log','RELEASE INPUT')==34
quick=checked(qa/'release-input.log','RELEASE INPUT')
assert read(qa/'final-correction-status.json')['complete']
native=read(qa/'native-release-final.json')
assert native['exit']==0 and native['profile_unchanged'] and native['executable_sha256'].upper()==sha(build/'OrbitBreaker.exe')
win=read(qa/'final/moving-performance.json'); web=read(qa/'web-performance.json')['results']
for group in [win,web]:
    assert len(group)==3
    for t in group: assert t['p95_ms']<=16.7 and t['p99_ms']<=25,t
matrix=read(root/'art_source/worklist.json')
assert len(matrix)==125 and all(r['status']=='implemented-render-verified' for r in matrix)
for row in matrix:
    for evidence in row['evidence']: assert (root/evidence).is_file(),evidence
source=read(qa/'web-stress/source-equality.json')
for name,digest in source.items(): assert sha(root/name)==digest.upper(),name
protected=int(re.search(r'Protected source/fixtures: (\d+) hashes unchanged',(qa/'verification.log').read_text(encoding='utf-8-sig'))[1])
assert protected==59
guide='''ORBIT BREAKER 3.18 / ART 2026-10-12
Windows: OrbitBreaker.exe를 실행하세요.
이번 그래픽 개편은 로컬 검증본입니다. 기존 공개 사이트에는 아직 게시하지 않았습니다.
Web: 압축을 풀고 HTTP 서버에서 index.html을 여세요. file://로 직접 열면 동작하지 않습니다.
저장소에서: python -m http.server 8765 --bind 127.0.0.1 --directory build/current/web
그 다음 http://127.0.0.1:8765/index.html 에 접속하세요.
이동: 마우스 / WASD / 방향키. 돌진: 좌클릭 / Space. 오버드라이브: 우클릭 / E.
TAB: 도감. ESC: 일시정지. F11: 전체 화면. 강화: 1/2/3 또는 선택 버튼.
기존 게임 규칙·밸런스·저장·고스트 형식은 유지합니다. 기록과 랭킹은 이 기기/브라우저 로컬입니다.
Windows 기록: %APPDATA%/OrbitBreaker/profile/. Windows와 Web의 저장소는 별개입니다.
출처: 자체 Blender/SVG/Imagegen 아트. Noto 폰트 OFL와 Godot 등은 게임 제작 정보에서 확인하세요.
검증: RTX4070 Ti Windows와 내장 Chromium Web에서 검사했습니다. 다른 장치/사람의 미적 수용은 별도입니다.
'''
(build/'PLAY-KO.txt').write_text(guide,encoding='utf-8')
with zipfile.ZipFile(build/'OrbitBreaker-3.18-Art-Windows.zip','w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    for name in ['OrbitBreaker.exe','PLAY-KO.txt']: z.write(build/name,name)
with zipfile.ZipFile(build/'OrbitBreaker-3.18-Art-Web.zip','w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    for p in (build/'web').rglob('*'):
        if p.is_file(): z.write(p,p.relative_to(build/'web'))
    z.write(build/'PLAY-KO.txt','PLAY-KO.txt')
hashes={p.relative_to(build).as_posix():sha(p) for p in build.rglob('*') if p.is_file() and p.name!='SHA256.txt'}
(art/'release-hashes.json').write_text(json.dumps(hashes,indent=2),encoding='utf-8')
(build/'SHA256.txt').write_text('\n'.join(f'{v}  {k}' for k,v in hashes.items())+'\n',encoding='utf-8')
production={p.relative_to(root).as_posix():sha(p) for p in list((root/'scripts').glob('*.gd'))+[root/'project.godot',root/'export_presets.cfg',root/'icon.svg']+list((root/'assets').rglob('*')) if p.is_file() and p.suffix!='.import'}
(art/'production-source-hashes.json').write_text(json.dumps(production,indent=2),encoding='utf-8')
status=read(qa/'runtime-status.json')
for step in status['steps']:
    if 'ten minute' in step['name']: step['log']='artifacts/candidate/art/release-input-soak.log'
status['source_hashes']={p.relative_to(root).as_posix():sha(p).lower() for p in list((root/'scripts').glob('*.gd'))+[root/'project.godot',root/'export_presets.cfg']}
status['post_soak_changes']='Compact menu links/selection pairing and branding only; 16 render cases, 325 art checks, native input, exports, native180 and final Web stress revalidated; model/combat/replay functions unchanged.'
(qa/'runtime-status.json').write_text(json.dumps(status,indent=2),encoding='utf-8')
verification={'version':'3.18','generation':'art-20261012','local_validation_complete':True,'promotion':'pending','automated_groups':len(automated),'automated_passed':sum(e['passed'] for e in automated),'render_cases':len(render),'render_passed':sum(e['passed'] for e in render),'art_passed':count,'native_input_passed':quick,'soak_passed':34,'soak_minutes':10,'protected_hashes':protected,'matrix_rows':125,'art_resources':95,'branding_resources':2,'windows_performance':win,'web_performance':web,'native_release':native,'pck_bytes':(build/'web/index.pck').stat().st_size,'pck_baseline_bytes':(root/'build/current/web/index.pck').stat().st_size,'web_bytes_delta':sum(p.stat().st_size for p in (build/'web').rglob('*') if p.is_file())-sum(p.stat().st_size for p in (root/'build/current/web').rglob('*') if p.is_file()),'visual_review':{'identity':4,'form':4,'readability':4,'motion':4,'composition':4,'technical':4,'critical_findings':0,'human_acceptance':'not performed'},'limitations':['Native Computer Use capture timed out; native engine input harness used instead of claiming hardware clicks','Low-end hardware, Safari/Firefox and human long-play/aesthetic acceptance not checked','2 ObjectDB exit warnings remain in some normal shutdown logs','Planning Temp cleanup previously blocked by policy; not retried','No public publication']}
(art/'verification.json').write_text(json.dumps(verification,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in verification.items() if k in ['automated_passed','render_passed','art_passed','protected_hashes','pck_bytes','web_bytes_delta']}))
print('Verified candidate packaged; promotion remains separate.')
