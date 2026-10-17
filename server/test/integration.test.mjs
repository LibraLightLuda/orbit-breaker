import {resolve,sep} from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {mkdtempSync,rmSync,readFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {createHash} from 'node:crypto';
import {PROTOCOL} from '../contract.mjs';
import {gunzipSync} from 'node:zlib';

function channel(url) {
 const socket=new WebSocket(url), messages=[], waiters=[];
 socket.addEventListener('message',event=>{const value=JSON.parse(event.data);messages.push(value);for(const waiter of [...waiters])if(waiter.predicate(value)){waiters.splice(waiters.indexOf(waiter),1);clearTimeout(waiter.timer);waiter.resolve(value);}});
 const next=(predicate,timeout=15_000)=>new Promise((resolve,reject)=>{const found=messages.find(predicate);if(found)return resolve(found);const waiter={predicate,resolve,timer:setTimeout(()=>{waiters.splice(waiters.indexOf(waiter),1);reject(new Error('message timeout'));},timeout)};waiters.push(waiter);});
 return {socket,next,messages,open:new Promise((resolve,reject)=>{socket.addEventListener('open',resolve,{once:true});socket.addEventListener('error',reject,{once:true});}),send:value=>socket.send(JSON.stringify(value))};
}
test('anonymous HTTP + two WebSocket clients against Godot + stored replay', {timeout:60_000}, async()=>{
 const directory=mkdtempSync(join(tmpdir(),'orbit-network-'));
 const processHandle=spawn(process.execPath,['server/gateway.mjs'],{env:{...process.env,ORBIT_PORT:'18788',ORBIT_DATA_DIR:directory,ORBIT_MATCH_SCRIPT:'res://server/test/match_fixture.gd',ORBIT_SITES_URL:'',ORBIT_BIND:'127.0.0.1',ORBIT_SHUTDOWN_SECONDS:'2',ORBIT_INTERNAL_KEY:'isolated-test-key',ORBIT_TRUST_PROXY:'loopback'},windowsHide:true,stdio:['ignore','pipe','pipe']});
 let logs='';processHandle.stdout.on('data',x=>logs+=x);processHandle.stderr.on('data',x=>logs+=x);
 const sockets=[];
 const api=async(path,value)=>{const response=await fetch('http://127.0.0.1:18788'+path,{method:value?'POST':'GET',headers:{'Content-Type':'application/json'},body:value?JSON.stringify(value):undefined});return {status:response.status,value:await response.json()};};
 try {
  for(let i=0;i<100&&!logs.includes('ORBIT_GATEWAY_READY');i++)await new Promise(resolve=>setTimeout(resolve,50));
  assert.match(logs,/ORBIT_GATEWAY_READY/);
  assert.equal((await api('/v1/config')).value.anonymous,true);
  assert.equal((await api('/v1/rankings',{run_id:'a'.repeat(32),nickname:'위조',score:999999})).status,404);
  assert.equal((await api('/internal/results',{score:999})).status,403);
  const invalid=await api('/v1/rooms',{mode:'coop',difficulty:'wrong',sector:'ring',ship:'scout'});assert.equal(invalid.status,400);
  const created=await api('/v1/rooms',{mode:'coop',difficulty:'normal',sector:'storm',ship:'striker',nickname:'웹'});
  assert.equal(created.status,201,JSON.stringify(created.value)+' '+logs);
  const joined=await api('/v1/rooms/join',{code:created.value.code});assert.equal(joined.status,200);
  const a=channel(created.value.websocket),b=channel(joined.value.websocket);sockets.push(a.socket,b.socket);
  await Promise.all([a.open,b.open]);
  a.send({type:'hello',protocol:PROTOCOL,nickname:'웹',ship:'striker'});b.send({type:'hello',protocol:PROTOCOL,nickname:'Windows',ship:'scout'});
  const [ha,hb]=await Promise.all([a.next(x=>x.type==='hello'),b.next(x=>x.type==='hello')]);assert.notEqual(ha.slot,hb.slot);
  a.send({type:'ready',ready:true});b.send({type:'ready',ready:true});
  await Promise.all([a.next(x=>x.type==='begin'),b.next(x=>x.type==='begin')]);
  const offer=await a.next(value=>value.type==='state'&&value.state==='upgrade');
  for(const revision of [-1,offer.choice_revision+0.5]){
   a.send({type:'choice',id:offer.choices[0],revision});
   await new Promise(resolve=>setTimeout(resolve,150));
   assert.equal(a.messages.filter(value=>value.type==='state').at(-1).state,'upgrade','invalid revision cannot consume a card');
  }
  a.send({type:'choice',id:offer.choices[0],revision:offer.choice_revision});
  a.send({type:'input',seq:1,move:[-1,0],aim:[-1,0],dash:true});b.send({type:'input',seq:1,move:[1,0],aim:[1,0],dash:true});
  const state=await a.next(x=>x.type==='state'&&x.tick>15);
  assert.equal(state.players.length,2);assert.ok(state.players[0].position[0]<state.players[1].position[0]);
  b.socket.close();await a.next(x=>x.type==='status'&&x.phase==='reconnecting');
  const resumed=channel(created.value.websocket);sockets.push(resumed.socket);await resumed.open;
  resumed.send({type:'hello',protocol:PROTOCOL,resume:hb.resume});
  assert.equal((await resumed.next(x=>x.type==='hello')).slot,hb.slot);
  await resumed.next(x=>x.type==='begin');
  const finished=await a.next(x=>x.type==='result');assert.equal(finished.result.mode,'coop');
  const late=channel(created.value.websocket);sockets.push(late.socket);await late.open;
  late.send({type:'hello',protocol:PROTOCOL,resume:ha.resume});
  assert.equal((await late.next(x=>x.type==='result')).result.id,finished.result.id,'F3 ended reconnect resends the persisted result');
  assert.equal((await api(`/v1/runs/${finished.result.id}`)).status,200,'F3 HTTP recovery survives a lost result message');
  assert.ok(a.messages.filter(value=>value.type==='state'&&value.phase==='playing'&&value.tick>0).length>=36,'two-second fixture delivers the configured 20Hz snapshots');
  let row;
  for(let i=0;i<30;i++){row=await api('/v1/rankings',{run_id:finished.result.id,nickname:'익명 편대'});if(row.status===200)break;await new Promise(resolve=>setTimeout(resolve,100));}
  assert.equal(row.status,200,JSON.stringify(row)+' '+logs);assert.equal(row.value.verification,'server');
  const rankings=await api('/v1/rankings?mode=coop&difficulty=normal&sector=storm');assert.equal(rankings.value.items[0].nickname,'익명 편대');
  const manifest=await api(`/v1/replays/${row.value.id}/manifest`);assert.equal(manifest.value.status,'complete');
  const chunk=Buffer.from(await (await fetch(`http://127.0.0.1:18788/v1/replays/${row.value.id}/0.json.gz`)).arrayBuffer());
  assert.equal(createHash('sha256').update(chunk).digest('hex'),manifest.value.chunks[0].sha256);
  assert.ok(JSON.parse(gunzipSync(chunk)).frames.length>=10,'two-second fixture records the configured 5Hz ghost samples');
  assert.equal((await api('/internal/drain',{})).status,403);
  const drained=await fetch('http://127.0.0.1:18788/internal/drain',{method:'POST',headers:{'X-Orbit-Key':'isolated-test-key'}});assert.equal(drained.status,200);
  assert.equal((await api('/v1/config')).value.draining,true);
  assert.equal((await api('/v1/rooms',{mode:'solo',difficulty:'normal',sector:'ring',ship:'striker'})).status,503);
  for(let i=0;i<240;i++)assert.equal((await fetch('http://127.0.0.1:18788/v1/config',{headers:{'X-Orbit-Client-IP':'203.0.113.11'}})).status,200);
  assert.equal((await fetch('http://127.0.0.1:18788/v1/config',{headers:{'X-Orbit-Client-IP':'203.0.113.11'}})).status,429);
  assert.equal((await fetch('http://127.0.0.1:18788/v1/config',{headers:{'X-Orbit-Client-IP':'203.0.113.12'}})).status,200,'another visitor is not blocked by the proxy IP quota');
  assert.doesNotMatch(logs,/SCRIPT ERROR|Parse Error|ERROR:/,logs);
 } finally {
  for(const socket of sockets)socket.close();
  const exited=new Promise(resolve=>processHandle.once('exit',resolve));processHandle.kill();await exited;
  assert.ok(resolve(directory).startsWith(resolve(tmpdir())+sep));rmSync(directory,{recursive:true,force:true,maxRetries:10,retryDelay:100});
 }
});
