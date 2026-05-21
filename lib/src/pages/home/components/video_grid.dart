// video_grid.dart
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
  final Function(String videoUrl) onRemove; // NOVO: Callback para remover vídeo

  const VideoGrid({
    super.key,
    required this.videoUrls,
    required this.controllers,
    required this.onFullScreen,
    required this.videoStatuses,
    required this.videoErrors,
    required this.videoMetadata,
    required this.onRemove, // REQUERIDO
  });

  @override
  State<VideoGrid> createState() => _VideoGridState();
}

class _VideoGridState extends State<VideoGrid> {
  late List<String> _videos;
  String? _hoveredVideoUrl; // Estado para rastrear qual vídeo está sendo hoverado

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
        final crossAxisCount = (constraints.maxWidth / 204).floor();
        return ReorderableGridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 14 / 9,
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

            Widget content;

            if (status == VideoStreamStatus.loading) {
              content = const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            } else if (status == VideoStreamStatus.error) {
              content = Center(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    errorMessage ?? 'Erro no dispositivo!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red, fontSize: 14.0),
                  ),
                ),
              );
            } else if (status == VideoStreamStatus.loaded && widget.controllers[url] != null && url.isNotEmpty) {
              content = Stack(
                children: [
                  Video(
                    aspectRatio: 16 / 9,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.low,
                    controller: widget.controllers[url]!,
                  ),
                  // Metadados (Placa e Canal)
                  Positioned(
                    top: 20.0,
                    left: 8.0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.0),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: Text(
                        '$plate | Canal $channel',
                        style: const TextStyle(color: Colors.white, fontSize: 8.0, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  // Botão de tela cheia
                  Positioned(
                    bottom: 12.0,
                    right: 8.0,
                    child: IconButton(
                      icon: const Icon(Icons.fullscreen, color: Colors.white),
                      onPressed: () {
                        widget.onFullScreen(url);
                      },
                    ),
                  ),
                  // NOVO: Botão de "X" para remover (visível apenas no hover)
                  if (_hoveredVideoUrl == url) // Só mostra se este vídeo está sendo hoverado
                    Positioned(
                      top: 4.0, // Ajuste a posição conforme necessário
                      right: 4.0, // Ajuste a posição conforme necessário
                      child: IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.red, size: 20.0), // Ícone de "X"
                        onPressed: () {
                          widget.onRemove(url); // Chama o callback de remoção
                          setState(() {
                            _hoveredVideoUrl = null; // Reseta o hover após clicar
                          });
                        },
                      ),
                    ),
                ],
              );
            } else {
              content = const Center(
                child: Text(
                  'Aguardando vídeo...',
                  style: TextStyle(color: Colors.grey, fontSize: 14.0),
                ),
              );
            }

            return ReorderableDelayedDragStartListener(
              key: ValueKey(url),
              index: index,
              child: MouseRegion(
                // NOVO: Detecta entrada e saída do mouse
                onEnter: (_) {
                  setState(() {
                    _hoveredVideoUrl = url;
                  });
                },
                onExit: (_) {
                  setState(() {
                    _hoveredVideoUrl = null;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.all(5.0),
                  color: Colors.black,
                  child: content,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
