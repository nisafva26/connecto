import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connecto/feature/dashboard/models/access_request_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

final adminNotificationsProvider =
    StreamProvider<List<AccessRequestModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('notifications_admin')
      .where('type', isEqualTo: 'accessRequest')
      .where('status', isEqualTo: 'pending') // Only show pending ones
      .orderBy('requestedAt', descending: true)
      .snapshots()
      .map((snap) =>
          snap.docs.map((doc) => AccessRequestModel.fromDoc(doc)).toList());
});

class AdminAccessRequestsScreen extends ConsumerWidget {
  const AdminAccessRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accessRequestsAsync = ref.watch(adminNotificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("User Access Requests"),
        backgroundColor: Colors.transparent,
        centerTitle: true,
      ),
      body: accessRequestsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Error: $e")),
        data: (requests) {
          if (requests.isEmpty) {
            return const Center(
              child: Text("No pending requests",
                  style: TextStyle(color: Colors.white70)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              return _buildRequestCard(context, request);
            },
          );
        },
      ),
    );
  }

  Widget _buildRequestCard(BuildContext context, AccessRequestModel request) {
    return Card(
      color: const Color(0xFF0F2A29),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          ListTile(
            title: Text(request.fullName,
                style: const TextStyle(color: Colors.white)),
            subtitle: Text(request.requesterPhone,
                style: const TextStyle(color: Colors.grey)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)
                .copyWith(top: 0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      await FirebaseFirestore.instance
                          .collection('accessRequests')
                          .doc(request.requesterPhone)
                          .update({'status': 'approved'});

                      await FirebaseFirestore.instance
                          .collection('notifications_admin')
                          .doc(request.id)
                          .update({'status': 'approved'});

                      if (context.mounted) {
                        Fluttertoast.showToast(
                          msg: "User request approved!",
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          textColor: Colors.black,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF03FFE2),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      textStyle: const TextStyle(fontSize: 14),
                    ),
                    child: const Text('Approve'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      await FirebaseFirestore.instance
                          .collection('accessRequests')
                          .doc(request.requesterPhone)
                          .update({'status': 'rejected'});

                      await FirebaseFirestore.instance
                          .collection('notifications_admin')
                          .doc(request.id)
                          .update({'status': 'rejected'});

                      if (context.mounted) {
                        Fluttertoast.showToast(
                          msg: "User request rejected!",
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          textColor: Colors.black,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      textStyle: const TextStyle(fontSize: 14),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
