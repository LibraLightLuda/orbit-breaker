"""A/B only the hull in an isolated copy; never replace production art."""
from pathlib import Path
import shutil, subprocess
root=Path(__file__).resolve().parents[1]
qa=root/'art_source/web_qa_project'
binary='D:/Antigravity/GodotGameProject/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe'
shutil.copy2(root/'tests/art_combat_fixture.gd',qa/'combat_fixture.gd')
target=qa/'assets/art/ships/striker.png'
try:
    for method,source in [('imagegen',root/'assets/art/ships/striker.png'),('blender',root/'art_source/comparison/striker_blender.png')]:
        shutil.copy2(source,target)
        subprocess.run([binary,'--headless','--path',str(qa),'--editor','--quit'],check=True)
        result=subprocess.run([binary,'--path',str(qa),'--audio-driver','Dummy','--resolution','1600x900','--script','res://combat_fixture.gd','--',str(root/f'artifacts/candidate/art/combat-comparison-{method}.png')],capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=60)
        print(result.stdout,result.stderr)
        assert result.returncode==0 and 'ERROR:' not in result.stderr
finally:
    shutil.copy2(root/'assets/art/ships/striker.png',target)
assert target.read_bytes()==(root/'assets/art/ships/striker.png').read_bytes()
