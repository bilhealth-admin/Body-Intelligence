import 'package:flutter/widgets.dart';

import '../../app/localization/app_localizations.dart';

/// Locale-aware copy for analytics surfaces while their legacy prose is
/// progressively moved into the central catalog.
String analyticsText(BuildContext context, String english, String arabic) {
  final language = Localizations.localeOf(context).languageCode;
  final authored = _copy[english];
  return switch (language) {
    'ar' => arabic,
    'en' => english,
    'fr' => authored?.fr ?? 'Informations analytiques indisponibles',
    'es' => authored?.es ?? 'Información analítica no disponible',
    'tr' => authored?.tr ?? 'Analiz bilgisi kullanılamıyor',
    _ => context.strings.text(english),
  };
}

const _copy = <String, ({String fr, String es, String tr})>{
  'Open nutrition analytics': (
    fr: 'Ouvrir les analyses nutritionnelles',
    es: 'Abrir análisis de nutrición',
    tr: 'Beslenme analizlerini aç',
  ),
  'Analytics': (fr: 'Analyses', es: 'Análisis', tr: 'Analizler'),
  'Loading analytics': (
    fr: 'Chargement des analyses',
    es: 'Cargando análisis',
    tr: 'Analizler yükleniyor',
  ),
  'Create a share report': (
    fr: 'Créer un rapport à partager',
    es: 'Crear un informe para compartir',
    tr: 'Paylaşılabilir rapor oluştur',
  ),
  'Back to settings': (
    fr: 'Retour aux paramètres',
    es: 'Volver a ajustes',
    tr: 'Ayarlara dön',
  ),
  'Weekly review': (
    fr: 'Bilan hebdomadaire',
    es: 'Revisión semanal',
    tr: 'Haftalık değerlendirme',
  ),
  'Your personal baseline': (
    fr: 'Votre référence personnelle',
    es: 'Tu referencia personal',
    tr: 'Kişisel başlangıç düzeyiniz',
  ),
  'Tracked days': (
    fr: 'Jours suivis',
    es: 'Días registrados',
    tr: 'İzlenen günler',
  ),
  'Weight points': (
    fr: 'Mesures de poids',
    es: 'Mediciones de peso',
    tr: 'Kilo ölçümleri',
  ),
  'Evidence confidence': (
    fr: 'Fiabilité des preuves',
    es: 'Confianza de la evidencia',
    tr: 'Kanıt güveni',
  ),
  'Selected range': (
    fr: 'Période choisie',
    es: 'Periodo seleccionado',
    tr: 'Seçilen aralık',
  ),
  'What changed': (fr: 'Ce qui a changé', es: 'Qué cambió', tr: 'Ne değişti'),
  'Change': (fr: 'Variation', es: 'Cambio', tr: 'Değişim'),
  'Weight over time': (
    fr: 'Évolution du poids',
    es: 'Peso a lo largo del tiempo',
    tr: 'Zaman içinde kilo',
  ),
  'Weight chart with evidence explanation': (
    fr: 'Graphique du poids avec explication des preuves',
    es: 'Gráfico de peso con explicación de la evidencia',
    tr: 'Kanıt açıklamalı kilo grafiği',
  ),
  'Add weight entries to unlock trend interpretation.': (
    fr: 'Ajoutez des mesures de poids pour interpréter la tendance.',
    es: 'Añade registros de peso para interpretar la tendencia.',
    tr: 'Eğilim yorumunu açmak için kilo kayıtları ekleyin.',
  ),
  'Recorded-day coverage': (
    fr: 'Couverture des jours enregistrés',
    es: 'Cobertura de días registrados',
    tr: 'Kayıtlı gün kapsamı',
  ),
  'Analytics time range': (
    fr: 'Période d’analyse',
    es: 'Periodo de análisis',
    tr: 'Analiz zaman aralığı',
  ),
  '7 days': (fr: '7 jours', es: '7 días', tr: '7 gün'),
  '30 days': (fr: '30 jours', es: '30 días', tr: '30 gün'),
  '90 days': (fr: '90 jours', es: '90 días', tr: '90 gün'),
  'All': (fr: 'Tout', es: 'Todo', tr: 'Tümü'),
  'Last 7 days': (
    fr: '7 derniers jours',
    es: 'Últimos 7 días',
    tr: 'Son 7 gün',
  ),
  'Last 30 days': (
    fr: '30 derniers jours',
    es: 'Últimos 30 días',
    tr: 'Son 30 gün',
  ),
  'Last 90 days': (
    fr: '90 derniers jours',
    es: 'Últimos 90 días',
    tr: 'Son 90 gün',
  ),
  'All time': (
    fr: 'Toute la période',
    es: 'Todo el periodo',
    tr: 'Tüm zamanlar',
  ),
  'Start': (fr: 'Début', es: 'Inicio', tr: 'Başlangıç'),
  'Current': (fr: 'Actuel', es: 'Actual', tr: 'Güncel'),
  'Range change': (
    fr: 'Variation sur la période',
    es: 'Cambio del periodo',
    tr: 'Aralık değişimi',
  ),
  'recorded': (fr: 'enregistré', es: 'registrado', tr: 'kayıtlı'),
  'missing': (fr: 'manquant', es: 'sin registro', tr: 'eksik'),
  'insufficient': (fr: 'insuffisante', es: 'insuficiente', tr: 'yetersiz'),
  'low': (fr: 'faible', es: 'baja', tr: 'düşük'),
  'medium': (fr: 'moyenne', es: 'media', tr: 'orta'),
  'high': (fr: 'élevée', es: 'alta', tr: 'yüksek'),
  'Evidence and limits': (
    fr: 'Preuves et limites',
    es: 'Evidencia y límites',
    tr: 'Kanıtlar ve sınırlar',
  ),
  'Confidence': (fr: 'Fiabilité', es: 'Confianza', tr: 'Güven'),
  'Source: saved local meal, water, and weight records.': (
    fr: 'Source : journaux locaux enregistrés des repas, de l’eau et du poids.',
    es: 'Fuente: registros locales guardados de comidas, agua y peso.',
    tr: 'Kaynak: kayıtlı yerel öğün, su ve kilo kayıtları.',
  ),
  'Days without records': (
    fr: 'Jours sans données',
    es: 'Días sin registros',
    tr: 'Kayıtsız günler',
  ),
  'They are not filled or estimated.': (
    fr: 'Ils ne sont ni complétés ni estimés.',
    es: 'No se completan ni se estiman.',
    tr: 'Doldurulmaz veya tahmin edilmez.',
  ),
  'Measured weight change in range': (
    fr: 'Variation de poids mesurée sur la période',
    es: 'Cambio de peso medido en el periodo',
    tr: 'Aralıktaki ölçülen kilo değişimi',
  ),
  'Generated locally and available offline; sync never changes the calculation.': (
    fr: 'Généré localement et disponible hors ligne ; la synchronisation ne modifie jamais le calcul.',
    es: 'Generado localmente y disponible sin conexión; la sincronización nunca cambia el cálculo.',
    tr: 'Yerel olarak oluşturulur ve çevrimdışı kullanılabilir; eşitleme hesabı değiştirmez.',
  ),
  'Saved records could not be read. Your data was not lost; try again.': (
    fr: 'Impossible de lire les données enregistrées. Elles ne sont pas perdues ; réessayez.',
    es: 'No se pudieron leer los registros guardados. Tus datos no se perdieron; inténtalo de nuevo.',
    tr: 'Kayıtlı veriler okunamadı. Verileriniz kaybolmadı; yeniden deneyin.',
  ),
};
