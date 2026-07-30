import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:notifecation/core/themes/app_colors.dart';
import 'package:notifecation/shared/presentation/widgets/app_text.dart';

class AppButtonWidget extends StatelessWidget {
  const AppButtonWidget({
    required this.text,
    required this.onPressed,
    super.key,
    this.isLoading = false,
    this.isDisabled = false,
    this.icon,
    this.isOutlined = false,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isDisabled;
  final IconData? icon;
  final bool isOutlined;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isDisabled && !isLoading;
    final label = AppText(
      isLoading ? '...' : text,
      color: isOutlined ? AppColors.primaryColor : AppColors.onPrimary,
    );

    if (isOutlined) {
      return SizedBox(
        height: 48.h,
        child: icon == null
            ? OutlinedButton(onPressed: enabled ? onPressed : null, child: label)
            : OutlinedButton.icon(
                onPressed: enabled ? onPressed : null,
                icon: Icon(icon, size: 20.r),
                label: label,
              ),
      );
    }

    return SizedBox(
      height: 48.h,
      child: icon == null
          ? FilledButton(
              onPressed: enabled ? onPressed : null,
              style: _filledStyle(),
              child: label,
            )
          : FilledButton.icon(
              onPressed: enabled ? onPressed : null,
              style: _filledStyle(),
              icon: Icon(icon, size: 20.r, color: AppColors.onPrimary),
              label: label,
            ),
    );
  }

  ButtonStyle _filledStyle() {
    return FilledButton.styleFrom(
      backgroundColor: AppColors.primaryColor,
      foregroundColor: AppColors.onPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
      ),
    );
  }
}
