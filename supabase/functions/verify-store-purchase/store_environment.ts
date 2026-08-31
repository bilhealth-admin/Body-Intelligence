export type StoreEnvironment = 'sandbox' | 'production';

export function verifiedStoreEnvironment(value: unknown): StoreEnvironment {
  const normalized = String(value ?? '').trim().toLowerCase();
  if (normalized === 'sandbox' || normalized === 'production') return normalized;
  throw new Error('wrong_environment');
}

export function googleSubscriptionEnvironment(testPurchase: unknown): StoreEnvironment {
  return testPurchase ? 'sandbox' : 'production';
}

export function googleProductEnvironment(purchaseType: unknown): StoreEnvironment {
  return Number(purchaseType ?? -1) === 0 ? 'sandbox' : 'production';
}

export function appleServerHost(environment: StoreEnvironment): string {
  return environment === 'sandbox'
    ? 'api.storekit-sandbox.itunes.apple.com'
    : 'api.storekit.itunes.apple.com';
}
