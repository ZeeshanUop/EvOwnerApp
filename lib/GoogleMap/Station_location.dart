import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../core/constant.dart';

class ChargerMapScreen extends StatefulWidget {
  final List<LatLng> polylinePoints;
  final List<Map<String, dynamic>> stationData;

  const ChargerMapScreen({
    Key? key,
    required this.polylinePoints,
    required this.stationData,
  }) : super(key: key);

  @override
  State<ChargerMapScreen> createState() => _ChargerMapScreenState();
}

class _ChargerMapScreenState extends State<ChargerMapScreen> {
  GoogleMapController? _mapController;
  BitmapDescriptor? _greenIcon;
  Position? userPosition;
  Map<String, dynamic>? selectedStation;
  String? _selectedDistanceText;

  // ✅ Load API key from .env
  final apiKey = ApiKeys.googleMaps;

  @override
  void initState() {
    super.initState();
    _loadCustomMarker();
    _getCurrentLocation();
  }

  Future<void> _loadCustomMarker() async {
    _greenIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'Assets/A01.png',
    );
    setState(() {});
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) return;

    userPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() {});
  }

  Future<String> _getRoadDistanceTime(double destLat, double destLng) async {
    if (userPosition == null) return "Locating...";

    final origin = '${userPosition!.latitude},${userPosition!.longitude}';
    final destination = '$destLat,$destLng';

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/distancematrix/json'
          '?origins=$origin&destinations=$destination'
          '&mode=driving&units=metric&key=$apiKey',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final elements = data['rows'][0]['elements'][0];
        if (elements['status'] == 'OK') {
          final distance = elements['distance']['text'];
          final duration = elements['duration']['text'];
          return '$distance • $duration';
        }
      }
    } catch (e) {
      debugPrint('Distance Matrix API error: $e');
    }

    return "N/A";
  }

  void _fitAllMarkersAndPolyline() {
    if (_mapController == null) return;

    final allPoints = [
      ...widget.polylinePoints,
      ...widget.stationData.map((s) => LatLng(
        (s['latitude'] as num).toDouble(),
        (s['longitude'] as num).toDouble(),
      )),
    ];

    if (allPoints.isEmpty) return;

    double minLat = allPoints.first.latitude;
    double maxLat = allPoints.first.latitude;
    double minLng = allPoints.first.longitude;
    double maxLng = allPoints.first.longitude;

    for (var point in allPoints) {
      minLat = point.latitude < minLat ? point.latitude : minLat;
      maxLat = point.latitude > maxLat ? point.latitude : maxLat;
      minLng = point.longitude < minLng ? point.longitude : minLng;
      maxLng = point.longitude > maxLng ? point.longitude : maxLng;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 70),
      );
    });
  }

  void _launchMaps(LatLng destination) async {
    final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    final url =
        'https://www.google.com/maps/dir/?api=1&origin=${position.latitude},${position.longitude}'
        '&destination=${destination.latitude},${destination.longitude}&travelmode=driving';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  @override
  Widget build(BuildContext context) {
    final initialCenter = widget.polylinePoints.isNotEmpty
        ? widget.polylinePoints.first
        : widget.stationData.isNotEmpty
        ? LatLng(
      (widget.stationData[0]['latitude'] as num).toDouble(),
      (widget.stationData[0]['longitude'] as num).toDouble(),
    )
        : const LatLng(33.6844, 73.0479); // Fallback

    return Scaffold(
      appBar: AppBar(title: const Text("Charging Stations on Route")),
      body: GestureDetector(
        onTap: () => setState(() => selectedStation = null),
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(target: initialCenter, zoom: 12),
              onMapCreated: (controller) {
                _mapController = controller;
                Future.delayed(const Duration(milliseconds: 300), () {
                  _fitAllMarkersAndPolyline();
                });
              },
              polylines: {
                Polyline(
                  polylineId: const PolylineId("route"),
                  points: widget.polylinePoints,
                  color: Colors.lightBlue,
                  width: 4,
                  zIndex: 1,
                ),
              },
              markers: widget.stationData.map((station) {
                final LatLng pos = LatLng(
                  (station['latitude'] as num).toDouble(),
                  (station['longitude'] as num).toDouble(),
                );
                return Marker(
                  markerId: MarkerId(station['stationId']),
                  position: pos,
                  icon: _greenIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                  zIndex: 10,
                  infoWindow: InfoWindow(title: station['name']),
                  onTap: () async {
                    setState(() {
                      selectedStation = station;
                      _selectedDistanceText = null;
                    });

                    final distanceText = await _getRoadDistanceTime(
                      (station['latitude'] as num).toDouble(),
                      (station['longitude'] as num).toDouble(),
                    );

                    setState(() {
                      _selectedDistanceText = distanceText;
                    });
                  },
                );
              }).toSet(),
            ),
            AnimatedSlide(
              offset: selectedStation != null ? Offset(0, 0) : Offset(0, 1),
              duration: const Duration(milliseconds: 300),
              child: AnimatedOpacity(
                opacity: selectedStation != null ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: selectedStation == null
                    ? const SizedBox.shrink()
                    : Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16, left: 12, right: 12),
                    child: Container(
                      height: 140,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)],
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                bottomLeft: Radius.circular(16)),
                            child: Image.network(
                              selectedStation!['imageUrl'] ?? '',
                              width: 100,
                              height: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    selectedStation!['name'] ?? 'Station Name',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.black54),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    selectedStation!['location'] ?? 'Station Address',
                                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 5),
                                  Row(
                                    children: [
                                      Icon(Icons.star, color: Colors.amber, size: 20),
                                      Text(
                                        '${(selectedStation!['rating'] ?? 0).toStringAsFixed(1)}  ',
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                      Spacer(),
                                      Text(
                                        '${selectedStation!['totalSlots']}',
                                        style: const TextStyle(fontSize: 14, color: Colors.black54),
                                      ),
                                      const SizedBox(width: 2),
                                      const Text(
                                        'Charging Points',
                                        style: TextStyle(fontSize: 14, color: Colors.black54),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        _selectedDistanceText ?? 'Calculating...',
                                        style: const TextStyle(fontSize: 12, color: Colors.green),
                                      ),
                                      Spacer(),
                                      ElevatedButton(
                                        onPressed: () {
                                          _launchMaps(LatLng(
                                            (selectedStation!['latitude'] as num).toDouble(),
                                            (selectedStation!['longitude'] as num).toDouble(),
                                          ));
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          minimumSize: const Size(80, 36),
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: const Text("Get Direction", style: TextStyle(fontSize: 12,color: Colors.white)),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
