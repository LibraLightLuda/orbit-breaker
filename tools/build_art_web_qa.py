"""Build a local-only Web stress entry using byte-identical production scripts/assets."""
from pathlib import Path
import shutil, subprocess, hashlib, json
root=Path(__file__).resolve().parents[1]
qa=root/'artifacts/clarity-work/web-project'; qa.mkdir(exist_ok=True,parents=True)
for folder in ['assets','scripts']: shutil.copytree(root/folder,qa/folder,dirs_exist_ok=True)
shutil.copy2(root/'main.tscn',qa/'main.tscn')
shutil.copy2(root/'icon.svg',qa/'icon.svg')
shutil.copy2(root/'export_presets.cfg',qa/'export_presets.cfg')
(qa/'tools').mkdir(exist_ok=True)
shutil.copy2(root/'tools/web_shell.html',qa/'tools/web_shell.html')
shutil.copy2(root/'tests/art_web_qa.gd',qa/'qa.gd')
shutil.copy2(root/'tests/art_web_profile.gd',qa/'qa_profile.gd')
(qa/'qa.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://qa.gd" id="1"]\n[node name="ArtWebQA" type="Node"]\nscript=ExtResource("1")\n',encoding='utf-8')
config=(root/'project.godot').read_text(encoding='utf-8').replace('res://main.tscn','res://qa.tscn').replace('custom_user_dir_name="OrbitBreaker"','custom_user_dir_name="OrbitBreakerClarityQA"')
(qa/'project.godot').write_text(config,encoding='utf-8')
binary='D:/Antigravity/GodotGameProject/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe'
out=root/'artifacts/clarity-work/web-stress'; out.mkdir(exist_ok=True,parents=True)
manifest={}
for folder in ['scripts','assets']:
    for p in (root/folder).rglob('*'):
        if p.is_file():
            q=qa/p.relative_to(root)
            assert p.read_bytes()==q.read_bytes(),str(p)
            manifest[p.relative_to(root).as_posix()]=hashlib.sha256(p.read_bytes()).hexdigest()
(out/'source-equality.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
for args in [['--editor','--quit'],['--export-release','Web',str(out/'index.html')]]:
    run=subprocess.run([binary,'--headless','--path',str(qa),*args],capture_output=True,text=True,encoding='utf-8',errors='replace')
    print(run.stdout); print(run.stderr)
    assert run.returncode==0 and 'SCRIPT ERROR:' not in run.stdout+run.stderr and 'Parse Error:' not in run.stdout+run.stderr
print('Local QA Web export complete; product main scene and profile remain unchanged.')
html=out/'index.html'
text=html.read_text(encoding='utf-8')
needle='const ratio = window.orbitMobile ? 1 : Math.min(devicePixelRatio || 1, 2);'
assert needle in text
text=text.replace(needle,"const ratio = Number(new URLSearchParams(location.search).get('qa_dpr')) || (window.orbitMobile ? 1 : Math.min(devicePixelRatio || 1, 2));")
html.write_text(text,encoding='utf-8')
