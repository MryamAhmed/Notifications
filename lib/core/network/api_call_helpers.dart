import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:notifecation/core/constants/app_error_codes.dart';
import 'package:notifecation/core/error/app_error.dart';

Future<Either<AppError, T>> callApi<T>({
  required Future<Response<dynamic>> Function() request,
  required T Function(Map<String, dynamic> json) mapSuccess,
}) async {
  try {
    final response = await request();
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return Right(mapSuccess(data));
    }
    return Left(AppError.local(AppErrorCodes.unknown));
  } on DioException catch (error) {
    return Left(_mapDioException(error));
  } catch (error) {
    return Left(AppError.unknown(message: error.toString()));
  }
}

Future<Either<AppError, T>> callDownload<T>({
  required Future<T> Function() request,
  String failureCode = AppErrorCodes.unknown,
}) async {
  try {
    final result = await request();
    return Right(result);
  } on DioException catch (error) {
    return Left(
      AppError(
        code: failureCode,
        message: error.message,
        statusCode: error.response?.statusCode,
      ),
    );
  } catch (error) {
    return Left(AppError.local(failureCode, message: error.toString()));
  }
}

AppError _mapDioException(DioException error) {
  if (error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.connectionError) {
    return AppError.network(message: error.message);
  }

  return AppError(
    code: AppErrorCodes.unknown,
    message: error.message,
    statusCode: error.response?.statusCode,
  );
}
