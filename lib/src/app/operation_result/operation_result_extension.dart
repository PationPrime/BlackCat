part of 'operation_result.dart';

extension OperationResultX<T> on OperationResult<T> {
  bool get isSuccess => failure == null;
  bool get isFailed => failure != null;

  T get requireData => data as T;
}
