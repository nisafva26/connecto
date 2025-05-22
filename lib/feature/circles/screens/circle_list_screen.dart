import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connecto/feature/circles/models/circle_model.dart';
import 'package:connecto/feature/circles/widgets/add_circle_modal.dart';
import 'package:connecto/feature/circles/widgets/circle_tile.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loading_indicator/loading_indicator.dart';

//fetching circles

final circlesProvider = StreamProvider.autoDispose<List<CircleModel>>((ref) {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('circles')
      .where('registeredUsers', arrayContains: currentUser.uid)
      .snapshots()
      .asyncMap((snapshot) async {
    // log('===snpashot : ${snapshot.docs}');
    return Future.wait(
        snapshot.docs.map((doc) => CircleModel.fromFirestore(doc)));
  });
});

class CircleListScreen extends ConsumerWidget {
  const CircleListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final circlesAsync = ref.watch(circlesProvider);
    // Future.microtask(() {
    //   if (context.mounted) {
    //     ref.read(circleNotifierProvider.notifier).resetState();
    //   }
    // });

    // log('====circle async === $circlesAsync');

    // log('cuurent user : $user');

    return Expanded(
      child: ListView(
        children: [
          // buildCircleTile('Close Friends', 4, Color(0xff00F0C2),
          //     fontColor: Colors.black),
          // buildCircleTile('Family', 2, Color(0xff4653EE),
          //     fontColor: Colors.white),
          // buildCircleTile('Work', 4, Color(0xffFC7D5D),
          // fontColor: Colors.white),

          circlesAsync.when(
            data: (circles) {
              // log('===circle data avaialable ${circles}');
              return ListView(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                children: [
                  ...circles.map((circle) {
                    return buildCircleTile(circle, context);
                  }),
                ],
              );
            },
            loading: () => Center(
              child: Container(
                height: 40,
                child: LoadingIndicator(
                  indicatorType: Indicator.ballBeat,
                  colors: [Theme.of(context).colorScheme.primary],
                ),
              ),
            ),
            error: (err, stack) => Center(
                child: Text("Error loading circles",
                    style: TextStyle(color: Colors.red))),
          ),

          InkWell(
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => AddCircleModal(),
              );
            },
            child: Container(
              height: 148,
              width: MediaQuery.sizeOf(context).width,
              decoration: BoxDecoration(
                color: Color(0xff091F1E),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 24,
                    width: 24,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle, color: Color(0xff03FFE2)),
                    child: Center(
                      child: Icon(
                        Icons.add,
                        size: 18,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 8,
                  ),
                  Text(
                    'Add a circle',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
                  SizedBox(
                    height: 8,
                  ),
                  Text(
                    'Create a circle and share with friends',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
