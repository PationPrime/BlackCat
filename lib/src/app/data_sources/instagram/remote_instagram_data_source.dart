import 'dart:async';
import 'dart:convert';
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

/// A stream of a post and where it goes on disk
typedef InstagramStreamTarget = ({InstagramStreamDto stream, String path});

/// Instagram: post pages and their files
abstract interface class RemoteInstagramDataSource {
  /// The post a share link leads to; other links as they are.
  /// Throws [VideoException] when Instagram does not show the post
  Future<InstagramVideoLink> resolve(InstagramVideoLink link);

  /// The video of a post: what its page shows and its files. The size and
  /// the picture of a ready file come from its first bytes.
  /// Throws [VideoException] when Instagram does not show the video
  Future<InstagramVideoDto> getVideo(InstagramVideoLink link);

  /// A ready file with its size, picture and codec, as its first bytes tell
  /// them. The file as it is when they do not
  Future<InstagramStreamDto> probeFile(InstagramStreamDto file);

  /// Downloads [files] into their paths in slices over several connections,
  /// in a background isolate. Slice progress lives in
  /// `state_<downloadId>.fds` in [stateDirectory], so a stopped download
  /// continues from it.
  ///
  /// Throws [MediaStreamLinksExpiredException] when the links are refused,
  /// and [VideoException] with [VideoErrorCodes.canceled] when stopped
  /// through [cancellation]
  Future<void> downloadStreams({
    required String downloadId,
    required String code,
    required List<InstagramStreamTarget> files,
    required String stateDirectory,
    required void Function(MediaStreamProgress progress) onProgress,
    DownloadCancellation? cancellation,
  });
}

final class RemoteInstagramDataSourceImpl implements RemoteInstagramDataSource {
  static const _progressInterval = Duration(milliseconds: 250);

  /// A web file keeps `moov` in its first kilobytes
  static const _probeBytes = 64 * 1024;
  static const _maxMoovBytes = 16 * 1024 * 1024;

  /// Instagram renders the post into the page only for a browser that
  /// opens it
  static const _pageHeaders = {
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Sec-Fetch-Dest': 'document',
    'Sec-Fetch-Mode': 'navigate',
    'Sec-Fetch-Site': 'none',
    'Sec-Fetch-User': '?1',
    'Upgrade-Insecure-Requests': '1',
  };

  /// Page data scripts; one of them carries the post
  static final _scriptPattern = RegExp(
    r'<script\b[^>]*\bdata-sjs\b[^>]*>(.*?)</script>',
    dotAll: true,
  );
  static final _representationPattern = RegExp(
    r'<Representation\b([^>]*)>(.*?)</Representation>',
    dotAll: true,
  );
  static final _attributePattern = RegExp(r'([\w:]+)="([^"]*)"');
  static final _baseUrlPattern = RegExp(r'<BaseURL>([^<]+)</BaseURL>');
  static final _presentationDurationPattern = RegExp(
    r'mediaPresentationDuration="([^"]+)"',
  );
  static final _isoDurationPattern = RegExp(
    r'^PT(?:([\d.]+)H)?(?:([\d.]+)M)?(?:([\d.]+)S)?$',
  );

  final ApiProvider _apiProvider;
  final FilesDownloader _filesDownloader;

  /// Where the post pages live: another server in tests
  final String _origin;

  RemoteInstagramDataSourceImpl({
    required this._apiProvider,
    FilesDownloader? filesDownloader,
    this._origin = InstagramConstants.origin,
  }) : _filesDownloader = filesDownloader ?? FilesDownloader();

  Dio get _dio => _apiProvider.instagram.dio;

  Future<Response<String>> _page(String url) async {
    final Response<String> response;

    try {
      response = await _dio.get<String>(
        url,
        options: Options(
          responseType: ResponseType.plain,
          headers: _pageHeaders,
        ),
      );
    } on DioException catch (error) {
      throw _exceptionOf(error);
    }

    /// Instagram sends a visitor it limits to the login page
    if (response.realUri.path.startsWith('/accounts/login')) {
      throw VideoException(const VideoErrorCodes().instagramRateLimited);
    }

    return response;
  }

  String _pageUrlOf(InstagramVideoLink link) => switch (link.code) {
    final code? => '$_origin/${link.kind.path}/$code/',
    null => link.url,
  };

  @override
  Future<InstagramVideoLink> resolve(InstagramVideoLink link) async {
    if (!link.isShare) return link;

    final response = await _page(link.url);

    return InstagramUrlParser.parse('${response.realUri}') ??
        (throw VideoException(const VideoErrorCodes().instagramUnavailable));
  }

  @override
  Future<InstagramVideoDto> getVideo(InstagramVideoLink link) async {
    final response = await _page(_pageUrlOf(link));
    final pageLink = link.isShare
        ? InstagramUrlParser.parse('${response.realUri}')
        : link;
    final video = videoOf(response.data ?? '', kind: pageLink?.kind);
    final streams = <InstagramStreamDto>[];

    for (final stream in video.streams) {
      streams.add(
        stream.kind == InstagramStreamKind.file
            ? await probeFile(stream)
            : stream,
      );
    }

    return InstagramVideoDto(
      code: video.code,
      title: video.title,
      /// A ready file whose first bytes tell no picture gets no quality
      streams: streams,
      url: video.url,
      author: video.author,
      authorName: video.authorName,

      /// A page without a duration: the ready file tells it
      durationSeconds:
          video.durationSeconds ??
          streams.map((stream) => stream.duration).nonNulls.firstOrNull,
      thumbnail: video.thumbnail,
      viewCount: video.viewCount,
    );
  }

  /// The video of a post page. [kind] names the page link of the post;
  /// a reel by default
  static InstagramVideoDto videoOf(String html, {InstagramPostKind? kind}) {
    const codes = VideoErrorCodes();
    final unavailable = VideoException(codes.instagramUnavailable);
    final media = _mediaOf(html);

    /// An error page: the post is removed, private or not shown to visitors
    if (media == null) throw unavailable;

    final post = _map(media['if_not_gated_logged_out']);

    /// Sensitive and age-restricted posts are shown only after login
    if (post == null) throw unavailable;

    final item = switch (_list(post['carousel_media'])) {
      /// A post of several photos and videos: its first video
      final items when items.isNotEmpty =>
        items
            .map(_map)
            .firstWhere(
              (item) => item != null && _hasVideo(item),
              orElse: () => null,
            ),
      _ => _hasVideo(post) ? post : null,
    };

    if (item == null) throw VideoException(codes.instagramPhoto);

    final streams = [
      ...filesOf(item),
      ...dashStreamsOf('${item['video_dash_manifest'] ?? ''}'),
    ];

    if (streams.isEmpty) throw unavailable;

    final user = _map(post['user']);
    final username = user?['username'] as String?;
    final fullName = '${user?['full_name'] ?? ''}'.trim();
    final caption = '${_map(post['caption'])?['text'] ?? ''}'
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final code = '${post['code'] ?? media['code'] ?? ''}';
    final candidates = _list(_map(item['image_versions2'])?['candidates']);
    final thumbnail =
        _map(candidates.firstOrNull)?['url'] ?? item['display_uri'];
    final postKind =
        kind ??
        (post['product_type'] == 'clips'
            ? InstagramPostKind.reel
            : InstagramPostKind.post);

    return InstagramVideoDto(
      code: code,
      title: caption.isNotEmpty
          ? caption
          : 'Instagram${username == null ? '' : ' @$username'}',
      streams: streams,
      url: InstagramVideoLink(code, kind: postKind).url,
      author: username,
      authorName: fullName.isNotEmpty ? fullName : username,
      durationSeconds:
          _num(item['video_duration']) ??
          _durationOfManifest('${item['video_dash_manifest'] ?? ''}'),
      thumbnail: thumbnail is String && thumbnail.isNotEmpty ? thumbnail : null,
      viewCount:
          _int(post['play_count']) ??
          _int(post['ig_play_count']) ??
          _int(post['view_count']),
    );
  }

  static bool _hasVideo(Map<dynamic, dynamic> item) =>
      _list(item['video_versions']).isNotEmpty ||
      '${item['video_dash_manifest'] ?? ''}'.isNotEmpty;

  /// `xig_polaris_media` of the page data
  static Map<dynamic, dynamic>? _mediaOf(String html) {
    for (final match in _scriptPattern.allMatches(html)) {
      final script = match.group(1)!;

      if (!script.contains('xig_polaris_media')) continue;

      final Object? json;

      try {
        json = jsonDecode(script);
      } on FormatException {
        continue;
      }

      if (_find(json, 'xig_polaris_media') case final media?) return media;
    }

    return null;
  }

  static Map<dynamic, dynamic>? _find(Object? value, String key) {
    switch (value) {
      case final Map<dynamic, dynamic> map:
        if (_map(map[key]) case final found?) return found;

        for (final child in map.values) {
          if (_find(child, key) case final found?) return found;
        }
      case final List<dynamic> list:
        for (final child in list) {
          if (_find(child, key) case final found?) return found;
        }
    }

    return null;
  }

  /// Ready files of a post; its versions often are the same file
  static List<InstagramStreamDto> filesOf(Map<dynamic, dynamic> item) {
    final files = <String, InstagramStreamDto>{};

    for (final version in _list(item['video_versions']).map(_map)) {
      final url = version?['url'];

      if (url is! String || url.isEmpty || files.containsKey(url)) continue;

      files[url] = InstagramStreamDto(
        kind: InstagramStreamKind.file,
        url: url,
        key: 0,
        width: _int(version?['width']),
        height: _int(version?['height']),
      );
    }

    return files.values.toList();
  }

  /// DASH video and audio of a manifest
  static List<InstagramStreamDto> dashStreamsOf(String manifest) => [
    for (final match in _representationPattern.allMatches(manifest))
      ?_dashStreamOf(match.group(1)!, match.group(2)!),
  ];

  static InstagramStreamDto? _dashStreamOf(String attributes, String body) {
    final values = {
      for (final match in _attributePattern.allMatches(attributes))
        match.group(1)!: _unescape(match.group(2)!),
    };
    final url = _baseUrlPattern.firstMatch(body)?.group(1);
    final id = values['id'] ?? '';
    final codec = values['codecs'];
    final mimeType = values['mimeType'] ?? '';
    final isAudio =
        mimeType.startsWith('audio/') ||
        (mimeType.isEmpty && (codec?.startsWith('mp4a') ?? false));

    if (url == null || !(isAudio || mimeType.startsWith('video/'))) {
      return null;
    }

    return InstagramStreamDto(
      kind: isAudio ? InstagramStreamKind.audio : InstagramStreamKind.video,
      url: _unescape(url.trim()),
      key: int.tryParse(id.replaceAll(RegExp(r'\D'), '')) ?? id.hashCode.abs(),
      codec: codec,
      width: int.tryParse(values['width'] ?? ''),
      height: int.tryParse(values['height'] ?? ''),
      size: int.tryParse(values['FBContentLength'] ?? ''),
      bandwidth: int.tryParse(values['bandwidth'] ?? ''),
    );
  }

  static double? _durationOfManifest(String manifest) {
    final value = _presentationDurationPattern.firstMatch(manifest)?.group(1);
    final match = _isoDurationPattern.firstMatch(value ?? '');

    if (match == null) return null;

    double part(int group) => double.tryParse(match.group(group) ?? '') ?? 0;

    final seconds = part(1) * 3600 + part(2) * 60 + part(3);

    return seconds > 0 ? seconds : null;
  }

  static String _unescape(String value) => value
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&');

  static Map<dynamic, dynamic>? _map(Object? value) =>
      value is Map ? value : null;

  static List<Object?> _list(Object? value) => value is List ? value : const [];

  static num? _num(Object? value) => switch (value) {
    final num number when number > 0 => number,
    final String text => num.tryParse(text),
    _ => null,
  };

  static int? _int(Object? value) => _num(value)?.toInt();

  static Exception _exceptionOf(DioException error) {
    const codes = VideoErrorCodes();
    final status = error.response?.statusCode;

    return switch (error.type) {
      DioExceptionType.cancel => VideoException(codes.canceled),
      DioExceptionType.badResponse when status == 404 => VideoException(
        codes.instagramUnavailable,
      ),
      DioExceptionType.badResponse when status == 429 => VideoException(
        codes.instagramRateLimited,
      ),
      DioExceptionType.badResponse => VideoException(
        codes.instagramHttpStatus,
        args: {'status': '$status'},
      ),
      _ => VideoException(codes.instagramNoConnection),
    };
  }

  @override
  Future<InstagramStreamDto> probeFile(InstagramStreamDto file) async {
    int? length;
    var offset = 0;

    try {
      /// A few reads at most: boxes before `moov` are skipped by their size
      for (var reads = 0; reads < 4; reads++) {
        final chunk = await _read(file.url, offset, _probeBytes);

        if (chunk == null) break;

        length ??= chunk.length;

        switch (Mp4Probe.seek(
          chunk.bytes,
          chunkOffset: offset,
          fileLength: length,
        )) {
          case Mp4MoovAt(offset: final moovOffset, :final size)
              when size <= _maxMoovBytes:
            final start = moovOffset - offset;
            final moov = start + size <= chunk.bytes.length
                ? Uint8List.sublistView(chunk.bytes, start, start + size)
                : (await _read(file.url, moovOffset, size))?.bytes;
            final info = moov == null || moov.length < size
                ? null
                : Mp4Probe.videoOf(moov);

            return _withFileInfo(file, length: length, info: info);
          case Mp4ReadFrom(offset: final next) when next > offset:
            offset = next;
          default:
            return _withFileInfo(file, length: length);
        }
      }
    } on DioException {
      /// The download tells what is wrong with the file
    }

    return _withFileInfo(file, length: length);
  }

  static InstagramStreamDto _withFileInfo(
    InstagramStreamDto file, {
    int? length,
    Mp4VideoInfo? info,
  }) => InstagramStreamDto(
    kind: file.kind,
    url: file.url,
    key: length ?? file.key,
    codec: info?.codec ?? file.codec,
    width: info?.width ?? file.width,
    height: info?.height ?? file.height,
    size: length ?? file.size,
    bandwidth: file.bandwidth,
    duration: info?.duration ?? file.duration,
  );

  /// [count] bytes of [url] from [start] and the length of the whole file.
  /// `null` when the server does not give parts
  Future<({Uint8List bytes, int length})?> _read(
    String url,
    int start,
    int count,
  ) async {
    final response = await _dio.get<ResponseBody>(
      url,
      options: Options(
        responseType: ResponseType.stream,
        headers: {'Range': 'bytes=$start-${start + count - 1}'},
      ),
    );
    final body = response.data;
    final length = switch (response.statusCode) {
      206 => int.tryParse(
        response.headers.value('content-range')?.split('/').last ?? '',
      ),
      200 when start == 0 => int.tryParse(
        response.headers.value('content-length') ?? '',
      ),
      _ => null,
    };

    if (body == null || length == null) {
      await body?.stream.listen(null).cancel();

      return null;
    }

    final builder = BytesBuilder(copy: false);

    /// A server that ignores the range sends the whole file: the rest
    /// is not read
    await for (final bytes in body.stream) {
      builder.add(bytes);

      if (builder.length >= count) break;
    }

    final bytes = builder.takeBytes();

    return (
      bytes: bytes.length > count
          ? Uint8List.sublistView(bytes, 0, count)
          : bytes,
      length: length,
    );
  }

  @override
  Future<void> downloadStreams({
    required String downloadId,
    required String code,
    required List<InstagramStreamTarget> files,
    required String stateDirectory,
    required void Function(MediaStreamProgress progress) onProgress,
    DownloadCancellation? cancellation,
  }) async {
    const codes = VideoErrorCodes();

    if (cancellation?.isCancelled ?? false) {
      throw VideoException(codes.canceled);
    }

    final client = _apiProvider.instagram;
    final expected = files.every((file) => file.stream.size != null)
        ? files.fold<int>(0, (sum, file) => sum + file.stream.size!)
        : null;
    final download = await _filesDownloader.start(
      FilesDownloadRequest(
        id: downloadId,
        stateDirectory: stateDirectory,
        options: FilesDownloadOptions(
          sliceSize: YouTubeConstants.streamChunkSize,
          maxConnections: InstagramConstants.connections,
          connectTimeout: client.connectTimeout,
          idleTimeout: client.receiveTimeout,
          progressInterval: _progressInterval,
          headers: {
            for (final header in client.headers.entries)
              header.key: '${header.value}',
          },
        ),
        files: [
          for (final file in files)
            DownloadFileRequest(
              url: file.stream.url,
              savePath: file.path,
              expectedLength: file.stream.size,

              /// Links change with every page, the file stays the same
              fingerprint:
                  '${InstagramConstants.filePrefix}$code-${file.stream.key}',
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
              progress.totalBytes ?? expected ?? progress.downloadedBytes,
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
        throw mediaDownloadExceptionOf(
          error,
          source: VideoSourceModel.instagram,
        );
    }
  }
}
