"""Curate verified audio evidence and package the guarded local generation."""
from pathlib import Path
import hashlib
import json
import re
import shutil
import subprocess
import zipfile
import imageio_ffmpeg

ROOT=Path(__file__).resolve().parents[1]
QA=ROOT/'artifacts/audio-candidate'
READY=ROOT/'artifacts/audio-ready'
BUILD=ROOT/'build/candidate'
GENERATION='audio-20261014'
FFMPEG=imageio_ffmpeg.get_ffmpeg_exe()

def read(path):return json.loads(path.read_text(encoding='utf-8-sig'))
def dump(path,value):path.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest().upper()

def checked(path):
    text=path.read_text(encoding='utf-8-sig',errors='replace')
    assert not re.search(r'(?im)\b(?:SCRIPT ERROR|ERROR|Parse Error):',text),path
    return text

def media_metrics(path):
    p=subprocess.run([FFMPEG,'-hide_banner','-i',str(path),'-af','loudnorm=print_format=json','-f','null','-'],capture_output=True,text=True,encoding='utf-8',errors='replace',check=True)
    match=re.findall(r'\{\s*"input_i".*?\}',p.stderr,re.S)
    assert match,path
    value=json.loads(match[-1])
    return {key:float(value[key]) for key in ['input_i','input_tp','input_lra']}

def main():
    status=read(QA/'delivery-status.json')
    assert status['complete'] and not status.get('error'),status
    assert not READY.exists(),'Inspect previous staging before retrying'
    full=checked(QA/'full-build.log')
    assert 'Candidate exported.' in full
    groups=[{'name':m[1],'passed':int(m[2])} for m in re.finditer(r'(?m)^([A-Z0-9 ]+) SELF-CHECK: (\d+) / \2 assertions passed',full)]
    support=re.search(r'SUPPORT TESTS: (\d+) checks, 0 failures',full)
    assert support and len(groups)==22,groups
    groups.append({'name':'SUPPORT','passed':int(support[1])})
    for name in ['audio-final','render','audio-profile','long-review','native-release','packaged-scene','packaged-rendered','export-probe']:
        checked(QA/(name+'.log'))
    native=read(QA/'native-release.json')
    assert native['profile_unchanged'] and native['exit']==0
    assert sha(BUILD/'OrbitBreaker.exe')==native['executable_sha256']
    for path,digest in native['source_hashes'].items():assert sha(ROOT/path)==digest,path
    browser=read(QA/'browser-status.json')
    assert browser['complete'] and not browser['errors'] and browser['audio_output_recorded'],browser
    manifest=read(ROOT/'audio_source/manifest.json')
    for row in manifest['assets']:assert sha(ROOT/row['path'])==row['sha256'],row['path']
    assert manifest['runtime_bytes'] < 15*1024*1024
    capture=read(QA/'long-review/capture.json')
    assert capture['seconds']>=600 and capture['peak_one_shots']<=16 and capture['save_error']==0
    wav=QA/'long-review/mix.wav'
    metrics={'native':media_metrics(wav),'browser':media_metrics(QA/'browser-mix.webm')}
    assert metrics['native']['input_tp'] <= -1.0 and metrics['browser']['input_tp'] <= -.5,metrics
    assert metrics['native']['input_i'] > -45 and metrics['browser']['input_i'] > -55,metrics
    subprocess.run([FFMPEG,'-y','-hide_banner','-loglevel','error','-i',str(wav),'-c:a','libvorbis','-q:a','5',str(QA/'long-review/mix.ogg')],check=True)
    # A ninety-second contact reel, nine seconds from each real recorded section.
    filters=[]
    for i in range(10):filters.append(f'[0:a]atrim=start={i*60+3}:end={i*60+12},asetpts=PTS-STARTPTS[a{i}]')
    filters.append(''.join(f'[a{i}]' for i in range(10))+'concat=n=10:v=0:a=1[out]')
    subprocess.run([FFMPEG,'-y','-hide_banner','-loglevel','error','-i',str(wav),'-filter_complex',';'.join(filters),'-map','[out]','-c:a','libvorbis','-q:a','5',str(QA/'audio-preview.ogg')],check=True)
    frames=QA/'preview-frames.txt'
    frames.write_text(''.join("file '"+(QA/f'long-review/scene-{i*2+1:02d}.png').as_posix()+"'\nduration 9\n" for i in range(10))+"file '"+(QA/'long-review/scene-19.png').as_posix()+"'\n",encoding='utf-8')
    subprocess.run([FFMPEG,'-y','-hide_banner','-loglevel','error','-f','concat','-safe','0','-i',str(frames),'-i',str(QA/'audio-preview.ogg'),'-t','90','-vf','fps=10,format=yuv420p','-c:v','libx264','-preset','fast','-crf','23','-c:a','aac','-b:a','160k','-movflags','+faststart',str(QA/'audio-preview.mp4')],check=True)
    dump(QA/'mix-analysis.json',metrics)
    guide='''ORBIT BREAKER 3.18.3 / AUDIO / 2026-10-14
Windows: OrbitBreaker.exe 실행. Web: HTTP 서버에서 index.html 실행.
정밀 SF 전투 음악, 전장별 환경음, 전투·장착·미션·재해 효과음 적용.
설정: 전체 소리/BGM ON·OFF와 전체·음악·효과음 음량 조절.
낮은 선체는 코어 경보, 빠른 자연 붕괴는 기계 틱, 외곽은 하행 신호.
마우스/WASD 이동, 좌클릭/Space 돌진, 우클릭/E 오버드라이브.
모바일 드래그 이동, 길게 끌었다 놓기 돌진, 두 번 탭 오버드라이브.
기존 규칙·수치·로컬 저장·랭킹·고스트 형식 유지.
공개 사이트에는 이 로컬 오디오 세대를 게시하지 않았습니다.
실물 휴대폰·Safari·저사양·사람의 청취 수용은 미검증입니다.
'''
    (BUILD/'PLAY-KO.txt').write_text(guide,encoding='utf-8')
    for platform in ['Windows','Web']:
        members=[BUILD/'OrbitBreaker.exe'] if platform=='Windows' else [p for p in (BUILD/'web').rglob('*') if p.is_file()]
        members.append(BUILD/'PLAY-KO.txt')
        with zipfile.ZipFile(BUILD/f'OrbitBreaker-3.18.3-Audio-{platform}.zip','w',zipfile.ZIP_DEFLATED) as archive:
            for p in members:archive.write(p,p.relative_to(BUILD/'web') if p.is_relative_to(BUILD/'web') else p.name)
        with zipfile.ZipFile(BUILD/f'OrbitBreaker-3.18.3-Audio-{platform}.zip') as archive:assert archive.testzip() is None
    hashes={p.relative_to(BUILD).as_posix():sha(p) for p in BUILD.rglob('*') if p.is_file() and p.name!='SHA256.txt'}
    (BUILD/'SHA256.txt').write_text(''.join(f'{digest}  {path}\n' for path,digest in hashes.items()),encoding='utf-8')
    READY.mkdir()
    audio=READY/'audio';audio.mkdir()
    names=['baseline.json','model-baseline.txt','delivery-status.json','full-build.log','audio-final.log','render.log','audio-profile.log','profile.json','long-review.log','native-release.log','packaged-scene.log','native-release.json','export-probe.log','browser-status.json','browser-mix.webm','mix-analysis.json','audio-preview.ogg','audio-preview.mp4']
    for name in names:shutil.copy2(QA/name,audio/name)
    for p in QA.glob('browser-frame-*.png'):shutil.copy2(p,audio/p.name)
    shutil.copytree(QA/'long-review',audio/'long-review',ignore=shutil.ignore_patterns('mix.wav'))
    shutil.copy2(ROOT/'audio_source/manifest.json',audio/'asset-manifest.json')
    for p in (ROOT/'artifacts/candidate').rglob('*'):
        if p.is_file() and p.stat().st_mtime>=status['started']:
            target=READY/'render'/p.relative_to(ROOT/'artifacts/candidate');target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,target)
    previous=read(QA/'baseline.json')['previous_executable_sha256']
    profiles=read(QA/'profile.json')
    old_retention=read(ROOT/'artifacts/current/retention-status.json')
    dump(READY/'previous-retention.json',old_retention)
    dump(READY/'automated-results.json',groups)
    dump(READY/'production-source-hashes.json',native['source_hashes'])
    dump(READY/'release-hashes.json',hashes)
    verification={'version':'3.18.3','generation':GENERATION,'local_validation_complete':True,'promotion':'pending','previous_executable_sha256':previous,'native_release':native,'automated_groups':len(groups),'automated_passed':sum(g['passed'] for g in groups),'audio_cues':len(manifest['cues']),'audio_assets':len(manifest['assets']),'audio_runtime_bytes':manifest['runtime_bytes'],'audio_capture':capture,'mix_analysis':metrics,'performance':profiles,'browser':browser,'public_publication':'not_requested','human_listening':False,'physical_mobile_device':False,'limitations':['Human listening acceptance, physical phone, Safari and low-end performance not verified','Native release EXE startup tested headless; embedded scene/assets additionally tested using matching Godot engine; native packaged interactive audio not separately certified','Forced engine --quit-after bypasses graceful stream shutdown; normal window close is verified','Previously blocked scratch paths remain subject to prior retention status']}
    dump(READY/'verification.json',verification)
    dump(READY/'evidence-hashes.json',{p.relative_to(READY).as_posix():sha(p) for p in READY.rglob('*') if p.is_file() and p.name not in ['evidence-hashes.json','verification.json']})
    print(json.dumps({k:verification[k] for k in ['generation','automated_groups','automated_passed','audio_cues','audio_assets','mix_analysis']}))

if __name__=='__main__':main()
