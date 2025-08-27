import 'package:flutter/material.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/place_type.dart';
import 'package:google_places_flutter/model/prediction.dart';

import '../../../core/constant.dart'; // Required for Prediction

class DestinationPickerScreen extends StatefulWidget {
  const DestinationPickerScreen({super.key});

  @override
  State<DestinationPickerScreen> createState() => _DestinationPickerScreenState();
}

class _DestinationPickerScreenState extends State<DestinationPickerScreen> {
  final TextEditingController _controller = TextEditingController();
  final apiKey = ApiKeys.googleMaps;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pick Destination")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GooglePlaceAutoCompleteTextField(
          textEditingController: _controller,
          googleAPIKey: apiKey,
          inputDecoration: const InputDecoration(
            hintText: "Enter your destination",
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.search),
          ),
          debounceTime: 600,
          isLatLngRequired: true,
          countries: const ["pk"],
          getPlaceDetailWithLatLng: (Prediction prediction) {
            final lat = prediction.lat;
            final lng = prediction.lng;
            print("Lat: $lat, Lng: $lng");

            Navigator.pop(context, {
              'description': prediction.description,
              'latitude': lat,
              'longitude': lng,
            });
          },
          itemClick: (Prediction prediction) {
            _controller.text = prediction.description!;
            _controller.selection = TextSelection.fromPosition(
              TextPosition(offset: prediction.description!.length),
            );
          },
          itemBuilder: (context, index, Prediction prediction) {
            return Container(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  const Icon(Icons.location_on),
                  const SizedBox(width: 7),
                  Expanded(child: Text(prediction.description ?? "")),
                ],
              ),
            );
          },
          seperatedBuilder: const Divider(),
          isCrossBtnShown: true,
          containerHorizontalPadding: 10,
          placeType: PlaceType.geocode,
        ),
      ),
    );
  }
}
