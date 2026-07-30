import 'package:flutter/material.dart';
import 'package:notifecation/core/themes/app_colors.dart';
import 'package:notifecation/shared/presentation/widgets/app_text.dart';

class AppSnackBar {
  AppSnackBar._();

  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: AppText(message, color: AppColors.onPrimary),
        backgroundColor: AppColors.error,
      ),
    );
  }

  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: AppText(message, color: AppColors.onPrimary),
        backgroundColor: AppColors.primaryColor,
      ),
    );
  }
}
