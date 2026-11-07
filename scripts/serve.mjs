import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../build/web');
const types = {'.html':'text/html','.js':'text/javascript','.wasm':'application/wasm','.pck':'application/octet-stream','.png':'image/png','.svg':'image/svg+xml','.json':'application/json'};
const port = Number(process.env.PORT || 8080);
http.createServer((req,res)=>{
  let pathname;
  try { pathname = decodeURIComponent(new URL(req.url,'http://localhost').pathname); } catch {res.writeHead(400).end(); return;}
  const file = path.resolve(root,'.'+(pathname === '/' ? '/index.html' : pathname));
  if (!file.startsWith(root+path.sep)) {res.writeHead(403).end(); return;}
  fs.stat(file,(error,stat)=>{
    if (error || !stat.isFile()) {res.writeHead(404).end('Not found'); return;}
    res.writeHead(200,{'Content-Type':types[path.extname(file)] || 'application/octet-stream','Content-Length':stat.size,'Cache-Control':'no-cache','X-Content-Type-Options':'nosniff'});
    fs.createReadStream(file).pipe(res);
  });
}).listen(port,'0.0.0.0',()=>console.log(`ARENA: http://localhost:${port} (Android: use this computer's LAN IP and port ${port})`));
