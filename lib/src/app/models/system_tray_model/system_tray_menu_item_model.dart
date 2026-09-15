import 'package:equatable/equatable.dart';

part 'system_tray_content_model.dart';
part 'system_tray_event_model.dart';

/// Item of the tray icon context menu
sealed class SystemTrayMenuItemModel extends Equatable {
  const SystemTrayMenuItemModel();
}

/// Clickable item. [key] comes back in [SystemTrayMenuItemClicked]
final class SystemTrayMenuActionModel extends SystemTrayMenuItemModel {
  final String key;
  final String label;
  final bool enabled;

  const SystemTrayMenuActionModel({
    required this.key,
    required this.label,
    this.enabled = true,
  });

  @override
  List<Object?> get props => [key, label, enabled];
}

final class SystemTrayMenuSeparatorModel extends SystemTrayMenuItemModel {
  const SystemTrayMenuSeparatorModel();

  @override
  List<Object?> get props => [];
}
