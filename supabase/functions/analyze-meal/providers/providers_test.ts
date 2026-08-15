import { buildProviderRequest } from './builders.ts';
import { normalizeProviderResponse } from './normalize.ts';
import { ProviderConfig, VisionProviderError } from './types.ts';

const configs: Record<string, ProviderConfig> = {
  openai: { provider: 'openai', apiKey: 'test-only', model: 'openai-test', endpoint: 'https://example.test/openai' },
  gemini: { provider: 'gemini', apiKey: 'test-only', model: 'gemini-test', endpoint: 'https://example.test/gemini' },
  mistral: { provider: 'mistral', apiKey: 'test-only', model: 'mistral-test', endpoint: 'https://example.test/mistral' },
};
const modelJson = JSON.stringify({ candidates: [{ name: 'koshari', confidence: 0.9, evidence: 'visible bowl' }] });

Deno.test('builders keep secrets in headers and images in request bodies', () => {
  for (const config of Object.values(configs)) {
    const request = buildProviderRequest(config, { imageBase64: 'AAAA', mimeType: 'image/jpeg', requestedLocale: 'ar' });
    if (request.url.includes('test-only') || !request.body.includes('AAAA')) throw new Error('unsafe request construction');
  }
});

Deno.test('all provider envelopes normalize to the BIL schema', () => {
  const envelopes = {
    openai: { output: [{ content: [{ type: 'output_text', text: modelJson }] }], usage: { input_tokens: 10, output_tokens: 5 } },
    gemini: { candidates: [{ content: { parts: [{ text: modelJson }] } }], usageMetadata: { promptTokenCount: 10, candidatesTokenCount: 5 } },
    mistral: { choices: [{ message: { content: modelJson } }], usage: { prompt_tokens: 10, completion_tokens: 5 } },
  };
  for (const provider of Object.keys(configs)) {
    const result = normalizeProviderResponse(envelopes[provider as keyof typeof envelopes], configs[provider]);
    if (result.candidates[0].name !== 'koshari' || result.usage.cost_usd !== null) throw new Error('normalization failed');
  }
});

Deno.test('a provider markdown JSON fence is normalized without relaxing JSON parsing', () => {
  const fenced = `\`\`\`json\n${modelJson}\n\`\`\``;
  const result = normalizeProviderResponse(
    { candidates: [{ content: { parts: [{ text: fenced }] } }] }, configs.gemini);
  if (result.candidates[0].name !== 'koshari') throw new Error('fenced JSON normalization failed');
});

Deno.test('malformed candidates fail closed', () => {
  try {
    normalizeProviderResponse({ choices: [{ message: { content: '{"candidates":[{"name":"","confidence":2}]}' } }] }, configs.mistral);
    throw new Error('expected malformed response');
  } catch (error) {
    if (!(error instanceof VisionProviderError) || error.code !== 'malformed_response') throw error;
  }
});

Deno.test('empty low-confidence dish identity is a safe abstention', () => {
  const content = JSON.stringify({ candidates: [{
    name: 'visible soup', confidence: 0.9, evidence: 'visible bowl',
    dish_identity: { name: '', confidence: 0.2, alternatives: [] },
    visible_components: [{ name: 'beans', confidence: 0.92, evidence: 'visible beans' }],
  }] });
  const result = normalizeProviderResponse(
    { candidates: [{ content: { parts: [{ text: content }] } }] }, configs.gemini);
  if (result.candidates[0].dish_identity !== null ||
      result.candidates[0].visible_components[0].name !== 'beans') {
    throw new Error('abstention normalization failed');
  }
});

Deno.test('empty optional serving details normalize to null', () => {
  const content = JSON.stringify({ candidates: [{
    name: 'visible soup', confidence: 0.9, evidence: 'visible bowl',
    amount: 0, unit: '', uncertainty: '', alternatives: [], warnings: [],
  }] });
  const result = normalizeProviderResponse(
    { candidates: [{ content: { parts: [{ text: content }] } }] }, configs.gemini);
  const item = result.candidates[0];
  if (item.amount !== null || item.unit !== null || item.uncertainty !== null) {
    throw new Error('optional detail normalization failed');
  }
});

Deno.test('visual artifacts and seasoning are not food components', () => {
  const content = JSON.stringify({ candidates: [{
    name: 'chicken plate', confidence: 0.98, evidence: 'visible plate',
    visible_components: [
      { name: 'chicken', confidence: 0.98, evidence: 'visible meat' },
      { name: 'grill marks', confidence: 0.99, evidence: 'dark lines' },
      { name: 'orange seasoning/coating', confidence: 0.99, evidence: 'orange color' },
    ],
  }] });
  const result = normalizeProviderResponse(
    { candidates: [{ content: { parts: [{ text: content }] } }] }, configs.gemini);
  if (result.candidates[0].visible_components.length !== 1 ||
      result.candidates[0].visible_components[0].name !== 'chicken') {
    throw new Error('non-food component filtering failed');
  }
});

Deno.test('generic liquid descriptions abstain while ingredient-named sauces remain', () => {
  const content = JSON.stringify({ candidates: [{
    name: 'salmon plate', confidence: 0.98, evidence: 'visible plate',
    visible_components: [
      { name: 'salmon', confidence: 0.98, evidence: 'visible fish' },
      { name: 'red sauce', confidence: 0.99, evidence: 'red liquid' },
      { name: 'yellow broth/sauce', confidence: 0.99, evidence: 'yellow liquid' },
      { name: 'blueberry sauce', confidence: 0.98, evidence: 'visible berries in sauce' },
    ],
  }] });
  const result = normalizeProviderResponse(
    { candidates: [{ content: { parts: [{ text: content }] } }] }, configs.gemini);
  const names = result.candidates[0].visible_components.map((item) => item.name);
  if (names.join('|') !== 'salmon|blueberry sauce') {
    throw new Error('generic liquid abstention failed');
  }
});

Deno.test('surface artifacts are removed and visible foods are deduplicated', () => {
  const content = JSON.stringify({ candidates: [{
    name: 'salmon plate', confidence: 0.98, evidence: 'visible plate',
    visible_components: [
      { name: 'salmon', confidence: 0.98, evidence: 'visible fish' },
      { name: 'green herbs', confidence: 0.95, evidence: 'visible leaves' },
      { name: 'Green Herbs', confidence: 0.94, evidence: 'visible leaves' },
      { name: 'glossy glaze', confidence: 0.99, evidence: 'surface shine' },
      { name: 'roasted surface', confidence: 0.99, evidence: 'brown exterior' },
    ],
  }] });
  const result = normalizeProviderResponse(
    { candidates: [{ content: { parts: [{ text: content }] } }] }, configs.gemini);
  const names = result.candidates[0].visible_components.map((item) => item.name.toLowerCase());
  if (names.join('|') !== 'salmon|green herbs') {
    throw new Error('surface filtering or deduplication failed');
  }
});
