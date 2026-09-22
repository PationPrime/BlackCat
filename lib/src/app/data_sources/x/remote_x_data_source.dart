import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:files_downloader/files_downloader.dart';

import '../../api/api.dart';
import '../../constants/constants.dart';
import '../../dto/dto.dart';
import '../../errors/errors.dart';
import '../../models/models.dart';
import '../../tools/tools.dart';
import '../media_stream/remote_media_stream_data_source.dart';

/// X (Twitter): posts from the embed API and their video files
abstract interface class RemoteXDataSource {
  /// The video of a post: what the post shows and its files with their
  /// sizes. Throws [VideoException] when X does not show the post or it has
  /// no video
  Future<XVideoDto> getVideo(XPostLink link);

  /// Exact size of a file, from its first byte. `null` when the server
  /// does not tell it
  Future<int?> sizeOf(String url);

  /// Downloads [format] into [path] in slices over several connections,
  /// in a background isolate. Slice progress lives in
  /// `state_<downloadId>.fds` in [stateDirectory], so a stopped download
  /// continues from it.
  ///
  /// Throws [MediaStreamLinksExpiredException] when the links are refused,
  /// and [VideoException] with [VideoErrorCodes.canceled] when stopped
  /// through [cancellation]
  Future<void> downloadVideo({
    required String downloadId,
    required XFormatDto format,
    required String path,
    required String stateDirectory,
    required void Function(MediaStreamProgress progress) onProgress,
    DownloadCancellation? cancellation,
  });
}

final class RemoteXDataSourceImpl implements RemoteXDataSource {
  static const _progressInterval = Duration(milliseconds: 250);
  static const _videoTypes = {'video', 'animated_gif'};

  /// Short links X adds to the text: the media and the links in it
  static final _shortLinkPattern = RegExp(r'\s*https?://t\.co/\S+');

  final ApiProvider _apiProvider;
  final FilesDownloader _filesDownloader;

  /// Where the embed API lives: another server in tests
  final String _syndicationOrigin;

  RemoteXDataSourceImpl({
    required this._apiProvider,
    FilesDownloader? filesDownloader,
    this._syndicationOrigin = XConstants.syndicationOrigin,
  }) : _filesDownloader = filesDownloader ?? FilesDownloader();

  Dio get _dio => _apiProvider.x.dio;

  /// The token the X embed script sends with a post id:
  /// `(id / 1e15 * π).toString(36)` without zeros and dots
  static String syndicationToken(String id) =>
      _toRadix36(int.parse(id) / 1e15 * math.pi).replaceAll(RegExp('[0.]'), '');

  /// `Number.prototype.toString(36)` of a positive number, digit for digit
  /// as JavaScript writes it: the fraction goes as far as the number is
  /// precise
  static String _toRadix36(double value) {
    const radix = 36;
    const alphabet = '0123456789abcdefghijklmnopqrstuvwxyz';

    var integer = value.truncateToDouble();
    var fraction = value - integer;
    var delta = math.max(double.minPositive, _ulp(value) / 2);
    final digits = <int>[];

    while (fraction >= delta) {
      delta *= radix;
      fraction *= radix;

      final digit = fraction.truncate();

      fraction -= digit;
      digits.add(digit);

      /// Rounding carries through the digits written
      if ((fraction > 0.5 || (fraction == 0.5 && digit.isOdd)) &&
          fraction + delta > 1) {
        var index = digits.length - 1;

        while (true) {
          if (index < 0) {
            integer += 1;
            break;
          }

          if (digits[index] + 1 < radix) {
            digits[index] += 1;
            break;
          }

          digits.removeAt(index);
          index--;
        }

        break;
      }
    }

    var whole = BigInt.from(integer);
    final head = StringBuffer();
    final big = BigInt.from(radix);

    do {
      head.write(alphabet[(whole % big).toInt()]);
      whole ~/= big;
    } while (whole > BigInt.zero);

    return [
      head.toString().split('').reversed.join(),
      if (digits.isNotEmpty)
        '.${digits.map((digit) => alphabet[digit]).join()}',
    ].join();
  }

  /// Distance to the next larger number
  static double _ulp(double value) {
    final data = ByteData(8)..setFloat64(0, value);

    data.setInt64(0, data.getInt64(0) + 1);

    return data.getFloat64(0) - value;
  }

  @override
  Future<XVideoDto> getVideo(XPostLink link) async {
    final Response<String> response;

    try {
      response = await _dio.get<String>(
        '$_syndicationOrigin/tweet-result',
        queryParameters: {
          'id': link.id,
          'token': syndicationToken(link.id),
          'lang': 'en',
        },
        options: Options(responseType: ResponseType.plain),
      );
    } on DioException catch (error) {
      throw _exceptionOf(error);
    }

    final Object? json;

    try {
      json = jsonDecode(response.data ?? '');
    } on FormatException {
      throw VideoException(const VideoErrorCodes().xUnavailable);
    }

    final video = videoOf(json, link: link);
    final sizes = await Future.wait([
      for (final format in video.formats) sizeOf(format.url),
    ]);

    return XVideoDto(
      id: video.id,
      title: video.title,
      formats: [
        for (final (index, format) in video.formats.indexed)
          format.withSize(
            sizes[index] ??
                switch (video.durationSeconds) {
                  final seconds? when format.bitrate > 0 =>
                    (format.bitrate / 8 * seconds).round(),
                  _ => null,
                },
          ),
      ],
      url: video.url,
      author: video.author,
      authorName: video.authorName,
      durationSeconds: video.durationSeconds,
      thumbnail: video.thumbnail,
      viewCount: video.viewCount,
    );
  }

  /// The video of an embed API answer. [link] names the media of the post;
  /// without it the first video is taken, or the first one of the quoted
  /// post
  static XVideoDto videoOf(Object? json, {required XPostLink link}) {
    const codes = VideoErrorCodes();
    final status = _map(json);
    final typename = status?['__typename'];

    /// A removed, protected or age-restricted post shows a tombstone
    if (status == null ||
        typename == 'TweetTombstone' ||
        typename == 'TweetUnavailable') {
      throw VideoException(codes.xUnavailable);
    }

    List<Map<dynamic, dynamic>> mediaOf(Map<dynamic, dynamic>? post) => [
      for (final media in _list(post?['mediaDetails'])) ?_map(media),
    ];

    bool isVideo(Map<dynamic, dynamic> media) =>
        _videoTypes.contains(media['type']);

    final ownMedia = mediaOf(status);
    final index = link.mediaIndex;

    /// The post's own videos, or the ones of the post it quotes
    final videos = ownMedia.where(isVideo).isNotEmpty || index != null
        ? ownMedia.where(isVideo).toList()
        : mediaOf(_map(status['quoted_tweet'])).where(isVideo).toList();
    final media = switch (index) {
      final index? when index <= ownMedia.length => ownMedia[index - 1],
      null => videos.firstOrNull,
      _ => null,
    };

    if (media == null || !isVideo(media)) {
      throw VideoException(codes.xNoVideo);
    }

    final availability = _map(media['ext_media_availability'])?['status'];

    if ('$availability'.toLowerCase() == 'unavailable') {
      throw VideoException(codes.xUnavailable);
    }

    final info = _map(media['video_info']);
    final original = _map(media['original_info']);
    final formats = <XFormatDto>[];

    for (final variant in _list(info?['variants']).map(_map)) {
      final url = variant?['url'];

      if (variant?['content_type'] != 'video/mp4' ||
          url is! String ||
          url.isEmpty ||
          formats.any((format) => format.url == url)) {
        continue;
      }

      /// A GIF link does not name its picture: the post does
      final size = XQualities.sizeOfUrl(url);

      formats.add(
        XFormatDto(
          url: url,
          bitrate: _int(variant?['bitrate']) ?? 0,
          width: size?.width ?? _int(original?['width']),
          height: size?.height ?? _int(original?['height']),
          codec: XQualities.codecOfUrl(url),
        ),
      );
    }

    final user = _map(status['user']);
    final screenName = user?['screen_name'] as String?;
    final text = _unescape(
      '${status['text'] ?? ''}',
    ).replaceAll(_shortLinkPattern, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    final number = videos.length > 1 ? videos.indexOf(media) + 1 : 0;
    final title = text.isNotEmpty
        ? text
        : 'X${screenName == null ? '' : ' @$screenName'}';
    final duration = _int(info?['duration_millis']);
    final thumbnail = media['media_url_https'];

    return XVideoDto(
      id: '${status['id_str'] ?? link.id}',
      title: number > 0 ? '$title #$number' : title,
      formats: formats,
      url: XPostLink(
        '${status['id_str'] ?? link.id}',
        author: screenName ?? link.author,
        mediaIndex: link.mediaIndex,
      ).url,
      author: screenName,
      authorName: user?['name'] as String? ?? screenName,
      durationSeconds: duration == null ? null : duration / 1000,
      thumbnail: thumbnail is String && thumbnail.isNotEmpty ? thumbnail : null,
    );
  }

  /// X escapes these in the post text
  static String _unescape(String text) => text
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&amp;', '&');

  static Map<dynamic, dynamic>? _map(Object? value) =>
      value is Map ? value : null;

  static List<Object?> _list(Object? value) => value is List ? value : const [];

  static int? _int(Object? value) => switch (value) {
    final num number => number.toInt(),
    final String text => int.tryParse(text),
    _ => null,
  };

  static Exception _exceptionOf(DioException error) {
    const codes = VideoErrorCodes();
    final status = error.response?.statusCode;

    return switch (error.type) {
      DioExceptionType.cancel => VideoException(codes.canceled),
      DioExceptionType.badResponse when status == 404 => VideoException(
        codes.xUnavailable,
      ),
      DioExceptionType.badResponse => VideoException(
        codes.xHttpStatus,
        args: {'status': '$status'},
      ),
      _ => VideoException(codes.xNoConnection),
    };
  }

  @override
  Future<int?> sizeOf(String url) async {
    try {
      final response = await _dio.get<ResponseBody>(
        url,
        options: Options(
          responseType: ResponseType.stream,
          headers: const {'Range': 'bytes=0-0'},
        ),
      );

      /// Only the header is needed
      await response.data?.stream.listen(null).cancel();

      return switch (response.statusCode) {
        206 => int.tryParse(
          response.headers.value('content-range')?.split('/').last ?? '',
        ),
        200 => int.tryParse(response.headers.value('content-length') ?? ''),
        _ => null,
      };
    } on DioException {
      /// The download tells what is wrong with the file
      return null;
    }
  }

  @override
  Future<void> downloadVideo({
    required String downloadId,
    required XFormatDto format,
    required String path,
    required String stateDirectory,
    required void Function(MediaStreamProgress progress) onProgress,
    DownloadCancellation? cancellation,
  }) async {
    const codes = VideoErrorCodes();

    if (cancellation?.isCancelled ?? false) {
      throw VideoException(codes.canceled);
    }

    final client = _apiProvider.x;
    final download = await _filesDownloader.start(
      FilesDownloadRequest(
        id: downloadId,
        stateDirectory: stateDirectory,
        options: FilesDownloadOptions(
          sliceSize: YouTubeConstants.streamChunkSize,
          maxConnections: XConstants.connections,
          connectTimeout: client.connectTimeout,
          idleTimeout: client.receiveTimeout,
          progressInterval: _progressInterval,
          headers: {
            for (final header in client.headers.entries)
              header.key: '${header.value}',
          },
        ),
        files: [
          DownloadFileRequest(
            url: format.url,
            savePath: path,
            expectedLength: format.size,

            /// The link names the file: it stays the same between requests
            fingerprint:
                '${XConstants.filePrefix}${Uri.tryParse(format.url)?.path}',
            checkValidator: false,
          ),
        ],
      ),
    );

    final subscription = download.progress.listen(
      (progress) => onProgress(
        MediaStreamProgress(
          downloadedBytes: progress.downloadedBytes,
          totalBytes:
              progress.totalBytes ?? format.size ?? progress.downloadedBytes,
          bytesPerSecond: progress.bytesPerSecond,
        ),
      ),
    );

    unawaited(cancellation?.whenCancelled.then((_) => download.pause()));

    final result = await download.result;

    /// The progress stream is already closed
    unawaited(subscription.cancel());

    switch (result) {
      case FilesDownloadCompleted():
        return;
      case FilesDownloadStopped():
        throw VideoException(codes.canceled);
      case FilesDownloadFailed(:final error):
        throw mediaDownloadExceptionOf(error, source: VideoSourceModel.x);
    }
  }
}
