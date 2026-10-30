import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import test from 'node:test';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';

// The CLI modules have intentional privileged top-level entry points. Execute
// their exact request function declarations in an isolated lexical context,
// without importing a main routine or opening any credentials. Real Node fetch
// talks to two loopback servers; only endpoint constants are test dependencies.
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const modules = [
  {
    name: 'Google title',
    file: 'tool/google_play/google_play_title_update.mjs',
    start: 'async function request(', end: '\nconst credentialsPath', target: 'request',
  },
  {
    name: 'Google community link',
    file: 'tool/google_play/google_play_community_guidelines_link_update.mjs',
    start: 'async function request(', end: '\nconst credentialsPath', target: 'request',
  },
  {
    name: 'Google screenshots API',
    file: 'tool/store_media/pull_google_play_screenshots.mjs',
    start: 'async function api(', end: '\nfunction localGooglePlayInventory', target: 'api',
  },
];

function declaration(source, start, end) {
  const first = source.indexOf(start);
  assert.ok(first >= 0 && first === source.lastIndexOf(start), 'Unique actual function required');
  const last = source.indexOf(end, first);
  assert.ok(last > first, 'Actual function boundary must remain available');
  return source.slice(first, last).trim();
}

function digest(value) {
  return crypto.createHash('sha256').update(value).digest('hex');
}

function loadActualFunction(spec, endpoint) {
  const source = fs.readFileSync(path.join(root, spec.file), 'utf8');
  let selected = declaration(source, spec.start, spec.end);
  if (spec.oauth) {
    selected = declaration(source, 'function base64Url(', '\nfunction sha256') + '\n' + selected;
  }
  const context = vm.createContext({
    API_ROOT: endpoint, TOKEN_URL: endpoint, SCOPE: 'test-only-no-real-authority',
    Buffer, URLSearchParams, crypto,
    fetch(resource, options) {
      const url = new URL(resource);
      assert.equal(url.hostname, '127.0.0.1', 'No production request permitted');
      assert.equal(url.origin, new URL(endpoint).origin, 'Initial request must use the owned server');
      return fetch(resource, options);
    },
  });
  new vm.Script(`${selected}\nglobalThis.actualRequest = ${spec.target};`, {
    filename: spec.file,
  }).runInContext(context, { timeout: 1_000 });
  assert.equal(typeof context.actualRequest, 'function');
  return {
    request: context.actualRequest,
    moduleSha256: digest(source), functionSha256: digest(selected),
  };
}

async function listen(server) {
  await new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(0, '127.0.0.1', resolve);
  });
  return `http://127.0.0.1:${server.address().port}`;
}

async function stop(server) {
  server.closeAllConnections();
  await new Promise((resolve) => server.close(resolve));
}

async function recordRequest(request, collection) {
  const chunks = [];
  for await (const chunk of request) chunks.push(chunk);
  const body = Buffer.concat(chunks);
  collection.push({
    method: request.method,
    authorizationPresent: Boolean(request.headers.authorization),
    bodyBytes: body.length, bodySha256: digest(body),
  });
}

const rsa = crypto.generateKeyPairSync('rsa', { modulusLength: 2048 });

async function exercise(spec, method, redirectStatus) {
  const firstRequests = [], secondRequests = [];
  const second = http.createServer(async (request, response) => {
    await recordRequest(request, secondRequests);
    response.writeHead(200, { 'Content-Type': 'application/json' });
    response.end(JSON.stringify({ ok: true, access_token: 'LOCAL_FAKE_TOKEN' }));
  });
  let first;
  let actual;
  let requestError;
  let value;
  try {
    const secondUrl = await listen(second);
    first = http.createServer(async (request, response) => {
      await recordRequest(request, firstRequests);
      if (redirectStatus) {
        response.writeHead(redirectStatus, { Location: `${secondUrl}/unexpected-destination` });
        response.end();
      } else {
        response.writeHead(200, { 'Content-Type': 'application/json' });
        response.end(JSON.stringify({ ok: true, access_token: 'LOCAL_FAKE_TOKEN' }));
      }
    });
    const firstUrl = await listen(first);
    actual = loadActualFunction(spec, firstUrl);
    try {
      value = spec.oauth
        ? await actual.request({ client_email: 'qa-only@example.invalid', private_key: rsa.privateKey })
        : await actual.request('LOCAL_FAKE_BEARER', method, '/probe',
          method === 'POST' ? { sentinel: 'PUBLIC_TEST_PAYLOAD_NO_USER_DATA' } : undefined);
    } catch (error) {
      requestError = error;
    }
    const evidenceDirectory = process.env.BIL_GOOGLE_REDIRECT_EVIDENCE_DIR;
    if (evidenceDirectory) {
      fs.mkdirSync(evidenceDirectory, { recursive: true });
      fs.appendFileSync(path.join(evidenceDirectory, 'request-observations.jsonl'), JSON.stringify({
        name: spec.name, source: spec.file, method, redirectStatus,
        moduleSha256: actual.moduleSha256, functionSha256: actual.functionSha256,
        firstRequests, secondRequests,
        rejected: Boolean(requestError), errorName: requestError?.name ?? null,
        errorCause: requestError?.cause?.message ?? null,
        credentialSource: spec.oauth ? 'Ephemeral RSA generated in memory' : 'Fake sentinel only',
        productionRequests: 0, realCredentialFilesRead: 0,
      }) + '\n');
    }
    assert.equal(firstRequests.length, 1, 'Exactly one real request must reach the owned source server');
    if (redirectStatus) {
      assert.ok(requestError, 'The actual helper must reject a redirect');
      assert.equal(secondRequests.length, 0, 'A redirect must never reach the other origin');
    } else {
      assert.equal(requestError, undefined, 'A direct valid response must still succeed');
      assert.equal(secondRequests.length, 0);
      assert.ok(value !== undefined);
    }
  } finally {
    if (first) await stop(first);
    await stop(second);
  }
}

for (const spec of modules) {
  test(`${spec.name}: direct response remains supported`, { timeout: 8_000 }, () =>
    exercise(spec, 'GET', 0));
  test(`${spec.name}: GET302 cannot leave the requested origin`, { timeout: 8_000 }, () =>
    exercise(spec, 'GET', 302));
  test(`${spec.name}: POST307 cannot forward its body to another origin`, { timeout: 8_000 }, () =>
    exercise(spec, 'POST', 307));
}

const oauth = {
  name: 'Screenshot OAuth assertion',
  file: 'tool/store_media/pull_google_play_screenshots.mjs',
  start: 'async function googleToken(', end: '\nasync function api(',
  target: 'googleToken', oauth: true,
};
test('Screenshot OAuth: direct token response remains supported', { timeout: 8_000 }, () =>
  exercise(oauth, 'POST', 0));
test('Screenshot OAuth: POST307 cannot forward the signed test assertion', { timeout: 8_000 }, () =>
  exercise(oauth, 'POST', 307));
