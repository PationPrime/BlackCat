import 'dart:async';
import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:peeky_cat/src/app/constants/constants.dart';
import 'package:peeky_cat/src/app/data_sources/data_sources.dart';
import 'package:peeky_cat/src/app/errors/errors.dart';
import 'package:peeky_cat/src/app/models/models.dart';
import 'package:peeky_cat/src/app/operation_result/operation_result.dart';
import 'package:peeky_cat/src/app/repositories/repositories.dart';
import 'package:peeky_cat/src/app/services/services.dart';
import 'package:peeky_cat/src/app/tools/tools.dart';

import '../../support/test_localization.dart';

const _ytDlpUrl =
    'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe';
const _ytDlpSumsUrl =
    'https://github.com/yt-dlp/yt-dlp/releases/latest/download/SHA2-256SUMS';
const _denoUrl =
    'https://github.com/denoland/deno/releases/latest/download/deno-x86_64-pc-windows-msvc.zip';
const _denoSumUrl = '$_denoUrl.sha256sum';

class _TestFileSystemService extends FileSystemServiceImpl {
  final Directory root;

  _TestFileSystemService(this.root);

  @override
  Future<String> localAppFolder(String name) async => p.join(root.path, name);
}

/// Programs "run" when their files are in the tools folder, unless broken
final class _ToolsYtDlpService implements YtDlpService {
  final String toolsFolder;

  /// yt-dlp or a runtime installed on the computer beforehand
  final DependencyToolModel? systemYtDlp;
  final DependencyToolModel? systemJsRuntime;

  /// Installed files do not start, e.g. blocked by an antivirus
  bool broken = false;

  _ToolsYtDlpService(
    this.toolsFolder, {
    this.systemYtDlp,
    this.systemJsRuntime,
  });

  @override
  bool get isSupported => true;

  Future<DependencyToolModel?> _bundled(String name, String version) async {
    final path = p.join(toolsFolder, '$name.exe');

    if (broken || !await File(path).exists()) return null;

    return DependencyToolModel(
      name: name,
      executable: path,
      version: version,
      isBundled: true,
    );
  }

  @override
  Future<YtDlpSetupModel> setup({bool refresh = false}) async =>
      YtDlpSetupModel(
        ytDlp: systemYtDlp ?? await _bundled('yt-dlp', '2026.08.19'),
        jsRuntime: systemJsRuntime ?? await _bundled('deno', 'deno 2.9.6'),
      );

  @override
  Future<YtDlpRunResult> run(
    List<String> arguments, {
    ValueChanged<String>? onLine,
    DownloadCancellation? cancellation,
  }) => throw UnimplementedError();
}

/// GitHub stand-in: serves files by link, in two blocks
final class _FakeRemote implements RemoteDependencyDataSource {
  final Map<String, List<int>> files;
  final requests = <String>[];

  /// Thrown instead of downloading
  DioException? downloadError;

  /// Downloads wait for it: lets the test stop the installation midway
  Completer<void>? downloadGate;

  _FakeRemote(this.files);

  @override
  Future<String> fetchText(String url, {CancelToken? cancelToken}) async {
    requests.add(url);

    return utf8.decode(files[url] ?? (throw _notFound(url)));
  }

  @override
  Future<void> downloadFile(
    String url, {
    required String path,
    required void Function(int receivedBytes, int? totalBytes) onProgress,
    CancelToken? cancelToken,
  }) async {
    requests.add(url);

    if (downloadError case final error?) throw error;

    final bytes = files[url] ?? (throw _notFound(url));
    final half = bytes.length ~/ 2;

    await File(path).parent.create(recursive: true);

    await File(path).writeAsBytes(bytes.sublist(0, half));
    onProgress(half, bytes.length);

    if (downloadGate case final gate?) {
      await Future.any([
        gate.future,
        if (cancelToken != null) cancelToken.whenCancel,
      ]);
    }

    if (cancelToken?.isCancelled ?? false) {
      await File(path).delete();

      throw DioException.requestCancelled(
        requestOptions: RequestOptions(path: url),
        reason: 'stopped',
      );
    }

    await File(path).writeAsBytes(bytes, mode: FileMode.write);
    onProgress(bytes.length, bytes.length);
  }

  static DioException _notFound(String url) => DioException.badResponse(
    statusCode: 404,
    requestOptions: RequestOptions(path: url),
    response: Response(
      requestOptions: RequestOptions(path: url),
      statusCode: 404,
    ),
  );
}

String _sha(List<int> bytes) => '${sha256.convert(bytes)}';

void main() {
  late Directory root;
  late String tools;
  late _FakeRemote remote;

  final ytDlpBytes = utf8.encode('MZ fake yt-dlp ${'x' * 4096}');
  final denoBytes = utf8.encode('MZ fake deno ${'y' * 8192}');
  final denoZip = ZipEncoder().encodeBytes(
    Archive()..addFile(ArchiveFile.bytes('deno.exe', denoBytes)),
  );

  setUpAll(loadTestTranslations);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('dependencies-repository');
    tools = p.join(root.path, StorageConstants.toolsFolder);
    remote = _FakeRemote({
      _ytDlpSumsUrl: utf8.encode(
        '${_sha(ytDlpBytes)}  yt-dlp.exe\n${'0' * 64}  yt-dlp_macos\n',
      ),
      _ytDlpUrl: ytDlpBytes,
      _denoSumUrl: utf8.encode(
        '\r\nAlgorithm : SHA256\r\nHash      : ${_sha(denoZip).toUpperCase()}\r\n'
        'Path      : C:\\a\\deno\\deno-x86_64-pc-windows-msvc.zip\r\n',
      ),
      _denoUrl: denoZip,
    });
  });

  tearDown(() => root.delete(recursive: true));

  DependenciesRepository repository(
    _ToolsYtDlpService ytDlpService, {
    Abi abi = Abi.windowsX64,
  }) => DependenciesRepository(
    ytDlpService: ytDlpService,
    remoteDependencyDataSource: remote,
    fileSystemService: _TestFileSystemService(root),
    abi: abi,
  );

  List<String> leftovers() => Directory(tools).existsSync()
      ? [
          for (final entity in Directory(tools).listSync())
            p.basename(entity.path),
        ]
      : const [];

  test(
    'ставит yt-dlp и Deno из релизов GitHub, сверяя контрольные суммы',
    () async {
      final progress = <DependencyInstallProgressModel>[];
      final result = await repository(
        _ToolsYtDlpService(tools),
      ).installMissing(onProgress: progress.add);

      expect(result.failure, isNull, reason: result.failure?.message);
      expect(result.requireData.isReady, isTrue);
      expect(result.requireData.ytDlp?.isBundled, isTrue);
      expect(await File(p.join(tools, 'yt-dlp.exe')).readAsBytes(), ytDlpBytes);
      expect(await File(p.join(tools, 'deno.exe')).readAsBytes(), denoBytes);
      expect(leftovers()..sort(), ['deno.exe', 'yt-dlp.exe']);
      expect(remote.requests, [
        _ytDlpSumsUrl,
        _ytDlpUrl,
        _denoSumUrl,
        _denoUrl,
      ]);

      expect(
        [for (final step in progress) (step.kind, step.stage)],
        [
          (DependencyKind.ytDlp, DependencyInstallStage.downloading),
          (DependencyKind.ytDlp, DependencyInstallStage.downloading),
          (DependencyKind.ytDlp, DependencyInstallStage.downloading),
          (DependencyKind.ytDlp, DependencyInstallStage.verifying),
          (DependencyKind.ytDlp, DependencyInstallStage.done),
          (DependencyKind.jsRuntime, DependencyInstallStage.downloading),
          (DependencyKind.jsRuntime, DependencyInstallStage.downloading),
          (DependencyKind.jsRuntime, DependencyInstallStage.downloading),
          (DependencyKind.jsRuntime, DependencyInstallStage.verifying),
          (DependencyKind.jsRuntime, DependencyInstallStage.extracting),
          (DependencyKind.jsRuntime, DependencyInstallStage.done),
        ],
      );
      expect(progress[2].fraction, 1);
    },
  );

  test('ставится только недостающее: Node.js уже есть', () async {
    const node = DependencyToolModel(
      name: 'node',
      executable: 'node',
      version: 'v24.12.0',
    );
    final result = await repository(
      _ToolsYtDlpService(tools, systemJsRuntime: node),
    ).installMissing(onProgress: (_) {});

    expect(result.requireData.jsRuntime, node);
    expect(remote.requests, [_ytDlpSumsUrl, _ytDlpUrl]);
    expect(leftovers(), ['yt-dlp.exe']);
  });

  test('всё уже установлено: ничего не скачивается', () async {
    const ytDlp = DependencyToolModel(
      name: 'yt-dlp',
      executable: 'python',
      version: '2026.08.19',
    );
    const node = DependencyToolModel(
      name: 'node',
      executable: 'node',
      version: 'v24.12.0',
    );
    final result = await repository(
      _ToolsYtDlpService(tools, systemYtDlp: ytDlp, systemJsRuntime: node),
    ).installMissing(onProgress: (_) {});

    expect(
      result.requireData,
      const YtDlpSetupModel(ytDlp: ytDlp, jsRuntime: node),
    );
    expect(remote.requests, isEmpty);
  });

  test(
    'несовпавшая контрольная сумма останавливает установку и удаляет файл',
    () async {
      remote.files[_ytDlpUrl] = utf8.encode('tampered');

      final result = await repository(
        _ToolsYtDlpService(tools),
      ).installMissing(onProgress: (_) {});

      expect(
        result.failure?.code,
        const DependencyErrorCodes().checksumMismatch,
      );
      expect(result.failure?.message, contains('yt-dlp'));
      expect(leftovers(), isEmpty);
      expect(remote.requests, isNot(contains(_denoUrl)));
    },
  );

  test(
    'файла нет в списке контрольных сумм — установка не начинается',
    () async {
      remote.files[_ytDlpSumsUrl] = utf8.encode('${'0' * 64}  yt-dlp_macos\n');

      final result = await repository(
        _ToolsYtDlpService(tools),
      ).installMissing(onProgress: (_) {});

      expect(
        result.failure?.code,
        const DependencyErrorCodes().checksumMissing,
      );
      expect(remote.requests, [_ytDlpSumsUrl]);
    },
  );

  test('нет сети: причина называет программу и GitHub', () async {
    remote.downloadError = DioException.connectionError(
      requestOptions: RequestOptions(path: _ytDlpUrl),
      reason: 'offline',
    );

    final result = await repository(
      _ToolsYtDlpService(tools),
    ).installMissing(onProgress: (_) {});

    expect(result.failure?.code, const DependencyErrorCodes().download);
    expect(
      result.failure?.message,
      'Не удалось скачать yt-dlp: нет соединения с GitHub.',
    );
  });

  test('остановка во время скачивания удаляет недокачанный файл', () async {
    final cancellation = DownloadCancellation();

    remote.downloadGate = Completer<void>();

    final pending = repository(_ToolsYtDlpService(tools)).installMissing(
      cancellation: cancellation,
      onProgress: (progress) {
        if ((progress.receivedBytes) > 0) cancellation.cancel();
      },
    );
    final result = await pending;

    expect(result.failure?.code, const DependencyErrorCodes().canceled);
    expect(result.failure?.message, 'Установка отменена.');
    expect(leftovers(), isEmpty);
  });

  test(
    'архив без программы и неработающая программа — понятные ошибки',
    () async {
      remote.files[_denoUrl] = ZipEncoder().encodeBytes(
        Archive()..addFile(ArchiveFile.string('README.md', 'deno')),
      );
      remote.files[_denoSumUrl] = utf8.encode(
        '${_sha(remote.files[_denoUrl]!)}  deno-x86_64-pc-windows-msvc.zip\n',
      );

      final extractResult = await repository(
        _ToolsYtDlpService(tools),
      ).installMissing(onProgress: (_) {});

      expect(extractResult.failure?.code, const DependencyErrorCodes().extract);
      expect(leftovers(), ['yt-dlp.exe']);

      remote.files[_denoUrl] = denoZip;
      remote.files[_denoSumUrl] = utf8.encode(
        '${_sha(denoZip)}  deno-x86_64-pc-windows-msvc.zip\n',
      );

      final brokenService = _ToolsYtDlpService(tools)..broken = true;
      final brokenResult = await repository(
        brokenService,
      ).installMissing(onProgress: (_) {});

      expect(
        brokenResult.failure?.code,
        const DependencyErrorCodes().notWorking,
      );
      expect(brokenResult.failure?.message, contains('yt-dlp'));
    },
  );

  test('для системы без готовых сборок установка недоступна', () async {
    final result = await repository(
      _ToolsYtDlpService(tools),
      abi: Abi.androidArm64,
    ).installMissing(onProgress: (_) {});

    expect(
      result.failure?.code,
      const DependencyErrorCodes().unsupportedPlatform,
    );
    expect(remote.requests, isEmpty);
  });
}
