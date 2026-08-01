import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:notifecation/core/background/background_download_service.dart';
import 'package:notifecation/core/background/download_trace.dart';
import 'package:notifecation/core/di/di.dart';
import 'package:notifecation/core/notifications/notification_service.dart';
import 'package:notifecation/core/themes/app_colors.dart';
import 'package:notifecation/flavors.dart';
import 'package:notifecation/l10n/app_localizations.dart';
import 'package:notifecation/shared/presentation/cubit/general_cubit.dart';

Future<void> mainCommon() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Seeing this again when you reopen the app proves it was a COLD start
  // (process was killed). No line means the process survived.
  fgsTrace('UI', 'STEP 0 mainCommon() start - UI isolate booting');

  // STEP 1: Register GetIt dependencies (Cubits, use cases, Dio, etc.).
  await configureDependencies();

  // STEP 2: Init local notifications in the UI isolate (channels + plugin).
  await getIt<NotificationService>().initialize();

  // STEP 3: Configure flutter_background_service (does NOT start it yet).
  // This registers the background isolate entry point used for FGS downloads.
  await getIt<BackgroundDownloadService>().initialize();
  fgsTrace('UI', 'STEP 0a configure() done - event channel attached');

  runApp(const NotificationSpikeApp());
}

class NotificationSpikeApp extends StatelessWidget {
  const NotificationSpikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = getIt<GoRouter>();

    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      builder: (_, __) {
        return BlocProvider.value(
          value: getIt<GeneralCubit>(),
          child: MaterialApp.router(
            title: Flavor.appFlavor == AppFlavor.prod
                ? 'Notification Spike'
                : 'Notification Spike [${Flavor.flavorName}]',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.primaryColor,
              ),
              useMaterial3: true,
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        );
      },
    );
  }
}
