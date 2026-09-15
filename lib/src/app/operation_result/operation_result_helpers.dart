part of 'operation_result.dart';

OperationResult<T> ok<T>(T? data) => (failure: null, data: data);

OperationResult<T> fail<T>(Failure failure) => (failure: failure, data: null);
