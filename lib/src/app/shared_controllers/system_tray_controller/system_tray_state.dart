part of 'system_tray_controller.dart';

class SystemTrayState extends Equatable {
  /// The tray icon is shown: closing the window hides it there
  final bool isAvailable;

  /// Download whose title and progress the tray shows
  final DownloadTaskModel? activeTask;

  const SystemTrayState({this.isAvailable = false, this.activeTask});

  @override
  List<Object?> get props => [isAvailable, activeTask];

  SystemTrayState copyWith({
    bool? isAvailable,
    DownloadTaskModel? activeTask,
    bool clearActiveTask = false,
  }) => SystemTrayState(
    isAvailable: isAvailable ?? this.isAvailable,
    activeTask: clearActiveTask ? null : activeTask ?? this.activeTask,
  );
}

final class SystemTrayInitialState extends SystemTrayState {
  const SystemTrayInitialState();
}
