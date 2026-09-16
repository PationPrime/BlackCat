import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:youtube_downloader/src/app/data_sources/data_sources.dart';
import 'package:youtube_downloader/src/app/errors/errors.dart';
import 'package:youtube_downloader/src/app/models/models.dart';
import 'package:youtube_downloader/src/app/repositories/repositories.dart';
import 'package:youtube_downloader/src/app/services/services.dart';
import 'package:youtube_downloader/src/app/tools/tools.dart';

import '../../support/test_localization.dart';

/// 2099-01-01 in seconds
const _future = 4070908800;

class _TestFileSystemService extends FileSystemServiceImpl {
  final Directory root;

  _TestFileSystemService(this.root);

  @override
  Future<String> localAppFolder(String name) async => p.join(root.path, 'local', name);

  @override
  Future<String> supportFolder() async => p.join(root.path, 'support');
}

final class _FakeFileSelector implements FileSelectorService {
  String? pickedFile;
  Object? error;
  final requests = <({List<String> extensions, String? initialDirectory})>[];

  @override
  Future<String?> pickDirectory({String? initialDirectory, String? confirmButtonText}) async => null;

  @override
  Future<String?> pickFile({
    required String typeLabel,
    required List<String> extensions,
    List<String> mimeTypes = const [],
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    requests.add((extensions: extensions, initialDirectory: initialDirectory));

    if (error case final error?) throw error;

    return pickedFile;
  }
}

final class _FakeWebDataSource implements WebAuthenticationDataSource {
  List<BrowserCookieModel>? signInCookies;

  @override
  Future<List<BrowserCookieModel>?> signIn() async => signInCookies;

  @override
  Future<List<BrowserCookieModel>> readProfileCookies() async => const [];
}

String _cookiesTxt(String sessionValue) => [
  '# Netscape HTTP Cookie File',
  ['#HttpOnly_.youtube.com', 'TRUE', '/', 'TRUE', '$_future', 'LOGIN_INFO', sessionValue].join('\t'),
  ['.youtube.com', 'TRUE', '/', 'TRUE', '$_future', 'SAPISID', 'sapisid'].join('\t'),
  ['.example.com', 'TRUE', '/', 'FALSE', '$_future', 'tracker', 'x'].join('\t'),
].join('\n');

void main() {
  late Directory root;
  late LocalAuthenticationDataSource localDataSource;
  late _FakeFileSelector fileSelector;
  late _FakeWebDataSource webDataSource;
  late AuthenticationRepository repository;

  setUpAll(loadTestTranslations);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('authentication-repository');
    localDataSource = LocalAuthenticationDataSourceImpl(fileSystemService: _TestFileSystemService(root));
    fileSelector = _FakeFileSelector();
    webDataSource = _FakeWebDataSource();
    repository = AuthenticationRepository(
      localDataSource: localDataSource,
      webDataSource: webDataSource,
      fileSelectorService: fileSelector,
    );
  });

  tearDown(() => root.delete(recursive: true));

  Future<String> writeFile(String name, String content) async {
    final file = File(p.join(root.path, 'Downloads', name));

    await file.parent.create(recursive: true);
    await file.writeAsString(content);

    return file.path;
  }

  test('importCookies: проверенные cookies становятся сессией и переживают перезапуск', () async {
    final path = await writeFile('cookies.txt', _cookiesTxt('imported'));

    fileSelector.pickedFile = path;

    final result = await repository.importCookies();

    expect(result.failure, isNull, reason: result.failure?.message);
    expect(result.data?.isImported, isTrue);
    expect(result.data?.cookiesFilePath, path);
    expect(fileSelector.requests.single.extensions, ['txt']);

    final saved = await localDataSource.readCookies();

    expect([for (final cookie in saved!) cookie.name], ['LOGIN_INFO', 'SAPISID']);
    expect(saved.first.value, 'imported');

    /// The user's file stays as it was
    expect(await File(path).readAsString(), _cookiesTxt('imported'));

    final restored = await repository.restoreSession();

    expect(restored.data, result.data);

    /// The next picker opens next to the previous file
    fileSelector.pickedFile = null;

    expect((await repository.importCookies()).data, isNull);
    expect(fileSelector.requests.last.initialDirectory, p.dirname(path));
  });

  test('importCookies: ошибки файла сообщаются, прежняя сессия не трогается', () async {
    webDataSource.signInCookies = NetscapeCookies.decode(_cookiesTxt('window'));

    expect((await repository.signIn()).data, isTrue);

    fileSelector.pickedFile = await writeFile('notes.txt', 'просто текст');

    final formatResult = await repository.importCookies();

    expect(formatResult.failure?.code, const AuthenticationErrorCodes().cookiesFormat);
    expect(formatResult.failure?.message, contains('Netscape'));

    fileSelector.pickedFile = await writeFile('cookies.json', _cookiesTxt('json'));

    expect((await repository.importCookies()).failure?.code, const AuthenticationErrorCodes().cookiesNotText);

    fileSelector.pickedFile = p.join(root.path, 'missing.txt');

    final readResult = await repository.importCookies();

    expect(readResult.failure?.code, const AuthenticationErrorCodes().cookiesRead);
    expect(readResult.failure?.message, startsWith('Не удалось прочитать файл cookies'));

    fileSelector.error = StateError('no dialog');

    expect((await repository.importCookies()).failure?.code, const AuthenticationErrorCodes().cookiesPicker);

    expect((await localDataSource.readCookies())!.first.value, 'window');
    expect(await repository.restoreSession(), (failure: null, data: const AccountSessionModel.signInWindow()));
  });

  test('вход через окно заменяет импорт, выход удаляет cookies вместе с отметкой об импорте', () async {
    fileSelector.pickedFile = await writeFile('cookies.txt', _cookiesTxt('imported'));

    expect((await repository.importCookies()).data?.isImported, isTrue);

    webDataSource.signInCookies = NetscapeCookies.decode(_cookiesTxt('window'));

    await repository.signIn();

    expect((await repository.restoreSession()).data, const AccountSessionModel.signInWindow());

    await repository.importCookies();
    await repository.signOut();

    expect(await localDataSource.readCookies(), isNull);
    expect(await localDataSource.readCookiesSource(), isNull);
    expect((await repository.restoreSession()).data, isNull);
  });
}
