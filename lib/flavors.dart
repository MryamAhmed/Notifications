enum AppFlavor { dev, staging, prod }

class Flavor {
  Flavor._();

  static AppFlavor appFlavor = AppFlavor.prod;

  static String get flavorName {
    switch (appFlavor) {
      case AppFlavor.dev:
        return 'DEV';
      case AppFlavor.staging:
        return 'STAGING';
      case AppFlavor.prod:
        return 'PROD';
    }
  }

  /// Small PDF used only to render the preview quickly.
  static String get previewPdfUrl {
    switch (appFlavor) {
      case AppFlavor.dev:
      case AppFlavor.staging:
      case AppFlavor.prod:
        return 'https://mozilla.github.io/pdf.js/web/compressed.tracemonkey-pldi-09.pdf';
    }
  }

  /// Verified 25 MB PDF used for visible Foreground Service progress testing.
  static String get downloadPdfUrl {
    switch (appFlavor) {
      case AppFlavor.dev:
      case AppFlavor.staging:
      case AppFlavor.prod:
        return 'https://samplefile.com/samples/download/document/pdf/'
            'pdf_sample_file_25MB.pdf/';
    }
  }

  static bool get enableNetworkLogging => appFlavor != AppFlavor.prod;
}
