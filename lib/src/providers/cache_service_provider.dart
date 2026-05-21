// lib/src/providers/cache_service_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grupo_alessat_app/src/services/cache_service.dart';

final cacheServiceProvider = Provider<CacheService>((ref) {
  return CacheService();
});
