import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:injectable/injectable.dart';
import 'package:notifecation/core/di/di.dart';
import 'package:notifecation/core/routing/app_routes.dart';
import 'package:notifecation/features/downloads/presentation/downloads_screen/cubit/downloads_cubit.dart';
import 'package:notifecation/features/downloads/presentation/downloads_screen/screens/downloads_screen.dart';

@module
abstract class RouterModule {
  @lazySingleton
  GoRouter appRouter() {
    return GoRouter(
      initialLocation: AppRoutes.downloads,
      routes: [
        GoRoute(
          path: AppRoutes.downloads,
          name: AppRouteNames.downloads,
          builder: (context, state) => BlocProvider(
            create: (_) => getIt.get<DownloadsCubit>(),
            child: const DownloadsScreen(),
          ),
        ),
      ],
    );
  }
}
