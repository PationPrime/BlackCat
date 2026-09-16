import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_downloader/src/app/errors/errors.dart';
import 'package:youtube_downloader/src/app/models/models.dart';
import 'package:youtube_downloader/src/modules/downloads/module.dart';

import '../../support/test_app.dart';
import '../../support/test_localization.dart';

const _signInFailure = VideoFailure(
  code: 'bot_check',
  message: 'YouTube просит подтвердить, что вы не бот.',
  needsSignIn: true,
);

void main() {
  setUpAll(loadTestTranslations);

  testWidgets('разделы: активная загрузка, очередь и завершённые', (tester) async {
    final app = TestApp();

    await app.pumpPage(tester, const DownloadsScreen());

    expect(find.text('Загрузки'), findsOneWidget);
    expect(find.text('АКТИВНАЯ ЗАГРУЗКА'), findsOneWidget);
    expect(find.text('ОЧЕРЕДЬ СКАЧИВАНИЯ'), findsOneWidget);
    expect(find.textContaining('Нет активной загрузки'), findsOneWidget);
    expect(find.textContaining('Очередь пуста'), findsOneWidget);
    expect(find.text('СКАЧАННЫЕ'), findsOneWidget);
    expect(find.text('Здесь появятся скачанные видео.'), findsOneWidget);

    await app.addTask(tester, 'a');
    await app.addTask(tester, 'b');
    await app.addTask(tester, 'c');

    app.videoRepository.downloads.single.reportProgress(
      const DownloadProgressModel(DownloadStage.downloading, 50, speed: 1024, eta: 4, downloadedBytes: 500, totalBytes: 1000),
    );
    await app.settle(tester);

    expect(find.text('Видео a'), findsOneWidget);
    expect(find.textContaining('Скачивание 50%'), findsOneWidget);
    expect(find.text('Видео b'), findsOneWidget);
    expect(find.text('Видео c'), findsOneWidget);
    expect(find.byType(QueuedDownloadTile), findsNWidgets(2));
    expect(find.textContaining('Очередь пуста'), findsNothing);

    app.videoRepository.downloads.single.succeed(r'C:\Downloads\a.mp4', sizeBytes: 70000000);
    await app.settle(tester);

    expect(find.byType(DownloadedVideoTile), findsOneWidget);
    expect(find.textContaining('67 МБ · Скачано '), findsOneWidget);
    expect(find.text('Здесь появятся скачанные видео.'), findsNothing);
    expect(find.byType(ActiveDownloadCard), findsOneWidget);
    expect(find.byType(QueuedDownloadTile), findsOneWidget);

    await app.close();
  });

  testWidgets('удаление начатой загрузки спрашивает подтверждение', (tester) async {
    final app = TestApp();

    await app.pumpPage(tester, const DownloadsScreen());
    await app.addTask(tester, 'a');

    app.videoRepository.downloads.single.reportProgress(
      const DownloadProgressModel(DownloadStage.downloading, 30, downloadedBytes: 300, totalBytes: 1000),
    );
    await app.settle(tester);

    final remove = find.descendant(of: find.byType(ActiveDownloadCard), matching: find.byTooltip('Убрать'));

    await tester.tap(remove);
    await app.settle(tester);

    expect(find.text('Убрать видео?'), findsOneWidget);

    await tester.tap(find.text('Отмена'));
    await app.settle(tester);

    expect(find.text('Убрать видео?'), findsNothing);
    expect(app.queueController.state.activeTask?.video.id, 'a');

    await tester.tap(remove);
    await app.settle(tester);
    await tester.tap(find.text('Убрать и удалить файл'));
    await app.settle(tester);

    expect(app.queueController.state.activeTask, isNull);
    expect(app.queueRepository.removedTaskIds, hasLength(1));

    await app.close();
  });

  testWidgets('«Скачать сейчас» в очереди делает видео активным', (tester) async {
    final app = TestApp();

    await app.pumpPage(tester, const DownloadsScreen());
    await app.addTask(tester, 'a');
    await app.addTask(tester, 'b');

    await tester.tap(find.byTooltip('Скачать сейчас'));
    await app.settle(tester);

    expect(app.queueController.state.activeTask?.video.id, 'b');
    expect(find.textContaining('На паузе'), findsOneWidget);

    await app.close();
  });

  testWidgets('«Добавить видео» в заголовке открывает главную', (tester) async {
    final app = TestApp();

    app.navigationController.selectTab(AppTabModel.downloads);

    await app.pumpPage(tester, const DownloadsScreen());
    await tester.tap(find.text('Добавить видео'));
    await app.settle(tester);

    expect(app.navigationController.state.tab, AppTabModel.home);

    await app.close();
  });

  testWidgets('«Ошибка скачивания» появляется после очереди только с упавшими видео', (tester) async {
    final app = TestApp();

    await app.pumpPage(tester, const DownloadsScreen());

    expect(find.text('ОШИБКА СКАЧИВАНИЯ'), findsNothing);

    await app.addTask(tester, 'a');
    await app.addTask(tester, 'b');

    app.videoRepository.downloads.single.failWith(
      const VideoFailure(code: 'mux', message: 'Не удалось собрать файл: нет места'),
    );
    await app.settle(tester);

    final failedTitle = find.text('ОШИБКА СКАЧИВАНИЯ');

    expect(failedTitle, findsOneWidget);
    expect(find.byType(FailedDownloadTile), findsOneWidget);
    expect(find.byType(QueuedDownloadTile), findsNothing);
    expect(find.text('Не удалось собрать файл: нет места'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('ОЧЕРЕДЬ СКАЧИВАНИЯ')).dy,
      lessThan(tester.getTopLeft(failedTitle).dy),
    );
    expect(
      tester.getTopLeft(failedTitle).dy,
      lessThan(tester.getTopLeft(find.text('СКАЧАННЫЕ')).dy),
    );

    /// No sign-in buttons for errors that signing in will not fix
    expect(find.descendant(of: find.byType(FailedDownloadTile), matching: find.text('Войти')), findsNothing);

    await tester.tap(find.descendant(of: find.byType(FailedDownloadTile), matching: find.text('Повторить')));
    await app.settle(tester);

    expect(find.text('ОШИБКА СКАЧИВАНИЯ'), findsNothing);
    expect(app.queueController.state.queue.first.video.id, 'a');

    await app.close();
  });

  testWidgets('ошибка входа: «Войти» повторяет загрузку, импорт cookies — все такие загрузки', (tester) async {
    final app = TestApp();

    await app.pumpPage(tester, const DownloadsScreen());
    await app.addTask(tester, 'a');

    app.videoRepository.downloads.single.failWith(_signInFailure);
    await app.settle(tester);

    final failed = find.byType(FailedDownloadTile);

    expect(failed, findsOneWidget);
    expect(find.descendant(of: failed, matching: find.text('Войти')), findsOneWidget);

    await tester.tap(find.descendant(of: failed, matching: find.text('Войти')));
    await app.settle(tester);

    expect(app.authenticationRepository.signInCalls, 1);
    expect(app.videoRepository.downloads, hasLength(2));
    expect(find.byType(FailedDownloadTile), findsNothing);

    app.videoRepository.downloads.last.failWith(_signInFailure);
    await app.settle(tester);

    app.navigationController.selectTab(AppTabModel.downloads);

    await tester.tap(find.descendant(of: find.byType(FailedDownloadTile), matching: find.text('Импортировать cookies.txt')));
    await app.settle(tester);

    expect(app.navigationController.state.tab, AppTabModel.settings);
    expect(app.navigationController.state.cookiesImport?.returnTab, AppTabModel.downloads);

    app.authenticationRepository.importResult = (
      failure: null,
      data: AccountSessionModel.cookiesFile(cookiesFilePath: r'C:\cookies.txt', importedAt: DateTime(2026, 9, 16)),
    );
    await app.authorizationController.importCookies();
    await app.settle(tester);

    expect(app.videoRepository.downloads, hasLength(3));
    expect(find.byType(FailedDownloadTile), findsNothing);

    await app.close();
  });
}
