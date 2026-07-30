import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:gap/gap.dart';
import 'package:notifecation/core/constants/app_values.dart';
import 'package:notifecation/core/constants/test_keys.dart';
import 'package:notifecation/core/extensions/app_error_localization.dart';
import 'package:notifecation/features/downloads/presentation/downloads_screen/cubit/downloads_cubit.dart';
import 'package:notifecation/features/downloads/presentation/downloads_screen/cubit/downloads_state.dart';
import 'package:notifecation/shared/presentation/widgets/app_widgets.dart';

class PdfPreviewWidget extends StatelessWidget {
  const PdfPreviewWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DownloadsCubit, DownloadsState>(
      buildWhen: (previous, current) =>
          previous.isLoadingPreview != current.isLoadingPreview ||
          previous.previewPath != current.previewPath ||
          previous.error != current.error,
      builder: (context, state) {
        if (state.isLoadingPreview) {
          return const AppLoadingWidget();
        }

        final previewPath = state.previewPath;
        if (previewPath == null || !File(previewPath).existsSync()) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppPadding.p24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppText(
                    state.error?.localized(context) ??
                        context.l10n.previewFailed,
                    textAlign: TextAlign.center,
                  ),
                  const Gap(AppSpacing.s16),
                  AppButtonWidget(
                    key: const Key(TestKeys.downloadsRetryButton),
                    text: context.l10n.retryLoadPdf,
                    isOutlined: true,
                    onPressed: () => context.read<DownloadsCubit>().loadPreview(
                          onError: (error) => AppSnackBar.showError(
                            context,
                            error.localized(context),
                          ),
                        ),
                  ),
                ],
              ),
            ),
          );
        }

        return PDFView(
          filePath: previewPath,
          enableSwipe: true,
          swipeHorizontal: false,
          autoSpacing: true,
          pageFling: true,
        );
      },
    );
  }
}
