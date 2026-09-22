import 'package:equatable/equatable.dart';

/// Version of the running app build, as `pubspec.yaml` gave it:
/// `0.2.0+1` is version `0.2.0`, build `1`
class AppVersionModel extends Equatable {
  /// `0.2.0`
  final String version;

  /// `1`. Empty when the build has no number
  final String buildNumber;

  const AppVersionModel({required this.version, this.buildNumber = ''});

  bool get hasBuildNumber => buildNumber.isNotEmpty;

  @override
  List<Object?> get props => [version, buildNumber];
}
