import {gameAsset} from './game-assets.mjs';
export function records(env){

const encoder=new TextEncoder();
const idPattern=/^[a-f0-9]{32}$/;
const allowedOrigins=new Set(['https://libralightluda.github.io','http://127.0.0.1:8060','http://localhost:8060']);
const rules={solo:'online-solo-v1',coop:'coop-v1'};
function name(value){return typeof value==='string'?[...value.normalize('NFKC').replace(/[\u0000-\u001f\u007f\u200b-\u200f\u202a-\u202e\u2060-\u206f]/g,'').trim()].slice(0,16).join('')||'파일럿':'파일럿';}
function json(value,status=200,origin=null){return Response.json(value,{status,headers:{'Cache-Control':'no-store','X-Content-Type-Options':'nosniff',...(origin?{'Access-Control-Allow-Origin':origin,'Vary':'Origin'}:{})}});}
async function readBody(request,limit){
 const reader=request.body?.getReader();if(!reader)return new Uint8Array();let size=0;const chunks=[];
 while(true){const {value,done}=await reader.read();if(done)break;size+=value.byteLength;if(size>limit){await reader.cancel();throw new Error('request too large');}chunks.push(value);}
 const result=new Uint8Array(size);let offset=0;for(const chunk of chunks){result.set(chunk,offset);offset+=chunk.length;}return result;
}
async function trusted(request,path,bytes){
 const secret=env.RECORDS_SERVER_KEY;
 const timestamp=request.headers.get('x-orbit-timestamp')||'',signature=request.headers.get('x-orbit-signature')||'';
 if(!secret||!/^\d+$/.test(timestamp)||Math.abs(Date.now()-Number(timestamp))>300000||!/^\w{64}$/.test(signature))return false;
 const key=await crypto.subtle.importKey('raw',encoder.encode(secret),{name:'HMAC',hash:'SHA-256'},false,['verify']);
 const signed=new Uint8Array(encoder.encode(`${timestamp}\n${path}\n`).length+bytes.length);signed.set(encoder.encode(`${timestamp}\n${path}\n`));signed.set(bytes,signed.length-bytes.length);
 return crypto.subtle.verify('HMAC',key,new Uint8Array(signature.match(/../g).map(x=>parseInt(x,16))),signed);
}
async function publish(id,nickname){
 const db=env.DB;if(!idPattern.test(id))return null;
 await db.prepare('UPDATE runs SET nickname=?,published=1 WHERE id=? AND published=0').bind(name(nickname),id).run();
 return db.prepare('SELECT id,nickname,score,ticks,mode,difficulty,sector,ships,rules,season,replay,published FROM runs WHERE id=?').bind(id).first();
}
async function GET(request){
 const assets=await gameAsset(request,env);if(assets)return assets;
 const url=new URL(request.url),origin=request.headers.get('origin');
 if(origin&&origin!==new URL(request.url).origin&&!allowedOrigins.has(origin))return json({error:'origin not allowed'},403);
 if(url.pathname==='/v1/runtime')return json({websocket:typeof WebSocketPair==='function',sharedRoomBinding:!!env.ROOMS,dom:typeof document!=='undefined',combat:false,reason:'Authoritative Godot execution and shared room binding are not provisioned'},200,origin);
 if(url.pathname==='/v1/config')return json({anonymous:true,service:'Orbit Breaker records',protocol:2,features:{rankings:true,replays:true,combat:false}},200,origin);
 if(url.pathname==='/v1/rankings'){
  const season=url.searchParams.get('season')||new Date(Date.now()+9*3600000).toISOString().slice(0,7),mode=url.searchParams.get('mode')||'solo',difficulty=url.searchParams.get('difficulty')||'normal',sector=url.searchParams.get('sector')||'ring',cursor=Number(url.searchParams.get('cursor')||0),ship=url.searchParams.get('ship')||'';
  if(!/^\d{4}-\d{2}$/.test(season)||!['solo','coop'].includes(mode)||!['normal','relaxed','veteran','cataclysm'].includes(difficulty)||!['ring','storm','forge'].includes(sector)||!Number.isSafeInteger(cursor)||cursor<0||cursor>1000000||(ship&&!['striker','scout','bastion'].includes(ship)))return json({error:'invalid board'},400,origin);
  const rows=await env.DB.prepare(`SELECT id,nickname,score,ticks,ships,finished_at,replay,RANK() OVER(ORDER BY score DESC,ticks DESC) AS rank FROM runs WHERE published=1 AND season=? AND mode=? AND difficulty=? AND sector=? AND rules=? AND (?='' OR EXISTS(SELECT 1 FROM json_each(runs.ships) WHERE value=?)) ORDER BY score DESC,ticks DESC,finished_at,id LIMIT 20 OFFSET ?`).bind(season,mode,difficulty,sector,rules[mode],ship,ship,cursor).all();
  return json({items:rows.results.map((row)=>({...row,ships:JSON.parse(String(row.ships)),replay:JSON.parse(String(row.replay))})),next_cursor:rows.results.length===20?String(cursor+20):null},200,origin);
 }
 const run=url.pathname.match(/^\/v1\/runs\/([a-f0-9]{32})$/);
 if(run){const row=await env.DB.prepare('SELECT * FROM runs WHERE id=?').bind(run[1]).first();if(!row)return json({error:'record unavailable'},404,origin);const {result_hash,...publicRow}=row;return json({...publicRow,ships:JSON.parse(row.ships),replay:JSON.parse(row.replay),verification:'server'},200,origin);}
 const replay=url.pathname.match(/^\/v1\/replays\/([a-f0-9]{32})\/(manifest|\d{1,3}\.json\.gz)$/);
 if(replay){
  const row=await env.DB.prepare('SELECT replay FROM runs WHERE id=?').bind(replay[1]).first();if(!row)return json({error:'replay unavailable'},404,origin);
  const manifest=JSON.parse(String(row.replay));if(manifest.status!=='complete')return json({error:({pending:'고스트 업로드 처리 중입니다. 잠시 후 다시 시도하세요.',failed:'이 경기의 고스트를 보존하지 못했습니다. 점수는 유지됩니다.',expired:'고스트 보관 기간이 끝났습니다.'})[manifest.status]||'고스트를 이용할 수 없습니다.',status:manifest.status},404,origin);
  if(replay[2]==='manifest')return json(manifest,200,origin);
  const index=Number(replay[2].split('.')[0]);if(!Number.isInteger(index)||!manifest.chunks?.[index])return json({error:'chunk unavailable'},404,origin);
  const object=await env.BUCKET.get(`replays/${replay[1]}/${replay[2]}`);if(!object)return json({error:'replay expired'},404,origin);
  return new Response(object.body,{headers:{'Content-Type':'application/octet-stream','Content-Length':String(object.size),'Cache-Control':'public,max-age=3600',...(origin?{'Access-Control-Allow-Origin':origin}:{})}});
 }
 return json({error:'not found'},404,origin);
}
async function OPTIONS(request){const origin=request.headers.get('origin');if(origin&&origin!==new URL(request.url).origin&&!allowedOrigins.has(origin))return json({error:'origin not allowed'},403);return new Response(null,{status:204,headers:{'Access-Control-Allow-Origin':origin||'*','Access-Control-Allow-Methods':'GET,POST,OPTIONS','Access-Control-Allow-Headers':'Content-Type','Vary':'Origin'}});}
async function POST(request){
 const path=new URL(request.url).pathname,origin=request.headers.get('origin');
 if(origin&&origin!==new URL(request.url).origin&&!allowedOrigins.has(origin))return json({error:'origin not allowed'},403);
 try{
  const internal=path.startsWith('/internal/'),bytes=await readBody(request,internal?1048576:8192);
  if(internal&&!await trusted(request,path,bytes))return json({error:'server access required'},403);
  const asset=path.match(/^\/internal\/game-assets\/([a-f0-9]{64})\/(index(?:\.[a-z-]+)*\.(?:html|js|wasm|pck|png))\/(\d{1,3})$/);
  if(asset){if(bytes.length>1048576)return json({error:'part too large'},413);await env.BUCKET.put(`game/${asset[1]}/${asset[2]}/${asset[3]}`,bytes);return json({stored:true});}
  const chunk=path.match(/^\/internal\/replays\/([a-f0-9]{32})\/(\d{1,3}\.json\.gz)$/);
  if(chunk){await env.BUCKET.put(`replays/${chunk[1]}/${chunk[2]}`,bytes);return json({stored:true});}
  const value=JSON.parse(new TextDecoder().decode(bytes));
  if(path==='/internal/game-retention'){
   const active=await env.BUCKET.get('game/current.json');if(!active)return json({error:'no active game'},409);
   const current=await active.json();if(!/^[a-f0-9]{64}$/.test(value.release)||value.release===current.release)return json({error:'active release is protected'},409);
   const page=await env.BUCKET.list({prefix:`game/${value.release}/`,limit:500,cursor:value.cursor||undefined});
   for(const object of page.objects)await env.BUCKET.delete(object.key);
   return json({deleted:page.objects.length,cursor:page.truncated?page.cursor:null});
  }
  if(path==='/internal/game-release'){
   if(!/^[a-f0-9]{64}$/.test(value.release)||!value.files||Object.keys(value.files).length>9)return json({error:'invalid release'},400);
   for(const [file,entry] of Object.entries(value.files)){
    if(!/^index(?:\.[a-z-]+)*\.(html|js|wasm|pck|png)$/.test(file)||!Array.isArray(entry.parts)||entry.parts.length>100||!/^[a-f0-9]{64}$/.test(entry.sha256))return json({error:'invalid asset'},400);
    let size=0;for(let i=0;i<entry.parts.length;i++){
     const object=await env.BUCKET.get(`game/${value.release}/${file}/${i}`),part=entry.parts[i];if(!object||object.size!==part.bytes)return json({error:'missing asset part'},409);
     const hash=await crypto.subtle.digest('SHA-256',await object.arrayBuffer());if([...new Uint8Array(hash)].map(x=>x.toString(16).padStart(2,'0')).join('')!==part.sha256)return json({error:'corrupt asset part'},409);size+=object.size;
    }if(size!==entry.bytes)return json({error:'invalid asset size'},409);
   }
   if(!['index.html','index.js','index.wasm','index.pck'].every(file=>value.files[file]))return json({error:'incomplete release'},400);
   await env.BUCKET.put('game/current.json',JSON.stringify(value));return json({release:value.release});
  }
  if(path==='/internal/storage-check'){
   const probe=crypto.randomUUID().replaceAll('-','');
   const responses=await env.DB.batch([
    env.DB.prepare("INSERT INTO runs(id,nickname,score,ticks,mode,difficulty,sector,ships,rules,season,started_at,finished_at,result_hash,replay) VALUES(?,?,0,0,'solo','normal','ring','[\"striker\"]','storage-check','2000-01',?,?,?,'{}')").bind(probe,'storage-check',new Date().toISOString(),new Date().toISOString(),'0'.repeat(64)),
    env.DB.prepare('SELECT id FROM runs WHERE id=?').bind(probe),
    env.DB.prepare('DELETE FROM runs WHERE id=?').bind(probe)
   ]);
   const objectKey=`probes/${probe}`;let r2=false;
   try{await env.BUCKET.put(objectKey,encoder.encode(probe));const object=await env.BUCKET.get(objectKey);r2=await object?.text()===probe;}finally{await env.BUCKET.delete(objectKey);}
   return json({d1:responses[1].results[0]?.id===probe?'ok':'failed',r2:r2?'ok':'failed'});
  }
  if(path==='/internal/retention'){
   const now=new Date(),cutoff=new Date(now.valueOf()-7*86400000).toISOString();
   const rows=await env.DB.prepare(`WITH best AS (SELECT id,ROW_NUMBER() OVER(PARTITION BY season,mode,difficulty,sector,rules ORDER BY score DESC,ticks DESC,finished_at,id) AS place FROM runs WHERE published=1)
    SELECT id,replay FROM runs WHERE json_extract(replay,'$.status') IN ('complete','pending','failed') AND finished_at<? AND (id NOT IN(SELECT id FROM best WHERE place<=20) OR datetime(season||'-01','+1 month','+90 days')<datetime(?)) LIMIT 500`).bind(cutoff,now.toISOString()).all();
   for(const row of rows.results){
    const manifest=JSON.parse(String(row.replay));
    for(let index=0;index<(manifest.chunks||[]).length;index++)await env.BUCKET.delete(`replays/${row.id}/${index}.json.gz`);
    await env.DB.prepare("UPDATE runs SET replay=json_set(replay,'$.status','expired') WHERE id=?").bind(row.id).run();
   }
   const listed=await env.BUCKET.list({prefix:'replays/',limit:500,cursor:value.cursor||undefined});let orphaned=0;
   for(const object of listed.objects){const id=object.key.split('/')[1];if(!idPattern.test(id)||object.uploaded.valueOf()>Date.now()-86400000)continue;const row=await env.DB.prepare('SELECT replay FROM runs WHERE id=?').bind(id).first();if(!row||['failed','expired'].includes(JSON.parse(row.replay).status)){await env.BUCKET.delete(object.key);orphaned++;}}
   return json({expired:rows.results.length,orphaned,cursor:listed.truncated?listed.cursor:null});
  }
  if(path==='/internal/replay-state'){
   if(!idPattern.test(value.id)||!['pending','complete','failed','expired'].includes(value.replay?.status))return json({error:'invalid replay state'},400);
   const row=await env.DB.prepare('SELECT result_hash,replay FROM runs WHERE id=?').bind(value.id).first();if(!row)return json({error:'record missing'},404);
   if(row.result_hash!==value.result_hash)return json({error:'conflicting result'},409);
   const old=JSON.parse(row.replay);if(old.status==='expired'||old.status==='complete')return json({id:value.id,status:old.status});
   if(value.replay.status==='complete'){
    if(!Array.isArray(value.replay.chunks)||!value.replay.chunks.length||value.replay.chunks.length>301)return json({error:'invalid chunks'},400);
    let total=0;
    for(let i=0;i<value.replay.chunks.length;i++){
     const part=value.replay.chunks[i];if(!/^[a-f0-9]{64}$/.test(part.sha256)||!Number.isSafeInteger(part.bytes)||part.bytes<1||part.bytes>1048576)return json({error:'invalid chunk'},400);
     total+=part.bytes;if(total>67108864)return json({error:'replay too large'},400);
     const object=await env.BUCKET.get(`replays/${value.id}/${i}.json.gz`);if(!object||object.size!==part.bytes)return json({error:'missing chunk'},409);
     const hash=await crypto.subtle.digest('SHA-256',await object.arrayBuffer());if([...new Uint8Array(hash)].map(x=>x.toString(16).padStart(2,'0')).join('')!==part.sha256)return json({error:'corrupt chunk'},409);
    }
   }
   await env.DB.prepare('UPDATE runs SET replay=? WHERE id=? AND result_hash=?').bind(JSON.stringify(value.replay),value.id,row.result_hash).run();return json({id:value.id,status:value.replay.status});
  }
  if(path==='/internal/results'){
   if(!idPattern.test(value.id)||!Number.isSafeInteger(value.score)||value.score<0||value.score>1e9||!Number.isSafeInteger(value.ticks)||value.ticks<0||value.ticks>36001||!['solo','coop'].includes(value.mode)||value.rules!==rules[value.mode]||!/^\w{64}$/.test(value.result_hash))return json({error:'invalid server result'},400);
   const old=await env.DB.prepare('SELECT * FROM runs WHERE id=?').bind(value.id).first();if(old&&(['score','ticks','mode','difficulty','sector','rules','season','started_at','finished_at'].some(key=>old[key]!==value[key])||old.ships!==JSON.stringify(value.ships)))return json({error:'conflicting duplicate'},409);if(old)return json({id:value.id,result_hash:old.result_hash});
   await env.DB.prepare('INSERT OR IGNORE INTO runs(id,nickname,score,ticks,mode,difficulty,sector,ships,rules,season,started_at,finished_at,result_hash,replay) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?)').bind(value.id,name(value.nickname),value.score,value.ticks,value.mode,value.difficulty,value.sector,JSON.stringify(value.ships),value.rules,value.season,value.started_at,value.finished_at,value.result_hash,JSON.stringify(value.replay||{})).run();
   return json({id:value.id,result_hash:value.result_hash});
  }
  if(path==='/v1/rankings'||path==='/internal/publish'){
   const row=await publish(String(value.run_id||value.id||''),value.nickname);return json(row||{error:'verified server result not found'},row?200:404,origin);
  }
  if(path==='/internal/export'){
   const cursor=String(value.cursor||'');const rows=await env.DB.prepare('SELECT * FROM runs WHERE id>? ORDER BY id LIMIT 500').bind(cursor).all();return json({rows:rows.results,next:rows.results.length===500?rows.results[rows.results.length-1].id:null});
  }
  if(path==='/internal/restore'){
   if(!idPattern.test(value.id)||!/^\w{64}$/.test(value.result_hash)||!['solo','coop'].includes(value.mode)||value.rules!==rules[value.mode]||!Number.isSafeInteger(value.score)||value.score<0||value.score>1e9||!Number.isSafeInteger(value.ticks)||value.ticks<0||value.ticks>36001)return json({error:'invalid backup row'},400);
   JSON.parse(value.ships);JSON.parse(value.replay);
   const old=await env.DB.prepare('SELECT result_hash FROM runs WHERE id=?').bind(value.id).first();
   if(old&&old.result_hash!==value.result_hash)return json({error:'restore conflict; existing data preserved'},409);
   await env.DB.prepare('INSERT OR IGNORE INTO runs(id,nickname,score,ticks,mode,difficulty,sector,ships,rules,season,started_at,finished_at,result_hash,replay,published) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)').bind(value.id,name(value.nickname),value.score,value.ticks,value.mode,value.difficulty,value.sector,value.ships,value.rules,value.season,value.started_at,value.finished_at,value.result_hash,value.replay,value.published===1?1:0).run();
   return json({id:value.id,existing:!!old});
  }
  return json({error:'not found'},404,origin);
 }catch{return json({error:'invalid request'},400,origin);}
}

return {GET,POST,OPTIONS};
}
