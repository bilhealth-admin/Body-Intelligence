import 'package:flutter/widgets.dart';
import '../../../app/localization/bil_locale_policy.dart';

class CommunityCodePrivacyCopy {
  CommunityCodePrivacyCopy.of(BuildContext context)
    : this.forTag(
        BilLocalePolicy.canonicalTag(Localizations.localeOf(context)),
      );
  CommunityCodePrivacyCopy.forTag(String tag) : _row = rows[tag] ?? rows['en']!;
  final List<String> _row;
  String get intro => _row[0];
  String get blocked => _row[1];
  String get check => _row[2];
  static const rows = <String, List<String>>{
    "en": [
      "This code identifies your Community profile. It cannot sign anyone in.",
      "Your privacy settings prevent friends from finding you with this code.",
      "Review your Community privacy settings before sharing this code.",
    ],
    "ar": [
      "هذا الرمز يعرّف بملفك في المجتمع، ولا يمكنه تسجيل دخول أي شخص.",
      "إعدادات الخصوصية تمنع الأصدقاء من العثور عليك بهذا الرمز.",
      "راجع إعدادات خصوصية المجتمع قبل مشاركة هذا الرمز.",
    ],
    "fr": [
      "Ce code identifie votre profil communautaire. Il ne permet de connecter personne.",
      "Vos réglages de confidentialité empêchent vos amis de vous trouver avec ce code.",
      "Vérifiez la confidentialité de votre profil communautaire avant de partager ce code.",
    ],
    "es": [
      "Este código identifica tu perfil de Comunidad. No permite iniciar sesión.",
      "Tu configuración de privacidad impide que tus amigos te encuentren con este código.",
      "Revisa la privacidad de tu perfil de Comunidad antes de compartir este código.",
    ],
    "tr": [
      "Bu kod Topluluk profilinizi tanımlar. Kimsenin oturum açmasını sağlamaz.",
      "Gizlilik ayarlarınız arkadaşlarınızın sizi bu kodla bulmasını engelliyor.",
      "Bu kodu paylaşmadan önce Topluluk gizlilik ayarlarınızı gözden geçirin.",
    ],
    "de": [
      "Dieser Code kennzeichnet dein Community-Profil. Er ermöglicht keine Anmeldung.",
      "Deine Datenschutzeinstellungen verhindern, dass Freunde dich mit diesem Code finden.",
      "Prüfe die Datenschutzeinstellungen deines Community-Profils, bevor du diesen Code teilst.",
    ],
    "it": [
      "Questo codice identifica il tuo profilo Community. Non consente di accedere a un account.",
      "Le tue impostazioni di privacy impediscono agli amici di trovarti con questo codice.",
      "Controlla la privacy del tuo profilo Community prima di condividere questo codice.",
    ],
    "pt-BR": [
      "Este código identifica seu perfil na Comunidade. Ele não permite fazer login.",
      "Suas configurações de privacidade impedem que amigos encontrem você com este código.",
      "Revise a privacidade do seu perfil na Comunidade antes de compartilhar este código.",
    ],
    "pt-PT": [
      "Este código identifica o teu perfil na Comunidade. Não permite iniciar sessão.",
      "As tuas definições de privacidade impedem os amigos de te encontrarem com este código.",
      "Revê a privacidade do teu perfil na Comunidade antes de partilhares este código.",
    ],
    "ur": [
      "یہ کوڈ کمیونٹی میں آپ کی پروفائل کی شناخت کرتا ہے۔ اس سے کوئی سائن ان نہیں کر سکتا۔",
      "آپ کی رازداری کی ترتیبات دوستوں کو اس کوڈ سے آپ کو تلاش کرنے سے روکتی ہیں۔",
      "یہ کوڈ شیئر کرنے سے پہلے کمیونٹی کی رازداری کی ترتیبات دیکھیں۔",
    ],
    "fa": [
      "این کد نمایهٔ انجمن شما را مشخص می‌کند و امکان ورود به حساب را نمی‌دهد.",
      "تنظیمات حریم خصوصی شما مانع می‌شود دوستان با این کد شما را پیدا کنند.",
      "پیش از اشتراک‌گذاری این کد، تنظیمات حریم خصوصی انجمن را بررسی کنید.",
    ],
    "hi": [
      "यह कोड आपकी कम्युनिटी प्रोफ़ाइल की पहचान करता है। इससे कोई साइन इन नहीं कर सकता।",
      "आपकी गोपनीयता सेटिंग दोस्तों को इस कोड से आपको ढूँढने से रोकती हैं।",
      "यह कोड साझा करने से पहले कम्युनिटी की गोपनीयता सेटिंग देखें।",
    ],
    "id": [
      "Kode ini mengidentifikasi profil Komunitas Anda. Kode ini tidak dapat digunakan untuk masuk akun.",
      "Pengaturan privasi Anda mencegah teman menemukan Anda dengan kode ini.",
      "Tinjau pengaturan privasi Komunitas sebelum membagikan kode ini.",
    ],
    "ms": [
      "Kod ini mengenal pasti profil Komuniti anda. Ia tidak boleh digunakan untuk log masuk.",
      "Tetapan privasi anda menghalang rakan daripada mencari anda dengan kod ini.",
      "Semak tetapan privasi Komuniti sebelum berkongsi kod ini.",
    ],
    "ja": [
      "このコードはコミュニティのプロフィールを識別するものです。ログインには使えません。",
      "プライバシー設定により、友だちはこのコードであなたを見つけることができません。",
      "このコードを共有する前に、コミュニティのプライバシー設定を確認してください。",
    ],
    "ko": [
      "이 코드는 커뮤니티 프로필을 식별하며 로그인에는 사용할 수 없습니다.",
      "개인정보 설정 때문에 친구가 이 코드로 회원님을 찾을 수 없습니다.",
      "이 코드를 공유하기 전에 커뮤니티 개인정보 설정을 확인하세요.",
    ],
    "zh-Hans": [
      "此代码用于识别你的社区个人资料，不能用于登录。",
      "你的隐私设置阻止好友通过此代码找到你。",
      "分享此代码前，请检查社区隐私设置。",
    ],
    "zh-Hant": [
      "此代碼用於識別你的社群個人資料，不能用來登入。",
      "你的隱私設定會阻止好友透過此代碼找到你。",
      "分享此代碼前，請檢查社群隱私設定。",
    ],
    "ru": [
      "Этот код обозначает ваш профиль в Сообществе. Войти в аккаунт с его помощью нельзя.",
      "Ваши настройки конфиденциальности не позволяют друзьям найти вас по этому коду.",
      "Перед отправкой кода проверьте настройки конфиденциальности Сообщества.",
    ],
    "bn": [
      "এই কোডটি আপনার কমিউনিটি প্রোফাইল চিহ্নিত করে। এটি দিয়ে কেউ সাইন ইন করতে পারে না।",
      "আপনার গোপনীয়তার সেটিংস বন্ধুদের এই কোড দিয়ে আপনাকে খুঁজে পেতে বাধা দেয়।",
      "কোডটি শেয়ার করার আগে কমিউনিটির গোপনীয়তার সেটিংস দেখুন।",
    ],
    "vi": [
      "Mã này xác định hồ sơ Cộng đồng của bạn, không dùng để đăng nhập.",
      "Cài đặt quyền riêng tư đang ngăn bạn bè tìm thấy bạn bằng mã này.",
      "Hãy xem lại cài đặt quyền riêng tư của Cộng đồng trước khi chia sẻ mã này.",
    ],
    "th": [
      "รหัสนี้ใช้ระบุโปรไฟล์ชุมชนของคุณ ไม่สามารถใช้เข้าสู่ระบบได้",
      "การตั้งค่าความเป็นส่วนตัวทำให้เพื่อนไม่สามารถค้นหาคุณด้วยรหัสนี้ได้",
      "ตรวจสอบการตั้งค่าความเป็นส่วนตัวของชุมชนก่อนแชร์รหัสนี้",
    ],
    "pl": [
      "Ten kod wskazuje Twój profil w Społeczności. Nie umożliwia logowania.",
      "Twoje ustawienia prywatności uniemożliwiają znajomym znalezienie Cię za pomocą tego kodu.",
      "Przed udostępnieniem kodu sprawdź ustawienia prywatności Społeczności.",
    ],
    "nl": [
      "Deze code verwijst naar je Community-profiel. Je kunt er niet mee inloggen.",
      "Door je privacyinstellingen kunnen vrienden je niet met deze code vinden.",
      "Controleer je privacyinstellingen voor de Community voordat je deze code deelt.",
    ],
    "uk": [
      "Цей код позначає ваш профіль у Спільноті. Увійти в обліковий запис за ним неможливо.",
      "Ваші налаштування приватності не дозволяють друзям знайти вас за цим кодом.",
      "Перед поширенням коду перевірте налаштування приватності Спільноти.",
    ],
  };
}
