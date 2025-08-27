import 'package:flutter/material.dart';

class ConnectorTile extends StatelessWidget {
  final String connector;
  final String power;
  final String price;
  final String availability;
  final Color availabilityColor;

  const ConnectorTile({
    super.key,
    required this.connector,
    required this.power,
    required this.price,
    required this.availability,
    required this.availabilityColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Image.asset(
            _getConnectorIconPath(connector),
            height: 30,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 8),
          Text(
            connector,
            style: const TextStyle(fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            power,
            style: const TextStyle(fontSize: 12),
          ),
          Text(
            price,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: availabilityColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              availability,
              style: TextStyle(
                fontSize: 10,
                color: availabilityColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        ],
      ),
    );
  }

  String _getConnectorIconPath(String connector) {
    switch (connector.toLowerCase()) {
      case 'ccs':
        return 'Assets/icon1.png';
      case 'ccs2':
        return 'Assets/icon2.png';
      case 'mennekes':
        return 'Assets/icon3.png';
      default:
        return 'assets/ev5.png';
    }
  }
}
