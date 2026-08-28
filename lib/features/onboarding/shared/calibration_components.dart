part of '../bil_flagship_onboarding.dart';

String _bodyCanvasText(BuildContext context, String english, String arabic) {
  final locale = Localizations.localeOf(context);
  final code = locale.languageCode;
  if (code == 'ar') return arabic;
  final translations = _bodyCanvasCopy[english];
  return translations?[locale.toLanguageTag()] ??
      translations?[code] ??
      english;
}

String _adultEligibilityText(BuildContext context) {
  final locale = Localizations.localeOf(context);
  final tag = locale.toLanguageTag();
  const copy = <String, String>{
    'en': 'BIL is available only to adults aged 18 or older.',
    'ar': 'BIL متاح فقط للبالغين بعمر 18 عامًا أو أكثر.',
    'fr': 'BIL est réservé aux adultes âgés de 18 ans ou plus.',
    'es': 'BIL está disponible solo para adultos mayores de 18 años.',
    'tr': 'BIL yalnızca 18 yaş ve üzerindeki yetişkinler içindir.',
    'de': 'BIL ist nur für Erwachsene ab 18 Jahren verfügbar.',
    'it': 'BIL è disponibile solo per adulti di almeno 18 anni.',
    'pt-BR': 'O BIL está disponível somente para adultos com 18 anos ou mais.',
    'pt-PT': 'O BIL está disponível apenas para adultos com 18 anos ou mais.',
    'ur': 'BIL صرف 18 سال یا اس سے زیادہ عمر کے بالغوں کے لیے دستیاب ہے۔',
    'fa': 'BIL فقط برای بزرگسالان ۱۸ ساله یا بالاتر در دسترس است.',
    'hi': 'BIL केवल 18 वर्ष या उससे अधिक आयु के वयस्कों के लिए उपलब्ध है।',
    'id': 'BIL hanya tersedia untuk orang dewasa berusia 18 tahun ke atas.',
    'ms': 'BIL hanya tersedia untuk orang dewasa berumur 18 tahun ke atas.',
    'ja': 'BIL は18歳以上の成人のみ利用できます。',
    'ko': 'BIL은 만 18세 이상의 성인만 이용할 수 있습니다.',
    'zh-Hans': 'BIL 仅供年满 18 岁的成年人使用。',
    'zh-Hant': 'BIL 僅供年滿 18 歲的成年人使用。',
    'ru': 'BIL доступен только взрослым в возрасте 18 лет и старше.',
    'bn':
        'BIL শুধুমাত্র ১৮ বছর বা তার বেশি বয়সী প্রাপ্তবয়স্কদের জন্য উপলভ্য।',
    'vi': 'BIL chỉ dành cho người lớn từ 18 tuổi trở lên.',
    'th': 'BIL เปิดให้บริการเฉพาะผู้ใหญ่ที่มีอายุ 18 ปีขึ้นไป',
    'pl':
        'BIL jest dostępny tylko dla osób dorosłych w wieku co najmniej 18 lat.',
    'nl': 'BIL is alleen beschikbaar voor volwassenen van 18 jaar en ouder.',
    'uk': 'BIL доступний лише дорослим віком від 18 років.',
  };
  return copy[tag] ?? copy[locale.languageCode] ?? copy['en']!;
}

String _bodyCanvasMonth(BuildContext context, int index) {
  final code = Localizations.localeOf(context).languageCode;
  const months = <String, List<String>>{
    'ar': [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ],
    'en': [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ],
    'fr': [
      'janv.',
      'févr.',
      'mars',
      'avr.',
      'mai',
      'juin',
      'juil.',
      'août',
      'sept.',
      'oct.',
      'nov.',
      'déc.',
    ],
    'es': [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ],
    'tr': [
      'Oca',
      'Şub',
      'Mar',
      'Nis',
      'May',
      'Haz',
      'Tem',
      'Ağu',
      'Eyl',
      'Eki',
      'Kas',
      'Ara',
    ],
  };
  return (months[code] ?? months['en']!)[index];
}

const _bodyCanvasCopy = <String, Map<String, String>>{
  'Weight': {'fr': 'Poids', 'es': 'Peso', 'tr': 'Kilo'},
  'Height': {'fr': 'Taille', 'es': 'Altura', 'tr': 'Boy'},
  'Age': {'fr': 'Âge', 'es': 'Edad', 'tr': 'Yaş'},
  'Sex': {
    'bn': 'লিঙ্গ',
    'de': 'Geschlecht',
    'fa': 'جنسیت',
    'fr': 'Sexe',
    'hi': 'लिंग',
    'id': 'Jenis kelamin',
    'it': 'Sesso',
    'ja': '性別',
    'ko': '성별',
    'ms': 'Jantina',
    'nl': 'Geslacht',
    'pl': 'Płeć',
    'pt-BR': 'Sexo',
    'pt-PT': 'Sexo',
    'ru': 'Пол',
    'es': 'Sexo',
    'th': 'เพศ',
    'tr': 'Cinsiyet',
    'uk': 'Стать',
    'ur': 'جنس',
    'vi': 'Giới tính',
    'zh-Hans': '性别',
    'zh-Hant': '性別',
    'zh': '性别',
  },
  'Goal': {'fr': 'Objectif', 'es': 'Objetivo', 'tr': 'Hedef'},
  'Waist': {'fr': 'Tour de taille', 'es': 'Cintura', 'tr': 'Bel'},
  'Neck': {'fr': 'Tour de cou', 'es': 'Cuello', 'tr': 'Boyun'},
  'Activity': {'fr': 'Activité', 'es': 'Actividad', 'tr': 'Aktivite'},
  'Male': {'fr': 'Homme', 'es': 'Hombre', 'tr': 'Erkek'},
  'Female': {'fr': 'Femme', 'es': 'Mujer', 'tr': 'Kadın'},
  'Lose fat': {
    'fr': 'Perdre de la graisse',
    'es': 'Perder grasa',
    'tr': 'Yağ kaybet',
  },
  'Maintain': {'fr': 'Maintenir', 'es': 'Mantener', 'tr': 'Kiloyu koru'},
  'Build muscle': {
    'fr': 'Prendre du muscle',
    'es': 'Ganar músculo',
    'tr': 'Kas kazan',
  },
  'Low': {'fr': 'Faible', 'es': 'Baja', 'tr': 'Düşük'},
  'Light': {'fr': 'Légère', 'es': 'Ligera', 'tr': 'Hafif'},
  'Moderate': {'fr': 'Modérée', 'es': 'Moderada', 'tr': 'Orta'},
  'High': {'fr': 'Élevée', 'es': 'Alta', 'tr': 'Yüksek'},
  'Very high': {'fr': 'Très élevée', 'es': 'Muy alta', 'tr': 'Çok yüksek'},
  'Save': {'fr': 'Enregistrer', 'es': 'Guardar', 'tr': 'Kaydet'},
  'Choose value and precision — saves automatically': {
    'fr': 'Choisissez la valeur et la précision — enregistrement automatique',
    'es': 'Elige el valor y la precisión — se guarda automáticamente',
    'tr': 'Değeri ve hassasiyeti seçin — otomatik kaydedilir',
  },
  'Not now': {'fr': 'Pas maintenant', 'es': 'Ahora no', 'tr': 'Şimdi değil'},
  'Required': {'fr': 'Obligatoire', 'es': 'Obligatorio', 'tr': 'Gerekli'},
  'Optional': {'fr': 'Facultatif', 'es': 'Opcional', 'tr': 'İsteğe bağlı'},
  'Date of birth': {
    'fr': 'Date de naissance',
    'es': 'Fecha de nacimiento',
    'tr': 'Doğum tarihi',
  },
  'Choose day, month and year — saves automatically': {
    'fr': 'Choisissez le jour, le mois et l’année — enregistrement automatique',
    'es': 'Elige día, mes y año — se guarda automáticamente',
    'tr': 'Gün, ay ve yılı seçin — otomatik kaydedilir',
  },
  'Complete required details': {
    'fr': 'Renseignez les informations requises',
    'es': 'Completa los datos obligatorios',
    'tr': 'Gerekli bilgileri tamamlayın',
  },
  'Back': {'fr': 'Retour', 'es': 'Atrás', 'tr': 'Geri'},
  'Build your body model': {
    'fr': 'Créez votre modèle corporel',
    'es': 'Crea tu modelo corporal',
    'tr': 'Vücut modelinizi oluşturun',
  },
  'Model accuracy': {
    'fr': 'Précision du modèle',
    'es': 'Precisión del modelo',
    'tr': 'Model doğruluğu',
  },
  'Profile completion': {
    'fr': 'Profil complété',
    'es': 'Perfil completado',
    'tr': 'Profil tamamlanma',
  },
  'Private': {'fr': 'Privé', 'es': 'Privado', 'tr': 'Özel'},
  'Explainable': {
    'fr': 'Explicable',
    'es': 'Explicable',
    'tr': 'Açıklanabilir',
  },
};

class _ChoiceData<T> {
  const _ChoiceData({
    required this.value,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final T value;
  final IconData icon;
  final String title;
  final String? subtitle;
}

class _ChoiceTile<T> extends StatelessWidget {
  const _ChoiceTile({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final _ChoiceData<T> data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: selected ? 1 : .985,
      duration: const Duration(milliseconds: 170),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        decoration: BoxDecoration(
          color: selected
              ? _BilColors.emerald.withValues(alpha: .12)
              : _BilColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? _BilColors.emerald : _BilColors.stroke,
            width: selected ? 1.6 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _BilColors.emerald.withValues(alpha: .13),
                    blurRadius: 28,
                    spreadRadius: -8,
                  ),
                ]
              : const [],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                _IconOrb(icon: data.icon, selected: selected),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.title,
                        style: const TextStyle(
                          color: _BilColors.textStrong,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (data.subtitle != null) ...[
                        const SizedBox(height: 5),
                        Text(
                          data.subtitle!,
                          style: const TextStyle(
                            color: _BilColors.textMuted,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? _BilColors.emerald : _BilColors.textDim,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({this.trailing});

  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_BilColors.cyan, _BilColors.emerald],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.auto_graph_rounded, color: Colors.white),
        ),
        const SizedBox(width: 12),
        const Text(
          'BIL',
          style: TextStyle(
            color: Colors.white,
            fontSize: 27,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        ?trailing,
      ],
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 22,
    this.glow = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF101828).withValues(alpha: .08),
                blurRadius: 24,
                spreadRadius: -12,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: const Color(
                  0xFFBDE9FF,
                ).withValues(alpha: glow ? .22 : .10),
                blurRadius: glow ? 34 : 20,
                spreadRadius: -12,
              ),
              BoxShadow(color: _BilColors.stroke, blurRadius: 1),
            ],
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class _IconOrb extends StatelessWidget {
  const _IconOrb({required this.icon, this.selected = false});

  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: (selected ? _BilColors.emerald : _BilColors.cyan).withValues(
          alpha: .12,
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(icon, color: selected ? _BilColors.emerald : _BilColors.cyan),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        gradient: onPressed == null
            ? null
            : const LinearGradient(
                colors: [_BilColors.blue, _BilColors.emerald],
              ),
        color: onPressed == null ? _BilColors.stroke : null,
        borderRadius: BorderRadius.circular(17),
        boxShadow: onPressed == null
            ? null
            : [
                BoxShadow(
                  color: _BilColors.emerald.withValues(alpha: .20),
                  blurRadius: 26,
                  spreadRadius: -9,
                ),
              ],
      ),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.arrow_forward_rounded),
          ],
        ),
      ),
    );
  }
}

class _AmbientBackground extends StatelessWidget {
  const _AmbientBackground();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF3F8FC), Color(0xFFEEF4FA), Color(0xFFF8F6FB)],
        ),
      ),
    );
  }
}

abstract final class _BilColors {
  static const background = Color(0xFFF7F8FB);
  static const surface = Colors.white;
  static const stroke = Color(0xFFE4E7EC);
  static const emerald = Color(0xFF00A884);
  static const cyan = Color(0xFF0066EE);
  static const blue = Color(0xFF0066EE);
  static const textStrong = Color(0xFF101828);
  static const textMuted = Color(0xFF667085);
  static const textDim = Color(0xFF98A2B3);
}
