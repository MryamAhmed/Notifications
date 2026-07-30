import 'package:notifecation/core/constants/app_error_codes.dart';

class AppError {
  const AppError({
    required this.code,
    this.message,
    this.statusCode,
  });

  factory AppError.local(String code, {String? message}) => AppError(
        code: code,
        message: message,
      );

  factory AppError.network({String? message}) => AppError(
        code: AppErrorCodes.network,
        message: message,
      );

  factory AppError.unknown({String? message}) => AppError(
        code: AppErrorCodes.unknown,
        message: message,
      );

  final String code;
  final String? message;
  final int? statusCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppError &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          message == other.message &&
          statusCode == other.statusCode;

  @override
  int get hashCode => Object.hash(code, message, statusCode);
}
