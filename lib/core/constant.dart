import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiKeys {
  static final String googleMaps = dotenv.env['AIzaSyD-p_PCcAP6MUJSjkizdxi4vy7Jh5A1JBE'] ?? '';
  static final fcmServer = dotenv.env['BAVaSjy7H5P1ya_qWwE3_HW-L2qY9bq1pHBUf9NDeQskLYb-PyUMHM0MJS1muE1bkQr_lj2mfAo4O7tDU8GdhPQ'] ?? '';

}
