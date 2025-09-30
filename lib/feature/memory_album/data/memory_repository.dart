// data/memories_repository.dart
import 'dart:developer';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connecto/feature/memory_album/models/gathering_media_model.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:mime/mime.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path/path.dart' as p;


class UploadFailure {
  UploadFailure({
    required this.name,
    required this.message,
    required this.code,
  });
  final String name;     // filename
  final String message;  // user-facing description
  final String code;     // e.g., 'too_large', 'unauthorized', 'unknown'
}

class UploadReport {
  UploadReport({required this.success, required this.failures});
  final int success;
  final List<UploadFailure> failures;
}

String _normalizeContentType(String path, String? mime) {
  final ext = p.extension(path).toLowerCase();
  if (ext == '.jpg' || ext == '.jpeg') return 'image/jpeg';
  if (ext == '.png') return 'image/png';
  if (ext == '.heic') return 'image/heic';
  if (ext == '.mp4') return 'video/mp4';
  if (ext == '.mov') return 'video/quicktime';
  if (ext == '.m4v') return 'video/x-m4v';
  return (mime == null || mime.isEmpty) ? 'application/octet-stream' : mime;
}


class MemoriesRepository {
  MemoriesRepository(this._db, this._storage);
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> _mediaCol(String gid) =>
      _db.collection('gatherings').doc(gid).collection('media');

  DocumentReference<Map<String, dynamic>> _quotaDoc(String gid, String uid) =>
      _db.collection('gatherings').doc(gid).collection('mediaQuota').doc(uid);

  Stream<List<GatheringMedia>> watchMedia(String gid) {
    return _mediaCol(gid)
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => GatheringMedia.fromJson(d.id, d.data(), gid))
            .toList());
  }

  Stream<int> watchQuota(String gid, String uid) {
    return _quotaDoc(gid, uid).snapshots().map((s) {
      if (!s.exists) return 0;
      return (s.data()?['count'] as num?)?.toInt() ?? 0;
    });
  }

  Future<void> uploadImages({
    required String gid,
    required String uid,
    required String uploaderName,
    required List<File> files,
    void Function(int index, double progress)? onProgress,
  }) async {
    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      final mediaId = _db.collection('_ids').doc().id; // random id
      final storagePath = 'gatherings/$gid/media/$uid/$mediaId.jpg';
      final ref = _storage.ref(storagePath);

      final uploadTask = ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
      uploadTask.snapshotEvents.listen((s) {
        final total = s.totalBytes == 0 ? 1 : s.totalBytes;
        final p = s.bytesTransferred / total;
        onProgress?.call(i, p);
      });

      final snap = await uploadTask;
      // (Optional) get image dimensions here if needed (using package:image)

      final mediaDoc = _mediaCol(gid).doc(mediaId);
      final quotaRef = _quotaDoc(gid, uid);

      final batch = _db.batch();

      // Ensure quota exists: read current first (safe – small extra read)
      final quotaSnap = await quotaRef.get();
      final current = quotaSnap.exists ? (quotaSnap.data()?['count'] as num?)?.toInt() ?? 0 : 0;

      batch.set(mediaDoc, {
        'uploaderId': uid,
        'uploaderName': uploaderName,
        'type': 'image',
        'storagePath': storagePath,
        'thumbPath': null, // will be filled by Resize Images extension if installed
        'mime': snap.metadata?.contentType ?? 'image/jpeg',
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'active',
      });

      if (quotaSnap.exists) {
        batch.update(quotaRef, {'count': current + 1});
      } else {
        batch.set(quotaRef, {'count': 1});
      }

      await batch.commit();
    }
  }

  // Future<void> deleteMedia({
  //   required String gid,
  //   required String uid,
  //   required GatheringMedia media,
  //   bool decrementQuota = false, // enable if you add decrement in rules
  // }) async {
  //   // Soft delete (safe with current rules)
  //   await _mediaCol(gid).doc(media.id).update({'status': 'removed'});

  //   // Optionally remove file in Storage (no quota change in rules now)
  //   await _storage.ref(media.storagePath).delete().catchError((_) {});
  // }

  // data/memories_repository.dart

Future<void> deleteMedia({
  required String gid,
  required String uid,
  required GatheringMedia media,
  bool decrementQuota = false,
}) async {
  final mediaRef = _mediaCol(gid).doc(media.id);
  final quotaRef = _quotaDoc(gid, uid);

  // Read current quota (safe if missing)
  final quotaSnap = await quotaRef.get();
  final current = quotaSnap.exists ? (quotaSnap.data()?['count'] as num?)?.toInt() ?? 0 : 0;

  final batch = _db.batch();

  // Soft delete media so others don't see it
  batch.update(mediaRef, {'status': 'removed'});

  if (decrementQuota && current > 0) {
    // rules now allow -1
    batch.update(quotaRef, {'count': current - 1});
  }

  await batch.commit();

  // Best-effort storage cleanup (outside batch)
  try { await _storage.ref(media.storagePath).delete(); } catch (_) {}
}


 /// Upload mixed images & videos. Returns an UploadReport with per-file failures.
  Future<UploadReport> uploadMixed({
    required String gid,
    required String uid,
    required String uploaderName,
    required List<File> files,
    void Function(int index, double progress)? onProgress,
  }) async {
    int ok = 0;
    final failures = <UploadFailure>[];

    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      final filename = p.basename(file.path);

      try {
        // Detect content type
        final detected = lookupMimeType(file.path);
        final contentType = _normalizeContentType(file.path, detected);
        final isVideo = contentType.startsWith('video/');

        // Create Firestore doc id first so we can derive a stable storage path
        final mediaRef = _mediaCol(gid).doc();
        final mediaId = mediaRef.id;

        final ext0 = p.extension(file.path).toLowerCase().replaceFirst('.', '');
        final ext = ext0.isEmpty ? (isVideo ? 'mp4' : 'jpg') : ext0;

        final storagePath = 'gatherings/$gid/media/$uid/$mediaId.$ext';
        final ref = _storage.ref(storagePath);

        // Upload original (rules will reject >50MB videos or non-participants)
        final task = ref.putFile(file, SettableMetadata(contentType: contentType));
        task.snapshotEvents.listen((s) {
          final total = s.totalBytes == 0 ? 1 : s.totalBytes;
          onProgress?.call(i, s.bytesTransferred / total);
        });
        final snap = await task; // may throw FirebaseException(unauthorized)

        // Quota doc read (MVP; rules guard <5 on create)
        final quotaRef = _quotaDoc(gid, uid);
        final quotaSnap = await quotaRef.get();
        final current = quotaSnap.exists ? (quotaSnap.data()?['count'] as num?)?.toInt() ?? 0 : 0;

        // Create media doc + increment quota
        final batch = _db.batch();
        batch.set(mediaRef, {
          'uploaderId': uid,
          'uploaderName': uploaderName,
          'type': isVideo ? 'video' : 'image',
          'storagePath': storagePath,
          'thumbPath': null, // fill later for videos
          'mime': snap.metadata?.contentType ?? contentType,
          'duration': null,
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'active',
        });
        if (quotaSnap.exists) {
          batch.update(quotaRef, {'count': current + 1});
        } else {
          batch.set(quotaRef, {'count': 1});
        }
        await batch.commit();

        // Best-effort video thumbnail upload (ignore failures)
        if (isVideo) {
          try {
            final bytes = await VideoThumbnail.thumbnailData(
              video: file.path,
              imageFormat: ImageFormat.JPEG,
              timeMs: 1000,
              quality: 60,
            );
            if (bytes != null) {
              final thumbRef = _storage.ref('gatherings/$gid/thumbs/$mediaId.jpg');
              await thumbRef.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
              await mediaRef.update({'thumbPath': thumbRef.fullPath});
            }
          } catch (_) {/* ignore */}
        }

        ok++;
      } on FirebaseException catch (e) {
        log("storage error : ${e.message}");
        // Classify common cases; continue loop (don't abort remaining files)
        final mime = lookupMimeType(file.path) ?? '';
        final isVideo = mime.startsWith('video/') ||
            file.path.toLowerCase().endsWith('.mp4') ||
            file.path.toLowerCase().endsWith('.mov') ||
            file.path.toLowerCase().endsWith('.m4v');

        final isTooLargeVideo = e.code == 'unauthorized' && isVideo;
        failures.add(UploadFailure(
          name: filename,
          code: isTooLargeVideo ? 'too_large' : e.code,
          message: isTooLargeVideo
              ? 'Video exceeds the 50 MB limit'
              : (e.message ?? 'Upload failed'),
        ));
        continue;
      } catch (e) {
        log('got error : ${e}');
        failures.add(UploadFailure(
          name: filename,
          code: 'unknown',
          message: e.toString(),
        ));
        continue;
      }
    }

    return UploadReport(success: ok, failures: failures);
  }



// Future<void> uploadMixed({
//     required String gid,
//     required String uid,
//     required String uploaderName,
//     required List<File> files,
//     void Function(int index, double progress)? onProgress,
//   }) async {
//     for (int i = 0; i < files.length; i++) {
//       final file = files[i];
//       final mimeType = lookupMimeType(file.path) ?? '';
//       final isVideo = mimeType.startsWith('video/');
//       final mediaRef = _mediaCol(gid).doc();
//       final mediaId = mediaRef.id;

//       final ext = file.path.split('.').last.toLowerCase();
//       final storagePath = 'gatherings/$gid/media/$uid/$mediaId.$ext';
//       final ref = _storage.ref(storagePath);

//       // Upload original
//       final uploadTask = ref.putFile(file, SettableMetadata(contentType: mimeType));
//       uploadTask.snapshotEvents.listen((s) {
//         final total = s.totalBytes == 0 ? 1 : s.totalBytes;
//         onProgress?.call(i, s.bytesTransferred / total);
//       });
//       final snap = await uploadTask;

//       String? thumbPath;
//       int? duration;

//       if (isVideo) {
//         // Generate a poster frame on device (1s mark)
//         final bytes = await VideoThumbnail.thumbnailData(
//           video: file.path,
//           imageFormat: ImageFormat.JPEG,
//           timeMs: 1000,
//           quality: 60,
//         );
//         if (bytes != null) {
//           final thumbRef = _storage.ref('gatherings/$gid/thumbs/$mediaId.jpg');
//           await thumbRef.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
//           thumbPath = thumbRef.fullPath;
//         }
//         // Duration is optional for MVP; leave null or compute with a plugin if you need it
//         duration = null;
//       }

//       // Quota doc read
//       final quotaRef = _quotaDoc(gid, uid);
//       final quotaSnap = await quotaRef.get();
//       final current = quotaSnap.exists ? (quotaSnap.data()?['count'] as num?)?.toInt() ?? 0 : 0;

//       // Firestore batched write
//       final batch = _db.batch();
//       batch.set(mediaRef, {
//         'uploaderId': uid,
//         'uploaderName': uploaderName,
//         'type': isVideo ? 'video' : 'image',
//         'storagePath': storagePath,
//         'thumbPath': thumbPath,
//         'mime': snap.metadata?.contentType ?? mimeType,
//         'duration': duration,
//         'createdAt': FieldValue.serverTimestamp(),
//         'status': 'active',
//       });
//       if (quotaSnap.exists) {
//         batch.update(quotaRef, {'count': current + 1});
//       } else {
//         batch.set(quotaRef, {'count': 1});
//       }
//       await batch.commit();
//     }
//   }


//  Future<UploadReport> uploadMixed({
//     required String gid,
//     required String uid,
//     required String uploaderName,
//     required List<File> files,
//     void Function(int index, double progress)? onProgress,
//   }) async {
//     int ok = 0;
//     final failures = <UploadFailure>[];

//     for (int i = 0; i < files.length; i++) {
//       final file = files[i];
//       final name = p.basename(file.path);
//       try {
//         final detected = lookupMimeType(file.path);
//         final contentType = _normalizeContentType(file.path, detected);
//         final isVideo = contentType.startsWith('video/');

//         // Create doc id first so storage path uses it
//         final mediaRef = _mediaCol(gid).doc();
//         final mediaId = mediaRef.id;
//         final ext = p.extension(file.path).toLowerCase().replaceFirst('.', '');
//         final storagePath = 'gatherings/$gid/media/$uid/$mediaId.${ext.isEmpty ? (isVideo ? 'mp4' : 'jpg') : ext}';
//         final ref = _storage.ref(storagePath);

//         // Upload original
//         final task = ref.putFile(file, SettableMetadata(contentType: contentType));
//         task.snapshotEvents.listen((s) {
//           final total = (s.totalBytes == 0) ? 1 : s.totalBytes;
//           onProgress?.call(i, s.bytesTransferred / total);
//         });
//         final snap = await task; // <-- throws if unauthorized (e.g., >50MB)

//         // Quota doc
//         final quotaRef = _quotaDoc(gid, uid);
//         final quotaSnap = await quotaRef.get();
//         final current = quotaSnap.exists ? (quotaSnap.data()?['count'] as num?)?.toInt() ?? 0 : 0;

//         // Write media doc (no thumb yet)
//         final batch = _db.batch();
//         batch.set(mediaRef, {
//           'uploaderId': uid,
//           'uploaderName': uploaderName,
//           'type': isVideo ? 'video' : 'image',
//           'storagePath': storagePath,
//           'thumbPath': null,
//           'mime': snap.metadata?.contentType ?? contentType,
//           'duration': null,
//           'createdAt': FieldValue.serverTimestamp(),
//           'status': 'active',
//         });
//         if (quotaSnap.exists) {
//           batch.update(quotaRef, {'count': current + 1});
//         } else {
//           batch.set(quotaRef, {'count': 1});
//         }
//         await batch.commit();

//         // Best-effort poster for video
//         if (isVideo) {
//           try {
//             final bytes = await VideoThumbnail.thumbnailData(
//               video: file.path,
//               imageFormat: ImageFormat.JPEG,
//               timeMs: 1000,
//               quality: 60,
//             );
//             if (bytes != null) {
//               final thumbRef = _storage.ref('gatherings/$gid/thumbs/$mediaId.jpg');
//               await thumbRef.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
//               await mediaRef.update({'thumbPath': thumbRef.fullPath});
//             }
//           } catch (_) {/* ignore poster errors */}
//         }

//         ok++; // success for this item
//       } on FirebaseException catch (e) {
//         // Do NOT abort the whole batch. Record and continue.
//         final reason = (e.code == 'unauthorized')
//             ? 'Not allowed by rules (likely >50MB or event not ended)'
//             : (e.message ?? e.code);
//         failures.add(UploadFailure(name: name, reason: reason));
//         // continue
//       } catch (e) {
//         failures.add(UploadFailure(name: name, reason: e.toString()));
//       }
//     }

//     return UploadReport(success: ok, failures: failures);
//   }

}
