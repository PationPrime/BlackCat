import 'dart:io';

import 'package:path/path.dart' as p;

import '../../constants/constants.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../tools/tools.dart';

/// cookies.txt аккаунта и профиль WebView2 окна входа на диске
abstract interface class LocalAuthenticationDataSource {
  Future<String> cookiesFilePath();

  /// `null`, если файла cookies нет
  Future<List<BrowserCookieModel>?> readCookies();

  Future<void> writeCookies(List<BrowserCookieModel> cookies);

  Future<void> deleteCookies();

  /// Папка данных WebView2 окна входа
  Future<String> signInProfileFolder();

  /// Профиль окна входа уже создавался: в нём может быть сессия Google
  Future<bool> signInProfileExists();

  /// Стирает профиль окна входа вместе с сессией Google
  Future<void> deleteSignInProfile();
}

final class LocalAuthenticationDataSourceImpl
    implements LocalAuthenticationDataSource {
  final FileSystemService _fileSystemService;

  const LocalAuthenticationDataSourceImpl({required this._fileSystemService});

  @override
  Future<String> cookiesFilePath() async => p.join(
    await _fileSystemService.supportFolder(),
    StorageConstants.cookiesFileName,
  );

  @override
  Future<List<BrowserCookieModel>?> readCookies() async {
    final file = File(await cookiesFilePath());

    if (!await file.exists()) {
      return null;
    }

    return NetscapeCookies.decode(await file.readAsString());
  }

  @override
  Future<void> writeCookies(List<BrowserCookieModel> cookies) async {
    final file = File(await cookiesFilePath());

    await file.parent.create(recursive: true);
    await file.writeAsString(NetscapeCookies.encode(cookies));
  }

  @override
  Future<void> deleteCookies() async {
    final file = File(await cookiesFilePath());

    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<String> signInProfileFolder() =>
      _fileSystemService.localAppFolder(StorageConstants.signInProfileFolder);

  Future<Directory> _profileData() async =>
      Directory(p.join(await signInProfileFolder(), 'EBWebView'));

  @override
  Future<bool> signInProfileExists() async => (await _profileData()).exists();

  @override
  Future<void> deleteSignInProfile() async {
    final profile = await _profileData();

    for (var attempt = 1; attempt <= 5 && await profile.exists(); attempt++) {
      try {
        await profile.delete(recursive: true);
      } on FileSystemException {
        /// WebView2 отпускает файлы не сразу после закрытия последнего окна
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
  }
}
