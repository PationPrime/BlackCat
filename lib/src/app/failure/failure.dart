import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

part 'constants.dart';

abstract class Failure extends Equatable implements Exception {
  final String title;
  final String? code;
  final String message;
  final StackTrace? stackTrace;
  final DioException? dioException;
  final String? details;

  const Failure({
    this.title = 'Error',
    this.code,
    this.message = 'Something went wrong',
    this.stackTrace,
    this.dioException,
    this.details,
  });

  @override
  List<Object?> get props => [
    title,
    code,
    message,
    stackTrace,
    dioException,
    details,
  ];

  Failure fromException(
    Object error, {
    StackTrace? stackTrace,
    String? message,
  });

  Failure fromOtherFailure(Failure other);

  @override
  String toString() => message;
}
