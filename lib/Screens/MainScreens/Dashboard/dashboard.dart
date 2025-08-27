import 'dart:async';
import 'dart:convert';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:async/async.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';

import '../../../Model/Connector_info_Model.dart';
import '../Booking/Booking_History.dart';
import '../../../Model/chargingstation_model.dart';
import '../Notifications/NotificationScreen.dart';
import '../Profile/ProfileScreen.dart';
import '../EnrouteChargingStation/enroute_charging_station.dart';
import '../FIlterScreen/filterScreen.dart';
import '../StationDetailScreen/Nearby_station_screen.dart';
import '../SearchScreen/searchBar.dart';
import '../FavouritesScreen/favourites.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> with WidgetsBindingObserver {
  final Color primaryColor = Colors.green.shade700;
  int _currentIndex = 0;

  final iconList = <IconData>[
    Icons.home,
    Icons.route,
    Icons.book_online,
    Icons.favorite,
    Icons.person,
  ];

  Position? _currentPosition;
  String? _currentCity;
  StreamSubscription<Position>? _positionStreamSubscription;

  String? _selectedConnection;
  String? _selectedDistance;
  List<String>? _selectedSpeeds;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _getCurrentLocation());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionStreamSubscription?.cancel();
    super.dispose();
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _currentPosition == null) {
      _getCurrentLocation();
    }
  }
  Future<void> saveFcmTokenToFirestore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final fcmToken = await FirebaseMessaging.instance.getToken();

    if (uid != null && fcmToken != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'fcmToken': fcmToken,
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await _showLocationDialog(
        title: "Location Disabled",
        message: "Please enable location services to continue.",
      );
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        await _showLocationDialog(
          title: "Permission Denied",
          message: "Location permission is required to find nearby EV stations.",
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      await _showLocationDialog(
        title: "Permission Permanently Denied",
        message: "Please allow location access from settings to use this feature.",
      );
      return;
    }

    // ✅ Use getCurrentPosition instead of getPositionStream
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      final Placemark place = placemarks.first;

      final String? sublocality = place.subLocality;
      final String? city = place.locality;

      setState(() {
        _currentPosition = position;
        _currentCity = "${sublocality ?? ''}, ${city ?? ''}".trim();
      });

      print('✅ Current Position: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      print('⚠️ Error getting position: $e');
    }
  }


  Future<void> _showLocationDialog({required String title, required String message}) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);

              // 👉 Open location settings on Android
              const intent = AndroidIntent(
                action: 'android.settings.LOCATION_SOURCE_SETTINGS',
                flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
              );
              intent.launch();
            },
            child: const Text("Open Settings"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }

  Future<double?> getRoadDistanceInKm(
      double originLat, double originLng, double destLat, double destLng) async {
    print('📍 Origin: $originLat, $originLng');
    print('📍 Destination: $destLat, $destLng');

    const apiKey = 'AIzaSyD-p_PCcAP6MUJSjkizdxi4vy7Jh5A1JBE';

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/distancematrix/json'
          '?origins=$originLat,$originLng'
          '&destinations=$destLat,$destLng'
          '&mode=driving'
          '&units=metric'
          '&key=$apiKey',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rows = data['rows'];
        if (rows != null &&
            rows.isNotEmpty &&
            rows[0]['elements'] != null &&
            rows[0]['elements'].isNotEmpty &&
            rows[0]['elements'][0]['status'] == 'OK') {
          final meters = rows[0]['elements'][0]['distance']['value'];
          return meters / 1000.0;
        }
      } else {
        print('Distance Matrix API error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching road distance: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(child: _buildBody()),
      bottomNavigationBar: AnimatedBottomNavigationBar(
        icons: iconList,
        activeIndex: _currentIndex,
        gapLocation: GapLocation.none,
        activeColor: primaryColor,
        inactiveColor: Colors.grey,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _buildHomeScreen();
      case 1:
        return EnrouteChargingScreen();
      case 2:
        return BookingScreen();
      case 3:
        return const FavoritesScreen();
      case 4:
        return const ProfileScreen();
      default:
        return _buildHomeScreen();
    }
  }

  Widget _buildHomeScreen() {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      "Current city: ${_currentCity ?? 'Detecting...'}",
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                  _buildNotificationIcon(),
                ],
              )
              ,
              if (_currentCity == null)
                TextButton(
                  onPressed: _getCurrentLocation,
                  child: const Text("Retry Location", style: TextStyle(color: Colors.blue)),
                ),
              const SizedBox(height: 8),
              FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users')
                    .doc(FirebaseAuth.instance.currentUser!.uid).get(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return const Text("Welcome", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold));
                  }

                  final userData = snapshot.data!.data() as Map<String, dynamic>;
                  final userName = userData['name'] ?? 'User';

                  return Text(
                    "Welcome $userName,",
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  );
                },
              ),
              const Text("Find charging stations now", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              SearchBarWithRecent(),
              _sectionHeader("Nearby Charging Stations", () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => NearbyStationsScreen()));
              }),
              SizedBox(height: 300, child: _buildStationList('nearby')),
              const SizedBox(height: 24),
              _sectionHeader(
                "Enroute Charging Stations",
                    () async {
                  final filters = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => Filterscreen()),
                  );

                  if (filters != null && mounted) {
                    setState(() {
                      _selectedConnection = filters['connection'];
                      _selectedDistance = filters['distance'];
                      _selectedSpeeds = List<String>.from(filters['speeds']);
                    });
                  }
                },
                showFilterIcon: true,
              ),

              const SizedBox(height: 8),
              _buildStationList('enroute'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationIcon() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return const SizedBox();

    return StreamBuilder<List<QuerySnapshot>>(
      stream: StreamZip([
        FirebaseFirestore.instance
            .collection('notifications')
            .where('to', isEqualTo: userId)
            .where('status', isEqualTo: 'unread')
            .snapshots(),
        FirebaseFirestore.instance
            .collection('notifications_to_send')
            .where('to', isEqualTo: userId)
            .where('status', isEqualTo: 'unread')
            .snapshots(),
      ]),
      builder: (context, snapshot) {
        int unreadCount = 0;

        if (snapshot.hasData && snapshot.data!.length == 2) {
          unreadCount = snapshot.data![0].docs.length +
              snapshot.data![1].docs.length;
        }

        return IconButton(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_none, color: Colors.black),
              if (unreadCount > 0)
                Positioned(
                  right: -6,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$unreadCount',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NotificationScreen(),
              ),
            );
          },
        );
      },
    );
  }


  Widget _sectionHeader(String title, VoidCallback onTap, {bool showFilterIcon = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        showFilterIcon
            ? IconButton(
          icon: const Icon(Icons.filter_alt, color: Colors.green),
          onPressed: onTap,
        )
            : TextButton(
          onPressed: onTap,
          child: const Text('See All', style: TextStyle(color: Colors.green)),
        ),
      ],
    );
  }


  Widget _buildStationList(String type) {
    final isNearby = type == 'nearby';
    final isEnroute = type == 'enroute';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('ev_stations').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || _currentPosition == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final futures = snapshot.data!.docs.map((doc) async {
          final data = doc.data() as Map<String, dynamic>;
          if (data['latitude'] == null || data['longitude'] == null) return null;

          // Try road distance first
          double? roadDistance = await getRoadDistanceInKm(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            (data['latitude'] as num).toDouble(),
            (data['longitude'] as num).toDouble(),
          );

          // ✅ fallback: straight-line distance
          roadDistance ??= Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            (data['latitude'] as num).toDouble(),
            (data['longitude'] as num).toDouble(),
          ) /
              1000;

          return {
            'doc': doc,
            'data': data,
            'distanceKm': roadDistance,
          };
        }).toList();

        return FutureBuilder<List<Map<String, dynamic>?>>(
          future: Future.wait(futures),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final validStations = snap.data!.whereType<Map<String, dynamic>>().toList();

            // Debug log
            for (var station in validStations) {
              final data = station['data'] as Map<String, dynamic>;
              debugPrint("[${data['name']}] -> ${station['distanceKm']} km");
            }

            // ✅ Apply filters
            final filtered = validStations.where((entry) {
              final distance = entry['distanceKm'] as double;
              final data = entry['data'] as Map<String, dynamic>;
              final connectors = data['connectors'] as List<dynamic>? ?? [];

              // Nearby filter
              if (isNearby && distance > 50) return false;

              // Enroute filter
              if (isEnroute && (distance < 50 || distance > 200)) return false;

              // Connection filter
              bool matchConnection = _selectedConnection == null ||
                  connectors.any((conn) => conn['name'] == _selectedConnection);

              // Speed filter
              bool matchSpeed = true;
              if ((_selectedSpeeds ?? []).isNotEmpty) {
                matchSpeed = connectors.any((conn) {
                  final raw = conn['power']?.toString().toLowerCase() ?? "0";
                  final power = double.tryParse(raw.replaceAll("kw", "").trim()) ?? 0;

                  return _selectedSpeeds!.any((speed) {
                    if (speed.contains('Standard')) return power < 3.7;
                    if (speed.contains('Semi')) return power >= 3.7 && power <= 20;
                    if (speed.contains('Fast')) return power > 20 && power <= 43;
                    if (speed.contains('Ultra')) return power > 43;
                    return false;
                  });
                });
              }

              // Distance filter
              bool matchDistance = switch (_selectedDistance) {
                '< 5 km' => distance < 5,
                '< 10 km' => distance < 10,
                '< 20 km' => distance < 20,
                '< 30 km' => distance < 30,
                '> 30 km' => distance > 30,
                _ => true,
              };

              return matchConnection && matchSpeed && matchDistance;
            }).toList();

            // Sort by distance
            filtered.sort((a, b) => (a['distanceKm'] as double).compareTo(b['distanceKm'] as double));

            // ✅ Render
            if (isNearby) {
              return SizedBox(
                height: 300,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: filtered.map((entry) {
                    final doc = entry['doc'] as DocumentSnapshot;
                    final data = entry['data'] as Map<String, dynamic>;
                    final distanceKm = entry['distanceKm'] as double;

                    return ChargingCard(
                      stationId: doc.id,
                      name: data['name'] ?? 'Unnamed Station',
                      location: data['location'] ?? 'Unknown',
                      rating: (data['rating'] ?? 0).toDouble(),
                      status: data['status'] ?? 'Unknown',
                      imagePath: data['imageUrl'] ?? '',
                      openingHours: data['openingHours'],
                      connectors: (data['connectors'] as List<dynamic>?)
                          ?.map((e) => ConnectorInfo.fromJson(Map<String, dynamic>.from(e)))
                          .toList() ??
                          [],
                      amenities: List<String>.from(data['amenities'] ?? []),
                      distance: '${distanceKm.toStringAsFixed(2)} km',
                      isImageLeft: false,
                      height: 180,
                      latitude: data['latitude'],
                      longitude: data['longitude'],
                    );
                  }).toList(),
                ),
              );
            } else if (isEnroute) {
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final entry = filtered[index];
                  final doc = entry['doc'] as DocumentSnapshot;
                  final data = entry['data'] as Map<String, dynamic>;
                  final distanceKm = entry['distanceKm'] as double;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: ChargingCard(
                      stationId: doc.id,
                      name: data['name'] ?? 'Unnamed Station',
                      location: data['location'] ?? 'Unknown',
                      rating: (data['rating'] ?? 0).toDouble(),
                      status: data['status'] ?? 'Unknown',
                      imagePath: data['imageUrl'] ?? '',
                      openingHours: data['openingHours'],
                      connectors: (data['connectors'] as List<dynamic>?)
                          ?.map((e) => ConnectorInfo.fromJson(Map<String, dynamic>.from(e)))
                          .toList() ??
                          [],
                      amenities: List<String>.from(data['amenities'] ?? []),
                      distance: '${distanceKm.toStringAsFixed(2)} km',
                      isImageLeft: true,
                      width: double.infinity,
                      height: 185,
                      latitude: data['latitude'],
                      longitude: data['longitude'],
                    ),
                  );
                },
              );
            } else {
              return const SizedBox.shrink();
            }
          },
        );
      },
    );
  }

}