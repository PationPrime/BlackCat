import 'package:file_selector/file_selector.dart';

/// System folder picker dialog
abstract interface class DirectoryPickerService {
  /// Path to the selected folder. `null` if the user closed the dialog
  Future<String?> pickDirectory({
    String? initialDirectory,
    String? confirmButtonText,
  });
}

class DirectoryPickerServiceImpl implements DirectoryPickerService {
  const DirectoryPickerServiceImpl();

  @override
  Future<String?> pickDirectory({
    String? initialDirectory,
    String? confirmButtonText,
  }) => getDirectoryPath(
    initialDirectory: initialDirectory,
    confirmButtonText: confirmButtonText,
  );
}
