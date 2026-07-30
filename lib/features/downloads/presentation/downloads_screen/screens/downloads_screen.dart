import 'package:flutter/material.dart';
import 'package:notifecation/core/constants/test_keys.dart';
import 'package:notifecation/core/extensions/app_error_localization.dart';
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
        title: AppText(context.l10n.downloadsTitle),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.onPrimary,
      ),
      body: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DownloadsHeader(),
          Divider(height: 1, color: AppColors.divider),
          Expanded(child: PdfPreviewWidget()),
        ],
      ),
    );
  }
}
