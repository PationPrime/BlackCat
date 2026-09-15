import 'dart:io';

import 'package:path/path.dart' as p;

import '../../constants/constants.dart';
import '../../services/services.dart';

/// YouTube player JavaScript cache on disk: ~3 MB, changes about once a week
abstract interface class LocalPlayerDataSource {
  /// `null` if this player has not been downloaded yet
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
