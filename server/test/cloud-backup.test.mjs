import {test} from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import {spawn} from 'node:child_process';
import {randomBytes,createHmac} from 'node:crypto';
import {mkdtemp,rm} from 'node:fs/promises';
import {join} from 'node:path';
import {tmpdir} from 'node:os';

test('cloud metadata backup preserves anonymous publication and verifies encryption before restore',{timeout:20000},async()=>{
 const directory=await mkdtemp(join(tmpdir(),'orbit-cloud-backup-test-')),archive=join(directory,'records.enc'),key=randomBytes(32).toString('hex'),secret=randomBytes(32).toString('hex');
 const row={id:'a'.repeat(32),nickname:'익명 게시 이름',score:12,ticks:60,mode:'solo',difficulty:'normal',sector:'ring',ships:'["striker"]',rules:'online-solo-v1',season:'2026-10',started_at:'2026-10-16T00:00:00Z',finished_at:'2026-10-16T00:00:01Z',result_hash:'f'.repeat(64),replay:'{"status":"complete","chunks":[]}',published:1};
 const restored=[];
 const server=http.createServer(async(req,res)=>{
  const chunks=[];for await(const chunk of req)chunks.push(chunk);const body=Buffer.concat(chunks).toString(),timestamp=req.headers['x-orbit-timestamp'];
  assert.equal(req.headers['x-orbit-signature'],createHmac('sha256',secret).update(`${timestamp}\n${req.url}\n${body}`).digest('hex'));
  const value=JSON.parse(body);res.setHeader('Content-Type','application/json');
  if(req.url==='/internal/export')res.end(JSON.stringify({rows:[row],next:null}));
  else{restored.push(value);res.end(JSON.stringify({id:value.id}));}
 });
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
 const run=(mode,backupKey=key)=>new Promise(resolve=>{
  const child=spawn(process.execPath,['server/backup_cloud.mjs',mode,archive],{env:{...process.env,ORBIT_BACKUP_KEY:backupKey,ORBIT_SITES_URL:`http://127.0.0.1:${server.address().port}`,ORBIT_SITES_KEY:secret},windowsHide:true,stdio:'ignore'});child.once('exit',resolve);
 });
 try{
  assert.equal(await run('backup'),0);
  assert.notEqual(await run('restore',randomBytes(32).toString('hex')),0);assert.equal(restored.length,0);
  assert.equal(await run('restore'),0);assert.deepEqual(restored,[row]);
 }finally{await new Promise(resolve=>server.close(resolve));await rm(directory,{recursive:true,force:true});}
});
