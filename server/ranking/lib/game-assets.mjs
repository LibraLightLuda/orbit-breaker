const files=new Set(['index.html','index.js','index.wasm','index.pck','index.png','index.icon.png','index.apple-touch-icon.png','index.audio.worklet.js','index.audio.position.worklet.js']);
export async function gameAsset(request,env){
 const path=new URL(request.url).pathname;
 if(!path.startsWith('/game/'))return null;
 const file=path==='/game/'?'index.html':path.slice(6);
 if(!files.has(file))return new Response('Not found',{status:404});
 const release=await env.BUCKET.get('game/current.json');
 if(!release)return new Response('Game candidate is not installed',{status:503});
 const manifest=await release.json(),entry=manifest.files?.[file];
 if(!/^[a-f0-9]{64}$/.test(manifest.release)||!entry)return new Response('Invalid game manifest',{status:503});
 let index=0,reader;
 const stream=request.method==='HEAD'?null:new ReadableStream({async pull(controller){
  try{while(true){
   if(!reader){if(index>=entry.parts.length){controller.close();return;}const object=await env.BUCKET.get(`game/${manifest.release}/${file}/${index}`);if(!object||object.size!==entry.parts[index].bytes)throw new Error('Missing game part');reader=object.body.getReader();index++;}
   const item=await reader.read();if(item.done){reader.releaseLock();reader=null;continue;}controller.enqueue(item.value);return;
  }}catch(error){controller.error(error);}
 },async cancel(){if(reader)await reader.cancel();}});
 const type=file.endsWith('.wasm')?'application/wasm':file.endsWith('.js')?'text/javascript':file.endsWith('.html')?'text/html; charset=utf-8':file.endsWith('.png')?'image/png':'application/octet-stream';
 return new Response(request.method==='HEAD'?null:stream,{headers:{'Content-Type':type,'Content-Length':String(entry.bytes),'Cache-Control':'no-cache','ETag':`"${entry.sha256}"`,'X-Content-Type-Options':'nosniff'}});
}
