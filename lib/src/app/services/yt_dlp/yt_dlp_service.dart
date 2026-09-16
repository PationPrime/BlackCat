import 'dart:async';
import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../constants/constants.dart';
import '../../errors/errors.dart';
import '../../models/models.dart';
import '../../tools/tools.dart';
import '../file_system/file_system_service.dart';

part 'yt_dlp_run_result.dart';

/// yt-dlp run as a separate process, with a JavaScript runtime for YouTube.
///
/// Desktop platforms only. yt-dlp is looked up in `YTDLP_PATH`, then among
/// the programs the app installed, then as the `yt-dlp` program and as
/// the `yt_dlp` Python module
abstract interface class YtDlpService {
  bool get isSupported;

  /// What is installed. The result is kept until [refresh]: the app
  /// installs programs while it runs
  Future<YtDlpSetupModel> setup({bool refresh = false});

  /// Runs yt-dlp with [arguments]. Every output line goes to [onLine].
  /// Stopping via [cancellation] ends yt-dlp together with its child
  /// processes. Throws [VideoException] when yt-dlp or the JavaScript
  /// runtime is missing
  Future<YtDlpRunResult> run(
    List<String> arguments, {
    ValueChanged<String>? onLine,
    DownloadCancellation? cancellation,
  });
}

typedef _ToolCandidate = ({
  String name,
  String executable,
  List<String> prefixArguments,
  bool isBundled,
  List<int>? minVersion,
});

final class YtDlpServiceImpl implements YtDlpService {
  static const _pathVariable = 'YTDLP_PATH';

  /// `1`: ignore programs installed on the computer and use only the ones
  /// the app installed. Lets the installer be tried on a computer that
  /// already has yt-dlp
  static const bundledOnlyVariable = 'YT_DOWNLOAD_BUNDLED_TOOLS_ONLY';

  /// Python writes in the console code page otherwise: titles would break
  static const _processEnvironment = {
    'PYTHONIOENCODING': 'utf-8',
    'PYTHONUTF8': '1',
  };

  final FileSystemService _fileSystemService;
  final Map<String, String> _environment;

  Future<YtDlpSetupModel>? _setup;

  YtDlpServiceImpl({
    required this._fileSystemService,
    Map<String, String>? environment,
  }) : _environment = environment ?? Platform.environment;

  @override
  bool get isSupported =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  @override
  Future<YtDlpSetupModel> setup({bool refresh = false}) {
    if (!isSupported) {
      return Future.value(const YtDlpSetupModel());
    }

    if (refresh) {
      _setup = null;
    }

    return _setup ??= _detect().catchError((Object error) {
      _setup = null;

      throw error;
    });
  }

  bool get _bundledOnly => _environment[bundledOnlyVariable] == '1';

  Future<YtDlpSetupModel> _detect() async {
    final toolsFolder = await _fileSystemService.localAppFolder(
      StorageConstants.toolsFolder,
    );

    final (ytDlp, jsRuntime) = await (
      _firstWorking(_ytDlpCandidates(toolsFolder)),
      _firstWorking(_jsRuntimeCandidates(toolsFolder)),
    ).wait;

    return YtDlpSetupModel(ytDlp: ytDlp, jsRuntime: jsRuntime);
  }

  List<_ToolCandidate> _ytDlpCandidates(String toolsFolder) {
    final explicit = _environment[_pathVariable]?.trim();

    if (explicit != null && explicit.isNotEmpty) {
      return [_tool('yt-dlp', explicit)];
    }

    return [
      _tool('yt-dlp', _bundledPath(toolsFolder, 'yt-dlp'), isBundled: true),
      if (!_bundledOnly) ...[
        _tool('yt-dlp', 'yt-dlp'),

        /// `py` is the Python launcher of Windows; `python3` is the usual
        /// name elsewhere
        for (final python
            in Platform.isWindows
                ? const ['python', 'py']
                : const ['python3', 'python'])
          _tool('yt-dlp', python, prefixArguments: const ['-m', 'yt_dlp']),
      ],
    ];
  }

  /// yt-dlp prefers Deno; Node.js and Bun work when they are new enough
  List<_ToolCandidate> _jsRuntimeCandidates(String toolsFolder) => [
    _tool(
      'deno',
      _bundledPath(toolsFolder, 'deno'),
      isBundled: true,
      minVersion: DependencyConstants.minDenoVersion,
    ),
    if (!_bundledOnly) ...[
      _tool('deno', 'deno', minVersion: DependencyConstants.minDenoVersion),
      _tool('node', 'node', minVersion: DependencyConstants.minNodeVersion),
      _tool('bun', 'bun', minVersion: DependencyConstants.minBunVersion),
    ],
  ];

  static String _bundledPath(String toolsFolder, String name) => p.join(
    toolsFolder,
    DependencyAssets.executableName(name, abi: Abi.current()),
  );

  static _ToolCandidate _tool(
    String name,
    String executable, {
    List<String> prefixArguments = const [],
    bool isBundled = false,
    List<int>? minVersion,
  }) => (
    name: name,
    executable: executable,
    prefixArguments: prefixArguments,
    isBundled: isBundled,
    minVersion: minVersion,
  );

  Future<DependencyToolModel?> _firstWorking(
    List<_ToolCandidate> candidates,
  ) async {
    for (final candidate in candidates) {
      /// A missing file is skipped without starting a process
      if (candidate.isBundled && !await File(candidate.executable).exists()) {
        continue;
      }

      final version = await _versionOf(candidate.executable, [
        ...candidate.prefixArguments,
        '--version',
      ]);

      if (version == null) continue;

      if (candidate.minVersion case final minimum?) {
        final parsed = DependencyAssets.parseVersion(version);

        if (parsed == null || !DependencyAssets.isAtLeast(parsed, minimum)) {
          continue;
        }
      }

      return DependencyToolModel(
        name: candidate.name,
        executable: candidate.executable,
        prefixArguments: candidate.prefixArguments,
        version: version,
        isBundled: candidate.isBundled,
      );
    }

    return null;
  }

  /// First output line of a successful run; `null` if the program
  /// is missing or fails
  Future<String?> _versionOf(String executable, List<String> arguments) async {
    try {
      final result = await Process.run(
        executable,
        arguments,
        environment: _processEnvironment,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );

      final output = '${result.stdout}'.trim();

      return result.exitCode == 0 && output.isNotEmpty
          ? const LineSplitter().convert(output).first.trim()
          : null;
    } on ProcessException {
      return null;
    }
  }

  /// yt-dlp enables only Deno from `PATH` on its own: other runtimes and
  /// the app's Deno are named together with their path
  static List<String> _jsRuntimeArguments(DependencyToolModel runtime) {
    if (runtime.name == 'deno' && !runtime.isBundled) {
      return const [];
    }

    return [
      '--js-runtimes',
      runtime.isBundled
          ? '${runtime.name}:${runtime.executable}'
          : runtime.name,
    ];
  }

  @override
  Future<YtDlpRunResult> run(
    List<String> arguments, {
    ValueChanged<String>? onLine,
    DownloadCancellation? cancellation,
  }) async {
    final setup = await this.setup();

    if (!setup.isReady) {
      throw VideoException(const VideoErrorCodes().ytDlpNotFound);
    }

    if (cancellation?.isCancelled ?? false) {
      return const YtDlpRunResult(exitCode: -1, isCancelled: true);
    }

    final ytDlp = setup.ytDlp!;

    final process = await Process.start(ytDlp.executable, [
      ...ytDlp.prefixArguments,
      '--no-colors',
      ..._jsRuntimeArguments(setup.jsRuntime!),
      ...arguments,
    ], environment: _processEnvironment);

    var isCancelled = false;

    unawaited(
      cancellation?.whenCancelled.then((_) async {
        isCancelled = true;

        await _kill(process);
      }),
    );

    Future<String> collect(Stream<List<int>> stream) async {
      final buffer = StringBuffer();

      await stream
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .forEach((line) {
            buffer.writeln(line);
            onLine?.call(line);
          });

      return buffer.toString();
    }

    final stdout = collect(process.stdout);
    final stderr = collect(process.stderr);
    final exitCode = await process.exitCode;

    return YtDlpRunResult(
      exitCode: exitCode,
      stdout: await stdout,
      stderr: await stderr,
      isCancelled: isCancelled,
    );
  }

  /// A standalone `yt-dlp.exe` and the `py` launcher start yt-dlp as a child
  /// process: on Windows the whole process tree is ended
  Future<void> _kill(Process process) async {
    if (Platform.isWindows) {
      try {
        await Process.run('taskkill', ['/PID', '${process.pid}', '/T', '/F']);

        return;
      } on ProcessException {
        /// No taskkill: end at least the process itself
      }
    }

    process.kill();
  }
}
