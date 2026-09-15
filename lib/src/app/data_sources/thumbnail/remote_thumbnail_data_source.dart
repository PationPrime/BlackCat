import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../api/api.dart';

/// Video thumbnails from i.ytimg.com
abstract interface class RemoteThumbnailDataSource {
  /// Image bytes of the thumbnail at [url]
  Future<Uint8List> getThumbnail(String url);
}

final class RemoteThumbnailDataSourceImpl implements RemoteThumbnailDataSource {
  final ApiProvider _apiProvider;

  const RemoteThumbnailDataSourceImpl({required this._apiProvider});

  @override
  Future<Uint8List> getThumbnail(String url) async {
    final response = await _apiProvider.youtube.dio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );

    return Uint8List.fromList(response.data ?? const []);
  }
}
