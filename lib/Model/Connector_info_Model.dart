import 'package:flutter/material.dart';

class ConnectorInfo {
  final String name;
  final String power;
  final String price;
  final int totalSlots;
  final int availableSlots;
  final int bookedSlots;

  ConnectorInfo({
    required this.name,
    required this.power,
    required this.price,
    required this.totalSlots,
    required this.availableSlots,
    this.bookedSlots = 0,
  });

  /// Dynamically calculate available points
  // int get availableSlots => (totalSlots - bookedSlots).clamp(0, totalSlots);

  /// Status label
  String get availability {
    if (totalSlots == 0) return 'Unknown';
    if (availableSlots == 0) return 'Busy';
    return 'Available';
  }

  /// Status color
  Color get availabilityColor {
    if (totalSlots == 0) return Colors.grey;
    if (availableSlots == 0) return Colors.red;
    if (availableSlots < totalSlots) return Colors.orange;
    return Colors.green;
  }

  factory ConnectorInfo.fromJson(Map<String, dynamic> json, {int bookedSlots = 0}) {
    return ConnectorInfo(
      name: json['name'] ?? '',
      power: json['power'] ?? '',
      price: json['price'] ?? '',
      availableSlots: (json['availablePoints'] as num?)?.toInt() ?? 0,
      totalSlots: (json['totalSlots'] as num?)?.toInt() ?? 0,
      bookedSlots: bookedSlots,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'power': power,
      'price': price,
      'totalSlots': totalSlots,
     'bookedSlots':bookedSlots,
      // bookedSlots not stored in Firestore
    };
  }
}
