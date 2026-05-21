// lib/src/providers/storage_service_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grupo_alessat_app/src/services/storage_service.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});
