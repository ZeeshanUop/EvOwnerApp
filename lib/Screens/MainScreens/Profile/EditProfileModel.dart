// User Profile Provider
import 'package:flutter/material.dart';
import 'dart:io';

class UserProfileProvider extends ChangeNotifier {
  String _name = '';
  String _phone = '';
  File? _profileImage;

  String get name => _name;
  String get phone => _phone;
  File? get profileImage => _profileImage;

  void updateProfile({required String name, required String phone}) {
    _name = name;
    _phone = phone;
    notifyListeners();
  }

  void updateProfileImage(File? image) {
    _profileImage = image;
    notifyListeners();
  }
}