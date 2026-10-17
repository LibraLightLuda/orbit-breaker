import {test} from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import {readFileSync,mkdtempSync,writeFileSync,mkdirSync,utimesSync,rmSync} from 'node:fs';
import {createHmac,createHash} from 'node:crypto';
import {tmpdir} from 'node:os';
import {join,resolve,sep} from 'node:path';
import {spawn} from 'node:child_process';
import http from 'node:http';
import {records} from '../ranking/lib/records.mjs';
import {result} from '../contract.mjs';

function fixture(){
 const db=new DatabaseSync(':memory:');db.exec(readFileSync(new URL('../schema.sql',import.meta.url),'utf8'));
 const DB={prepare(sql){return {bind(...params){return {async first(){return db.prepare(sql).get(...params)||null;},async all(){return {results:db.prepare(sql).all(...params)};},async run(){db.prepare(sql).run(...params);return {success:true};}};}};}};
 const objects=new Map();const BUCKET={async list({prefix}){return {objects:[...objects.keys()].filter(key=>key.startsWith(prefix)).map(key=>({key,uploaded:new Date()})),truncated:false};},async put(key,value){objects.set(key,Buffer.from(value));},async get(key){const bytes=objects.get(key);return bytes?{size:bytes.length,body:new Blob([bytes]).stream(),arrayBuffer:async()=>bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),text:async()=>bytes.toString(),json:async()=>JSON.parse(bytes)}:null;},async delete(key){objects.delete(key);}};
 return {env:{DB,BUCKET,RECORDS_SERVER_KEY:'test-only-key'},db,objects};
}
function sample(){const now=new Date().toISOString();return result({id:'b'.repeat(32),nickname:'파일럿',score:17,ticks:120,mode:'solo',difficulty:'normal',sector:'ring',ships:['striker'],rules:'online-solo-v1',started_at:now,finished_at:now,replay:{version:1,status:'pending',chunks:[]}});}
async function request(handler,path,value){const content=value instanceof Uint8Array?value:JSON.stringify(value),timestamp=String(Date.now());const headers=value===undefined?{}:{'X-Orbit-Timestamp':timestamp,'X-Orbit-Signature':createHmac('sha256','test-only-key').update(`${timestamp}\n${path}\n`).update(content).digest('hex')};return handler[value===undefined?'GET':'POST'](new Request('https://candidate.chatgpt.site'+path,{method:value===undefined?'GET':'POST',headers,body:content}));}

test('Sites preserves score independently, verifies ghost bytes, and supports global result/replay reads',async()=>{
 const f=fixture(),handler=records(f.env),value=sample();
 try{
  assert.equal((await request(handler,'/internal/results',value)).status,200);
  assert.equal((await request(handler,`/v1/runs/${value.id}`)).status,200);
  assert.equal((await request(handler,'/internal/results',{...value,score:18})).status,409);
  const bytes=Buffer.from('verified ghost'),replay={version:1,status:'complete',chunks:[{bytes:bytes.length,sha256:createHash('sha256').update(bytes).digest('hex'),start:0,end:2}]};
  assert.equal(result({...value,replay}).result_hash,value.result_hash,'mutable replay is outside immutable result hash');
  assert.equal((await request(handler,'/internal/replay-state',{...value,replay})).status,409,'missing chunk cannot complete');
  assert.equal((await request(handler,`/internal/replays/${value.id}/0.json.gz`,Buffer.from('wrong bytes'))).status,200);
  assert.equal((await request(handler,'/internal/replay-state',{...value,replay})).status,409);
  await request(handler,`/internal/replays/${value.id}/0.json.gz`,bytes);
  assert.equal((await request(handler,'/internal/replay-state',{...value,replay})).status,200);
  assert.equal((await request(handler,'/internal/replay-state',{...value,replay:{status:'pending'}})).status,200);
  assert.equal((await (await request(handler,`/v1/replays/${value.id}/manifest`)).json()).status,'complete');
  assert.equal(Buffer.from(await (await request(handler,`/v1/replays/${value.id}/0.json.gz`)).arrayBuffer()).toString(),bytes.toString());
  const own=new Request('https://candidate.chatgpt.site/v1/config',{headers:{Origin:'https://candidate.chatgpt.site'}});
  assert.equal((await handler.GET(own)).status,200);
  assert.equal((await handler.GET(new Request(own.url,{headers:{Origin:'https://evil.example'}}))).status,403);
  assert.equal((await handler.POST(new Request('https://candidate.chatgpt.site/internal/results',{method:'POST',body:JSON.stringify(value)}))).status,403);
 }finally{f.db.close();}
});

test('gateway mirrors a score before a broken ghost, reads global data with an empty local DB, and reclaims old orphans', {timeout:25000},async()=>{
 const f=fixture(),handler=records(f.env),directory=mkdtempSync(join(tmpdir(),'orbit-sites-fixes-'));
 const upstream=http.createServer(async(req,res)=>{try{const chunks=[];for await(const x of req)chunks.push(x);const url='https://candidate.chatgpt.site'+req.url;const response=await handler[req.method](new Request(url,{method:req.method,headers:req.headers,body:req.method==='POST'?Buffer.concat(chunks):undefined}));res.writeHead(response.status,Object.fromEntries(response.headers));res.end(Buffer.from(await response.arrayBuffer()));}catch(e){res.writeHead(500);res.end(String(e));}});
 await new Promise(yes=>upstream.listen(0,'127.0.0.1',yes));
 const value=sample();value.replay={status:'complete',chunks:[{bytes:8,sha256:'a'.repeat(64),start:0,end:2}]};
 writeFileSync(join(directory,value.id+'.result.json'),JSON.stringify(value));
 const orphan=join(directory,'c'.repeat(32)+'.replay');mkdirSync(orphan);writeFileSync(join(orphan,'0.json.gz'),'orphan');utimesSync(orphan,new Date(0),new Date(0));
 const child=spawn(process.execPath,['server/gateway.mjs'],{windowsHide:true,env:{...process.env,ORBIT_DATA_DIR:directory,ORBIT_PORT:'18789',ORBIT_BIND:'127.0.0.1',ORBIT_SITES_URL:`http://127.0.0.1:${upstream.address().port}`,ORBIT_SITES_KEY:'test-only-key',ORBIT_MAX_REPLAY_GB:String(64/1024**3),ORBIT_SHUTDOWN_SECONDS:'1'},stdio:['ignore','pipe','pipe']});let logs='';child.stdout.on('data',x=>logs+=x);child.stderr.on('data',x=>logs+=x);
 try{
  for(let i=0;i<100&&!logs.includes('ORBIT_GATEWAY_READY');i++)await new Promise(yes=>setTimeout(yes,50));
  assert.match(logs,/ORBIT_GATEWAY_READY/,logs);
  const global=await (await request(handler,`/v1/runs/${value.id}`)).json();assert.equal(global.score,17);assert.equal(global.replay.status,'failed');
  const ghostless=sample();ghostless.id='d'.repeat(32);await request(handler,'/internal/results',ghostless);
  const remote=await fetch(`http://127.0.0.1:18789/v1/runs/${ghostless.id}`);assert.equal(remote.status,200,'F5 empty local DB reads Sites');
  const {existsSync}=await import('node:fs');assert.equal(existsSync(orphan),false,'F6 old orphan reclaimed');
  assert.doesNotMatch(logs,/Result retained for retry/,'F4 missing local ghost must terminate as failed without losing score');
 }finally{const exited=new Promise(yes=>child.once('exit',yes));child.kill();await exited;await new Promise(yes=>upstream.close(yes));f.db.close();assert.ok(resolve(directory).startsWith(resolve(tmpdir())+sep));rmSync(directory,{recursive:true,force:true,maxRetries:10,retryDelay:100});}
});

test('game assets commit only verified parts and stream the original WASM bytes',async()=>{
 const f=fixture(),handler=records(f.env),release='e'.repeat(64),files={};
 try{
  for(const file of ['index.html','index.js','index.wasm','index.pck']){
   const bytes=Buffer.from(file),sha256=createHash('sha256').update(bytes).digest('hex');
   files[file]={bytes:bytes.length,sha256,parts:[{bytes:bytes.length,sha256}]};
   await request(handler,`/internal/game-assets/${release}/${file}/0`,bytes);
  }
  const broken=structuredClone(files);broken['index.wasm'].parts[0].sha256='0'.repeat(64);
  assert.equal((await request(handler,'/internal/game-release',{release,files:broken})).status,409);
  assert.equal((await request(handler,'/internal/game-release',{release,files})).status,200);
  const response=await handler.GET(new Request('https://candidate.chatgpt.site/game/index.wasm'));
  assert.equal(response.headers.get('content-type'),'application/wasm');assert.equal(await response.text(),'index.wasm');
  assert.equal((await request(handler,'/internal/game-retention',{release})).status,409,'active release is protected');
  const old='f'.repeat(64);await f.env.BUCKET.put(`game/${old}/index.wasm/0`,Buffer.from('old'));
  assert.equal((await (await request(handler,'/internal/game-retention',{release:old})).json()).deleted,1);
  assert.equal((await handler.GET(new Request('https://candidate.chatgpt.site/game/../secret'))).status,404);
 }finally{f.db.close();}
});
