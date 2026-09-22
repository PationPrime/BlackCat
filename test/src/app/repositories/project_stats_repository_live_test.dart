// Live check of the PeekyCat stats on GitHub (two API requests). Not part of
// the regular run:
//   $env:GITHUB_LIVE='1'; flutter test --tags live
@Tags(['live'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:peeky_cat/src/app/api/api.dart';
import 'package:peeky_cat/src/app/data_sources/data_sources.dart';
import 'package:peeky_cat/src/app/models/models.dart';
import 'package:peeky_cat/src/app/operation_result/operation_result.dart';
import 'package:peeky_cat/src/app/repositories/repositories.dart';

import '../../support/test_localization.dart';

void main() {
  final enabled = Platform.environment['GITHUB_LIVE'] == '1';

  test(
    'звёзды репозитория и скачивания последней версии для macOS и Windows',
    () async {
      loadTestTranslations();

      final repository = ProjectStatsRepository(
        remoteProjectStatsDataSource: RemoteProjectStatsDataSourceImpl(
          apiProvider: ApiProvider(),
        ),
      );
      final result = await repository.getStats();

      expect(result.failure, isNull, reason: result.failure?.message);

      final stats = result.requireData;

      expect(stats.stars, isNotNull);
      expect(stats.version, startsWith('v'));
      expect(
        stats.downloadsOf(ReleasePlatformModel.macos),
        greaterThanOrEqualTo(0),
      );
      expect(
        stats.downloadsOf(ReleasePlatformModel.windows),
        greaterThanOrEqualTo(0),
      );

      // ignore: avoid_print
      print(stats);
    },
    skip: enabled ? false : 'нужен GITHUB_LIVE=1',
  );
}
