import { ProviderConfig, VisionProviderError, VisionProviderName } from './types.ts';

export type EnvReader = (name: string) => string | undefined;

const defaults: Record<VisionProviderName, { model: string; endpoint: string }> = {
  openai: { model: 'gpt-4.1-mini', endpoint: 'https://api.openai.com/v1/responses' },
  gemini: { model: 'gemini-2.5-flash', endpoint: 'https://generativelanguage.googleapis.com/v1beta' },
  mistral: { model: 'pixtral-large-latest', endpoint: 'https://api.mistral.ai/v1/chat/completions' },
};

const names: Record<VisionProviderName, { key: string; model: string; endpoint: string }> = {
  openai: { key: 'BIL_OPENAI_API_KEY', model: 'BIL_OPENAI_VISION_MODEL', endpoint: 'BIL_OPENAI_VISION_ENDPOINT' },
  gemini: { key: 'BIL_GEMINI_API_KEY', model: 'BIL_GEMINI_VISION_MODEL', endpoint: 'BIL_GEMINI_VISION_ENDPOINT' },
  mistral: { key: 'BIL_MISTRAL_API_KEY', model: 'BIL_MISTRAL_VISION_MODEL', endpoint: 'BIL_MISTRAL_VISION_ENDPOINT' },
};

export function loadProviderConfig(provider: VisionProviderName, env: EnvReader): ProviderConfig {
  const spec = names[provider];
  const apiKey = env(spec.key)?.trim() ?? '';
  if (!apiKey) throw new VisionProviderError('not_configured', `${spec.key} is not configured`, provider);
  const model = env(spec.model)?.trim() || defaults[provider].model;
  const endpoint = env(spec.endpoint)?.trim() || defaults[provider].endpoint;
  let parsed: URL;
  try { parsed = new URL(endpoint); } catch { throw new VisionProviderError('not_configured', `${spec.endpoint} is invalid`, provider); }
  if (parsed.protocol !== 'https:') throw new VisionProviderError('not_configured', `${spec.endpoint} must use HTTPS`, provider);
  return { provider, apiKey, model, endpoint: parsed.toString().replace(/\/$/, '') };
}
