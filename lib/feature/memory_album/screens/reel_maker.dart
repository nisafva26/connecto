


// import 'dart:async';
// import 'dart:io';
// import 'package:file_picker/file_picker.dart';
// import 'package:flutter/material.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:ffmpeg_kit_flutter_min_gpl/ffmpeg_kit.dart';
// import 'package:ffmpeg_kit_flutter_min_gpl/return_code.dart';
// import 'package:video_player/video_player.dart';

// void main() {
//   WidgetsFlutterBinding.ensureInitialized();
//   runApp(const MaterialApp(home: ReelMakerPage()));
// }

// class ReelMakerPage extends StatefulWidget {
//   const ReelMakerPage({super.key});

//   @override
//   State<ReelMakerPage> createState() => _ReelMakerPageState();
// }

// class _ReelMakerPageState extends State<ReelMakerPage> {
//   List<_PickedMedia> _items = [];
//   bool _isBuilding = false;
//   String? _outputPath;
//   String _fitMode = 'contain'; // 'contain' or 'cover'
//   double _imageSeconds = 2.5;   // duration per image
//   final _log = StringBuffer();
//   VideoPlayerController? _controller;

//   @override
//   void dispose() {
//     _controller?.dispose();
//     super.dispose();
//   }

//   void _appendLog(String msg) {
//     setState(() {
//       _log.writeln(msg);
//     });
//     // ignore: avoid_print
//     print(msg);
//   }

//   Future<void> _pickMedia() async {
//     final res = await FilePicker.platform.pickFiles(
//       allowMultiple: true,
//       type: FileType.custom,
//       allowedExtensions: [
//         'jpg', 'jpeg', 'png',
//         'mp4', 'mov', 'm4v'
//       ],
//       withData: true, // so we can copy if path is not directly accessible
//     );
//     if (res == null) return;

//     final tmpDir = await getTemporaryDirectory();
//     final work = Directory('${tmpDir.path}/reel_work');
//     if (!work.existsSync()) work.createSync(recursive: true);

//     final picked = <_PickedMedia>[];

//     for (final f in res.files) {
//       // Ensure we have a real file path on disk: if path is null, write bytes
//       String outPath;
//       if (f.path != null) {
//         outPath = f.path!;
//       } else {
//         final safeName = f.name.replaceAll(RegExp(r'[^A-Za-z0-9_\.-]'), '_');
//         outPath = '${work.path}/$safeName';
//         if (f.bytes != null) {
//           await File(outPath).writeAsBytes(f.bytes!);
//         } else {
//           continue; // skip if we cannot access
//         }
//       }

//       final ext = outPath.split('.').last.toLowerCase();
//       final isImage = ['jpg', 'jpeg', 'png'].contains(ext);
//       picked.add(_PickedMedia(path: outPath, isImage: isImage));
//     }

//     setState(() {
//       _items = picked;
//       _outputPath = null;
//       _controller?.dispose();
//       _controller = null;
//       _log.clear();
//     });
//   }

//   Future<void> _buildReel() async {
//     if (_items.isEmpty) return;
//     setState(() => _isBuilding = true);

//     final tmpDir = await getTemporaryDirectory();
//     final work = Directory('${tmpDir.path}/reel_work');
//     if (!work.existsSync()) work.createSync(recursive: true);

//     _appendLog('Preparing ${_items.length} clips…');

//     final segmentPaths = <String>[];
//     for (int i = 0; i < _items.length; i++) {
//       final it = _items[i];
//       final segOut = '${work.path}/seg_${i.toString().padLeft(3, '0')}.mp4';

//       // Build the scaling filter for 1080x1920 without distortion
//       final vf = _fitMode == 'cover'
//           ? "scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,setsar=1,fps=30"
//           : "scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=30";

//       String cmd;
//       if (it.isImage) {
//         final dur = _imageSeconds.toStringAsFixed(2);
//         // -loop image + silent audio => uniform A/V layout for concat later
//         cmd =
//             "-y -loop 1 -t $dur -i \"${it.path}\" -f lavfi -t $dur -i anullsrc=channel_layout=stereo:sample_rate=44100 "
//             "-vf \"$vf\" -r 30 -c:v libx264 -preset veryfast -crf 20 -pix_fmt yuv420p "
//             "-c:a aac -ar 44100 -ac 2 -shortest -movflags +faststart \"$segOut\"";
//       } else {
//         cmd =
//             "-y -i \"${it.path}\" -vf \"$vf\" -r 30 -c:v libx264 -preset veryfast -crf 20 -pix_fmt yuv420p "
//             "-c:a aac -ar 44100 -ac 2 -movflags +faststart \"$segOut\"";
//       }

//       _appendLog('Transcoding clip ${i + 1}/${_items.length}…');
//       final session = await FFmpegKit.execute(cmd);
//       final code = await session.getReturnCode();
//       if (!ReturnCode.isSuccess(code)) {
//         _appendLog('❌ Failed on segment $i: ${await session.getAllLogsAsString()}');
//         setState(() => _isBuilding = false);
//         return;
//       }
//       segmentPaths.add(segOut);
//     }

//     // Create a concat list file
//     final listFile = File('${work.path}/list.txt');
//     final content = segmentPaths.map((p) => "file '" + p.replaceAll("'", "'\\''") + "'").join("\n");
//     await listFile.writeAsString(content);

//     final outPath = '${work.path}/reel_${DateTime.now().millisecondsSinceEpoch}.mp4';

//     // Concat (re-encode to be safe across any tiny diffs)
//     final concatCmd =
//         "-y -f concat -safe 0 -i \"${listFile.path}\" -c:v libx264 -preset veryfast -crf 20 -c:a aac -b:a 192k -movflags +faststart \"$outPath\"";

//     _appendLog('Concatenating ${segmentPaths.length} segments…');
//     final concatSession = await FFmpegKit.execute(concatCmd);
//     final concatCode = await concatSession.getReturnCode();
//     if (!ReturnCode.isSuccess(concatCode)) {
//       _appendLog('❌ Concat failed: ${await concatSession.getAllLogsAsString()}');
//       setState(() => _isBuilding = false);
//       return;
//     }

//     // OPTIONAL: Mix background music (uncomment to enable)
//     // final musicPath = "/path/to/music.mp3"; // let user pick a music file if needed
//     // final mixedOut = '${work.path}/reel_music.mp4';
//     // final mixCmd =
//     //     "-y -i \"$outPath\" -stream_loop -1 -i \"$musicPath\" "
//     //     "-filter_complex \"[1:a]volume=0.35[a1];[0:a][a1]amix=inputs=2:duration=first:dropout_transition=2[aout]\" "
//     //     "-map 0:v -map [aout] -c:v copy -c:a aac -shortest -movflags +faststart \"$mixedOut\"";
//     // final mixSession = await FFmpegKit.execute(mixCmd);
//     // if (ReturnCode.isSuccess(await mixSession.getReturnCode())) {
//     //   _appendLog('Background music mixed.');
//     //   _outputPath = mixedOut;
//     // } else {
//     //   _appendLog('Mixing failed; using original concat output.');
//     //   _outputPath = outPath;
//     // }

//     setState(() {
//       _outputPath = outPath; // set to mixedOut if you enabled the music step
//       _isBuilding = false;
//     });

//     _appendLog('✅ Done: $outPath');

//     // Preview
//     final c = VideoPlayerController.file(File(outPath));
//     await c.initialize();
//     await c.setLooping(true);
//     setState(() => _controller = c);
//     await c.play();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Reel Maker (1080×1920)'),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.folder_open),
//             onPressed: _pickMedia,
//             tooltip: 'Pick media',
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           Padding(
//             padding: const EdgeInsets.all(12),
//             child: Row(
//               children: [
//                 const Text('Fit:'),
//                 const SizedBox(width: 8),
//                 DropdownButton<String>(
//                   value: _fitMode,
//                   items: const [
//                     DropdownMenuItem(value: 'contain', child: Text('Contain (pad)')),
//                     DropdownMenuItem(value: 'cover', child: Text('Cover (crop)')),
//                   ],
//                   onChanged: (v) => setState(() => _fitMode = v ?? 'contain'),
//                 ),
//                 const Spacer(),
//                 const Text('Image seconds:'),
//                 SizedBox(
//                   width: 140,
//                   child: Slider(
//                     value: _imageSeconds,
//                     min: 0.8,
//                     max: 6.0,
//                     divisions: 26,
//                     label: _imageSeconds.toStringAsFixed(1),
//                     onChanged: (v) => setState(() => _imageSeconds = v),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           Expanded(
//             child: _items.isEmpty
//                 ? const Center(child: Text('Pick images/videos to begin'))
//                 : ListView.separated(
//                     itemCount: _items.length,
//                     separatorBuilder: (_, __) => const Divider(height: 1),
//                     itemBuilder: (context, i) {
//                       final it = _items[i];
//                       return ListTile(
//                         leading: Icon(it.isImage ? Icons.photo : Icons.videocam),
//                         title: Text(it.path.split('/').last),
//                         subtitle: Text(it.isImage ? 'Image' : 'Video'),
//                       );
//                     },
//                   ),
//           ),
//           if (_isBuilding) const LinearProgressIndicator(minHeight: 3),
//           if (_controller != null)
//             AspectRatio(
//               aspectRatio: _controller!.value.aspectRatio,
//               child: VideoPlayer(_controller!),
//             ),
//           Padding(
//             padding: const EdgeInsets.all(12),
//             child: Row(
//               children: [
//                 ElevatedButton.icon(
//                   onPressed: _items.isEmpty || _isBuilding ? null : _buildReel,
//                   icon: const Icon(Icons.movie_creation_outlined),
//                   label: const Text('Build Reel'),
//                 ),
//                 const SizedBox(width: 12),
//                 if (_outputPath != null)
//                   Expanded(
//                     child: Text(
//                       _outputPath!,
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis,
//                       style: const TextStyle(fontSize: 12),
//                     ),
//                   ),
//               ],
//             ),
//           ),
//           ExpansionTile(
//             title: const Text('Build Log'),
//             children: [
//               SizedBox(
//                 height: 140,
//                 child: SingleChildScrollView(
//                   padding: const EdgeInsets.all(12),
//                   child: Text(_log.toString()),
//                 ),
//               )
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _PickedMedia {
//   final String path;
//   final bool isImage;
//   const _PickedMedia({required this.path, required this.isImage});
// }

