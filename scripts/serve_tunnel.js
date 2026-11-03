const http = require('http');
const fs = require('fs');
const path = require('path');

const root = path.resolve(process.argv[2] || 'mobile/build/web');
const port = Number(process.argv[3] || 3100);

const types = {
  '.html': 'text/html',
  '.js': 'text/javascript',
  '.mjs': 'text/javascript',
  '.json': 'application/json',
  '.css': 'text/css',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.wasm': 'application/wasm',
  '.otf': 'font/otf',
  '.ttf': 'font/ttf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2'
};

const server = http.createServer((req, res) => {
  if (req.url.startsWith('/api') || req.url.startsWith('/media')) {
    const headers = { ...req.headers, host: '127.0.0.1:8000' };
    const options = {
      host: '127.0.0.1',
      port: 8000,
      path: req.url,
      method: req.method,
      headers: headers
    };
    const p = http.request(options, r => {
      res.writeHead(r.statusCode, r.headers);
      r.pipe(res);
    });
    p.on('error', () => {
      res.writeHead(502, { 'Content-Type': 'text/plain' });
      res.end('Backend indisponible');
    });
    req.pipe(p);
    return;
  }

  let filePath = path.join(root, decodeURIComponent(req.url.split('?')[0]));
  if (!filePath.startsWith(root) || !fs.existsSync(filePath) || fs.statSync(filePath).isDirectory()) {
    filePath = path.join(root, 'index.html');
  }

  const ext = path.extname(filePath);
  const contentType = types[ext] || 'application/octet-stream';

  res.writeHead(200, {
    'Content-Type': contentType,
    'Cache-Control': 'no-cache'
  });
  fs.createReadStream(filePath).pipe(res);
});

server.listen(port, '127.0.0.1', () => {
  console.log(`Serveur tunnel actif sur http://127.0.0.1:${port} avec racine ${root}`);
});

