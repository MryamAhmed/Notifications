import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:notifecation/shared/presentation/cubit/general_state.dart';

@lazySingleton
class GeneralCubit extends Cubit<GeneralState> {
  GeneralCubit() : super(const GeneralState());

  void setNotificationPermissionGranted(bool granted) {
    emit(state.copyWith(notificationPermissionGranted: granted));
  }
}
