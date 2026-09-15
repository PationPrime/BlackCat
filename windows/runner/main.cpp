#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter_windows.h>
#include <windows.h>

#include <algorithm>

#include "flutter_window.h"
#include "utils.h"
#include "window_constants.h"

namespace {

// Brings the window of the already running copy to the front. The window may
// be hidden in the system tray, minimized or covered by other windows.
bool ActivateRunningInstance() {
  HWND window = ::FindWindow(kWindowClassName, kWindowTitle);

  if (!window) {
    return false;
  }

  if (!::IsWindowVisible(window)) {
    ::ShowWindow(window, SW_SHOW);
  }

  if (::IsIconic(window)) {
    ::ShowWindow(window, SW_RESTORE);
  }

  ::SetForegroundWindow(window);

  return true;
}

// Window size that fits the work area of the primary monitor, in logical
// pixels.
Win32Window::Size FittedSize(const RECT& work_area, double scale_factor) {
  const unsigned int work_width =
      static_cast<unsigned int>((work_area.right - work_area.left) / scale_factor);
  const unsigned int work_height =
      static_cast<unsigned int>((work_area.bottom - work_area.top) / scale_factor);

  return Win32Window::Size(std::min(kDefaultWindowWidth, work_width),
                           std::min(kDefaultWindowHeight, work_height));
}

// Origin that centers a window of |size| on the work area of the primary
// monitor, in logical pixels: Win32Window scales it by the monitor DPI.
Win32Window::Point CenteredOrigin(const RECT& work_area,
                                  const Win32Window::Size& size,
                                  double scale_factor) {
  const double left = work_area.left +
                      ((work_area.right - work_area.left) -
                       size.width * scale_factor) / 2;
  const double top = work_area.top +
                     ((work_area.bottom - work_area.top) -
                      size.height * scale_factor) / 2;

  return Win32Window::Point(
      static_cast<unsigned int>(std::max(0.0, left / scale_factor)),
      static_cast<unsigned int>(std::max(0.0, top / scale_factor)));
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Only one copy of the app runs: downloads, the queue database and the tray
  // icon belong to it. Launching the app again shows the running window.
  HANDLE single_instance_mutex =
      ::CreateMutex(nullptr, TRUE, kSingleInstanceMutexName);

  if (::GetLastError() == ERROR_ALREADY_EXISTS) {
    ActivateRunningInstance();

    if (single_instance_mutex) {
      ::CloseHandle(single_instance_mutex);
    }

    return EXIT_SUCCESS;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  HMONITOR primary_monitor =
      ::MonitorFromPoint(POINT{0, 0}, MONITOR_DEFAULTTOPRIMARY);
  MONITORINFO monitor_info{sizeof(MONITORINFO)};
  ::GetMonitorInfo(primary_monitor, &monitor_info);
  const double scale_factor =
      FlutterDesktopGetDpiForMonitor(primary_monitor) / 96.0;

  FlutterWindow window(project);
  Win32Window::Size size = FittedSize(monitor_info.rcWork, scale_factor);
  Win32Window::Point origin =
      CenteredOrigin(monitor_info.rcWork, size, scale_factor);
  if (!window.Create(kWindowTitle, origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();

  if (single_instance_mutex) {
    ::ReleaseMutex(single_instance_mutex);
    ::CloseHandle(single_instance_mutex);
  }

  return EXIT_SUCCESS;
}
