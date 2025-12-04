import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoAsset;
  final Widget? nextScreen;
  const VideoPlayerScreen({super.key, required this.videoAsset, this.nextScreen});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.asset(widget.videoAsset)
      ..initialize().then((_) {
        setState(() {});
        _videoController.play();
      });

    _chewieController = ChewieController(
      videoPlayerController: _videoController,
      autoPlay: true,
      looping: false,
    );
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vídeo do exercício')),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _videoController.value.isInitialized
                  ? AspectRatio(
                      aspectRatio: _videoController.value.aspectRatio,
                      child: Chewie(controller: _chewieController!),
                    )
                  : const CircularProgressIndicator(),
            ),
          ),
          if (widget.nextScreen != null) ...[
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => widget.nextScreen!)),
                  child: const Text('Iniciar Coleta'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
