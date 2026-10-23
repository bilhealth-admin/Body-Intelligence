// QA-only local replacement for the OS channel. Keys travel through stdin;
// nothing is sent to a service or written to disk. This is real AES-GCM,
// not a plaintext envelope or proof of CryptoKit/Keychain on a physical iPhone.
import { createCipheriv, createDecipheriv, randomBytes } from 'node:crypto';
import { createInterface } from 'node:readline';

for await (const line of createInterface({ input: process.stdin })) {
  let request;
  try {
    request = JSON.parse(line);
    const key = Buffer.from(request.key, 'base64');
    if (key.length !== 32) throw new Error('Invalid key length');
    let result;
    if (request.method === 'encryptAes256Gcm') {
      const nonce = randomBytes(12);
      const cipher = createCipheriv('aes-256-gcm', key, nonce);
      const ciphertext = Buffer.concat([
        cipher.update(Buffer.from(request.plaintext, 'base64')), cipher.final(),
        cipher.getAuthTag(),
      ]);
      result = { nonce: nonce.toString('base64'), protected: ciphertext.toString('base64') };
    } else if (request.method === 'decryptAes256Gcm') {
      const nonce = Buffer.from(request.nonce, 'base64');
      const bytes = Buffer.from(request.protected, 'base64');
      if (nonce.length !== 12 || bytes.length < 16) throw new Error('Invalid envelope');
      const cipher = createDecipheriv('aes-256-gcm', key, nonce);
      cipher.setAuthTag(bytes.subarray(-16));
      result = { plaintext: Buffer.concat([
        cipher.update(bytes.subarray(0, -16)), cipher.final(),
      ]).toString('base64') };
    } else throw new Error('Unsupported operation');
    process.stdout.write(JSON.stringify({ id: request.id, ok: true, ...result }) + '\n');
  } catch {
    // Never log input, key material, plaintext, or an exception containing it.
    process.stdout.write(JSON.stringify({ id: request?.id, ok: false }) + '\n');
  }
}
