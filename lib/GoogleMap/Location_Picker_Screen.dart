import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_google_places_hoc081098/flutter_google_places_hoc081098.dart';
import 'package:google_maps_webservice/places.dart';

import '../core/constant.dart';

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  LatLng? selectedLocation;
  String selectedAddress = "Searching current location...";
  GoogleMapController? _mapController;
  final _places = GoogleMapsPlaces(apiKey: ApiKeys.googleMaps);

  @override
  void initState() {
    super.initState();
    _setInitialLocation();
  }

  Future<void> _setInitialLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnack('Please enable location services.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          _showSnack('Location permission is required.');
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final latLng = LatLng(position.latitude, position.longitude);
      selectedLocation = latLng;
      await _updateAddressFromLatLng(latLng);
      _mapController?.animateCamera(CameraUpdate.newLatLng(latLng));
    } catch (e) {
      debugPrint('Location error: $e');
      _showSnack('Failed to get current location.');
    }
  }

  Future<void> _updateAddressFromLatLng(LatLng latLng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latLng.latitude, latLng.longitude);
      final place = placemarks.isNotEmpty ? placemarks.first : null;

      setState(() {
        selectedLocation = latLng;
        selectedAddress = place != null
            ? "${place.street ?? ''}, ${place.locality ?? ''}, ${place.country ?? ''}"
            : "Unknown Location";
      });
    } catch (e) {
      debugPrint('Address error: $e');
      setState(() => selectedAddress = "Failed to fetch address");
    }
  }

  Future<void> _handlePlaceSearch() async {
    try {
      Prediction? prediction = await PlacesAutocomplete.show(
        context: context,
        apiKey: ApiKeys.googleMaps,
        mode: Mode.overlay,
        language: "en",
        components: [Component(Component.country, "pk")],
      );

      if (prediction != null) {
        PlacesDetailsResponse detail = await _places.getDetailsByPlaceId(prediction.placeId!);
        final lat = detail.result.geometry!.location.lat;
        final lng = detail.result.geometry!.location.lng;
        final latLng = LatLng(lat, lng);

        _mapController?.animateCamera(CameraUpdate.newLatLng(latLng));
        await _updateAddressFromLatLng(latLng);
      }
    } catch (e) {
      debugPrint('Place search error: $e');
      _showSnack('Failed to search location.');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pick Location"),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _handlePlaceSearch,
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: selectedLocation == null
                ? const Center(child: CircularProgressIndicator())
                : GoogleMap(
              initialCameraPosition: CameraPosition(
                target: selectedLocation!,
                zoom: 14,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
                if (selectedLocation != null) {
                  _mapController!.animateCamera(CameraUpdate.newLatLng(selectedLocation!));
                }
              },
              onTap: (LatLng position) {
                _updateAddressFromLatLng(position);
              },
              markers: selectedLocation != null
                  ? {
                Marker(
                  markerId: const MarkerId("picked"),
                  position: selectedLocation!,
                  draggable: true,
                  onDragEnd: (newPosition) => _updateAddressFromLatLng(newPosition),
                ),
              }
                  : {},
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        selectedAddress,
                        style: const TextStyle(fontSize: 14),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: selectedLocation != null
                      ? () {
                    Navigator.pop(context, {
                      "latLng": selectedLocation,
                      "address": selectedAddress,
                    });
                  }
                      : null,
                  icon: const Icon(Icons.check),
                  label: const Text("Confirm Location"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
