import 'dart:convert';
import 'package:grupo_alessat_app/src/services/cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  final cacheService = CacheService();
  static const String _mosaicsKey = 'mosaics';

  Future<void> saveMosaics(List<Map<String, dynamic>> mosaics) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> mosaicsJson = mosaics.map((mosaic) => jsonEncode(mosaic)).toList();
    await prefs.setStringList(_mosaicsKey, mosaicsJson);
    cacheService.set('mosaics', mosaics);
  }

  Future<List<Map<String, dynamic>>> loadMosaics() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> mosaicsJson = prefs.getStringList(_mosaicsKey) ?? [];
    List<Map<String, dynamic>> mosaics = [];

    for (String mosaicJson in mosaicsJson) {
      try {
        Map<String, dynamic> mosaic = jsonDecode(mosaicJson) as Map<String, dynamic>;
        mosaics.add(mosaic);
      } catch (e) {
        throw Exception('Falha ao realizar decode do mosaico: $e');
      }
    }

    return mosaics;
  }

  Future<void> deleteMosaic(int index) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> mosaicsJson = prefs.getStringList(_mosaicsKey) ?? [];
    if (index >= 0 && index < mosaicsJson.length) {
      mosaicsJson.removeAt(index);
      await prefs.setStringList(_mosaicsKey, mosaicsJson);
    }
  }
}
