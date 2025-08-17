import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPage extends StatefulWidget {
  const VideoPage({required this.urlFuture, required this.heroTag});
  final Future<String> urlFuture;
  final String heroTag;

  @override
  State<VideoPage> createState() => _VideoPageState();
}
class _VideoPageState extends State<VideoPage> with AutomaticKeepAliveClientMixin {
  VideoPlayerController? _ctrl;
  String? _url;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    widget.urlFuture.then((u) async {
      _url = u;
      _ctrl = VideoPlayerController.networkUrl(Uri.parse(u));
      await _ctrl!.initialize();
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (!_ready) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    return Hero(
      tag: widget.heroTag,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: _ctrl!.value.aspectRatio,
            child: VideoPlayer(_ctrl!),
          ),
          IconButton(
            iconSize: 56,
            color: Colors.white70,
            icon: Icon(_ctrl!.value.isPlaying ? Icons.pause_circle : Icons.play_circle),
            onPressed: () {
              setState(() {
                _ctrl!.value.isPlaying ? _ctrl!.pause() : _ctrl!.play();
              });
            },
          ),
        ],
      ),
    );
  }
}


