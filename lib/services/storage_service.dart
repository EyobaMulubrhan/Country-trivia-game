import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class StorageService {
  Future<Set<String>> loadSolvedCodes() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(StorageKeys.solvedCodes);
    if (jsonStr == null) return {};
    final list = jsonDecode(jsonStr) as List<dynamic>;
    return list.cast<String>().toSet();
  }

  Future<void> saveSolvedCodes(Set<String> codes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      StorageKeys.solvedCodes,
      jsonEncode(codes.toList()),
    );
  }

  Future<int> loadScore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(StorageKeys.totalScore) ?? 0;
  }

  Future<void> saveScore(int score) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(StorageKeys.totalScore, score);
  }
}
