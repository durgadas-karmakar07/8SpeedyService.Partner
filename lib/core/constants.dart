import 'package:material_ui/material_ui.dart';

/// App-wide constants for the 8SpeedyService Partner (mechanic) app.
/// Shares the same Supabase backend as the customer app.
class PartnerConstants {
  PartnerConstants._();

  // ---------------------------------------------------------------------------
  // Backend (same keys as customer app: --dart-define-from-file=../env/prod.json)
  // ---------------------------------------------------------------------------

  // ignore: constant_identifier_names
  static const String SUPABASE_URL = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://your-project-id.supabase.co',
  );

  // ignore: constant_identifier_names
  static const String SUPABASE_ANON_KEY = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'your-supabase-anon-key',
  );

  static bool get isBackendConfigured =>
      !SUPABASE_URL.contains('your-project-id') &&
      !SUPABASE_ANON_KEY.contains('your-supabase-anon-key');

  // ---------------------------------------------------------------------------
  // Brand
  // ---------------------------------------------------------------------------

  static const String appName = '8Speedy Partner';

  /// Must match `version:` in pubspec.yaml (without +build).
  /// Compared with `app_config.min_partner_version` for force updates.
  static const String appVersion = '1.0.0';
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.speedyservice.partner';

  static const String cityName = 'Durgapur';
  static const Color primaryColor = Color(0xFFFF5722);
  static const Color darkColor = Color(0xFF1E293B);
  static const Color backgroundColor = Color(0xFFF1F5F9);
  static const Color successColor = Color(0xFF16A34A);
  static const Color warningColor = Color(0xFFD97706);
  static const Color dangerColor = Color(0xFFDC2626);

  // ---------------------------------------------------------------------------
  // Map
  // ---------------------------------------------------------------------------

  static const double defaultLat = 23.5411;
  static const double defaultLng = 87.2915;
  static const String osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String osmUserAgentPackageName = 'com.speedyservice.partner';

  // ---------------------------------------------------------------------------
  // Timings
  // ---------------------------------------------------------------------------

  /// How often open requests are refreshed while online.
  static const Duration requestPollInterval = Duration(seconds: 8);

  /// How often the active job is re-checked (detects customer cancel).
  static const Duration jobPollInterval = Duration(seconds: 8);

  /// Location is re-sent at least this often so the mechanic stays visible
  /// on the customer radar (server hides mechanics silent for 20 min).
  static const Duration locationHeartbeat = Duration(seconds: 60);

  /// Minimum gap between two location uploads.
  static const Duration minUploadGap = Duration(seconds: 10);

  /// Requests within this distance are shown.
  static const int requestRadiusMeters = 10000;

  // ---------------------------------------------------------------------------
  // Booking statuses
  // ---------------------------------------------------------------------------

  static const String statusSearching = 'SEARCHING';
  static const String statusAccepted = 'ACCEPTED';
  static const String statusArrived = 'ARRIVED';
  static const String statusInProgress = 'IN_PROGRESS';
  static const String statusCompleted = 'COMPLETED';
  static const String statusCancelled = 'CANCELLED';

  // ---------------------------------------------------------------------------
  // Support
  // ---------------------------------------------------------------------------

  // Legal pages (GitHub Pages site from the `8SpeedyService` (gh-pages branch) repo).
  static const String legalBaseUrl =
      'https://durgadas-karmakar07.github.io/8SpeedyService';
  static const String privacyPolicyUrl = '$legalBaseUrl/privacy.html';
  static const String partnerTermsUrl = '$legalBaseUrl/partner-terms.html';
  static const String deleteAccountUrl = '$legalBaseUrl/delete-account.html';
  static const String websiteUrl = '$legalBaseUrl/';

  static const String supportPhoneNumber = '919635297320';
  static const String supportPhoneDisplay = '+91 96352 97320';
  static const String whatsappSupportUrl =
      'https://wa.me/919635297320?text=Hi%208SpeedyService%2C%20I%20am%20a%20partner%20mechanic%20and%20need%20help.';

  // ---------------------------------------------------------------------------
  // Vehicles
  // ---------------------------------------------------------------------------

  static const List<VehicleType> vehicleTypes = <VehicleType>[
    VehicleType('cycle_toto', 'Cycle / Toto', Icons.pedal_bike_rounded),
    VehicleType('two_wheeler', 'Bike / Scooty', Icons.two_wheeler_rounded),
    VehicleType('four_wheeler', 'Car / SUV', Icons.directions_car_rounded),
    VehicleType('heavy_vehicle', 'Heavy / Van', Icons.local_shipping_rounded),
  ];

  /// Illustration for a booking's vehicle (body type first, else category).
  static String vehicleAsset({String? bodyType, required String category}) {
    const bodies = <String>{
      'cycle', 'e_rickshaw', 'scooter', 'motorcycle', 'auto_rickshaw',
      'hatchback', 'sedan', 'suv', 'pickup', 'truck',
    };
    if (bodyType != null && bodies.contains(bodyType)) {
      return 'assets/vehicles/$bodyType.png';
    }
    switch (category) {
      case 'cycle_toto':
        return 'assets/vehicles/e_rickshaw.png';
      case 'four_wheeler':
        return 'assets/vehicles/hatchback.png';
      case 'heavy_vehicle':
        return 'assets/vehicles/pickup.png';
      default:
        return 'assets/vehicles/scooter.png';
    }
  }

  static VehicleType vehicleFor(String key) {
    for (final v in vehicleTypes) {
      if (v.key == key) return v;
    }
    return vehicleTypes[1];
  }

  /// Returns true when [current] is older than [minimum] (1.0.0 < 1.2.0).
  static bool isVersionOlder(String current, String minimum) {
    List<int> parse(String v) => v
        .split('+')
        .first
        .split('.')
        .map((part) => int.tryParse(part.trim()) ?? 0)
        .toList();
    final a = parse(current);
    final b = parse(minimum);
    for (var i = 0; i < 3; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x < y;
    }
    return false;
  }
}

class VehicleType {
  const VehicleType(this.key, this.title, this.icon);

  final String key;
  final String title;
  final IconData icon;
}
