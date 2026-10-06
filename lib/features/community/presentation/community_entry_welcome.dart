import 'package:flutter/material.dart';

import 'community_copy.dart';
import 'community_entry_copy.dart';
import 'community_welcome.dart';

/// Name-only entry. Optional identity controls belong in the existing editor,
/// not a crowded form or an implicit discoverability consent on first entry.
class CommunityEntryWelcome extends StatelessWidget {
  const CommunityEntryWelcome({
    required this.name,
    required this.saving,
    required this.onContinue,
    this.error,
    super.key,
  });
  final TextEditingController name;
  final bool saving;
  final VoidCallback onContinue;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        key: const Key('community-entry-scroll'),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: AspectRatio(
                      aspectRatio: 1.7,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ExcludeSemantics(
                            child: Image.asset(
                              CommunityWelcome.imageAsset,
                              fit: BoxFit.cover,
                              alignment: const Alignment(0, .2),
                              cacheWidth: 900,
                              errorBuilder: (_, _, _) => const ColoredBox(
                                color: Color(0xFF163753),
                                child: Center(
                                  child: Icon(
                                    Icons.groups_rounded,
                                    size: 78,
                                    color: Color(0xFFB6DCFF),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0x00102138), Color(0xD9102138)],
                              ),
                            ),
                          ),
                          PositionedDirectional(
                            bottom: 16,
                            start: 18,
                            end: 18,
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1677FF),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: const Color(0x668BC8FF),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.groups_outlined,
                                    color: Colors.white,
                                    size: 23,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    communityText(
                                      context,
                                      'BIL Community',
                                      'مجتمع BIL',
                                    ),
                                    style: theme.titleLarge?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  Text(
                    CommunityEntryCopy.text(
                      context,
                      CommunityEntryCopyKey.heading,
                    ),
                    style: theme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      letterSpacing: -.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    CommunityEntryCopy.text(
                      context,
                      CommunityEntryCopyKey.introduction,
                    ),
                    style: theme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    key: const Key('community-entry-name'),
                    controller: name,
                    enabled: !saving,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.nickname],
                    onSubmitted: (_) {
                      if (!saving) onContinue();
                    },
                    decoration: InputDecoration(
                      labelText: communityText(
                        context,
                        'Display name',
                        'الاسم الظاهر',
                      ),
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                      filled: true,
                      fillColor: dark ? scheme.surfaceContainer : Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 20,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(
                          color: scheme.outlineVariant.withValues(alpha: .6),
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        error!,
                        key: const Key('community-entry-error'),
                        style: theme.bodyMedium?.copyWith(color: scheme.error),
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF278FFF), Color(0xFF1254F5)],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1668ED).withValues(alpha: .22),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: FilledButton.icon(
                      key: const Key('community-entry-save'),
                      onPressed: saving ? null : onContinue,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        disabledBackgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        disabledForegroundColor: const Color(0xFFDFEDFF),
                        shadowColor: Colors.transparent,
                        minimumSize: const Size(48, 58),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 17,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      icon: saving
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.qr_code_2_rounded, size: 23),
                      label: Text(
                        communityText(
                          context,
                          'Save profile and create BIL Code',
                          'احفظ الملف وأنشئ رمز BIL',
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 19,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          communityText(
                            context,
                            'Your measurements and health logs stay private.',
                            'تبقى قياساتك ويومياتك الصحية خاصة.',
                          ),
                          style: theme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
