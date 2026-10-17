import {readFile,readdir} from 'node:fs/promises';
import {createHash,createHmac} from 'node:crypto';
import {join} from 'node:path';
if(process.stdin.isTTY)process.stdin.setRawMode(true);
console.log('Ready for hidden staging input');
const config=await new Promise(resolve=>{let input='';process.stdin.on('data',chunk=>{input+=chunk;if(input.includes('\n')||input.includes('\r')){process.stdin.pause();if(process.stdin.isTTY)process.stdin.setRawMode(false);resolve(JSON.parse(input.trim()));}});});
const {url,key,bearer,directory}=config;
if(!new URL(url).hostname.endsWith('.chatgpt.site'))throw new Error('Sites URL required');
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
const files={},content=new Map();
for(const file of (await readdir(directory)).sort()){
 if(!/^index(?:\.[a-z-]+)*\.(html|js|wasm|pck|png)$/.test(file))continue;
 const bytes=await readFile(join(directory,file)),parts=[];
 for(let at=0;at<bytes.length;at+=1048576){const part=bytes.subarray(at,at+1048576);parts.push({bytes:part.length,sha256:hash(part)});}
 files[file]={bytes:bytes.length,sha256:hash(bytes),parts};content.set(file,bytes);
}
const release=hash(JSON.stringify(files));
async function post(path,bytes){
 const timestamp=String(Date.now()),signature=createHmac('sha256',key).update(`${timestamp}\n${path}\n`).update(bytes).digest('hex');
 for(let attempt=0;attempt<3;attempt++){
  const response=await fetch(new URL(path,url),{method:'POST',headers:{'X-Orbit-Timestamp':timestamp,'X-Orbit-Signature':signature,'OAI-Sites-Authorization':`Bearer ${bearer}`},body:bytes});
  if(response.ok)return response.json();if(response.status<500||attempt===2)throw new Error(`${path}: ${response.status} ${(await response.text()).slice(0,200)}`);
 }
}
for(const [file,bytes] of content){for(let index=0;index<files[file].parts.length;index++)await post(`/internal/game-assets/${release}/${file}/${index}`,bytes.subarray(index*1048576,(index+1)*1048576));console.log(`STAGED ${file} ${bytes.length}`);}
await post('/internal/game-release',Buffer.from(JSON.stringify({release,files})));
console.log(JSON.stringify({release,fileCount:Object.keys(files).length}));
