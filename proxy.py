import os
import sys
import mimetypes
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
import urllib.request
import urllib.error

BACKEND_URL = "http://127.0.0.1:8000"
FRONTEND_URL = "http://127.0.0.1:8081"
PORT = 8080
WEB_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "mobile", "build", "web"))

class ReverseProxyHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        self._handle_request()

    def do_HEAD(self):
        self._handle_request()

    def do_POST(self):
        self._handle_request()

    def do_PUT(self):
        self._handle_request()

    def do_PATCH(self):
        self._handle_request()

    def do_DELETE(self):
        self._handle_request()

    def do_OPTIONS(self):
        self._handle_request()

    def _handle_request(self):
        path = self.path
        clean_path = path.split('?')[0]

        # 1. API & Backend requests -> proxy to Django
        if (clean_path.startswith('/api/') or 
            clean_path.startswith('/health') or 
            clean_path.startswith('/admin/') or 
            clean_path.startswith('/media/')):
            self._proxy_to(BACKEND_URL + path)
            return

        # 2. If release build exists, serve static web build directly (super fast & multi-threaded!)
        if os.path.isdir(WEB_DIR) and self.command in ('GET', 'HEAD'):
            rel_path = clean_path.lstrip('/')
            file_path = os.path.join(WEB_DIR, rel_path)

            if os.path.isfile(file_path):
                self._serve_file(file_path)
                return
            elif not clean_path.startswith('/static/'):
                # SPA fallback: any page route serves index.html
                index_path = os.path.join(WEB_DIR, 'index.html')
                if os.path.isfile(index_path):
                    self._serve_file(index_path)
                    return

        # 3. Fallback: proxy to debug dev server if release build not found
        self._proxy_to(FRONTEND_URL + path)

    def _serve_file(self, file_path):
        mime, _ = mimetypes.guess_type(file_path)
        if not mime:
            mime = 'application/octet-stream'
        if file_path.endswith('.wasm'):
            mime = 'application/wasm'
        elif file_path.endswith('.js'):
            mime = 'application/javascript'
        elif file_path.endswith('.json'):
            mime = 'application/json'

        try:
            with open(file_path, 'rb') as f:
                content = f.read()
            self.send_response(200)
            self.send_header('Content-Type', mime)
            self.send_header('Content-Length', str(len(content)))
            if not file_path.endswith('index.html'):
                self.send_header('Cache-Control', 'public, max-age=86400')
            else:
                self.send_header('Cache-Control', 'no-cache')
            self.end_headers()
            if self.command != 'HEAD':
                self.wfile.write(content)
        except Exception as e:
            self.send_response(500)
            self.end_headers()
            self.wfile.write(str(e).encode('utf-8'))

    def _proxy_to(self, target_url):
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length) if content_length > 0 else None

        headers = {}
        for key, val in self.headers.items():
            if key.lower() not in ('host', 'content-length'):
                headers[key] = val

        req = urllib.request.Request(target_url, data=body, headers=headers, method=self.command)

        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                self.send_response(resp.status)
                for header, val in resp.getheaders():
                    if header.lower() not in ('transfer-encoding', 'connection', 'content-encoding'):
                        self.send_header(header, val)
                self.end_headers()
                self.wfile.write(resp.read())
        except urllib.error.HTTPError as e:
            self.send_response(e.code)
            for header, val in e.headers.items():
                if header.lower() not in ('transfer-encoding', 'connection', 'content-encoding'):
                    self.send_header(header, val)
            self.end_headers()
            self.wfile.write(e.read())
        except Exception as e:
            self.send_response(502)
            self.send_header('Content-Type', 'text/plain; charset=utf-8')
            self.end_headers()
            self.wfile.write(f"Proxy error connecting to {target_url}: {e}".encode('utf-8'))

    def log_message(self, format, *args):
        pass

if __name__ == '__main__':
    server = ThreadingHTTPServer(('0.0.0.0', PORT), ReverseProxyHandler)
    print(f"Threading reverse proxy listening on 0.0.0.0:{PORT}...")
    sys.stdout.flush()
    server.serve_forever()
