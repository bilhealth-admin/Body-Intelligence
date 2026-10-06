import 'bil_locale_policy.dart';

part 'runtime_copy_next_workspace_0.dart';
part 'runtime_copy_next_workspace_1.dart';
part 'runtime_copy_next_workspace_2.dart';
part 'runtime_copy_next_workspace_3.dart';

/// Authored next-version workspace and inbox copy; all locale rows are tested.
abstract final class NextWorkspaceRuntimeCopy {
  static const _primarySources = <String>[
    "Could not confirm these updates as read. Please retry.",
    "Mark this page read",
    "Let's make today count.",
    "Today's Focus",
    "One small action at a time. Your coach is here to help you log, reflect, and plan.",
    "Plan Tools",
    "Log a Meal",
    "Voice Log",
    "Just talk",
    "In seconds",
    "Scan Product",
    "Barcode / Label",
    "Turn any meal into insights",
    "Snap a photo to review food and portions before adding it to your log.",
    "Try Photo Logging  ›",
    "Your Health Timeline",
    "Meals logged",
    "{count} meal entries in your actual log",
    "Activity synced",
    "Your verified entries will appear here.",
    "Small consistent actions create meaningful progress.\n— BIL AI Coach",
    "Your health partner, always with you",
    "Search conversations",
  ];
  static const supplementalSources = ['Overview', 'Post photos', 'Home'];
  static const sources = <String>[..._primarySources, ...supplementalSources];
  static const _supplemental = <String, List<String>>{
    'ar': ['نظرة عامة', 'صور المنشور', 'الرئيسية'],
    'fr': ['Vue d’ensemble', 'Photos de la publication', 'Accueil'],
    'es': ['Resumen', 'Fotos de la publicación', 'Inicio'],
    'tr': ['Genel bakış', 'Gönderi fotoğrafları', 'Ana sayfa'],
    'de': ['Übersicht', 'Beitragsfotos', 'Startseite'],
    'it': ['Panoramica', 'Foto del post', 'Pagina iniziale'],
    'pt-BR': ['Visão geral', 'Fotos da publicação', 'Início'],
    'pt-PT': ['Visão geral', 'Fotografias da publicação', 'Início'],
    'ur': ['جائزہ', 'پوسٹ کی تصاویر', 'مرکزی صفحہ'],
    'fa': ['نمای کلی', 'عکس‌های پست', 'خانه'],
    'hi': ['अवलोकन', 'पोस्ट की तस्वीरें', 'मुख्य पृष्ठ'],
    'id': ['Ringkasan', 'Foto postingan', 'Beranda'],
    'ms': ['Gambaran keseluruhan', 'Foto siaran', 'Laman utama'],
    'ja': ['概要', '投稿の写真', 'ホーム'],
    'ko': ['개요', '게시물 사진', '홈'],
    'zh-Hans': ['概览', '帖子照片', '首页'],
    'zh-Hant': ['總覽', '貼文照片', '首頁'],
    'ru': ['Обзор', 'Фотографии публикации', 'Главная'],
    'bn': ['সারসংক্ষেপ', 'পোস্টের ছবি', 'প্রধান পাতা'],
    'vi': ['Tổng quan', 'Ảnh bài viết', 'Trang chủ'],
    'th': ['ภาพรวม', 'รูปภาพของโพสต์', 'หน้าหลัก'],
    'pl': ['Przegląd', 'Zdjęcia wpisu', 'Strona główna'],
    'nl': ['Overzicht', 'Berichtfoto’s', 'Startpagina'],
    'uk': ['Огляд', 'Фотографії допису', 'Головна'],
  };
  static const rows = <String, List<String>>{
    ..._nextWorkspaceRows0,
    ..._nextWorkspaceRows1,
    ..._nextWorkspaceRows2,
    ..._nextWorkspaceRows3,
  };
  static String? resolve(String source, String localeTag) {
    final index = sources.indexOf(source);
    if (index < 0) return null;
    final tag = BilLocalePolicy.canonicalSupportedTag(localeTag);
    if (tag == 'en') return source;
    final primary = rows[tag];
    final supplemental = _supplemental[tag];
    if (primary == null || supplemental == null) return null;
    final row = <String>[...primary, ...supplemental];
    if (row.length != sources.length) {
      throw StateError('Incomplete next workspace copy for $tag');
    }
    return row[index];
  }
}
