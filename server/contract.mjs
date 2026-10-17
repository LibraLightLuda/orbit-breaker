import {createHash} from 'node:crypto';

export const PROTOCOL = 2;
export const RULES = Object.freeze({solo:'online-solo-v1',coop:'coop-v1'});
export const MODES = ['normal','relaxed','veteran','cataclysm'];
export const SHIPS = ['striker','scout','bastion'];
export const SECTORS = ['ring','storm','forge'];
export const RUN_ID = /^[a-f0-9]{32}$/;
export function cleanName(value) {
  return typeof value === 'string' ? [...value.normalize('NFKC').replace(/[\u0000-\u001f\u007f\u200b-\u200f\u202a-\u202e\u2060-\u206f]/g,'').trim()].slice(0,16).join('') || '파일럿' : '파일럿';
}
export function seasonAt(value) {
  const date = new Date(value);
  if (!Number.isFinite(date.valueOf())) throw new Error('invalid timestamp');
  return new Date(date.valueOf()+9*3600_000).toISOString().slice(0,7);
}
export function roomOptions(value) {
  if (!value || !['solo','coop'].includes(value.mode) || !MODES.includes(value.difficulty) || !SHIPS.includes(value.ship) || !SECTORS.includes(value.sector)) throw new Error('invalid room settings');
  return {mode:value.mode,difficulty:value.difficulty,ship:value.ship,sector:value.sector,nickname:cleanName(value.nickname)};
}
export function result(value) {
  if (!value || !RUN_ID.test(value.id) || !['solo','coop'].includes(value.mode) || !MODES.includes(value.difficulty) || !SECTORS.includes(value.sector)) throw new Error('invalid result');
  if (!Number.isSafeInteger(value.score) || value.score < 0 || value.score > 1e9 || !Number.isSafeInteger(value.ticks) || value.ticks < 0 || value.ticks > 36001) throw new Error('invalid score or duration');
  if (value.rules !== RULES[value.mode] || !Array.isArray(value.ships) || value.ships.length !== (value.mode === 'coop'?2:1) || value.ships.some(x=>!SHIPS.includes(x))) throw new Error('incompatible rules');
  const started = new Date(value.started_at), finished = new Date(value.finished_at);
  if (!Number.isFinite(started.valueOf()) || !Number.isFinite(finished.valueOf()) || finished < started || finished-started > 1805_000 || finished > Date.now()+60_000) throw new Error('invalid match clock');
  const replay = value.replay ?? {};
  if (typeof replay !== 'object' || replay === null || Array.isArray(replay)) throw new Error('invalid replay');
  const normalized = {id:value.id,nickname:cleanName(value.nickname),score:value.score,ticks:value.ticks,mode:value.mode,difficulty:value.difficulty,sector:value.sector,ships:value.ships,rules:value.rules,season:seasonAt(started),started_at:started.toISOString(),finished_at:finished.toISOString(),replay};
  const {nickname,replay:ignored,...immutable}=normalized;
  return {...normalized,hash_version:2,result_hash:createHash('sha256').update(JSON.stringify(immutable)).digest('hex')};
}
export function sameResult(a,b) {
  return ['id','score','ticks','mode','difficulty','sector','rules','season','started_at','finished_at'].every(key=>a[key]===b[key]) && JSON.stringify(typeof a.ships==='string'?JSON.parse(a.ships):a.ships)===JSON.stringify(typeof b.ships==='string'?JSON.parse(b.ships):b.ships);
}
export function board(value) {
  const get = key => value instanceof URLSearchParams ? value.get(key) : value[key];
  const params = {season:get('season') || seasonAt(Date.now()),mode:get('mode') || 'solo',difficulty:get('difficulty') || 'normal',sector:get('sector') || 'ring',ship:get('ship') || '',cursor:Number(get('cursor') || 0)};
  if (!/^\d{4}-\d{2}$/.test(params.season) || !['solo','coop'].includes(params.mode) || !MODES.includes(params.difficulty) || !SECTORS.includes(params.sector) || (params.ship && !SHIPS.includes(params.ship)) || !Number.isSafeInteger(params.cursor) || params.cursor < 0 || params.cursor > 1e6) throw new Error('invalid leaderboard filter');
  return {...params,rules:RULES[params.mode]};
}
