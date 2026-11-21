import 'package:material_ui/material_ui.dart';

import 'constants.dart';

/// "Honda Activa 6G" from the booking label; falls back to the category name
/// for bookings made before customers could save vehicles.
String vehicleName(String? label, String category, {bool withPlate = false}) {
  final l = label?.trim() ?? '';
  if (l.isEmpty) return PartnerConstants.vehicleFor(category).title;
  return withPlate ? l : l.split(' • ').first;
}

/// Number plate part of the label ("WB38AB1234"), if any.
String? vehiclePlate(String? label) {
  final parts = (label ?? '').split(' • ');
  return parts.length > 1 && parts[1].trim().isNotEmpty
      ? parts[1].trim()
      : null;
}

class VehicleImage extends StatelessWidget {
  const VehicleImage({
    super.key,
    required this.category,
    this.bodyType,
    this.height = 48,
  });

  final String category;
  final String? bodyType;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      PartnerConstants.vehicleAsset(bodyType: bodyType, category: category),
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => Icon(
        PartnerConstants.vehicleFor(category).icon,
        size: height * 0.6,
        color: PartnerConstants.primaryColor,
      ),
    );
  }
}
