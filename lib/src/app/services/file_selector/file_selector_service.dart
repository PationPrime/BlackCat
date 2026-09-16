import 'package:file_selector/file_selector.dart';

/// System folder and file picker dialogs
abstract interface class FileSelectorService {
  /// Path to the selected folder. `null` if the user closed the dialog
  Future<String?> pickDirectory({
    String? initialDirectory,
    String? confirmButtonText,
  });

  /// Path to the selected file with one of [extensions] (without the dot).
  /// `null` if the user closed the dialog
  Future<String?> pickFile({
    required String typeLabel,
    required List<String> extensions,
    List<String> mimeTypes = const [],
    String? initialDirectory,
    String? confirmButtonText,
  });
}

class FileSelectorServiceImpl implements FileSelectorService {
  const FileSelectorServiceImpl();

  @override
  Future<String?> pickDirectory({
    String? initialDirectory,
    String? confirmButtonText,
  }) => getDirectoryPath(
    initialDirectory: initialDirectory,
    confirmButtonText: confirmButtonText,
  );

  @override
  Future<String?> pickFile({
    required String typeLabel,
    required List<String> extensions,
    List<String> mimeTypes = const [],
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    final file = await openFile(
      acceptedTypeGroups: [
        XTypeGroup(
          label: typeLabel,
          extensions: extensions,
          mimeTypes: mimeTypes,
        ),
      ],
      initialDirectory: initialDirectory,
      confirmButtonText: confirmButtonText,
    );

    return file?.path;
  }
}
