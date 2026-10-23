'use strict';
// Accident-prevention for reviewed fixture tests, not a hostile-code sandbox.
const denied = () => { throw new Error('BIL_FIXTURE_NETWORK_DENIED'); };
globalThis.fetch = denied;
for (const name of ['node:http', 'node:https']) {
  const transport = require(name);
  transport.request = denied;
  transport.get = denied;
}
const net = require('node:net');
net.connect = denied;
net.createConnection = denied;
net.Socket.prototype.connect = denied;
require('node:tls').connect = denied;
require('node:dgram').createSocket = denied;
require('node:http2').connect = denied;
const dns = require('node:dns');
for (const api of [dns, dns.promises, dns.Resolver.prototype, dns.promises.Resolver.prototype]) {
  for (const name of Object.getOwnPropertyNames(api)) {
    if (/^(lookup|resolve|reverse)/.test(name) && typeof api[name] === 'function') api[name] = denied;
  }
}
require('node:module').syncBuiltinESMExports();
// Node's warning switch accepts a category, not a message. Restore every other
// warning in that category, dropping only our own fixed permission opt-in note.
const ownPermissionNote = 'The flag --allow-child-process must be used with extreme caution. It could invalidate the permission model.';
process.on('warning', warning => {
  if (warning.name === 'SecurityWarning' && warning.message !== ownPermissionNote) {
    process.stderr.write((warning.stack ?? `${warning.name}: ${warning.message}`) + '\n');
  }
});
