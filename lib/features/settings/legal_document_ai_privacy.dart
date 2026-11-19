part of 'legal_document_page.dart';

const _aiCoachPrivacyDisclosure =
    'BIL sends your questions and only the categories you select—weight, goals and measurements; meals, nutrition, water and preferences; activity and training; sleep and habits; plus up to 12 recent conversation turns—to Google Gemini, a third-party AI service operated by Google, to generate requested answers. Raw microphone audio is not sent. You can decline and keep using local features, or withdraw later in AI Coach settings.';
const _mealVisionPrivacyDisclosure =
    'If you agree, BIL sends the photo you select, your app language, and necessary technical request metadata to Google Gemini, a third-party AI service operated by Google. It is used to suggest foods and portions for your review. Nothing is logged until you confirm the results.\n\nYou can decline and continue with manual food entry. You can withdraw consent later in Privacy settings.';
const _combinedAiPrivacyDisclosure =
    '$_aiCoachPrivacyDisclosure $_mealVisionPrivacyDisclosure';

bool _includeGeminiEstimatePrivacy(BilLegalDocument document) =>
    document == BilLegalDocument.privacy &&
    const bool.fromEnvironment('BIL_GEMINI_PHOTO_ESTIMATES_V2');

(String, String) _geminiEstimatePrivacySection(BuildContext context) =>
    ('BIL Vision · Google Gemini · 2026-11-18', geminiEstimateCopy(context, 3));
