import {DatabaseSync} from 'node:sqlite';
import {mkdtemp,rm,readFile} from 'node:fs/promises';
import {join,resolve} from 'node:path';
import {tmpdir} from 'node:os';
import {fileURLToPath} from 'node:url';
import {createHmac} from 'node:crypto';
import {spawnSync} from 'node:child_process';

const [mode,target]=process.argv.slice(2);
if(!['backup','restore'].includes(mode)||!target||!process.env.ORBIT_SITES_URL||!process.env.ORBIT_SITES_KEY||!process.env.ORBIT_BACKUP_KEY)throw new Error('Usage: server environment + ORBIT_BACKUP_KEY: node backup_cloud.mjs backup|restore archive.enc');
async function api(path,value){
 const body=JSON.stringify(value),timestamp=String(Date.now()),signature=createHmac('sha256',process.env.ORBIT_SITES_KEY).update(`${timestamp}\n${path}\n${body}`).digest('hex');
 const response=await fetch(new URL(path,process.env.ORBIT_SITES_URL),{method:'POST',headers:{'Content-Type':'application/json','X-Orbit-Timestamp':timestamp,'X-Orbit-Signature':signature},body,signal:AbortSignal.timeout(15000)});
 if(!response.ok)throw new Error(`Cloud backup operation failed (${response.status}); existing records preserved`);return response.json();
}
const scratch=await mkdtemp(join(tmpdir(),'orbit-cloud-backup-')),snapshot=join(scratch,'records.sqlite');
function encrypted(mode,source,destination){
 const result=spawnSync(process.execPath,[fileURLToPath(new URL('./backup.mjs',import.meta.url)),mode,source,destination],{env:process.env,windowsHide:true,encoding:'utf8'});
 if(result.status!==0)throw new Error('Encrypted backup verification failed');
}
let count=0,database;
try{
 if(mode==='backup'){
  database=new DatabaseSync(snapshot);database.exec(await readFile(new URL('./schema.sql',import.meta.url),'utf8'));
  let cursor='';
  do{
   const page=await api('/internal/export',{cursor});
   if(!Array.isArray(page.rows)||page.rows.length>500||page.next&&page.next<=cursor)throw new Error('Invalid export page');
   const statement=database.prepare('INSERT INTO runs(id,nickname,score,ticks,mode,difficulty,sector,ships,rules,season,started_at,finished_at,result_hash,replay,published) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)');
   database.exec('BEGIN');try{for(const row of page.rows){statement.run(...['id','nickname','score','ticks','mode','difficulty','sector','ships','rules','season','started_at','finished_at','result_hash','replay','published'].map(key=>row[key]));count++;}database.exec('COMMIT');}catch(error){database.exec('ROLLBACK');throw error;}
   cursor=page.next;
  }while(cursor);
  database.close();database=null;encrypted('backup',snapshot,resolve(target));
 }else{
  encrypted('restore',resolve(target),snapshot);database=new DatabaseSync(snapshot,{readOnly:true});
  for(const row of database.prepare('SELECT * FROM runs ORDER BY id').iterate()){await api('/internal/restore',row);count++;}
 }
 console.log(`CLOUD_${mode.toUpperCase()}_OK ${count} records; replay objects use their independent retention`);
}finally{database?.close();await rm(scratch,{recursive:true,force:true});}
