import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:notifecation/core/constants/app_values.dart';
import 'package:notifecation/core/constants/test_keys.dart';
import 'package:notifecation/core/extensions/app_error_localization.dart';
import 'package:notifecation/core/themes/app_colors.dart';
import 'package:notifecation/features/downloads/presentation/downloads_screen/cubit/downloads_cubit.dart';
import 'package:notifecation/features/downloads/presentation/downloads_screen/cubit/downloads_state.dart';
import 'package:notifecation/shared/presentation/widgets/app_widgets.dart';

class DownloadsHeader extends StatelessWidget {
  const DownloadsHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DownloadsCubit, DownloadsState>(
      buildWhen: (previous, current) =>
          previous.isDownloading != current.isDownloading ||
          previous.progress != current.progress ||
          previous.savedPath != current.savedPath ||
          previous.error != current.error ||
          previous.permissionGranted != current.permissionGranted ||
          previous.isLoadingPreview != current.isLoadingPreview,
      builder: (context, state) {
        final cubit = context.read<DownloadsCubit>();
        final message = _statusMessage(context, state);

        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppPadding.p16,
            AppPadding.p16,
            AppPadding.p16,
            AppPadding.p8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppText(
                message,
                key: const Key(TestKeys.downloadsStatusText),
              ),
              if (state.isDownloading) ...[
                const Gap(AppSpacing.s12),
                LinearProgressIndicator(
                  key: const Key(TestKeys.downloadsProgressBar),
                  value: state.progress / 100,
                  color: AppColors.primaryColor,
                  backgroundColor: AppColors.progressTrack,
                  minHeight: 6.h,
                ),
                const Gap(AppSpacing.s4),
                AppText('${state.progress}%', color: AppColors.textGray),
              ],
              const Gap(AppSpacing.s12),
              AppButtonWidget(
                key: const Key(TestKeys.downloadsDownloadButton),
                text: state.isDownloading
                    ? context.l10n.downloading
                    : context.l10n.download,
                icon: Icons.download,
                isLoading: state.isDownloading,
                isDisabled: !cubit.canDownload,
                onPressed: () {
                  final cubit = context.read<DownloadsCubit>();
                  cubit.downloadPdf(
                    onSuccess: () {
                      final path = cubit.state.savedPath ?? '';
                      AppSnackBar.showSuccess(
                        context,
                        context.l10n.downloadComplete(path),
                      );
                    },
                    onError: (error) => AppSnackBar.showError(
                      context,
                      error.localized(context),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _statusMessage(BuildContext context, DownloadsState state) {
    if (state.isLoadingPreview) {
      return state.permissionGranted
          ? context.l10n.loadingPdfPreview
          : context.l10n.permissionDeniedLoadingPreview;
    }
    if (state.isDownloading) {
      return context.l10n.downloadingPdf(state.progress);
    }
    if (state.savedPath != null) {
      return context.l10n.downloadComplete(state.savedPath!);
    }
    if (state.error != null) {
      return state.error!.localized(context);
    }
    if (state.previewPath != null) {
      return context.l10n.pdfReady;
    }
    return context.l10n.loadingPdfPreview;
  }
}
