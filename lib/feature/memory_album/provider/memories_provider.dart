// providers/memories_providers.dart
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connecto/feature/memory_album/data/memory_repository.dart';
import 'package:connecto/feature/memory_album/models/gathering_media_model.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


final firestoreProvider = Provider((ref) => FirebaseFirestore.instance);
final storageProvider   = Provider((ref) => FirebaseStorage.instance);

final memoriesRepoProvider = Provider<MemoriesRepository>((ref) {
  return MemoriesRepository(ref.watch(firestoreProvider), ref.watch(storageProvider));
});

final mediaStreamProvider =
    StreamProvider.family<List<GatheringMedia>, String>((ref, gid) {
  return ref.watch(memoriesRepoProvider).watchMedia(gid);
});

final mediaQuotaProvider =
    StreamProvider.family.autoDispose<int, ({String gid, String uid})>((ref, args) {
  return ref.watch(memoriesRepoProvider).watchQuota(args.gid, args.uid);
});

/// Upload controller with progress for multiple files
class UploadItem {
  UploadItem(this.file);
  final File file;
  double progress = 0; // 0..1
}

class UploadState {
  final List<UploadItem> items;
  final bool isUploading;
  final String? error;
  UploadState({this.items = const [], this.isUploading = false, this.error});

  UploadState copyWith({List<UploadItem>? items, bool? isUploading, String? error}) =>
      UploadState(items: items ?? this.items, isUploading: isUploading ?? this.isUploading, error: error);
}

class MemoriesUploadController extends StateNotifier<UploadState> {
  MemoriesUploadController(this.ref) : super(UploadState());
  final Ref ref;

  Future<void> upload({
    required String gid,
    required String uid,
    required String uploaderName,
    required List<File> files,
  }) async {
    state = state.copyWith(
      items: files.map((f) => UploadItem(f)).toList(),
      isUploading: true,
      error: null,
    );

    try {
      await ref.read(memoriesRepoProvider).uploadImages(
        gid: gid,
        uid: uid,
        uploaderName: uploaderName,
        files: files,
        onProgress: (index, p) {
          final items = [...state.items];
          items[index].progress = p;
          state = state.copyWith(items: items);
        },
      );
      state = UploadState(items: [], isUploading: false);
    } catch (e) {
      state = state.copyWith(isUploading: false, error: e.toString());
    }
  }

    Future<UploadReport> uploadMixed({
    required String gid,
    required String uid,
    required String uploaderName,
    required List<File> files,
  }) async {
    state = state.copyWith(
      items: files.map((f) => UploadItem(f)).toList(),
      isUploading: true,
      error: null,
    );

    try {
      final report = await ref.read(memoriesRepoProvider).uploadMixed(
        gid: gid,
        uid: uid,
        uploaderName: uploaderName,
        files: files,
        onProgress: (index, p) {
          final items = [...state.items];
          if (index >= 0 && index < items.length) {
            items[index].progress = p;
            state = state.copyWith(items: items);
          }
        },
      );

      state =  UploadState(items: [], isUploading: false);
      return report;
    } catch (e) {
      state = state.copyWith(isUploading: false, error: e.toString());
      rethrow;
    }
  }


//   // providers/memories_providers.dart  (inside MemoriesUploadController)
// Future<void> uploadMixed({
//   required String gid,
//   required String uid,
//   required String uploaderName,
//   required List<File> files,
// }) async {
//   state = state.copyWith(
//     items: files.map((f) => UploadItem(f)).toList(),
//     isUploading: true,
//     error: null,
//   );
//   try {
//     await ref.read(memoriesRepoProvider).uploadMixed(
//       gid: gid,
//       uid: uid,
//       uploaderName: uploaderName,
//       files: files,
//       onProgress: (index, p) {
//         final items = [...state.items];
//         items[index].progress = p;
//         state = state.copyWith(items: items);
//       },
//     );
//     state = UploadState(items: [], isUploading: false);
//   } catch (e) {
//     state = state.copyWith(isUploading: false, error: e.toString());
//   }
// }

}

final memoriesUploadControllerProvider =
    StateNotifierProvider<MemoriesUploadController, UploadState>(
        (ref) => MemoriesUploadController(ref));
