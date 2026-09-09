import 'package:flutter/material.dart';

import '../domain/community_food_input.dart';
import '../domain/community_models.dart';
import '../domain/community_text_policy.dart';
import 'community_copy.dart';

/// Owns its controllers and validation inside the modal route. Validation
/// never queues a global SnackBar that can leak into an unrelated conversation.
class CommunityFoodSubmissionSheet extends StatefulWidget {
  const CommunityFoodSubmissionSheet({required this.onSubmit, super.key});
  final Future<void> Function(CommunityFoodDraft draft) onSubmit;

  @override
  State<CommunityFoodSubmissionSheet> createState() =>
      _CommunityFoodSubmissionSheetState();
}

class _CommunityFoodSubmissionSheetState
    extends State<CommunityFoodSubmissionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = {
    for (final field in CommunityFoodField.values)
      field: TextEditingController(),
  };
  bool _submitting = false;
  String? _failure;

  Map<CommunityFoodField, String> get _input => {
    for (final entry in _controllers.entries) entry.key: entry.value.text,
  };

  String _text(String en, String ar) => communityText(context, en, ar);

  String _label(CommunityFoodField field) => switch (field) {
    CommunityFoodField.name => _text('Name', 'الاسم'),
    CommunityFoodField.serving => _text('Serving grams', 'الحصة بالغرام'),
    CommunityFoodField.calories => _text('Calories', 'السعرات'),
    CommunityFoodField.protein => _text('Protein', 'البروتين'),
    CommunityFoodField.carbohydrate => _text('Carbohydrate', 'الكربوهيدرات'),
    CommunityFoodField.fat => _text('Fat', 'الدهون'),
  };

  String? _validate(CommunityFoodField field) {
    final issue = validateCommunityFoodInput(_input).issues[field];
    return switch (issue) {
      null => null,
      CommunityFoodInputIssue.missingValue => _text(
        'This value is required.',
        'هذه القيمة مطلوبة.',
      ),
      CommunityFoodInputIssue.nameLength => _text(
        'Use 2 to 180 characters.',
        'اكتب من حرفين إلى 180 حرفًا.',
      ),
      CommunityFoodInputIssue.invalidNumber => _text(
        'Enter a non-negative decimal number.',
        'أدخل رقمًا عشريًا غير سالب.',
      ),
      CommunityFoodInputIssue.positiveServing => _text(
        'Serving weight must be greater than zero.',
        'يجب أن يكون وزن الحصة أكبر من صفر.',
      ),
      CommunityFoodInputIssue.tooLarge => _text(
        'Check this value and its unit; it is too large.',
        'راجع هذه القيمة ووحدتها؛ القيمة كبيرة جدًا.',
      ),
      CommunityFoodInputIssue.macroExceedsServing => _text(
        'Nutrient grams cannot exceed the serving weight.',
        'غرامات العنصر الغذائي لا يمكن أن تتجاوز وزن الحصة.',
      ),
      CommunityFoodInputIssue.macroTotalExceedsServing => _text(
        'Total macro grams exceed this serving weight.',
        'مجموع غرامات الماكروز يتجاوز وزن هذه الحصة.',
      ),
    };
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _failure = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final result = validateCommunityFoodInput(_input);
    if (!result.isValid) return;
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(result.draft!);
      if (!mounted) return;
      setState(() => _submitting = false);
      Navigator.of(context).pop(true);
    } on CommunityTextPolicyException catch (error) {
      if (!mounted) return;
      setState(
        () => _failure = error.localizedMessage(
          Localizations.localeOf(context).toLanguageTag(),
        ),
      );
    } on Object {
      if (!mounted) return;
      setState(
        () => _failure = _text(
          'Submission could not be confirmed. Your values are kept. Check your submissions before retrying.',
          'تعذر تأكيد الإرسال. احتفظنا بالقيم. تحقق من مساهماتك قبل إعادة المحاولة.',
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_submitting,
    child: SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _text('Submit community food', 'إضافة غذاء مجتمعي'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                _text(
                  'Enter all nutrition values for this serving, not per 100 g.',
                  'أدخل جميع القيم الغذائية لهذه الحصة، وليس لكل 100 غرام.',
                ),
              ),
              const SizedBox(height: 16),
              for (final field in CommunityFoodField.values) ...[
                TextFormField(
                  key: Key('community-food-input-${field.name}'),
                  controller: _controllers[field],
                  enabled: !_submitting,
                  validator: (_) => _validate(field),
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  keyboardType: field == CommunityFoodField.name
                      ? TextInputType.text
                      : const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: field == CommunityFoodField.fat
                      ? TextInputAction.done
                      : TextInputAction.next,
                  onFieldSubmitted: (_) {
                    if (field == CommunityFoodField.fat) _submit();
                  },
                  decoration: InputDecoration(
                    labelText: _label(field),
                    errorMaxLines: 3,
                    suffixText: field == CommunityFoodField.name
                        ? null
                        : field == CommunityFoodField.calories
                        ? 'kcal'
                        : 'g',
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_failure != null) ...[
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _failure!,
                    key: const Key('community-food-submit-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              FilledButton.icon(
                key: const Key('community-food-submit'),
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.fact_check_outlined),
                label: Text(
                  _submitting
                      ? _text('Sending…', 'جارٍ الإرسال…')
                      : _text('Send for review', 'إرسال للمراجعة'),
                ),
              ),
              TextButton(
                key: const Key('community-food-cancel'),
                onPressed: _submitting
                    ? null
                    : () => Navigator.of(context).pop(false),
                child: Text(_text('Cancel', 'إلغاء')),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
