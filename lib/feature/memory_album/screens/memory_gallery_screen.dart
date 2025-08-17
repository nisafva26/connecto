// ui/memories_gallery_screen.dart
import 'dart:collection';
import 'package:connecto/feature/memory_album/widgets/video_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connecto/feature/memory_album/data/memory_repository.dart';
import 'package:connecto/feature/memory_album/models/gathering_media_model.dart';

class MemoriesGalleryScreen extends StatefulWidget {
  const MemoriesGalleryScreen({
    super.key,
    required this.gid,
    required this.currentUid,
    required this.items,
    required this.initialIndex,
  });

  final String gid;
  final String currentUid;
  final List<GatheringMedia> items;
  final int initialIndex;

  @override
  State<MemoriesGalleryScreen> createState() => _MemoriesGalleryScreenState();
}

class _MemoriesGalleryScreenState extends State<MemoriesGalleryScreen> {
  late final PageController _controller;
  late List<GatheringMedia> _items; // local mutable copy
  int _index = 0;
  bool _chromeHidden = false;

  final _urlCache = HashMap<String, String>();

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.items);
    _index = widget.initialIndex;
    _controller = PageController(initialPage: _index);
    // small prefetch
    _preloadUrl(_items[_index]);
    if (_index + 1 < _items.length) _preloadUrl(_items[_index + 1]);
    if (_index - 1 >= 0) _preloadUrl(_items[_index - 1]);
  }

  Future<String> _getUrl(GatheringMedia m) async {
    if (_urlCache.containsKey(m.id)) return _urlCache[m.id]!;
    final u =
        await FirebaseStorage.instance.ref(m.storagePath).getDownloadURL();
    _urlCache[m.id] = u;
    return u;
  }

  void _preloadUrl(GatheringMedia m) {
    _getUrl(m)
        .then((u) => precacheImage(Image.network(u).image, context))
        .catchError((_) {});
  }

  Future<void> _deleteCurrent() async {
    final current = _items[_index];
    if (current.uploaderId != widget.currentUid) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete photo?'),
        content:
            const Text('This removes the photo from Memories for everyone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;

    final repo = MemoriesRepository(
        FirebaseFirestore.instance, FirebaseStorage.instance);
    await repo.deleteMedia(
      gid: widget.gid,
      uid: widget.currentUid,
      media: current,
      decrementQuota: true,
    );

    // Update local view instantly
    setState(() {
      _items.removeAt(_index);
      if (_items.isEmpty) {
        Navigator.pop(context);
      } else {
        if (_index >= _items.length) _index = _items.length - 1;
        _controller.jumpToPage(_index);
      }
    });
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Photo deleted')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final canDelete =
        _items.isNotEmpty && _items[_index].uploaderId == widget.currentUid;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _chromeHidden
          ? null
          : AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              title: Text('${_index + 1}/${_items.length}'),
              actions: [
                if (canDelete)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: _deleteCurrent,
                  ),
              ],
            ),
      body: GestureDetector(
        onTap: () => setState(() => _chromeHidden = !_chromeHidden),
        child: PageView.builder(
          controller: _controller,
          onPageChanged: (i) {
            setState(() => _index = i);
            if (i + 1 < _items.length) _preloadUrl(_items[i + 1]);
            if (i - 1 >= 0) _preloadUrl(_items[i - 1]);
          },
          itemCount: _items.length,
          itemBuilder: (context, i) {
            final m = _items[i];

            return m.type == 'video'
                ? VideoPage(urlFuture: _getUrl(m), heroTag: m.id)
                : Center(
                    child: FutureBuilder<String>(
                      future: _getUrl(m),
                      builder: (c, snap) {
                        if (!snap.hasData) {
                          return const SizedBox(
                            width: 48,
                            height: 48,
                            child:
                                CircularProgressIndicator(color: Colors.white),
                          );
                        }
                        return Hero(
                          tag: m.id,
                          child: InteractiveViewer(
                            minScale: 1.0,
                            maxScale: 4.0,
                            child: Image.network(
                              snap.data!,
                              fit: BoxFit.contain,
                            ),
                          ),
                        );
                      },
                    ),
                  );
          },
        ),
      ),
    );
  }
}
