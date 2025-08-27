import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FavoriteProvider with ChangeNotifier {
  final List<String> _favoriteIds = [];
  final _auth = FirebaseAuth.instance;

  List<String> get favorites => _favoriteIds;

  FavoriteProvider() {
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (doc.exists) {
      final data = doc.data();
      if (data != null && data.containsKey('favorites')) {
        final favList = List<String>.from(data['favorites']);
        _favoriteIds
          ..clear()
          ..addAll(favList);
        notifyListeners();
      }
    }
  }

  Future<void> _saveFavoritesToFirestore() async {
    final user = _auth.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'favorites': _favoriteIds}, SetOptions(merge: true));
    }
  }

  Future<void> addFavorite(String stationId) async {
    if (!_favoriteIds.contains(stationId)) {
      _favoriteIds.add(stationId);
      notifyListeners();
      await _saveFavoritesToFirestore();
    }
  }

  Future<void> removeFavorite(String stationId) async {
    if (_favoriteIds.remove(stationId)) {
      notifyListeners();
      await _saveFavoritesToFirestore();
    }
  }

  Future<void> toggleFavorite(String stationId) async {
    if (_favoriteIds.contains(stationId)) {
      await removeFavorite(stationId);
    } else {
      await addFavorite(stationId);
    }
  }

  bool isFavorite(String stationId) {
    return _favoriteIds.contains(stationId);
  }
}
