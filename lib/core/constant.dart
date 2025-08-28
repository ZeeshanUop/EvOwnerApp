import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiKeys {
  static final String googleMaps = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  static final String fcmServer = dotenv.env['FCM_SERVER_KEY'] ?? '';
}
