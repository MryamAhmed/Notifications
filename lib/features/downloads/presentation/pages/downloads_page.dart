import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/notification_service.dart';
import '../cubit/downloads_cubit.dart';
import '../cubit/downloads_state.dart';

/// Stateless view — all mutable state lives in [DownloadsCubit].
class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Phase 1: Local Notifications')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: BlocBuilder<DownloadsCubit, DownloadsState>(
          builder: (context, state) {
            final cubit = context.read<DownloadsCubit>();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Channel: ${NotificationService.downloadsChannel.id}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(state.status),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: cubit.showNotification,
                  child: const Text('Show notification'),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: cubit.updateNotificationProgress,
                  child: const Text('Update notification with progress'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: cubit.cancelNotification,
                  child: const Text('Cancel notification'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
