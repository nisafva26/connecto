import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class ReelJob {
  final String id;
  final String status; // queued | running | done | error
  final int progress;  // 0..100
  final String? gcsPath;
  final String? error;
  final DateTime? createdAt;
  final DateTime? finishedAt;

  ReelJob({
    required this.id,
    required this.status,
    required this.progress,
    this.gcsPath,
    this.error,
    this.createdAt,
    this.finishedAt,
  });

  factory ReelJob.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    DateTime? ts(Timestamp? t) => t != null ? t.toDate() : null;
    return ReelJob(
      id: doc.id,
      status: d['status'] ?? 'queued',
      progress: (d['progress'] ?? 0) is int ? d['progress'] : (d['progress'] as num?)?.round() ?? 0,
      gcsPath: d['gcsPath'],
      error: d['error'],
      createdAt: ts(d['createdAt']),
      finishedAt: ts(d['finishedAt']),
    );
  }

  bool get isActive => status == 'queued' || status == 'running';
  bool get isDone => status == 'done';
  bool get isError => status == 'error';
}

class ReelsRepository {
  ReelsRepository(this.db, this.storage, this.functions);
  final FirebaseFirestore db;
  final FirebaseStorage storage;
  final FirebaseFunctions functions;

  Stream<List<ReelJob>> watchJobs(String gid) {
    return db.collection('gatherings/$gid/reelsJobs')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((q) => q.docs.map((d) => ReelJob.fromDoc(d)).toList());
  }

  // Future<String> startJob(String gid) async {
  //   final fn = functions.httpsCallable('startReelJob');
  //   final res = await fn.call({'gatheringId': gid, 'targetSeconds': 60, 'crossfade': 0.5, 'fitMode': 'cover', 'maxPerVideo': 5});
  //   final data = Map<String, dynamic>.from(res.data as Map);
  //   return data['jobDocPath'] as String; // e.g. gatherings/{gid}/reelsJobs/{jobId}
  // }

  // ReelsRepository.startJob
Future<String> startJob(String gid) async {
  final fn = functions.httpsCallable('startReelJob');
  try {
    final res = await fn.call({
      'gatheringId': gid,
      'targetSeconds': 60,
      'crossfade': 0.5,
      'fitMode': 'cover',
      'maxPerVideo': 5,
    });
    final data = Map<String, dynamic>.from(res.data as Map);
    return data['jobDocPath'] as String;
  } on FirebaseFunctionsException catch (e) {
    // <-- you'll finally see the real reason
    debugPrint('startReelJob failed code=${e.code} message=${e.message} details=${e.details}');
    throw Exception(e.message ?? e.code);
  }
}


  Future<String> urlForGcsPath(String gcsPath) async {
    return await storage.ref(gcsPath).getDownloadURL();
  }
}
