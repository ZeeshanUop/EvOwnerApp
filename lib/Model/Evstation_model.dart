class EvStation {
  final String name;
  final String location;
  final double latitude;
  final double longitude;
  final int availableSlots;
  final String imagePath;

  EvStation({
    required this.name,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.availableSlots,
    required this.imagePath,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'location': location,
    'latitude': latitude,
    'longitude': longitude,
    'availableSlots': availableSlots,
    'imagePath': imagePath,
  };

  factory EvStation.fromJson(Map<String, dynamic> json) => EvStation(
    name: json['name'],
    location: json['location'],
    latitude: json['latitude'],
    longitude: json['longitude'],
    availableSlots: json['availableSlots'],
    imagePath: json['imagePath'],
  );
}
