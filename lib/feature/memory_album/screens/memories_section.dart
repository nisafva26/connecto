// ui/memories_section.dart
import 'dart:developer';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:connecto/feature/memory_album/data/memory_repository.dart';
import 'package:connecto/feature/memory_album/models/gathering_media_model.dart';
import 'package:connecto/feature/memory_album/models/reels_model.dart';
import 'package:connecto/feature/memory_album/provider/memories_provider.dart';
import 'package:connecto/feature/memory_album/screens/memory_gallery_screen.dart';
import 'package:connecto/feature/memory_album/widgets/reels_widget.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:image_picker/image_picker.dart';

import 'package:firebase_storage/firebase_storage.dart';

// final functionsProvider = Provider((ref) => FirebaseFunctions.instance);

// providers
final functionsProvider = Provider<FirebaseFunctions>((ref) {
  // your callable is in us-central1
  return FirebaseFunctions.instanceFor(region: 'us-central1');
});

final reelsRepoProvider = Provider<ReelsRepository>((ref) {
  return ReelsRepository(
    ref.watch(firestoreProvider),
    ref.watch(storageProvider),
    ref.watch(functionsProvider),
  );
});

final reelsJobsProvider =
    StreamProvider.family<List<ReelJob>, String>((ref, gid) {
  return ref.watch(reelsRepoProvider).watchJobs(gid);
});

// host check (if you don’t already have it)
final gatheringHostIdProvider =
    StreamProvider.family<String?, String>((ref, gid) {
  return ref
      .watch(firestoreProvider)
      .doc('gatherings/$gid')
      .snapshots()
      .map((d) => (d.data() ?? {})['hostId'] as String?);
});

class MemoriesSection extends ConsumerWidget {
  const MemoriesSection({
    super.key,
    required this.gid,
    required this.currentUid,
    required this.currentUserName,
    required this.gatheringStatus, // "ended" or others
  });

  final String gid;
  final String currentUid;
  final String currentUserName;
  final String gatheringStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (gatheringStatus != 'ended') {
      return const SizedBox.shrink();
    }

    final mediaAsync = ref.watch(mediaStreamProvider(gid));
    final quotaAsync =
        ref.watch(mediaQuotaProvider((gid: gid, uid: currentUid)));
    final upload = ref.watch(memoriesUploadControllerProvider);

    final jobsAsync = ref.watch(reelsJobsProvider(gid));
    final hostId = ref.watch(gatheringHostIdProvider(gid)).value;
    final isHost = hostId != null && hostId == currentUid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Memories',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const Spacer(),
            // Create Reel button (host only)

            quotaAsync.when(
              data: (count) {
                final remaining = 5 - count;
                return Text('You can add $remaining',
                    style: TextStyle(
                        color: remaining > 0 ? Colors.green : Colors.red));
              },
              loading: () => const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              error: (_, __) => const SizedBox(),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: quotaAsync.maybeWhen(
                data: (count) => (5 - count) > 0
                    ? () => _pickAndUpload(context, ref, 5 - count)
                    : null,
                orElse: () => null,
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add photos'),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Upload progress list (if any)
        if (upload.isUploading && upload.items.isNotEmpty)
          ...upload.items.map((it) => _UploadTile(item: it)),

        const SizedBox(height: 8),

        mediaAsync.when(
            data: (items) =>
                _MemoriesGrid(items: items, gid: gid, currentUid: currentUid),
            loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
            error: (e, _) {
              log('error : $e');
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text('Failed to load memories: $e'),
              );
            }),

        const SizedBox(height: 24),

        // Reels header
        Row(
          children: [
            Text('Reels',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            Spacer(),
            if (isHost) ...[
              // const SizedBox(height: 20),
              Center(child: CreateReelButton(gid: gid)),
              // const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 12),
        // Progress + list of reels
        jobsAsync.when(
          data: (jobs) {
            log('reels job : ${jobs.toList().toString()}');
            final active = jobs.firstWhere(
              (j) => j.isActive,
              orElse: () => jobs.isNotEmpty
                  ? jobs.first
                  : ReelJob(id: '', status: 'none', progress: 0),
            );

            log('active : ${active.status}');
             log('error ? : ${active.error}');
            final hasActive = active.id.isNotEmpty && active.isActive;

            if (hasActive) return ReelProgressTile(job: active);

            final done = jobs.where((j) => j.isDone).toList();
            if (done.isEmpty && !hasActive) {
              return const Text('No reels yet.');
            }

            return Column(
              children: done.map((j) => ReelDoneTile(job: j)).toList(),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(),
          ),
          error: (e, _) => Text('Failed to load reels: $e'),
        ),
      ],
    );
  }

  Future<void> _pickAndUpload(
      BuildContext context, WidgetRef ref, int remaining) async {
    final picker = ImagePicker();

    // Show quick "preparing" feedback to cover iOS export delays
    _showBlockingLoader(context, 'Preparing media…');

    final List<XFile> selected =
        await picker.pickMultipleMedia(imageQuality: 85);

    // Close loader now; we’ll show progress rows immediately after
    if (context.mounted) Navigator.pop(context);
    if (selected.isEmpty) return;

    final files = selected.take(remaining).map((x) => File(x.path)).toList();

    // Start upload (progress bars render immediately via controller state)
    final report =
        await ref.read(memoriesUploadControllerProvider.notifier).uploadMixed(
              gid: gid,
              uid: currentUid,
              uploaderName: currentUserName,
              files: files,
            );

    if (!context.mounted) return;

    // Friendly summary
    if (report.failures.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All items uploaded')),
      );
    } else {
      // log('report failures : ${report.failures}');
      report.failures.forEach((rep){

        log('report : ${rep.message}');
      });
      final tooLarge =
          report.failures.where((f) => f.code == 'too_large').toList();
      final others =
          report.failures.where((f) => f.code != 'too_large').toList();

      final lines = <String>[];
      if (report.success > 0) lines.add('Uploaded ${report.success} item(s).');
      if (tooLarge.isNotEmpty) {
        final names = tooLarge.take(2).map((f) => f.name).join(', ');
        lines.add(
            'Skipped ${tooLarge.length} video(s) over 50 MB: $names${tooLarge.length > 2 ? ' …' : ''}');
      }
      if (others.isNotEmpty) {
        lines.add('Skipped ${others.length} item(s): ${others.first.message}');
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(lines.join('\n'))));
    }
  }

  void _showBlockingLoader(BuildContext context, String text) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          content: Row(
            children: [
              const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 12),
              Flexible(child: Text(text)),
            ],
          ),
        ),
      ),
    );
  }
}

class _UploadTile extends StatelessWidget {
  const _UploadTile({required this.item});
  final UploadItem item;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Row(
        children: [
          const Icon(Icons.photo),
          const SizedBox(width: 12),
          const Expanded(child: Text('Uploading…')),
          SizedBox(
            width: 120,
            child: LinearProgressIndicator(value: item.progress),
          ),
          const SizedBox(width: 8),
          Text('${(item.progress * 100).toStringAsFixed(0)}%'),
        ],
      ),
    );
  }
}

class _MemoriesGrid extends ConsumerWidget {
  const _MemoriesGrid(
      {required this.items, required this.gid, required this.currentUid});
  final List<GatheringMedia> items;
  final String gid;
  final String currentUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text('No memories yet. Be the first to add photos!'),
        ),
      );
    }

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemBuilder: (context, i) {
        final m = items[i];
        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MemoriesGalleryScreen(
                  gid: gid,
                  currentUid: currentUid,
                  items: items, // pass the whole list once
                  initialIndex: i,
                ),
              ),
            );
          },
          child: _MediaTile(
              key: ValueKey(m.id),
              media: m,
              isOwner: m.uploaderId == currentUid),
        );
      },
    );
  }
}

class _MediaTile extends StatefulWidget {
  const _MediaTile({super.key, required this.media, required this.isOwner});
  final GatheringMedia media;
  final bool isOwner;

  @override
  State<_MediaTile> createState() => _MediaTileState();
}

class _MediaTileState extends State<_MediaTile> {
  String? _url;

  Future<void> _loadUrl() async {
    // For videos prefer the poster thumb if available
    final path = widget.media.type == 'video'
        ? (widget.media.thumbPath ?? widget.media.storagePath)
        : widget.media.storagePath;
    final u = await FirebaseStorage.instance.ref(path).getDownloadURL();
    if (mounted) setState(() => _url = u);
  }

  @override
  void initState() {
    super.initState();
    _loadUrl();
  }

  @override
  void didUpdateWidget(covariant _MediaTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.media.storagePath != widget.media.storagePath ||
        oldWidget.media.thumbPath != widget.media.thumbPath) {
      _url = null;
      _loadUrl();
    }
  }

  @override
  Widget build(BuildContext context) {
    final showPlay = widget.media.type == 'video';
    // log('${_url}');
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: _url == null
              ? const ColoredBox(color: Colors.black12)
              : Hero(
                  tag: widget.media.id,
                  child: Image.network(_url!, fit: BoxFit.cover),
                ),
        ),
        if (widget.isOwner)
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                color: Colors.white,
                onSelected: (v) async {
                  if (v == 'delete') {
                    // Minimal delete using current rules (soft delete)
                    final repo = MemoriesRepository(
                        FirebaseFirestore.instance, FirebaseStorage.instance);
                    await repo.deleteMedia(
                        gid: widget.media.gid,
                        uid: widget.media.uploaderId,
                        media: widget.media,
                        decrementQuota: true);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Delete',
                        style: TextStyle(color: Colors.black),
                      )),
                ],
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.more_vert, color: Colors.white, size: 18),
                ),
              ),
            ),
          ),
        if (showPlay)
          const Align(
            alignment: Alignment.center,
            child: Icon(Icons.play_circle_fill_rounded,
                size: 42, color: Colors.white70),
          ),
      ],
    );
  }
}
