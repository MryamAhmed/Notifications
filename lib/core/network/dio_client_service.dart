import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:notifecation/flavors.dart';

@lazySingleton
class DioClientService {
  DioClientService() {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
      ),
    );

    if (Flavor.enableNetworkLogging) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: false,
          responseBody: false,
        ),
      );
    }
  }

  late final Dio _dio;

  Dio get dio => _dio;
}
