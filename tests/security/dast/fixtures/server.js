const http = require('http');
const port = Number(process.argv[2] || 18080);
const server = http.createServer((req, res) => {
  res.writeHead(200, {'content-type': 'text/html'});
  res.end('<!doctype html><title>DevShield DAST fixture</title><h1>Test application</h1>');
});
server.listen(port, '127.0.0.1', () => console.log(`DAST fixture listening on ${port}`));
process.on('SIGTERM', () => server.close(() => process.exit(0)));
