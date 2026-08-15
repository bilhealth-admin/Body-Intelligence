class NutritionPathwayTranslation {
  const NutritionPathwayTranslation(
    this.title,
    this.subtitle,
    this.tags,
    this.approach,
    this.tracking,
  );
  final String title;
  final String subtitle;
  final List<String> tags;
  final List<String> approach;
  final List<String> tracking;
}

const nutritionPathwayTranslations =
    <String, Map<String, NutritionPathwayTranslation>>{
      'fr': {
        'cutting': NutritionPathwayTranslation(
          'Perte de graisse intelligente',
          'Un déficit mesuré pour préserver la masse maigre',
          ['Protéines élevées', 'Déficit modéré', 'Révisable'],
          [
            'Définir le déficit selon les données mesurées',
            'Répartir les protéines entre les repas',
            'Réviser selon le poids et les performances',
          ],
          ['Tendance du poids', 'Force et récupération', 'Faim et adhésion'],
        ),
        'lean-mass': NutritionPathwayTranslation(
          'Construction de masse maigre',
          'Un surplus contrôlé pour l’entraînement et la récupération',
          ['Performance', 'Récupération', 'Surplus contrôlé'],
          [
            'Commencer par un petit surplus révisable',
            'Adapter les repas à la charge d’entraînement',
            'Augmenter l’énergie seulement si les données le justifient',
          ],
          [
            'Performance',
            'Tendance du poids',
            'Tour de taille et récupération',
          ],
        ),
        'mediterranean': NutritionPathwayTranslation(
          'Méditerranéen',
          'Aliments entiers flexibles et graisses insaturées',
          ['Santé cardiaque', 'Flexible', 'Fibres'],
          [
            'Privilégier légumes, céréales complètes et légumineuses',
            'Préférer les graisses insaturées',
            'Garder une flexibilité sociale',
          ],
          ['Fibres', 'Variété alimentaire', 'Régularité hebdomadaire'],
        ),
        'high-protein': NutritionPathwayTranslation(
          'Équilibré riche en protéines',
          'Satiété et soutien musculaire sans restriction extrême',
          ['Équilibré', 'Satiété', 'Soutien musculaire'],
          [
            'Varier les sources de protéines',
            'Les répartir dans la journée',
            'Conserver glucides et lipides de qualité',
          ],
          ['Protéines enregistrées', 'Satiété', 'Performance'],
        ),
        'plant-forward': NutritionPathwayTranslation(
          'À dominante végétale',
          'Plus de végétaux avec protéines et micronutriments planifiés',
          ['Dominante végétale', 'Fibres', 'Variété'],
          [
            'Augmenter progressivement les végétaux',
            'Planifier les protéines',
            'Vérifier les micronutriments en cas de restriction',
          ],
          ['Variété végétale', 'Protéines', 'Micronutriments'],
        ),
        'dash': NutritionPathwayTranslation(
          'Modèle DASH',
          'Un modèle équilibré axé sur la qualité et le sodium',
          ['Sodium maîtrisé', 'Équilibré', 'Révision'],
          [
            'Préférer les aliments peu transformés',
            'Comparer le sodium des étiquettes vérifiées',
            'Consulter en cas de maladie ou traitement',
          ],
          ['Sodium', 'Qualité alimentaire', 'Mesures vérifiées'],
        ),
        'low-carb': NutritionPathwayTranslation(
          'Méditerranéen pauvre en glucides',
          'Moins de glucides avec fibres et graisses insaturées',
          ['Méditerranéen', 'Flexible', 'Fibres'],
          [
            'Réduire les glucides sans supprimer les fibres',
            'Choisir des sources peu transformées',
            'Adapter selon la réponse et l’adhésion',
          ],
          ['Fibres', 'Énergie et faim', 'Tendance du poids'],
        ),
        'keto': NutritionPathwayTranslation(
          'Céto guidé',
          'Très peu de glucides avec des limites explicites',
          ['Très pauvre en glucides', 'Électrolytes', 'Révision'],
          [
            'Vérifier l’adéquation avant de commencer',
            'Ne jamais modifier seul médicaments ou liquides',
            'Utiliser un brouillon arrêtable et révisable',
          ],
          ['Symptômes', 'Adhésion', 'Avis clinique'],
        ),
        'pregnancy': NutritionPathwayTranslation(
          'Nutrition pendant la grossesse',
          'Soutien adapté au trimestre et aux conseils cliniques',
          ['Micronutriments', 'Sécurité alimentaire', 'Avis clinique'],
          [
            'Aligner le brouillon sur le trimestre et les conseils cliniques',
            'Prioriser la sécurité alimentaire',
            'Aucun déficit ni supplément sans avis',
          ],
          ['Conseils cliniques', 'Sécurité alimentaire', 'Qualité du suivi'],
        ),
        'psmf': NutritionPathwayTranslation(
          'PSMF sous supervision clinique',
          'Un protocole restrictif non destiné à l’automédication',
          ['Supervision médicale', 'Non autonome', 'Suivi'],
          [
            'BIL ne génère jamais de PSMF autonome',
            'Approbation et suivi cliniques réels requis',
            'Le parcours reste verrouillé sans supervision',
          ],
          ['Approbation clinique', 'Suivi clinique', 'État de sécurité'],
        ),
      },
      'es': {
        'cutting': NutritionPathwayTranslation(
          'Pérdida de grasa inteligente',
          'Déficit medido para preservar masa magra',
          ['Más proteína', 'Déficit moderado', 'Revisable'],
          [
            'Definir el déficit con datos medidos',
            'Distribuir la proteína entre comidas',
            'Revisar según peso y rendimiento',
          ],
          [
            'Tendencia del peso',
            'Fuerza y recuperación',
            'Hambre y adherencia',
          ],
        ),
        'lean-mass': NutritionPathwayTranslation(
          'Desarrollo de masa magra',
          'Superávit controlado para entrenamiento y recuperación',
          ['Rendimiento', 'Recuperación', 'Superávit controlado'],
          [
            'Empezar con un pequeño superávit revisable',
            'Ajustar comidas a la carga de entrenamiento',
            'Aumentar energía solo con evidencia',
          ],
          ['Rendimiento', 'Tendencia del peso', 'Cintura y recuperación'],
        ),
        'mediterranean': NutritionPathwayTranslation(
          'Mediterránea',
          'Alimentos integrales flexibles con grasas insaturadas',
          ['Salud cardíaca', 'Flexible', 'Fibra'],
          [
            'Priorizar verduras, cereales integrales y legumbres',
            'Preferir grasas insaturadas',
            'Mantener flexibilidad social',
          ],
          ['Fibra', 'Variedad alimentaria', 'Constancia semanal'],
        ),
        'high-protein': NutritionPathwayTranslation(
          'Equilibrada alta en proteína',
          'Saciedad y apoyo muscular sin restricción extrema',
          ['Equilibrada', 'Saciedad', 'Apoyo muscular'],
          [
            'Usar fuentes variadas de proteína',
            'Distribuirlas durante el día',
            'Mantener carbohidratos y grasas de calidad',
          ],
          ['Proteína registrada', 'Saciedad', 'Rendimiento'],
        ),
        'plant-forward': NutritionPathwayTranslation(
          'Predominio vegetal',
          'Más plantas con proteína y micronutrientes planificados',
          ['Predominio vegetal', 'Fibra', 'Variedad'],
          [
            'Aumentar plantas gradualmente',
            'Planificar la proteína',
            'Revisar micronutrientes si hay restricciones',
          ],
          ['Variedad vegetal', 'Proteína', 'Micronutrientes'],
        ),
        'dash': NutritionPathwayTranslation(
          'Patrón DASH',
          'Patrón equilibrado centrado en calidad y sodio',
          ['Sodio consciente', 'Equilibrado', 'Revisión'],
          [
            'Preferir alimentos poco procesados',
            'Comparar sodio en etiquetas verificadas',
            'Consultar si hay enfermedad o medicación',
          ],
          ['Sodio', 'Calidad alimentaria', 'Mediciones verificadas'],
        ),
        'low-carb': NutritionPathwayTranslation(
          'Mediterránea baja en carbohidratos',
          'Menos carbohidratos con fibra y grasas insaturadas',
          ['Mediterránea', 'Flexible', 'Fibra'],
          [
            'Reducir carbohidratos sin eliminar fibra',
            'Elegir fuentes poco procesadas',
            'Ajustar a respuesta y adherencia',
          ],
          ['Fibra', 'Energía y hambre', 'Tendencia del peso'],
        ),
        'keto': NutritionPathwayTranslation(
          'Keto guiada',
          'Muy pocos carbohidratos con límites explícitos',
          ['Muy baja en carbohidratos', 'Electrolitos', 'Revisión'],
          [
            'Comprobar idoneidad antes de empezar',
            'No ajustar medicación ni líquidos por cuenta propia',
            'Usar un borrador reversible y revisable',
          ],
          ['Síntomas', 'Adherencia', 'Revisión clínica'],
        ),
        'pregnancy': NutritionPathwayTranslation(
          'Nutrición en el embarazo',
          'Apoyo según trimestre y consejo clínico',
          ['Micronutrientes', 'Seguridad alimentaria', 'Revisión clínica'],
          [
            'Alinear el borrador con trimestre y consejo clínico',
            'Priorizar seguridad alimentaria',
            'Sin déficits ni suplementos sin revisión',
          ],
          [
            'Consejo clínico',
            'Seguridad alimentaria',
            'Suficiencia del registro',
          ],
        ),
        'psmf': NutritionPathwayTranslation(
          'PSMF con supervisión clínica',
          'Protocolo restrictivo no apto para uso autónomo',
          ['Supervisión médica', 'No autónomo', 'Seguimiento'],
          [
            'BIL nunca genera un PSMF autónomo',
            'Se requieren aprobación y seguimiento clínicos',
            'La ruta permanece bloqueada sin supervisión',
          ],
          ['Aprobación clínica', 'Seguimiento clínico', 'Estado de seguridad'],
        ),
      },
      'tr': {
        'cutting': NutritionPathwayTranslation(
          'Akıllı yağ kaybı',
          'Yağsız kütleyi koruyan ölçülü açık',
          ['Yüksek protein', 'Orta açık', 'Gözden geçirilebilir'],
          [
            'Açığı ölçülen verilerle belirleyin',
            'Proteini öğünlere dağıtın',
            'Kilo ve performansa göre gözden geçirin',
          ],
          ['Kilo eğilimi', 'Güç ve toparlanma', 'Açlık ve uyum'],
        ),
        'lean-mass': NutritionPathwayTranslation(
          'Yağsız kütle gelişimi',
          'Antrenman ve toparlanma için kontrollü fazla',
          ['Performans', 'Toparlanma', 'Kontrollü fazla'],
          [
            'Küçük bir fazla ile başlayın',
            'Öğünleri antrenman yüküne uydurun',
            'Enerjiyi yalnızca kanıt varsa artırın',
          ],
          ['Performans', 'Kilo eğilimi', 'Bel ve toparlanma'],
        ),
        'mediterranean': NutritionPathwayTranslation(
          'Akdeniz',
          'Doymamış yağlarla esnek tam gıdalar',
          ['Kalp sağlığı', 'Esnek', 'Lif'],
          [
            'Sebze, tam tahıl ve bakliyatı temel alın',
            'Doymamış yağları seçin',
            'Sosyal esnekliği koruyun',
          ],
          ['Lif', 'Gıda çeşitliliği', 'Haftalık tutarlılık'],
        ),
        'high-protein': NutritionPathwayTranslation(
          'Dengeli yüksek protein',
          'Aşırı kısıtlama olmadan tokluk ve kas desteği',
          ['Dengeli', 'Tokluk', 'Kas desteği'],
          [
            'Farklı protein kaynakları kullanın',
            'Gün içine dağıtın',
            'Kaliteli karbonhidrat ve yağa yer bırakın',
          ],
          ['Kayıtlı protein', 'Tokluk', 'Performans'],
        ),
        'plant-forward': NutritionPathwayTranslation(
          'Bitki ağırlıklı',
          'Planlı protein ve mikro besinlerle daha fazla bitki',
          ['Bitki ağırlıklı', 'Lif', 'Çeşitlilik'],
          [
            'Bitkileri kademeli artırın',
            'Proteini planlayın',
            'Kısıtlamada mikro besinleri inceleyin',
          ],
          ['Bitki çeşitliliği', 'Protein', 'Mikro besinler'],
        ),
        'dash': NutritionPathwayTranslation(
          'DASH düzeni',
          'Gıda kalitesi ve sodyuma odaklı dengeli düzen',
          ['Sodyum bilinci', 'Dengeli', 'İnceleme'],
          [
            'Az işlenmiş gıdaları seçin',
            'Doğrulanmış etiketlerden sodyumu karşılaştırın',
            'Hastalık veya ilaçta uzmana danışın',
          ],
          ['Sodyum', 'Gıda kalitesi', 'Doğrulanmış ölçümler'],
        ),
        'low-carb': NutritionPathwayTranslation(
          'Düşük karbonhidratlı Akdeniz',
          'Lif ve doymamış yağlarla daha az karbonhidrat',
          ['Akdeniz', 'Esnek', 'Lif'],
          [
            'Lifi kaldırmadan karbonhidratı azaltın',
            'Az işlenmiş kaynaklar seçin',
            'Yanıt ve uyuma göre ayarlayın',
          ],
          ['Lif', 'Enerji ve açlık', 'Kilo eğilimi'],
        ),
        'keto': NutritionPathwayTranslation(
          'Rehberli keto',
          'Açık sınırlarla çok düşük karbonhidrat',
          ['Çok düşük karbonhidrat', 'Elektrolitler', 'İnceleme'],
          [
            'Başlamadan uygunluğu kontrol edin',
            'İlaç veya sıvıyı kendiniz ayarlamayın',
            'Durdurulabilir ve incelenebilir taslak kullanın',
          ],
          ['Belirtiler', 'Uyum', 'Uzman incelemesi'],
        ),
        'pregnancy': NutritionPathwayTranslation(
          'Gebelik beslenmesi',
          'Trimester ve uzman önerisine uygun destek',
          ['Mikro besinler', 'Gıda güvenliği', 'Uzman incelemesi'],
          [
            'Taslağı trimester ve uzman rehberliğine uydurun',
            'Gıda güvenliğine öncelik verin',
            'İnceleme olmadan açık veya takviye belirlemeyin',
          ],
          ['Uzman rehberliği', 'Gıda güvenliği', 'Kayıt yeterliliği'],
        ),
        'psmf': NutritionPathwayTranslation(
          'Uzman gözetimli PSMF',
          'Kendi kendine uygulanmayan kısıtlayıcı protokol',
          ['Tıbbi gözetim', 'Kendi kendine değil', 'İzleme'],
          [
            'BIL kendi kendine PSMF oluşturmaz',
            'Gerçek klinik onay ve izleme gerekir',
            'Gözetim olmadan yol kilitli kalır',
          ],
          ['Uzman onayı', 'Klinik izleme', 'Güvenlik durumu'],
        ),
      },
    };
