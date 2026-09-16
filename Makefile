clean:
	flutter clean
	flutter pub get
	flutter pub upgrade
	
get:
	flutter pub get
	flutter pub upgrade

build_runner:
	flutter pub run build_runner build --delete-conflicting-outputs

router:
	make build_runner

db:
	make build_runner

build_windows_release:
	flutter build windows --release

build_macos_release:
	flutter build macos --release

build_linux_release:
	flutter build linux --release

build_apk:
	flutter build apk --release

locale: 
	flutter pub get
	flutter pub run easy_localization:generate -S assets/lang -O lib/src/app/localization/lang/ -o codegen_loader.g.dart
	flutter pub get
	flutter pub run easy_localization:generate -S assets/lang  -f keys -O lib/src/app/localization/lang/ -o locale_keys.g.dart
	flutter pub get