export type MealVisionConsent = {
  granted?: boolean | null;
  policy_version?: string | null;
} | null;

export const mealVisionConsentIsCurrent = (
  consent: MealVisionConsent,
): boolean => consent?.granted === true && consent.policy_version === "1";

// The consent shown in the app names Google Gemini. A configured gateway or
// another provider is not covered by that consent.
export const mealVisionConsentProvider = "gemini" as const;

export const mealVisionProviderMatchesConsent = (
  provider: string | null | undefined,
): boolean =>
  provider?.trim().toLowerCase() === mealVisionConsentProvider;

// Supplemental scope only; the original photo-purpose grant and withdrawal
// stay mandatory. A nutrition receipt never authorizes uploading on its own.
export const mealVisionNutritionConsentPurpose = "meal_vision_nutrition_ai";
