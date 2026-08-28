import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/environment/app_environment.dart';
import '../../../app/localization/bil_locale_policy.dart';
import '../../nutrition/domain/product_identity.dart';
import '../data/community_repository.dart';
import '../domain/community_models.dart';
import '../domain/community_text_policy.dart';
import 'community_copy.dart';

Future<bool> showProductReviewSubmissionDialog(
  BuildContext context, {
  required String barcode,
  ProductIdentity? suggestedProduct,
}) async {
  final languageCode = BilLocalePolicy.canonicalTag(
    Localizations.localeOf(context),
  );
  String t(String en, String ar) =>
      communityTextForLanguage(languageCode, en, ar);
  if (!AppEnvironment.cloudConfigured ||
      Supabase.instance.client.auth.currentUser == null) {
    final signIn = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t('Sign-in required', 'يلزم تسجيل الدخول')),
        content: Text(
          t(
            'Submitting a product for review requires an account. BIL will not upload or guess nutrition values, and the barcode stays on this device until you sign in.',
            'إرسال المنتج للمراجعة يحتاج حسابًا. لن نرفع قيمًا غذائية أو نخمنها، وسيبقى الباركود على جهازك حتى تسجل الدخول.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t('Not now', 'ليس الآن')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(t('Sign in', 'تسجيل الدخول')),
          ),
        ],
      ),
    );
    if (signIn == true && context.mounted) context.push('/login');
    return false;
  }

  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ProductReviewSubmissionDialog(
          barcode: barcode,
          suggestedProduct: suggestedProduct,
          languageCode: languageCode,
        ),
      ) ??
      false;
}

class _ProductReviewSubmissionDialog extends StatefulWidget {
  const _ProductReviewSubmissionDialog({
    required this.barcode,
    required this.languageCode,
    this.suggestedProduct,
  });

  final String barcode;
  final ProductIdentity? suggestedProduct;
  final String languageCode;

  @override
  State<_ProductReviewSubmissionDialog> createState() =>
      _ProductReviewSubmissionDialogState();
}

class _ProductReviewSubmissionDialogState
    extends State<_ProductReviewSubmissionDialog> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController name;
  late final TextEditingController brand;
  late final TextEditingController country;
  late final TextEditingController evidence;
  late final TextEditingController note;
  late ProductKind kind;
  bool submitting = false;

  bool get arabic => widget.languageCode == 'ar';
  String _t(String en, String ar) =>
      communityTextForLanguage(widget.languageCode, en, ar);

  @override
  void initState() {
    super.initState();
    final product = widget.suggestedProduct;
    name = TextEditingController(
      text: arabic && product?.arabicName?.trim().isNotEmpty == true
          ? product!.arabicName
          : product?.name,
    );
    brand = TextEditingController(text: product?.brand);
    country = TextEditingController();
    evidence = TextEditingController();
    note = TextEditingController();
    kind = product?.kind ?? ProductKind.unknown;
  }

  @override
  void dispose() {
    name.dispose();
    brand.dispose();
    country.dispose();
    evidence.dispose();
    note.dispose();
    super.dispose();
  }

  String _kindLabel(ProductKind value) => switch (value) {
    ProductKind.food => _t('Food', 'غذاء'),
    ProductKind.beverage => _t('Beverage', 'مشروب'),
    ProductKind.alcohol => _t('Alcohol', 'مشروب كحولي'),
    ProductKind.supplement => _t('Supplement', 'مكمل غذائي'),
    ProductKind.medicine => _t('Medicine', 'دواء'),
    ProductKind.tobacco => _t('Tobacco', 'تبغ'),
    ProductKind.personalCare => _t('Personal care', 'عناية أو تجميل'),
    ProductKind.petFood => _t('Pet food', 'غذاء حيوانات'),
    ProductKind.household => _t('Household', 'منظف أو منتج منزلي'),
    ProductKind.generalProduct => _t('General product', 'منتج عام'),
    ProductKind.unknown => _t('Unknown', 'غير معروف'),
  };

  String? _optional(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _submit() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    setState(() => submitting = true);
    try {
      await CommunityRepository(Supabase.instance.client).submitProductReview(
        ProductReviewDraft(
          name: name.text.trim(),
          barcode: widget.barcode,
          kind: kind,
          brand: _optional(brand.text),
          countryCode: _optional(country.text),
          evidenceUrl: _optional(evidence.text),
          note: _optional(note.text),
          observedSource: widget.suggestedProduct?.source,
          observedConfidence: widget.suggestedProduct?.confidence,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } on CommunityTextPolicyException catch (error) {
      if (!mounted) return;
      setState(() => submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.localizedMessage(
              Localizations.localeOf(context).toLanguageTag(),
            ),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Could not submit the product. Check the connection and try again.',
              'تعذر إرسال المنتج. تحقق من الاتصال وحاول مجددًا.',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(_t('Submit product for review', 'إرسال منتج للمراجعة')),
    content: SizedBox(
      width: 480,
      child: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _t(
                  'This product will not become verified or searchable until a moderator reviews it. Do not submit estimated nutrition values.',
                  'لن يصبح المنتج موثقًا أو ظاهرًا في البحث حتى يراجعه مشرف. لا تُرسل قيمًا غذائية تخمينية.',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: name,
                decoration: InputDecoration(
                  labelText: _t('Product name', 'اسم المنتج'),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? _t('Enter the product name', 'أدخل اسم المنتج')
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: widget.barcode,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: _t('Barcode', 'الباركود'),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ProductKind>(
                initialValue: kind,
                decoration: InputDecoration(
                  labelText: _t('Product type', 'نوع المنتج'),
                ),
                items: ProductKind.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(_kindLabel(value)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) => setState(() {
                  kind = value ?? ProductKind.unknown;
                }),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: brand,
                decoration: InputDecoration(
                  labelText: _t(
                    'Brand (optional)',
                    'العلامة التجارية (اختياري)',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: country,
                maxLength: 2,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: _t(
                    'Country code (optional)',
                    'رمز البلد (اختياري)',
                  ),
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty || RegExp(r'^[A-Za-z]{2}$').hasMatch(text)) {
                    return null;
                  }
                  return _t(
                    'Use two letters, for example SA',
                    'استخدم حرفين مثل SA',
                  );
                },
              ),
              TextFormField(
                controller: evidence,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: _t(
                    'Evidence URL (optional)',
                    'رابط المصدر (اختياري)',
                  ),
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return null;
                  final uri = Uri.tryParse(text);
                  return uri != null &&
                          (uri.scheme == 'https' || uri.scheme == 'http')
                      ? null
                      : _t('Enter a valid URL', 'أدخل رابطًا صالحًا');
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: note,
                maxLength: 1000,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: _t(
                    'Note for reviewer (optional)',
                    'ملاحظة للمراجع (اختياري)',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: submitting ? null : () => Navigator.pop(context, false),
        child: Text(_t('Cancel', 'إلغاء')),
      ),
      FilledButton(
        onPressed: submitting ? null : _submit,
        child: submitting
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(_t('Submit for review', 'إرسال للمراجعة')),
      ),
    ],
  );
}
