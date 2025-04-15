import 'dart:async';
import 'dart:developer';
import 'dart:math' as math;

import 'package:connecto/feature/circles/controller/circle_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulsator/pulsator.dart';

class SuccessModal extends ConsumerStatefulWidget {
  final String circleName;
  final Color circleColor;
  final List<Map<String, String>>
      members; // List of members {fullName, phoneNumber}

  const SuccessModal({
    Key? key,
    required this.circleName,
    required this.circleColor,
    required this.members,
  }) : super(key: key);

  @override
  _SuccessModalState createState() => _SuccessModalState();
}

class _SuccessModalState extends ConsumerState<SuccessModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double angle = 0.0;

  late Timer _rotationTimer;

  @override
  void initState() {
    super.initState();
    // 🎯 Animation Controller for Circle Pulse
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 3),
    )..repeat(reverse: true);

    /// 🔄 Timer for Circular Motion
    _rotationTimer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      if (mounted) {
        setState(() {
          angle += math.pi / 50;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }

  /// 🔹 Function to Calculate Circular Position
  Offset calculatePosition(int index, int totalMembers, double radius) {
    final double angleOffset = (2 * math.pi / totalMembers) * index + angle;
    return Offset(
        radius * math.cos(angleOffset), radius * math.sin(angleOffset));
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.4,
      maxChildSize: 0.7,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Color(0xff091F1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check, color: Colors.tealAccent, size: 32),
              SizedBox(height: 12),
              Text(
                "Your circle has been added",
                style: TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),

              /// 🔹 Radiating Circle Effect with Members
              Expanded(
                child: Pulsator(
                  count: 6,
                  duration: Duration(seconds: 6),
                  repeat: 0,
                  startFromScratch: false,
                  autoStart: true,
                  style: PulseStyle(color: widget.circleColor),
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Container(
                        height: 200,
                        width: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.circleColor,
                          boxShadow: [
                            BoxShadow(
                              color: widget.circleColor.withOpacity(0.5),
                              blurRadius:
                                  _controller.value * 15 + 10, // Pulsating Glow
                              spreadRadius: _controller.value * 10 + 5,
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Text(
                              widget.circleName,
                              style: TextStyle(
                                color:
                                    widget.circleColor.computeLuminance() > .5
                                        ? Colors.black
                                        : Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            // 🔹 Members in Circular Motion
                            ...List.generate(
                              widget.members.length,
                              (index) {
                                Offset position = calculatePosition(
                                    index, widget.members.length, 75);
                                return AnimatedPositioned(
                                  duration: Duration(milliseconds: 500),
                                  left: 80 + position.dx,
                                  top: 80 + position.dy,
                                  child: CircleAvatar(
                                    radius: 18,
                                    backgroundColor: Colors.white,
                                    child: Text(
                                      _getInitials(
                                          widget.members[index]['fullName']!),
                                      style: TextStyle(color: Colors.black),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),

              /// 🎯 Pulsating Glow using **Pulsator**
              // Expanded(
              //   child: Pulsator(
              //     // effectExtent: 40, // Controls glow extent
              //     // pulseCurve: Curves.easeInOut,
              //     count: 5,
              //     duration: Duration(seconds: 4),
              //     repeat: 0,
              //     startFromScratch: false,
              //     autoStart: true,

              //     style: PulseStyle(color: widget.circleColor),
              //     child: Container(
              //       height: 200,
              //       width: 200,
              //       decoration: BoxDecoration(
              //         shape: BoxShape.circle,
              //         color: widget.circleColor,
              //       ),
              //       child: Stack(
              //         alignment: Alignment.center,
              //         children: [
              //           Text(
              //             widget.circleName,
              //             style: TextStyle(
              //               color: Colors.white,
              //               fontSize: 14,
              //               fontWeight: FontWeight.w500,
              //             ),
              //           ),

              //           /// 🔄 Members in Circular Motion
              //           ...List.generate(
              //             widget.members.length,
              //             (index) {
              //               Offset position = calculatePosition(
              //                   index, widget.members.length, 75);
              //               return AnimatedPositioned(
              //                 duration: Duration(milliseconds: 500),
              //                 left: 80 + position.dx,
              //                 top: 80 + position.dy,
              //                 child: CircleAvatar(
              //                   radius: 18,
              //                   backgroundColor: Colors.white,
              //                   child: Text(
              //                     _getInitials(
              //                         widget.members[index]['fullName']!),
              //                     style: TextStyle(color: Colors.black),
              //                   ),
              //                 ),
              //               );
              //             },
              //           ),
              //         ],
              //       ),
              //     ),
              //   ),
              // ),

              SizedBox(height: 24),

              /// ✅ "Okay" Button
              ElevatedButton(
                onPressed: () {
                  log('✅ Modal dismissed, resetting state');
                  ref.read(circleNotifierProvider.notifier).resetState();
                  Navigator.pop(context); // Close modal
                  context.go('/bond'); // Navigate to /bond
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xff03FFE2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  minimumSize: Size(double.infinity, 48),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Okay",
                        style: TextStyle(color: Colors.black, fontSize: 16)),
                    SizedBox(width: 5),
                    Icon(Icons.arrow_forward, color: Colors.black),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// ✅ Helper Function to Get Initials
  String _getInitials(String name) {
    List<String> names = name.trim().split(' ');
    if (names.length > 1) {
      return '${names[0][0]}${names[1][0]}'.toUpperCase();
    } else {
      return names[0][0].toUpperCase();
    }
  }
}
