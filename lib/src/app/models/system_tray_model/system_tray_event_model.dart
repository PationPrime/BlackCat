part of 'system_tray_menu_item_model.dart';

/// Interaction with the tray icon
sealed class SystemTrayEventModel extends Equatable {
  const SystemTrayEventModel();
}

/// Left click on the icon. Not reported on Linux: the shell opens the menu itself
final class SystemTrayIconClicked extends SystemTrayEventModel {
  const SystemTrayIconClicked();

  @override
  List<Object?> get props => [];
}

/// Right click on the icon. Not reported on Linux: the shell opens the menu itself
final class SystemTrayIconRightClicked extends SystemTrayEventModel {
  const SystemTrayIconRightClicked();

  @override
  List<Object?> get props => [];
}

final class SystemTrayMenuItemClicked extends SystemTrayEventModel {
  final String key;

  const SystemTrayMenuItemClicked(this.key);

  @override
  List<Object?> get props => [key];
}
