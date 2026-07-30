// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'تجربة الإشعارات';

  @override
  String get downloadsTitle => 'المرحلة 5: تنزيل WorkManager';

  @override
  String get download => 'تنزيل';

  @override
  String get downloading => 'جاري التنزيل...';

  @override
  String get queuedWaitingForAndroid =>
      'في قائمة الانتظار. بانتظار أن يبدأ أندرويد المهمة...';

  @override
  String get retryLoadPdf => 'إعادة تحميل PDF';

  @override
  String get loadingPdfPreview => 'جاري تحميل معاينة PDF...';

  @override
  String get permissionDeniedLoadingPreview =>
      'تم رفض إذن الإشعارات. جاري تحميل المعاينة...';

  @override
  String get pdfReady =>
      'ملف PDF جاهز. اضغط تنزيل لتسليم المهمة إلى WorkManager.';

  @override
  String downloadingPdf(int progress) {
    return 'تنزيل WorkManager... $progress%';
  }

  @override
  String downloadComplete(String path) {
    return 'اكتمل التنزيل.\nتم الحفظ في: $path';
  }

  @override
  String get downloadFailed => 'فشل التنزيل';

  @override
  String get previewFailed => 'فشل تحميل معاينة PDF';

  @override
  String get unknownError => 'حدث خطأ ما';

  @override
  String get networkError => 'خطأ في الشبكة. تحقق من اتصالك.';

  @override
  String get ok => 'حسناً';
}
