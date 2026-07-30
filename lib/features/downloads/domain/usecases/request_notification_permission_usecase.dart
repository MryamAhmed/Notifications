import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:notifecation/core/error/app_error.dart';
import 'package:notifecation/core/notifications/notification_service.dart';
import 'package:notifecation/shared/presentation/cubit/general_cubit.dart';

@injectable
class RequestNotificationPermissionUseCase {
  RequestNotificationPermissionUseCase(
    this._notificationService,
    this._generalCubit,
  );

  final NotificationService _notificationService;
  final GeneralCubit _generalCubit;

  Future<Either<AppError, bool>> call() async {
    final granted =
        await _notificationService.requestNotificationPermission();
    _generalCubit.setNotificationPermissionGranted(granted);
    return Right(granted);
  }
}
