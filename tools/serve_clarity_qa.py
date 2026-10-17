"""Loopback-only validation server; stores WebAssembly measurements in the task evidence."""
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT / 'artifacts/clarity-work/web-results.json'


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def do_POST(self):
        length = int(self.headers.get('Content-Length', '0'))
        if self.path != '/qa-report' or not 0 < length < 65536:
            self.send_error(400)
            return
        value = json.loads(self.rfile.read(length))
        if value.get('kind') not in ['orbit-art-web-stress', 'orbit-mobile-input']:
            self.send_error(400)
            return
        values = json.loads(REPORT.read_text(encoding='utf-8')) if REPORT.exists() else []
        values.append(value)
        REPORT.write_text(json.dumps(values, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        self.send_response(204)
        self.end_headers()


if __name__ == '__main__':
    ThreadingHTTPServer(('127.0.0.1', 8769), Handler).serve_forever()
