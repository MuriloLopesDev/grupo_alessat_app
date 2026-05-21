// lib/src/providers/mosaics_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grupo_alessat_app/src/providers/cache_service_provider.dart';
import 'package:grupo_alessat_app/src/providers/storage_service_provider.dart';
import 'package:grupo_alessat_app/src/services/storage_service.dart';
import 'package:grupo_alessat_app/src/services/cache_service.dart';

final mosaicsProvider = StateNotifierProvider<MosaicsNotifier, List<Map<String, dynamic>>>((ref) {
  return MosaicsNotifier(ref.read(storageServiceProvider), ref.read(cacheServiceProvider));
});

class MosaicsNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  final StorageService _storageService;
  final CacheService _cacheService;

  MosaicsNotifier(this._storageService, this._cacheService) : super([]);

  Future<void> loadMosaics() async {
    try {
      var cachedMosaics = _cacheService.get('mosaics');
      if (cachedMosaics != null) {
        state = List<Map<String, dynamic>>.from(cachedMosaics);
        return;
      }

      var loadedMosaics = await _storageService.loadMosaics();
      _cacheService.set('mosaics', loadedMosaics);
      state = loadedMosaics;
    } catch (e) {
      print('Erro ao carregar mosaicos no provider: $e');
      state = [];
    }
  }

  Future<void> addMosaic(Map<String, dynamic> mosaic) async {
    try {
      final currentMosaics = List<Map<String, dynamic>>.from(state);
      currentMosaics.add(mosaic);
      await _storageService.saveMosaics(currentMosaics);
      _cacheService.set('mosaics', currentMosaics); // Atualizar cache
      state = currentMosaics;
    } catch (e) {
      print('Erro ao adicionar mosaico no provider: $e');
    }
  }

  Future<void> updateMosaic(String oldMosaicName, Map<String, dynamic> newMosaic) async {
    try {
      final currentMosaics = List<Map<String, dynamic>>.from(state);
      final index = currentMosaics.indexWhere((m) => m['nome'] == oldMosaicName);
      if (index != -1) {
        currentMosaics[index] = newMosaic;
        await _storageService.saveMosaics(currentMosaics);
        _cacheService.set('mosaics', currentMosaics); // Atualizar cache
        state = currentMosaics;
      }
    } catch (e) {
      print('Erro ao atualizar mosaico no provider: $e');
    }
  }

  Future<void> deleteMosaic(int index) async {
    try {
      final currentMosaics = List<Map<String, dynamic>>.from(state);
      currentMosaics.removeAt(index);
      await _storageService.saveMosaics(currentMosaics);
      _cacheService.set('mosaics', currentMosaics); // Atualizar cache
      state = currentMosaics;
    } catch (e) {
      print('Erro ao deletar mosaico no provider: $e');
    }
  }
}
