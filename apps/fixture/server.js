'use strict';
const http = require('node:http');
const port = Number(process.env.PORT || 3000);
const server = http.createServer((request, response) => {
  if (request.url === '/health') { response.writeHead(200, {'content-type':'application/json'}); response.end('{"status":"ok"}\n'); return; }
  response.writeHead(200, {'content-type':'text/plain'}); response.end('DevShield container fixture\n');
});
server.listen(port, '0.0.0.0');
