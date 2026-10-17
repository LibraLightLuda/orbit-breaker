import {test} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,rmSync,readFileSync,existsSync,writeFileSync,readdirSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join,resolve,sep} from 'node:path';
import {spawnSync} from 'node:child_process';
import {randomBytes} from 'node:crypto';
import {DatabaseSync} from 'node:sqlite';

test('encrypted consistent SQLite backup, restore and wrong-key rejection',()=>{
 const directory=mkdtempSync(join(tmpdir(),'orbit-backup-')),source=join(directory,'source.sqlite'),archive=join(directory,'backup.enc'),restored=join(directory,'restored.sqlite');
 const database=new DatabaseSync(source);database.exec("CREATE TABLE proof(value TEXT); INSERT INTO proof VALUES('actual saved data');");
 const key=randomBytes(32).toString('hex');
 const run=(args,secret=key)=>spawnSync(process.execPath,['server/backup.mjs',...args],{env:{...process.env,ORBIT_BACKUP_KEY:secret},encoding:'utf8'});
 try{
  writeFileSync(archive+'.sqlite','unrelated existing file');
  assert.equal(run(['backup',source,archive]).status,0);
  assert.equal(readFileSync(archive+'.sqlite','utf8'),'unrelated existing file');
  assert.notEqual(run(['backup',source,archive]).status,0);
  assert.equal(readdirSync(directory).some(name=>name.includes('.snapshot-')),false);
  assert.equal(readFileSync(archive).includes(Buffer.from('actual saved data')),false);
  assert.notEqual(run(['restore',archive,join(directory,'wrong.sqlite')],randomBytes(32).toString('hex')).status,0);
  assert.equal(existsSync(join(directory,'wrong.sqlite')),false);
  assert.equal(run(['restore',archive,restored]).status,0);
  const copy=new DatabaseSync(restored);try{assert.equal(copy.prepare('SELECT value FROM proof').get().value,'actual saved data');}finally{copy.close();}
  assert.notEqual(run(['restore',archive,restored]).status,0,'existing files cannot be overwritten');
 }finally{database.close();assert.ok(resolve(directory).startsWith(resolve(tmpdir())+sep));rmSync(directory,{recursive:true,force:true,maxRetries:10,retryDelay:100});}
});
