// DO NOT EDIT. This is code generated via package:easy_localization/generate.dart

// ignore_for_file: prefer_single_quotes, avoid_renaming_method_parameters, constant_identifier_names

import 'dart:ui';

import 'package:easy_localization/easy_localization.dart' show AssetLoader;

class CodegenLoader extends AssetLoader{
  const CodegenLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) {
    return Future.value(mapLocales[locale.toString()]);
  }

  static const Map<String,dynamic> _en_US = {
  "app": {
    "title": "YT Download",
    "common": {
      "file_size": {
        "bytes": "{value} B",
        "kilobytes": "{value} KB",
        "megabytes": "{value} MB",
        "gigabytes": "{value} GB"
      }
    },
    "authorization": {
      "sign_in": "Sign in to YouTube",
      "checking": "Checking sign-in…",
      "waiting": "Waiting for sign-in…",
      "signed_in": "Account connected",
      "sign_out": "Sign out",
      "window_title": "Sign in to YouTube"
    },
    "window": {
      "minimize": "Minimize",
      "maximize": "Maximize",
      "restore": "Restore down",
      "close": "Close"
    },
    "tray": {
      "open": "Open YT Download",
      "hide": "Minimize to tray",
      "quit": "Quit",
      "no_active_download": "No active download"
    },
    "downloader": {
      "url_hint": "https://www.youtube.com/watch?v=...",
      "buttons": {
        "search": "Search",
        "searching": "Searching…",
        "show_in_folder": "Show in folder",
        "sign_in_and_retry": "Sign in to YouTube and retry",
        "refresh_sign_in_and_retry": "Refresh sign-in and retry",
        "add_video": "Add video",
        "settings": "Settings",
        "start_now": "Download now",
        "pause": "Pause",
        "resume": "Resume",
        "remove": "Remove",
        "retry": "Retry",
        "clear_finished": "Clear",
        "hide": "Hide",
        "reorder": "Drag to reorder"
      },
      "video": {
        "views": "{count} views",
        "quality": "Quality",
        "audio_only": "Audio only",
        "audio_only_m4a": "Audio only (M4A)"
      },
      "progress": {
        "preparing": "Preparing the download…",
        "downloading": "Downloading {percent}%",
        "downloaded": "{downloaded} of {total}",
        "speed": "{value}/s",
        "eta": "{value} left",
        "processing": "Merging video and audio…"
      },
      "sections": {
        "active": "Active download",
        "queue": "Download queue",
        "finished": "Downloaded"
      },
      "empty": {
        "active": "No active download. Add a video and it will start downloading right away.",
        "queue": "The queue is empty. Videos added during a download will line up here.",
        "finished": "Downloaded videos will appear here."
      },
      "task": {
        "queued": "Queued",
        "queued_with_progress": "Queued · {percent}% downloaded",
        "paused": "Paused · {percent}%",
        "completed_at": "Downloaded {date}",
        "failed": "Error"
      },
      "dialog": {
        "title": "Add video",
        "add_to_queue": "Add to queue",
        "download_now": "Download",
        "cancel": "Cancel"
      },
      "remove_dialog": {
        "title": "Remove the video?",
        "message": "“{title}” is {percent}% downloaded. The partial file will be deleted from the device, and the download will have to start over.",
        "confirm": "Remove and delete file",
        "cancel": "Cancel"
      },
      "clear_finished_dialog": {
        "title": "Clear the downloaded list?",
        "message": "The videos stay in the download folder: only their records and thumbnails are removed from the app.",
        "confirm": "Clear",
        "cancel": "Cancel"
      }
    },
    "settings": {
      "title": "Settings",
      "back": "Back",
      "download_directory": {
        "title": "Download folder",
        "description": "Finished videos are saved here. A new folder applies to the next downloads; partial files are kept in the app folder until the download finishes.",
        "default_badge": "Default",
        "change": "Change…",
        "reset": "Back to Downloads",
        "open": "Open folder",
        "picker_confirm": "Select folder"
      },
      "language": {
        "title": "Language",
        "description": "App interface language."
      }
    },
    "errors": {
      "unknown": "Something went wrong: {error}",
      "network": {
        "no_connection": "No connection to YouTube.",
        "timeout": "YouTube is taking too long to respond.",
        "canceled": "The download was canceled.",
        "forbidden": "YouTube rejected the request (403). Try again: the stream links may have expired.",
        "rate_limited": "YouTube has temporarily limited requests (429). Please wait a bit.",
        "http_status": "YouTube responded with error {status}.",
        "unexpected": "Network error: {error}"
      },
      "video": {
        "not_youtube_url": "This is not a YouTube video link.",
        "player_config": "YouTube changed the player page: its settings could not be read.",
        "unplayable": "YouTube does not serve this video ({status}).",
        "streams_unavailable": "YouTube did not provide direct stream links for this video.",
        "player_parse": "Could not parse the YouTube player: {error}",
        "challenge": "Could not solve the YouTube check ({type}): {error}",
        "quality_unavailable": "The selected quality is no longer available. Add the video again.",
        "unknown_quality": "Unknown quality: {quality}",
        "mux": "Could not build the file: {error}",
        "stream_interrupted": "YouTube keeps interrupting the stream download. Try again.",
        "web_view_runtime": "Downloading requires Microsoft Edge WebView2 Runtime.",
        "js_engine": "The built-in JavaScript engine (WebView2) returned an error: {error}",
        "destination_unavailable": "Could not save the file to “{path}”: {error}"
      },
      "authentication": {
        "web_view_runtime": "Signing in requires Microsoft Edge WebView2 Runtime.",
        "session_not_issued": "Sign-in was not completed: YouTube did not issue account cookies. Try again."
      },
      "settings": {
        "picker": "Could not open the folder picker: {error}",
        "storage": "Could not save the settings: {error}"
      },
      "download_queue": {
        "storage": "Could not save the download queue: {error}"
      }
    }
  }
};
static const Map<String,dynamic> _ru_RU = {
  "app": {
    "title": "YT Download",
    "common": {
      "file_size": {
        "bytes": "{value} Б",
        "kilobytes": "{value} КБ",
        "megabytes": "{value} МБ",
        "gigabytes": "{value} ГБ"
      }
    },
    "authorization": {
      "sign_in": "Войти в YouTube",
      "checking": "Проверяем вход…",
      "waiting": "Ждём вход…",
      "signed_in": "Аккаунт подключён",
      "sign_out": "Выйти",
      "window_title": "Вход в YouTube"
    },
    "window": {
      "minimize": "Свернуть",
      "maximize": "Развернуть",
      "restore": "Восстановить",
      "close": "Закрыть"
    },
    "tray": {
      "open": "Открыть YT Download",
      "hide": "Свернуть в трей",
      "quit": "Выйти",
      "no_active_download": "Нет активной загрузки"
    },
    "downloader": {
      "url_hint": "https://www.youtube.com/watch?v=...",
      "buttons": {
        "search": "Найти",
        "searching": "Ищем…",
        "show_in_folder": "Показать в папке",
        "sign_in_and_retry": "Войти в YouTube и повторить",
        "refresh_sign_in_and_retry": "Обновить вход и повторить",
        "add_video": "Добавить видео",
        "settings": "Настройки",
        "start_now": "Скачать сейчас",
        "pause": "Пауза",
        "resume": "Продолжить",
        "remove": "Убрать",
        "retry": "Повторить",
        "clear_finished": "Очистить",
        "hide": "Скрыть",
        "reorder": "Перетащите, чтобы изменить порядок"
      },
      "video": {
        "views": "{count} просмотров",
        "quality": "Качество",
        "audio_only": "Только звук",
        "audio_only_m4a": "Только звук (M4A)"
      },
      "progress": {
        "preparing": "Готовим загрузку…",
        "downloading": "Скачивание {percent}%",
        "downloaded": "{downloaded} из {total}",
        "speed": "{value}/с",
        "eta": "осталось {value}",
        "processing": "Склеиваем видео и звук…"
      },
      "sections": {
        "active": "Активная загрузка",
        "queue": "Очередь скачивания",
        "finished": "Скачанные"
      },
      "empty": {
        "active": "Нет активной загрузки. Добавьте видео — оно сразу начнёт скачиваться.",
        "queue": "Очередь пуста. Видео, добавленные во время загрузки, встанут сюда.",
        "finished": "Здесь появятся скачанные видео."
      },
      "task": {
        "queued": "В очереди",
        "queued_with_progress": "В очереди · скачано {percent}%",
        "paused": "На паузе · {percent}%",
        "completed_at": "Скачано {date}",
        "failed": "Ошибка"
      },
      "dialog": {
        "title": "Добавить видео",
        "add_to_queue": "Добавить в очередь",
        "download_now": "Скачать",
        "cancel": "Отмена"
      },
      "remove_dialog": {
        "title": "Убрать видео?",
        "message": "«{title}» скачано на {percent}%. Недокачанный файл удалится с устройства, и загрузку придётся начинать заново.",
        "confirm": "Убрать и удалить файл",
        "cancel": "Отмена"
      },
      "clear_finished_dialog": {
        "title": "Очистить список скачанных?",
        "message": "Видео останутся в папке загрузок: из приложения пропадут только записи о них и превью.",
        "confirm": "Очистить",
        "cancel": "Отмена"
      }
    },
    "settings": {
      "title": "Настройки",
      "back": "Назад",
      "download_directory": {
        "title": "Папка для загрузок",
        "description": "Сюда сохраняются готовые видео. Новая папка применится к следующим загрузкам; недокачанные файлы до конца загрузки хранятся в папке приложения.",
        "default_badge": "По умолчанию",
        "change": "Изменить…",
        "reset": "Вернуть «Загрузки»",
        "open": "Открыть папку",
        "picker_confirm": "Выбрать папку"
      },
      "language": {
        "title": "Язык",
        "description": "Язык интерфейса приложения."
      }
    },
    "errors": {
      "unknown": "Что-то пошло не так: {error}",
      "network": {
        "no_connection": "Нет соединения с YouTube.",
        "timeout": "YouTube слишком долго не отвечает.",
        "canceled": "Загрузка отменена.",
        "forbidden": "YouTube отклонил запрос (403). Попробуйте ещё раз: ссылки на потоки могли устареть.",
        "rate_limited": "YouTube временно ограничил запросы (429). Подождите немного.",
        "http_status": "YouTube ответил ошибкой {status}.",
        "unexpected": "Ошибка сети: {error}"
      },
      "video": {
        "not_youtube_url": "Это не ссылка на YouTube-видео.",
        "player_config": "YouTube изменил страницу плеера: не удалось прочитать её настройки.",
        "unplayable": "YouTube не отдаёт это видео ({status}).",
        "streams_unavailable": "YouTube не дал прямых ссылок на потоки этого видео.",
        "player_parse": "Не удалось разобрать плеер YouTube: {error}",
        "challenge": "Не удалось решить проверку YouTube ({type}): {error}",
        "quality_unavailable": "Выбранное качество больше недоступно. Добавьте видео заново.",
        "unknown_quality": "Неизвестное качество: {quality}",
        "mux": "Не удалось собрать файл: {error}",
        "stream_interrupted": "YouTube обрывает загрузку потока. Попробуйте ещё раз.",
        "web_view_runtime": "Для скачивания нужен Microsoft Edge WebView2 Runtime.",
        "js_engine": "Встроенный JavaScript-движок (WebView2) вернул ошибку: {error}",
        "destination_unavailable": "Не удалось сохранить файл в папку «{path}»: {error}"
      },
      "authentication": {
        "web_view_runtime": "Для входа нужен Microsoft Edge WebView2 Runtime.",
        "session_not_issued": "Вход не завершён: YouTube не выдал cookies аккаунта. Попробуйте ещё раз."
      },
      "settings": {
        "picker": "Не удалось открыть выбор папки: {error}",
        "storage": "Не удалось сохранить настройки: {error}"
      },
      "download_queue": {
        "storage": "Не удалось сохранить очередь загрузок: {error}"
      }
    }
  }
};
static const Map<String, Map<String,dynamic>> mapLocales = {"en_US": _en_US, "ru_RU": _ru_RU};
}
