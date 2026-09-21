import 'dart:async';

import 'package:dio/dio.dart';
import 'package:files_downloader/files_downloader.dart';

import '../../api/api.dart';
import '../../constants/constants.dart';
import '../../dto/dto.dart';
import '../../errors/errors.dart';
import '../../models/models.dart';
import '../../tools/tools.dart';
import '../media_stream/remote_media_stream_data_source.dart';

/// A segment of a download: where it comes from and where it goes
final class MediaSegmentTarget {
  final String url;
  final String path;

  const MediaSegmentTarget({required this.url, required this.path});
}

/// RuTube: the player API, HLS playlists and their segments
abstract interface class RemoteRuTubeDataSource {
  /// Title, author, preview and the HLS master playlist of a video.
  /// Throws [VideoException] when RuTube does not show the video: blocked
  /// in the country, removed, private without its key, a live stream
  Future<RuTubeVideoDto> getVideo(RuTubeVideoLink link);

  /// Text of an HLS playlist. Throws [MediaStreamLinksExpiredException]
  /// when the link no longer works
  Future<String> getPlaylist(Uri url);

  /// Downloads the segments into their files, several at a time, in
  /// a background isolate. Segments already on disk are not downloaded
  /// again, so a stopped download continues. [expectedBytes] shows the
  /// size until the finished segments tell it.
  ///
  /// Throws [MediaStreamLinksExpiredException] when the links are refused,
  /// and [VideoException] with [VideoErrorCodes.canceled] when stopped
  /// through [cancellation]
  Future<void> downloadSegments({
    required String downloadId,
    required List<MediaSegmentTarget> segments,
    required void Function(MediaStreamProgress progress) onProgress,
    int? expectedBytes,
    DownloadCancellation? cancellation,
  });
}

final class RemoteRuTubeDataSourceImpl implements RemoteRuTubeDataSource {
  static const _progressInterval = Duration(milliseconds: 250);

  final ApiProvider _apiProvider;
  final FilesDownloader _filesDownloader;

  /// Where the player API lives: another server in tests
  final String _apiOrigin;

  RemoteRuTubeDataSourceImpl({
    required this._apiProvider,
    FilesDownloader? filesDownloader,
    this._apiOrigin = RuTubeConstants.origin,
  }) : _filesDownloader = filesDownloader ?? FilesDownloader();

  @override
  Future<RuTubeVideoDto> getVideo(RuTubeVideoLink link) async {
    final Response<Map<String, dynamic>> response;

    try {
      response = await _apiProvider.rutube.dio.get<Map<String, dynamic>>(
        RuTubeConstants.playOptionsUrl(
          link.id,
          privateKey: link.privateKey,
          apiOrigin: _apiOrigin,
        ),
      );
    } on DioException catch (error) {
      throw _exceptionOf(error);
    }

    return videoOf(link, response.data ?? const {});
  }

  /// The video of a player API answer
  static RuTubeVideoDto videoOf(
    RuTubeVideoLink link,
    Map<String, dynamic> json,
  ) {
    const codes = VideoErrorCodes();
    final balancer = json['video_balancer'];

    /// A blocked video comes without playlists, with the text RuTube
    /// shows in its place
    if (balancer is! Map) {
      throw VideoException(
        codes.rutubeUnavailable,
        reason: _reasonOf(json['detail']),
      );
    }

    final live = json['live_streams'];

    if ((live is Map && live.isNotEmpty) || (live is List && live.isNotEmpty)) {
      throw VideoException(codes.rutubeLive);
    }

    final playlist = balancer['m3u8'] ?? balancer['default'];
    final uri = playlist is String ? Uri.tryParse(playlist) : null;

    if (uri == null || !uri.isAbsolute) {
      throw VideoException(codes.rutubeUnavailable);
    }

    final title = json['title'];
    final author = json['author'];
    final duration = json['duration'];
    final thumbnail = json['thumbnail_url'];

    return RuTubeVideoDto(
      id: link.id,
      title: title is String && title.trim().isNotEmpty
          ? title.trim()
          : link.id,
      author: author is Map ? author['name'] as String? : null,

      /// The player API counts milliseconds
      durationSeconds: duration is num && duration > 0 ? duration / 1000 : null,
      thumbnail: thumbnail is String ? thumbnail : null,
      masterPlaylist: uri,
    );
  }

  /// What RuTube shows instead of the video, in Russian if it has it
  static String? _reasonOf(Object? detail) {
    final languages = detail is Map ? detail['languages'] : null;

    if (languages is! List) return null;

    final entries = languages.whereType<Map>();
    final entry =
        entries.where((entry) => entry['lang'] == 'rus').firstOrNull ??
        entries.firstOrNull;
    final title = entry?['title'];

    return title is String && title.trim().isNotEmpty ? title.trim() : null;
  }

  @override
  Future<String> getPlaylist(Uri url) async {
    try {
      final response = await _apiProvider.rutube.dio.get<String>(
        url.toString(),
        options: Options(responseType: ResponseType.plain),
      );

      return response.data ?? '';
    } on DioException catch (error) {
      /// Playlist links are signed and expire like the segment links
      if (error.response?.statusCode case 401 || 403 || 404 || 410) {
        throw const MediaStreamLinksExpiredException();
      }

      throw _exceptionOf(error);
    }
  }

  static Exception _exceptionOf(DioException error) {
    const codes = VideoErrorCodes();
    final status = error.response?.statusCode;
    final data = error.response?.data;

    return switch (error.type) {
      DioExceptionType.cancel => VideoException(codes.canceled),
      DioExceptionType.badResponse when status == 404 => VideoException(
        codes.rutubeUnavailable,
        reason: _reasonOf(data is Map ? data['detail'] : null),
      ),
      DioExceptionType.badResponse => VideoException(
        codes.rutubeHttpStatus,
        args: {'status': '$status'},
      ),
      _ => VideoException(codes.rutubeNoConnection),
    };
  }

  @override
  Future<void> downloadSegments({
    required String downloadId,
    required List<MediaSegmentTarget> segments,
    required void Function(MediaStreamProgress progress) onProgress,
    int? expectedBytes,
    DownloadCancellation? cancellation,
  }) async {
    const codes = VideoErrorCodes();

    if (cancellation?.isCancelled ?? false) {
      throw VideoException(codes.canceled);
    }

    final client = _apiProvider.rutube;
    final download = await _filesDownloader.startSegments(
      SegmentsDownloadRequest(
        id: downloadId,
        expectedBytes: expectedBytes,
        options: FilesDownloadOptions(
          maxConnections: RuTubeConstants.segmentConnections,
          connectTimeout: client.connectTimeout,
          idleTimeout: client.receiveTimeout,
          progressInterval: _progressInterval,
          headers: {
            for (final header in client.headers.entries)
              header.key: '${header.value}',
          },
        ),
        segments: [
          for (final segment in segments)
            DownloadSegmentRequest(url: segment.url, savePath: segment.path),
        ],
      ),
    );

    final subscription = download.progress.listen(
      (progress) => onProgress(
        MediaStreamProgress(
          downloadedBytes: progress.downloadedBytes,
          totalBytes:
              progress.totalBytes ?? expectedBytes ?? progress.downloadedBytes,
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
        throw mediaDownloadExceptionOf(error, source: VideoSourceModel.rutube);
    }
  }
}
