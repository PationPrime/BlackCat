import 'package:flutter/foundation.dart';

import '../errors/errors.dart';

abstract class BaseRepositoryInterface {
  @protected
  ErrorHandler get errorHandler;
}
