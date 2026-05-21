// lib/src/providers/api_service_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grupo_alessat_app/src/api/api_service.dart';

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});
