import 'package:freezed_annotation/freezed_annotation.dart';

part 'general_state.freezed.dart';

@freezed
abstract class GeneralState with _$GeneralState {
  const factory GeneralState({
    @Default(false) bool notificationPermissionGranted,
  }) = _GeneralState;
}
