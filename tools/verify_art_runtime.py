"""Final render regression, real exported launch, and native input/10-minute soak."""
from pathlib import Path
import subprocess, hashlib, json, re
root=Path(__file__).resolve().parents[1]
art=root/'artifacts/candidate/art'
profile=Path.home()/'AppData/Roaming/OrbitBreaker/profile'
def hashes():
    return {p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in profile.glob('*') if p.is_file()}
before=hashes()
status_path=art/'runtime-status.json'
status=json.loads(status_path.read_text(encoding='utf-8')) if status_path.exists() else {'steps':[],'profile_unchanged':None,'complete':False}
sources={p.relative_to(root).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in list((root/'scripts').glob('*.gd'))+[root/'project.godot',root/'export_presets.cfg']}
if 'source_hashes' in status and status['source_hashes']!=sources:
    raise RuntimeError('Production source changed; invalidate affected completed steps before resuming this checkpoint.')
status['source_hashes']=sources
status.pop('error',None)
def save(): (art/'runtime-status.json').write_text(json.dumps(status,indent=2),encoding='utf-8')
def run(name,args,log,timeout,pattern=None):
    if any(step['name']==name and step['exit']==0 for step in status['steps']):
        print('Preserving completed '+name,flush=True)
        return
    status['running']=name; save(); print('Running '+name,flush=True)
    with (root/log).open('w',encoding='utf-8') as output:
        result=subprocess.run(args,cwd=root,stdout=output,stderr=subprocess.STDOUT,timeout=timeout)
    text=(root/log).read_text(encoding='utf-8',errors='replace')
    assert result.returncode==0 and not re.search(r'(?im)\b(?:SCRIPT ERROR|ERROR|Parse Error):',text),name+' failed: '+log
    if pattern: assert re.search(pattern,text),name+' missing success: '+log
    status['steps'].append({'name':name,'exit':result.returncode,'log':log}); save()
try:
    run('render regressions',['powershell','-NoProfile','-ExecutionPolicy','Bypass','-File','tools/verify_uiux.ps1'],'artifacts/candidate/render-art.log',300,'All rendering fixtures passed')
    run('exported Windows 180 frames',[str(root/'build/candidate/OrbitBreaker.exe'),'--audio-driver','Dummy','--quit-after','180'],'artifacts/candidate/art/native-release.log',60)
    binary='D:/Antigravity/GodotGameProject/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe'
    run('native input and ten minute soak',[binary,'--path',str(root),'--audio-driver','Dummy','--resolution','1600x900','--script','res://tests/art_release_input.gd','--','--soak'],'artifacts/candidate/art/release-input.log',900,r'RELEASE INPUT SELF-CHECK: (\d+) / \1 assertions passed')
    status['profile_unchanged']=hashes()==before
    assert status['profile_unchanged'],'Player profile changed unexpectedly; preserve evidence and investigate.'
    status['complete']=True
except Exception as error:
    status['error']=str(error)
    raise
finally:
    status['profile_unchanged']=hashes()==before
    status.pop('running',None); save()
