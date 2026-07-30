import 'package:flutter/material.dart';
import 'package:notifecation/core/constants/app_values.dart';
import 'package:notifecation/core/constants/test_keys.dart';
import 'package:notifecation/core/themes/app_colors.dart';
import 'package:notifecation/features/downloads/presentation/downloads_screen/widgets/downloads_header.dart';
import 'package:notifecation/features/downloads/presentation/downloads_screen/widgets/pdf_preview_widget.dart';
import 'package:notifecation/shared/presentation/widgets/app_widgets.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      key: const Key(TestKeys.downloadsScaffold),
      appBar: AppBar(
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.onPrimary,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DownloadsHeader(),
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(
                AppMargin.m16,
                0,
                AppMargin.m16,
                AppMargin.m16,
              ),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.divider),
              ),
              child: const PdfPreviewWidget(),
            ),
          ),
        ],
      ),
    );
  }
}
