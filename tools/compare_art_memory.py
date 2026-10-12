"""Like-for-like fresh native battle counters: approved Git source versus current art."""
from pathlib import Path
import subprocess,json,re,zipfile,io,shutil
root=Path(__file__).resolve().parents[1]
binary='D:/Antigravity/GodotGameProject/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe'
out=root/'artifacts/current/art'
current=root/'art_source/web_qa_project'; baseline=root/'art_source/memory_baseline_project'
shutil.copy2(root/'tests/art_web_qa.gd',current/'qa.gd')
archive=subprocess.check_output(['git','archive','--format=zip','c0b1236f6855e5f3b6256fda40add9ad2a516a81','scripts','assets/fonts','main.tscn','project.godot','icon.svg'],cwd=root)
baseline.mkdir(exist_ok=True)
assert baseline.resolve().is_relative_to((root/'art_source').resolve())
with zipfile.ZipFile(io.BytesIO(archive)) as z:
    for info in z.infolist(): assert (baseline/info.filename).resolve().is_relative_to(baseline.resolve())
    z.extractall(baseline)
for name in ['qa.gd','qa_profile.gd','qa.tscn']: shutil.copy2(current/name,baseline/name)
# The approved baseline predates the optional replay-model parameter.
profile=baseline/'qa_profile.gd'
profile.write_text(profile.read_text(encoding='utf-8').replace('_draw_enemy(enemy: Dictionary, model: RunModel = null)', '_draw_enemy(enemy: Dictionary)').replace('super._draw_enemy(enemy, model)','super._draw_enemy(enemy)'),encoding='utf-8')
config=(baseline/'project.godot').read_text(encoding='utf-8').replace('res://main.tscn','res://qa.tscn').replace('custom_user_dir_name="OrbitBreaker"','custom_user_dir_name="OrbitBreakerArtBaselineQA"')
(baseline/'project.godot').write_text(config,encoding='utf-8')
comparison={'baseline_commit':'c0b1236f6855e5f3b6256fda40add9ad2a516a81','scope':'fresh native requested window1600x900, logical viewport in results; same full physics/HUD/ghost fixture, warm60 + measured300 per trial, muted Dummy audio; Godot allocation counters, not whole-process RSS'}
for label,project in [('current',current),('baseline',baseline)]:
    imported=subprocess.run([binary,'--headless','--path',str(project),'--editor','--quit'],capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=120)
    assert imported.returncode==0 and 'ERROR:' not in imported.stderr
    run=subprocess.run([binary,'--path',str(project),'--audio-driver','Dummy','--resolution','1600x900','--quit-after','1600'],capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=120)
    (out/f'memory-{label}.log').write_text(run.stdout+run.stderr,encoding='utf-8')
    assert run.returncode==0 and 'ERROR:' not in run.stdout+run.stderr,label
    message=next(json.loads(line) for line in run.stdout.splitlines() if line.startswith('{') and 'orbit-art-web-stress' in line)
    assert all(t['elapsed_advanced'] and t['ghost_frames']>=25 for t in message['results'])
    comparison[label]=message['results']
    print(label,[(t['p95_ms'],t['texture_bytes'],t['static_memory_bytes']) for t in message['results']],flush=True)
(out/'memory-comparison.json').write_text(json.dumps(comparison,indent=2),encoding='utf-8')
