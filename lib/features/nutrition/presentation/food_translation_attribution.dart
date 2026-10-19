import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/widgets/bil_pearl_alert_dialog.dart';
import '../../community/presentation/community_translation_copy.dart';
import '../../settings/food_search_privacy_disclosure.dart';
import '../services/food_presentation_localizer.dart';

const googleTranslationWarrantyNotice =
    'THIS SERVICE MAY CONTAIN TRANSLATIONS POWERED BY GOOGLE. GOOGLE DISCLAIMS ALL WARRANTIES RELATED TO THE TRANSLATIONS, EXPRESS OR IMPLIED, INCLUDING ANY WARRANTIES OF ACCURACY, RELIABILITY, AND ANY IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.';

Future<void> showFoodTranslationInformation(BuildContext context) =>
    showDialog<void>(
      context: context,
      builder: (context) => BilPearlAlertDialog(
        title: Text(translationCopy(context, 6)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(foodSearchPrivacyDisclosure(context)),
              const SizedBox(height: 12),
              const Text(
                googleTranslationWarrantyNotice,
                textDirection: TextDirection.ltr,
              ),
              TextButton(
                onPressed: () => unawaited(
                  launchUrl(
                    Uri.parse('https://cloud.google.com/translate'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                child: const Text('Google Translate'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(MaterialLocalizations.of(context).closeButtonLabel),
          ),
        ],
      ),
    );

/// A cloud-generated display name always travels with the approved badge.
/// Canonical identity and nutrition remain independent of the display label.
class GoogleFoodNameText extends StatelessWidget {
  const GoogleFoodNameText({
    super.key,
    required this.name,
    required this.localeTag,
    this.arabicName,
    this.isCustom = false,
    this.source = '',
    this.style,
    this.maxLines,
    this.overflow,
    this.textDirection,
  });

  final String name;
  final String localeTag;
  final String? arabicName;
  final bool isCustom;
  final String source;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextDirection? textDirection;

  @override
  Widget build(BuildContext context) {
    String label(bool cloud) => FoodPresentationLocalizer.foodName(
      name: name,
      arabicName: arabicName,
      localeTag: localeTag,
      isCustom: isCustom,
      source: source,
      allowCloudTranslation: cloud,
    );
    final display = label(true);
    final text = Text(
      display,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      textDirection: textDirection,
    );
    if (display == label(false)) return text;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        text,
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Image.asset(
            Theme.of(context).brightness == Brightness.dark
                ? 'assets/branding/google_translate_white.png'
                : 'assets/branding/google_translate_color.png',
            key: const Key('food-google-translation-attribution'),
            height: 16,
            fit: BoxFit.contain,
            semanticLabel: 'Powered by Google Translate',
          ),
        ),
      ],
    );
  }
}
