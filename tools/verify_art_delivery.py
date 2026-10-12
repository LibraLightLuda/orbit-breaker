"""Check the delivered generation and refresh its file inventory; never rebuild or promote."""
from pathlib import Path
import hashlib,json,subprocess

root=Path(__file__).resolve().parents[1]
def data(p): return json.loads((root/p).read_text(encoding='utf-8-sig'))
def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest().upper()
def dump(p,o): (root/p).write_text(json.dumps(o,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

assert sorted(p.name for p in (root/'build').iterdir() if p.is_dir())==['current']
assert sorted(p.name for p in (root/'artifacts').iterdir() if p.is_dir())==['candidate','current']
assert sorted(p.name for p in (root/'artifacts/candidate').iterdir())==['art']
v=data('artifacts/current/verification.json')
assert v['promotion']=='local-current' and v['local_validation_complete']
for p,h in data('artifacts/current/production-source-hashes.json').items(): assert digest(root/p)==h.upper(),p
for p,h in data('artifacts/current/release-hashes.json').items(): assert digest(root/'build/current'/p)==h.upper(),p
for p in (root/'build/current/web').iterdir():
    if p.is_file(): assert p.read_bytes()==(root/'web'/p.name).read_bytes(),p.name
protected=0
allowed={'main.gd','item_catalog.gd','item_icon.gd','ui_glyph.gd','export_presets.cfg','project.godot','test_viewport.gd','menu_flow.gd','test_uiux.gd'}
for p in data('art_source/baseline/hashes.json'):
    if Path(p['Path']).name in allowed: continue
    assert digest(Path(p['Path']))==p['Hash'].upper(),p['Path']
    protected+=1
assert protected==v['protected_hashes']==59
rows=data('art_source/worklist.json'); manifest=data('art_source/asset-manifest.json')
assert len(rows)==v['matrix_rows']==125 and len(manifest)==v['art_resources']==95
for p in manifest.values(): assert (root/p.removeprefix('res://')).is_file(),p
for r in rows:
    assert r['status']=='implemented-render-verified',r['target']
    for p in r['evidence']: assert (root/p).is_file(),p
auto=data('artifacts/current/automated-results.json'); render=data('artifacts/current/render-results.json')
assert len(auto)==v['automated_groups']==20 and sum(t['passed'] for t in auto)==v['automated_passed']==2546
assert all(t['passed']==t['total'] for t in auto)
assert len(render)==v['render_cases']==16 and sum(t['passed'] for t in render)==v['render_passed']==2532
for trials in [v['windows_performance'],v['web_performance']]:
    assert len(trials)==3 and all(t['p95_ms']<=16.7 and t['p99_ms']<=25 for t in trials)
assert all(t['elapsed_advanced'] and t['ghost_frames']>=30 for t in v['web_performance'])
assert sum(t['over_33_3ms'] for t in v['web_performance'])==1
assert data('artifacts/current/art/runtime-status.json')['complete']
assert data('artifacts/current/art/native-release-final.json')['profile_unchanged']
assert data('artifacts/current/retention-status.json')['local_release_cleanup_complete']
for p in (root/'docs').glob('ART_*.md'):
    p.write_text(p.read_text(encoding='utf-8').rstrip()+'\n',encoding='utf-8')
for p in ['docs/VALIDATION_V3.md','docs/SURVIVAL_V3.md']:
    q=root/p; q.write_text(q.read_text(encoding='utf-8').rstrip()+'\n',encoding='utf-8')
(root/'web/.gdignore').write_bytes(subprocess.check_output(['git','show','HEAD:web/.gdignore'],cwd=root))
check=subprocess.run(['git','diff','--check'],cwd=root,capture_output=True,text=True)
assert check.returncode==0,check.stdout+check.stderr
dump('artifacts/current/art/delivery-check.json',{'passed':True,'protected_hashes':protected,'matrix_rows':len(rows),'art_resources':len(manifest),'release_hashes_match':True,'production_hashes_match':True,'web_copy_matches':True,'single_verified_release_generation':True,'temporary_cleanup_complete':False,'cleanup_status':'blocked by policy; candidate/art and two scratch QA projects remain; no candidate executable','git_diff_check':True,'generation':v['generation']})
inventory=[]
for folder in ['build/current','artifacts/current']:
    for p in sorted((root/folder).rglob('*')):
        if p.is_file() and p.name!='file-inventory.json':
            inventory.append({'path':p.relative_to(root).as_posix(),'bytes':p.stat().st_size,'sha256':digest(p)})
dump('artifacts/current/file-inventory.json',{'generation':v['generation'],'excludes_self':True,'files':inventory})
print(f'Delivery verified: {len(rows)} rows, {len(manifest)} art assets, {protected} protected hashes, {len(inventory)} inventoried files; one verified release, supplemental QA cleanup blocked by policy.')
