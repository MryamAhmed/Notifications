import 'package:flutter/material.dart';
import 'package:notifecation/l10n/app_localizations.dart';
import 'package:notifecation/core/constants/app_error_codes.dart';
import 'package:notifecation/core/error/app_error.dart';

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}

extension AppErrorX on AppError {
  String localized(BuildContext context) {
    final l10n = context.l10n;
    switch (code) {
      case AppErrorCodes.network:
        return l10n.networkError;
      case AppErrorCodes.pdfPreviewFailed:
        return l10n.previewFailed;
      case AppErrorCodes.pdfDownloadFailed:
        return l10n.downloadFailed;
      case AppErrorCodes.foregroundServiceFailed:
        return l10n.downloadFailed;
      default:
        return message?.isNotEmpty == true ? message! : l10n.unknownError;
    }
  }
}
