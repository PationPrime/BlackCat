part of 'app_window_frame_model.dart';

/// Changes of the main window reported by the platform
enum AppWindowEvent {
  /// The user closes the window: the close button, Alt+F4, the taskbar menu
  closeRequested,
  maximized,
  unmaximized,
  minimized,
  restored,
  enteredFullScreen,
  leftFullScreen,
  shown,
  hidden,
}
