import hashlib,json,subprocess,pathlib,datetime
root=pathlib.Path(r'D:\Antigravity\NewProject'); out=root/'docs/audits/online-20261016'
paths=subprocess.check_output(['git','ls-files','--cached','--others','--exclude-standard'],cwd=root,text=True).splitlines()
hashes={p:hashlib.sha256((root/p).read_bytes()).hexdigest() for p in paths if (root/p).is_file() and not p.startswith('docs/audits/online-20261016')}
(out/'baseline.json').write_text(json.dumps({'time':datetime.datetime.now().isoformat(),'head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),'files':hashes},indent=2),encoding='utf-8')
godot=r'D:\Antigravity\GodotGameProject\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe'
tests=['online_world','online_ui','online_history','online_life','online_damage','online_choices','online_replay','online_practice','online_soak','model','survival','combat_expansion','replay_world','progression']
results=[]
for label,cmd in [('node',['node','--test','server/test/*.test.mjs'])]+[(t,[godot,'--headless','--path',str(root),'--script',f'res://tests/test_{t}.gd']) for t in tests]:
 try:
  p=subprocess.run(cmd,cwd=root,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,encoding='utf-8',errors='replace',timeout=150)
  log=p.stdout; code=p.returncode
 except subprocess.TimeoutExpired as e: log=str(e.output); code='timeout'
 (out/(label+'.log')).write_text(log,encoding='utf-8')
 bad=any(x in log for x in ['SCRIPT ERROR','Parse Error','Assertion failed'])
 results.append({'test':label,'exit':code,'runtime_error':bad,'tail':log.splitlines()[-4:]})
 print(json.dumps(results[-1],ensure_ascii=True),flush=True)
(out/'suite-results.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf-8')

