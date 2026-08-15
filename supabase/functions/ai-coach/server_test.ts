import { assertEquals, assertThrows } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { boundedMessages, handler, parseModelJson, responseLanguage } from './server.ts';

Deno.test('message contract is bounded and ends with a user message', () => {
  assertEquals(boundedMessages([
    { role: 'assistant', content: 'ready' },
    { role: 'user', content: 'hello' },
  ]).length, 2);
  assertThrows(() => boundedMessages([{ role: 'assistant', content: 'done' }]));
  assertThrows(() => boundedMessages([{ role: 'user', content: 'x'.repeat(4001) }]));
});

Deno.test('response language is independent from interface locale', () => {
  assertEquals(responseLanguage([
    { role: 'user', content: 'أعطني نصيحة عامة قصيرة لتحسين النوم' },
  ], 'en'), 'ar');
  assertEquals(responseLanguage([
    { role: 'user', content: 'Give me one short general sleep tip' },
  ], 'ar'), 'en');
  assertEquals(responseLanguage([
    { role: 'user', content: 'Скільки калорій залишилось?' },
  ], 'en'), 'uk');
});

Deno.test('model actions are allow-listed and confirmation-gated', () => {
  const parsed = parseModelJson(JSON.stringify({
    reply: 'I can prepare that.',
    spoken_reply: 'I can prepare that after your confirmation.',
    proposed_actions: [
      { type: 'log_water', arguments: { amountMl: 250 }, requires_confirmation: false },
      { type: 'run_sql', arguments: { sql: 'drop table profiles' } },
    ],
  }));
  assertEquals(parsed.proposed_actions, [{
    type: 'log_water', arguments: { amountMl: 250 }, requires_confirmation: true,
  }]);
  assertEquals(parsed.spoken_reply, 'I can prepare that after your confirmation.');
  assertThrows(() => parseModelJson(JSON.stringify({
    reply: 'Safe written answer.',
    spoken_reply: '* not a spoken sentence',
    proposed_actions: [],
  })));
});

Deno.test('HTTP boundary rejects unsupported methods and missing auth', async () => {
  assertEquals((await handler(new Request('https://example.test', { method: 'GET' }))).status, 405);
  const response = await handler(new Request('https://example.test', {
    method: 'POST', body: '{}', headers: { 'content-type': 'application/json' },
  }));
  assertEquals(response.status, 401);
  assertEquals(await response.json(), { error: 'authentication_required' });
});

function requestBody(requestId = 'coach-test-request-0001') {
  return new Request('https://example.test', {
    method: 'POST',
    headers: { authorization: 'Bearer test', 'content-type': 'application/json' },
    body: JSON.stringify({
      request_id: requestId,
      locale: 'en',
      messages: [{ role: 'user', content: 'Give one short sleep tip' }],
      context: {},
    }),
  });
}

function fakeClients(reservations: Array<Record<string, unknown>>) {
  const settlements: Array<Record<string, unknown>> = [];
  return {
    settlements,
    create: (_authorization: string) => ({
      auth: { auth: { getUser: async () => ({ data: { user: { id: '00000000-0000-4000-8000-000000000001' } }, error: null }) } },
      admin: {
        rpc: async (name: string, params: Record<string, unknown>) => {
          if (name === 'bil_reserve_ai_usage') {
            return { data: reservations.shift() ?? { duplicate: true, state: 'succeeded' }, error: null };
          }
          settlements.push(params);
          return { data: { state: params.p_succeeded ? 'succeeded' : 'refunded' }, error: null };
        },
      },
    }),
  };
}

Deno.test('provider timeout refunds exactly one established reservation', async () => {
  const fake = fakeClients([{ duplicate: false, state: 'reserved' }]);
  const response = await handler(requestBody(), {
    clients: fake.create as never,
    geminiCall: async () => { throw new Error('provider_timeout'); },
    now: (() => { let value = 1000; return () => value += 10; })(),
  });
  assertEquals(response.status, 503);
  assertEquals(fake.settlements.length, 1);
  assertEquals(fake.settlements[0].p_succeeded, false);
});

Deno.test('malformed provider JSON refunds rather than charging', async () => {
  const fake = fakeClients([{ duplicate: false, state: 'reserved' }]);
  const response = await handler(requestBody(), {
    clients: fake.create as never,
    geminiCall: async () => ({
      attempts: 1,
      data: { candidates: [{ content: { parts: [{ text: '{"reply":"missing spoken"}' }] } }] },
    }),
  });
  assertEquals(response.status, 503);
  assertEquals(fake.settlements.length, 1);
  assertEquals(fake.settlements[0].p_succeeded, false);
});

Deno.test('duplicate request never calls provider or settles twice', async () => {
  const fake = fakeClients([{ duplicate: true, state: 'succeeded' }]);
  let providerCalls = 0;
  const response = await handler(requestBody('coach-test-request-duplicate'), {
    clients: fake.create as never,
    geminiCall: async () => {
      providerCalls += 1;
      throw new Error('must_not_run');
    },
  });
  assertEquals(response.status, 409);
  assertEquals(providerCalls, 0);
  assertEquals(fake.settlements.length, 0);
});

Deno.test('reservation failure does not attempt settlement', async () => {
  const settlements: Array<Record<string, unknown>> = [];
  const response = await handler(requestBody('coach-test-reserve-failure'), {
    clients: ((_authorization: string) => ({
      auth: { auth: { getUser: async () => ({ data: { user: { id: '00000000-0000-4000-8000-000000000001' } }, error: null }) } },
      admin: { rpc: async (name: string, params: Record<string, unknown>) => {
        if (name === 'bil_reserve_ai_usage') return { data: null, error: { message: 'database unavailable' } };
        settlements.push(params);
        return { data: null, error: null };
      } },
    })) as never,
  });
  assertEquals(response.status, 503);
  assertEquals(settlements.length, 0);
});
