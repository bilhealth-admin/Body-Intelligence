import 'package:flutter/material.dart';
import '../../../app/theme/bil_pearl_finish.dart';
import '../domain/store_benefit_delivery.dart';
import '../domain/store_catalog_configuration.dart';
import '../domain/commerce_plan.dart';

/// An accessible, dismissible local surface. It does not navigate, buy,
/// finish a store transaction or update the verified benefit.
class StoreBenefitConfirmation extends StatefulWidget {
  const StoreBenefitConfirmation({
    required this.delivery,
    required this.onContinue,
    required this.onPainted,
    this.subscriptionLifecycle,
    super.key,
  });
  final StoreBenefitDelivery delivery;
  final String? subscriptionLifecycle;
  final VoidCallback onContinue, onPainted;
  @override
  State<StoreBenefitConfirmation> createState() =>
      _StoreBenefitConfirmationState();
}

class _StoreBenefitConfirmationState extends State<StoreBenefitConfirmation> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onPainted();
    });
  }

  String copy(String en, String ar, String fr, String es, String tr) =>
      switch (Localizations.localeOf(context).languageCode) {
        'ar' => ar,
        'fr' => fr,
        'es' => es,
        'tr' => tr,
        _ => en,
      };
  @override
  Widget build(BuildContext context) {
    final event = widget.delivery;
    final plan =
        StoreCatalogConfiguration.bindingForProduct(event.productId)?.plan ==
            CommercePlan.premiumAiCoach
        ? 'Premium AI Coach'
        : 'BIL Premium';
    final amount = '\u2066${event.quantity} BIL AI Tokens\u2069';
    final title = event.isBoost
        ? copy(
            '${event.quantity} BIL AI Tokens added',
            'تمت إضافة $amount',
            '${event.quantity} BIL AI Tokens ajoutés',
            '${event.quantity} BIL AI Tokens añadidos',
            '${event.quantity} BIL AI Tokens eklendi',
          )
        : copy(
            'Welcome to $plan',
            'أهلًا بك في $plan',
            'Bienvenue dans $plan',
            'Te damos la bienvenida a $plan',
            '$plan planına hoş geldin',
          );
    final body = event.isBoost
        ? copy(
            'Your verified tokens are ready to use.',
            'توكناتك المؤكدة جاهزة للاستخدام.',
            'Vos jetons vérifiés sont prêts.',
            'Tus tokens verificados están listos.',
            'Doğrulanan tokenlerin kullanıma hazır.',
          )
        : widget.subscriptionLifecycle == 'trial'
        ? copy(
            'Your trial is active. Its features are ready to use.',
            'بدأت فترتك التجريبية. ميزات خطتك جاهزة للاستخدام.',
            'Votre période d’essai est active. Les fonctionnalités sont prêtes.',
            'Tu período de prueba está activo. Sus funciones están listas.',
            'Deneme süren etkin. Özellikler kullanıma hazır.',
          )
        : copy(
            'Your plan is active. Its features are ready to use.',
            'تم تفعيل خطتك. ميزاتها جاهزة للاستخدام.',
            'Votre formule est active. Ses fonctionnalités sont prêtes.',
            'Tu plan está activo. Sus funciones están listas.',
            'Planın etkin. Özellikleri kullanıma hazır.',
          );
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      key: const Key('store-benefit-confirmation'),
      container: true,
      liveRegion: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(
          begin: MediaQuery.disableAnimationsOf(context) ? 1 : .96,
          end: 1,
        ),
        duration: Duration(
          milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 220,
        ),
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          child: BilFrostedPanel(
            radius: BorderRadius.circular(28),
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_rounded, size: 44, color: scheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'BILDisplay',
                      fontFamilyFallback: const ['BILArabic'],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    body,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurface),
                  ),
                  if (event.environment == 'sandbox') ...[
                    const SizedBox(height: 12),
                    Text(
                      copy(
                        'Test purchase',
                        'عملية تجريبية',
                        'Achat de test',
                        'Compra de prueba',
                        'Test satın alımı',
                      ),
                      key: const Key('store-confirmation-sandbox'),
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const Key('store-confirmation-continue'),
                      onPressed: widget.onContinue,
                      child: Text(
                        copy(
                          'Continue',
                          'متابعة',
                          'Continuer',
                          'Continuar',
                          'Devam',
                        ),
                      ),
                    ),
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
