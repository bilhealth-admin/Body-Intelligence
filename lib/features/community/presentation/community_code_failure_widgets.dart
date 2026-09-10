part of 'community_bil_code_page.dart';

class _CodeUnavailable extends StatelessWidget {
  const _CodeUnavailable({
    required this.failure,
    required this.onRetry,
    this.forOwnCode = false,
    this.onOpenProfile,
  });

  final CommunityPublicCodeFailure failure;
  final VoidCallback? onRetry;
  final bool forOwnCode;
  final VoidCallback? onOpenProfile;

  String _message(BuildContext context) {
    if (!forOwnCode) {
      return communityText(
        context,
        'This BIL Code is unavailable right now. Try again.',
        'رمز BIL هذا غير متاح الآن. حاول مجددًا.',
      );
    }
    return switch (failure.kind) {
      CommunityPublicCodeFailureKind.authenticationRequired => communityText(
        context,
        'Sign in to create and share your BIL Code.',
        'سجّل الدخول لإنشاء رمز BIL ومشاركته.',
      ),
      CommunityPublicCodeFailureKind.profileRequired => communityText(
        context,
        'Save your Community profile first. Your BIL Code is then created automatically; you do not need to add a friend first.',
        'احفظ ملف المجتمع أولًا. بعدها يُنشأ رمز BIL تلقائيًا ولا تحتاج إلى إضافة صديق أولًا.',
      ),
      CommunityPublicCodeFailureKind.communityUnavailable => communityText(
        context,
        'Community access is unavailable for this account, so a BIL Code cannot be created yet.',
        'الوصول إلى المجتمع غير متاح لهذا الحساب، لذلك لا يمكن إنشاء رمز BIL الآن.',
      ),
      CommunityPublicCodeFailureKind.unavailable => communityText(
        context,
        'Your BIL Code could not be created right now. Try again.',
        'تعذر إنشاء رمز BIL الآن. حاول مجددًا.',
      ),
    };
  }

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.qr_code_2_rounded, size: 52),
          const SizedBox(height: 14),
          Text(_message(context), textAlign: TextAlign.center),
          if (forOwnCode &&
              failure.kind == CommunityPublicCodeFailureKind.profileRequired &&
              onOpenProfile != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('community-bil-code-open-profile'),
              onPressed: onOpenProfile,
              icon: const Icon(Icons.person_outline_rounded),
              label: Text(
                communityText(
                  context,
                  'Open Community profile',
                  'فتح ملف المجتمع',
                ),
              ),
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(communityText(context, 'Retry', 'إعادة المحاولة')),
            ),
          ],
        ],
      ),
    ),
  );
}

class _MemberCodeUnavailable extends StatelessWidget {
  const _MemberCodeUnavailable();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        communityText(
          context,
          'This code is invalid, expired, private, or unavailable.',
          'هذا الرمز غير صالح أو منتهي أو خاص أو غير متاح.',
        ),
        textAlign: TextAlign.center,
      ),
    ),
  );
}

class _CodeScannerFailure extends StatelessWidget {
  const _CodeScannerFailure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            communityText(
              context,
              'Camera access is denied or restricted. Enable it in system settings and retry.',
              'الوصول إلى الكاميرا مرفوض أو مقيّد. فعّله من إعدادات النظام ثم حاول مجددًا.',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(
              communityText(context, 'Retry camera', 'إعادة محاولة الكاميرا'),
            ),
          ),
        ],
      ),
    ),
  );
}
