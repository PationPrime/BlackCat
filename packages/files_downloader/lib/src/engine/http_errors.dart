import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../models/download_error.dart';

/// The download was stopped by its owner
final class DownloadStoppedSignal implements Exception {
  const DownloadStoppedSignal();
}

/// Statuses after which the same link will not work
bool isFinalStatus(int? status) =>
    status == 401 || status == 403 || status == 404 || status == 410;

FilesDownloadError statusError(int status, String url) => FilesDownloadError(
  FilesDownloadErrorType.httpStatus,
  'The server answered $status',
  url: url,
  statusCode: status,
);

/// A dio failure as a download error. A cancelled request means
/// the download is being stopped
Object dioError(DioException error, String url) => switch (error.type) {
  DioExceptionType.cancel => const DownloadStoppedSignal(),
  DioExceptionType.badResponse => statusError(
    error.response?.statusCode ?? 0,
    url,
  ),
  DioExceptionType.badCertificate => FilesDownloadError(
    FilesDownloadErrorType.network,
    'The server certificate is not trusted: ${error.message}',
    url: url,
  ),
  _ => FilesDownloadError(
    FilesDownloadErrorType.network,
    '${error.message ?? error.error ?? error.type.name}',
    url: url,
  ),
};

/// Errors of reading a response body
FilesDownloadError? streamError(Object error, String url) => switch (error) {
  FilesDownloadError() => error,
  TimeoutException() => FilesDownloadError(
    FilesDownloadErrorType.network,
    'No bytes came for too long',
    url: url,
  ),
  SocketException() || HttpException() => FilesDownloadError(
    FilesDownloadErrorType.network,
    '$error',
    url: url,
  ),
  DioException() => switch (dioError(error, url)) {
    final FilesDownloadError downloadError => downloadError,
    _ => null,
  },
  _ => null,
};
