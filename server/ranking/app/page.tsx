'use client';
import {useEffect,useState} from 'react';
type Row={id:string;rank:number;nickname:string;score:number;ticks:number};
export default function Page(){
 const [rows,setRows]=useState<Row[]>([]),[status,setStatus]=useState('기록을 불러오는 중…'),[mode,setMode]=useState('solo'),[difficulty,setDifficulty]=useState('normal'),[sector,setSector]=useState('ring');
 useEffect(()=>{const controller=new AbortController();setStatus('기록을 불러오는 중…');fetch(`/v1/rankings?mode=${mode}&difficulty=${difficulty}&sector=${sector}`,{signal:controller.signal}).then(r=>{if(!r.ok)throw new Error();return r.json();}).then(data=>{setRows(data.items);setStatus(data.items.length?'':'이번 시즌의 첫 기록을 남겨보세요.');}).catch(()=>{if(!controller.signal.aborted)setStatus('연결을 확인한 뒤 다시 시도하세요.');});return()=>controller.abort();},[mode,difficulty,sector]);
 const control={background:'#142537',color:'#eef3e7',padding:12,border:'1px solid #72dce6',borderRadius:8,minHeight:44};
 return <main style={{minHeight:'100vh',margin:0,padding:'48px max(24px, calc((100vw - 760px) / 2))',background:'#09121f',color:'#eef3e7',fontFamily:'system-ui,sans-serif'}}><p style={{color:'#72dce6',letterSpacing:3}}>ORBIT BREAKER</p><h1 style={{fontSize:'clamp(30px,6vw,44px)'}}>익명 경기 기록</h1><p>ChatGPT 로그인 없이 이용합니다. 닉네임은 중복될 수 있으며, 공식 기록은 전투 서버에서 확인한 경기입니다.</p><div style={{display:'flex',gap:12,flexWrap:'wrap',margin:'28px 0'}}>
 <select aria-label="경기 방식" value={mode} onChange={e=>setMode(e.target.value)} style={control}><option value="solo">솔로</option><option value="coop">2인 협동</option></select>
 <select aria-label="난이도" value={difficulty} onChange={e=>setDifficulty(e.target.value)} style={control}>{[['normal','표준'],['relaxed','여유'],['veteran','숙련'],['cataclysm','대격변']].map(([id,label])=><option key={id} value={id}>{label}</option>)}</select>
 <select aria-label="전장" value={sector} onChange={e=>setSector(e.target.value)} style={control}>{[['ring','궤도'],['storm','폭풍'],['forge','용광로']].map(([id,label])=><option key={id} value={id}>{label}</option>)}</select></div>
 <p role="status">{status}</p><ol style={{listStyle:'none',padding:0}}>{rows.map(row=><li key={row.id} style={{display:'flex',justifyContent:'space-between',gap:16,padding:'16px 0',borderBottom:'1px solid #263b4d'}}><span>{row.rank} · {row.nickname}</span><strong>{row.score.toLocaleString('ko-KR')}</strong></li>)}</ol>
 <a href="https://libralightluda.github.io/orbit-breaker/" style={{display:'inline-block',background:'#b7f878',color:'#09121f',padding:'14px 24px',borderRadius:8,textDecoration:'none',marginTop:20}}>웹에서 플레이</a><p style={{color:'#9aacbc',fontSize:14}}>웹과 Windows 버전에서 같은 랭킹과 고스트를 조회합니다. 온라인 공식 도전과 2인 협동은 아직 제공되지 않습니다.</p></main>;
}
