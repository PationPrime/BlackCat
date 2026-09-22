import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:black_cat/src/app/api/api.dart';
import 'package:black_cat/src/app/constants/constants.dart';
import 'package:black_cat/src/app/data_sources/data_sources.dart';
import 'package:black_cat/src/app/models/models.dart';
import 'package:black_cat/src/app/operation_result/operation_result.dart';
import 'package:black_cat/src/app/repositories/repositories.dart';

import '../../support/test_localization.dart';

const _repository = '/repos/PationPrime/BlackCat';

/// GitHub API stand-in: the repository and its latest release
final class _GitHubServer {
  final requests = <String>[];

  /// Status of every answer by its path; 200 when not set
  final statuses = <String, int>{};
  var stars = 12;

  late final HttpServer _server;

  String get repositoryApiUrl =>
      'http://${_server.address.host}:${_server.port}$_repository';

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen(_handle);
  }

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    final response = request.response;

    requests.add(path);

    try {
      response.statusCode = statuses[path] ?? 200;

      if (response.statusCode != 200) {
        response.write('{"message":"Not Found"}');

        return;
      }

      response.headers.contentType = ContentType.json;
      response.write(
        jsonEncode(switch (path) {
          _repository => {
            'full_name': 'PationPrime/BlackCat',
            'stargazers_count': stars,
          },
          _ => {
            'tag_name': 'v0.2.0',
            'assets': [
              {
                'name': 'BlackCat_0.2.0_Apple_Silicon_aarch64.dmg',
                'download_count': 40,
              },
              {'name': 'BlackCat_0.2.0_Intel_x64.dmg', 'download_count': 7},
              {
                'name': 'BlackCat_Windows_x86_0.2.0.zip',
                'download_count': 1500,
              },
              {
                'name': 'BlackCat_Windows_x86_0.2.0.zip.sha256',
                'download_count': 3,
              },
            ],
          },
        }),
      );
    } finally {
      await response.close();
    }
  }
}

void main() {
  late _GitHubServer server;
  late DateTime now;
  late ProjectStatsRepository repository;

  setUpAll(loadTestTranslations);

  setUp(() async {
    server = _GitHubServer();
    await server.start();
    now = DateTime(2026, 9, 22, 12);
    repository = ProjectStatsRepository(
      remoteProjectStatsDataSource: RemoteProjectStatsDataSourceImpl(
        apiProvider: ApiProvider(),
        repositoryApiUrl: server.repositoryApiUrl,
      ),
      now: () => now,
    );
  });

  tearDown(() => server.close());

  test('звёзды и скачивания последней версии по системам', () async {
    final result = await repository.getStats();

    expect(result.failure, isNull, reason: result.failure?.message);
    expect(
      result.requireData,
      const ProjectStatsModel(
        stars: 12,
        version: 'v0.2.0',
        downloads: {
          ReleasePlatformModel.macos: 47,
          ReleasePlatformModel.windows: 1500,
        },
      ),
    );
    expect(
      result.requireData.downloadsOf(ReleasePlatformModel.linux),
      0,
      reason: 'a release without a Linux file has 0 Linux downloads',
    );
    expect(
      server.requests,
      unorderedEquals([_repository, '$_repository/releases/latest']),
    );
  });

  test(
    'ответ хранится 15 минут: GitHub без аккаунта даёт мало запросов',
    () async {
      await repository.getStats();
      server.stars = 13;

      now = now.add(const Duration(minutes: 10));

      expect((await repository.getStats()).requireData.stars, 12);
      expect(server.requests, hasLength(2));

      now = now.add(ProjectConstants.statsLifetime);

      expect((await repository.getStats()).requireData.stars, 13);
      expect(server.requests, hasLength(4));
    },
  );

  test('обновление по запросу идёт в GitHub сразу', () async {
    await repository.getStats();
    server.stars = 14;

    expect((await repository.getStats(refresh: true)).requireData.stars, 14);
  });

  test('без релизов — звёзды есть, скачиваний нет', () async {
    server.statuses['$_repository/releases/latest'] = 404;

    final stats = (await repository.getStats()).requireData;

    expect(stats.stars, 12);
    expect(stats.version, isNull);
    expect(stats.downloadsOf(ReleasePlatformModel.macos), isNull);
  });

  test('GitHub ответил не на всё — показывается известное, '
      'остальное спрашивается снова', () async {
    server.statuses[_repository] = 403;

    final partial = (await repository.getStats()).requireData;

    expect(partial.stars, isNull);
    expect(partial.downloadsOf(ReleasePlatformModel.windows), 1500);

    server.statuses.clear();

    expect((await repository.getStats()).requireData.stars, 12);
  });

  test('GitHub не ответил совсем — ошибка', () async {
    server.statuses[_repository] = 500;
    server.statuses['$_repository/releases/latest'] = 500;

    final result = await repository.getStats();

    expect(result.data, isNull);
    expect(result.failure, isNotNull);
  });
}
