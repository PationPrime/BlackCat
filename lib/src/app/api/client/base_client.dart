import 'package:dio/dio.dart';

base class ApiClient {
  final Dio dio;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final Map<String, dynamic> headers;
  final List<Interceptor> interceptors;

  ApiClient({
    this.connectTimeout = const Duration(seconds: 20),
    this.receiveTimeout = const Duration(seconds: 60),
    this.headers = const {},
    this.interceptors = const [],
  }) : dio = Dio(
         BaseOptions(
           headers: headers,
           connectTimeout: connectTimeout,
           receiveTimeout: receiveTimeout,
         ),
       )..interceptors.addAll(interceptors);

  @override
  String toString() =>
      'connectTimeout: $connectTimeout\nreceiveTimeout: $receiveTimeout\nheaders: $headers\ninterceptors: $interceptors';
}
