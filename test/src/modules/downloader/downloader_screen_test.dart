import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_downloader/src/app/design_system/design_system.dart';
import 'package:youtube_downloader/src/app/models/models.dart';
import 'package:youtube_downloader/src/app/repositories/repositories.dart';
import 'package:youtube_downloader/src/app/services/services.dart';
import 'package:youtube_downloader/src/app/shared_controllers/shared_controllers.dart';
import 'package:youtube_downloader/src/modules/downloader/module.dart';

import '../../support/fake_repositories.dart';
import '../../support/test_localization.dart';

const _quality = QualityModel(id: '1080', kind: QualityKind.video, label: '1080p', resolution: 1080);

VideoInfoModel _video(String id) => VideoInfoModel(
  id: id,
  title: 'Видео $id',
  url: 'https://www.youtube.com/watch?v=$id',
  qualities: const [_quality],
);

final class _Screen {
  final videoRepository = FakeVideoRepository();
  final queueRepository = FakeDownloadQueueRepository();
  late final authorizationController = AuthorizationController(
    authenticationRepository: FakeAuthenticationRepository(),
  );
  late final controller = DownloadQueueController(
    downloadQueueRepository: queueRepository,
    videoRepository: videoRepository,
    settingsRepository: FakeSettingsRepository(),
    authorizationController: authorizationController,
  );

  Future<void> pump(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1000, 1800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<FileSystemService>.value(value: FileSystemServiceImpl()),
          RepositoryProvider<VideoRepositoryInterface>.value(value: videoRepository),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider<AuthorizationController>.value(value: authorizationController),
            BlocProvider<DownloadQueueController>.value(value: controller),
          ],
          child: MaterialApp(theme: AppThemeData.darkTheme, home: const DownloaderScreen()),
        ),
      ),
    );
  }

  Future<void> add(WidgetTester tester, String id) async {
    await controller.addTask(video: _video(id), quality: _quality);
    await settle(tester);
  }

  /// Enough both for the queue change chain and for the dialog open and close animation
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }
}

void main() {
  setUpAll(loadTestTranslations);

  testWidgets('разделы: активная загрузка, очередь и завершённые', (tester) async {
    final screen = _Screen();

    await screen.pump(tester);

    expect(find.text('АКТИВНАЯ ЗАГРУЗКА'), findsOneWidget);
    expect(find.text('ОЧЕРЕДЬ СКАЧИВАНИЯ'), findsOneWidget);
    expect(find.textContaining('Нет активной загрузки'), findsOneWidget);
    expect(find.textContaining('Очередь пуста'), findsOneWidget);
    expect(find.text('СКАЧАННЫЕ'), findsOneWidget);
    expect(find.text('Здесь появятся скачанные видео.'), findsOneWidget);

    await screen.add(tester, 'a');
    await screen.add(tester, 'b');
    await screen.add(tester, 'c');

    screen.videoRepository.downloads.single.reportProgress(
      const DownloadProgressModel(DownloadStage.downloading, 50, speed: 1024, eta: 4, downloadedBytes: 500, totalBytes: 1000),
    );
    await screen.settle(tester);

    expect(find.text('Видео a'), findsOneWidget);
    expect(find.textContaining('Скачивание 50%'), findsOneWidget);
    expect(find.text('Видео b'), findsOneWidget);
    expect(find.text('Видео c'), findsOneWidget);
    expect(find.byType(QueuedDownloadTile), findsNWidgets(2));
    expect(find.textContaining('Очередь пуста'), findsNothing);

    screen.videoRepository.downloads.single.succeed(r'C:\Downloads\a.mp4', sizeBytes: 70000000);
    await screen.settle(tester);

    expect(find.byType(DownloadedVideoTile), findsOneWidget);
    expect(find.textContaining('67 МБ · Скачано '), findsOneWidget);
    expect(find.text('Здесь появятся скачанные видео.'), findsNothing);
    expect(find.byType(ActiveDownloadCard), findsOneWidget);
    expect(find.byType(QueuedDownloadTile), findsOneWidget);

    await screen.controller.close();
  });

  testWidgets('удаление начатой загрузки спрашивает подтверждение', (tester) async {
    final screen = _Screen();

    await screen.pump(tester);
    await screen.add(tester, 'a');

    screen.videoRepository.downloads.single.reportProgress(
      const DownloadProgressModel(DownloadStage.downloading, 30, downloadedBytes: 300, totalBytes: 1000),
    );
    await screen.settle(tester);

    await tester.tap(find.descendant(of: find.byType(ActiveDownloadCard), matching: find.byTooltip('Убрать')));
    await screen.settle(tester);

    expect(find.text('Убрать видео?'), findsOneWidget);

    await tester.tap(find.text('Отмена'));
    await screen.settle(tester);

    expect(find.text('Убрать видео?'), findsNothing);
    expect(screen.controller.state.activeTask?.video.id, 'a');

    await tester.tap(find.descendant(of: find.byType(ActiveDownloadCard), matching: find.byTooltip('Убрать')));
    await screen.settle(tester);
    await tester.tap(find.text('Убрать и удалить файл'));
    await screen.settle(tester);

    expect(screen.controller.state.activeTask, isNull);
    expect(screen.queueRepository.removedTaskIds, hasLength(1));

    await screen.controller.close();
  });

  testWidgets('«Скачать сейчас» в очереди делает видео активным', (tester) async {
    final screen = _Screen();

    await screen.pump(tester);
    await screen.add(tester, 'a');
    await screen.add(tester, 'b');

    await tester.tap(find.byTooltip('Скачать сейчас'));
    await screen.settle(tester);

    expect(screen.controller.state.activeTask?.video.id, 'b');
    expect(find.textContaining('На паузе'), findsOneWidget);

    await screen.controller.close();
  });

  testWidgets('«Добавить видео» открывает диалог поиска', (tester) async {
    final screen = _Screen();

    await screen.pump(tester);

    await tester.tap(find.text('Добавить видео'));
    await screen.settle(tester);

    expect(find.byType(AddVideoDialog), findsOneWidget);
    expect(find.text('Найти'), findsOneWidget);

    await tester.tap(find.text('Отмена'));
    await screen.settle(tester);

    expect(find.byType(AddVideoDialog), findsNothing);

    await screen.controller.close();
  });
}
