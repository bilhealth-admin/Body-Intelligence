import '../../../shared/widgets/bil_pearl_material.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app/localization/app_localizations.dart';
import '../domain/coach_conversation_titles.dart';

String coachRenameCopy(BuildContext context, String english, String arabic) =>
    Localizations.localeOf(context).languageCode == 'ar'
    ? arabic
    : context.strings.text(english);

class CoachConversationRenameDialog extends StatefulWidget {
  const CoachConversationRenameDialog({
    super.key,
    required this.title,
    required this.onSave,
  });
  final String title;
  final Future<void> Function(String title) onSave;
  @override
  State<CoachConversationRenameDialog> createState() =>
      _CoachConversationRenameDialogState();
}

class _CoachConversationRenameDialogState
    extends State<CoachConversationRenameDialog> {
  late final editor = TextEditingController(text: widget.title);
  bool saving = false;
  String? error;
  @override
  void dispose() {
    editor.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving) return;
    late final String title;
    try {
      title = validatedCoachConversationTitle(editor.text);
    } on FormatException catch (failure) {
      setState(
        () => error = failure.message == 'empty_conversation_title'
            ? coachRenameCopy(
                context,
                'Enter a conversation name.',
                'اكتب اسمًا للمحادثة.',
              )
            : coachRenameCopy(
                context,
                'Use at most 60 characters.',
                'استخدم 60 حرفًا كحد أقصى.',
              ),
      );
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.onSave(title);
      if (mounted) Navigator.pop(context, title);
    } on Object {
      if (mounted) {
        setState(
          () => error = coachRenameCopy(
            context,
            'Could not save the name. Try again.',
            'تعذّر حفظ الاسم. أعد المحاولة.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => BilPearlMaterialAlertDialog(
    scrollable: true,
    title: Text(
      coachRenameCopy(context, 'Rename conversation', 'إعادة تسمية المحادثة'),
    ),
    content: TextField(
      key: const Key('ai-coach-conversation-name'),
      controller: editor,
      autofocus: true,
      minLines: 1,
      maxLines: 3,
      enabled: !saving,
      maxLength: coachConversationTitleLimit,
      maxLengthEnforcement: MaxLengthEnforcement.none,
      decoration: InputDecoration(
        labelText: coachRenameCopy(
          context,
          'Conversation name',
          'اسم المحادثة',
        ),
        errorText: error,
      ),
      onChanged: (_) {
        if (error != null) setState(() => error = null);
      },
      onSubmitted: (_) => save(),
    ),
    actions: [
      TextButton(
        key: const Key('ai-coach-rename-cancel'),
        onPressed: saving ? null : () => Navigator.pop(context),
        child: Text(context.strings.text('Cancel')),
      ),
      FilledButton(
        key: const Key('ai-coach-rename-save'),
        onPressed: saving ? null : save,
        child: Text(context.strings.text('Save')),
      ),
    ],
  );
}
