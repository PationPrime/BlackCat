part of 'yt_dlp_service.dart';

/// Finished yt-dlp run
final class YtDlpRunResult {
  final int exitCode;
  final String stdout;
  final String stderr;

  /// The run was stopped via its cancellation
  final bool isCancelled;

  const YtDlpRunResult({
    required this.exitCode,
    this.stdout = '',
    this.stderr = '',
    this.isCancelled = false,
  });

  bool get isSuccess => exitCode == 0 && !isCancelled;

  /// yt-dlp writes errors to stderr, but some wrappers mix the streams
  String get errorOutput => stderr.trim().isEmpty ? stdout : stderr;
}
