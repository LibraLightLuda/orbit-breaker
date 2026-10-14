"""Required audio release checks, with UTF-8 logs and explicit progress/status.

Run with the bundled workspace Python. Player files are checked before/after.
This validates and exports a candidate; promotion remains separately guarded.
"""
from pathlib import Path
import hashlib
import json
import re
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'artifacts/audio-candidate'
GODOT = 'D:/Antigravity/GodotGameProject/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe'
STATUS = {'complete':False,'steps':[],'started':time.time()}

def dump(path,value):
    path.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

def run(name,args,token='',timeout=1200):
    STATUS['running']=name
    dump(OUT/'delivery-status.json',STATUS)
    print(name,flush=True)
    start=time.time()
    with (OUT/(name+'.log')).open('w',encoding='utf-8') as log:
        result=subprocess.run(args,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,timeout=timeout)
    text=(OUT/(name+'.log')).read_text(encoding='utf-8-sig',errors='replace')
    assert result.returncode == 0 and not re.search(r'(?im)\b(?:SCRIPT ERROR|ERROR|Parse Error):',text), f'{name}: inspect its log'
    if token: assert token in text, f'{name}: missing success marker'
    STATUS['steps'].append({'name':name,'seconds':round(time.time()-start,2),'exit':result.returncode})
    dump(OUT/'delivery-status.json',STATUS)

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    resume='--resume-render' in sys.argv
    if resume:
        STATUS.update(json.loads((OUT/'delivery-status.json').read_text(encoding='utf-8')))
        STATUS.pop('error',None)
        assert {'full-build','audio-final'} <= {s['name'] for s in STATUS['steps']}
        production=[p for folder in ['scripts','assets'] for p in (ROOT/folder).rglob('*') if p.is_file() and p.suffix not in ['.import','.uid']]
        production += [ROOT/p for p in ['project.godot','main.tscn','export_presets.cfg','tools/web_shell.html']]
        assert all(p.stat().st_mtime<=STATUS['started'] for p in production),'Production changed; full regression required'
    else:
        # Capture wall-clock audio while CPU-only regressions run, then profile alone.
        review_log=(OUT/'long-review.log').open('w',encoding='utf-8')
        review=subprocess.Popen([GODOT,'--path',str(ROOT),'--resolution','1280x720','--script','res://tests/audio_review.gd','--','--seconds=600','--output=res://artifacts/audio-candidate/long-review'],cwd=ROOT,stdout=review_log,stderr=subprocess.STDOUT)
        STATUS['review_pid']=review.pid
        run('full-build',['powershell','-NoProfile','-ExecutionPolicy','Bypass','-File','tools/build.ps1'],'Candidate exported.')
        run('audio-final',[GODOT,'--headless','--path',str(ROOT),'--script','res://tests/test_audio.gd'],'AUDIO SELF-CHECK:')
    run('render',['powershell','-NoProfile','-ExecutionPolicy','Bypass','-File','tools/verify_uiux.ps1'],'All rendering fixtures passed.')
    STATUS['running']='long-review'
    dump(OUT/'delivery-status.json',STATUS)
    code=0 if resume else review.wait(timeout=750)
    if not resume:review_log.close()
    text=(OUT/'long-review.log').read_text(encoding='utf-8-sig',errors='replace')
    assert code == 0 and 'AUDIO REVIEW COMPLETE' in text and not re.search(r'(?im)\b(?:SCRIPT ERROR|ERROR|Parse Error):',text), 'long-review: inspect its log'
    STATUS['steps'].append({'name':'long-review','exit':code})
    run('audio-profile',[GODOT,'--path',str(ROOT),'--resolution','1280x720','--script','res://tests/audio_profile.gd'],'AUDIO PROFILE COMPLETE')
    exe=ROOT/'build/candidate/OrbitBreaker.exe'
    run('native-release',[str(exe),'--headless','--quit-after','180'])
    isolated=OUT/'package-probe'
    isolated.mkdir(exist_ok=True)
    run('packaged-scene',[GODOT,'--headless','--path',str(isolated),'--main-pack',str(exe),'--script',str(ROOT/'tests/audio_smoke.gd')],'AUDIO SMOKE COMPLETE')
    run('packaged-rendered',[GODOT,'--path',str(isolated),'--main-pack',str(exe),'--script',str(ROOT/'tests/audio_smoke.gd')],'AUDIO SMOKE COMPLETE')
    run('export-probe',[GODOT,'--headless','--path',str(isolated),'--main-pack',str(exe),'--script',str(ROOT/'tests/audio_export_probe.gd')],'AUDIO EXPORT SELF-CHECK:')
    baseline=json.loads((OUT/'baseline.json').read_text(encoding='utf-8-sig'))
    for path,digest in baseline['profile'].items():
        assert sha(Path(path))==digest, f'Player profile changed: {path}'
    assert sha(ROOT/'build/current/OrbitBreaker.exe')==baseline['previous_executable_sha256'],'Current normal release changed during candidate checks'
    source={p.relative_to(ROOT).as_posix():sha(p) for folder in ['scripts','assets'] for p in (ROOT/folder).rglob('*') if p.is_file() and p.suffix not in ['.import','.uid']}
    source.update({p:sha(ROOT/p) for p in ['project.godot','main.tscn','export_presets.cfg','tools/web_shell.html']})
    dump(OUT/'native-release.json',{'exit':0,'executable_sha256':sha(exe),'source_hashes':source,'profile_unchanged':True,'native_startup':'release EXE headless 180 frames; Dummy audio','embedded_scene':'same-version Godot loads embedded EXE pack from isolated directory','physical_cursor':'verified by native rendered feedback317 fixtures after user stopped moving mouse','fullscreen':'verified by viewport-1600 fixture'})
    STATUS.update(complete=True,running=None,finished=time.time())
    dump(OUT/'delivery-status.json',STATUS)
    print('AUDIO DELIVERY CHECKS COMPLETE',flush=True)

if __name__=='__main__':
    try:
        main()
    except BaseException as error:
        STATUS['error']=str(error)
        dump(OUT/'delivery-status.json',STATUS)
        raise
