"""Package a validated mobile candidate and only evidence for this generation."""
from pathlib import Path
import hashlib, json, re, shutil, zipfile

ROOT = Path(__file__).resolve().parents[1]
MOBILE = ROOT/'artifacts/mobile-candidate'
QA = ROOT/'artifacts/candidate'
READY = ROOT/'artifacts/mobile-ready'
BUILD = ROOT/'build/candidate'
PREVIOUS = '1F4D0FCBE22227C3C7DA024AB2ECBF9ADDAA97F322D25E39C0AF7D44ECB2F74C'
def read(p): return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest().upper()
def dump(p,v): p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def log(p):
    text=p.read_text(encoding='utf-8-sig',errors='replace')
    assert not re.search(r'(?im)\b(?:SCRIPT ERROR|ERROR|Parse Error):',text),p
    return text
def passed(p,tag):
    m=re.search(re.escape(tag)+r' SELF-CHECK: (\d+) / (\d+) assertions passed',log(p))
    assert m and m[1]==m[2],p
    return int(m[1])

assert not READY.exists(), 'Inspect existing staging before retrying'
assert sha(ROOT/'build/current/OrbitBreaker.exe')==PREVIOUS
gates=read(MOBILE/'final-gates.json')
assert gates['complete'] and gates['profile_unchanged']
assert sha(BUILD/'OrbitBreaker.exe')==gates['executable_sha256']
for name,digest in gates['source_hashes'].items(): assert sha(ROOT/name)==digest.upper(),name
for step in gates['steps']: assert step['exit']==0 and log(ROOT/step['log'])
build_text=log(MOBILE/'full-build.log')
groups=[{'name':m[1],'passed':int(m[2])} for m in re.finditer(r'(?m)^([A-Z0-9 ]+) SELF-CHECK: (\d+) / \2 assertions passed',build_text)]
support=re.search(r'SUPPORT TESTS: (\d+) checks, 0 failures',build_text)
assert support
groups.append({'name':'SUPPORT','passed':int(support[1])})
assert len(groups)==21 and sum(r['passed'] for r in groups)==2557,groups
assert passed(MOBILE/'mobile-native.log','MOBILE')>=33
render=read(QA/'render-results.json')
assert len(render)==16
assert passed(QA/'art/art-test.log','ART')==325
motion=read(QA/'motion/motion-results.json')
assert motion['failures']==0 and passed(QA/'motion/motion.log','MOTION')==motion['checks']
browser=read(MOBILE/'web-play-status.json')
assert browser['complete'] and not browser['product_console']
web_input=read(MOBILE/'web-input.json')
assert web_input['passed']==web_input['total']==5
performance=read(MOBILE/'web-performance.json')
assert len(performance)==2 and {r['profile'] for r in performance}=={'mixed','tank'}
for report in performance:
    assert len(report['results'])==3
    for t in report['results']:
        assert t['p95_ms']<=16.7 and t['p99_ms']<=25 and t['enemies']>=240 and t['shots']>=240 and t['gems']==300
        assert t['elapsed_advanced'] and t['ghost_frames']>=30

guide='''ORBIT BREAKER 3.18.2 / MOBILE 2026-10-13
공개 플레이: https://libralightluda.github.io/orbit-breaker/
Windows: OrbitBreaker.exe 실행.
Web: HTTP 서버에서 index.html을 엽니다. file:// 실행은 지원하지 않습니다.
모바일: 가로 화면 권장. 드래그 이동, 탭 돌진, 두 번 탭 오버드라이브.
두 번 탭 판별은 0.24초이며 오버드라이브만 발동합니다. 아래 스킬 버튼은 즉시 발동합니다.
가로 전체화면 버튼은 지원 브라우저에서 회전을 잠급니다. 지원하지 않으면 기기를 직접 돌리세요.
데스크톱: 마우스/WASD 이동, 좌클릭/Space 돌진, 우클릭/E 오버드라이브.
기존 규칙·밸런스·로컬 저장·고스트 호환 유지. Windows와 Web 저장소는 별개입니다.
실제 휴대폰/Safari 성능은 미검증. Godot 터치 입력 및 Chromium 모바일 화면 크기에서 검증했습니다.
'''
(BUILD/'PLAY-KO.txt').write_text(guide,encoding='utf-8')
for kind,members in [('Windows',[BUILD/'OrbitBreaker.exe',BUILD/'PLAY-KO.txt']),('Web',list((BUILD/'web').rglob('*'))+[BUILD/'PLAY-KO.txt'])]:
    with zipfile.ZipFile(BUILD/f'OrbitBreaker-3.18.2-{kind}.zip','w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
        for p in members:
            if p.is_file(): z.write(p,p.relative_to(BUILD/'web') if p.is_relative_to(BUILD/'web') else p.name)
    with zipfile.ZipFile(BUILD/f'OrbitBreaker-3.18.2-{kind}.zip') as z: assert z.testzip() is None
hashes={p.relative_to(BUILD).as_posix():sha(p) for p in BUILD.rglob('*') if p.is_file() and p.name!='SHA256.txt'}
(BUILD/'SHA256.txt').write_text(''.join(f'{v}  {k}\n' for k,v in hashes.items()),encoding='utf-8')
READY.mkdir()
shutil.copytree(MOBILE,READY/'mobile')
for step in gates['steps']:
    step['log']=step['log'].replace('artifacts/mobile-candidate/','artifacts/current/mobile/')
dump(READY/'mobile/final-gates.json',gates)
for folder in ['uiux','small','items','events','expedition','expedition-small','feedback315','feedback317','art/final','art/release-input']:
    if (QA/folder).is_dir(): shutil.copytree(QA/folder,READY/folder,dirs_exist_ok=True)
for p in QA.iterdir():
    if p.is_dir() and p.name.startswith(('viewport-','feedback318-')): shutil.copytree(p,READY/p.name)
    if p.is_file() and p.suffix in ['.log','.json','.png']: shutil.copy2(p,READY/p.name)
(READY/'motion').mkdir()
for clip in motion['clips']:
    for p in (QA/'motion').glob(clip['name']+'-*'): shutil.copy2(p,READY/'motion'/p.name)
for name in ['motion-results.json','motion.log','index.html']: shutil.copy2(QA/'motion'/name,READY/'motion'/name)
shutil.copy2(QA/'art/art-test.log',READY/'art/art-test.log')
shutil.copy2(QA/'art/web-stress/source-equality.json',READY/'mobile/source-equality.json')
for filename in ['worklist.json','motion_worklist.json']:
    for row in read(ROOT/'art_source'/filename):
        for e in row['evidence']:
            assert (READY/e.removeprefix('artifacts/current/')).is_file() if e.startswith('artifacts/current/') else (ROOT/e).is_file(),e
production={p.relative_to(ROOT).as_posix():sha(p) for p in list((ROOT/'scripts').rglob('*'))+list((ROOT/'assets').rglob('*'))+[ROOT/'project.godot',ROOT/'export_presets.cfg',ROOT/'main.tscn',ROOT/'icon.svg',ROOT/'tools/web_shell.html'] if p.is_file() and p.suffix!='.import'}
dump(READY/'production-source-hashes.json',production)
dump(READY/'release-hashes.json',hashes)
dump(READY/'automated-results.json',groups)
verification={'version':'3.18.2','generation':'mobile-20261013','promotion':'pending','local_validation_complete':True,
 'previous_executable_sha256':PREVIOUS,'native_release':gates,'automated_groups':len(groups),'automated_passed':sum(r['passed'] for r in groups),
 'mobile_native_checks':passed(MOBILE/'mobile-native.log','MOBILE'),'desktop_input_checks':passed(MOBILE/'desktop-input.log','RELEASE INPUT'),
 'render_cases':16,'render_passed':sum(r['passed'] for r in render),'art_passed':325,'motion_checks':motion['checks'],'motion_frames':576,
 'web_performance':performance,'web_play':browser,'web_touch_checks':web_input,'public_publication':'pending','physical_mobile_device':False,
 'limitations':['Physical phone, iOS/Safari, low-end hardware and long human play not verified','Previously blocked temporary cleanup not retried'],
 'validation_scope':gates.get('retained_checks_note','Full native gates and exports')}
dump(READY/'verification.json',verification)
dump(READY/'evidence-hashes.json',{p.relative_to(READY).as_posix():sha(p) for p in READY.rglob('*') if p.is_file() and p.name!='verification.json'})
print('Mobile candidate packaged and curated. Current release remains untouched.')
