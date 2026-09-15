import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/constants.dart';

/// App settings on the device
abstract interface class LocalSettingsDataSource {
  /// `null` if the user has not chosen a folder
  Future<String?> getDownloadDirectory();

  Future<void> setDownloadDirectory(String path);

  Future<void> clearDownloadDirectory();

  /// Interface language code. `null` if the user has not chosen a language
  Future<String?> getLanguageCode();

  Future<void> setLanguageCode(String code);
}

final class LocalSettingsDataSourceImpl implements LocalSettingsDataSource {
  final SharedPreferencesAsync _preferences;

  LocalSettingsDataSourceImpl({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  @override
  Future<String?> getDownloadDirectory() =>
      _preferences.getString(StorageConstants.downloadDirectoryKey);

  @override
  Future<void> setDownloadDirectory(String path) =>
      _preferences.setString(StorageConstants.downloadDirectoryKey, path);

  @override
  Future<void> clearDownloadDirectory() =>
      _preferences.remove(StorageConstants.downloadDirectoryKey);

  @override
  Future<String?> getLanguageCode() =>
      _preferences.getString(StorageConstants.languageKey);

  @override
  Future<void> setLanguageCode(String code) =>
      _preferences.setString(StorageConstants.languageKey, code);
}
