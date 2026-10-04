import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_community_review.dart';
import 'package:body_intelligence_log/features/community/presentation/community_copy.dart';
import 'package:flutter_test/flutter_test.dart';

// Authored copy fixture, not native-speaker approval or device/layout evidence.
const _publishRecoverySources = <String>[
  "A previous publishing attempt is still unresolved. Retry its original content or cancel the pending attempt before changing it.",
  "Cancel pending attempt",
  "Could not finish verifying cancellation. Retry before publishing again.",
  "The previous attempt was already published. Check My posts before publishing again.",
  "The previous publishing operation completed, but its post is no longer available. This cancellation did not delete any media.",
];

// Independent exact expected cells detect shifted rows and truncated strings.
const _publishRecoveryExpected = <String, List<String>>{
  "en": [
    "A previous publishing attempt is still unresolved. Retry its original content or cancel the pending attempt before changing it.",
    "Cancel pending attempt",
    "Could not finish verifying cancellation. Retry before publishing again.",
    "The previous attempt was already published. Check My posts before publishing again.",
    "The previous publishing operation completed, but its post is no longer available. This cancellation did not delete any media.",
  ],
  "ar": [
    "لم تُحسم محاولة النشر السابقة. أعد المحاولة بمحتواها الأصلي أو ألغِ المحاولة المعلّقة قبل تغييره.",
    "إلغاء المحاولة المعلّقة",
    "تعذر إكمال التحقق من الإلغاء. أعد المحاولة قبل النشر مجددًا.",
    "نُشرت المحاولة السابقة بالفعل. تحقق من منشوراتي قبل النشر مجددًا.",
    "اكتملت عملية النشر السابقة، لكن منشورها لم يعد متاحًا. لم يحذف هذا الإلغاء أي وسائط.",
  ],
  "fr": [
    "Une tentative de publication précédente reste non résolue. Réessayez avec son contenu d’origine ou annulez la tentative en attente avant de modifier ce contenu.",
    "Annuler la tentative en attente",
    "La vérification de l’annulation n’a pas pu être terminée. Réessayez avant de publier à nouveau.",
    "La tentative précédente a déjà abouti à une publication. Consultez Mes publications avant de publier à nouveau.",
    "L’opération de publication précédente s’est terminée, mais sa publication n’est plus disponible. Cette annulation n’a supprimé aucun média.",
  ],
  "es": [
    "Un intento de publicación anterior sigue sin resolverse. Vuelve a intentarlo con su contenido original o cancela el intento pendiente antes de cambiar ese contenido.",
    "Cancelar el intento pendiente",
    "No se pudo terminar de verificar la cancelación. Vuelve a intentarlo antes de publicar de nuevo.",
    "El intento anterior ya se publicó. Revisa Mis publicaciones antes de publicar de nuevo.",
    "La operación de publicación anterior terminó, pero su publicación ya no está disponible. Esta cancelación no eliminó ningún archivo multimedia.",
  ],
  "tr": [
    "Önceki bir yayınlama girişimi hâlâ sonuçlanmadı. İçeriği değiştirmeden önce özgün içeriğiyle yeniden deneyin veya bekleyen girişimi iptal edin.",
    "Bekleyen girişimi iptal et",
    "İptalin doğrulanması tamamlanamadı. Yeniden yayınlamadan önce tekrar deneyin.",
    "Önceki girişim zaten yayınlandı. Yeniden yayınlamadan önce Gönderilerim’i kontrol edin.",
    "Önceki yayınlama işlemi tamamlandı, ancak gönderisi artık mevcut değil. Bu iptal işlemi hiçbir medyayı silmedi.",
  ],
  "de": [
    "Ein vorheriger Veröffentlichungsversuch ist noch ungeklärt. Versuchen Sie es mit dem ursprünglichen Inhalt erneut oder brechen Sie den ausstehenden Versuch ab, bevor Sie den Inhalt ändern.",
    "Ausstehenden Versuch abbrechen",
    "Die Überprüfung des Abbruchs konnte nicht abgeschlossen werden. Versuchen Sie es erneut, bevor Sie wieder veröffentlichen.",
    "Der vorherige Versuch wurde bereits veröffentlicht. Prüfen Sie Meine Beiträge, bevor Sie erneut veröffentlichen.",
    "Der vorherige Veröffentlichungsvorgang wurde abgeschlossen, aber der Beitrag ist nicht mehr verfügbar. Durch diesen Abbruch wurden keine Medien gelöscht.",
  ],
  "it": [
    "Un tentativo di pubblicazione precedente è ancora irrisolto. Riprova con il contenuto originale oppure annulla il tentativo in sospeso prima di modificarlo.",
    "Annulla il tentativo in sospeso",
    "Non è stato possibile completare la verifica dell’annullamento. Riprova prima di pubblicare di nuovo.",
    "Il tentativo precedente è già stato pubblicato. Controlla I miei post prima di pubblicare di nuovo.",
    "L’operazione di pubblicazione precedente è stata completata, ma il suo post non è più disponibile. Questo annullamento non ha eliminato alcun contenuto multimediale.",
  ],
  "pt-BR": [
    "Uma tentativa anterior de publicação ainda não foi resolvida. Tente novamente com o conteúdo original ou cancele a tentativa pendente antes de alterar esse conteúdo.",
    "Cancelar tentativa pendente",
    "Não foi possível concluir a verificação do cancelamento. Tente novamente antes de publicar de novo.",
    "A tentativa anterior já foi publicada. Confira Minhas postagens antes de publicar de novo.",
    "A operação de publicação anterior foi concluída, mas a postagem não está mais disponível. Este cancelamento não excluiu nenhum arquivo de mídia.",
  ],
  "pt-PT": [
    "Uma tentativa anterior de publicação continua por resolver. Volte a tentar com o conteúdo original ou cancele a tentativa pendente antes de alterar esse conteúdo.",
    "Cancelar tentativa pendente",
    "Não foi possível concluir a verificação do cancelamento. Volte a tentar antes de publicar novamente.",
    "A tentativa anterior já foi publicada. Consulte Minhas postagens antes de publicar novamente.",
    "A operação de publicação anterior foi concluída, mas a publicação já não está disponível. Este cancelamento não eliminou qualquer ficheiro multimédia.",
  ],
  "ur": [
    "پچھلی اشاعت کی کوشش ابھی غیر حل شدہ ہے۔ مواد تبدیل کرنے سے پہلے اسی اصل مواد کے ساتھ دوبارہ کوشش کریں یا زیرِ التوا کوشش منسوخ کریں۔",
    "زیرِ التوا کوشش منسوخ کریں",
    "منسوخی کی تصدیق مکمل نہیں ہو سکی۔ دوبارہ شائع کرنے سے پہلے پھر کوشش کریں۔",
    "پچھلی کوشش پہلے ہی شائع ہو چکی ہے۔ دوبارہ شائع کرنے سے پہلے میری پوسٹس دیکھیں۔",
    "پچھلی اشاعت کا عمل مکمل ہو گیا تھا، لیکن اس کی پوسٹ اب دستیاب نہیں ہے۔ اس منسوخی سے کوئی میڈیا حذف نہیں ہوا۔",
  ],
  "fa": [
    "تلاش قبلی برای انتشار هنوز تعیین تکلیف نشده است. پیش از تغییر محتوا، با همان محتوای اصلی دوباره تلاش کنید یا تلاش در انتظار را لغو کنید.",
    "لغو تلاش در انتظار",
    "تأیید لغو تکمیل نشد. پیش از انتشار دوباره، مجدداً تلاش کنید.",
    "تلاش قبلی قبلاً منتشر شده است. پیش از انتشار دوباره، پست های من را بررسی کنید.",
    "عملیات انتشار قبلی تکمیل شد، اما پست آن دیگر در دسترس نیست. این لغو هیچ رسانه‌ای را حذف نکرده است.",
  ],
  "hi": [
    "पिछला प्रकाशन प्रयास अभी अनिर्णीत है। सामग्री बदलने से पहले उसी मूल सामग्री के साथ फिर कोशिश करें या लंबित प्रयास रद्द करें।",
    "लंबित प्रयास रद्द करें",
    "रद्द करने की पुष्टि पूरी नहीं हो सकी। दोबारा प्रकाशित करने से पहले फिर कोशिश करें।",
    "पिछला प्रयास पहले ही प्रकाशित हो चुका है। दोबारा प्रकाशित करने से पहले मेरी पोस्ट देखें।",
    "पिछली प्रकाशन प्रक्रिया पूरी हो गई थी, लेकिन उसकी पोस्ट अब उपलब्ध नहीं है। इस रद्द करने की कार्रवाई से कोई मीडिया नहीं मिटाया गया।",
  ],
  "id": [
    "Percobaan penerbitan sebelumnya masih belum terselesaikan. Coba lagi dengan konten aslinya atau batalkan percobaan yang tertunda sebelum mengubah konten tersebut.",
    "Batalkan percobaan tertunda",
    "Verifikasi pembatalan tidak dapat diselesaikan. Coba lagi sebelum menerbitkan kembali.",
    "Percobaan sebelumnya sudah diterbitkan. Periksa Postingan saya sebelum menerbitkan kembali.",
    "Proses penerbitan sebelumnya selesai, tetapi postingannya sudah tidak tersedia. Pembatalan ini tidak menghapus media apa pun.",
  ],
  "ms": [
    "Percubaan penerbitan sebelumnya masih belum diselesaikan. Cuba lagi dengan kandungan asalnya atau batalkan percubaan yang tertangguh sebelum mengubah kandungan itu.",
    "Batalkan percubaan tertangguh",
    "Pengesahan pembatalan tidak dapat diselesaikan. Cuba lagi sebelum menerbitkan semula.",
    "Percubaan sebelumnya sudah diterbitkan. Semak Catatan saya sebelum menerbitkan semula.",
    "Proses penerbitan sebelumnya telah selesai, tetapi catatannya tidak lagi tersedia. Pembatalan ini tidak memadamkan sebarang media.",
  ],
  "ja": [
    "前回の投稿の試行はまだ未解決です。内容を変更する前に、元の内容で再試行するか、保留中の試行をキャンセルしてください。",
    "保留中の試行をキャンセル",
    "キャンセルの確認を完了できませんでした。再度投稿する前に、もう一度お試しください。",
    "前回の試行はすでに投稿されています。再度投稿する前に「私の投稿」を確認してください。",
    "前回の投稿処理は完了しましたが、その投稿は現在利用できません。このキャンセルでメディアは削除されていません。",
  ],
  "ko": [
    "이전 게시 시도가 아직 해결되지 않았습니다. 내용을 변경하기 전에 원래 내용으로 다시 시도하거나 보류 중인 시도를 취소하세요.",
    "보류 중인 시도 취소",
    "취소 확인을 완료하지 못했습니다. 다시 게시하기 전에 재시도하세요.",
    "이전 시도는 이미 게시되었습니다. 다시 게시하기 전에 내 게시물을 확인하세요.",
    "이전 게시 작업은 완료되었지만 해당 게시물은 더 이상 이용할 수 없습니다. 이번 취소로 삭제된 미디어는 없습니다.",
  ],
  "zh-Hans": [
    "上一次发布尝试仍未解决。更改内容前，请使用原始内容重试，或取消待处理的尝试。",
    "取消待处理的尝试",
    "未能完成取消验证。再次发布前，请重试。",
    "上一次尝试已发布。再次发布前，请查看“我的帖子”。",
    "上一次发布操作已完成，但其帖子已不可用。此次取消未删除任何媒体文件。",
  ],
  "zh-Hant": [
    "上一次發布嘗試仍未解決。變更內容前，請使用原始內容重試，或取消待處理的嘗試。",
    "取消待處理的嘗試",
    "未能完成取消驗證。再次發布前，請重試。",
    "上一次嘗試已發布。再次發布前，請查看「我的貼文」。",
    "上一次發布操作已完成，但其貼文已無法使用。此次取消未刪除任何媒體檔案。",
  ],
  "ru": [
    "Предыдущая попытка публикации ещё не разрешена. Повторите её с исходным содержимым или отмените ожидающую попытку, прежде чем менять содержимое.",
    "Отменить ожидающую попытку",
    "Не удалось завершить проверку отмены. Повторите попытку перед новой публикацией.",
    "Предыдущая попытка уже опубликована. Проверьте Мои сообщения, прежде чем публиковать снова.",
    "Предыдущая операция публикации завершена, но её публикация больше недоступна. Эта отмена не удалила никакие медиафайлы.",
  ],
  "bn": [
    "আগের প্রকাশের প্রচেষ্টা এখনও অমীমাংসিত। বিষয়বস্তু পরিবর্তনের আগে একই মূল বিষয়বস্তু দিয়ে আবার চেষ্টা করুন অথবা অপেক্ষমাণ প্রচেষ্টাটি বাতিল করুন।",
    "অপেক্ষমাণ প্রচেষ্টা বাতিল করুন",
    "বাতিলের যাচাই শেষ করা যায়নি। আবার প্রকাশের আগে পুনরায় চেষ্টা করুন।",
    "আগের প্রচেষ্টাটি ইতিমধ্যেই প্রকাশিত হয়েছে। আবার প্রকাশের আগে আমার পোস্ট দেখুন।",
    "আগের প্রকাশের প্রক্রিয়া সম্পন্ন হয়েছে, কিন্তু সেই পোস্টটি আর পাওয়া যাচ্ছে না। এই বাতিলের ফলে কোনো মিডিয়া মুছে ফেলা হয়নি।",
  ],
  "vi": [
    "Lần thử đăng trước vẫn chưa được giải quyết. Hãy thử lại với nội dung gốc hoặc hủy lần thử đang chờ trước khi thay đổi nội dung đó.",
    "Hủy lần thử đang chờ",
    "Không thể hoàn tất việc xác minh hủy. Hãy thử lại trước khi đăng tiếp.",
    "Lần thử trước đã được đăng. Hãy kiểm tra Bài đăng của tôi trước khi đăng lại.",
    "Thao tác đăng trước đã hoàn tất, nhưng bài đăng đó không còn khả dụng. Việc hủy này không xóa bất kỳ nội dung đa phương tiện nào.",
  ],
  "th": [
    "การพยายามเผยแพร่ครั้งก่อนยังไม่ได้ข้อสรุป โปรดลองอีกครั้งด้วยเนื้อหาเดิม หรือยกเลิกการพยายามที่รอดำเนินการก่อนเปลี่ยนเนื้อหา",
    "ยกเลิกการพยายามที่รอดำเนินการ",
    "ไม่สามารถตรวจสอบการยกเลิกให้เสร็จสิ้นได้ โปรดลองอีกครั้งก่อนเผยแพร่อีกครั้ง",
    "การพยายามครั้งก่อนได้เผยแพร่แล้ว โปรดตรวจสอบโพสต์ของฉันก่อนเผยแพร่อีกครั้ง",
    "การเผยแพร่ครั้งก่อนได้เสร็จสิ้นแล้ว แต่โพสต์นั้นไม่พร้อมใช้งานอีกต่อไป การยกเลิกนี้ไม่ได้ลบสื่อใด ๆ",
  ],
  "pl": [
    "Poprzednia próba publikacji nadal jest nierozstrzygnięta. Spróbuj ponownie z oryginalną treścią lub anuluj oczekującą próbę, zanim zmienisz tę treść.",
    "Anuluj oczekującą próbę",
    "Nie udało się zakończyć weryfikacji anulowania. Spróbuj ponownie przed kolejną publikacją.",
    "Poprzednia próba została już opublikowana. Sprawdź Moje posty, zanim opublikujesz ponownie.",
    "Poprzednia operacja publikacji została zakończona, ale jej post nie jest już dostępny. To anulowanie nie usunęło żadnych plików multimedialnych.",
  ],
  "nl": [
    "Een eerdere publicatiepoging is nog niet afgehandeld. Probeer het opnieuw met de oorspronkelijke inhoud of annuleer de openstaande poging voordat je die inhoud wijzigt.",
    "Openstaande poging annuleren",
    "De controle van de annulering kon niet worden voltooid. Probeer het opnieuw voordat je weer publiceert.",
    "De vorige poging is al gepubliceerd. Controleer Mijn berichten voordat je opnieuw publiceert.",
    "De vorige publicatiebewerking is voltooid, maar het bericht is niet meer beschikbaar. Door deze annulering zijn geen media verwijderd.",
  ],
  "uk": [
    "Попередня спроба публікації досі не вирішена. Повторіть її з початковим вмістом або скасуйте спробу, що очікує, перш ніж змінювати цей вміст.",
    "Скасувати спробу, що очікує",
    "Не вдалося завершити перевірку скасування. Спробуйте ще раз перед повторною публікацією.",
    "Попередню спробу вже опубліковано. Перевірте Мої пости, перш ніж публікувати знову.",
    "Попередню операцію публікації завершено, але її допис більше недоступний. Це скасування не видалило жодних медіафайлів.",
  ],
};

void main() {
  test(
    'publishing recovery has exactly five cells in every release locale',
    () {
      expect(_publishRecoverySources, hasLength(5));
      expect(_publishRecoverySources.toSet(), hasLength(5));
      expect(
        _publishRecoveryExpected.keys.toSet(),
        BilLocalePolicy.productionTags,
      );
      expect(_publishRecoveryExpected, hasLength(25));
      expect(CommunityReviewCopy.keys.take(6), const [
        'Posts',
        'Shared with BIL members',
        'Workout videos',
        'Videos & training routines',
        'Add emoji',
        'Like',
      ]);
      for (final row in _publishRecoveryExpected.values) {
        expect(row, hasLength(5));
      }
    },
  );

  for (final locale in BilLocalePolicy.productionTags) {
    test('Community actions resolve without English fallback in $locale', () {
      for (final source in const ['Add emoji', 'Like']) {
        final text = CommunityReviewCopy.resolve(source, locale);
        expect(text, isNotNull, reason: '$locale: $source');
        expect(text!.trim(), isNotEmpty);
        expect(RuntimeCopy.resolve(source, locale), text);
        if (locale != 'en') {
          expect(text, isNot(source));
        }
      }
      expect(
        CommunityReviewCopy.translations[locale],
        hasLength(CommunityReviewCopy.keys.length),
      );
    });

    test(
      'Community publishing recovery exact five-message lookup in $locale',
      () {
        final expected = _publishRecoveryExpected[locale]!;
        for (var index = 0; index < _publishRecoverySources.length; index++) {
          final source = _publishRecoverySources[index];
          final cell = expected[index];
          expect(CommunityReviewCopy.keys.indexOf(source), 6 + index);
          expect(cell.trim(), isNotEmpty, reason: '$locale: $source');
          expect(
            CommunityReviewCopy.resolve(source, locale),
            cell,
            reason: 'exact row mapping $locale: $source',
          );
          expect(
            RuntimeCopy.resolve(source, locale),
            cell,
            reason: 'RuntimeCopy $locale: $source',
          );
          expect(
            communityTextForLanguage(
              locale,
              source,
              'ARABIC_FALLBACK_SENTINEL',
            ),
            cell,
            reason: 'actual Community consumer $locale: $source',
          );
          if (locale == 'en') {
            expect(cell, source);
          } else {
            expect(
              cell,
              isNot(source),
              reason: 'no English fallback $locale: $source',
            );
          }
          expect(cell, isNot(contains('ARABIC_FALLBACK_SENTINEL')));
          expect(RegExp(r'\{[^}]+\}').allMatches(cell), isEmpty);
          for (final marker in const ['\uFFFD', 'Ã', 'Â']) {
            expect(cell, isNot(contains(marker)), reason: '$locale: $source');
          }
        }
      },
    );
  }
}
