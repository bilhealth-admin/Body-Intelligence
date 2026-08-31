#!/usr/bin/env node

import crypto from 'node:crypto';
import fs from 'node:fs';

const ENDPOINT =
  'https://tgmanzhqulksykhslrzb.supabase.co/functions/v1/verify-store-purchase';
const GOOGLE_PLAY_PUBLISHER =
  'serviceAccount:google-play-developer-notifications@system.gserviceaccount.com';

function base64url(value) {
  return Buffer.from(value).toString('base64url');
}

function resourceHash(value) {
  return crypto.createHash('sha256').update(String(value)).digest('hex').slice(0, 12);
}

async function accessToken(credential) {
  const now = Math.floor(Date.now() / 1000);
  const header = base64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const payload = base64url(
    JSON.stringify({
      iss: credential.client_email,
      scope: 'https://www.googleapis.com/auth/cloud-platform',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
    }),
  );
  const unsigned = `${header}.${payload}`;
  const signature = crypto
    .sign('RSA-SHA256', Buffer.from(unsigned), credential.private_key)
    .toString('base64url');
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: `${unsigned}.${signature}`,
    }),
  });
  if (!response.ok) {
    return { status: response.status, token: null };
  }
  const body = await response.json();
  return { status: response.status, token: body.access_token ?? null };
}

async function googleGet(url, token) {
  const response = await fetch(url, {
    headers: { authorization: `Bearer ${token}` },
  });
  let body = {};
  try {
    body = await response.json();
  } catch {
    // The audit reports only HTTP status and redacted structural facts.
  }
  return { status: response.status, body };
}

async function audit(credentialPath, label) {
  const credential = JSON.parse(fs.readFileSync(credentialPath, 'utf8'));
  const tokenResult = await accessToken(credential);
  const result = {
    label,
    oauth_status: tokenResult.status,
    topics_list_status: null,
    subscriptions_list_status: null,
    topic_count: 0,
    subscription_count: 0,
    push_endpoint_matches: [],
    topic_publisher_bindings: [],
  };
  if (!tokenResult.token) return result;

  const project = `projects/${credential.project_id}`;
  const topicsResult = await googleGet(
    `https://pubsub.googleapis.com/v1/${project}/topics?pageSize=1000`,
    tokenResult.token,
  );
  const subscriptionsResult = await googleGet(
    `https://pubsub.googleapis.com/v1/${project}/subscriptions?pageSize=1000`,
    tokenResult.token,
  );
  result.topics_list_status = topicsResult.status;
  result.subscriptions_list_status = subscriptionsResult.status;

  const topics = Array.isArray(topicsResult.body.topics)
    ? topicsResult.body.topics
    : [];
  const subscriptions = Array.isArray(subscriptionsResult.body.subscriptions)
    ? subscriptionsResult.body.subscriptions
    : [];
  result.topic_count = topics.length;
  result.subscription_count = subscriptions.length;

  result.push_endpoint_matches = subscriptions
    .filter((subscription) => subscription.pushConfig?.pushEndpoint === ENDPOINT)
    .map((subscription) => ({
      subscription_hash: resourceHash(subscription.name),
      topic_hash: resourceHash(subscription.topic),
      oidc_service_account_present: Boolean(
        subscription.pushConfig?.oidcToken?.serviceAccountEmail,
      ),
      oidc_service_account_hash: subscription.pushConfig?.oidcToken
          ?.serviceAccountEmail
        ? resourceHash(subscription.pushConfig.oidcToken.serviceAccountEmail)
        : null,
      audience_exact: subscription.pushConfig?.oidcToken?.audience === ENDPOINT,
      dead_letter_policy_present: Boolean(subscription.deadLetterPolicy),
      retry_policy_present: Boolean(subscription.retryPolicy),
    }));

  for (const topic of topics) {
    const policy = await googleGet(
      `https://pubsub.googleapis.com/v1/${topic.name}:getIamPolicy`,
      tokenResult.token,
    );
    const bindings = Array.isArray(policy.body.bindings)
      ? policy.body.bindings
      : [];
    result.topic_publisher_bindings.push({
      topic_hash: resourceHash(topic.name),
      http_status: policy.status,
      google_play_publisher_granted: bindings.some(
        (binding) =>
          binding.role === 'roles/pubsub.publisher' &&
          Array.isArray(binding.members) &&
          binding.members.includes(GOOGLE_PLAY_PUBLISHER),
      ),
    });
  }
  return result;
}

const credentialPaths = process.argv.slice(2);
if (credentialPaths.length === 0) {
  console.error('Usage: node google_pubsub_readiness_audit.mjs <credential.json> [...]');
  process.exit(2);
}

const results = [];
for (let index = 0; index < credentialPaths.length; index += 1) {
  results.push(await audit(credentialPaths[index], `credential-${index + 1}`));
}

console.log(
  JSON.stringify(
    {
      audited_at: new Date().toISOString(),
      endpoint_hash: resourceHash(ENDPOINT),
      credentials: results,
    },
    null,
    2,
  ),
);
