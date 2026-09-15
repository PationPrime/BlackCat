import 'dart:io';

import 'package:path/path.dart' as p;

import '../../constants/constants.dart';
import '../../services/services.dart';

/// Кэш JavaScript плеера YouTube на диске: ~3 МБ, меняется примерно раз в неделю
abstract interface class LocalPlayerDataSource {
  /// `null`, если этот плеер ещё не скачивался
  Future<String?> readPlayerJs(String playerId);

  Future<void> writePlayerJs(String playerId, String code);
}

final class LocalPlayerDataSourceImpl implements LocalPlayerDataSource {
  final FileSystemService _fileSystemService;

  const LocalPlayerDataSourceImpl({required this._fileSystemService});

  Future<File> _file(String playerId) async => File(
    p.join(
      await _fileSystemService.localAppFolder(
        StorageConstants.playerCacheFolder,
      ),
      'player-$playerId.js',
    ),
  );

  @override
  Future<String?> readPlayerJs(String playerId) async {
    final file = await _file(playerId);

    return await file.exists() ? file.readAsString() : null;
  }

  @override
  Future<void> writePlayerJs(String playerId, String code) async {
    final file = await _file(playerId);

    await file.parent.create(recursive: true);
    await file.writeAsString(code);
  }
}
