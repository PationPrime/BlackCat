import '../failure/failure.dart';

part 'operation_result_extension.dart';
part 'operation_result_helpers.dart';

typedef OperationResult<T> = ({Failure? failure, T? data});
