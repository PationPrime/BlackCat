import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

class ApiError extends Equatable {
  final String code;
  final String message;
  final StackTrace? stackTrace;
  final DioException? dioException;

  const ApiError({
    required this.code,
    required this.message,
    this.stackTrace,
    this.dioException,
  });

  @override
  List<Object?> get props => [code, message, stackTrace, dioException];

  ApiError copyWith({
    String? code,
    String? message,
    StackTrace? stackTrace,
    DioException? dioException,
  }) => ApiError(
    code: code ?? this.code,
    message: message ?? this.message,
    stackTrace: stackTrace ?? this.stackTrace,
    dioException: dioException ?? this.dioException,
  );
}
