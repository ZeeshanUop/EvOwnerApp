import 'package:flutter/material.dart';
import '../Screens/MainScreens/Booking/Ev_booking screen.dart';

class BookingScreenRouteHandler extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;

    return EvBookingScreen(
      stationId: args['stationId'] ?? '',
      stationName: args['stationName'] ?? 'Unnamed Station',
      availableSlots: args['availableSlots'] ?? 0,
      stationImageUrl: args['stationImageUrl'],
      vehicleType: args['vehicleType'],
      vehicleModel: args['vehicleModel'],
      connectionType: args['connectionType'],
      chargePercentage: args['chargePercentage'],
    );
  }
}
