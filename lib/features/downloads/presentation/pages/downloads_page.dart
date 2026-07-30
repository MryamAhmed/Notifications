import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

import '../cubit/downloads_cubit.dart';
import '../cubit/downloads_state.dart';

/// Stateless view — Cubit owns permission, preview loading, and download progress.
class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Phase 1: PDF Download')),
      body: BlocBuilder<DownloadsCubit, DownloadsState>(
        builder: (context, state) {
          final cubit = context.read<DownloadsCubit>();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(state.message),
                    if (state.isDownloading) ...[
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: state.progress / 100,
                      ),
                      const SizedBox(height: 4),
                      Text('${state.progress}%'),
                    ],
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed:
                          state.canDownload ? cubit.downloadPdf : null,
                      icon: const Icon(Icons.download),
                      label: Text(
                        state.isDownloading ? 'Downloading...' : 'Download',
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(child: _PdfPreview(state: state, onRetry: cubit.loadPreview)),
            ],
          );
        },
      ),
    );
  }
}

class _PdfPreview extends StatelessWidget {
  const _PdfPreview({
    required this.state,
    required this.onRetry,
  });

  final DownloadsState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (state.status == DownloadsStatus.loadingPreview ||
        state.status == DownloadsStatus.initial) {
      return const Center(child: CircularProgressIndicator());
    }

    final previewPath = state.previewPath;
    if (previewPath == null || !File(previewPath).existsSync()) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                state.message,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onRetry,
                child: const Text('Retry load PDF'),
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
  }
}
