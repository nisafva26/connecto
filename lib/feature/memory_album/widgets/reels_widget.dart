import 'dart:developer';

import 'package:connecto/feature/memory_album/models/reels_model.dart';
import 'package:connecto/feature/memory_album/screens/memories_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

class CreateReelButton extends ConsumerWidget {
  const CreateReelButton({required this.gid});
  final String gid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(reelsJobsProvider(gid)).value ?? const <ReelJob>[];
    final hasActive = jobs.any((j) => j.isActive);

    return FilledButton.icon(
      onPressed: hasActive
          ? null
          : () async {
              try {
                await ref.read(reelsRepoProvider).startJob(gid);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reel generation started')));
              } catch (e) {
                log('error : $e');
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to start: $e')));
              }
            },
      icon: const Icon(Icons.movie_creation_outlined),
      label: Text(hasActive ? 'Generating…' : 'Create reel'),
    );
  }
}

class ReelProgressTile extends StatelessWidget {
  const ReelProgressTile({required this.job});
  final ReelJob job;

  @override
  Widget build(BuildContext context) {
    final pct = (job.progress.clamp(0, 100)) / 100.0;
    final subtitle = job.status == 'queued'
        ? 'Queued'
        : job.status == 'running'
            ? 'Rendering…'
            : job.status == 'error'
                ? 'Error'
                : job.status;

    return ListTile(
      leading: const Icon(Icons.timelapse),
      title: Text('Reel is generating (${job.progress}%)'),
      subtitle: Text(subtitle),
      trailing: SizedBox(
        width: 140,
        child: LinearProgressIndicator(value: pct),
      ),
    );
  }
}

class ReelDoneTile extends ConsumerWidget {
  const ReelDoneTile({required this.job});
  final ReelJob job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      color: Color(0xff091F1E),
      child: ListTile(
        leading: const Icon(Icons.movie),
        title: Text(
            'Reel • ${job.finishedAt != null ? job.finishedAt!.toLocal().toString().split(".").first : ""}'),
        subtitle: Text(job.gcsPath ?? ''),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Open',
              icon: const Icon(Icons.open_in_new),
              onPressed: job.gcsPath == null
                  ? null
                  : () async {
                      final url = await ref
                          .read(reelsRepoProvider)
                          .urlForGcsPath(job.gcsPath!);
                      // open in external player as a fallback
                      await launchUrl(Uri.parse(url),
                          mode: LaunchMode.externalApplication);
                    },
            ),
            IconButton(
              tooltip: 'Play',
              icon: const Icon(Icons.play_circle_outline),
              onPressed: job.gcsPath == null
                  ? null
                  : () async {
                      log('gcs path : ${job.gcsPath!}');
                      final url = await ref
                          .read(reelsRepoProvider)
                          .urlForGcsPath(job.gcsPath!);
                      log('video url : $url');
                      // show simple in-app dialog player
                      // ignore: use_build_context_synchronously
                      // showDialog(context: context, builder: (_) => _VideoDialog(url: url));
                      // Navigate to the new full-screen VideoPage
                      // ignore: use_build_context_synchronously
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => VideoPage(url: url),
                        ),
                      );
                    },
            ),
          ],
        ),
      ),
    );
  }
}

// Import the necessary flutter libraries

// Renamed for clarity: VideoPage is a full-screen widget
class VideoPage extends StatefulWidget {
  const VideoPage({super.key, required this.url});
  final String url;

  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> {
  late VideoPlayerController _c;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _c = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        setState(() => _ready = true);
        _c.play();
      });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          Colors.black, // Set background to black for a cinematic look
      appBar: AppBar(
        backgroundColor: Colors.transparent, // Make the app bar transparent
        elevation: 0, // Remove the shadow
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(), // Pop to go back
        ),
      ),
      body: Center(
        child: _ready
            ? AspectRatio(
                aspectRatio: _c.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    VideoPlayer(_c),
                    VideoProgressIndicator(_c, allowScrubbing: true),
                  ],
                ),
              )
            : const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
      ),
    );
  }
}

// class _VideoDialog extends StatefulWidget {
//   const _VideoDialog({required this.url});
//   final String url;

//   @override
//   State<_VideoDialog> createState() => _VideoDialogState();
// }

// class _VideoDialogState extends State<_VideoDialog> {
//   late VideoPlayerController _c;
//   bool _ready = false;

//   @override
//   void initState() {
//     super.initState();
//     _c = VideoPlayerController.networkUrl(Uri.parse(widget.url))
//       ..initialize().then((_) {
//         setState(() => _ready = true);
//         _c.play();
//       });
//   }

//   @override
//   void dispose() {
//     _c.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Dialog(
//       child: AspectRatio(
//         aspectRatio: _ready ? _c.value.aspectRatio : 9/16,
//         child: _ready
//             ? Stack(
//                 alignment: Alignment.bottomCenter,
//                 children: [
//                   VideoPlayer(_c),
//                   VideoProgressIndicator(_c, allowScrubbing: true),
//                 ],
//               )
//             : const SizedBox(
//                 height: 300,
//                 child: Center(child: CircularProgressIndicator()),
//               ),
//       ),
//     );
//   }
// }
