import 'package:equatable/equatable.dart';

/// Folder where finished files are saved
class DownloadDirectoryModel extends Equatable {
  final String path;

  /// The system Downloads folder: the user has not chosen their own
  final bool isDefault;

  const DownloadDirectoryModel({required this.path, required this.isDefault});

  @override
  List<Object?> get props => [path, isDefault];
}
