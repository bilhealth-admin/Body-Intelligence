export type MealVisionConsent = {
  granted?: boolean | null;
  policy_version?: string | null;
} | null;

export const mealVisionConsentIsCurrent = (
  consent: MealVisionConsent,
): boolean => consent?.granted === true && consent.policy_version === "1";
