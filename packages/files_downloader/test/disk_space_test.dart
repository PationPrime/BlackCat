import 'dart:io';

import 'package:files_downloader/files_downloader.dart';
import 'package:files_downloader/src/engine/file_errors.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// OS codes of the current system
final _diskFullCode = Platform.isWindows ? 112 : 28;
final _ioErrorCode = Platform.isWindows ? 1117 : 5;
final _accessDeniedCode = Platform.isWindows ? 5 : 13;

FileSystemException _error(int code) =>
    FileSystemException('Cannot write', 'movie.bin', OSError('reason', code));

FilesDownloadError _classify(
  int code, {
  int neededBytes = 5000,
  int? availableBytes,
}) => fileError(
  _error(code),
  path: 'movie.bin',
  neededBytes: neededBytes,
  availableBytes: () => availableBytes,
  minimumFreeBytes: 1000,
);

void main() {
  group('файловые ошибки', () {
    test(
      'система прямо говорит о нехватке места — diskFull со свободным местом',
      () {
        final error = _classify(_diskFullCode, availableBytes: 1 << 30);

        expect(error.type, FilesDownloadErrorType.diskFull);
        expect(error.neededBytes, 5000);
        expect(error.availableBytes, 1 << 30);
        expect(error.path, 'movie.bin');
        expect(error.message, contains('(5000 bytes)'));
        expect(isDiskFull(_error(_diskFullCode)), isTrue);
      },
    );

    test(
      'ошибка ввода-вывода: места меньше нужного — diskFull, иначе — fileSystem',
      () {
        expect(
          _classify(_ioErrorCode, availableBytes: 4999).type,
          FilesDownloadErrorType.diskFull,
        );
        expect(
          _classify(_ioErrorCode, availableBytes: 5000).type,
          FilesDownloadErrorType.fileSystem,
        );
      },
    );

    test(
      'свободно меньше минимума — diskFull, даже если загрузке больше ничего не нужно',
      () {
        expect(
          _classify(_ioErrorCode, neededBytes: 0, availableBytes: 999).type,
          FilesDownloadErrorType.diskFull,
        );
      },
    );

    test('система не знает свободное место — fileSystem', () {
      final error = _classify(_ioErrorCode);

      expect(error.type, FilesDownloadErrorType.fileSystem);
      expect(error.message, 'Cannot write: reason');
    });

    test('у ошибки своя причина (нет прав) — место не проверяется', () {
      final error = fileError(
        _error(_accessDeniedCode),
        path: 'movie.bin',
        neededBytes: 5000,
        availableBytes: () => fail('The free space is not asked'),
        minimumFreeBytes: 1000,
      );

      expect(error.type, FilesDownloadErrorType.fileSystem);
      expect(mayBeDiskFull(_error(_accessDeniedCode)), isFalse);
    });

    test('ошибка без кода системы может быть от нехватки места', () {
      expect(
        mayBeDiskFull(const FileSystemException('Cannot write', 'movie.bin')),
        isTrue,
      );
    });
  });

  group('свободное место системы', () {
    late Directory root;

    setUp(() async => root = await Directory.systemTemp.createTemp('fds-disk'));
    tearDown(() => root.delete(recursive: true));

    test('есть и у папки, и у ещё не созданного файла в ней', () {
      const diskSpace = SystemDiskSpace();
      final folder = diskSpace.availableBytes(root.path);
      final file = diskSpace.availableBytes(
        p.join(root.path, 'not', 'yet', 'movie.bin'),
      );

      expect(folder, greaterThan(0));
      expect(file, greaterThan(0));

      /// The same volume: only other programs change the free space
      expect((file! - folder!).abs(), lessThan(1 << 30));
    });

    test('совпадает с df на macOS и Linux', () {
      final result = Process.runSync('df', ['-Pk', root.path]);
      final columns = '${result.stdout}'
          .trim()
          .split('\n')
          .last
          .split(RegExp(r'\s+'));
      final df =
          int.parse(
            columns[columns.indexWhere((c) => RegExp(r'^\d+%$').hasMatch(c)) -
                1],
          ) *
          1024;

      expect(
        (const SystemDiskSpace().availableBytes(root.path)! - df).abs(),
        lessThan(1 << 30),
      );
    }, testOn: 'mac-os || linux');
  });
}
