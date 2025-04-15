import 'dart:developer';

import 'package:connecto/feature/circles/controller/circle_notifier.dart';
import 'package:connecto/feature/circles/models/circle_state.dart';
import 'package:connecto/feature/circles/widgets/circle_success_modal.dart';
import 'package:connecto/helper/color_helper.dart';
import 'package:connecto/helper/get_initials.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CreateCircleScreen extends ConsumerStatefulWidget {
  final List<Map<String, String>> selectedUsers;

  const CreateCircleScreen({super.key, required this.selectedUsers});

  @override
  ConsumerState<CreateCircleScreen> createState() => _CreateCircleScreenState();
}

class _CreateCircleScreenState extends ConsumerState<CreateCircleScreen> {
  TextEditingController circleNameController = TextEditingController();
  List<Color> circleColors = [
    Color(0xFFFF5A5A),
    Color(0xFF7748E7),
    Color(0xFF4EA46B),
    Color(0xFF475AE7),
    Color(0xFFFFC453),
    Color(0xFFAD45E7),
  ];
  Color selectedColor = Color(0xFFFF5A5A); // Default color

  @override
  Widget build(BuildContext context) {
    final circleState = ref.watch(circleNotifierProvider);
    log('🔍 UI Circle State: ${circleState.status}');

    if (circleState.status == CircleStateStatus.success) {
      log('🎉 UI Should Show Success Modal');

      // ✅ Use `WidgetsBinding.instance.addPostFrameCallback` to open modal **after UI build completes**
      // WidgetsBinding.instance.addPostFrameCallback((_) async {
      //   log("🟢 Showing Success Modal");

      //   showModalBottomSheet(
      //     context: context,
      //     isScrollControlled: true,
      //     backgroundColor: Colors.transparent,
      //     builder: (context) {
      //       return SuccessModal(
      //         circleName: circleNameController.text,
      //         circleColor: selectedColor,
      //         members: widget.selectedUsers,
      //       );
      //     },
      //   );

      //   // log("✅ Modal Closed - Resetting State & Navigating");

      //   // // ✅ Reset state AFTER modal closes
      //   ref.read(circleNotifierProvider.notifier).resetState();

      //   // ✅ Navigate only AFTER modal is dismissed
      //   // if (context.mounted) {
      //   //   context.replace('/bond');
      //   // }
      // });

      /// ✅ Ensure modal is shown **after** the build phase
      Future.microtask(() {
        log('===inside futre.micro task');
        if (context.mounted) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) {
              return SuccessModal(
                circleName: circleNameController.text,
                circleColor: selectedColor,
                members: widget.selectedUsers,
              );
            },
          );
          // .then((_) {
          //   log('✅ Modal dismissed, resetting state');
          //   ref.read(circleNotifierProvider.notifier).resetState();

          //   /// ✅ 🚀 Navigate after modal is dismissed
          //   // context.replace('/bond');
          // });
        }
      });
    }
    return Scaffold(
      backgroundColor: Color(0xff001311),
      appBar: AppBar(
        backgroundColor: Color(0xff091F1E),
        title: Text('Add Friend', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        actions: [
          // IconButton(
          //     onPressed: () {
          //       showModalBottomSheet(
          //         context: context,
          //         isScrollControlled: true,
          //         backgroundColor: Colors.transparent,
          //         builder: (context) {
          //           return SuccessModal(
          //             circleName: circleNameController.text,
          //             circleColor: selectedColor,
          //             members: widget.selectedUsers,
          //           );
          //         },
          //       );
          //     },
          //     icon: Icon(Icons.settings)),
          TextButton(
            onPressed: () => context.pop(), // Close screen
            child: Text('Cancel', style: TextStyle(color: Colors.tealAccent)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 10),

                    /// 🔹 Circle Name Input
                    Text("Circle name", style: _sectionTitleStyle),
                    SizedBox(height: 6),

                    TextField(
                      controller: circleNameController,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        fillColor: Color(0xff08201E),
                        filled: true,
                        hintText: "Enter circle name",
                        hintStyle: TextStyle(color: Colors.grey),

                        // labelText: 'Full name',
                        labelStyle: TextStyle(color: Colors.tealAccent[700]),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Color(0xff0E3735)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                              color: Colors.tealAccent[700]!, width: 1),
                        ),
                      ),
                    ),

                    SizedBox(height: 24),

                    /// 🔹 Circle Color Selection
                    Text("Circle color", style: _sectionTitleStyle),
                    SizedBox(height: 8),
                    Text(
                      'Select the color for the circle',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
                    ),
                    SizedBox(height: 24),
                    GridView.builder(
                      itemCount: circleColors.length,
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 3,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemBuilder: (context, index) {
                        final color = circleColors[index];
                        return GestureDetector(
                          onTap: () {
                            setState(() => selectedColor = color);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selectedColor == color
                                    ? Colors.white
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: selectedColor == color
                                ? Center(
                                    child:
                                        Icon(Icons.check, color: Colors.white),
                                  )
                                : SizedBox.shrink(),
                          ),
                        );
                      },
                    ),

                    SizedBox(height: 0),

                    /// 🔹 Selected Contacts/Friends
                    Text("Selected contacts (${widget.selectedUsers.length})",
                        style: _sectionTitleStyle),
                    SizedBox(height: 10),
                    ListView.separated(
                      physics: NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      padding: EdgeInsets.all(0),
                      separatorBuilder: (context, index) {
                        return Divider(
                          color: Color(0xff2b3c3a),
                          height: .7,
                        );
                      },
                      itemCount: widget.selectedUsers.length,
                      itemBuilder: (context, index) {
                        final user = widget.selectedUsers[index];
                        return ListTile(
                          contentPadding: EdgeInsets.all(0),
                          leading: CircleAvatar(
                            backgroundColor: Colors.grey[800],
                            child: Text(
                              getInitials(user['fullName'] ?? ''),
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(
                            user['fullName']!,
                            style: TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            user['phoneNumber']!,
                            style: TextStyle(color: Colors.grey),
                          ),
                        );
                      },
                    ),

                    SizedBox(height: 10),

                    // /// 🔹 Add Circle Button
                    // ElevatedButton(
                    //   onPressed: () {
                    //     if (circleNameController.text.isNotEmpty) {
                    //       _saveCircle();
                    //     }
                    //   },
                    //   style: ElevatedButton.styleFrom(
                    //     backgroundColor: Colors.tealAccent,
                    //     padding: EdgeInsets.symmetric(vertical: 14),
                    //     shape: RoundedRectangleBorder(
                    //       borderRadius: BorderRadius.circular(10),
                    //     ),
                    //   ),
                    //   child: Row(
                    //     mainAxisAlignment: MainAxisAlignment.center,
                    //     children: [
                    //       Text("Add circle",
                    //           style:
                    //               TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    //       SizedBox(width: 8),
                    //       Icon(Icons.arrow_forward),
                    //     ],
                    //   ),
                    // ),

                    SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
          Consumer(builder: (context, ref, child) {
            return Padding(
              padding: EdgeInsets.only(bottom: 40, left: 20, right: 20),
              child: ElevatedButton(
                onPressed: () async {
                  log('selected color : ${colorToHex(selectedColor)}');
                  // Handle Add Circle
                  await ref.read(circleNotifierProvider.notifier).addCircle(
                        circleName: circleNameController.text,
                        circleColor:
                            colorToHex(selectedColor), // e.g., "#FF5A5A"
                        members: widget.selectedUsers
                            .toList(), // [{fullName, phoneNumber}]
                      );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xff03FFE2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  minimumSize: Size(double.infinity, 48),
                ),
                child: circleState.status == CircleStateStatus.loading
                    ? CircularProgressIndicator(
                        color: Colors.white,
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Add circle",
                              style:
                                  TextStyle(color: Colors.black, fontSize: 16)),
                          SizedBox(width: 5),
                          Icon(Icons.arrow_forward, color: Colors.black),
                        ],
                      ),
              ),
            );
          }),
        ],
      ),
    );
  }

  final _sectionTitleStyle = TextStyle(
      color: Colors.white,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 20 / 14,
      fontFamily: "Inter");
}
