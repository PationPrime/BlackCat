import 'dart:io';

import 'package:path/path.dart' as p;

import '../../constants/constants.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../tools/tools.dart';

/// Account cookies.txt and the sign-in window WebView2 profile on disk
abstract interface class LocalAuthenticationDataSource {
  Future<String> cookiesFilePath();

  /// `null` if there is no cookies file
  Future<List<BrowserCookieModel>?> readCookies();

  Future<void> writeCookies(List<BrowserCookieModel> cookies);

  Future<void> deleteCookies();

  /// WebView2 data folder of the sign-in window
  Future<String> signInProfileFolder();

  /// The sign-in window profile has been created before: it may hold a Google session
  Future<bool> signInProfileExists();

  /// Wipes the sign-in window profile together with the Google session
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
        /// WebView2 does not release files right after the last window closes
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
  }
}
