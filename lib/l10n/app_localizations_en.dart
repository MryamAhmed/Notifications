// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Notification Spike';

  @override
  String get downloadsTitle => 'Phase 4: Foreground Download';

  @override
  String get download => 'Download';

  @override
  String get downloading => 'Downloading...';

  @override
  String get retryLoadPdf => 'Retry load PDF';

  @override
  String get loadingPdfPreview => 'Loading PDF preview...';

  @override
  String get permissionDeniedLoadingPreview =>
      'Notification permission denied. Loading PDF preview...';

  @override
  String get pdfReady =>
      'PDF ready. Press Download to run it in a Foreground Service with live progress.';

  @override
  String downloadingPdf(int progress) {
    return 'Foreground download... $progress%';
  }

  @override
  String downloadComplete(String path) {
    return 'Download complete.\nSaved to: $path';
  }

  @override
  String get downloadFailed => 'Download failed';

  @override
  String get previewFailed => 'Failed to load PDF preview';

  @override
  String get unknownError => 'Something went wrong';

  @override
  String get networkError => 'Network error. Check your connection.';

  @override
  String get ok => 'OK';
}
