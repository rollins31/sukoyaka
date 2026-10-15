import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Reads a JSON-encoded log stored under [key], or an empty list if nothing
/// has been saved yet. Callers sort the result; storage order isn't trusted.
List<T> readEntries<T>(
  SharedPreferences prefs,
  String key,
  T Function(Map<String, dynamic> json) fromJson,
) {
  final jsonString = prefs.getString(key);
  if (jsonString == null) return [];
  return (jsonDecode(jsonString) as List<dynamic>)
      .map((raw) => fromJson(raw as Map<String, dynamic>))
      .toList();
}

Future<void> writeEntries(
  SharedPreferences prefs,
  String key,
  Iterable<Map<String, dynamic>> json,
) =>
    prefs.setString(key, jsonEncode(json.toList()));
