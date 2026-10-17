import {DatabaseSync} from 'node:sqlite';
import {readFileSync,mkdirSync} from 'node:fs';
import {join} from 'node:path';
import {board,cleanName,RUN_ID,sameResult} from './contract.mjs';

export class Store {
  constructor(directory) {
    mkdirSync(directory,{recursive:true});
    this.db = new DatabaseSync(join(directory,'records.sqlite'));
    this.db.exec('PRAGMA journal_mode=WAL; PRAGMA foreign_keys=ON; PRAGMA busy_timeout=5000;');
    this.db.exec(readFileSync(new URL('./schema.sql',import.meta.url),'utf8'));
  }
  save(value) {
    const old = this.db.prepare('SELECT * FROM runs WHERE id=?').get(value.id);
    if (old) { if (!sameResult(old,value)) throw Object.assign(new Error('conflicting duplicate result'),{status:409}); return this.get(value.id); }
    this.db.prepare('INSERT INTO runs(id,nickname,score,ticks,mode,difficulty,sector,ships,rules,season,started_at,finished_at,result_hash,replay) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?)').run(value.id,value.nickname,value.score,value.ticks,value.mode,value.difficulty,value.sector,JSON.stringify(value.ships),value.rules,value.season,value.started_at,value.finished_at,value.result_hash,JSON.stringify(value.replay));
    return this.get(value.id);
  }
  get(id) {
    if (!RUN_ID.test(id)) return null;
    const row = this.db.prepare('SELECT * FROM runs WHERE id=?').get(id);
    if (!row) return null;
    const {result_hash,...publicRow} = row;
    return {...publicRow,ships:JSON.parse(row.ships),replay:JSON.parse(row.replay),verification:'server'};
  }
  publish(id,nickname) {
    if (!this.get(id)) throw Object.assign(new Error('server result not found'),{status:404});
    this.db.prepare('UPDATE runs SET published=1,nickname=? WHERE id=? AND published=0').run(cleanName(nickname),id);
    return this.get(id);
  }
  rankings(query) {
    const p = board(query);
    const rows = this.db.prepare(`SELECT id,nickname,score,ticks,ships,finished_at,replay,RANK() OVER(ORDER BY score DESC,ticks DESC) AS rank FROM runs WHERE published=1 AND season=? AND mode=? AND difficulty=? AND sector=? AND rules=? AND (?='' OR EXISTS(SELECT 1 FROM json_each(runs.ships) WHERE value=?)) ORDER BY score DESC,ticks DESC,finished_at,id LIMIT 20 OFFSET ?`).all(p.season,p.mode,p.difficulty,p.sector,p.rules,p.ship,p.ship,p.cursor);
    return {items:rows.map(row=>({...row,ships:JSON.parse(row.ships),replay:JSON.parse(row.replay)})),next_cursor:rows.length===20?String(p.cursor+20):null,...p};
  }
  close() { this.db.close(); }
  expiredReplays(now=Date.now()) {
    return this.db.prepare(`WITH best AS (SELECT id,ROW_NUMBER() OVER(PARTITION BY season,mode,difficulty,sector,rules ORDER BY score DESC,ticks DESC,finished_at,id) AS place FROM runs WHERE published=1)
      SELECT id,replay FROM runs WHERE json_extract(replay,'$.status')='complete' AND finished_at<? AND
      (id NOT IN(SELECT id FROM best WHERE place<=20) OR datetime(season||'-01','+1 month','+90 days')<datetime(?)) LIMIT 500`).all(new Date(now-7*86400000).toISOString(),new Date(now).toISOString()).map(row=>({...row,replay:JSON.parse(row.replay)}));
  }
  expireReplay(id) {
    this.db.prepare("UPDATE runs SET replay=json_set(replay,'$.status','expired') WHERE id=?").run(id);
  }
  replayState(id,replay) { this.db.prepare('UPDATE runs SET replay=? WHERE id=?').run(JSON.stringify(replay),id); }
}
