part of 'ai_coach_settings_page.dart';

class _BoostCard extends StatelessWidget {
  const _BoostCard({required this.boost, required this.t});
  final AiBoostPurchaseService boost;
  final _Copy t;

  @override
  Widget build(BuildContext context) => _PremiumCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final artworkSize = (constraints.maxWidth * .24)
                .clamp(72.0, 96.0)
                .toDouble();
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BilAiBoostCoachArtwork(
                  key: const ValueKey('settings-ai-boost-coach-artwork'),
                  size: artworkSize,
                  semanticLabel: 'BIL AI Boost',
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BIL AI Boost',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: const Color(0xFF071923),
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        '+2,500 BIL AI Tokens',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: const Color(0xFF071923),
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        Text(
          t(
            'A verified, non-expiring balance for text, voice, or Vision. Price is supplied by your store.',
            'رصيد موثّق لا تنتهي صلاحيته للنص أو الصوت أو الصور. يعرض متجرك السعر.',
            'Un solde vérifié sans expiration. Le prix vient de votre boutique.',
            'Saldo verificado sin caducidad. Tu tienda muestra el precio.',
            'Metin, ses ve görüntü için süresiz bakiye. Fiyatı mağazanız gösterir.',
          ),
          style: const TextStyle(color: Color(0xFF536873), height: 1.4),
        ),
        if (boost.product != null) ...[
          const SizedBox(height: 7),
          Text(
            boost.product!.price,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
        ],
        const SizedBox(height: 14),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF12394E),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: boost.state == AiBoostPurchaseState.ready
              ? boost.purchaseBoost
              : null,
          icon: Icon(
            boost.state == AiBoostPurchaseState.pending
                ? Icons.hourglass_top_rounded
                : Icons.lock_rounded,
          ),
          label: Text(
            boost.state == AiBoostPurchaseState.pending
                ? t(
                    'Waiting for store…',
                    'بانتظار المتجر…',
                    'En attente…',
                    'Esperando…',
                    'Mağaza bekleniyor…',
                  )
                : t(
                    'Buy verified Boost',
                    'شراء Boost موثّق',
                    'Acheter le Boost',
                    'Comprar Boost',
                    'Doğrulanmış Boost al',
                  ),
          ),
        ),
        if (boost.errorCode != null) ...[
          const SizedBox(height: 8),
          Text(
            t(
              'The store product is unavailable or verification failed. No tokens were granted.',
              'منتج المتجر غير متاح أو فشل التحقق. لم يُمنح أي رصيد.',
              'Le produit est indisponible ou la vérification a échoué.',
              'El producto no está disponible o falló la verificación.',
              'Ürün kullanılamıyor veya doğrulama başarısız.',
            ),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    ),
  );
}

String _number(int value) {
  final source = value.toString();
  return source.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
}
