import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_downloader/src/app/models/models.dart';
import 'package:youtube_downloader/src/app/shared_controllers/shared_controllers.dart';

void main() {
  test('по умолчанию открыта главная, selectTab переключает страницы', () {
    final controller = AppNavigationController();

    expect(controller.state.tab, AppTabModel.home);

    controller.selectTab(AppTabModel.downloads);

    expect(controller.state, const AppNavigationState(tab: AppTabModel.downloads));
  });

  test('импорт cookies: настройки с запросом, после импорта — страница, которая просила', () {
    final controller = AppNavigationController();

    controller.openCookiesImport(returnTab: AppTabModel.downloads);

    expect(controller.state.tab, AppTabModel.settings);
    expect(controller.state.cookiesImport, const CookiesImportRequest(id: 1, returnTab: AppTabModel.downloads));

    /// A repeated request is a new one: the settings scroll again
    controller.openCookiesImport(returnTab: AppTabModel.home);

    expect(controller.state.cookiesImport?.id, 2);

    controller.finishCookiesImport();

    expect(controller.state, const AppNavigationState());
  });

  test('уход из настроек отменяет запрос импорта; без запроса finishCookiesImport ничего не делает', () {
    final controller = AppNavigationController();

    controller.openCookiesImport(returnTab: AppTabModel.home);
    controller.selectTab(AppTabModel.settings);

    expect(controller.state.cookiesImport, isNotNull);

    controller.selectTab(AppTabModel.downloads);

    expect(controller.state.cookiesImport, isNull);

    controller.selectTab(AppTabModel.settings);
    controller.finishCookiesImport();

    expect(controller.state.tab, AppTabModel.settings);
  });
}
