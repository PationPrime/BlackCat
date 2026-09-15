import 'package:equatable/equatable.dart';

part 'app_window_event.dart';
part 'app_window_resize_edge.dart';

/// How the app draws the main window frame on the current platform
class AppWindowFrameModel extends Equatable {
  /// The app draws its own title bar instead of the system one
  final bool isCustom;

  /// The app draws minimize, maximize and close buttons. On macOS the native
  /// traffic light buttons stay
  final bool showsWindowButtons;

  /// Space on the left of the title bar left for native window buttons
  final double leadingInset;

  /// Window edges the app resizes itself: the platform provides no resize
  /// borders there once the system title bar is hidden
  final Set<AppWindowResizeEdge> resizeEdges;

  const AppWindowFrameModel({
    required this.isCustom,
    this.showsWindowButtons = false,
    this.leadingInset = 0,
    this.resizeEdges = const {},
  });

  /// The system draws the frame: mobile platforms, web and unsupported desktops
  const AppWindowFrameModel.system() : this(isCustom: false);

  @override
  List<Object?> get props => [
    isCustom,
    showsWindowButtons,
    leadingInset,
    resizeEdges,
  ];
}
