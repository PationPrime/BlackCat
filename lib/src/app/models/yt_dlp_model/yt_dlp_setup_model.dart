import 'package:equatable/equatable.dart';

import '../dependency_model/dependency_model.dart';

part 'yt_dlp_progress_model.dart';

/// yt-dlp and the JavaScript runtime found on the computer.
/// yt-dlp downloads from YouTube only when both are present
class YtDlpSetupModel extends Equatable {
  /// `null` if yt-dlp is not found
  final DependencyToolModel? ytDlp;

  /// Deno, Node.js or Bun for YouTube checks; `null` if none is found
  final DependencyToolModel? jsRuntime;

  const YtDlpSetupModel({this.ytDlp, this.jsRuntime});

  bool get isReady => ytDlp != null && jsRuntime != null;

  /// What the app has to install
  List<DependencyKind> get missing => [
    if (ytDlp == null) DependencyKind.ytDlp,
    if (jsRuntime == null) DependencyKind.jsRuntime,
  ];

  @override
  List<Object?> get props => [ytDlp, jsRuntime];
}
