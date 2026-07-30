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

  /// Sample PDF used by the downloads spike (full URL).
  static String get samplePdfUrl {
    switch (appFlavor) {
      case AppFlavor.dev:
      case AppFlavor.staging:
      case AppFlavor.prod:
        return 'https://mozilla.github.io/pdf.js/web/compressed.tracemonkey-pldi-09.pdf';
    }
  }

  static bool get enableNetworkLogging => appFlavor != AppFlavor.prod;
}
