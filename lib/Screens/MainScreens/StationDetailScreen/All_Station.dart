// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'Charging_station_info.dart';
// import 'Model/Connector_info_Model.dart';
// import 'Model/chargingstation_model.dart'; // your ChargingCard widget
//
//
// class AllStationsScreen extends StatefulWidget {
//   const AllStationsScreen({super.key});
//
//   @override
//   State<AllStationsScreen> createState() => _AllStationsScreenState();
// }
//
// class _AllStationsScreenState extends State<AllStationsScreen> {
//   String selectedCity = 'Islamabad'; // Default city
//   final List<String> cityList = ['Islamabad', 'Lahore', 'Karachi', 'Peshawar']; // Extend as needed
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("All EV Stations"),
//         backgroundColor: Colors.green.shade700,
//       ),
//       body: Column(
//         children: [
//           Padding(
//             padding: const EdgeInsets.all(12),
//             child: DropdownButtonFormField<String>(
//               value: selectedCity,
//               decoration: const InputDecoration(
//                 labelText: 'Select City',
//                 border: OutlineInputBorder(),
//               ),
//               items: cityList.map((city) {
//                 return DropdownMenuItem(
//                   value: city,
//                   child: Text(city),
//                 );
//               }).toList(),
//               onChanged: (value) {
//                 if (value != null) {
//                   setState(() {
//                     selectedCity = value;
//                   });
//                 }
//               },
//             ),
//           ),
//           Expanded(
//             child: StreamBuilder<QuerySnapshot>(
//               stream: FirebaseFirestore.instance
//                   .collection('ev_stations')
//                   .where('city', isEqualTo: selectedCity)
//                   .snapshots(),
//               builder: (context, snapshot) {
//                 if (!snapshot.hasData) {
//                   return const Center(child: CircularProgressIndicator());
//                 }
//
//                 final docs = snapshot.data!.docs;
//
//                 if (docs.isEmpty) {
//                   return const Center(child: Text("No stations found for selected city"));
//                 }
//
//                 return ListView.builder(
//                   itemCount: docs.length,
//                   itemBuilder: (context, index) {
//                     final data = docs[index].data() as Map<String, dynamic>;
//                     final connectorsList = (data['connectors'] as List<dynamic>?)?.map((e) {
//                       if (e is Map<String, dynamic>) {
//                         return ConnectorInfo.fromJson(e);
//                       } else if (e is String) {
//                         return ConnectorInfo(
//                           name: e,
//                           power: 'Unknown',
//                           price: 'Unknown',
//                           totalSlots: 0,
//                           availableSlots: 0,
//                         );
//                       } else {
//                         return ConnectorInfo(
//                           name: 'Unknown',
//                           power: 'Unknown',
//                           price: 'Unknown',
//                           totalSlots: 0,
//                           availableSlots: 0,
//                         );
//                       }
//                     }).toList() ?? [];
//
//                     return Padding(
//                       padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6),
//                       child: GestureDetector(
//                         onTap: () {
//                           Navigator.push(
//                             context,
//                             MaterialPageRoute(
//                               builder: (_) => ChargingStationDetailScreen(
//                                 stationId: docs[index].id,
//                                 name: data['name'] ?? '',
//                                 imagePath: data['imageUrl'] ?? '',
//                                 rating: (data['rating'] ?? 0).toDouble(),
//                                 location: data['location'] ?? '',
//                                 points: data['availablePoints'] ?? 0,
//                                 openingHours: data['openingHours'] ?? 'Not Available',
//                                 pricing: data['pricing'] ?? '20PKR/unit',
//                                 latitude: (data['latitude'] ?? 0.0).toDouble(),
//                                 longitude: (data['longitude'] ?? 0.0).toDouble(),
//                                 amenities: List<String>.from(data['amenities'] ?? []),
//                                 connectors: connectorsList,
//                               ),
//                             ),
//                           );
//                         },
//                         child: ChargingCard(
//                           stationId: docs[index].id,
//                           name: data['name'] ?? 'Unnamed Station',
//                           location: data['location'] ?? 'Unknown Location',
//                           rating: (data['rating'] ?? 0).toDouble(),
//                           points: data['points'] ?? 0,
//                           status: data['status'] ?? 'Unknown',
//                           imagePath: data['imageUrl'] ?? 'Assets/default.jpg',
//                           openingHours: data['openingHours'] ?? 'Not Available',
//                           connectors: connectorsList,
//                           amenities: List<String>.from(data['amenities'] ?? []),
//                           distance: '',
//                           isImageLeft: !(data['stationType'] == 'nearby'),
//                           height: 160,
//                           width: double.infinity,
//                         ),
//                       ),
//                     );
//                   },
//                 );
//               },
//             ),
//           )
//         ],
//       ),
//     );
//   }
// }
