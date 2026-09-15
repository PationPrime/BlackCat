#ifndef RUNNER_WINDOW_CONSTANTS_H_
#define RUNNER_WINDOW_CONSTANTS_H_

// Main window class. A second copy of the app finds the running one by
// the class and the title
inline constexpr wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";

inline constexpr wchar_t kWindowTitle[] = L"YT Download";

// Held by the running copy of the app for its whole lifetime
inline constexpr wchar_t kSingleInstanceMutexName[] =
    L"YTDownloadSingleInstanceMutex";

// Initial window size in logical pixels. The minimum size is set from Dart
inline constexpr unsigned int kDefaultWindowWidth = 760;
inline constexpr unsigned int kDefaultWindowHeight = 820;

#endif  // RUNNER_WINDOW_CONSTANTS_H_
