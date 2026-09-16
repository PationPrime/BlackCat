import 'package:equatable/equatable.dart';

enum AccountSessionSource {
  /// Signed in through the app sign-in window
  signInWindow,

  /// cookies.txt imported in the settings
  cookiesFile,
}

/// Signed-in YouTube account: where its cookies came from
class AccountSessionModel extends Equatable {
  final AccountSessionSource source;

  /// The imported cookies.txt; `null` for the sign-in window
  final String? cookiesFilePath;
  final DateTime? importedAt;

  const AccountSessionModel.signInWindow()
    : source = AccountSessionSource.signInWindow,
      cookiesFilePath = null,
      importedAt = null;

  const AccountSessionModel.cookiesFile({
    required String this.cookiesFilePath,
    required DateTime this.importedAt,
  }) : source = AccountSessionSource.cookiesFile;

  bool get isImported => source == AccountSessionSource.cookiesFile;

  @override
  List<Object?> get props => [source, cookiesFilePath, importedAt];
}
