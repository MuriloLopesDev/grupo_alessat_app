// lib/src/api/api_service.dart
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/login_request.dart';
import '../models/login_response.dart';

class ApiService {
  final String baseUrl = "https://moovsec.alessat.com.br:5000";
  final String baseUrlLive = "https://moovsec.alessat.com.br:3000"; // Consistência na URL base
  // API que gera/solicita o live media
  final String baseUrlLiveApi = "https://moovsec.alessat.com.br:3000";
    // Servidor que entrega o arquivo de mídia .m3u8/.jpg
  final String baseUrlMedia = "https://moovsec.alessat.com.br:3010";
  final int maxConcurrentRequests = 5;
  final Queue _requestQueue = Queue();

  Future<LoginResponse> login(LoginRequest request) async {
    final url = Uri.parse("$baseUrl/auth/login");

    try {
      final response = await _enqueueRequest(() => http.post(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(request.toJson()),
          ));

      if (response.statusCode == 201) {
        final teste = LoginResponse.fromJson(jsonDecode(response.body));
        return teste;
      } else {
        return LoginResponse(
          token: "",
          message: "Usuário ou senha inválidos",
        );
      }
    } catch (e) {
      return LoginResponse(
        token: "",
        message: "Erro de conexão: $e",
      );
    }
  }

  Future<String?> getLiveMediaUrl(String deviceSerial, int channel, String token) async {
    // Mantido como estava, pois já usa baseUrlLive
    final url = Uri.parse('$baseUrlLive/dvr/$deviceSerial/livemedia?channel=$channel&streamType=MainStream&forceStreamType=true');

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        final address = body['data']['address'];
        return '$baseUrlLive$address'; // Usando baseUrlLive para consistência
      } else {
        print('Erro ao buscar stream para $deviceSerial - Canal $channel: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Exceção ao buscar stream para $deviceSerial: $e');
      return null;
    }
  }

  Future getAllVehicles(String token) async {
    final urlFleetBetterBeef = Uri.parse("$baseUrl/fleet/all/true");
    print('Chamando API para getAllVehicles: $urlFleetBetterBeef'); // Adicionar log

    try {
      final response = await _enqueueRequest(() => http.get(
            urlFleetBetterBeef,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          ));
      print('Status da resposta getAllVehicles: ${response.statusCode}'); // Adicionar log
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Dados recebidos de getAllVehicles: ${data.length} itens'); // Adicionar log
        return data['data']; // Certifique-se de que 'data' é a chave correta
      } else {
        print('Erro na API getAllVehicles: ${response.statusCode} - ${response.reasonPhrase} - ${response.body}'); // Log de erro completo
        throw Exception('Erro ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      print('Exceção ao obter veículos na ApiService: $e'); // Log de exceção
      return null; // Retornar null em caso de erro
    }
  }

Future<Map<String, dynamic>?> liveMedia(String deviceSerial, String token, int channel) async {
  try {
    final url = Uri.parse(
      "$baseUrlLiveApi/dvr/$deviceSerial/livemedia"
      "?channel=$channel"
      "&streamType=SubStream"
      "&forceStreamType=true"
      "&thumbnail=true",
    );

    print('Chamando liveMedia: $url');

    final response = await _enqueueRequest(() => http.get(url, headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        }));

    print('Status liveMedia [$deviceSerial canal $channel]: ${response.statusCode}');
    print('Body liveMedia [$deviceSerial canal $channel]: ${response.body}');

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      return responseData['data'];
    } else {
      throw Exception('Erro ${response.statusCode}: ${response.reasonPhrase} - ${response.body}');
    }
  } catch (e) {
    print('Erro ao obter live media: $e');
    return null;
  }
}

  Future<http.Response> _enqueueRequest(Future<http.Response> Function() request) async {
    if (_requestQueue.length >= maxConcurrentRequests) {
      await _requestQueue.removeFirst().future;
    }

    final completer = Completer<http.Response>();
    _requestQueue.add(completer);

    try {
      final response = await request();
      completer.complete(response);
      return response;
    } catch (e) {
      completer.completeError(e);
      rethrow;
    }
  }
}
