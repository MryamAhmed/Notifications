import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:notifecation/core/di/di.dart';
import 'package:notifecation/core/notifications/notification_service.dart';
import 'package:notifecation/core/themes/app_colors.dart';
import 'package:notifecation/flavors.dart';
import 'package:notifecation/shared/presentation/cubit/general_cubit.dart';

Future<void> mainCommon() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  await getIt<NotificationService>().initialize();
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
