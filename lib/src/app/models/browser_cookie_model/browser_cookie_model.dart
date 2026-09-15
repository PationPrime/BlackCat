import 'package:equatable/equatable.dart';

/// Cookie из профиля WebView2 или из cookies.txt
class BrowserCookieModel extends Equatable {
  final String name;
  final String value;
  final String domain;
  final String path;
  final DateTime? expires;
  final bool secure;
  final bool httpOnly;
  final bool sessionOnly;

  const BrowserCookieModel({
    required this.name,
    required this.value,
    required this.domain,
    this.path = '/',
    this.expires,
    this.secure = false,
    this.httpOnly = false,
    this.sessionOnly = false,
  });

  @override
  List<Object?> get props => [
    name,
    value,
    domain,
    path,
    expires,
    secure,
    httpOnly,
    sessionOnly,
  ];
}
