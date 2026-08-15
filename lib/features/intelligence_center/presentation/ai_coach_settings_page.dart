import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/ai_boost_purchase_service.dart';

class AiCoachSettingsPage extends StatefulWidget {
  const AiCoachSettingsPage({super.key});

  @override
  State<AiCoachSettingsPage> createState() => _AiCoachSettingsPageState();
}

class _AiCoachSettingsPageState extends State<AiCoachSettingsPage> {
  late final AiBoostPurchaseService boost;
  Future<Map<String, Object?>>? usage;

  @override
  void initState() {
    super.initState();
    boost = AiBoostPurchaseService()..addListener(_boostChanged);
    usage = _loadUsage();
    boost.initialize();
  }

  void _boostChanged() {
    if (!mounted) return;
    if (boost.state == AiBoostPurchaseState.verified) usage = _loadUsage();
    setState(() {});
  }

  Future<Map<String, Object?>> _loadUsage() async {
    final value = await Supabase.instance.client.rpc('bil_get_ai_usage_status');
    return Map<String, Object?>.from(value as Map);
  }

  String t(String en, String ar, String fr, String es, String tr) {
    return switch (Localizations.localeOf(context).languageCode) {
      'ar' => ar,
      'fr' => fr,
      'es' => es,
      'tr' => tr,
      _ => en,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          t(
            'AI Coach',
            'المدرب الذكي',
            'Coach IA',
            'Coach de IA',
            'Yapay Zekâ Koçu',
          ),
        ),
      ),
      body: FutureBuilder<Map<String, Object?>>(
        future: usage,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          final capabilities = Map<String, Object?>.from(
            data['capabilities']! as Map,
          );
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                data['plan'] == 'ai_coach'
                    ? t(
                        'AI Coach subscription active',
                        'اشتراك المدرب الذكي نشط',
                        'Abonnement Coach IA actif',
                        'Suscripción de Coach de IA activa',
                        'Yapay Zekâ Koçu aboneliği aktif',
                      )
                    : t(
                        'AI Coach subscription inactive',
                        'اشتراك المدرب الذكي غير نشط',
                        'Abonnement Coach IA inactif',
                        'Suscripción de Coach de IA inactiva',
                        'Yapay Zekâ Koçu aboneliği etkin değil',
                      ),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                '${t('Weekly reset', 'إعادة الضبط الأسبوعية', 'Réinitialisation hebdomadaire', 'Reinicio semanal', 'Haftalık sıfırlama')}: ${data['reset_at']}',
              ),
              const SizedBox(height: 20),
              _UsageCard(
                label: t(
                  'Vision analyses',
                  'تحليلات الصور',
                  'Analyses Vision',
                  'Análisis Vision',
                  'Görüntü analizleri',
                ),
                data: capabilities['vision'],
              ),
              _UsageCard(
                label: t(
                  'Text messages',
                  'الرسائل النصية',
                  'Messages texte',
                  'Mensajes de texto',
                  'Metin mesajları',
                ),
                data: capabilities['text'],
              ),
              _UsageCard(
                label: t(
                  'Voice minutes',
                  'دقائق الصوت',
                  'Minutes vocales',
                  'Minutos de voz',
                  'Ses dakikaları',
                ),
                data: capabilities['voice'],
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'BIL AI Boost',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${boost.product?.price ?? t('Price from the store', 'السعر من المتجر', 'Prix de la boutique', 'Precio de la tienda', 'Mağaza fiyatı')} • ${t('+25 Vision • +125 text • +15 voice minutes. Stacks and never expires.', '+25 صورة • +125 رسالة • +15 دقيقة صوت. يتراكم ولا تنتهي صلاحيته.', '+25 Vision • +125 textes • +15 minutes vocales. Cumulable, sans expiration.', '+25 Vision • +125 textos • +15 minutos de voz. Acumulable y sin caducidad.', '+25 görüntü • +125 metin • +15 ses dakikası. Birikir ve süresi dolmaz.')}',
                      ),
                      const SizedBox(height: 14),
                      FilledButton(
                        onPressed: boost.state == AiBoostPurchaseState.ready
                            ? boost.purchaseBoost
                            : null,
                        child: Text(
                          boost.state == AiBoostPurchaseState.pending
                              ? t(
                                  'Waiting for store…',
                                  'بانتظار المتجر…',
                                  'En attente du store…',
                                  'Esperando la tienda…',
                                  'Mağaza bekleniyor…',
                                )
                              : t(
                                  'Buy verified Boost',
                                  'شراء Boost موثّق',
                                  'Acheter le Boost vérifié',
                                  'Comprar Boost verificado',
                                  'Doğrulanmış Boost satın al',
                                ),
                        ),
                      ),
                      if (boost.errorCode != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          t(
                            'The store product is not ready or verification failed. No credit was granted.',
                            'منتج المتجر غير جاهز أو فشل التحقق. لم يُمنح أي رصيد.',
                            'Le produit est indisponible ou la vérification a échoué. Aucun crédit accordé.',
                            'El producto no está listo o falló la verificación. No se otorgó crédito.',
                            'Mağaza ürünü hazır değil veya doğrulama başarısız. Kredi verilmedi.',
                          ),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              TextButton(
                onPressed: _manageSubscription,
                child: Text(
                  t(
                    'Manage subscription in store',
                    'إدارة الاشتراك في المتجر',
                    'Gérer l’abonnement',
                    'Gestionar suscripción',
                    'Aboneliği yönet',
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _manageSubscription() async {
    final uri = defaultTargetPlatform == TargetPlatform.iOS
        ? Uri.parse('https://apps.apple.com/account/subscriptions')
        : Uri.parse('https://play.google.com/store/account/subscriptions');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  void dispose() {
    boost.removeListener(_boostChanged);
    boost.dispose();
    super.dispose();
  }
}

class _UsageCard extends StatelessWidget {
  const _UsageCard({required this.label, required this.data});
  final String label;
  final Object? data;

  @override
  Widget build(BuildContext context) {
    final values = data is Map
        ? Map<String, Object?>.from(data! as Map)
        : const <String, Object?>{};
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Weekly: ${values['weekly_remaining'] ?? 0} / ${values['weekly_limit'] ?? 0}',
            ),
            Text('Paid: ${values['paid_remaining'] ?? 0}'),
          ],
        ),
      ),
    );
  }
}
