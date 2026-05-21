// lib/src/providers/vehicles_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grupo_alessat_app/src/api/api_service.dart';
import 'package:grupo_alessat_app/src/providers/api_service_provider.dart';
import 'package:grupo_alessat_app/src/providers/cache_service_provider.dart';
import 'package:grupo_alessat_app/src/services/cache_service.dart';

final vehiclesProvider = StateNotifierProvider<VehiclesNotifier, List<Map<String, dynamic>>>((ref) {
  return VehiclesNotifier(ref.read(apiServiceProvider), ref.read(cacheServiceProvider));
});

class VehiclesNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  final ApiService _apiService;
  final CacheService _cacheService;

  VehiclesNotifier(this._apiService, this._cacheService) : super([]);

  Future<void> getAllVehicles(String token) async {
    try {
      var cachedVehicles = _cacheService.get('vehicles');
      if (cachedVehicles != null) {
        state = List<Map<String, dynamic>>.from(cachedVehicles);
        print('Veículos carregados do cache: ${state.length}');
        return;
      }

      print('Buscando veículos da API...');
      dynamic data = await _apiService.getAllVehicles(token);

      List<Map<String, dynamic>> fetchedVehicles = [];
      if (data != null && data is List) {
        // Certifica que 'data' é uma lista
        for (int i = 0; i < data.length; i++) {
          if (data[i] != null && data[i]['name'] == 'BETTER BEEF') {
            // Verifica se data[i] não é null
            dynamic dataFleet = data[i]['vehicleList'];
            if (dataFleet != null && dataFleet is List) {
              // Certifica que 'dataFleet' é uma lista
              for (int j = 0; j < dataFleet.length; j++) {
                String? deviceSerialValue;
                if (dataFleet[j] != null && // dataFleet[j] não nulo
                    dataFleet[j]['deviceList'] != null && // deviceList não nulo
                    dataFleet[j]['deviceList'] is List && // deviceList é uma lista
                    dataFleet[j]['deviceList'].isNotEmpty) {
                  // lista não vazia

                  // Tenta acessar o primeiro elemento da lista e depois a chave 'deviceSerial'
                  // Adicionado verificação para garantir que o elemento da lista é um Map
                  if (dataFleet[j]['deviceList'][0] is Map<String, dynamic>) {
                    deviceSerialValue = dataFleet[j]['deviceList'][0]['deviceSerial']?.toString();
                  }
                }

                fetchedVehicles.add({
                  'plate': dataFleet[j]?['plate']?.toString() ?? 'N/A', // Acesso seguro e fallback
                  'status': dataFleet[j]?['lastConnectionStatus']?['status']?.toString() ?? 'disconnected', // Acesso seguro e fallback
                  'deviceSerial': deviceSerialValue,
                });
              }
            }
          }
        }
      }
      _cacheService.set('vehicles', fetchedVehicles);
      state = fetchedVehicles;
      print('Veículos carregados da API: ${state.length}');
    } catch (e) {
      print('Erro ao carregar veículos no provider: $e');
      state = [];
    }
  }
}
