import { mealVisionPrompt } from './prompt.ts';
import { MealVisionInput, ProviderConfig, ProviderRequest } from './types.ts';

export function buildProviderRequest(config: ProviderConfig, input: MealVisionInput): ProviderRequest {
  const prompt = mealVisionPrompt(input.requestedLocale);
  const dataUrl = `data:${input.mimeType};base64,${input.imageBase64}`;
  if (config.provider === 'openai') return {
    url: config.endpoint,
    headers: { 'content-type': 'application/json', authorization: `Bearer ${config.apiKey}` },
    body: JSON.stringify({ model: config.model, input: [{ role: 'user', content: [
      { type: 'input_text', text: prompt }, { type: 'input_image', image_url: dataUrl },
    ] }], text: { format: { type: 'json_object' } } }),
  };
  if (config.provider === 'gemini') return {
    url: `${config.endpoint}/models/${encodeURIComponent(config.model)}:generateContent`,
    headers: { 'content-type': 'application/json', 'x-goog-api-key': config.apiKey },
    body: JSON.stringify({ contents: [{ role: 'user', parts: [
      { text: prompt }, { inline_data: { mime_type: input.mimeType, data: input.imageBase64 } },
    ] }], generationConfig: { responseMimeType: 'application/json' } }),
  };
  return {
    url: config.endpoint,
    headers: { 'content-type': 'application/json', authorization: `Bearer ${config.apiKey}` },
    body: JSON.stringify({ model: config.model, response_format: { type: 'json_object' }, messages: [
      { role: 'user', content: [{ type: 'text', text: prompt }, { type: 'image_url', image_url: dataUrl }] },
    ] }),
  };
}
