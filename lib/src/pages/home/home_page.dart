import 'dart:async';

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
  static const int _maxActiveStreams = 32;
  static const int _maxStreamPreparationAttempts = 5;

  // Mapas para gerenciar players e controladores de cada vídeo
  final Map<String, Player> players = {};
  final Map<String, VideoController> controllers = {};
  // Novo mapa para gerenciar o status de cada URL de vídeo individualmente
  final Map<String, VideoStreamStatus> videoStatuses = {};
  final Map<String, String> videoErrors = {};
  final Map<String, StreamSubscription<dynamic>> _playerSubscriptions = {};
  final Set<String> _loadingUrls = {};
  Set<String> _desiredVideoUrls = {};
  int _selectionRevision = 0;

  // Mapa para armazenar metadados (placa e canal) por URL de vídeo
  final Map<String, Map<String, dynamic>> _videoMetadata = {};

  List<String> _currentVideoOrder =
      []; // Ordem atual dos vídeos exibidos no grid

  bool isLoadingGlobal = false;
  bool showMosaicList = true;
  bool showVehicleDirectList = false;

  bool _showLists = true;

  final Map<String, List<int>> _selectedDirectChannels = {};

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
    _selectionRevision++;
    _desiredVideoUrls.clear();
    for (final subscription in _playerSubscriptions.values) {
      unawaited(subscription.cancel());
    }
    for (final player in players.values) {
      unawaited(player.dispose());
    }
    _playerSubscriptions.clear();
    players.clear();
    controllers.clear();
    super.dispose();
  }

  Future<void> _maximizeWindow() async {
    await windowManager.ensureInitialized();
    await windowManager.setMinimumSize(const Size(1024, 600));
    await windowManager.setResizable(true);
    await windowManager.maximize();
  }

  Future<void> _disposePlayer(String url) async {
    final subscription = _playerSubscriptions.remove(url);
    final player = players.remove(url);
    controllers.remove(url);

    await subscription?.cancel();
    await player?.dispose();
  }

  Future<void> _disposeAllPlayers() async {
    final urls = <String>{
      ...players.keys,
      ..._playerSubscriptions.keys,
    };
    await Future.wait(urls.map(_disposePlayer));
  }

  Future<void> confirmDeleteMosaic(int index) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color.fromARGB(255, 25, 32, 37),
          title: const Text(
            'Confirmar Exclusão',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18.0,
                fontWeight: FontWeight.bold),
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
          itensToClear
              .addAll((frota['itens'] as List).cast<Map<String, dynamic>>());
        }

        _selectionRevision++;
        _desiredVideoUrls.clear();
        await _clearMosaicVideos(itensToClear);
        await _disposeAllPlayers();
        ref.read(mosaicsProvider.notifier).deleteMosaic(index);

        if (!mounted) return;
        setState(() {
          _currentVideoOrder.clear();
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
    final Set<String> urlsToDispose = {};

    for (var item in items) {
      final canal = item['canal'];
      final deviceSerial = item['veiculo']?['deviceSerial'];

      if (deviceSerial != null) {
        final urlBaseVideo =
            'https://moovsec.alessat.com.br:3010/live/${deviceSerial}_$canal';
        urlsToDispose.add(urlBaseVideo);
      }
    }

    await Future.wait(urlsToDispose.map(_disposePlayer));

    if (!mounted) return;
    setState(() {
      _currentVideoOrder.removeWhere(urlsToDispose.contains);
      for (final url in urlsToDispose) {
        videoStatuses.remove(url);
        videoErrors.remove(url);
        _videoMetadata.remove(url);
      }
    });
  }

  Future<void> _manageVideoStreams(
      {required List<Map<String, dynamic>> newItems}) async {
    final revision = ++_selectionRevision;
    final apiService = ref.read(apiServiceProvider);
    final String token = widget.token;
    final Map<String, Map<String, dynamic>> uniqueItems = {};
    final Map<String, Map<String, dynamic>> tempNewVideoMetadata = {};

    for (final item in newItems) {
      final vehicle = item['veiculo'];
      if (vehicle is! Map || vehicle['deviceSerial'] == null) continue;
      final deviceSerial = vehicle['deviceSerial'].toString().trim();
      if (deviceSerial.isEmpty) continue;
      final canal = item['canal'] is int
          ? item['canal'] as int
          : int.tryParse(item['canal'].toString()) ?? 1;
      final url =
          'https://moovsec.alessat.com.br:3010/live/${deviceSerial}_$canal';
      uniqueItems.putIfAbsent(url, () => item);
      tempNewVideoMetadata.putIfAbsent(
          url,
          () => {
                'plate': vehicle['plate'],
                'channel': canal,
                'deviceSerial': deviceSerial,
              });
    }

    final limitedEntries = uniqueItems.entries.take(_maxActiveStreams).toList();
    final selectedUrls = limitedEntries.map((entry) => entry.key).toList();
    final selectedUrlSet = selectedUrls.toSet();
    _desiredVideoUrls = selectedUrlSet;

    final urlsToRemove = players.keys
        .where((url) => !selectedUrlSet.contains(url))
        .toList(growable: false);
    final requestedUrlsToLoad = <String>[];
    for (final url in selectedUrls) {
      if (!players.containsKey(url) && !_loadingUrls.contains(url)) {
        requestedUrlsToLoad.add(url);
      }
    }

    if (!mounted) return;
    setState(() {
      _currentVideoOrder = selectedUrls;
      _videoMetadata
        ..clear()
        ..addEntries(tempNewVideoMetadata.entries
            .where((entry) => selectedUrlSet.contains(entry.key)));
      for (final url in urlsToRemove) {
        videoStatuses.remove(url);
        videoErrors.remove(url);
      }
      for (final url in requestedUrlsToLoad) {
        videoStatuses[url] = VideoStreamStatus.loading;
        videoErrors.remove(url);
      }
    });

    // Libera os streams antigos antes de solicitar novos ao servidor.
    await Future.wait(urlsToRemove.map(_disposePlayer));
    if (!mounted || revision != _selectionRevision) return;

    final actualUrlsToLoad = <String>[];
    for (final url in selectedUrls) {
      if (!players.containsKey(url) && _loadingUrls.add(url)) {
        actualUrlsToLoad.add(url);
      }
    }

    if (uniqueItems.length > _maxActiveStreams) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
          'Cada visualizacao aceita no maximo 32 cameras simultaneas.',
        ),
      ));
    }

    final loadTasks = <Future<void>>[];
    for (final entry in limitedEntries) {
      if (!actualUrlsToLoad.contains(entry.key)) continue;
      final item = entry.value;
      final vehicle = item['veiculo'] as Map;
      final deviceSerial = vehicle['deviceSerial'].toString();
      final canal = item['canal'] is int
          ? item['canal'] as int
          : int.tryParse(item['canal'].toString()) ?? 1;
      loadTasks.add(_loadSingleVideo(
          entry.key, deviceSerial, canal, vehicle, apiService, token));
    }

    try {
      await Future.wait(loadTasks);
    } catch (e) {
      print('Erro ao gerenciar streams de vídeo: $e');
    } finally {
      if (mounted && revision == _selectionRevision) {
        setState(() {
          isLoadingGlobal = false;
        });
      }
    }
  }

  // NOVO: Método para remover um vídeo da grid E atualizar a seleção direta
  Future<void> _removeVideoFromGrid(String videoUrl) async {
    _desiredVideoUrls.remove(videoUrl);
    setState(() {
      _currentVideoOrder.remove(videoUrl);
      videoStatuses.remove(videoUrl);
      videoErrors.remove(videoUrl);

      // 2. Tentar atualizar _selectedDirectChannels
      final metadata = _videoMetadata[videoUrl];
      if (metadata != null &&
          metadata.containsKey('deviceSerial') &&
          metadata.containsKey('channel')) {
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
    await _disposePlayer(videoUrl);
  }

  Future<void> _clearAllVideos() async {
    _selectionRevision++;
    _desiredVideoUrls.clear();
    setState(() {
      videoStatuses.clear();
      videoErrors.clear();
      _videoMetadata.clear();
      _currentVideoOrder.clear();
      _selectedDirectChannels.clear();
      isLoadingGlobal = false;
    });
    await _disposeAllPlayers();
  }

  Future<void> _loadSingleVideo(
    String urlBaseVideo,
    String deviceSerial,
    int canal,
    dynamic veiculo,
    ApiService apiService,
    String token,
  ) async {
    Player? createdPlayer;
    StreamSubscription<dynamic>? errorSubscription;
    try {
      String? address;
      var isTemporaryImage = false;
      for (var attempt = 1;
          attempt <= _maxStreamPreparationAttempts;
          attempt++) {
        if (!mounted || !_desiredVideoUrls.contains(urlBaseVideo)) return;

        final urlData = await apiService.liveMedia(deviceSerial, token, canal);
        address = urlData?['address']?.toString().trim();
        final lowerAddress = address?.toLowerCase() ?? '';
        isTemporaryImage = urlData?['isThumbnail'] == true ||
            lowerAddress.endsWith('.jpg') ||
            lowerAddress.endsWith('.jpeg') ||
            lowerAddress.endsWith('.png');

        if (address != null && address.isNotEmpty && !isTemporaryImage) {
          break;
        }

        if (attempt < _maxStreamPreparationAttempts) {
          final delaySeconds = (1 << (attempt - 1)).clamp(1, 8);
          await Future.delayed(Duration(seconds: delaySeconds));
        }
      }

      if (!mounted || !_desiredVideoUrls.contains(urlBaseVideo)) return;
      if (address == null || address.isEmpty || isTemporaryImage) {
        throw TimeoutException(
          'Câmera offline ou sem HLS após '
          '$_maxStreamPreparationAttempts tentativas.',
        );
      }

      final lowerAddress = address.toLowerCase();
      if (!lowerAddress.endsWith('.m3u8')) {
        throw FormatException('A mídia retornada não é HLS: $address');
      }

      final actualStreamUrl = address.startsWith('http')
          ? address
          : '${apiService.baseUrlMedia}$address';
      print(
          'URL FINAL DO STREAM [$deviceSerial canal $canal]: $actualStreamUrl');

      final player = Player(
          configuration: const PlayerConfiguration(
        vo: 'gpu',
        bufferSize: 4 * 1024 * 1024,
      ));
      createdPlayer = player;
      final controller = VideoController(player);

      final media = Media(actualStreamUrl, httpHeaders: {
        'Authorization': 'Bearer $token',
        'Cache-Control': 'max-age=0, no-cache',
        'Pragma': 'no-cache',
        'Accept': 'application/vnd.apple.mpegurl, application/x-mpegURL, */*',
        'User-Agent': 'grupo_alessat_app/2.0.2',
      });

      errorSubscription = player.stream.error.listen((error) {
        print('Player para $actualStreamUrl encontrou um erro: "$error".');
        unawaited(_handlePlayerError(
          urlBaseVideo,
          player,
          'Erro ao abrir stream: $error',
        ));
      });

      await player.open(media, play: true);
      await player.setVolume(0);

      if (!mounted || !_desiredVideoUrls.contains(urlBaseVideo)) return;

      setState(() {
        players[urlBaseVideo] = player;
        controllers[urlBaseVideo] = controller;
        _playerSubscriptions[urlBaseVideo] = errorSubscription!;
        videoStatuses[urlBaseVideo] = VideoStreamStatus.loaded;
        videoErrors.remove(urlBaseVideo);
      });
      createdPlayer = null;
      errorSubscription = null;
    } catch (e) {
      if (!mounted || !_desiredVideoUrls.contains(urlBaseVideo)) return;
      setState(() {
        videoStatuses[urlBaseVideo] = VideoStreamStatus.error;
        videoErrors[urlBaseVideo] =
            'Erro ao obter mídia do dispositivo: $deviceSerial '
            '(canal: $canal). Erro: $e';
      });
    } finally {
      _loadingUrls.remove(urlBaseVideo);
      await errorSubscription?.cancel();
      await createdPlayer?.dispose();
    }
  }

  Future<void> _handlePlayerError(
      String url, Player player, String error) async {
    if (!mounted || players[url] != player) return;
    setState(() {
      videoStatuses[url] = VideoStreamStatus.error;
      videoErrors[url] = error;
    });
    await _disposePlayer(url);
  }

  Future<void> _retrySingleVideo(String url) async {
    if (!_desiredVideoUrls.contains(url) || _loadingUrls.contains(url)) return;
    final metadata = _videoMetadata[url];
    if (metadata == null) return;

    await _disposePlayer(url);
    if (!mounted ||
        !_desiredVideoUrls.contains(url) ||
        !_loadingUrls.add(url)) {
      return;
    }

    final deviceSerial = metadata['deviceSerial'].toString();
    final canal = metadata['channel'] is int
        ? metadata['channel'] as int
        : int.tryParse(metadata['channel'].toString()) ?? 1;
    setState(() {
      videoStatuses[url] = VideoStreamStatus.loading;
      videoErrors.remove(url);
    });

    await _loadSingleVideo(
      url,
      deviceSerial,
      canal,
      {
        'deviceSerial': deviceSerial,
        'plate': metadata['plate'],
        'status': 'connected',
      },
      ref.read(apiServiceProvider),
      widget.token,
    );
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

  Future<void> _switchToListMode(bool toMosaicList) async {
    _selectionRevision++;
    _desiredVideoUrls.clear();
    setState(() {
      showMosaicList = toMosaicList;
      showVehicleDirectList = !toMosaicList;
      _currentVideoOrder.clear();
      _selectedDirectChannels.clear();

      videoStatuses.clear();
      videoErrors.clear();
      _videoMetadata.clear();
      isLoadingGlobal = false;
    });
    await _disposeAllPlayers();
  }

  void _onChannelToggleDirect(
      Map<String, dynamic> vehicle, int channel, bool isSelected) async {
    final deviceSerial = vehicle['deviceSerial'];
    setState(() {
      _selectedDirectChannels.putIfAbsent(deviceSerial, () => []);
      if (isSelected) {
        if (!(_selectedDirectChannels[deviceSerial]?.contains(channel) ??
            false)) {
          _selectedDirectChannels[deviceSerial]?.add(channel);
        }
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

  List<Map<String, dynamic>> _getSelectedDirectVideoItems(
      List<Map<String, dynamic>> allVehicles) {
    return _selectedDirectChannels.entries.expand((entry) {
      final deviceSerial = entry.key;
      final channels = entry.value;
      final vehicle =
          allVehicles.firstWhere((v) => v['deviceSerial'] == deviceSerial);
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
                child: SizedBox(
                  width: (MediaQuery.of(context).size.width * 0.22)
                      .clamp(280.0, 340.0),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Wrap(
                          spacing: 8.0,
                          runSpacing: 8.0,
                          alignment: WrapAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: () => _switchToListMode(true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: showMosaicList
                                    ? const Color(0xFF0794bc)
                                    : Colors.transparent,
                                side: const BorderSide(color: Colors.white),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0, vertical: 8.0),
                              ),
                              child: const Text('Mosaicos',
                                  style: TextStyle(color: Colors.white)),
                            ),
                            ElevatedButton(
                              onPressed: () => _switchToListMode(false),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: showVehicleDirectList
                                    ? const Color(0xFF0794bc)
                                    : Colors.transparent,
                                side: const BorderSide(color: Colors.white),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0, vertical: 8.0),
                              ),
                              child: const Text('Câmeras por Veículo',
                                  style: TextStyle(color: Colors.white)),
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
                                            onSave: ref
                                                .read(mosaicsProvider.notifier)
                                                .loadMosaics,
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        side: const BorderSide(
                                            color: Colors.white),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8.0),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 24.0, vertical: 12.0),
                                      ),
                                      child: const Text(
                                        'Adicionar mosaico',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18.0),
                                      ),
                                    ),
                                  )
                                : MosaicList(
                                    mosaics: mosaics,
                                    vehicles: vehicles,
                                    onDelete: confirmDeleteMosaic,
                                    onLoad: (frota) {
                                      final List<Map<String, dynamic>> items =
                                          (frota['itens'] as List)
                                              .cast<Map<String, dynamic>>();

                                      // Check if any vehicle in the loaded items is offline
                                      bool hasOfflineVehicle = false;
                                      for (var item in items) {
                                        final deviceSerial =
                                            item['veiculo']?['deviceSerial'];
                                        final plate = item['veiculo']?['plate'];

                                        // Try finding by deviceSerial
                                        Map<String, dynamic> liveVehicle = {};
                                        if (deviceSerial != null) {
                                          liveVehicle = vehicles.firstWhere(
                                            (v) =>
                                                v['deviceSerial'] ==
                                                deviceSerial,
                                            orElse: () => <String, dynamic>{},
                                          );
                                        }
                                        // Fallback to plate
                                        if (liveVehicle.isEmpty &&
                                            plate != null) {
                                          liveVehicle = vehicles.firstWhere(
                                            (v) => v['plate'] == plate,
                                            orElse: () => <String, dynamic>{},
                                          );
                                        }

                                        if (liveVehicle.isEmpty ||
                                            liveVehicle['status'] !=
                                                'connected') {
                                          hasOfflineVehicle = true;
                                          break;
                                        }
                                      }

                                      if (hasOfflineVehicle) {
                                        ScaffoldMessenger.of(context)
                                            .clearSnackBars();
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Este veículo parece offline. A câmera pode não carregar.'),
                                            duration: Duration(seconds: 4),
                                            backgroundColor:
                                                Colors.orangeAccent,
                                          ),
                                        );
                                      }

                                      _manageVideoStreams(newItems: items);
                                    },
                                    onEdit: (mosaicToEdit) {
                                      showDialog(
                                        context: context,
                                        builder: (_) => AddMosaicoDialog(
                                          vehicles: vehicles,
                                          onSave: ref
                                              .read(mosaicsProvider.notifier)
                                              .loadMosaics,
                                          mosaicToEdit: mosaicToEdit,
                                        ),
                                      );
                                    },
                                  ))
                            : (showVehicleDirectList
                                ? VehicleChannelList(
                                    vehicles: vehicles,
                                    onChannelToggle:
                                        (vehicle, channel, isSelected) {
                                      _onChannelToggleDirect(
                                          vehicle, channel, isSelected);
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
                                    onSave: ref
                                        .read(mosaicsProvider.notifier)
                                        .loadMosaics,
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                side: const BorderSide(color: Colors.white),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24.0, vertical: 12.0),
                              ),
                              child: const Text(
                                'Adicionar mosaico',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 16.0),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: _currentVideoOrder.isEmpty &&
                        !isLoadingGlobal &&
                        !videoStatuses.containsValue(VideoStreamStatus.loading)
                    ? Center(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.videocam_off,
                                color: Colors.white.withOpacity(0.35),
                                size: 64,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Nenhuma câmera selecionada',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Escolha um veículo na lateral e marque os canais que deseja visualizar.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 14.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  _currentVideoOrder.length == 1
                                      ? '1 câmera aberta'
                                      : '${_currentVideoOrder.length} câmeras abertas',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 24.0),
                                TextButton.icon(
                                  onPressed: _clearAllVideos,
                                  icon: const Icon(Icons.clear_all,
                                      color: Colors.redAccent, size: 18),
                                  label: const Text(
                                    'Fechar todas',
                                    style: TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 13.0),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0, vertical: 4.0),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: VideoGrid(
                              videoUrls: _currentVideoOrder,
                              controllers: controllers,
                              onFullScreen: _enterFullScreen,
                              videoStatuses: videoStatuses,
                              videoErrors: videoErrors,
                              videoMetadata: _videoMetadata,
                              onRemove: _removeVideoFromGrid,
                              onRetry: _retrySingleVideo,
                            ),
                          ),
                        ],
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
