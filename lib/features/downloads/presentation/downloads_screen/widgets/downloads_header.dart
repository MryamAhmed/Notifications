import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:notifecation/core/background/download_trace.dart';
import 'package:notifecation/core/constants/app_values.dart';
import 'package:notifecation/core/constants/test_keys.dart';
import 'package:notifecation/core/extensions/app_error_localization.dart';
import 'package:notifecation/core/themes/app_colors.dart';
import 'package:notifecation/features/downloads/presentation/downloads_screen/cubit/downloads_cubit.dart';
import 'package:notifecation/features/downloads/presentation/downloads_screen/cubit/downloads_state.dart';
import 'package:notifecation/shared/presentation/widgets/app_widgets.dart';
import 'package:path/path.dart' as p;

class DownloadsHeader extends StatelessWidget {
  const DownloadsHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DownloadsCubit, DownloadsState>(
      buildWhen: (previous, current) =>
          previous.isDownloading != current.isDownloading ||
          previous.progress != current.progress ||
          previous.savedPath != current.savedPath ||
          previous.previewPath != current.previewPath ||
          previous.error != current.error ||
          previous.permissionGranted != current.permissionGranted ||
          previous.isLoadingPreview != current.isLoadingPreview,
      builder: (context, state) {
        // STEP 8: what the widget layer actually sees.
        fgsTrace(
          'UI',
          'STEP 8 header rebuilt',
          'isDownloading=${state.isDownloading} progress=${state.progress} '
              'isLoadingPreview=${state.isLoadingPreview}',
        );

        final cubit = context.read<DownloadsCubit>();
        final accent = _accentColor(state);

        return Container(
          margin: const EdgeInsets.all(AppMargin.m16),
          padding: const EdgeInsets.all(AppPadding.p16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20.r),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryColor.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppPadding.p12),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_stateIcon(state), color: accent, size: 22.r),
                  ),
                  const Gap(AppSpacing.s12),
                  Expanded(
                    child: AppText(
                      _statusMessage(context, state),
                      key: const Key(TestKeys.downloadsStatusText),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              if (state.isDownloading) ...[
                const Gap(AppSpacing.s16),
                // The service throttles notification posts to 2/sec, so the
                // events arrive in visible jumps. Animating between them keeps
                // the bar and the percentage moving smoothly.
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: state.progress / 100),
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOut,
                  builder: (context, value, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8.r),
                        child: LinearProgressIndicator(
                          key: const Key(TestKeys.downloadsProgressBar),
                          value: value,
                          color: accent,
                          backgroundColor: AppColors.progressTrack,
                          minHeight: 8.h,
                        ),
                      ),
                      const Gap(AppSpacing.s8),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: AppText(
                          '${(value * 100).round()}%',
                          color: accent,
                          style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Gap(AppSpacing.s16),
              AppButtonWidget(
                key: const Key(TestKeys.downloadsDownloadButton),
                text: state.isDownloading
                    ? context.l10n.downloading
                    : context.l10n.download,
                icon: Icons.download_rounded,
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

  Color _accentColor(DownloadsState state) {
    if (state.error != null) return AppColors.error;
    if (state.savedPath != null && !state.isDownloading) {
      return AppColors.success;
    }
    return AppColors.primaryColor;
  }

  IconData _stateIcon(DownloadsState state) {
    if (state.error != null) return Icons.error_outline_rounded;
    if (state.isDownloading) return Icons.downloading_rounded;
    if (state.savedPath != null) return Icons.check_circle_outline_rounded;
    if (state.isLoadingPreview) return Icons.hourglass_top_rounded;
    return Icons.picture_as_pdf_rounded;
  }

  String _statusMessage(BuildContext context, DownloadsState state) {
    if (state.isLoadingPreview) {
      return state.permissionGranted
          ? context.l10n.loadingPdfPreview
          : context.l10n.permissionDeniedLoadingPreview;
    }
    if (state.isDownloading) {
      return context.l10n.downloading;
    }
    if (state.savedPath != null) {
      // Only the file name: the full path is still shown in the snack bar.
      return context.l10n.downloadComplete(p.basename(state.savedPath!));
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
