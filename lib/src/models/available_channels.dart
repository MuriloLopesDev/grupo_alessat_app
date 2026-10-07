List<int> availableChannelsFromDevice(dynamic deviceEntry) {
  if (deviceEntry is! Map) return const [];
  final devices = deviceEntry['device'];
  if (devices is! List) return const [];

  for (final device in devices) {
    if (device is! Map) continue;
    final register = device['register'];
    if (register is! Map || register['channels'] is! List) continue;

    final channels = <int>{};
    for (final value in register['channels'] as List) {
      final channel = value is int ? value : int.tryParse(value.toString());
      if (channel != null && channel > 0) channels.add(channel);
    }
    if (channels.isNotEmpty) return channels.toList()..sort();
  }
  return const [];
}

List<int> availableChannelsForVehicle(Map<String, dynamic> vehicle) {
  final value = vehicle['channels'];
  if (value is! List) return const [];
  return value.whereType<int>().toList();
}
