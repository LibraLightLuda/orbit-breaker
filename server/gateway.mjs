import http from 'node:http';
import net from 'node:net';
import {spawn} from 'node:child_process';
import {createReadStream} from 'node:fs';
import {randomBytes,createHmac,timingSafeEqual,createHash} from 'node:crypto';
import {mkdir,readFile,readdir,rename,writeFile,stat,rm} from 'node:fs/promises';
import {resolve,join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {Store} from './store.mjs';
import {PROTOCOL,RULES,roomOptions,result,RUN_ID} from './contract.mjs';

const root = resolve(fileURLToPath(new URL('..',import.meta.url)));
const directory = resolve(process.env.ORBIT_DATA_DIR || join(root,'server','data'));
await mkdir(directory,{recursive:true});
const store = new Store(directory);
const secret = process.env.ORBIT_INTERNAL_KEY || randomBytes(32).toString('hex');
const host = process.env.ORBIT_BIND || '127.0.0.1';
const port = Number(process.env.ORBIT_PORT || 8788);
const publicBase = process.env.ORBIT_PUBLIC_URL || `http://127.0.0.1:${port}`;
if(publicBase.startsWith('https:')&&!process.env.ORBIT_INTERNAL_KEY)throw new Error('Public service requires ORBIT_INTERNAL_KEY');
const maxRooms = Math.min(32,Math.max(1,Number(process.env.ORBIT_MAX_ROOMS || 2)));
const godot = process.env.ORBIT_GODOT || (process.platform==='win32'?'D:\\Antigravity\\GodotGameProject\\Godot_v4.7.1-stable_win64.exe\\Godot_v4.7.1-stable_win64_console.exe':'godot');
const origins = new Set((process.env.ORBIT_ALLOWED_ORIGINS || 'https://libralightluda.github.io,http://127.0.0.1:8060,http://localhost:8060,http://127.0.0.1:8788,http://localhost:8788').split(','));
origins.add(new URL(publicBase).origin);
const rooms = new Map(), limits = new Map();
let closing = false;
let flushing = false;
let storageBytes=0,maintenanceAt=0,maintaining=false;
const storageLimit=Number(process.env.ORBIT_MAX_REPLAY_GB||10)*1024**3;

function send(response,status,value) {
  response.writeHead(status,{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store','X-Content-Type-Options':'nosniff'});
  response.end(JSON.stringify(value));
}
async function body(request,maximum=8192) {
  const chunks=[]; let count=0;
  for await (const chunk of request) { count+=chunk.length; if(count>maximum) throw Object.assign(new Error('request too large'),{status:413}); chunks.push(chunk); }
  try { return JSON.parse(Buffer.concat(chunks).toString('utf8')); } catch { throw Object.assign(new Error('invalid JSON'),{status:400}); }
}
function allowedSecret(request) {
  const actual = Buffer.from(String(request.headers['x-orbit-key']||'')), expected=Buffer.from(secret);
  return actual.length===expected.length && timingSafeEqual(actual,expected);
}
function rate(key,maximum) {
  const now=Date.now(); let value=limits.get(key);
  if(!value || value.until<=now) { value={count:0,until:now+60_000}; limits.set(key,value); }
  return ++value.count<=maximum;
}
function clientAddress(request){
  const peer=request.socket.remoteAddress,forwarded=request.headers['x-orbit-client-ip'];
  return process.env.ORBIT_TRUST_PROXY==='loopback'&&['127.0.0.1','::1','::ffff:127.0.0.1'].includes(peer)&&typeof forwarded==='string'&&net.isIP(forwarded)?forwarded:peer;
}
async function mirror(path,value,raw=false) {
  if(!process.env.ORBIT_SITES_URL) return;
  if(!process.env.ORBIT_SITES_KEY) throw new Error('Sites server key missing');
  const content=raw?value:JSON.stringify(value), timestamp=String(Date.now());
  const signature=createHmac('sha256',process.env.ORBIT_SITES_KEY).update(`${timestamp}\n${path}\n`).update(content).digest('hex');
  const response=await fetch(new URL(path,process.env.ORBIT_SITES_URL),{method:'POST',headers:{'Content-Type':raw?'application/octet-stream':'application/json','X-Orbit-Timestamp':timestamp,'X-Orbit-Signature':signature},body:content,signal:AbortSignal.timeout(10_000)});
  if(!response.ok) throw new Error(`Sites storage returned ${response.status}`);
  return response.json();
}
async function flushResults() {
  if(flushing)return;
  flushing=true;
  try {
  for(const name of await readdir(directory)) {
    if(!/^[a-f0-9]{32}\.result\.json$/.test(name)) continue;
    try {
      const value=result(JSON.parse(await readFile(join(directory,name),'utf8')));
      store.save(value);
      const accepted=await mirror('/internal/results',{...value,replay:{...value.replay,status:value.replay.status==='complete'?'pending':value.replay.status}});
      if(process.env.ORBIT_SITES_URL && value.replay.status==='complete'){
        let missing=false;
        for(let index=0;index<value.replay.chunks.length;index++){
          let bytes;
          try {bytes=await readFile(join(directory,`${value.id}.replay`,`${index}.json.gz`));} catch(error) {if(error.code!=='ENOENT')throw error;missing=true;break;}
          if(bytes.length!==value.replay.chunks[index].bytes || bytes.length>1048576 || createHash('sha256').update(bytes).digest('hex')!==value.replay.chunks[index].sha256){missing=true;break;}
          await mirror(`/internal/replays/${value.id}/${index}.json.gz`,bytes,true);
        }
        const replay={...value.replay,status:missing?'failed':'complete'};
        await mirror('/internal/replay-state',{id:value.id,result_hash:accepted.result_hash||value.result_hash,replay});
        store.replayState(value.id,replay);
      }
      const row=store.get(value.id);
      if(row.published) await mirror('/internal/publish',{id:value.id,nickname:row.nickname});
      await rename(join(directory,name),join(directory,name.replace('.result.json','.saved.json')));
    } catch(error) { console.error('Result retained for retry:',name,error.message); }
  }
  } finally {flushing=false;}
}
async function maintenance() {
  if(maintaining||Date.now()<maintenanceAt)return;
  maintaining=true;maintenanceAt=Date.now()+60_000;
  try{
    for(const row of store.expiredReplays()){
      if(await stat(join(directory,`${row.id}.result.json`)).then(()=>true,()=>false))continue;
      await rm(join(directory,`${row.id}.replay`),{recursive:true,force:true});
      store.expireReplay(row.id);
    }
    storageBytes=0;
    for(const entry of await readdir(directory,{withFileTypes:true})){
      if(entry.isDirectory()&&/^[a-f0-9]{32}\.replay$/.test(entry.name)){
        const id=entry.name.slice(0,32),row=store.get(id);
        const protectedRun=[...rooms.values()].some(room=>room.id===id)||await stat(join(directory,`${id}.result.json`)).then(()=>true,()=>false);
        if(!protectedRun && (!row||row.replay.status==='failed') && (await stat(join(directory,entry.name))).mtimeMs<Date.now()-Number(process.env.ORBIT_ORPHAN_GRACE_MS||86400000)){
          await rm(join(directory,entry.name),{recursive:true,force:true});continue;
        }
        for(const chunk of await readdir(join(directory,entry.name)))if(/^\d{1,3}\.json\.gz$/.test(chunk))storageBytes+=(await stat(join(directory,entry.name,chunk))).size;
      }
      if(entry.isFile()&&/^[a-f0-9]{32}\.(saved\.json|publish\.json\.saved)$/.test(entry.name)&&(await stat(join(directory,entry.name))).mtimeMs<Date.now()-7*86400000)await rm(join(directory,entry.name));
    }
    await mirror('/internal/retention',{});
  }catch(error){console.error('Maintenance will retry:',error.message);}
  finally{maintaining=false;}
}
async function launch(options) {
  if(rooms.size>=maxRooms || closing || storageBytes+rooms.size*67108864>=storageLimit) throw Object.assign(new Error('전투 서버가 가득 찼거나 점검 중입니다. 잠시 후 다시 시도하세요.'),{status:503});
  const id=randomBytes(16).toString('hex'), code=randomBytes(5).toString('hex').toUpperCase();
  const probe=net.createServer(); await new Promise((yes,no)=>probe.once('error',no).listen(0,'127.0.0.1',yes));
  const gamePort=probe.address().port; await new Promise(yes=>probe.close(yes));
  const configuration={...options,id,code,port:gamePort,directory,protocol:PROTOCOL};
  const room={id,code,options,port:gamePort,created:Date.now(),connections:0,ready:false,child:null};
  rooms.set(code,room);
  try {
    const matchScript=process.env.ORBIT_MATCH_SCRIPT || 'res://server/match_server.gd';
    if(matchScript!=='res://server/match_server.gd' && (host!=='127.0.0.1' || process.env.ORBIT_SITES_URL)) throw new Error('test fixture is restricted to isolated local storage');
    const child=spawn(godot,['--headless','--audio-driver','Dummy','--max-fps','60','--path',root,'--script',matchScript,'--','--config',Buffer.from(JSON.stringify(configuration)).toString('base64')],{cwd:root,env:{...process.env,ORBIT_INTERNAL_KEY:secret},windowsHide:true,stdio:['ignore','pipe','pipe']});
    room.child=child;
    child.once('exit',()=>{rooms.delete(code); flushResults().catch(console.error);});
    await new Promise((yes,no)=>{
      const timer=setTimeout(()=>{child.kill();no(new Error('전투 서버 시작 시간 초과'));},15_000); let buffer='';
      child.once('error',error=>{clearTimeout(timer);no(error);});
      child.once('exit',()=>{clearTimeout(timer); if(!room.ready) no(new Error('전투 서버 시작 실패'));});
      child.stdout.on('data',chunk=>{
        buffer=(buffer+chunk.toString()).slice(-32768);
        if(!room.ready && buffer.includes('ONLINE_SERVER_READY')) {room.ready=true;clearTimeout(timer);yes();}
        if(buffer.includes('ONLINE_RESULT_READY')) flushResults().catch(console.error);
      });
      child.stderr.on('data',chunk=>console.error('Match runtime:',chunk.toString().slice(0,1000)));
    });
    return room;
  } catch(error) {rooms.delete(code);room.child?.kill();throw error;}
}
function roomInfo(room) {return {id:room.id,code:room.code,mode:room.options.mode,difficulty:room.options.difficulty,sector:room.options.sector,websocket:publicBase.replace(/^http/,'ws')+`/play/${room.code}`,protocol:PROTOCOL};}

const server=http.createServer(async(request,response)=>{
  const origin=request.headers.origin;
  if(origin) {
    if(!origins.has(origin)) return send(response,403,{error:'origin not allowed'});
    response.setHeader('Access-Control-Allow-Origin',origin);response.setHeader('Vary','Origin');
    response.setHeader('Access-Control-Allow-Headers','Content-Type');response.setHeader('Access-Control-Allow-Methods','GET,POST,OPTIONS');
  }
  if(request.method==='OPTIONS') return send(response,204,undefined);
  const address=clientAddress(request);
  if(!rate(address,240)) return send(response,429,{error:'요청이 너무 많습니다.'});
  try {
    const url=new URL(request.url,'http://localhost');
    if(request.method==='GET' && process.env.ORBIT_WEB_DIR && url.pathname.startsWith('/game/')){
      const name=url.pathname==='/game/'?'index.html':url.pathname.slice(6);
      const files=new Set(['index.html','index.js','index.pck','index.wasm','index.png','index.icon.png','index.apple-touch-icon.png','index.audio.worklet.js','index.audio.position.worklet.js']);
      if(!files.has(name))return send(response,404,{error:'not found'});
      const path=join(resolve(process.env.ORBIT_WEB_DIR),name),info=await stat(path);
      const mime=name.endsWith('.wasm')?'application/wasm':name.endsWith('.js')?'text/javascript':name.endsWith('.html')?'text/html; charset=utf-8':name.endsWith('.png')?'image/png':'application/octet-stream';
      response.writeHead(200,{'Content-Type':mime,'Content-Length':info.size,'Cache-Control':'no-store'});createReadStream(path).on('error',()=>response.destroy()).pipe(response);return;
    }
    if(request.method==='GET' && url.pathname==='/v1/config') return send(response,200,{protocol:PROTOCOL,rules:RULES,features:{combat:true,rankings:true,replays:true},rankings_backend:process.env.ORBIT_SITES_URL?'sites':'local-development',capacity:maxRooms,rooms:rooms.size,anonymous:true,draining:closing});
    if(request.method==='POST' && url.pathname==='/internal/drain'){
      if(!allowedSecret(request))return send(response,403,{error:'server access required'});
      closing=true;return send(response,200,{draining:true,rooms:rooms.size});
    }
    if(request.method==='POST' && url.pathname==='/v1/rooms'){
      if(!rate(`rooms:${address}`,6))return send(response,429,{error:'방 생성이 너무 빠릅니다. 잠시 후 다시 시도하세요.'});
      return send(response,201,roomInfo(await launch(roomOptions(await body(request)))));
    }
    if(request.method==='POST' && url.pathname==='/v1/rooms/join') {
      const value=await body(request), room=rooms.get(String(value.code||'').toUpperCase());
      if(!room || room.options.mode!=='coop') return send(response,404,{error:'참가할 방을 찾지 못했습니다.'});
      return send(response,200,roomInfo(room));
    }
    if(request.method==='GET' && url.pathname==='/v1/rankings') {
      if(process.env.ORBIT_SITES_URL){
        try{const upstream=await fetch(new URL(url.pathname+url.search,process.env.ORBIT_SITES_URL),{signal:AbortSignal.timeout(5000)});if(!upstream.ok)throw new Error('storage unavailable');return send(response,200,{...await upstream.json(),storage:'sites'});}
        catch{return send(response,200,{...store.rankings(url.searchParams),storage:'cache',stale:true});}
      }
      return send(response,200,{...store.rankings(url.searchParams),storage:'local-development'});
    }
    if(request.method==='POST' && url.pathname==='/v1/rankings') {
      const value=await body(request); const row=store.publish(String(value.run_id||''),value.nickname);
      try {await mirror('/internal/publish',{id:row.id,nickname:row.nickname});return send(response,200,{...row,storage:process.env.ORBIT_SITES_URL?'sites':'local-development'});}
      catch {await writeFile(join(directory,`${row.id}.publish.json`),JSON.stringify({id:row.id,nickname:row.nickname}));return send(response,202,{...row,storage:'pending'});}
    }
    if(request.method==='GET' && process.env.ORBIT_SITES_URL && /^\/v1\/(runs|replays)\/[a-f0-9]{32}(\/.*)?$/.test(url.pathname)){
      try{
        const upstream=await fetch(new URL(url.pathname,process.env.ORBIT_SITES_URL),{signal:AbortSignal.timeout(5000)});
        if(upstream.status<500){response.writeHead(upstream.status,{'Content-Type':upstream.headers.get('content-type')||'application/json','Cache-Control':'no-store'});for await(const bytes of upstream.body)response.write(bytes);return response.end();}
      }catch{}
      response.setHeader('X-Orbit-Storage','stale-cache');
    }
    const run=url.pathname.match(/^\/v1\/runs\/([a-f0-9]{32})$/);
    if(request.method==='GET' && run) {const row=store.get(run[1]);return send(response,row?200:404,row||{error:'기록 없음'});}
    const replay=url.pathname.match(/^\/v1\/replays\/([a-f0-9]{32})\/(manifest|\d{1,3}\.json\.gz)$/);
    if(request.method==='GET' && replay) {
      const row=store.get(replay[1]); if(!row || row.replay.status!=='complete') return send(response,404,{error:'고스트 처리 중 또는 만료'});
      if(replay[2]==='manifest') return send(response,200,row.replay);
      const index=Number(replay[2].split('.')[0]); if(!row.replay.chunks[index]) return send(response,404,{error:'청크 없음'});
      const bytes=await readFile(join(directory,`${replay[1]}.replay`,replay[2]));
      response.writeHead(200,{'Content-Type':'application/octet-stream','Content-Length':bytes.length,'Cache-Control':'public,max-age=3600','X-Content-SHA256':createHash('sha256').update(bytes).digest('hex')});return response.end(bytes);
    }
    if(request.method==='POST' && url.pathname==='/internal/results') {
      if(!allowedSecret(request)) return send(response,403,{error:'server access required'});
      const value=result(await body(request,1_048_576));
      await writeFile(join(directory,`${value.id}.result.json.tmp`),JSON.stringify(value));
      await rename(join(directory,`${value.id}.result.json.tmp`),join(directory,`${value.id}.result.json`));
      store.save(value);return send(response,200,{id:value.id});
    }
    return send(response,404,{error:'not found'});
  } catch(error) {return send(response,error.status||400,{error:error.message});}
});
server.on('upgrade',(request,socket,head)=>{
  const code=String(request.url||'').match(/^\/play\/([A-F0-9]{10})$/)?.[1], room=rooms.get(code);
  if(!room?.ready || room.connections>=6 || (request.headers.origin && !origins.has(request.headers.origin))) {socket.end('HTTP/1.1 403 Forbidden\r\nConnection: close\r\n\r\n');return;}
  room.connections++;
  const upstream=net.connect(room.port,'127.0.0.1');
  upstream.once('connect',()=>{upstream.write(`${request.method} / HTTP/${request.httpVersion}\r\n${Object.entries(request.headers).map(([key,value])=>`${key}: ${value}`).join('\r\n')}\r\n\r\n`);if(head.length)upstream.write(head);socket.pipe(upstream).pipe(socket);});
  socket.once('close',()=>{room.connections--;upstream.destroy();});
  socket.on('error',()=>upstream.destroy());upstream.on('error',()=>socket.destroy());
});
const retry=setInterval(async()=>{
  for(const [key,value] of limits) if(value.until<Date.now()) limits.delete(key);
  await flushResults();
  await maintenance();
  for(const name of await readdir(directory)) if(/^[a-f0-9]{32}\.publish\.json$/.test(name)) {
    try {const value=JSON.parse(await readFile(join(directory,name),'utf8'));await mirror('/internal/publish',value);await rename(join(directory,name),join(directory,name+'.saved'));} catch {}
  }
},5000);retry.unref();
let stopping=false;
function stop() {
  if(stopping)return;stopping=true;closing=true;
  const finish=setInterval(()=>{
    if(rooms.size||flushing||maintaining)return;
    clearInterval(finish);clearInterval(retry);server.close(()=>{store.close();process.exit(0);});
  },250);finish.unref();
  setTimeout(()=>{for(const room of rooms.values())room.child?.kill();process.exit(1);},Number(process.env.ORBIT_SHUTDOWN_SECONDS||600)*1000).unref();
}
process.on('SIGINT',stop);process.on('SIGTERM',stop);
await flushResults();
await maintenance();
server.listen(port,host,()=>console.log(`ORBIT_GATEWAY_READY ${publicBase}`));
