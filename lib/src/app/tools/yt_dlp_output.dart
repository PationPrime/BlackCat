import 'dart:convert';

import '../errors/errors.dart';
import '../models/models.dart';

/// yt-dlp output: progress lines of downloads and error messages
abstract final class YtDlpOutput {
  static const _progressPrefix = '[progress]';

  /// `--progress-template` value: fields separated by spaces, `NA` when unknown
  static const progressTemplate =
      'download:$_progressPrefix %(progress.status)s '
      '%(progress.downloaded_bytes)s %(progress.total_bytes)s '
      '%(progress.total_bytes_estimate)s %(progress.speed)s %(progress.eta)s';

  static final _progressPattern = RegExp(
    r'^\[progress\] (\w+) (\S+) (\S+) (\S+) (\S+) (\S+)$',
  );

  static final _errorPrefixPattern = RegExp(
    r'^ERROR:\s*(?:\[[^\]]+\]\s*(?:[\w-]+:\s*)?)?',
  );

  /// `null` for lines that are not progress lines
  static YtDlpProgressModel? parseProgress(String line) {
    final match = _progressPattern.firstMatch(line.trim());

    if (match == null) return null;

    num? number(int group) => switch (match.group(group)) {
      'NA' || 'None' || null => null,
      final value => num.tryParse(value),
    };

    return YtDlpProgressModel(
      status: match.group(1)!,
      downloadedBytes: number(2)?.toInt(),
      totalBytes: (number(3) ?? number(4))?.toInt(),
      speed: number(5),
      eta: number(6),
    );
  }

  /// Domain exception for a failed yt-dlp run by its error output
  static VideoException toException(String output) {
    const codes = VideoErrorCodes();

    final known = <(RegExp, String, bool)>[
      (RegExp(r'confirm you.?re not a bot', caseSensitive: false), codes.botCheck, true),
      (RegExp(r'confirm your age|age.restricted|inappropriate for some users', caseSensitive: false), codes.ageRestricted, true),
      (RegExp(r'members.only|Join this channel', caseSensitive: false), codes.membersOnly, true),
      (RegExp(r'Private video', caseSensitive: false), codes.privateVideo, false),
      (RegExp(r'Requested format is not available', caseSensitive: false), codes.qualityUnavailable, false),
      (RegExp(r'Video unavailable|This video is( no longer)? (unavailable|available)', caseSensitive: false), codes.videoUnavailable, false),
    ];

    for (final (pattern, code, needsSignIn) in known) {
      if (pattern.hasMatch(output)) {
        return VideoException(code, needsSignIn: needsSignIn);
      }
    }

    final lastError = const LineSplitter()
        .convert(output)
        .lastWhere((line) => line.startsWith('ERROR:'), orElse: () => '')
        .replaceFirst(_errorPrefixPattern, '')
        .trim();

    return VideoException(
      codes.ytDlpFailed,
      args: {
        'error': lastError.isEmpty ? _lastLine(output) : _firstSentence(lastError),
      },
    );
  }

  /// yt-dlp appends long hints with links after the reason
  static String _firstSentence(String text) {
    final end = text.indexOf('. ');

    return end < 0 ? text : text.substring(0, end + 1);
  }

  static String _lastLine(String output) {
    final lines = const LineSplitter()
        .convert(output)
        .where((line) => line.trim().isNotEmpty);

    return lines.isEmpty ? '' : lines.last.trim();
  }
}
