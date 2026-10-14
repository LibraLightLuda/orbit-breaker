"""Local-only production Web audio probe; records output, never a microphone."""
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
import json

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'artifacts/audio-candidate'
WEB=ROOT/'build/candidate/web'
PROBE=r'''<script>
(()=>{
  const contexts=[]; let recording=null, chunks=[];
  const connect=AudioNode.prototype.connect;
  AudioNode.prototype.connect=function(target,...args){
    const result=connect.call(this,target,...args);
    const entry=contexts.find(x=>x.ctx===this.context);
    if(entry && target===entry.ctx.destination && !entry.nodes.has(this)){
      entry.nodes.add(this); connect.call(this,entry.tap);
    }
    return result;
  };
  for(const name of ['AudioContext','webkitAudioContext']){
    const Original=window[name]; if(!Original) continue;
    function Wrapped(...args){
      const ctx=new Original(...args);
      contexts.push({ctx,tap:ctx.createMediaStreamDestination(),nodes:new Set()});
      return ctx;
    }
    Wrapped.prototype=Original.prototype; window[name]=Wrapped;
  }
  window.addEventListener('DOMContentLoaded',()=>{
    const panel=document.createElement('div'); panel.id='audio-probe';
    panel.style='position:fixed;bottom:4px;right:4px;z-index:9999;background:#09121fee;color:#eef3e7;font:12px system-ui;padding:8px;border:1px solid #72dce6';
    panel.innerHTML='<span id="probe-state">audio waiting</span> <button id="probe-record">Record output</button> <button id="probe-snapshot">Save frame</button>';
    document.body.append(panel);
    setInterval(()=>{document.querySelector('#probe-state').textContent=contexts.map(x=>x.ctx.state+' / '+x.ctx.sampleRate+'Hz / '+x.nodes.size+' output').join(', ')||'audio waiting'},250);
    document.querySelector('#probe-record').onclick=async()=>{
      const button=document.querySelector('#probe-record');
      if(recording){ recording.stop();recording=null;button.textContent='Saving...';return; }
      const entry=contexts[0];if(!entry){button.textContent='Audio not ready';return;}
      await entry.ctx.resume(); chunks=[];
      recording=new MediaRecorder(entry.tap.stream,{mimeType:'audio/webm;codecs=opus'});
      recording.ondataavailable=e=>{if(e.data.size)chunks.push(e.data)};
      recording.onstop=async()=>{
        const blob=new Blob(chunks,{type:'audio/webm'});
        const response=await fetch('/qa/audio',{method:'POST',body:blob});
        button.textContent=response.ok?'Output saved':'Save failed';
      };
      recording.start(250);button.textContent='Stop recording';
    };
    let frames=0;
    document.querySelector('#probe-snapshot').onclick=()=>requestAnimationFrame(()=>{
      document.querySelector('canvas').toBlob(async blob=>{
        const r=await fetch('/qa/frame',{method:'POST',body:blob});
        document.querySelector('#probe-snapshot').textContent=r.ok?'Frame saved '+(++frames):'Frame failed';
      },'image/png');
    });
  });
})();
</script>'''

class Handler(SimpleHTTPRequestHandler):
    def __init__(self,*args,**kwargs):
        super().__init__(*args,directory=str(WEB),**kwargs)
    def do_GET(self):
        if self.path.split('?')[0]=='/audio-probe.html':
            html=(WEB/'index.html').read_text(encoding='utf-8').replace('<head>','<head>'+PROBE,1).encode()
            self.send_response(200);self.send_header('Content-Type','text/html; charset=utf-8');self.send_header('Content-Length',str(len(html)));self.end_headers();self.wfile.write(html)
        else:super().do_GET()
    def do_POST(self):
        size=int(self.headers.get('Content-Length','0'))
        if self.path not in ['/qa/audio','/qa/frame'] or not 0<size<32*1024*1024:
            self.send_error(400);return
        data=self.rfile.read(size)
        if self.path=='/qa/audio':name='browser-mix.webm'
        else:name=f'browser-frame-{len(list(OUT.glob("browser-frame-*.png")))+1:02d}.png'
        (OUT/name).write_bytes(data)
        self.send_response(200);self.end_headers();self.wfile.write(b'OK')
    def log_message(self,format,*args):
        print(format%args,flush=True)

if __name__=='__main__':
    OUT.mkdir(parents=True,exist_ok=True)
    print('Local production audio probe: http://127.0.0.1:8878/audio-probe.html',flush=True)
    ThreadingHTTPServer(('127.0.0.1',8878),Handler).serve_forever()
