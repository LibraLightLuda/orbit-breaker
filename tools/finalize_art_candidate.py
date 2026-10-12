"""Revalidate the final compact-menu correction without repeating unchanged rule simulations."""
from pathlib import Path
import subprocess,re,json
root=Path(__file__).resolve().parents[1]
art=root/'artifacts/candidate/art'
binary='D:/Antigravity/GodotGameProject/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe'
def run(name,args,log,pattern=None,timeout=180):
    print(name,flush=True)
    with (art/log).open('w',encoding='utf-8') as f:
        result=subprocess.run(args,cwd=root,stdout=f,stderr=subprocess.STDOUT,timeout=timeout)
    text=(art/log).read_text(encoding='utf-8',errors='replace')
    assert result.returncode==0 and not re.search(r'(?im)\b(?:SCRIPT ERROR|ERROR|Parse Error):',text),log
    if pattern: assert re.search(pattern,text),log
    return text
run('Import final source',[binary,'--headless','--path',str(root),'--editor','--quit'],'final-import.log')
for script,tag in [('test_ui','UI'),('test_uiux','UIUX'),('test_art','ART')]:
    args=[binary,'--headless','--path',str(root),'--script',f'res://tests/{script}.gd']
    if script=='test_uiux': args+=['--','--stage=6']
    run('Headless '+script,args,f'final-{script}.log',tag+r' SELF-CHECK: (\d+) / \1 assertions passed')
for preset,target in [('Windows Desktop','build/candidate/OrbitBreaker.exe'),('Web','build/candidate/web/index.html')]:
    run('Export '+preset,[binary,'--headless','--path',str(root),'--export-release',preset,str(root/target)],'final-export-'+preset.split()[0]+'.log')
run('Final Windows release',[str(root/'build/candidate/OrbitBreaker.exe'),'--audio-driver','Dummy','--quit-after','180'],'native-release.log')
run('Final native title capture',[str(root/'build/candidate/OrbitBreaker.exe'),'--audio-driver','Dummy','--resolution','1600x900','--quit-after','3','--write-movie',str(art/'native-title.png')],'native-movie.log')
run('Native input regression',[binary,'--path',str(root),'--audio-driver','Dummy','--resolution','1600x900','--script','res://tests/art_release_input.gd'],'release-input.log',r'RELEASE INPUT SELF-CHECK: (\d+) / \1 assertions passed')
run('All render regressions',['powershell','-NoProfile','-ExecutionPolicy','Bypass','-File','tools/verify_uiux.ps1'],'final-render.log','All rendering fixtures passed',300)
run('Art and isolated moving performance',['powershell','-NoProfile','-ExecutionPolicy','Bypass','-File','tools/verify_art.ps1'],'verification.log','three moving performance trials passed')
run('Same-source Web QA export',['python','tools/build_art_web_qa.py'],'web-qa-export.log','Local QA Web export complete')
(art/'final-correction-status.json').write_text(json.dumps({'complete':True,'scope':'compact real upgrade cards, readable nested links, card/selection pairing; combat/model/replay unchanged; prior ten-minute soak retained','steps':'import, 3 headless groups, 2 exports, release180, native3 capture, native input, 16 render cases, art/moving performance, Web QA export'},indent=2),encoding='utf-8')
print('Final compact correction and candidate validated; Web QA browser result remains separate.',flush=True)
