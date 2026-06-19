// video_grid.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'package:grupo_alessat_app/src/pages/home/home_page.dart'; // Importar o enum VideoStreamStatus

class VideoGrid extends StatefulWidget {
  final List<String> videoUrls;
  final Map<String, VideoController> controllers;
  final Function(String) onFullScreen;
  final Map<String, VideoStreamStatus> videoStatuses;
  final Map<String, String> videoErrors;
  final Map<String, Map<String, dynamic>> videoMetadata;
  final Function(String videoUrl) onRemove;
  final Function(String videoUrl) onRetry;

  const VideoGrid({
    super.key,
    required this.videoUrls,
    required this.controllers,
    required this.onFullScreen,
    required this.videoStatuses,
    required this.videoErrors,
    required this.videoMetadata,
    required this.onRemove,
    required this.onRetry,
  });

  @override
  State<VideoGrid> createState() => _VideoGridState();
}

class _VideoGridState extends State<VideoGrid> {
  late List<String> _videos;

  @override
  void initState() {
    super.initState();
    _videos = List.from(widget.videoUrls);
  }

  @override
  void didUpdateWidget(covariant VideoGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrls != widget.videoUrls) {
      setState(() {
        _videos = List.from(widget.videoUrls);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = (constraints.maxWidth / 240).floor();
        if (crossAxisCount < 1) crossAxisCount = 1;
        return ReorderableGridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 16 / 9,
          ),
          onReorder: (oldIndex, newIndex) {
            setState(() {
              final item = _videos.removeAt(oldIndex);
              _videos.insert(newIndex, item);
            });
          },
          itemCount: _videos.length,
          itemBuilder: (context, index) {
            final url = _videos[index];
            final status = widget.videoStatuses[url] ?? VideoStreamStatus.inactive;
            final errorMessage = widget.videoErrors[url];
            final metadata = widget.videoMetadata[url];
            final plate = metadata?['plate'] ?? 'N/A';
            final channel = metadata?['channel'] ?? 'N/A';

            return ReorderableDelayedDragStartListener(
              key: ValueKey(url),
              index: index,
              child: VideoTile(
                url: url,
                controller: widget.controllers[url],
                status: status,
                errorMessage: errorMessage,
                plate: plate,
                channel: channel,
                onFullScreen: () => widget.onFullScreen(url),
                onRemove: () => widget.onRemove(url),
                onRetry: () => widget.onRetry(url),
              ),
            );
          },
        );
      },
    );
  }
}

class VideoLoadingWidget extends StatelessWidget {
  const VideoLoadingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: const Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white, strokeWidth: 3.0),
              SizedBox(height: 12),
              Text(
                'Carregando câmera...',
                style: TextStyle(color: Colors.white70, fontSize: 11.0),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VideoErrorWidget extends StatelessWidget {
  final String? errorMessage;
  final VoidCallback onRetry;

  const VideoErrorWidget({
    super.key,
    required this.errorMessage,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(8.0),
      child: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxHeight < 120;
            return SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.videocam_off,
                    color: Colors.redAccent,
                    size: isCompact ? 20.0 : 28.0,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    errorMessage ?? 'Erro de conexão!',
                    textAlign: TextAlign.center,
                    maxLines: isCompact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: isCompact ? 9.0 : 11.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: Icon(Icons.refresh, size: isCompact ? 10 : 14),
                    label: Text(
                      'Reconectar',
                      style: TextStyle(fontSize: isCompact ? 8.0 : 10.0),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0794bc),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompact ? 6.0 : 10.0,
                        vertical: isCompact ? 2.0 : 4.0,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class VideoTile extends StatefulWidget {
  final String url;
  final VideoController? controller;
  final VideoStreamStatus status;
  final String? errorMessage;
  final String plate;
  final dynamic channel;
  final VoidCallback onFullScreen;
  final VoidCallback onRemove;
  final VoidCallback onRetry;

  const VideoTile({
    super.key,
    required this.url,
    required this.controller,
    required this.status,
    required this.errorMessage,
    required this.plate,
    required this.channel,
    required this.onFullScreen,
    required this.onRemove,
    required this.onRetry,
  });

  @override
  State<VideoTile> createState() => _VideoTileState();
}

class _VideoTileState extends State<VideoTile> {
  bool _isHovered = false;
  StreamSubscription<bool>? _bufferingSubscription;
  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<double>? _volumeSubscription;
  
  bool _hasStartedPlaying = false;
  bool _showBufferingLoader = false;
  double _volume = 0.0;
  Timer? _bufferingTimer;

  @override
  void initState() {
    super.initState();
    _subscribeToBuffering();
    _subscribeToPlaying();
    _subscribeToVolume();
  }

  @override
  void didUpdateWidget(VideoTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller || oldWidget.status != widget.status) {
      _unsubscribeFromBuffering();
      _unsubscribeFromPlaying();
      _unsubscribeFromVolume();
      setState(() {
        _hasStartedPlaying = false;
        _showBufferingLoader = false;
        _volume = 0.0;
      });
      _subscribeToBuffering();
      _subscribeToPlaying();
      _subscribeToVolume();
    }
  }

  @override
  void dispose() {
    _unsubscribeFromBuffering();
    _unsubscribeFromPlaying();
    _unsubscribeFromVolume();
    super.dispose();
  }

  void _subscribeToPlaying() {
    if (widget.controller != null) {
      _hasStartedPlaying = widget.controller!.player.state.playing;
      _playingSubscription = widget.controller!.player.stream.playing.listen((playing) {
        if (mounted && playing) {
          setState(() {
            _hasStartedPlaying = true;
          });
        }
      });
    } else {
      _hasStartedPlaying = false;
    }
  }

  void _unsubscribeFromPlaying() {
    _playingSubscription?.cancel();
    _playingSubscription = null;
  }

  void _subscribeToVolume() {
    if (widget.controller != null) {
      _volume = widget.controller!.player.state.volume;
      _volumeSubscription = widget.controller!.player.stream.volume.listen((volume) {
        if (mounted) {
          setState(() {
            _volume = volume;
          });
        }
      });
    } else {
      _volume = 0.0;
    }
  }

  void _unsubscribeFromVolume() {
    _volumeSubscription?.cancel();
    _volumeSubscription = null;
  }

  void _subscribeToBuffering() {
    if (widget.controller != null) {
      final isCurrentlyBuffering = widget.controller!.player.state.buffering;
      _handleBufferingChange(isCurrentlyBuffering);

      _bufferingSubscription = widget.controller!.player.stream.buffering.listen((buffering) {
        if (mounted) {
          _handleBufferingChange(buffering);
        }
      });
    } else {
      _showBufferingLoader = false;
    }
  }

  void _handleBufferingChange(bool buffering) {
    if (buffering) {
      if (_hasStartedPlaying) {
        // Buffering occurred after playback started. We wait 2 seconds before showing the loader.
        _bufferingTimer?.cancel();
        _bufferingTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _showBufferingLoader = true;
            });
          }
        });
      } else {
        // Hasn't started playing yet, show loader immediately.
        setState(() {
          _showBufferingLoader = true;
        });
      }
    } else {
      // Buffering ended
      _bufferingTimer?.cancel();
      _bufferingTimer = null;
      setState(() {
        _showBufferingLoader = false;
      });
    }
  }

  void _unsubscribeFromBuffering() {
    _bufferingSubscription?.cancel();
    _bufferingSubscription = null;
    _bufferingTimer?.cancel();
    _bufferingTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (widget.status == VideoStreamStatus.loading) {
      content = const VideoLoadingWidget();
    } else if (widget.status == VideoStreamStatus.error) {
      content = VideoErrorWidget(
        errorMessage: widget.errorMessage,
        onRetry: widget.onRetry,
      );
    } else if (widget.status == VideoStreamStatus.loaded && widget.controller != null && widget.url.isNotEmpty) {
      content = LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 180 || constraints.maxHeight < 100;
          final hideText = constraints.maxWidth < 120 || constraints.maxHeight < 70;

          final soundButton = Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                _volume > 0.0 ? Icons.volume_up : Icons.volume_off,
                color: Colors.white,
                size: isCompact ? 14.0 : 18.0,
              ),
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(
                minWidth: isCompact ? 22.0 : 28.0,
                minHeight: isCompact ? 22.0 : 28.0,
              ),
              onPressed: () {
                final player = widget.controller?.player;
                if (player != null) {
                  if (player.state.volume == 0.0) {
                    player.setVolume(100.0);
                  } else {
                    player.setVolume(0.0);
                  }
                }
              },
            ),
          );

          final Widget soundWidget = isCompact
              ? soundButton
              : Tooltip(
                  message: _volume > 0.0 ? 'Desativar som' : 'Ativar som',
                  child: soundButton,
                );

          final fullscreenButton = IconButton(
            icon: Icon(Icons.fullscreen, color: Colors.white, size: isCompact ? 16.0 : 20.0),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(
              minWidth: isCompact ? 20.0 : 28.0,
              minHeight: isCompact ? 20.0 : 28.0,
            ),
            onPressed: widget.onFullScreen,
          );

          final Widget fullscreenWidget = isCompact
              ? fullscreenButton
              : Tooltip(
                  message: 'Tela cheia',
                  child: fullscreenButton,
                );

          final removeButton = IconButton(
            icon: Icon(Icons.cancel, color: Colors.redAccent, size: isCompact ? 16.0 : 20.0),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(
              minWidth: isCompact ? 20.0 : 28.0,
              minHeight: isCompact ? 20.0 : 28.0,
            ),
            onPressed: widget.onRemove,
          );

          final Widget removeWidget = isCompact
              ? removeButton
              : Tooltip(
                  message: 'Remover câmera',
                  child: removeButton,
                );

          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Video(
                aspectRatio: 16 / 9,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.low,
                controller: widget.controller!,
                controls: NoVideoControls,
              ),
              if (_showBufferingLoader)
                const Positioned.fill(
                  child: VideoLoadingWidget(),
                ),
              // Metadados (Placa e Canal)
              if (!hideText)
                Positioned(
                  top: isCompact ? 4.0 : 8.0,
                  left: isCompact ? 4.0 : 8.0,
                  right: isCompact ? 32.0 : 48.0,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompact ? 3.0 : 6.0,
                        vertical: isCompact ? 1.5 : 3.0,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: Text(
                        '${widget.plate} | Canal ${widget.channel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isCompact ? 6.0 : 8.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              // Botão de som (canto inferior esquerdo)
              Positioned(
                bottom: isCompact ? 4.0 : 8.0,
                left: isCompact ? 4.0 : 8.0,
                child: soundWidget,
              ),
              // Botão de tela cheia (canto inferior direito)
              Positioned(
                bottom: isCompact ? 4.0 : 8.0,
                right: isCompact ? 4.0 : 8.0,
                child: fullscreenWidget,
              ),
              // Botão de "X" para remover (visível apenas no hover, canto superior direito)
              if (_isHovered)
                Positioned(
                  top: isCompact ? 4.0 : 8.0,
                  right: isCompact ? 4.0 : 8.0,
                  child: removeWidget,
                ),
            ],
          );
        },
      );
    } else {
      content = const Center(
        child: Text(
          'Aguardando vídeo...',
          style: TextStyle(color: Colors.grey, fontSize: 13.0),
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        margin: const EdgeInsets.all(5.0),
        color: Colors.black,
        child: content,
      ),
    );
  }
}
