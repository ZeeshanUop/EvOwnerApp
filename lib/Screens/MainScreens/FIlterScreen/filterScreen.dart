import 'package:flutter/material.dart';

class Filterscreen extends StatefulWidget {
  @override
  _FilterscreenState createState() => _FilterscreenState();
}

class _FilterscreenState extends State<Filterscreen> {
  // Connection types
  List<String> connectionTypes = ['CCS', 'CCS2', 'Mennekes'];
  String selectedConnection = 'Mennekes';

  // Enroute distance options (50-200 km)
  List<String> distances = ['50-100 km', '100-150 km', '150-200 km', 'All'];
  String selectedDistance = 'All';

  // Charging speed
  Map<String, bool> chargingSpeeds = {
    'Standard (<3.7 kW)': true,
    'Semi fast (3.7 - 20 kW)': true,
    'Fast (20 - 43 kW)': false,
    'Ultra fast (>43 kW)': false,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Filter Enroute Stations'),
        leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context);
            }),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Connection Type ---
            Text('Connection type',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Row(
              children: connectionTypes.map((type) {
                bool isSelected = selectedConnection == type;
                String imagePath;
                switch (type) {
                  case 'CCS':
                    imagePath = 'Assets/icon1.png';
                    break;
                  case 'CCS2':
                    imagePath = 'Assets/icon2.png';
                    break;
                  case 'Mennekes':
                  default:
                    imagePath = 'Assets/icon3.png';
                }

                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => selectedConnection = type),
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: 4),
                      padding: EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: isSelected ? Colors.green : Colors.grey),
                        borderRadius: BorderRadius.circular(10),
                        color: isSelected
                            ? Colors.green.withOpacity(0.1)
                            : Colors.white,
                      ),
                      child: Column(
                        children: [
                          Image.asset(
                            imagePath,
                            width: 40,
                            height: 40,
                            color: isSelected ? Colors.green : null,
                          ),
                          SizedBox(height: 5),
                          Text(
                            type,
                            style: TextStyle(
                                color:
                                isSelected ? Colors.green : Colors.black),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            SizedBox(height: 20),

            // --- Distance Selection ---
            Text('By distance (km)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 8,
              children: distances.map((distance) {
                bool isSelected = selectedDistance == distance;
                return ChoiceChip(
                  label: Text(distance),
                  selected: isSelected,
                  onSelected: (_) => setState(() => selectedDistance = distance),
                  selectedColor: Colors.green.shade100,
                  backgroundColor: Colors.grey.shade200,
                  labelStyle: TextStyle(
                      color: isSelected ? Colors.green : Colors.black),
                );
              }).toList(),
            ),

            SizedBox(height: 20),

            // --- Charging Speed ---
            Text('Charging speed',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Column(
              children: chargingSpeeds.entries.map((entry) {
                return InkWell(
                  onTap: () => setState(() {
                    chargingSpeeds[entry.key] = !entry.value;
                  }),
                  child: Row(
                    children: [
                      Checkbox(
                        value: entry.value,
                        onChanged: (bool? value) {
                          setState(() {
                            chargingSpeeds[entry.key] = value!;
                          });
                        },
                        activeColor: Colors.green,
                      ),
                      Expanded(child: Text(entry.key)),
                    ],
                  ),
                );
              }).toList(),
            ),

            Spacer(),

            // --- Footer Buttons ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, {
                      'connection': selectedConnection,
                      'distance': selectedDistance,
                      'speeds': chargingSpeeds.entries
                          .where((entry) => entry.value)
                          .map((entry) => entry.key)
                          .toList(),
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text('Apply'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
