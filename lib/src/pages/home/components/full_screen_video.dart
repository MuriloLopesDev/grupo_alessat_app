import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

class FullScreenVideo extends StatelessWidget {
  final VideoController controller;

  const FullScreenVideo({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Video(
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
                controller: controller,
              ),
            ),
          ),
          Positioned(
            top: 16.0,
            left: 16.0,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ),
        ],
      ),
    );
  }
}
