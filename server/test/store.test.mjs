import {resolve,sep} from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {Store} from '../store.mjs';
import {result,seasonAt,cleanName,roomOptions} from '../contract.mjs';

function sample(id='a'.repeat(32),score=100) {return result({id,nickname:'파일럿',score,ticks:120,mode:'solo',difficulty:'normal',sector:'ring',ships:['striker'],rules:'online-solo-v1',started_at:'2026-10-15T14:59:00Z',finished_at:'2026-10-15T15:01:00Z'});}
test('anonymous publication, duplicate results and shared ranking',()=>{
 const dir=mkdtempSync(join(tmpdir(),'orbit-store-'));const store=new Store(dir);
 try {
  const value=sample();store.save(value);store.save(value);
  store.db.prepare('UPDATE runs SET result_hash=? WHERE id=?').run('legacy-v1-hash',value.id);
  store.save(result({...value,replay:{status:'failed'}}));
  assert.equal(store.db.prepare('SELECT result_hash FROM runs WHERE id=?').get(value.id).result_hash,'legacy-v1-hash','legacy hash remains stable when ghost state changes');
  assert.equal(store.rankings({season:'2026-10'}).items.length,0);
  store.publish(value.id,'익명');store.publish(value.id,'변경 시도');
  assert.equal(store.get(value.id).nickname,'익명');
  assert.equal(store.rankings({season:'2026-10'}).items.length,1);
  assert.throws(()=>store.save(sample(value.id,999)),/conflicting/);
  store.save(sample('b'.repeat(32)));store.publish('b'.repeat(32),'익명');
  assert.deepEqual(store.rankings({season:'2026-10'}).items.map(x=>x.rank),[1,1]);
  assert.throws(()=>store.publish('c'.repeat(32),'위조'),/not found/);
  assert.equal(store.get('../secret'),null);
 } finally {store.close();assert.ok(resolve(dir).startsWith(resolve(tmpdir())+sep));rmSync(dir,{recursive:true,force:true});}
});
test('trust boundaries and Korea season',()=>{
 assert.equal(seasonAt('2026-10-31T15:00:00Z'),'2026-11');
 assert.equal(cleanName('  파일\u202e럿\n  '),'파일럿');
 assert.throws(()=>result({...sample(),score:NaN}));
 assert.throws(()=>result({...sample(),ticks:36002}));
 assert.throws(()=>result({...sample(),ships:['unknown']}));
 assert.throws(()=>roomOptions({mode:'coop',difficulty:'hacked',ship:'scout',sector:'ring'}));
});
test('replay expiry preserves scores and the twenty best published records until season + 90 days',()=>{
 const dir=mkdtempSync(join(tmpdir(),'orbit-retention-')),store=new Store(dir);
 try{
  for(let i=1;i<=22;i++){
   const value=sample(i.toString(16).padStart(32,'0'),i);value.replay={status:'complete',chunks:[]};store.save(result(value));if(i!==22)store.publish(value.id,'anonymous');
  }
  const candidates=store.expiredReplays(Date.parse('2026-10-24T00:00:00Z'));
  assert.deepEqual(candidates.map(row=>row.id).sort(),[1,22].map(i=>i.toString(16).padStart(32,'0')));
  store.expireReplay(candidates[0].id);
  assert.equal(store.get(candidates[0].id).replay.status,'expired');
  assert.equal(store.get(candidates[0].id).score,1);
  assert.equal(store.expiredReplays(Date.parse('2027-02-01T00:00:00Z')).length,21);
 }finally{store.close();assert.ok(resolve(dir).startsWith(resolve(tmpdir())+sep));rmSync(dir,{recursive:true,force:true});}
});
