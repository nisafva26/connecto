// models/gathering_media.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class GatheringMedia {
  final String id;
  final String gid;
  final String uploaderId;
  final String uploaderName;
  final String type; // "image"
  final String storagePath; // gs:// path not needed; we’ll use download URLs
  final String? thumbPath;
  final String mime;
  final DateTime createdAt;
  final int? width;
  final int? height;
  final String status; // "active" | "removed"

  final int? duration; // seconds for video

  GatheringMedia({
    required this.id,
    required this.gid,
    required this.uploaderId,
    required this.uploaderName,
    required this.type,
    required this.storagePath,
    required this.mime,
    required this.createdAt,
    required this.duration,
    this.thumbPath,
    this.width,
    this.height,
    this.status = 'active',
  });

  factory GatheringMedia.fromJson(
      String id, Map<String, dynamic> j, String gid) {
    final ts = j['createdAt'];
    final dt = ts is Timestamp
        ? ts.toDate()
        : DateTime.fromMillisecondsSinceEpoch(0); // fallback if null/missing
    return GatheringMedia(
      id: id,
      gid: gid,
      uploaderId: j['uploaderId'],
      uploaderName: j['uploaderName'] ?? '',
      type: j['type'],
      storagePath: j['storagePath'],
      thumbPath: j['thumbPath'],
      mime: j['mime'] ?? 'image/jpeg',
      createdAt: dt,
      width: (j['width'] as num?)?.toInt(),
      height: (j['height'] as num?)?.toInt(),
      status: j['status'] ?? 'active',
      duration: (j['duration'] as num?)?.toInt(), // NEW
    );
  }

  Map<String, dynamic> toJson() => {
        'uploaderId': uploaderId,
        'uploaderName': uploaderName,
        'type': type,
        'storagePath': storagePath,
        'thumbPath': thumbPath,
        'mime': mime,
        'createdAt': createdAt,
        'width': width,
        'height': height,
        'status': status,
      };
}
