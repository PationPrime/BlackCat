// DO NOT EDIT. This is code generated via package:easy_localization/generate.dart

// ignore_for_file: prefer_single_quotes, avoid_renaming_method_parameters, constant_identifier_names

import 'dart:ui';

import 'package:easy_localization/easy_localization.dart' show AssetLoader;

class CodegenLoader extends AssetLoader {
  const CodegenLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) {
    return Future.value(mapLocales[locale.toString()]);
  }

  static const Map<String, dynamic> _en_US = {
    "app": {
      "title": "BlackCat",
      "common": {
        "file_size": {
          "bytes": "{value} B",
          "kilobytes": "{value} KB",
          "megabytes": "{value} MB",
          "gigabytes": "{value} GB",
        },
      },
      "authorization": {
        "sign_in": "Sign in to YouTube",
        "checking": "Checking sign-in…",
        "waiting": "Waiting for sign-in…",
        "signed_in": "Account connected",
        "sign_out": "Sign out",
        "window_title": "Sign in to YouTube",
      },
      "window": {
        "minimize": "Minimize",
        "maximize": "Maximize",
        "restore": "Restore down",
        "close": "Close",
      },
      "tray": {
        "open": "Open BlackCat",
        "hide": "Minimize to tray",
        "quit": "Quit",
        "no_active_download": "No active download",
      },
      "downloader": {
        "url_hint": "https://www.youtube.com/watch?v=...",
        "buttons": {
          "search": "Search",
          "searching": "Searching…",
          "show_in_folder": "Show in folder",
          "sign_in_and_retry": "Sign in",
          "refresh_sign_in_and_retry": "Refresh sign-in",
          "add_video": "Add video",
          "settings": "Settings",
          "start_now": "Download now",
          "pause": "Pause",
          "resume": "Resume",
          "remove": "Remove",
          "retry": "Retry",
          "clear_finished": "Clear",
          "hide": "Hide",
          "reorder": "Drag to reorder",
          "import_cookies": "Import cookies.txt",
        },
        "video": {
          "views": "{count} views",
          "quality": "Quality",
          "audio_only": "Audio only",
          "audio_only_m4a": "Audio only (M4A)",
        },
        "progress": {
          "preparing": "Preparing the download…",
          "downloading": "Downloading {percent}%",
          "downloaded": "{downloaded} of {total}",
          "speed": "{value}/s",
          "eta": "{value} left",
          "processing": "Merging video and audio…",
        },
        "sections": {
          "active": "Active download",
          "queue": "Download queue",
          "failed": "Download errors",
          "finished": "Downloaded",
        },
        "empty": {
          "active":
              "No active download. Add a video on the Home page and it will start downloading right away.",
          "queue":
              "The queue is empty. Videos added during a download will line up here.",
          "finished": "Downloaded videos will appear here.",
        },
        "task": {
          "queued": "Queued",
          "queued_with_progress": "Queued · {percent}% downloaded",
          "paused": "Paused · {percent}%",
          "completed_at": "Downloaded {date}",
          "failed": "Error",
          "ytdlp_badge": "yt-dlp",
        },
        "dialog": {
          "title": "Add video",
          "add_to_queue": "Add to queue",
          "download_now": "Download",
          "cancel": "Cancel",
          "ytdlp_hint": "Searching with yt-dlp takes a few seconds.",
        },
        "remove_dialog": {
          "title": "Remove the video?",
          "message":
              "“{title}” is {percent}% downloaded. The partial file will be deleted from the device, and the download will have to start over.",
          "confirm": "Remove and delete file",
          "cancel": "Cancel",
        },
        "clear_finished_dialog": {
          "title": "Clear the downloaded list?",
          "message":
              "The videos stay in the download folder: only their records and thumbnails are removed from the app.",
          "confirm": "Clear",
          "cancel": "Cancel",
        },
        "dependencies": {
          "missing":
              "yt-dlp isn't installed: the built-in downloader will download the video.",
          "installing":
              "Installing yt-dlp: the built-in downloader works meanwhile.",
          "install": "Install",
          "show": "Show",
        },
      },
      "settings": {
        "title": "Settings",
        "download_directory": {
          "title": "Download folder",
          "description":
              "Finished videos are saved here. A new folder applies to the next downloads; partial files are kept in the app folder until the download finishes.",
          "default_badge": "Default",
          "change": "Change…",
          "reset": "Back to Downloads",
          "open": "Open folder",
          "picker_confirm": "Select folder",
        },
        "language": {
          "title": "Language",
          "description": "App interface language.",
        },
        "cookies": {
          "title": "YouTube cookies",
          "description":
              "If YouTube asks you to sign in or confirm you're not a bot and the app sign-in window doesn't work for you, import cookies from a browser where you're signed in to YouTube. Both yt-dlp and the built-in downloader use them.",
          "steps_title": "How to get cookies.txt",
          "step_1":
              "Open a new private (incognito) browser window and sign in to YouTube.",
          "step_2":
              "In the same tab, open youtube.com/robots.txt and export the youtube.com cookies in the Netscape format, for example with the “Get cookies.txt LOCALLY” extension for Chrome or “cookies.txt” for Firefox.",
          "step_3":
              "Close the private window so YouTube doesn't rotate these cookies, then choose the saved file below.",
          "guide": "Detailed guide in the yt-dlp FAQ",
          "guide_failed": "Couldn't open the link {url}",
          "warning":
              "The cookies file gives access to your account: don't share it with anyone.",
          "not_imported": "No file selected",
          "imported_at": "Imported {date}",
          "imported_badge": "In use",
          "sign_in_window_active":
              "You are signed in through the app window now. Importing cookies will replace that sign-in.",
          "choose": "Choose cookies.txt…",
          "importing": "Importing…",
          "remove": "Delete cookies",
          "picker_label": "Text files",
          "picker_confirm": "Import",
          "success": "Cookies imported: signed in to YouTube.",
        },
        "subtitle": "Download folder, interface language and YouTube cookies.",
      },
      "donations": {
        "title": "Support the project",
        "subtitle":
            "BlackCat is free and has no ads. If the app helps you, you can support its development.",
        "hero_title": "Thank you for using BlackCat!",
        "hero_description":
            "Your support helps update the app faster when YouTube changes something and add new features.",
        "platforms_title": "Ways to support",
        "open": "Open",
        "copy_link": "Copy link",
        "link_copied": "Link copied",
        "qr_hint": "Scan with your phone camera",
        "open_failed": "Couldn't open the link {url}",
        "thank_you": "Thank you for your support!",
        "platforms": {
          "donation_alerts": "One-time donation with a message",
          "donate_pay": "One-time donation",
          "boosty": "Subscription or one-time support",
        },
      },
      "errors": {
        "unknown": "Something went wrong: {error}",
        "network": {
          "no_connection": "No connection to YouTube.",
          "timeout": "YouTube is taking too long to respond.",
          "canceled": "The download was canceled.",
          "forbidden":
              "YouTube rejected the request (403). Try again: the stream links may have expired.",
          "rate_limited":
              "YouTube has temporarily limited requests (429). Please wait a bit.",
          "http_status": "YouTube responded with error {status}.",
          "unexpected": "Network error: {error}",
        },
        "video": {
          "not_youtube_url": "This is not a YouTube video link.",
          "player_config":
              "YouTube changed the player page: its settings could not be read.",
          "unplayable": "YouTube does not serve this video ({status}).",
          "streams_unavailable":
              "YouTube did not provide direct stream links for this video.",
          "player_parse": "Could not parse the YouTube player: {error}",
          "challenge": "Could not solve the YouTube check ({type}): {error}",
          "quality_unavailable":
              "The selected quality is no longer available. Add the video again.",
          "unknown_quality": "Unknown quality: {quality}",
          "mux": "Could not build the file: {error}",
          "stream_interrupted":
              "YouTube keeps interrupting the stream download. Try again.",
          "disk_write": "Could not write the file being downloaded: {error}",
          "disk_full":
              "Not enough disk space: the download needs {needed} more, {available} is free. Free up space and try again: the downloaded part is kept.",
          "disk_full_unknown_size":
              "Not enough disk space for the download. Free up space and try again: the downloaded part is kept.",
          "web_view_runtime":
              "Downloading requires Microsoft Edge WebView2 Runtime.",
          "js_engine":
              "The built-in JavaScript engine (WebView2) returned an error: {error}",
          "destination_unavailable":
              "Could not save the file to “{path}”: {error}",
          "ytdlp_not_found":
              "yt-dlp or a JavaScript runtime (Deno, Node.js 22+) wasn't found. Install them on the Home page.",
          "ytdlp_failed": "yt-dlp failed: {error}",
          "bot_check":
              "YouTube asks to confirm you're not a bot. Sign in to YouTube or import cookies.txt.",
          "age_restricted":
              "Age-restricted video: signing in to YouTube is required.",
          "members_only":
              "Members-only video: sign in with an account that has access.",
          "private_video": "This is a private video.",
          "video_unavailable": "The video is unavailable.",
        },
        "authentication": {
          "web_view_runtime":
              "Signing in requires Microsoft Edge WebView2 Runtime.",
          "session_not_issued":
              "Sign-in was not completed: YouTube did not issue account cookies. Try again.",
          "cookies_picker": "Couldn't open the file picker: {error}",
          "cookies_read": "Couldn't read the cookies file: {error}",
          "cookies_not_text":
              "Choose a .txt text file with cookies in the Netscape format. The selected file isn't a text file.",
          "cookies_too_large":
              "The file is too large for cookies.txt (over 5 MB). Export cookies for youtube.com only.",
          "cookies_json":
              "These cookies are in JSON format. Export them in the Netscape format (cookies.txt).",
          "cookies_format":
              "This doesn't look like cookies.txt: it has no lines in the Netscape format.",
          "cookies_no_youtube":
              "The file has no youtube.com cookies. Export cookies while youtube.com is open.",
          "cookies_no_session":
              "The file has no YouTube sign-in cookies. Sign in to YouTube in your browser and export the cookies again.",
          "cookies_expired":
              "The sign-in cookies have expired. Export a fresh cookies.txt.",
          "cookies_save": "Couldn't save the cookies: {error}",
        },
        "settings": {
          "picker": "Could not open the folder picker: {error}",
          "storage": "Could not save the settings: {error}",
        },
        "download_queue": {
          "storage": "Could not save the download queue: {error}",
        },
        "dependencies": {
          "unsupported_platform":
              "There are no ready-made yt-dlp and Deno builds for this system. Install them manually.",
          "download": "Couldn't download {name}: {error}",
          "checksum_missing":
              "Couldn't verify {name}: GitHub has no checksum for this file.",
          "checksum_mismatch":
              "The downloaded {name} didn't match the checksum on GitHub. Installation stopped and the file was deleted.",
          "extract": "Couldn't unpack {name}: {error}",
          "save": "Couldn't save {name} to the app folder: {error}",
          "not_working":
              "{name} is installed but doesn't start. An antivirus may have blocked it.",
          "canceled": "Installation canceled.",
          "network": {
            "no_connection": "no connection to GitHub.",
            "timeout": "GitHub is taking too long to respond.",
            "http_status": "GitHub responded with error {status}.",
          },
        },
        "player": {
          "folder_not_found":
              "The download folder is not found: {path}. Check that the drive is connected or choose another folder in the settings.",
          "storage": "Could not update the video list: {error}",
          "playback": "Could not play the video: {error}",
        },
      },
      "dependencies": {
        "install_dialog": {
          "title": "Installing yt-dlp",
          "description":
              "Videos are downloaded with yt-dlp, but it wasn't found on this computer. The app will download the official builds from GitHub into its own folder and verify their checksums. Python isn't needed.",
          "checking": "Checking what is already installed…",
          "yt_dlp_title": "yt-dlp",
          "yt_dlp_description": "Video download program",
          "js_runtime_title": "Deno",
          "js_runtime_description": "JavaScript runtime for YouTube checks",
          "status_waiting": "Waiting",
          "status_installed": "Already installed · {version}",
          "status_preparing": "Preparing…",
          "status_downloading": "Downloading: {received} of {total}",
          "status_downloading_unknown": "Downloading: {received}",
          "status_verifying": "Verifying checksum…",
          "status_extracting": "Unpacking…",
          "status_done": "Installed",
          "status_failed": "Not installed",
          "success": "Done: videos will be downloaded with yt-dlp {version}.",
          "cancel": "Cancel",
          "retry": "Retry",
          "close": "Close",
          "done": "Done",
        },
        "fallback_dialog": {
          "title": "yt-dlp isn't installed",
          "message_signed_in":
              "The yt-dlp components couldn't be installed, but you can still try to download videos: the app will use the built-in downloader with your YouTube sign-in.",
          "message_signed_out":
              "The yt-dlp components couldn't be installed. The built-in downloader can download videos too, but YouTube usually requires signing in: sign in to your account or import cookies.txt.",
          "reason": "Reason: {error}",
          "retry": "Retry installation",
          "add_video": "Add video",
          "sign_in": "Sign in",
          "import_cookies": "Import cookies.txt",
          "close": "Close",
        },
      },
      "navigation": {
        "home": "Home",
        "downloads": "Downloads",
        "player": "Player",
        "settings": "Settings",
        "donations": "Sponsor",
      },
      "home": {
        "title": "Home",
        "subtitle":
            "Paste a YouTube video link and press Enter, then choose the quality.",
        "added": "“{title}” was added to downloads.",
        "open_downloads": "Open downloads",
        "clear": "Clear",
        "direct": {
          "title": "Any link",
          "subtitle":
              "A check of the built-in downloader on its own: the file is downloaded with the same engine and settings as YouTube streams, only from another source. Nothing here is kept between launches.",
          "url_hint": "https://example.com/file.zip",
          "start": "Download file",
          "invalid_url": "The link must start with http:// or https://",
          "connections": "{value} connections",
          "saved": "Saved: {path}",
        },
      },
      "downloads": {
        "title": "Downloads",
        "subtitle": "Active download, queue and downloaded videos.",
        "add_video": "Add video",
      },
      "player": {
        "title": "Player",
        "subtitle":
            "Videos from the download folder. Playback resumes where you stopped.",
        "folder": "Folder: {path}",
        "open_folder": "Open folder",
        "refresh": "Refresh",
        "show_in_folder": "Show in folder",
        "play": "Watch",
        "videos_title": "Videos",
        "empty":
            "No videos in the download folder yet. Downloaded videos will appear here on their own.",
        "download_video": "Download a video",
        "stopped_at": "Stopped at {time}",
        "watched": "Watched",
        "seek_seconds": "{seconds} seconds",
        "retry": "Try again",
        "close": "Close",
        "controls": {
          "play": "Play (k)",
          "pause": "Pause (k)",
          "replay": "Replay (k)",
          "rewind": "Back 10 seconds (j)",
          "forward": "Forward 10 seconds (l)",
          "mute": "Mute (m)",
          "unmute": "Unmute (m)",
          "full_screen": "Full screen (f)",
          "exit_full_screen": "Exit full screen (f)",
          "speed": "Playback speed",
          "speed_normal": "Normal",
          "close": "Close (Esc)",
        },
      },
      "footer": {
        "idle": "No active downloads",
        "queued": "Queued: {count}",
        "open_downloads": "Open downloads",
      },
    },
  };
  static const Map<String, dynamic> _ru_RU = {
    "app": {
      "title": "BlackCat",
      "common": {
        "file_size": {
          "bytes": "{value} Б",
          "kilobytes": "{value} КБ",
          "megabytes": "{value} МБ",
          "gigabytes": "{value} ГБ",
        },
      },
      "authorization": {
        "sign_in": "Войти в YouTube",
        "checking": "Проверяем вход…",
        "waiting": "Ждём вход…",
        "signed_in": "Аккаунт подключён",
        "sign_out": "Выйти",
        "window_title": "Вход в YouTube",
      },
      "window": {
        "minimize": "Свернуть",
        "maximize": "Развернуть",
        "restore": "Восстановить",
        "close": "Закрыть",
      },
      "tray": {
        "open": "Открыть BlackCat",
        "hide": "Свернуть в трей",
        "quit": "Выйти",
        "no_active_download": "Нет активной загрузки",
      },
      "downloader": {
        "url_hint": "https://www.youtube.com/watch?v=...",
        "buttons": {
          "search": "Найти",
          "searching": "Ищем…",
          "show_in_folder": "Показать в папке",
          "sign_in_and_retry": "Войти",
          "refresh_sign_in_and_retry": "Обновить вход",
          "add_video": "Добавить видео",
          "settings": "Настройки",
          "start_now": "Скачать сейчас",
          "pause": "Пауза",
          "resume": "Продолжить",
          "remove": "Убрать",
          "retry": "Повторить",
          "clear_finished": "Очистить",
          "hide": "Скрыть",
          "reorder": "Перетащите, чтобы изменить порядок",
          "import_cookies": "Импортировать cookies.txt",
        },
        "video": {
          "views": "{count} просмотров",
          "quality": "Качество",
          "audio_only": "Только звук",
          "audio_only_m4a": "Только звук (M4A)",
        },
        "progress": {
          "preparing": "Готовим загрузку…",
          "downloading": "Скачивание {percent}%",
          "downloaded": "{downloaded} из {total}",
          "speed": "{value}/с",
          "eta": "осталось {value}",
          "processing": "Склеиваем видео и звук…",
        },
        "sections": {
          "active": "Активная загрузка",
          "queue": "Очередь скачивания",
          "failed": "Ошибка скачивания",
          "finished": "Скачанные",
        },
        "empty": {
          "active":
              "Нет активной загрузки. Добавьте видео на главной — оно сразу начнёт скачиваться.",
          "queue":
              "Очередь пуста. Видео, добавленные во время загрузки, встанут сюда.",
          "finished": "Здесь появятся скачанные видео.",
        },
        "task": {
          "queued": "В очереди",
          "queued_with_progress": "В очереди · скачано {percent}%",
          "paused": "На паузе · {percent}%",
          "completed_at": "Скачано {date}",
          "failed": "Ошибка",
          "ytdlp_badge": "yt-dlp",
        },
        "dialog": {
          "title": "Добавить видео",
          "add_to_queue": "Добавить в очередь",
          "download_now": "Скачать",
          "cancel": "Отмена",
          "ytdlp_hint": "Поиск через yt-dlp занимает несколько секунд.",
        },
        "remove_dialog": {
          "title": "Убрать видео?",
          "message":
              "«{title}» скачано на {percent}%. Недокачанный файл удалится с устройства, и загрузку придётся начинать заново.",
          "confirm": "Убрать и удалить файл",
          "cancel": "Отмена",
        },
        "clear_finished_dialog": {
          "title": "Очистить список скачанных?",
          "message":
              "Видео останутся в папке загрузок: из приложения пропадут только записи о них и превью.",
          "confirm": "Очистить",
          "cancel": "Отмена",
        },
        "dependencies": {
          "missing":
              "yt-dlp не установлен: видео скачается встроенным загрузчиком.",
          "installing":
              "Устанавливаем yt-dlp: пока работает встроенный загрузчик.",
          "install": "Установить",
          "show": "Показать",
        },
      },
      "settings": {
        "title": "Настройки",
        "download_directory": {
          "title": "Папка для загрузок",
          "description":
              "Сюда сохраняются готовые видео. Новая папка применится к следующим загрузкам; недокачанные файлы до конца загрузки хранятся в папке приложения.",
          "default_badge": "По умолчанию",
          "change": "Изменить…",
          "reset": "Вернуть «Загрузки»",
          "open": "Открыть папку",
          "picker_confirm": "Выбрать папку",
        },
        "language": {
          "title": "Язык",
          "description": "Язык интерфейса приложения.",
        },
        "cookies": {
          "title": "Cookies YouTube",
          "description":
              "Если YouTube просит войти или подтвердить, что вы не бот, а вход через окно приложения не подходит, импортируйте cookies браузера, в котором вы вошли в YouTube. Их используют и yt-dlp, и встроенный загрузчик.",
          "steps_title": "Как получить cookies.txt",
          "step_1":
              "Откройте новое приватное (инкогнито) окно браузера и войдите в YouTube.",
          "step_2":
              "В той же вкладке откройте youtube.com/robots.txt и экспортируйте cookies youtube.com в формате Netscape, например расширением «Get cookies.txt LOCALLY» для Chrome или «cookies.txt» для Firefox.",
          "step_3":
              "Закройте приватное окно, чтобы YouTube не сменил эти cookies, и выберите сохранённый файл ниже.",
          "guide": "Подробная инструкция в FAQ yt-dlp",
          "guide_failed": "Не удалось открыть ссылку {url}",
          "warning":
              "Файл cookies даёт доступ к вашему аккаунту: не передавайте его другим людям.",
          "not_imported": "Файл не выбран",
          "imported_at": "Импортирован {date}",
          "imported_badge": "Используется",
          "sign_in_window_active":
              "Сейчас используется вход через окно приложения. Импорт cookies заменит его.",
          "choose": "Выбрать cookies.txt…",
          "importing": "Импортируем…",
          "remove": "Удалить cookies",
          "picker_label": "Текстовые файлы",
          "picker_confirm": "Импортировать",
          "success": "Cookies импортированы: вход в YouTube выполнен.",
        },
        "subtitle": "Папка для загрузок, язык интерфейса и cookies YouTube.",
      },
      "donations": {
        "title": "Поддержать проект",
        "subtitle":
            "BlackCat бесплатный и без рекламы. Если приложение вам помогает, вы можете поддержать его развитие.",
        "hero_title": "Спасибо, что пользуетесь BlackCat!",
        "hero_description":
            "Поддержка помогает быстрее обновлять приложение, когда YouTube что-то меняет, и добавлять новые возможности.",
        "platforms_title": "Способы поддержки",
        "open": "Открыть",
        "copy_link": "Скопировать ссылку",
        "link_copied": "Ссылка скопирована",
        "qr_hint": "Отсканируйте камерой телефона",
        "open_failed": "Не удалось открыть ссылку {url}",
        "thank_you": "Спасибо за поддержку!",
        "platforms": {
          "donation_alerts": "Разовый донат с сообщением",
          "donate_pay": "Разовый донат",
          "boosty": "Подписка или разовая поддержка",
        },
      },
      "errors": {
        "unknown": "Что-то пошло не так: {error}",
        "network": {
          "no_connection": "Нет соединения с YouTube.",
          "timeout": "YouTube слишком долго не отвечает.",
          "canceled": "Загрузка отменена.",
          "forbidden":
              "YouTube отклонил запрос (403). Попробуйте ещё раз: ссылки на потоки могли устареть.",
          "rate_limited":
              "YouTube временно ограничил запросы (429). Подождите немного.",
          "http_status": "YouTube ответил ошибкой {status}.",
          "unexpected": "Ошибка сети: {error}",
        },
        "video": {
          "not_youtube_url": "Это не ссылка на YouTube-видео.",
          "player_config":
              "YouTube изменил страницу плеера: не удалось прочитать её настройки.",
          "unplayable": "YouTube не отдаёт это видео ({status}).",
          "streams_unavailable":
              "YouTube не дал прямых ссылок на потоки этого видео.",
          "player_parse": "Не удалось разобрать плеер YouTube: {error}",
          "challenge": "Не удалось решить проверку YouTube ({type}): {error}",
          "quality_unavailable":
              "Выбранное качество больше недоступно. Добавьте видео заново.",
          "unknown_quality": "Неизвестное качество: {quality}",
          "mux": "Не удалось собрать файл: {error}",
          "stream_interrupted":
              "YouTube обрывает загрузку потока. Попробуйте ещё раз.",
          "disk_write": "Не удалось записать скачиваемый файл: {error}",
          "disk_full":
              "Недостаточно места на диске: загрузке нужно ещё {needed}, свободно {available}. Освободите место и повторите загрузку: скачанное сохранится.",
          "disk_full_unknown_size":
              "Недостаточно места на диске для загрузки. Освободите место и повторите загрузку: скачанное сохранится.",
          "web_view_runtime":
              "Для скачивания нужен Microsoft Edge WebView2 Runtime.",
          "js_engine":
              "Встроенный JavaScript-движок (WebView2) вернул ошибку: {error}",
          "destination_unavailable":
              "Не удалось сохранить файл в папку «{path}»: {error}",
          "ytdlp_not_found":
              "Не найден yt-dlp или среда JavaScript (Deno, Node.js 22+). Установите их на главной странице.",
          "ytdlp_failed": "yt-dlp завершился с ошибкой: {error}",
          "bot_check":
              "YouTube просит подтвердить, что вы не бот. Войдите в аккаунт YouTube или импортируйте cookies.txt.",
          "age_restricted":
              "Видео с возрастным ограничением: нужен вход в аккаунт YouTube.",
          "members_only":
              "Видео только для спонсоров канала: нужен вход в аккаунт с доступом к нему.",
          "private_video": "Это приватное видео.",
          "video_unavailable": "Видео недоступно.",
        },
        "authentication": {
          "web_view_runtime":
              "Для входа нужен Microsoft Edge WebView2 Runtime.",
          "session_not_issued":
              "Вход не завершён: YouTube не выдал cookies аккаунта. Попробуйте ещё раз.",
          "cookies_picker": "Не удалось открыть выбор файла: {error}",
          "cookies_read": "Не удалось прочитать файл cookies: {error}",
          "cookies_not_text":
              "Нужен текстовый файл .txt с cookies в формате Netscape, а выбранный файл не текстовый.",
          "cookies_too_large":
              "Файл слишком большой для cookies.txt (больше 5 МБ). Экспортируйте cookies только для youtube.com.",
          "cookies_json":
              "Cookies сохранены в формате JSON. Экспортируйте их в формате Netscape (cookies.txt).",
          "cookies_format":
              "Файл не похож на cookies.txt: в нём нет ни одной строки в формате Netscape.",
          "cookies_no_youtube":
              "В файле нет cookies youtube.com. Экспортируйте cookies, когда открыт сайт youtube.com.",
          "cookies_no_session":
              "В файле нет cookies входа в аккаунт YouTube. Войдите в YouTube в браузере и экспортируйте cookies заново.",
          "cookies_expired":
              "Срок действия cookies входа истёк. Экспортируйте свежий cookies.txt.",
          "cookies_save": "Не удалось сохранить cookies: {error}",
        },
        "settings": {
          "picker": "Не удалось открыть выбор папки: {error}",
          "storage": "Не удалось сохранить настройки: {error}",
        },
        "download_queue": {
          "storage": "Не удалось сохранить очередь загрузок: {error}",
        },
        "dependencies": {
          "unsupported_platform":
              "Для этой системы нет готовых сборок yt-dlp и Deno. Установите их вручную.",
          "download": "Не удалось скачать {name}: {error}",
          "checksum_missing":
              "Не удалось проверить {name}: на GitHub нет контрольной суммы этого файла.",
          "checksum_mismatch":
              "Скачанный {name} не совпал с контрольной суммой на GitHub. Установка остановлена, файл удалён.",
          "extract": "Не удалось распаковать {name}: {error}",
          "save": "Не удалось сохранить {name} в папку приложения: {error}",
          "not_working":
              "{name} установлен, но не запускается. Возможно, его заблокировал антивирус.",
          "canceled": "Установка отменена.",
          "network": {
            "no_connection": "нет соединения с GitHub.",
            "timeout": "GitHub слишком долго не отвечает.",
            "http_status": "GitHub ответил ошибкой {status}.",
          },
        },
        "player": {
          "folder_not_found":
              "Папка загрузок не найдена: {path}. Проверьте, подключён ли диск, или выберите другую папку в настройках.",
          "storage": "Не удалось обновить список видео: {error}",
          "playback": "Не удалось воспроизвести видео: {error}",
        },
      },
      "dependencies": {
        "install_dialog": {
          "title": "Установка yt-dlp",
          "description":
              "Видео скачиваются через yt-dlp, но на компьютере его не нашлось. Приложение скачает официальные сборки с GitHub в свою папку и сверит их контрольные суммы. Python для этого не нужен.",
          "checking": "Проверяем, что уже установлено…",
          "yt_dlp_title": "yt-dlp",
          "yt_dlp_description": "Программа для скачивания видео",
          "js_runtime_title": "Deno",
          "js_runtime_description": "Среда JavaScript для проверок YouTube",
          "status_waiting": "Ожидает",
          "status_installed": "Уже установлен · {version}",
          "status_preparing": "Подготовка…",
          "status_downloading": "Скачивание: {received} из {total}",
          "status_downloading_unknown": "Скачивание: {received}",
          "status_verifying": "Проверка контрольной суммы…",
          "status_extracting": "Распаковка…",
          "status_done": "Установлен",
          "status_failed": "Не установлен",
          "success": "Готово: видео будут скачиваться через yt-dlp {version}.",
          "cancel": "Отменить",
          "retry": "Повторить",
          "close": "Закрыть",
          "done": "Готово",
        },
        "fallback_dialog": {
          "title": "yt-dlp не установлен",
          "message_signed_in":
              "Не удалось установить компоненты для yt-dlp, но вы всё равно можете попробовать скачать видео: приложение скачает его встроенным загрузчиком с вашим входом в YouTube.",
          "message_signed_out":
              "Не удалось установить компоненты для yt-dlp. Встроенный загрузчик тоже скачивает видео, но YouTube обычно требует входа: войдите в аккаунт или импортируйте cookies.txt.",
          "reason": "Причина: {error}",
          "retry": "Повторить установку",
          "add_video": "Добавить видео",
          "sign_in": "Войти",
          "import_cookies": "Импортировать cookies.txt",
          "close": "Закрыть",
        },
      },
      "navigation": {
        "home": "Главная",
        "downloads": "Загрузки",
        "player": "Плеер",
        "settings": "Настройки",
        "donations": "Поддержать",
      },
      "home": {
        "title": "Главная",
        "subtitle":
            "Вставьте ссылку на видео YouTube и нажмите Enter, затем выберите качество.",
        "added": "«{title}» добавлено в загрузки.",
        "open_downloads": "Открыть загрузки",
        "clear": "Очистить",
        "direct": {
          "title": "Любая ссылка",
          "subtitle":
              "Проверка самого загрузчика: файл скачивается тем же движком и с теми же настройками, что и потоки YouTube, только из другого источника. Между запусками здесь ничего не хранится.",
          "url_hint": "https://example.com/file.zip",
          "start": "Скачать файл",
          "invalid_url": "Ссылка должна начинаться с http:// или https://",
          "connections": "соединений: {value}",
          "saved": "Сохранено: {path}",
        },
      },
      "downloads": {
        "title": "Загрузки",
        "subtitle": "Активная загрузка, очередь и скачанные видео.",
        "add_video": "Добавить видео",
      },
      "player": {
        "title": "Плеер",
        "subtitle":
            "Видео из папки загрузок. Просмотр продолжится с того места, где вы остановились.",
        "folder": "Папка: {path}",
        "open_folder": "Открыть папку",
        "refresh": "Обновить",
        "show_in_folder": "Показать в папке",
        "play": "Смотреть",
        "videos_title": "Видео",
        "empty":
            "В папке загрузок пока нет видео. Скачанные видео появятся здесь сами.",
        "download_video": "Скачать видео",
        "stopped_at": "Остановились на {time}",
        "watched": "Просмотрено",
        "seek_seconds": "{seconds} секунд",
        "retry": "Повторить",
        "close": "Закрыть",
        "controls": {
          "play": "Смотреть (k)",
          "pause": "Пауза (k)",
          "replay": "Смотреть снова (k)",
          "rewind": "Назад на 10 секунд (j)",
          "forward": "Вперёд на 10 секунд (l)",
          "mute": "Выключить звук (m)",
          "unmute": "Включить звук (m)",
          "full_screen": "Во весь экран (f)",
          "exit_full_screen": "Выйти из полноэкранного режима (f)",
          "speed": "Скорость воспроизведения",
          "speed_normal": "Обычная",
          "close": "Закрыть (Esc)",
        },
      },
      "footer": {
        "idle": "Нет активных загрузок",
        "queued": "В очереди: {count}",
        "open_downloads": "Открыть загрузки",
      },
    },
  };
  static const Map<String, Map<String, dynamic>> mapLocales = {
    "en_US": _en_US,
    "ru_RU": _ru_RU,
  };
}
