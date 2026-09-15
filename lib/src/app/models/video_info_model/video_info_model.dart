import 'package:equatable/equatable.dart';

import '../quality_model/quality_model.dart';

class VideoInfoModel extends Equatable {
  final String id;
  final String title;

  /// Canonical link to the video page
  final String url;
  final List<QualityModel> qualities;
  final String? channel;

  /// Duration in seconds
  final num? duration;
  final String? thumbnail;
  final int? viewCount;

  const VideoInfoModel({
    required this.id,
    required this.title,
    required this.url,
    required this.qualities,
    this.channel,
    this.duration,
    this.thumbnail,
    this.viewCount,
  });

  @override
  List<Object?> get props => [
    id,
    title,
    url,
    qualities,
    channel,
    duration,
    thumbnail,
    viewCount,
  ];
}
