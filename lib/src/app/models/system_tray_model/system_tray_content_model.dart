part of 'system_tray_menu_item_model.dart';

/// Everything the tray icon shows: the context menu and the tooltip
final class SystemTrayContentModel extends Equatable {
  final List<SystemTrayMenuItemModel> menu;
  final String toolTip;

  const SystemTrayContentModel({required this.menu, required this.toolTip});

  @override
  List<Object?> get props => [menu, toolTip];
}
