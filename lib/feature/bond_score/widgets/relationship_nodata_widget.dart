import 'package:connecto/feature/auth/model/user_model.dart';
import 'package:connecto/feature/bond_score/screens/bond_relationship_screen.dart';
import 'package:connecto/helper/get_initials.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RelationNoDataWidget extends StatelessWidget {
  const RelationNoDataWidget({
    super.key,
    required this.userAsync,
    required this.widget,
    required this.user,
  });

  final AsyncValue<UserModel?> userAsync;
  final BondRelationshipScreen widget;
  final UserModel? user;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height,
      child: Stack(
        children: [
          // top gradient section
          Container(
            height: 316,
            width: MediaQuery.sizeOf(context).width,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF03FFE2),
                  Color(0xFF01675B),
                  Color(0xFF001311),
                ],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    children: [
                      userAsync.when(
                        data: (user) {
                          if (user == null) {
                            return CircleAvatar(
                                radius: 19,
                                child: Text(getInitials('No User')));
                          }
                          return CircleAvatar(
                              radius: 19,
                              backgroundColor: Colors.white,
                              child: Text(
                                getInitials(user.fullName),
                                style: TextStyle(
                                    fontWeight: FontWeight.w700),
                              ));
                        },
                        loading: () => CircleAvatar(
                            radius: 19,
                            child: Text(getInitials('No User'))),
                        error: (err, stack) => CircleAvatar(
                            radius: 19,
                            child: Text(getInitials('No User'))),
                      ),
                      const SizedBox(height: 6),
                      Text("You",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                          )),
                    ],
                  ),
                  const SizedBox(width: 50),
                  Column(
                    children: [
                      CircleAvatar(
                          radius: 19,
                          backgroundColor: Colors.white,
                          child: Text(
                            getInitials(widget.friendName),
                            style: TextStyle(fontWeight: FontWeight.w700),
                          )),
                      const SizedBox(height: 6),
                      Text(widget.friendName,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                          )),
                    ],
                  )
                ],
              ),
            ),
          ),
    
          // bottom container with dummy values
          Positioned.fill(
            top: 199,
            left: 0,
            right: 0,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF101F1E),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        LinearProgressIndicator(
                          minHeight: 7,
                          value: 0,
                          backgroundColor: Colors.grey.shade800,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 17),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text("0 points",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                            Row(
                              children: [
                                const Icon(Icons.emoji_events,
                                    color: Colors.white, size: 20),
                                Text("  Level 1",
                                    style: TextStyle(color: Colors.white))
                              ],
                            )
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                        radius: 10,
                                        backgroundColor: Colors.white,
                                        child: Text(
                                            getInitials(user!.fullName),
                                            style:
                                                TextStyle(fontSize: 9))),
                                    SizedBox(width: 7),
                                    Text("0",
                                        style: TextStyle(
                                            color: Colors.white)),
                                    SizedBox(width: 5),
                                    Text("points",
                                        style: TextStyle(
                                            color: Colors.white)),
                                  ],
                                ),
                                SizedBox(
                                  height: 5,
                                ),
                                Row(
                                  children: [
                                    CircleAvatar(
                                        radius: 10,
                                        backgroundColor: Colors.white,
                                        child: Text(
                                            getInitials(
                                                widget.friendName),
                                            style:
                                                TextStyle(fontSize: 9))),
                                    SizedBox(width: 7),
                                    Text("0",
                                        style: TextStyle(
                                            color: Colors.white)),
                                    SizedBox(width: 5),
                                    Text("points",
                                        style: TextStyle(
                                            color: Colors.white)),
                                  ],
                                ),
                              ],
                            ),
                            Spacer(),
                            Text("+1000 points to next level",
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text("Points",
                            style: TextStyle(
                                color: Colors.white, fontSize: 16)),
                        const SizedBox(height: 10),
                        const Text("No activity yet",
                            style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 20,
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}