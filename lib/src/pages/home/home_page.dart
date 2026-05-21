// home_page.dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grupo_alessat_app/src/api/api_service.dart';
import 'package:grupo_alessat_app/src/pages/home/components/add_mosaico_dialog.dart';
import 'package:grupo_alessat_app/src/pages/home/components/full_screen_video.dart';
import 'package:grupo_alessat_app/src/pages/home/components/mosaic_list.dart';
import 'package:grupo_alessat_app/src/pages/home/components/vehicle_channel_list.dart';
import 'package:grupo_alessat_app/src/pages/home/components/video_grid.dart';
import 'package:grupo_alessat_app/src/providers/api_service_provider.dart';
import 'package:grupo_alessat_app/src/providers/mosaics_provider.dart';
import 'package:grupo_alessat_app/src/providers/vehicles_provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart';

// Definindo o enum de status do stream de vídeo
enum VideoStreamStatus {
  loading,
  loaded,
  error,
  inactive,
}

class HomePage extends ConsumerStatefulWidget {
  final String token;
  const HomePage({super.key, required this.token});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> with WindowListener {
  // Mapas para gerenciar players e controladores de cada vídeo
  final Map<String, Player> players = {};
  final Map<String, VideoController> controllers = {};
  // Novo mapa para gerenciar o status de cada URL de vídeo individualmente
  final Map<String, VideoStreamStatus> videoStatuses = {};
  final Map<String, String> videoErrors = {};

  // Mapa para armazenar metadados (placa e canal) por URL de vídeo
  final Map<String, Map<String, dynamic>> _videoMetadata = {};

  List<String> _currentVideoOrder = []; // Ordem atual dos vídeos exibidos no grid

  bool isLoadingGlobal = false;
  bool showMosaicList = true;
  bool showVehicleDirectList = false;

  bool _showLists = true;

  Map<String, List<int>> _selectedDirectChannels = {};

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _maximizeWindow();
    ref.read(vehiclesProvider.notifier).getAllVehicles(widget.token);
    ref.read(mosaicsProvider.notifier).loadMosaics();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_showLists == true) {
      final screenWidth = MediaQuery.of(context).size.width;
      if (screenWidth < 900) {
        setState(() {
          _showLists = false;
        });
      }
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    for (var player in players.values) {
      player.dispose();
    }
    super.dispose();
  }

  Future<void> _maximizeWindow() async {
    await windowManager.ensureInitialized();
    await windowManager.setMinimumSize(const Size(1024, 600));
    await windowManager.setResizable(true);
    await windowManager.maximize();
  }

  Future<void> confirmDeleteMosaic(int index) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color.fromARGB(255, 25, 32, 37),
          title: const Text(
            'Confirmar Exclusão',
            style: TextStyle(color: Colors.white, fontSize: 18.0, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Tem certeza que deseja excluir este mosaico?',
            style: TextStyle(color: Colors.white, fontSize: 16.0),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.white, fontSize: 16.0),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text(
                'Excluir',
                style: TextStyle(color: Colors.white, fontSize: 16.0),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      setState(() {
        isLoadingGlobal = true;
      });
      final mosaics = ref.read(mosaicsProvider);
      if (index >= 0 && index < mosaics.length) {
        final mosaicToDelete = mosaics[index];
        final List<Map<String, dynamic>> itensToClear = [];

        for (var frota in (mosaicToDelete['frotas'] as List)) {
          itensToClear.addAll((frota['itens'] as List).cast<Map<String, dynamic>>());
        }

        await _clearMosaicVideos(itensToClear);
        ref.read(mosaicsProvider.notifier).deleteMosaic(index);

        setState(() {
          _currentVideoOrder.clear();
          players.forEach((key, value) => value.dispose());
          players.clear();
          controllers.clear();
          videoStatuses.clear();
          videoErrors.clear();
          _videoMetadata.clear();
          _selectedDirectChannels.clear();
          isLoadingGlobal = false;
        });
      }
    }
  }

  Future<void> _clearMosaicVideos(List<Map<String, dynamic>> items) async {
    List<Future<void>> futures = [];
    Set<String> urlsToDispose = {};

    for (var item in items) {
      final canal = item['canal'];
      final deviceSerial = item['veiculo']?['deviceSerial'];

      if (deviceSerial != null) {
        final urlBaseVideo = 'https://moovsec.alessat.com.br:3010/live/${deviceSerial}_$canal';
        urlsToDispose.add(urlBaseVideo);
      }
    }

    for (var url in urlsToDispose) {
      if (players.containsKey(url)) {
        futures.add(Future.sync(() async {
          players[url]?.dispose();
          players.remove(url);
          controllers.remove(url);
          videoStatuses.remove(url);
          videoErrors.remove(url);
          _videoMetadata.remove(url);
        }));
      }
    }

    setState(() {
      _currentVideoOrder.removeWhere((url) => urlsToDispose.contains(url));
    });

    try {
      await Future.wait(futures);
    } catch (e) {
      print('Error waiting for futures to clear videos: $e');
    }
  }

  Future<void> _manageVideoStreams({required List<Map<String, dynamic>> newItems}) async {
    final Set<String> newUrls = {};
    final apiService = ref.read(apiServiceProvider);
    final String token = widget.token;

    final Map<String, Map<String, dynamic>> tempNewVideoMetadata = {};

    for (var item in newItems) {
      final deviceSerial = item['veiculo']['deviceSerial'];
      final canal = item['canal'];
      final url = 'https://moovsec.alessat.com.br:3010/live/${deviceSerial}_$canal';
      newUrls.add(url);
      tempNewVideoMetadata[url] = {
        'plate': item['veiculo']['plate'],
        'channel': canal,
        'deviceSerial': deviceSerial, // Adicionar deviceSerial aqui para fácil acesso
      };
    }

    final List<String> urlsToRemove = players.keys.where((url) => !newUrls.contains(url)).toList();
    for (var url in urlsToRemove) {
      players[url]?.dispose();
      players.remove(url);
      controllers.remove(url);
      setState(() {
        videoStatuses.remove(url);
        videoErrors.remove(url);
        _videoMetadata.remove(url);
        _currentVideoOrder.remove(url);
      });
    }

    final List<Future<void>> loadTasks = [];
    final List<String> tempCurrentOrder = [];

    for (var item in newItems) {
      final deviceSerial = item['veiculo']['deviceSerial'];
      final canal = item['canal'];
      final urlBaseVideo = 'https://moovsec.alessat.com.br:3010/live/${deviceSerial}_$canal';

      tempCurrentOrder.add(urlBaseVideo);

      if (!players.containsKey(urlBaseVideo) || videoStatuses[urlBaseVideo] == VideoStreamStatus.error) {
        setState(() {
          videoStatuses[urlBaseVideo] = VideoStreamStatus.loading;
          videoErrors.remove(urlBaseVideo);
        });
        loadTasks.add(_loadSingleVideo(urlBaseVideo, deviceSerial, canal, item['veiculo'], apiService, token));
      } else {
        if (videoStatuses[urlBaseVideo] != VideoStreamStatus.loaded) {
          setState(() {
            videoStatuses[urlBaseVideo] = VideoStreamStatus.loaded;
            videoErrors.remove(urlBaseVideo);
          });
        }
      }
    }

    setState(() {
      _currentVideoOrder = tempCurrentOrder;
      _videoMetadata.clear();
      _videoMetadata.addAll(tempNewVideoMetadata);
    });

    try {
      await Future.wait(loadTasks);
    } catch (e) {
      print('Erro ao gerenciar streams de vídeo: $e');
    } finally {
      setState(() {
        videoStatuses.updateAll((key, value) {
          if (value == VideoStreamStatus.loading && !players.containsKey(key)) {
            return VideoStreamStatus.error;
          }
          return value;
        });
        isLoadingGlobal = false;
      });
    }
  }

  // NOVO: Método para remover um vídeo da grid E atualizar a seleção direta
  void _removeVideoFromGrid(String videoUrl) {
    setState(() {
      // 1. Descartar player e remover da grid
      _currentVideoOrder.remove(videoUrl);
      if (players.containsKey(videoUrl)) {
        players[videoUrl]?.dispose();
        players.remove(videoUrl);
        controllers.remove(videoUrl);
      }
      videoStatuses.remove(videoUrl);
      videoErrors.remove(videoUrl);

      // 2. Tentar atualizar _selectedDirectChannels
      final metadata = _videoMetadata[videoUrl];
      if (metadata != null && metadata.containsKey('deviceSerial') && metadata.containsKey('channel')) {
        final deviceSerial = metadata['deviceSerial'] as String;
        final channel = metadata['channel'] as int;

        if (_selectedDirectChannels.containsKey(deviceSerial)) {
          _selectedDirectChannels[deviceSerial]?.remove(channel);
          // Se não houver mais canais selecionados para este deviceSerial, remover a entrada
          if (_selectedDirectChannels[deviceSerial]?.isEmpty ?? false) {
            _selectedDirectChannels.remove(deviceSerial);
          }
        }
      }
      // 3. Remover metadados do vídeo
      _videoMetadata.remove(videoUrl);
    });
  }

  Future<void> _loadSingleVideo(
    String urlBaseVideo,
    String deviceSerial,
    dynamic canal,
    dynamic veiculo,
    ApiService apiService,
    String token,
  ) async {
    try {
      final urlData = await apiService.liveMedia(deviceSerial, token, canal);
if (urlData != null && urlData.isNotEmpty) {
  final address = urlData['address']?.toString();
  final isThumbnail = urlData['isThumbnail'] == true;

  print('liveMedia data [$deviceSerial canal $canal]: $urlData');

  if (address == null || address.isEmpty) {
    setState(() {
      videoStatuses[urlBaseVideo] = VideoStreamStatus.error;
      videoErrors[urlBaseVideo] = 'API não retornou endereço de mídia para $deviceSerial canal $canal';
    });
    return;
  }

  if (isThumbnail || address.toLowerCase().endsWith('.jpg') || address.toLowerCase().endsWith('.jpeg') || address.toLowerCase().endsWith('.png')) {
    print('Stream ainda não pronto para $deviceSerial canal $canal. Retornou thumbnail: $address');

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;

      _loadSingleVideo(
        urlBaseVideo,
        deviceSerial,
        canal,
        veiculo,
        apiService,
        token,
      );
    });

    return;
  }

  final actualStreamUrl = address.startsWith('http')
      ? address
      : '${apiService.baseUrlMedia}$address';

  print('URL FINAL DO STREAM [$deviceSerial canal $canal]: $actualStreamUrl');

        if (players.containsKey(urlBaseVideo)) {
          players[urlBaseVideo]?.dispose();
        }

        final player = Player(
            configuration: const PlayerConfiguration(
          vo: 'gpu',
          bufferSize: 4 * 1024 * 1024,
        ));
        final controller = VideoController(player);

final headers = {
  'Authorization': 'Bearer $token',
  'Cache-Control': 'max-age=0, no-cache',
  'Pragma': 'no-cache',
  'Accept': 'application/vnd.apple.mpegurl, application/x-mpegURL, */*',
  'User-Agent': 'grupo_alessat_app/1.0',
};

final media = Media(
  actualStreamUrl,
  httpHeaders: headers,
);

void reconnect() {
  Future.delayed(Duration(seconds: 2 + Random().nextInt(4)), () {
    try {
      player.open(media, play: true);
    } catch (e) {
      print('Não foi possível reconectar $actualStreamUrl, player provavelmente já foi descartado. Erro: $e');
    }
  });
}

player.stream.completed.listen((isCompleted) {
  if (isCompleted) {
    print('Player para $actualStreamUrl foi completado. Tentando reconectar...');
    reconnect();
  }
});

player.stream.error.listen((error) {
  print('Player para $actualStreamUrl encontrou um erro: "$error".');

  setState(() {
    videoStatuses[urlBaseVideo] = VideoStreamStatus.error;
    videoErrors[urlBaseVideo] = 'Erro ao abrir stream: $error';
  });

  // Durante o diagnóstico, não reconecta automaticamente.
  // Se reconectar aqui, o erro fica em loop e esconde a causa real.
  // reconnect();
});

await player.open(media, play: true);
await player.setVolume(0);

        setState(() {
          players[urlBaseVideo] = player;
          controllers[urlBaseVideo] = controller;
          videoStatuses[urlBaseVideo] = VideoStreamStatus.loaded;
          videoErrors.remove(urlBaseVideo);
        });
      } else {
        setState(() {
          videoStatuses[urlBaseVideo] = VideoStreamStatus.error;
          videoErrors[urlBaseVideo] = 'Erro ao carregar canal $canal da placa: ${veiculo['plate'] ?? deviceSerial}';
        });
      }
    } catch (e) {
      setState(() {
        videoStatuses[urlBaseVideo] = VideoStreamStatus.error;
        videoErrors[urlBaseVideo] = 'Erro ao obter mídia do dispositivo: $deviceSerial (canal: $canal). Erro: $e';
      });
    }
  }

  void _enterFullScreen(String url) {
    if (controllers.containsKey(url) && controllers[url] != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => FullScreenVideo(
            controller: controllers[url]!,
          ),
        ),
      );
    } else {
      print('Erro: Controlador de vídeo não disponível para a URL: $url');
    }
  }

  void _toggleListsVisibility() {
    setState(() {
      _showLists = !_showLists;
    });
  }

  void _switchToListMode(bool toMosaicList) {
    setState(() {
      showMosaicList = toMosaicList;
      showVehicleDirectList = !toMosaicList;
      _currentVideoOrder.clear();
      _selectedDirectChannels.clear();

      players.forEach((key, value) => value.dispose());
      players.clear();
      controllers.clear();
      videoStatuses.clear();
      videoErrors.clear();
      _videoMetadata.clear();
      isLoadingGlobal = false;
    });
  }

  void _onChannelToggleDirect(Map<String, dynamic> vehicle, int channel, bool isSelected) async {
    final deviceSerial = vehicle['deviceSerial'];
    setState(() {
      _selectedDirectChannels.putIfAbsent(deviceSerial, () => []);
      if (isSelected) {
        _selectedDirectChannels[deviceSerial]?.add(channel);
      } else {
        _selectedDirectChannels[deviceSerial]?.remove(channel);
        if (_selectedDirectChannels[deviceSerial]?.isEmpty ?? false) {
          _selectedDirectChannels.remove(deviceSerial);
        }
      }
    });
    final vehicles = ref.read(vehiclesProvider);
    _manageVideoStreams(newItems: _getSelectedDirectVideoItems(vehicles));
  }

  List<Map<String, dynamic>> _getSelectedDirectVideoItems(List<Map<String, dynamic>> allVehicles) {
    return _selectedDirectChannels.entries.expand((entry) {
      final deviceSerial = entry.key;
      final channels = entry.value;
      final vehicle = allVehicles.firstWhere((v) => v['deviceSerial'] == deviceSerial);
      return channels.map((channel) => {
            'canal': channel,
            'veiculo': {
              'plate': vehicle['plate'],
              'deviceSerial': vehicle['deviceSerial'],
              'status': vehicle['status'],
            }
          });
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isSmallScreen = screenWidth < 900;

    final mosaics = ref.watch(mosaicsProvider);
    final vehicles = ref.watch(vehiclesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF1e262d),
      body: Stack(
        children: [
          Row(
            children: [
              Visibility(
                visible: _showLists,
                child: Expanded(
                  flex: 4,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            ElevatedButton(
                              onPressed: () => _switchToListMode(true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: showMosaicList ? const Color(0xFF0794bc) : Colors.transparent,
                                side: const BorderSide(color: Colors.white),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                              ),
                              child: const Text('Mosaicos', style: TextStyle(color: Colors.white)),
                            ),
                            ElevatedButton(
                              onPressed: () => _switchToListMode(false),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: showVehicleDirectList ? const Color(0xFF0794bc) : Colors.transparent,
                                side: const BorderSide(color: Colors.white),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                              ),
                              child: const Text('Veículos Diretos', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: showMosaicList
                            ? (mosaics.isEmpty
                                ? Center(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (_) => AddMosaicoDialog(
                                            vehicles: vehicles,
                                            onSave: ref.read(mosaicsProvider.notifier).loadMosaics,
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        side: const BorderSide(color: Colors.white),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8.0),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                                      ),
                                      child: const Text(
                                        'Adicionar mosaico',
                                        style: TextStyle(color: Colors.white, fontSize: 18.0),
                                      ),
                                    ),
                                  )
                                : MosaicList(
                                    mosaics: mosaics,
                                    onDelete: confirmDeleteMosaic,
                                    onLoad: (frota) {
                                      final List<Map<String, dynamic>> items = (frota['itens'] as List).cast<Map<String, dynamic>>();
                                      _manageVideoStreams(newItems: items);
                                    },
                                    onEdit: (mosaicToEdit) {
                                      showDialog(
                                        context: context,
                                        builder: (_) => AddMosaicoDialog(
                                          vehicles: vehicles,
                                          onSave: ref.read(mosaicsProvider.notifier).loadMosaics,
                                          mosaicToEdit: mosaicToEdit,
                                        ),
                                      );
                                    },
                                  ))
                            : (showVehicleDirectList
                                ? VehicleChannelList(
                                    vehicles: vehicles,
                                    onChannelToggle: (vehicle, channel, isSelected) {
                                      _onChannelToggleDirect(vehicle, channel, isSelected);
                                    },
                                    selectedChannels: _selectedDirectChannels,
                                  )
                                : Container()),
                      ),
                      if (showMosaicList && mosaics.isNotEmpty)
                        Align(
                          alignment: Alignment.bottomLeft,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: ElevatedButton(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => AddMosaicoDialog(
                                    vehicles: vehicles,
                                    onSave: ref.read(mosaicsProvider.notifier).loadMosaics,
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                side: const BorderSide(color: Colors.white),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                              ),
                              child: const Text(
                                'Adicionar mosaico',
                                style: TextStyle(color: Colors.white, fontSize: 16.0),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: _showLists ? 16 : 20,
                child: _currentVideoOrder.isEmpty && !isLoadingGlobal && !videoStatuses.containsValue(VideoStreamStatus.loading)
                    ? const Center(
                        child: Text(
                          'Selecione um mosaico ou veículo para ver as câmeras',
                          style: TextStyle(color: Colors.white, fontSize: 18.0),
                        ),
                      )
                    : VideoGrid(
                        videoUrls: _currentVideoOrder,
                        controllers: controllers,
                        onFullScreen: _enterFullScreen,
                        videoStatuses: videoStatuses,
                        videoErrors: videoErrors,
                        videoMetadata: _videoMetadata,
                        onRemove: _removeVideoFromGrid, // Passa o callback de remoção
                      ),
              ),
            ],
          ),
          if (isLoadingGlobal)
            const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            ),
          Positioned(
            top: 16.0,
            right: 16.0,
            child: IconButton(
              icon: Icon(
                _showLists ? Icons.visibility_off : Icons.visibility,
                color: Colors.white,
              ),
              onPressed: _toggleListsVisibility,
            ),
          ),
        ],
      ),
    );
  }
}
