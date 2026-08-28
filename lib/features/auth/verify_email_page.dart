import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_entry_locale_copy.dart';
import 'auth_error_localizer.dart';
import 'supabase_auth_service.dart';

class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key, required this.email});

  final String email;

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  final code = TextEditingController();
  final codeFocus = FocusNode();
  Timer? resendTimer;
  DateTime? resendDeadline;
  int resendSeconds = 59;
  bool loading = false;
  bool statusIsError = false;
  String? status;

  String get _clock {
    final minutes = resendSeconds ~/ 60;
    final seconds = resendSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _startCountdown();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) codeFocus.requestFocus();
    });
  }

  void _startCountdown({bool notify = false}) {
    resendTimer?.cancel();
    resendDeadline = DateTime.now().add(const Duration(seconds: 60));
    if (notify && mounted) {
      setState(() => resendSeconds = 59);
    } else {
      resendSeconds = 59;
    }
    resendTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      final deadline = resendDeadline;
      if (!mounted || deadline == null) {
        timer.cancel();
        return;
      }
      final remaining = deadline.difference(DateTime.now());
      if (remaining.isNegative || remaining == Duration.zero) {
        timer.cancel();
        setState(() => resendSeconds = 0);
        return;
      }
      final next = remaining.inSeconds.clamp(1, 59).toInt();
      if (next != resendSeconds) {
        setState(() => resendSeconds = next);
      }
    });
  }

  Future<void> verify() async {
    if (loading || code.text.length != 6) return;
    FocusScope.of(context).unfocus();
    setState(() {
      loading = true;
      status = null;
      statusIsError = false;
    });
    try {
      await SupabaseAuthService(
        Supabase.instance.client,
      ).verifyEmailOtp(email: widget.email, code: code.text);
      if (mounted) context.go('/startup');
    } on AuthException catch (error) {
      if (mounted) {
        setState(() {
          status = localizedAuthError(context, error);
          statusIsError = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          status = authEntryText(
            context,
            AuthEntryCopyKey.codeVerificationFailed,
          );
          statusIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> resend() async {
    if (loading || resendSeconds != 0) return;
    setState(() {
      loading = true;
      status = null;
      statusIsError = false;
    });
    try {
      await SupabaseAuthService(
        Supabase.instance.client,
      ).sendEmailOtp(widget.email);
      if (!mounted) return;
      code.clear();
      _startCountdown(notify: true);
      setState(() {
        status = authEntryText(context, AuthEntryCopyKey.newCodeSent);
        statusIsError = false;
      });
      codeFocus.requestFocus();
    } on AuthException catch (error) {
      if (mounted) {
        setState(() {
          status = localizedAuthError(context, error);
          statusIsError = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          status = authEntryText(context, AuthEntryCopyKey.resendFailed);
          statusIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    resendTimer?.cancel();
    code.dispose();
    codeFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _VerifyTopBar(
              title: authEntryText(context, AuthEntryCopyKey.verifyEmail),
              onBack: loading ? null : () => context.go('/login'),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxHeight < 570;
                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      constraints.maxWidth < 390 ? 22 : 28,
                      compact ? 26 : 38,
                      constraints.maxWidth < 390 ? 22 : 28,
                      24 + MediaQuery.viewInsetsOf(context).bottom,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 430),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              authEntryText(
                                context,
                                AuthEntryCopyKey.enterVerificationCode,
                              ),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF111318),
                                fontSize: 24,
                                height: 1.15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -.45,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Directionality(
                              textDirection: TextDirection.ltr,
                              child: Text(
                                authEntryCodeSent(context, widget.email),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFF6D727B),
                                  fontSize: 14,
                                  height: 1.4,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            SizedBox(height: compact ? 26 : 34),
                            GestureDetector(
                              key: const Key('verification-code-boxes'),
                              behavior: HitTestBehavior.opaque,
                              onTap: codeFocus.requestFocus,
                              child: Stack(
                                children: [
                                  LayoutBuilder(
                                    builder: (context, boxConstraints) {
                                      final boxWidth =
                                          ((boxConstraints.maxWidth - 40) / 6)
                                              .clamp(36.0, 49.0)
                                              .toDouble();
                                      return Directionality(
                                        textDirection: TextDirection.ltr,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: List.generate(6, (index) {
                                            final value =
                                                index < code.text.length
                                                ? code.text[index]
                                                : '';
                                            final active =
                                                codeFocus.hasFocus &&
                                                code.text.length < 6 &&
                                                index == code.text.length;
                                            return AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 130,
                                              ),
                                              width: boxWidth,
                                              height: 59,
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF9F9FB),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: active
                                                      ? const Color(0xFF0877F9)
                                                      : const Color(0xFFD7D9DE),
                                                  width: active ? 1.8 : 1.2,
                                                ),
                                                boxShadow: active
                                                    ? const [
                                                        BoxShadow(
                                                          color: Color(
                                                            0x160877F9,
                                                          ),
                                                          blurRadius: 14,
                                                          offset: Offset(0, 5),
                                                        ),
                                                      ]
                                                    : const [],
                                              ),
                                              child: Text(
                                                value,
                                                style: const TextStyle(
                                                  fontSize: 23,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF111318),
                                                ),
                                              ),
                                            );
                                          }),
                                        ),
                                      );
                                    },
                                  ),
                                  Positioned.fill(
                                    child: Opacity(
                                      opacity: .01,
                                      child: TextField(
                                        key: const Key(
                                          'email-verification-code',
                                        ),
                                        controller: code,
                                        focusNode: codeFocus,
                                        enabled: !loading,
                                        keyboardType: TextInputType.number,
                                        textDirection: TextDirection.ltr,
                                        textInputAction: TextInputAction.done,
                                        autofillHints: const [
                                          AutofillHints.oneTimeCode,
                                        ],
                                        maxLength: 6,
                                        inputFormatters: <TextInputFormatter>[
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                          LengthLimitingTextInputFormatter(6),
                                        ],
                                        decoration: const InputDecoration(
                                          counterText: '',
                                        ),
                                        onChanged: (_) {
                                          setState(() {});
                                          if (code.text.length == 6 &&
                                              !loading) {
                                            unawaited(verify());
                                          }
                                        },
                                        onSubmitted: (_) => verify(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (status != null) ...[
                              const SizedBox(height: 15),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: statusIsError
                                      ? const Color(0xFFFFECEA)
                                      : const Color(0xFFEAF3FF),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  status!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: statusIsError
                                        ? const Color(0xFFB42318)
                                        : const Color(0xFF0668DB),
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                            SizedBox(height: compact ? 21 : 28),
                            FilledButton(
                              key: const Key('verify-email-submit'),
                              onPressed: code.text.length == 6 && !loading
                                  ? verify
                                  : null,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(56),
                                backgroundColor: const Color(0xFF0877F9),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: const Color(
                                  0xFFB8C8DE,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                                textStyle: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -.15,
                                ),
                              ),
                              child: loading
                                  ? const SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      authEntryText(
                                        context,
                                        AuthEntryCopyKey.verify,
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              key: const Key('resend-email-code'),
                              onPressed: resendSeconds == 0 && !loading
                                  ? resend
                                  : null,
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF0877F9),
                                disabledForegroundColor: const Color(
                                  0xFF0877F9,
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              child: Text(
                                resendSeconds == 0
                                    ? authEntryText(
                                        context,
                                        AuthEntryCopyKey.resendCode,
                                      )
                                    : authEntryResendCountdown(context, _clock),
                              ),
                            ),
                            TextButton(
                              key: const Key('change-email'),
                              onPressed: loading
                                  ? null
                                  : () => context.go('/login'),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF686D76),
                                textStyle: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              child: Text(
                                authEntryText(
                                  context,
                                  AuthEntryCopyKey.changeEmail,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerifyTopBar extends StatelessWidget {
  const _VerifyTopBar({required this.title, required this.onBack});

  final String title;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Container(
    height: 72,
    decoration: const BoxDecoration(
      color: Color(0xFFFAFAFC),
      border: Border(bottom: BorderSide(color: Color(0xFFE8E9ED), width: 1)),
    ),
    child: Stack(
      alignment: Alignment.center,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 16),
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 4,
              shadowColor: const Color(0x1F000000),
              child: IconButton(
                key: const Key('verify-email-back'),
                tooltip: authEntryText(context, AuthEntryCopyKey.back),
                onPressed: onBack,
                icon: Icon(
                  Directionality.of(context) == TextDirection.rtl
                      ? Icons.arrow_forward_ios_rounded
                      : Icons.arrow_back_ios_new_rounded,
                  size: 19,
                ),
                color: const Color(0xFF111318),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 74),
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF111318),
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -.25,
            ),
          ),
        ),
      ],
    ),
  );
}
