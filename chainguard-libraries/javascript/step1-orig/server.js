#!/usr/bin/env node

const http = require('http');
const { v4: uuidv4 } = require('uuid');
const _ = require('lodash');

const PORT = process.env.PORT || 3000;

const requests = [];

function sendJson(res, data, status = 200) {
  const body = JSON.stringify(data, null, 2);
  res.writeHead(status, {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(body)
  });
  res.end(body);
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://localhost:${PORT}`);

  if (req.method !== 'GET') {
    return sendJson(res, { error: 'Method not allowed' }, 405);
  }

  if (url.pathname === '/') {
    return sendJson(res, {
      message: 'Welcome to Chainguard Libraries for JavaScript Demo',
      version: '1.0.0',
      timestamp: new Date().toISOString(),
      libraries: _.map(['lodash', 'uuid'], _.startCase)
    });
  }

  if (url.pathname === '/api/health') {
    return sendJson(res, {
      status: 'healthy',
      uptime: _.round(process.uptime(), 2),
      timestamp: new Date().toISOString()
    });
  }

  if (url.pathname === '/api/uuid') {
    const entry = { id: uuidv4(), timestamp: new Date().toISOString() };
    requests.push(entry);
    return sendJson(res, {
      uuid: entry.id,
      totalRequests: requests.length
    });
  }

  if (url.pathname === '/api/requests') {
    const limit = parseInt(url.searchParams.get('limit')) || 10;
    return sendJson(res, {
      requests: _.takeRight(requests, limit),
      total: requests.length
    });
  }

  sendJson(res, { error: 'Not found' }, 404);
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`lodash version: ${require('lodash/package.json').version}`);
  console.log(`uuid version: ${require('uuid/package.json').version}`);
  console.log(`Node.js version: ${process.version}`);
});
