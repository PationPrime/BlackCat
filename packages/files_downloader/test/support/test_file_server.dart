import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

Uint8List testContent(int length, {int seed = 7}) => Uint8List.fromList([
  for (var i = 0; i < length; i++) (i * 31 + seed) % 256,
]);

/// A request the server got
final class ServedRequest {
  final String method;
  final String path;
  final String? rangeHeader;
  final String? rangeParameter;
  final String? ifRange;

  /// Which request of this path it is, from 1
  final int number;

  ServedRequest({
    required this.method,
    required this.path,
    required this.rangeHeader,
    required this.rangeParameter,
    required this.ifRange,
    required this.number,
  });

  /// Start of the asked range
  int? get askedStart {
    final range = rangeHeader?.replaceFirst('bytes=', '') ?? rangeParameter;

    return range == null ? null : int.tryParse(range.split('-').first);
  }

  @override
  String toString() => '$method $path ${rangeHeader ?? rangeParameter ?? ''}';
}

/// What a range answer actually is: the bytes sent and the header claimed
typedef ServedPart = ({int start, int end, String contentRange});

/// A file server whose answers a test can bend
final class TestFileServer {
  final files = <String, Uint8List>{};
  final requests = <ServedRequest>[];

  bool acceptRanges = true;
  bool supportHead = true;

  /// Ranges come as `?range=a-b` and are answered with `200`
  bool queryRanges = false;

  /// No `Content-Length`: the body is chunked
  bool chunked = false;
  String? etag;
  Duration chunkDelay = Duration.zero;

  /// Forces a status without a body
  int? Function(ServedRequest request)? statusFor;

  /// Changes the part sent for an asked range of a file of [total] bytes
  ServedPart? Function(ServedRequest request, int start, int end, int total)?
  bendRange;

  /// Sends the whole file with `200` instead of the asked part
  bool Function(ServedRequest request)? ignoreRange;

  /// Drops the connection after this many body bytes
  int? Function(ServedRequest request)? cutAfter;

  final writeErrors = <Object>[];

  var _active = 0;
  var maxActive = 0;
  var servedBytes = 0;

  late final HttpServer _server;
  final _counts = <String, int>{};

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen(_handle);
  }

  Future<void> close() => _server.close(force: true);

  /// Waits for the answers still being sent
  Future<void> idle() async {
    for (var i = 0; i < 500 && _active > 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  String url(String path) =>
      'http://${_server.address.host}:${_server.port}$path';

  List<ServedRequest> gets(String path) => [
    for (final request in requests)
      if (request.method == 'GET' && request.path == path) request,
  ];

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    final served = ServedRequest(
      method: request.method,
      path: path,
      rangeHeader: request.headers.value('range'),
      rangeParameter: request.uri.queryParameters['range'],
      ifRange: request.headers.value('if-range'),
      number: _counts[path] = (_counts[path] ?? 0) + 1,
    );
    final response = request.response;

    requests.add(served);
    _active++;
    maxActive = math.max(maxActive, _active);

    try {
      final content = files[path];

      if (content == null) {
        response.statusCode = 404;

        return;
      }

      if (statusFor?.call(served) case final status?) {
        response.statusCode = status;

        return;
      }

      if (acceptRanges && !queryRanges) {
        response.headers.set('accept-ranges', 'bytes');
      }

      if (etag case final etag?) response.headers.set('etag', etag);

      if (request.method == 'HEAD') {
        if (!supportHead) {
          response.statusCode = 405;

          return;
        }

        if (!chunked) response.contentLength = content.length;

        return;
      }

      final total = content.length;

      if (queryRanges && served.rangeParameter != null) {
        final [start, end] = [
          for (final part in served.rangeParameter!.split('-')) int.parse(part),
        ];

        await _send(
          served,
          response,
          content.sublist(start, math.min(end + 1, total)),
        );

        return;
      }

      final match = RegExp(
        r'^bytes=(\d+)-(\d*)$',
      ).firstMatch(served.rangeHeader ?? '');
      final ifRangeFails = served.ifRange != null && served.ifRange != etag;

      if (match == null ||
          !acceptRanges ||
          ifRangeFails ||
          (ignoreRange?.call(served) ?? false)) {
        await _send(served, response, content);

        return;
      }

      final start = int.parse(match.group(1)!);
      final end = math.min(
        match.group(2)!.isEmpty ? total - 1 : int.parse(match.group(2)!),
        total - 1,
      );

      if (start >= total) {
        response
          ..statusCode = 416
          ..headers.set('content-range', 'bytes */$total');

        return;
      }

      final part =
          bendRange?.call(served, start, end, total) ??
          (start: start, end: end, contentRange: 'bytes $start-$end/$total');

      response
        ..statusCode = 206
        ..headers.set('content-range', part.contentRange);

      await _send(
        served,
        response,
        content.sublist(part.start, math.min(part.end + 1, total)),
      );
    } on _Dropped {
      /// The connection is gone
    } catch (error) {
      /// The downloader closes a connection once it has what it needs
      writeErrors.add(error);
    } finally {
      _active--;

      try {
        await response.close();
      } catch (_) {
        /// The connection was dropped on purpose
      }
    }
  }

  Future<void> _send(
    ServedRequest served,
    HttpResponse response,
    Uint8List body,
  ) async {
    const chunkSize = 16 * 1024;
    final cut = cutAfter?.call(served);

    if (!chunked) response.contentLength = body.length;

    for (var offset = 0; offset < body.length; offset += chunkSize) {
      final end = math.min(offset + chunkSize, body.length);

      if (cut != null && end > cut) {
        response.add(body.sublist(offset, math.max(offset, cut)));
        servedBytes += math.max(0, cut - offset);
        await response.flush();

        /// Lets the bytes leave before the connection is dropped
        await Future<void>.delayed(const Duration(milliseconds: 30));

        final socket = await response.detachSocket(writeHeaders: false);

        socket.destroy();

        throw const _Dropped();
      }

      response.add(body.sublist(offset, end));
      servedBytes += end - offset;

      if (chunkDelay > Duration.zero) {
        await response.flush();
        await Future<void>.delayed(chunkDelay);
      }
    }
  }
}

final class _Dropped implements Exception {
  const _Dropped();
}
