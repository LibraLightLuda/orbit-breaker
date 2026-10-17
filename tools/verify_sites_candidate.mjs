import {readFile,readdir,writeFile} from 'node:fs/promises';
import {join} from 'node:path';
import {createHash,createHmac} from 'node:crypto';
import {result} from '../server/contract.mjs';
import {createRequire} from 'node:module';
if(process.stdin.isTTY)process.stdin.setRawMode(true);
console.log('Ready for hidden verification input');
const config=await new Promise(resolve=>{let input='';process.stdin.on('data',chunk=>{input+=chunk;if(input.includes('\n')||input.includes('\r')){process.stdin.pause();if(process.stdin.isTTY)process.stdin.setRawMode(false);resolve(JSON.parse(input.trim()));}});});
const {url,key,bearer,directory,output}=config;
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
async function fetchSite(path,body){
 const headers={'OAI-Sites-Authorization':`Bearer ${bearer}`};
 if(body!==undefined){const timestamp=String(Date.now());headers['X-Orbit-Timestamp']=timestamp;headers['X-Orbit-Signature']=createHmac('sha256',key).update(`${timestamp}\n${path}\n`).update(body).digest('hex');}
 const response=await fetch(new URL(path,url),{method:body===undefined?'GET':'POST',headers,body});
 if(!response.ok)throw new Error(`${path} ${response.status}: ${(await response.text()).slice(0,180)}`);
 return response;
}
const report={runtime:await (await fetchSite('/v1/runtime')).json(),assets:[],storage:await (await fetchSite('/internal/storage-check',Buffer.from('{}'))).json()};
const Socket=createRequire(import.meta.url)('../server/ranking/node_modules/ws');
report.websocketEcho=await new Promise((resolve,reject)=>{
 const socket=new Socket(new URL('/__sites_probe/ws',url).href.replace(/^http/,'ws'),{headers:{'OAI-Sites-Authorization':`Bearer ${bearer}`}});
 const timer=setTimeout(()=>{socket.terminate();reject(new Error('Sites WSS timeout'));},10000);
 socket.on('error',reject);socket.on('open',()=>socket.send('orbit-runtime-probe'));
 socket.on('message',bytes=>{clearTimeout(timer);socket.close();if(bytes.toString()!=='orbit-runtime-probe')reject(new Error('Sites WSS echo mismatch'));else resolve(true);});
});
for(const file of await readdir(directory)){
 if(!/^index(?:\.[a-z-]+)*\.(html|js|wasm|pck|png)$/.test(file))continue;
 const local=await readFile(join(directory,file)),response=await fetchSite('/game/'+file),remote=Buffer.from(await response.arrayBuffer());
 const identical=hash(local)===hash(remote);if(!identical&&(file!=='index.html'||!remote.toString().includes('Engine(')||!remote.toString().includes('index.pck')))throw new Error('Asset hash mismatch: '+file);if(!identical)console.log('Managed HTML response differs; Godot bootstrap verified');
 report.assets.push({identical,file,bytes:remote.length,sha256:hash(remote),type:response.headers.get('content-type')});
}
if(config.replayDirectory){
 const completed=(await readdir(config.replayDirectory)).find(file=>/^[a-f0-9]{32}\.saved\.json$/.test(file));
 if(completed){
  const value=result(JSON.parse(await readFile(join(config.replayDirectory,completed),'utf8'))),id=value.id;
  const accepted=await (await fetchSite('/internal/results',Buffer.from(JSON.stringify({...value,replay:{...value.replay,status:'pending'}})))).json();
  for(let i=0;i<value.replay.chunks.length;i++)await fetchSite(`/internal/replays/${id}/${i}.json.gz`,await readFile(join(config.replayDirectory,id+'.replay',i+'.json.gz')));
  await fetchSite('/internal/replay-state',Buffer.from(JSON.stringify({id,result_hash:accepted.result_hash,replay:value.replay})));
  await fetchSite('/internal/publish',Buffer.from(JSON.stringify({id,nickname:'검증 편대'})));
  const row=await (await fetchSite('/v1/runs/'+id)).json(),manifest=await (await fetchSite(`/v1/replays/${id}/manifest`)).json();
  const chunk=Buffer.from(await (await fetchSite(`/v1/replays/${id}/0.json.gz`)).arrayBuffer());if(hash(chunk)!==manifest.chunks[0].sha256)throw new Error('Cloud ghost hash mismatch');
  report.record={id,score:row.score,ghostStatus:manifest.status,chunkHash:hash(chunk)};
 }
}
report.retired=[];
for(const release of config.retireReleases||[])report.retired.push({release,...await (await fetchSite('/internal/game-retention',Buffer.from(JSON.stringify({release})))).json()});
await writeFile(output,JSON.stringify(report,null,2));console.log(JSON.stringify(report));
