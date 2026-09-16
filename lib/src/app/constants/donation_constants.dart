import '../models/donation_platform_model/donation_platform_model.dart';

/// Where the developer accepts support, as in rconite
abstract final class DonationConstants {
  static const platforms = [
    DonationPlatformModel(
      kind: DonationPlatformKind.donationAlerts,
      title: 'DonationAlerts',
      url: 'https://www.donationalerts.com/r/pationprime',
      logoAsset: 'assets/donations/donation_alerts.png',
    ),
    DonationPlatformModel(
      kind: DonationPlatformKind.donatePay,
      title: 'DonatePay',
      url: 'https://donatepay.ru/don/1453481',
      logoAsset: 'assets/donations/donate_pay.png',
    ),
    DonationPlatformModel(
      kind: DonationPlatformKind.boosty,
      title: 'Boosty',
      url: 'https://boosty.to/pationprime',
      logoAsset: 'assets/donations/boosty.png',
    ),
  ];
}
