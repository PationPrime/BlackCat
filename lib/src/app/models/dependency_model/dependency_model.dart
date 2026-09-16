import 'package:equatable/equatable.dart';

part 'dependency_install_progress_model.dart';

/// Program the yt-dlp engine needs
enum DependencyKind {
  ytDlp,

  /// Deno when the app installs it; Node.js or Bun if already installed
  jsRuntime,
}

/// A found program and how to start it
class DependencyToolModel extends Equatable {
  /// `yt-dlp`, `deno`, `node` or `bun`
  final String name;

  /// Command in `PATH` or a full path
  final String executable;

  /// `-m yt_dlp` when yt-dlp runs as a Python module
  final List<String> prefixArguments;

  final String version;

  /// Installed by the app into its own folder
  final bool isBundled;

  const DependencyToolModel({
    required this.name,
    required this.executable,
    required this.version,
    this.prefixArguments = const [],
    this.isBundled = false,
  });

  @override
  List<Object?> get props => [
    name,
    executable,
    prefixArguments,
    version,
    isBundled,
  ];
}
