import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class LocationMark {
  final int id;
  final String name;
  final double latitude;
  final double longitude;
  const LocationMark({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude
  });
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude' : longitude
    };
  }
  @override
  String toString() {
    return 'LocationMark{id: $id, name: $name, latitude: $latitude, longitude: $longitude}';
  }
}