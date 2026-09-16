import 'package:equatable/equatable.dart';

enum DonationPlatformKind { donationAlerts, donatePay, boosty }

/// A service to support the developer through
class DonationPlatformModel extends Equatable {
  final DonationPlatformKind kind;
  final String title;
  final String url;

  /// Service logo in the app assets
  final String logoAsset;

  const DonationPlatformModel({
    required this.kind,
    required this.title,
    required this.url,
    required this.logoAsset,
  });

  /// The link without the scheme and `www.`, for a caption
  String get displayUrl => url.replaceFirst(RegExp(r'^https?://(www\.)?'), '');

  @override
  List<Object?> get props => [kind, title, url, logoAsset];
}
