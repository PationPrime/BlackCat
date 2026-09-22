import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:files_downloader/files_downloader.dart';

import '../../api/api.dart';
import '../../constants/constants.dart';
import '../../dto/dto.dart';
import '../../errors/errors.dart';
import '../../models/models.dart';
import '../../tools/tools.dart';
import '../media_stream/remote_media_stream_data_source.dart';

/// TikTok: video pages and their files
abstract interface class RemoteTikTokDataSource {
  /// The video of a link: what its page shows, the qualities and the cookies
  /// their links need. A short link is followed to its video.
  /// Throws [VideoException] when TikTok does not show the video
  Future<TikTokVideoDto> getVideo(TikTokVideoLink link);

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
    required TikTokVideoDto video,
    required TikTokFormatDto format,
    required String path,
    required String stateDirectory,
    required void Function(MediaStreamProgress progress) onProgress,
    DownloadCancellation? cancellation,
  });
}

final class RemoteTikTokDataSourceImpl implements RemoteTikTokDataSource {
  static const _progressInterval = Duration(milliseconds: 250);

  /// The page data TikTok renders for the browser
  static final _dataPattern = RegExp(
    r'<script[^>]+id="__UNIVERSAL_DATA_FOR_REHYDRATION__"[^>]*>(.*?)</script>',
    dotAll: true,
  );

  final ApiProvider _apiProvider;
  final FilesDownloader _filesDownloader;

  /// Where the video pages live: another server in tests
  final String _origin;

  RemoteTikTokDataSourceImpl({
    required this._apiProvider,
    FilesDownloader? filesDownloader,
    this._origin = TikTokConstants.origin,
  }) : _filesDownloader = filesDownloader ?? FilesDownloader();

  @override
  Future<TikTokVideoDto> getVideo(TikTokVideoLink link) async {
    const codes = VideoErrorCodes();

    if (link.isPhoto) {
      throw VideoException(codes.tiktokPhoto);
    }

    final Response<String> response;

    try {
      response = await _apiProvider.tiktok.dio.get<String>(
        switch (link.id) {
          final id? => '$_origin/@${link.author ?? '_'}/video/$id',
          null => link.url,
        },
        options: Options(
          responseType: ResponseType.plain,
          headers: const {
            'Accept':
                'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          },
        ),
      );
    } on DioException catch (error) {
      throw _exceptionOf(error);
    }

    return videoOf(
      response.data ?? '',
      pageUrl: response.realUri.toString(),
      cookies: _cookiesOf(response.headers),
    );
  }

  /// The video of a page, with the page link and its cookies
  static TikTokVideoDto videoOf(
    String html, {
    required String pageUrl,
    required String cookies,
  }) {
    const codes = VideoErrorCodes();
    final unavailable = VideoException(codes.tiktokUnavailable);
    final data = _dataPattern.firstMatch(html)?.group(1);

    /// A page without the data: a check page or a blocked region
    if (data == null) throw unavailable;

    final Object? json;

    try {
      json = jsonDecode(data);
    } on FormatException {
      throw unavailable;
    }

    final detail = _map(
      _map(json)?['__DEFAULT_SCOPE__'],
    )?['webapp.video-detail'];
    final item = _map(_map(_map(detail)?['itemInfo'])?['itemStruct']);

    if (_map(detail)?['statusCode'] != 0 || item == null) throw unavailable;

    if (item['imagePost'] != null) {
      throw VideoException(codes.tiktokPhoto);
    }

    final video = _map(item['video']) ?? const {};
    final formats = [
      for (final info in _list(video['bitrateInfo']))
        if (_map(_map(info)?['PlayAddr']) case final play?)
          TikTokFormatDto(
            urls: [
              for (final url in _list(play['UrlList']))
                if (url is String && url.isNotEmpty) url,
            ],
            bitrate: _int(_map(info)?['Bitrate']) ?? 0,
            codec: '${_map(info)?['CodecType'] ?? 'h264'}',
            width: _int(play['Width']),
            height: _int(play['Height']),
            size: _int(play['DataSize']),
          ),
    ].where((format) => format.urls.isNotEmpty).toList();

    final playAddress = video['playAddr'];

    /// Older pages give only the one address the player starts with
    if (formats.isEmpty && playAddress is String && playAddress.isNotEmpty) {
      formats.add(
        TikTokFormatDto(
          urls: [playAddress],
          bitrate: _int(video['bitrate']) ?? 0,
          codec: '${video['codecType'] ?? 'h264'}',
          width: _int(video['width']),
          height: _int(video['height']),
        ),
      );
    }

    if (formats.isEmpty) throw unavailable;

    final author = _map(item['author']);
    final authorId = author?['uniqueId'] as String?;

    /// Descriptions often take several lines: the title takes one
    final description = '${item['desc'] ?? ''}'
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final cover = video['cover'] ?? video['originCover'];

    return TikTokVideoDto(
      id: '${item['id']}',
      title: description.isNotEmpty
          ? description
          : 'TikTok${authorId == null ? '' : ' @$authorId'}',
      author: authorId,
      authorName: author?['nickname'] as String? ?? authorId,
      durationSeconds: _int(video['duration']),
      thumbnail: cover is String && cover.isNotEmpty ? cover : null,
      viewCount:
          _int(_map(item['stats'])?['playCount']) ??
          _int(_map(item['statsV2'])?['playCount']),
      formats: formats,
      pageUrl: pageUrl,
      cookies: cookies,
    );
  }

  static Map<dynamic, dynamic>? _map(Object? value) =>
      value is Map ? value : null;

  static List<Object?> _list(Object? value) => value is List ? value : const [];

  /// TikTok writes numbers as numbers or as strings
  static int? _int(Object? value) => switch (value) {
    final num number => number.toInt(),
    final String text => int.tryParse(text),
    _ => null,
  };

  /// `Cookie` header of the cookies the page set
  static String _cookiesOf(Headers headers) => [
    for (final cookie in headers['set-cookie'] ?? const <String>[])
      if (cookie.split(';').first.trim() case final pair
          when pair.contains('='))
        pair,
  ].join('; ');

  static Exception _exceptionOf(DioException error) {
    const codes = VideoErrorCodes();
    final status = error.response?.statusCode;

    return switch (error.type) {
      DioExceptionType.cancel => VideoException(codes.canceled),
      DioExceptionType.badResponse when status == 404 => VideoException(
        codes.tiktokUnavailable,
      ),
      DioExceptionType.badResponse => VideoException(
        codes.tiktokHttpStatus,
        args: {'status': '$status'},
      ),
      _ => VideoException(codes.tiktokNoConnection),
    };
  }

  @override
  Future<void> downloadVideo({
    required String downloadId,
    required TikTokVideoDto video,
    required TikTokFormatDto format,
    required String path,
    required String stateDirectory,
    required void Function(MediaStreamProgress progress) onProgress,
    DownloadCancellation? cancellation,
  }) async {
    const codes = VideoErrorCodes();

    if (cancellation?.isCancelled ?? false) {
      throw VideoException(codes.canceled);
    }

    final client = _apiProvider.tiktok;
    final download = await _filesDownloader.start(
      FilesDownloadRequest(
        id: downloadId,
        stateDirectory: stateDirectory,
        options: FilesDownloadOptions(
          sliceSize: YouTubeConstants.streamChunkSize,
          maxConnections: TikTokConstants.connections,
          connectTimeout: client.connectTimeout,
          idleTimeout: client.receiveTimeout,
          progressInterval: _progressInterval,
          headers: {
            for (final header in client.headers.entries)
              header.key: '${header.value}',

            /// The file links check the page they came from
            'Referer': video.pageUrl,
            if (video.cookies.isNotEmpty) 'Cookie': video.cookies,
          },
        ),
        files: [
          DownloadFileRequest(
            url: format.urls.first,
            savePath: path,
            expectedLength: format.size,

            /// Links change with every page, the file stays the same
            fingerprint:
                '${TikTokConstants.filePrefix}${video.id}-${format.bitrate}',
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
        throw mediaDownloadExceptionOf(error, source: VideoSourceModel.tiktok);
    }
  }
}
