import 'dart:async';

import 'package:dio/dio.dart';

import '../models/byte_ranges.dart';
import '../models/download_error.dart';
import '../models/download_request.dart';
import '../models/remote_file_info.dart';
import 'download_api_client.dart';
import 'http_errors.dart';

/// Asks the server about a file before it is downloaded: its size,
/// whether it gives parts, and its validator
final class RemoteFileProber {
  final DownloadApiClient _client;

  const RemoteFileProber(this._client);

  Future<RemoteFileInfo> probe(
    DownloadFileRequest file, {
    CancelToken? cancelToken,
  }) async {
    final RemoteFileInfo info;

    try {
      info = switch (file.rangeMode) {
        RangeRequestMode.header => await _probeWithRange(file, cancelToken),

        /// Such servers give ranges by a parameter and are known to support
        /// them; only the size is asked
        RangeRequestMode.queryParameter => await _probeWithHead(
          file,
          cancelToken,
          assumeRanges: true,
        ),
      };
    } on FilesDownloadError catch (error) {
      /// The caller knows the size: a server that answers only real downloads
      /// is still downloadable
      if (file.expectedLength case final length?
          when error.type != FilesDownloadErrorType.httpStatus ||
              !isFinalStatus(error.statusCode)) {
        return RemoteFileInfo(
          length: length,
          acceptsRanges: file.rangeMode == RangeRequestMode.queryParameter,
        );
      }

      rethrow;
    }

    return info.length == null && file.expectedLength != null
        ? RemoteFileInfo(
            length: file.expectedLength,
            acceptsRanges: info.acceptsRanges,
            validator: info.validator,
          )
        : info;
  }

  /// `GET` of the first byte: a `206` with `Content-Range` tells the size
  /// and range support at once. A server that does not know ranges sends
  /// the whole file with `200`; the body is not read
  Future<RemoteFileInfo> _probeWithRange(
    DownloadFileRequest file,
    CancelToken? cancelToken,
  ) async {
    final response = await _send(
      file,
      method: 'GET',
      headers: {'range': 'bytes=0-0'},
      cancelToken: cancelToken,
    );

    await _discard(response);

    final status = response.statusCode ?? 0;
    final headers = response.headers;

    switch (status) {
      case 206:
        final range = ContentRange.parse(headers.value('content-range'));

        return RemoteFileInfo(
          length: range?.total,
          acceptsRanges: range != null,
          validator: validatorOf(headers),
        );
      case 200:
        return RemoteFileInfo(
          length: contentLengthOf(headers),
          acceptsRanges: false,
          validator: validatorOf(headers),
        );

      /// An empty file has no first byte
      case 416
          when ContentRange.unsatisfiedTotal(headers.value('content-range')) ==
              0:
        return RemoteFileInfo(
          length: 0,
          acceptsRanges: true,
          validator: validatorOf(headers),
        );
      case 405 || 416 || 501:
        return _probeWithHead(file, cancelToken, assumeRanges: false);
      default:
        throw statusError(status, file.url);
    }
  }

  Future<RemoteFileInfo> _probeWithHead(
    DownloadFileRequest file,
    CancelToken? cancelToken, {
    required bool assumeRanges,
  }) async {
    final response = await _send(
      file,
      method: 'HEAD',
      cancelToken: cancelToken,
    );

    await _discard(response);

    final status = response.statusCode ?? 0;

    if (status < 200 || status >= 300) {
      throw statusError(status, file.url);
    }

    final headers = response.headers;
    final acceptRanges = headers.value('accept-ranges')?.toLowerCase();

    return RemoteFileInfo(
      length: contentLengthOf(headers),
      acceptsRanges:
          assumeRanges ||
          (acceptRanges != null && acceptRanges.contains('bytes')),
      validator: validatorOf(headers),
    );
  }

  Future<Response<ResponseBody>> _send(
    DownloadFileRequest file, {
    required String method,
    Map<String, String> headers = const {},
    CancelToken? cancelToken,
  }) async {
    try {
      return await _client.dio.request<ResponseBody>(
        file.url,
        cancelToken: cancelToken,
        options: Options(
          method: method,
          headers: {...file.headers, ...headers},
        ),
      );
    } on DioException catch (error) {
      throw dioError(error, file.url);
    }
  }

  static Future<void> _discard(Response<ResponseBody> response) async {
    try {
      await response.data?.stream.listen(null).cancel();
    } catch (_) {
      /// The body is not needed
    }
  }

  /// `ETag` if the server gives it, otherwise `Last-Modified`
  static String? validatorOf(Headers headers) =>
      headers.value('etag') ?? headers.value('last-modified');

  static int? contentLengthOf(Headers headers) {
    final length = int.tryParse(headers.value('content-length') ?? '');

    return length == null || length < 0 ? null : length;
  }
}
