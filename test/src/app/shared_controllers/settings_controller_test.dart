import 'package:flutter_test/flutter_test.dart';
import 'package:black_cat/src/app/errors/errors.dart';
import 'package:black_cat/src/app/models/models.dart';
import 'package:black_cat/src/app/shared_controllers/shared_controllers.dart';

import '../../support/fake_repositories.dart';

const _customDirectory = DownloadDirectoryModel(
  path: r'D:\Видео',
  isDefault: false,
);

void main() {
  test('loadSettings: папка по умолчанию — «Загрузки»', () async {
    final controller = SettingsController(
      settingsRepository: FakeSettingsRepository(),
    );

    await controller.loadSettings();

    expect(controller.state.isLoading, isFalse);
    expect(controller.state.downloadDirectory?.isDefault, isTrue);
  });

  test('pickDownloadDirectory: выбранная папка, начиная с текущей', () async {
    final repository = FakeSettingsRepository(
      pickResult: (failure: null, data: _customDirectory),
    );
    final controller = SettingsController(settingsRepository: repository);

    await controller.loadSettings();
    await controller.pickDownloadDirectory();

    expect(repository.pickInitialDirectories, [r'C:\Users\user\Downloads']);
    expect(controller.state.downloadDirectory, _customDirectory);
  });

  test(
    'pickDownloadDirectory: закрытый диалог оставляет папку прежней',
    () async {
      final controller = SettingsController(
        settingsRepository: FakeSettingsRepository(),
      );

      await controller.loadSettings();

      final before = controller.state.downloadDirectory;

      await controller.pickDownloadDirectory();

      expect(controller.state.downloadDirectory, before);
      expect(controller.state.failure, isNull);
    },
  );

  test('resetDownloadDirectory возвращает «Загрузки»', () async {
    final controller = SettingsController(
      settingsRepository: FakeSettingsRepository(
        directoryResult: (failure: null, data: _customDirectory),
      ),
    );

    await controller.loadSettings();
    await controller.resetDownloadDirectory();

    expect(controller.state.downloadDirectory?.isDefault, isTrue);
  });

  test('ошибка выбора папки показывается', () async {
    const failure = SettingsFailure(
      code: 'picker',
      message: 'Не удалось открыть выбор папки',
    );
    final controller = SettingsController(
      settingsRepository: FakeSettingsRepository(
        pickResult: (failure: failure, data: null),
      ),
    );

    await controller.pickDownloadDirectory();

    expect(controller.state.failure, failure);
  });

  test('loadSettings читает сохранённый язык', () async {
    final controller = SettingsController(
      settingsRepository: FakeSettingsRepository(
        languageResult: (failure: null, data: AppLanguageModel.english),
      ),
    );

    expect(controller.state.language, AppLanguageModel.russian);

    await controller.loadSettings();

    expect(controller.state.language, AppLanguageModel.english);
  });

  test('changeLanguage переключает язык сразу и сохраняет его', () async {
    final repository = FakeSettingsRepository();
    final controller = SettingsController(settingsRepository: repository);

    await controller.changeLanguage(AppLanguageModel.english);

    expect(controller.state.language, AppLanguageModel.english);
    expect(repository.savedLanguages, [AppLanguageModel.english]);

    await controller.changeLanguage(AppLanguageModel.english);

    expect(repository.savedLanguages, hasLength(1));
  });

  test(
    'changeLanguage: язык не сохранился — остаётся прежний и показывается ошибка',
    () async {
      const failure = SettingsFailure(
        code: 'storage',
        message: 'Не удалось сохранить настройки',
      );
      final controller = SettingsController(
        settingsRepository: FakeSettingsRepository(
          setLanguageResult: (failure: failure, data: null),
        ),
        initialLanguage: AppLanguageModel.russian,
      );

      await controller.changeLanguage(AppLanguageModel.english);

      expect(controller.state.language, AppLanguageModel.russian);
      expect(controller.state.failure, failure);
    },
  );

  test('loadSettings читает версию приложения', () async {
    final controller = SettingsController(
      settingsRepository: FakeSettingsRepository(),
    );

    expect(controller.state.appVersion, isNull);

    await controller.loadSettings();

    expect(
      controller.state.appVersion,
      const AppVersionModel(version: '0.2.0', buildNumber: '1'),
    );
  });

  test(
    'версия не прочиталась — настройки загружаются без ошибки на странице',
    () async {
      final controller = SettingsController(
        settingsRepository: FakeSettingsRepository(
          appVersionResult: (
            failure: const SettingsFailure(message: 'no version'),
            data: null,
          ),
        ),
      );

      await controller.loadSettings();

      expect(controller.state.appVersion, isNull);
      expect(controller.state.failure, isNull);
      expect(controller.state.downloadDirectory?.isDefault, isTrue);
    },
  );

  test('AppLanguageModel.fromCode: неизвестный или пустой код — русский', () {
    expect(AppLanguageModel.fromCode('en'), AppLanguageModel.english);
    expect(AppLanguageModel.fromCode('de'), AppLanguageModel.russian);
    expect(AppLanguageModel.fromCode(null), AppLanguageModel.russian);
  });
}
