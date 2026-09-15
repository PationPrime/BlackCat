part of 'app_window_controller.dart';

class AppWindowState extends Equatable {
  /// How the app draws the window frame on this platform
  final AppWindowFrameModel frame;
  final bool isMaximized;

  /// Closing the window hides it in the system tray instead of ending the app.
  /// Set once the tray icon is shown: without it the app could not be reopened
  final bool closesToTray;

  const AppWindowState({
    this.frame = const AppWindowFrameModel.system(),
    this.isMaximized = false,
    this.closesToTray = false,
  });

  @override
  List<Object?> get props => [frame, isMaximized, closesToTray];

  AppWindowState copyWith({
    AppWindowFrameModel? frame,
    bool? isMaximized,
    bool? closesToTray,
  }) => AppWindowState(
    frame: frame ?? this.frame,
    isMaximized: isMaximized ?? this.isMaximized,
    closesToTray: closesToTray ?? this.closesToTray,
  );
}

final class AppWindowInitialState extends AppWindowState {
  const AppWindowInitialState();
}
