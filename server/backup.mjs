import {DatabaseSync,backup} from 'node:sqlite';
import {readFile,writeFile,mkdir,mkdtemp,rm} from 'node:fs/promises';
import {resolve,dirname} from 'node:path';
import {randomBytes,createCipheriv,createDecipheriv} from 'node:crypto';

const [mode,source,target]=process.argv.slice(2);
const key=Buffer.from(process.env.ORBIT_BACKUP_KEY||'','hex');
if(!['backup','restore'].includes(mode)||!source||!target||key.length!==32)throw new Error('Usage: ORBIT_BACKUP_KEY=<64 hex> node server/backup.mjs backup|restore source target');
await mkdir(dirname(resolve(target)),{recursive:true});
if(mode==='backup'){
 const scratch=await mkdtemp(resolve(target)+'.snapshot-'),snapshot=resolve(scratch,'records.sqlite');
 try{
  const database=new DatabaseSync(resolve(source),{readOnly:true});
  try{await backup(database,snapshot);}finally{database.close();}
  const iv=randomBytes(12),cipher=createCipheriv('aes-256-gcm',key,iv);const bytes=Buffer.concat([cipher.update(await readFile(snapshot)),cipher.final()]);
  await writeFile(resolve(target),Buffer.concat([Buffer.from('OBBK1'),iv,cipher.getAuthTag(),bytes]),{flag:'wx',mode:0o600});
 }finally{await rm(scratch,{recursive:true,force:true});}
}else{
 const bytes=await readFile(resolve(source));if(bytes.subarray(0,5).toString()!=='OBBK1')throw new Error('Invalid backup');
 const decipher=createDecipheriv('aes-256-gcm',key,bytes.subarray(5,17));decipher.setAuthTag(bytes.subarray(17,33));
 const restored=Buffer.concat([decipher.update(bytes.subarray(33)),decipher.final()]);
 await writeFile(resolve(target),restored,{flag:'wx',mode:0o600});
 const database=new DatabaseSync(resolve(target),{readOnly:true});try{if(database.prepare('PRAGMA integrity_check').get().integrity_check!=='ok')throw new Error('Restored database failed integrity check');}finally{database.close();}
}
console.log('BACKUP_CHECK_OK');
