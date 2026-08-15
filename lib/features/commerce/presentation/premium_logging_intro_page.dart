import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PremiumLoggingIntroPage extends StatelessWidget {
  const PremiumLoggingIntroPage({super.key});

  @override
  Widget build(BuildContext context) {
    final copy = _PremiumLoggingCopy.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: copy('No thanks'),
          onPressed: () => context.pop(),
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
          child: Column(
            children: [
              const _LoggingHero(),
              const SizedBox(height: 24),
              Text(
                copy('Log food in seconds'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                copy(
                  'Use the fastest BIL tools whenever typing is not convenient.',
                ),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              _FeatureRow(
                icon: Icons.qr_code_scanner_rounded,
                title: copy('Scan a barcode'),
                body: copy(
                  'Identify packaged products and review their nutrition before saving.',
                ),
              ),
              _FeatureRow(
                icon: Icons.mic_rounded,
                title: copy('Log with your voice'),
                body: copy(
                  'Describe a meal naturally, then confirm every item before it is added.',
                ),
              ),
              _FeatureRow(
                icon: Icons.add_a_photo_rounded,
                title: copy('Analyze a meal photo'),
                body: copy(
                  'Use a photo as a starting point and review portions and evidence.',
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('premium-logging-see-trial-options'),
                  onPressed: () => context.push('/plans'),
                  child: Text(copy('See free-trial options')),
                ),
              ),
              TextButton(
                key: const Key('premium-logging-no-thanks'),
                onPressed: () => context.pop(),
                child: Text(copy('No thanks')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoggingHero extends StatelessWidget {
  const _LoggingHero();

  @override
  Widget build(BuildContext context) => Container(
    height: 180,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(32),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF071A2A), Color(0xFF0A6FF5)],
      ),
    ),
    child: const Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _HeroIcon(Icons.qr_code_scanner_rounded),
        _HeroIcon(Icons.mic_rounded),
        _HeroIcon(Icons.add_a_photo_rounded),
      ],
    ),
  );
}

class _HeroIcon extends StatelessWidget {
  const _HeroIcon(this.icon);
  final IconData icon;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.14),
      shape: BoxShape.circle,
    ),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Icon(icon, color: Colors.white, size: 34),
    ),
  );
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(
                body,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _PremiumLoggingCopy {
  const _PremiumLoggingCopy(this.code);
  final String code;
  static _PremiumLoggingCopy of(BuildContext context) =>
      _PremiumLoggingCopy(Localizations.localeOf(context).languageCode);
  String call(String key) => (_copy[code] ?? _copy['en']!)[key] ?? key;
}

const _copy = <String, Map<String, String>>{
  'en': {},
  'ar': {
    'No thanks': 'لا شكرًا',
    'Log food in seconds': 'سجّل طعامك خلال ثوانٍ',
    'Use the fastest BIL tools whenever typing is not convenient.':
        'استخدم أسرع أدوات BIL عندما لا تكون الكتابة مناسبة.',
    'Scan a barcode': 'امسح الباركود',
    'Identify packaged products and review their nutrition before saving.':
        'تعرّف على المنتجات المعبأة وراجع قيمها الغذائية قبل الحفظ.',
    'Log with your voice': 'سجّل بصوتك',
    'Describe a meal naturally, then confirm every item before it is added.':
        'صف وجبتك بطبيعتك، ثم أكّد كل عنصر قبل إضافته.',
    'Analyze a meal photo': 'حلّل صورة الوجبة',
    'Use a photo as a starting point and review portions and evidence.':
        'استخدم الصورة كنقطة بداية وراجع الحصص والأدلة.',
    'See free-trial options': 'عرض خيارات التجربة المجانية',
  },
  'fr': {
    'No thanks': 'Non merci',
    'Log food in seconds': 'Enregistrez en quelques secondes',
    'Use the fastest BIL tools whenever typing is not convenient.':
        'Utilisez les outils BIL rapides lorsque la saisie est peu pratique.',
    'Scan a barcode': 'Scanner un code-barres',
    'Identify packaged products and review their nutrition before saving.':
        'Identifiez les produits emballés et vérifiez leur nutrition avant l’enregistrement.',
    'Log with your voice': 'Enregistrer à la voix',
    'Describe a meal naturally, then confirm every item before it is added.':
        'Décrivez naturellement le repas puis confirmez chaque élément.',
    'Analyze a meal photo': 'Analyser une photo du repas',
    'Use a photo as a starting point and review portions and evidence.':
        'Utilisez une photo puis vérifiez les portions et les preuves.',
    'See free-trial options': 'Voir les options d’essai gratuit',
  },
  'es': {
    'No thanks': 'No, gracias',
    'Log food in seconds': 'Registra comida en segundos',
    'Use the fastest BIL tools whenever typing is not convenient.':
        'Usa las herramientas rápidas de BIL cuando escribir no sea cómodo.',
    'Scan a barcode': 'Escanear un código de barras',
    'Identify packaged products and review their nutrition before saving.':
        'Identifica productos envasados y revisa su nutrición antes de guardar.',
    'Log with your voice': 'Registrar con la voz',
    'Describe a meal naturally, then confirm every item before it is added.':
        'Describe la comida y confirma cada elemento antes de añadirlo.',
    'Analyze a meal photo': 'Analizar una foto de la comida',
    'Use a photo as a starting point and review portions and evidence.':
        'Usa una foto como inicio y revisa porciones y evidencia.',
    'See free-trial options': 'Ver opciones de prueba gratuita',
  },
  'tr': {
    'No thanks': 'Hayır, teşekkürler',
    'Log food in seconds': 'Yemeğini saniyeler içinde kaydet',
    'Use the fastest BIL tools whenever typing is not convenient.':
        'Yazmanın uygun olmadığı anlarda hızlı BIL araçlarını kullan.',
    'Scan a barcode': 'Barkod tara',
    'Identify packaged products and review their nutrition before saving.':
        'Paketli ürünleri tanı ve kaydetmeden önce besin değerlerini incele.',
    'Log with your voice': 'Sesinle kaydet',
    'Describe a meal naturally, then confirm every item before it is added.':
        'Öğünü doğal biçimde anlat ve eklemeden önce her öğeyi onayla.',
    'Analyze a meal photo': 'Öğün fotoğrafını analiz et',
    'Use a photo as a starting point and review portions and evidence.':
        'Fotoğrafı başlangıç olarak kullan, porsiyonları ve kanıtı incele.',
    'See free-trial options': 'Ücretsiz deneme seçeneklerini gör',
  },
};
