import assert from 'node:assert/strict';
import {createHmac} from 'node:crypto';
import {mkdir,writeFile} from 'node:fs/promises';

const base=process.env.ORBIT_SITES_URL,key=process.env.ORBIT_SITES_KEY;
if(!base||!key)throw new Error('Server environment with Sites URL and signing key required');
const evidence={url:base,checked_at:new Date().toISOString(),checks:[]};
async function check(label,path,options,status){
 const response=await fetch(new URL(path,base),{...options,signal:AbortSignal.timeout(15000)});
 assert.equal(response.status,status,label);evidence.checks.push({label,status});return response;
}
assert.equal((await (await check('anonymous config','/v1/config',{},200)).json()).anonymous,true);
await check('anonymous leaderboard','/v1/rankings?mode=coop&sector=storm&ship=scout',{},200);
await check('forged client result denied','/internal/results',{method:'POST',body:'{}'},403);
await check('unverified score denied','/v1/rankings',{method:'POST',body:JSON.stringify({run_id:'f'.repeat(32),score:999999,nickname:'probe'})},404);
const cors=await check('GitHub Pages CORS','/v1/config',{headers:{Origin:'https://libralightluda.github.io'}},200);
assert.equal(cors.headers.get('access-control-allow-origin'),'https://libralightluda.github.io');
await check('other browser origin denied','/v1/config',{headers:{Origin:'https://untrusted.invalid'}},403);
const path='/internal/storage-check',body='{}',timestamp=String(Date.now());
const signature=createHmac('sha256',key).update(`${timestamp}\n${path}\n${body}`).digest('hex');
const storage=await (await check('real D1 and R2 write/read/delete',path,{method:'POST',headers:{'Content-Type':'application/json','X-Orbit-Timestamp':timestamp,'X-Orbit-Signature':signature},body},200)).json();
assert.deepEqual(storage,{d1:'ok',r2:'ok'});evidence.storage=storage;
await mkdir('artifacts/online-work',{recursive:true});
await writeFile('artifacts/online-work/sites-verification.json',JSON.stringify(evidence,null,2));
console.log(`SITES PUBLIC CHECK: ${evidence.checks.length} checks passed; D1/R2 roundtrip passed; no public test scores created`);
