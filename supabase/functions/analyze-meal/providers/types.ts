export type VisionProviderName = 'openai' | 'gemini' | 'mistral';

export type ProviderConfig = {
  provider: VisionProviderName;
  apiKey: string;
  model: string;
  endpoint: string;
};

export type MealVisionInput = {
  imageBase64: string;
  mimeType: 'image/jpeg' | 'image/png' | 'image/webp';
  requestedLocale: string;
};

export type ProviderRequest = {
  url: string;
  headers: Record<string, string>;
  body: string;
};

export type BilVisionCandidate = {
  name: string;
  confidence: number;
  evidence: string;
  amount: number | null;
  unit: string | null;
  alternatives: Array<{ name: string; confidence: number }>;
  uncertainty: string | null;
  warnings: string[];
  dish_identity: {
    name: string;
    confidence: number;
    alternatives: Array<{ name: string; confidence: number }>;
  } | null;
  visible_components: Array<{
    name: string;
    confidence: number;
    evidence: string;
  }>;
  provenance: {
    identification_provider: VisionProviderName;
    model_revision: string;
    nutrition_resolution: 'requires_verified_food_match';
  };
};

export type NormalizedProviderResult = {
  schema_version: 1;
  candidates: BilVisionCandidate[];
  usage: {
    input_tokens: number | null;
    output_tokens: number | null;
    cost_usd: number | null;
  };
};

export class VisionProviderError extends Error {
  constructor(
    readonly code: 'not_configured' | 'malformed_response' | 'provider_error',
    message: string,
    readonly provider?: VisionProviderName,
  ) {
    super(message);
    this.name = 'VisionProviderError';
  }
}
