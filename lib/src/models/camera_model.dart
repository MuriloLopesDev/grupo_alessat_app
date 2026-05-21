// lib/src/models/camera_model.dart
class Camera {
  final String deviceSerial;
  final String plate;
  final int channel;
  // O token é necessário para a requisição da URL do stream
  final String token;

  Camera({
    required this.deviceSerial,
    required this.plate,
    required this.channel,
    required this.token,
  });
}
