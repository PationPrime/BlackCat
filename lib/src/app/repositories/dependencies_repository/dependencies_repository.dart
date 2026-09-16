import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:path/path.dart' as p;

import '../../constants/constants.dart';
import '../../data_sources/data_sources.dart';
import '../../errors/errors.dart';
import '../../localization/lang/locale_keys.g.dart';
import '../../models/models.dart';
import '../../operation_result/operation_result.dart';
import '../../services/services.dart';
import '../../tools/tools.dart';
import 'dependencies_repository_interface.dart';

typedef _ProgressCallback =
    void Function(DependencyInstallProgressModel progress);

/// Installs yt-dlp and Deno the way their authors publish them: standalone
/// builds from the latest GitHub release, checked against the SHA-256 listed
/// in the same release. The programs go to the app folder, so neither
/// Python nor administrator rights are needed
final class DependenciesRepository implements DependenciesRepositoryInterface {
  static const _ytDlpName = 'yt-dlp';
  static const _denoName = 'Deno';

  /// A file being downloaded or unpacked: the program name appears only
  /// once the file is complete and checked
  static const _partialSuffix = '.download';

  /// Download progress is reported no more often: the dialog does not
  /// need every network block
  static const _progressInterval = Duration(milliseconds: 100);

  static const _codes = DependencyErrorCodes();

  final YtDlpService _ytDlpService;
  final RemoteDependencyDataSource _remoteDependencyDataSource;
  final FileSystemService _fileSystemService;
  final Abi _abi;

  DependenciesRepository({
    required this._ytDlpService,
    required this._remoteDependencyDataSource,
    required this._fileSystemService,
    Abi? abi,
  }) : _abi = abi ?? Abi.current();

  @override
  ErrorHandler<DependencyErrorCodes> get errorHandler =>
      const DependencyErrorHandler();

  @override
  bool get isSupported => _ytDlpService.isSupported;

  @override
  Future<OperationResult<YtDlpSetupModel>> getSetup({
    bool refresh = false,
  }) async {
    try {
      return ok(await _ytDlpService.setup(refresh: refresh));
    } catch (error, stackTrace) {
      return fail(errorHandler.handleError(error, stackTrace: stackTrace));
    }
  }

  @override
  Future<OperationResult<YtDlpSetupModel>> installMissing({
    required void Function(DependencyInstallProgressModel progress) onProgress,
    DownloadCancellation? cancellation,
  }) async {
    try {
      if (!isSupported) {
        throw DependencyException(_codes.unsupportedPlatform);
      }

      final setup = await _ytDlpService.setup(refresh: true);

      if (setup.isReady) {
        return ok(setup);
      }

      final toolsFolder = await _fileSystemService.localAppFolder(
        StorageConstants.toolsFolder,
      );

      for (final kind in setup.missing) {
        _throwIfCancelled(cancellation);

        switch (kind) {
          case DependencyKind.ytDlp:
            await _installYtDlp(toolsFolder, onProgress, cancellation);
          case DependencyKind.jsRuntime:
            await _installDeno(toolsFolder, onProgress, cancellation);
        }
      }

      final installed = await _ytDlpService.setup(refresh: true);

      if (installed.ytDlp == null) {
        throw DependencyException(_codes.notWorking, name: _ytDlpName);
      }

      if (installed.jsRuntime == null) {
        throw DependencyException(_codes.notWorking, name: _denoName);
      }

      return ok(installed);
    } catch (error, stackTrace) {
      return fail(errorHandler.handleError(error, stackTrace: stackTrace));
    }
  }

  Future<void> _installYtDlp(
    String toolsFolder,
    _ProgressCallback onProgress,
    DownloadCancellation? cancellation,
  ) async {
    const kind = DependencyKind.ytDlp;
    final asset =
        DependencyAssets.ytDlpAsset(_abi) ??
        (throw DependencyException(_codes.unsupportedPlatform));
    final target = p.join(
      toolsFolder,
      DependencyAssets.executableName('yt-dlp', abi: _abi),
    );
    final partial = '$target$_partialSuffix';

    onProgress(
      const DependencyInstallProgressModel(
        kind: kind,
        stage: DependencyInstallStage.downloading,
      ),
    );

    final checksums = await _network(
      _ytDlpName,
      cancellation,
      () => _remoteDependencyDataSource.fetchText(
        DependencyAssets.ytDlpChecksumsUrl,
        cancelToken: cancellation?.cancelToken,
      ),
    );

    await _downloadVerified(
      kind,
      _ytDlpName,
      url: DependencyAssets.ytDlpUrl(asset),
      path: partial,
      sha256:
          DependencyAssets.sha256Of(checksums, asset) ??
          (throw DependencyException(_codes.checksumMissing, name: _ytDlpName)),
      onProgress: onProgress,
      cancellation: cancellation,
    );

    await _saveProgram(_ytDlpName, from: partial, to: target);

    onProgress(
      const DependencyInstallProgressModel(
        kind: kind,
        stage: DependencyInstallStage.done,
      ),
    );
  }

  Future<void> _installDeno(
    String toolsFolder,
    _ProgressCallback onProgress,
    DownloadCancellation? cancellation,
  ) async {
    const kind = DependencyKind.jsRuntime;
    final asset =
        DependencyAssets.denoAsset(_abi) ??
        (throw DependencyException(_codes.unsupportedPlatform));
    final programName = DependencyAssets.executableName('deno', abi: _abi);
    final target = p.join(toolsFolder, programName);
    final archive = p.join(toolsFolder, '$asset$_partialSuffix');
    final partial = '$target$_partialSuffix';

    onProgress(
      const DependencyInstallProgressModel(
        kind: kind,
        stage: DependencyInstallStage.downloading,
      ),
    );

    final checksum = await _network(
      _denoName,
      cancellation,
      () => _remoteDependencyDataSource.fetchText(
        DependencyAssets.denoChecksumUrl(asset),
        cancelToken: cancellation?.cancelToken,
      ),
    );

    try {
      await _downloadVerified(
        kind,
        _denoName,
        url: DependencyAssets.denoUrl(asset),
        path: archive,
        sha256:
            DependencyAssets.sha256Of(checksum, asset) ??
            (throw DependencyException(
              _codes.checksumMissing,
              name: _denoName,
            )),
        onProgress: onProgress,
        cancellation: cancellation,
      );

      _throwIfCancelled(cancellation);

      onProgress(
        const DependencyInstallProgressModel(
          kind: kind,
          stage: DependencyInstallStage.extracting,
        ),
      );

      final bool extracted;

      try {
        extracted = await _fileSystemService.extractFromZip(
          archive,
          entryName: programName,
          destination: partial,
        );
      } catch (error) {
        await _fileSystemService.deleteFile(partial);

        throw DependencyException(
          _codes.extract,
          name: _denoName,
          cause: _describe(error),
        );
      }

      if (!extracted) {
        throw DependencyException(
          _codes.extract,
          name: _denoName,
          cause: programName,
        );
      }
    } finally {
      await _fileSystemService.deleteFile(archive);
    }

    await _saveProgram(_denoName, from: partial, to: target);

    onProgress(
      const DependencyInstallProgressModel(
        kind: kind,
        stage: DependencyInstallStage.done,
      ),
    );
  }

  /// Downloads [url] into [path] and deletes the file unless its SHA-256
  /// is [sha256]
  Future<void> _downloadVerified(
    DependencyKind kind,
    String name, {
    required String url,
    required String path,
    required String sha256,
    required _ProgressCallback onProgress,
    DownloadCancellation? cancellation,
  }) async {
    var lastReport = DateTime.fromMillisecondsSinceEpoch(0);

    await _fileSystemService.deleteFile(path);

    await _network(
      name,
      cancellation,
      () => _remoteDependencyDataSource.downloadFile(
        url,
        path: path,
        cancelToken: cancellation?.cancelToken,
        onProgress: (receivedBytes, totalBytes) {
          final now = DateTime.now();

          if (receivedBytes != totalBytes &&
              now.difference(lastReport) < _progressInterval) {
            return;
          }

          lastReport = now;
          onProgress(
            DependencyInstallProgressModel(
              kind: kind,
              stage: DependencyInstallStage.downloading,
              receivedBytes: receivedBytes,
              totalBytes: totalBytes,
            ),
          );
        },
      ),
    );

    _throwIfCancelled(cancellation);

    onProgress(
      DependencyInstallProgressModel(
        kind: kind,
        stage: DependencyInstallStage.verifying,
      ),
    );

    if (await _fileSystemService.sha256OfFile(path) != sha256) {
      await _fileSystemService.deleteFile(path);

      throw DependencyException(_codes.checksumMismatch, name: name);
    }
  }

  /// Gives the checked file the program name and allows running it
  Future<void> _saveProgram(
    String name, {
    required String from,
    required String to,
  }) async {
    try {
      await _fileSystemService.renameFile(from, to);
      await _fileSystemService.makeExecutable(to);
    } catch (error) {
      await _fileSystemService.deleteFile(from);

      throw DependencyException(
        _codes.save,
        name: name,
        cause: _describe(error),
      );
    }
  }

  /// Network and disk errors of a download name the program they happened
  /// with; a stop turns into [DependencyErrorCodes.canceled]
  Future<T> _network<T>(
    String name,
    DownloadCancellation? cancellation,
    Future<T> Function() request,
  ) async {
    try {
      return await request();
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel ||
          (cancellation?.isCancelled ?? false)) {
        throw DependencyException(_codes.canceled);
      }

      if (error.error case final FileSystemException fileError) {
        throw DependencyException(
          _codes.save,
          name: name,
          cause: _describe(fileError),
        );
      }

      throw DependencyException(
        _codes.download,
        name: name,
        cause: _describeNetwork(error),
      );
    } on FileSystemException catch (error) {
      throw DependencyException(
        _codes.save,
        name: name,
        cause: _describe(error),
      );
    }
  }

  static void _throwIfCancelled(DownloadCancellation? cancellation) {
    if (cancellation?.isCancelled ?? false) {
      throw DependencyException(_codes.canceled);
    }
  }

  static String _describeNetwork(DioException error) => switch (error.type) {
    DioExceptionType.connectionError =>
      LocaleKeys.app_errors_dependencies_network_no_connection.tr(),
    DioExceptionType.connectionTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.sendTimeout =>
      LocaleKeys.app_errors_dependencies_network_timeout.tr(),
    _ when error.response?.statusCode != null =>
      LocaleKeys.app_errors_dependencies_network_http_status.tr(
        namedArgs: {'status': '${error.response!.statusCode}'},
      ),
    _ => error.message ?? error.type.name,
  };

  static String _describe(Object error) => switch (error) {
    FileSystemException(:final osError?) => osError.message,
    FileSystemException(:final message) => message,
    _ => '$error',
  };
}
