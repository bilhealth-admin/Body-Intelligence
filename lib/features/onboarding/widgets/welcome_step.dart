import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/bil_wordmark.dart';

class WelcomeStep extends ConsumerStatefulWidget {
  const WelcomeStep({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  ConsumerState<WelcomeStep> createState() => _WelcomeStepState();
}

class _WelcomeStepState extends ConsumerState<WelcomeStep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _slide;
  late final Animation<double> _imageScale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 860),
    );
    _fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, .82, curve: Curves.easeOutCubic),
    );
    _slide = CurvedAnimation(
      parent: _controller,
      curve: const Interval(.04, .9, curve: Curves.easeOutCubic),
    );
    _imageScale = Tween<double>(
      begin: 1.035,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeLocale = Localizations.localeOf(context);
    final localeTag = activeLocale.toLanguageTag();
    final locale = _localizedCopy.containsKey(localeTag)
        ? localeTag
        : activeLocale.languageCode;
    final copy = _WelcomeCopy.forLocale(locale);
    final isRtl = _rtlLocales.contains(locale);

    return ColoredBox(
      color: Colors.white,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight <= 720;
            final wide = constraints.maxWidth >= 760;

            if (wide) {
              return _WideWelcome(
                copy: copy,
                isRtl: isRtl,
                compact: compact,
                fade: _fade,
                slide: _slide,
                imageScale: _imageScale,
                onContinue: widget.onContinue,
              );
            }

            final heroHeight = (constraints.maxHeight * (compact ? .42 : .49))
                .clamp(300.0, 470.0)
                .toDouble();

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                constraints.maxWidth < 390 ? 18 : 22,
                compact ? 10 : 18,
                constraints.maxWidth < 390 ? 18 : 22,
                compact ? 12 : 18,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 30,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _AnimatedEntrance(
                      fade: _fade,
                      slide: _slide,
                      dy: 12,
                      child: const Center(child: BilWordmark(height: 54)),
                    ),
                    SizedBox(height: compact ? 18 : 26),
                    _AnimatedEntrance(
                      fade: _fade,
                      slide: _slide,
                      dy: 18,
                      child: _ResponsiveWelcomeMessage(
                        message: copy.body,
                        isRtl: isRtl,
                        compact: compact,
                      ),
                    ),
                    SizedBox(height: compact ? 18 : 24),
                    _AnimatedHero(
                      fade: _fade,
                      scale: _imageScale,
                      height: heroHeight,
                    ),
                    SizedBox(height: compact ? 18 : 24),
                    _AnimatedEntrance(
                      fade: _fade,
                      slide: _slide,
                      dy: 24,
                      child: _PremiumContinueButton(
                        label: copy.continueLabel,
                        onPressed: widget.onContinue,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _WideWelcome extends StatelessWidget {
  const _WideWelcome({
    required this.copy,
    required this.isRtl,
    required this.compact,
    required this.fade,
    required this.slide,
    required this.imageScale,
    required this.onContinue,
  });

  final _WelcomeCopy copy;
  final bool isRtl;
  final bool compact;
  final Animation<double> fade;
  final Animation<double> slide;
  final Animation<double> imageScale;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 30 : 42,
            vertical: compact ? 14 : 28,
          ),
          child: Column(
            children: [
              _AnimatedEntrance(
                fade: fade,
                slide: slide,
                dy: 12,
                child: BilWordmark(height: compact ? 48 : 58),
              ),
              SizedBox(height: compact ? 16 : 32),
              Expanded(
                child: Row(
                  textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                  children: [
                    Expanded(
                      flex: 10,
                      child: _AnimatedHero(
                        fade: fade,
                        scale: imageScale,
                        height: double.infinity,
                      ),
                    ),
                    SizedBox(width: compact ? 30 : 44),
                    Expanded(
                      flex: 9,
                      child: _AnimatedEntrance(
                        fade: fade,
                        slide: slide,
                        dy: 20,
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _ResponsiveWelcomeMessage(
                                message: copy.body,
                                isRtl: isRtl,
                                compact: compact,
                                wide: true,
                              ),
                              SizedBox(height: compact ? 20 : 34),
                              _PremiumContinueButton(
                                label: copy.continueLabel,
                                onPressed: onContinue,
                              ),
                            ],
                          ),
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
    );
  }
}

/// Keeps the welcome promise elegant in every supported script. Translations
/// vary greatly in length, so measuring the actual localized text is more
/// reliable than assigning one oversized display font to all 25 locales.
class _ResponsiveWelcomeMessage extends StatelessWidget {
  const _ResponsiveWelcomeMessage({
    required this.message,
    required this.isRtl,
    required this.compact,
    this.wide = false,
  });

  final String message;
  final bool isRtl;
  final bool compact;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final direction = isRtl ? TextDirection.rtl : TextDirection.ltr;
    final textAlign = wide
        ? (isRtl ? TextAlign.right : TextAlign.left)
        : TextAlign.center;
    // This is supporting copy, not a display headline. Keep it restrained on
    // phones so long translations do not dominate the photo and primary CTA.
    final maxFontSize = wide
        ? (compact ? 21.0 : 24.0)
        : (compact ? 15.0 : 17.0);
    final minFontSize = wide ? 18.0 : 13.0;
    final targetLines = wide ? 5 : 5;
    final lineHeight = wide ? 1.28 : 1.32;

    return LayoutBuilder(
      builder: (context, constraints) {
        var fontSize = maxFontSize;
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final textScaler = MediaQuery.textScalerOf(context);

        while (fontSize > minFontSize) {
          final painter = TextPainter(
            text: TextSpan(
              text: message,
              style: TextStyle(
                fontSize: fontSize,
                height: lineHeight,
                fontWeight: FontWeight.w800,
                letterSpacing: isRtl ? 0 : (wide ? -.65 : -.25),
              ),
            ),
            textDirection: direction,
            textScaler: textScaler,
          )..layout(maxWidth: maxWidth);
          if (painter.computeLineMetrics().length <= targetLines) break;
          fontSize -= .5;
        }

        return Directionality(
          textDirection: direction,
          child: Text(
            key: const Key('welcome-message'),
            message,
            textAlign: textAlign,
            style: TextStyle(
              color: const Color(0xFF111936),
              fontSize: fontSize,
              height: lineHeight,
              fontWeight: FontWeight.w800,
              letterSpacing: isRtl ? 0 : (wide ? -.65 : -.25),
            ),
          ),
        );
      },
    );
  }
}

class _AnimatedHero extends StatelessWidget {
  const _AnimatedHero({
    required this.fade,
    required this.scale,
    required this.height,
  });

  final Animation<double> fade;
  final Animation<double> scale;
  final double height;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([fade, scale]),
      builder: (context, child) {
        return Opacity(
          opacity: fade.value,
          child: Transform.scale(scale: scale.value, child: child),
        );
      },
      child: SizedBox(
        height: height.isFinite ? height : null,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1406172F),
                blurRadius: 34,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/flagship/bil_body_intelligence_journey_v1.png',
                  fit: BoxFit.cover,
                  alignment: const Alignment(.12, -.02),
                ),
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x00FFFFFF),
                          Color(0x00FFFFFF),
                          Color(0xC8FFFFFF),
                        ],
                        stops: [0, .77, 1],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedEntrance extends StatelessWidget {
  const _AnimatedEntrance({
    required this.fade,
    required this.slide,
    required this.dy,
    required this.child,
  });

  final Animation<double> fade;
  final Animation<double> slide;
  final double dy;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([fade, slide]),
      child: child,
      builder: (context, child) {
        return Opacity(
          opacity: fade.value,
          child: Transform.translate(
            offset: Offset(0, dy * (1 - slide.value)),
            child: child,
          ),
        );
      },
    );
  }
}

class _PremiumContinueButton extends StatelessWidget {
  const _PremiumContinueButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [
            BoxShadow(
              color: Color(0x2A0B63F6),
              blurRadius: 26,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            height: 60,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xFF0A55F5), Color(0xFF0877F9)],
              ),
            ),
            child: InkWell(
              key: const Key('onboarding-welcome-continue'),
              onTap: onPressed,
              splashColor: Colors.white24,
              highlightColor: Colors.white10,
              child: Center(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.15,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomeCopy {
  const _WelcomeCopy(this.body, this.continueLabel);

  final String body;
  final String continueLabel;

  static _WelcomeCopy forLocale(String locale) =>
      _localizedCopy[locale] ?? _localizedCopy['en']!;
}

const _rtlLocales = <String>{'ar', 'fa', 'ur'};

const _localizedCopy = <String, _WelcomeCopy>{
  'ar': _WelcomeCopy(
    'ابدأ رحلتك نحو جسم أكثر صحة وقوة وذكاء مع نموذج شخصي يتعلم من بياناتك.',
    'متابعة',
  ),
  'bn': _WelcomeCopy(
    'আপনার ডেটা থেকে শেখে এমন একটি ব্যক্তিগত মডেলের সঙ্গে আরও সুস্থ, শক্তিশালী ও বুদ্ধিমান শরীরের পথে আপনার যাত্রা শুরু করুন।',
    'চালিয়ে যান',
  ),
  'de': _WelcomeCopy(
    'Starte deine Reise zu einem gesünderen, stärkeren und smarteren Körper – mit einem persönlichen Modell, das aus deinen Daten lernt.',
    'Weiter',
  ),
  'en': _WelcomeCopy(
    'Start your journey toward a healthier, stronger, smarter body with a personal model that learns from your data.',
    'Continue',
  ),
  'es': _WelcomeCopy(
    'Empieza tu camino hacia un cuerpo más sano, fuerte e inteligente con un modelo personal que aprende de tus datos.',
    'Continuar',
  ),
  'fa': _WelcomeCopy(
    'سفر خود را به سوی بدنی سالم‌تر، قوی‌تر و هوشمندتر با مدلی شخصی که از داده‌های شما یاد می‌گیرد آغاز کنید.',
    'ادامه',
  ),
  'fr': _WelcomeCopy(
    'Commencez votre parcours vers un corps plus sain, plus fort et plus intelligent avec un modèle personnel qui apprend de vos données.',
    'Continuer',
  ),
  'hi': _WelcomeCopy(
    'अपने डेटा से सीखने वाले व्यक्तिगत मॉडल के साथ अधिक स्वस्थ, मजबूत और समझदार शरीर की ओर अपनी यात्रा शुरू करें।',
    'जारी रखें',
  ),
  'id': _WelcomeCopy(
    'Mulai perjalanan menuju tubuh yang lebih sehat, kuat, dan cerdas dengan model pribadi yang belajar dari data Anda.',
    'Lanjutkan',
  ),
  'it': _WelcomeCopy(
    'Inizia il tuo percorso verso un corpo più sano, forte e intelligente con un modello personale che impara dai tuoi dati.',
    'Continua',
  ),
  'ja': _WelcomeCopy('あなたのデータから学ぶパーソナルモデルとともに、より健康で強く、賢い身体への旅を始めましょう。', '続ける'),
  'ko': _WelcomeCopy(
    '내 데이터에서 학습하는 개인 모델과 함께 더 건강하고 강하며 스마트한 몸을 향한 여정을 시작하세요.',
    '계속',
  ),
  'ms': _WelcomeCopy(
    'Mulakan perjalanan ke arah tubuh yang lebih sihat, kuat dan pintar dengan model peribadi yang belajar daripada data anda.',
    'Teruskan',
  ),
  'nl': _WelcomeCopy(
    'Begin je reis naar een gezonder, sterker en slimmer lichaam met een persoonlijk model dat van je gegevens leert.',
    'Doorgaan',
  ),
  'pl': _WelcomeCopy(
    'Rozpocznij drogę do zdrowszego, silniejszego i mądrzejszego ciała z osobistym modelem, który uczy się z Twoich danych.',
    'Dalej',
  ),
  'pt-BR': _WelcomeCopy(
    'Comece sua jornada rumo a um corpo mais saudável, forte e inteligente com um modelo pessoal que aprende com seus dados.',
    'Continuar',
  ),
  'pt-PT': _WelcomeCopy(
    'Comece a sua jornada rumo a um corpo mais saudável, forte e inteligente com um modelo pessoal que aprende com os seus dados.',
    'Continuar',
  ),
  'ru': _WelcomeCopy(
    'Начните путь к более здоровому, сильному и умному телу с персональной моделью, которая учится на ваших данных.',
    'Продолжить',
  ),
  'th': _WelcomeCopy(
    'เริ่มต้นเส้นทางสู่ร่างกายที่สุขภาพดี แข็งแรง และฉลาดยิ่งขึ้น ด้วยโมเดลส่วนบุคคลที่เรียนรู้จากข้อมูลของคุณ',
    'ดำเนินการต่อ',
  ),
  'tr': _WelcomeCopy(
    'Verilerinizden öğrenen kişisel bir modelle daha sağlıklı, daha güçlü ve daha akıllı bir bedene doğru yolculuğunuza başlayın.',
    'Devam et',
  ),
  'uk': _WelcomeCopy(
    'Розпочніть шлях до здоровішого, сильнішого й розумнішого тіла з персональною моделлю, яка навчається на ваших даних.',
    'Продовжити',
  ),
  'ur': _WelcomeCopy(
    'اپنے ڈیٹا سے سیکھنے والے ذاتی ماڈل کے ساتھ زیادہ صحت مند، مضبوط اور ذہین جسم کی طرف اپنا سفر شروع کریں۔',
    'جاری رکھیں',
  ),
  'vi': _WelcomeCopy(
    'Bắt đầu hành trình hướng tới một cơ thể khỏe mạnh, mạnh mẽ và thông minh hơn với mô hình cá nhân học từ dữ liệu của bạn.',
    'Tiếp tục',
  ),
  'zh-Hans': _WelcomeCopy('通过一个能从你的数据中学习的个性化模型，开启迈向更健康、更强壮、更智慧身体的旅程。', '继续'),
  'zh-Hant': _WelcomeCopy('透過一個能從你的資料中學習的個人化模型，開啟邁向更健康、更強壯、更智慧身體的旅程。', '繼續'),
};
