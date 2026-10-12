import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/localization/bil_locale_policy.dart';
import '../services/community_translation_service.dart';
import 'community_translation_copy.dart';

/// The author-owned source is immutable. Translations live only in this
/// visible visit; account, locale, edit, background and disposal retire it.
class CommunityTranslationContent extends ConsumerStatefulWidget {
  const CommunityTranslationContent({
    super.key,
    required this.contentId,
    required this.ownerId,
    required this.texts,
    required this.builder,
    this.ownerChanges,
    this.ownerIsCurrent,
  });
  final String contentId;
  final String ownerId;
  final Map<String, String> texts;
  final Widget Function(Map<String, String>) builder;
  final Listenable? ownerChanges;
  final ValueGetter<bool>? ownerIsCurrent;
  @override
  ConsumerState<CommunityTranslationContent> createState() =>
      _TranslationState();
}

class _TranslationState extends ConsumerState<CommunityTranslationContent>
    with WidgetsBindingObserver {
  int _generation = 0;
  String? _request;
  String? _target;
  CommunityTranslationPort? _port;
  CommunityTranslationResult? _result;
  bool _translated = false;
  bool _failed = false;
  bool _sameLanguage = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.ownerChanges?.addListener(_ownerChanged);
  }

  bool get _allowed =>
      widget.ownerId.isNotEmpty && (widget.ownerIsCurrent?.call() ?? true);
  void _retire() {
    _generation++;
    if (_request case final id?) {
      unawaited(_port!.cancel(id));
    }
    _request = null;
    _result = null;
    _translated = _failed = _sameLanguage = false;
  }

  void _ownerChanged() {
    if (mounted) {
      setState(_retire);
    }
  }

  @override
  void didUpdateWidget(covariant CommunityTranslationContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownerChanges != widget.ownerChanges) {
      oldWidget.ownerChanges?.removeListener(_ownerChanged);
      widget.ownerChanges?.addListener(_ownerChanged);
    }
    if (oldWidget.ownerId != widget.ownerId ||
        oldWidget.contentId != widget.contentId ||
        !mapEquals(oldWidget.texts, widget.texts)) {
      _retire();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final target = BilLocalePolicy.canonicalTag(
      Localizations.localeOf(context),
    );
    if (_target != target) {
      _retire();
      _target = target;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Native download permission sheets can temporarily make iOS inactive.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _ownerChanged();
    }
  }

  Future<void> _translate() async {
    if (!_allowed || _request != null) {
      return;
    }
    if (_result != null) {
      setState(() => _translated = !_translated);
      return;
    }
    final generation = ++_generation;
    final id = const Uuid().v4(); // No account/content IDs in native logs.
    final port = ref.read(communityTranslationProvider);
    setState(() {
      _port = port;
      _request = id;
      _failed = false;
    });
    try {
      final result = await port.translate(
        requestId: id,
        texts: Map.unmodifiable(widget.texts),
        targetTag: _target!,
        statusLabel: translationCopy(context, 2),
        cancelLabel: translationCopy(context, 3),
      );
      if (!mounted || generation != _generation || !_allowed) {
        return;
      }
      setState(() {
        _request = null;
        _sameLanguage = result.sameLanguage;
        _result = result.sameLanguage ? null : result;
        _translated = !result.sameLanguage;
      });
    } catch (_) {
      if (!mounted || generation != _generation || !_allowed) {
        return;
      }
      setState(() {
        _request = null;
        _failed = true;
      });
    }
  }

  void _information() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              translationCopy(context, 6),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(translationCopy(context, 7)),
            if (_result?.engine == 'google') ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => unawaited(
                  launchUrl(
                    Uri.parse('https://cloud.google.com/translate'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                child: const Text('Google Translate'),
              ),
              // Required Google translation warranty notice; not medical advice.
              const Text(
                'THIS SERVICE MAY CONTAIN TRANSLATIONS POWERED BY GOOGLE. GOOGLE DISCLAIMS ALL WARRANTIES RELATED TO THE TRANSLATIONS, EXPRESS OR IMPLIED, INCLUDING ANY WARRANTIES OF ACCURACY, RELIABILITY, AND ANY IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.',
                textDirection: TextDirection.ltr,
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = _request != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        widget.builder(_translated ? _result!.texts : widget.texts),
        if (_allowed &&
            widget.texts.values.any((text) => text.trim().isNotEmpty))
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: Key('community-translate-${widget.contentId}'),
              onPressed: busy ? () => setState(_retire) : _translate,
              icon: Icon(
                busy ? Icons.close_rounded : Icons.translate_rounded,
                size: 16,
              ),
              label: Text(
                !busy &&
                        !_translated &&
                        defaultTargetPlatform == TargetPlatform.android
                    ? googleTranslationAction(context)
                    : translationCopy(
                        context,
                        busy
                            ? 3
                            : _translated
                            ? 1
                            : 0,
                      ),
              ),
            ),
          ),
        if (busy || _failed || _sameLanguage)
          Semantics(
            liveRegion: true,
            child: Text(
              translationCopy(
                context,
                busy
                    ? 2
                    : _sameLanguage
                    ? 8
                    : 4,
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (_translated) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  translationCopy(context, 5),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              IconButton(
                onPressed: _information,
                tooltip: translationCopy(context, 6),
                icon: const Icon(Icons.info_outline_rounded, size: 18),
              ),
            ],
          ),
          if (_result!.engine == 'google')
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Image.asset(
                Theme.of(context).brightness == Brightness.dark
                    ? 'assets/branding/google_translate_white.png'
                    : 'assets/branding/google_translate_color.png',
                height: 20,
                semanticLabel: 'Powered by Google Translate',
              ),
            ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    widget.ownerChanges?.removeListener(_ownerChanged);
    WidgetsBinding.instance.removeObserver(this);
    _retire();
    super.dispose();
  }
}
