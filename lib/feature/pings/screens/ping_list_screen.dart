import 'dart:developer';
// import 'dart:math';

import 'package:connecto/feature/pings/model/ping_model.dart';
import 'package:connecto/feature/pings/screens/create_ping.dart';
import 'package:connecto/feature/pings/widgets/ping_visulaizer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:vibration/vibration.dart';

import 'dart:developer';

import 'package:connecto/feature/pings/model/ping_model.dart';
import 'package:connecto/feature/pings/screens/create_ping.dart';

import 'package:flutter/material.dart';

class PingListModal extends StatefulWidget {
  final List<PingModel> pings;

  const PingListModal({super.key, required this.pings});

  @override
  State<PingListModal> createState() => _PingListModalState();
}

class _PingListModalState extends State<PingListModal> {
  String searchQuery = "";
  List<PingModel> filteredPings = [];
  PingModel? selectedPing;

  @override
  void initState() {
    super.initState();
    filteredPings = widget.pings;
  }

  void _filterPings(String query) {
    setState(() {
      searchQuery = query;
      filteredPings = widget.pings
          .where(
              (ping) => ping.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  void _playHapticPattern(List<int> pattern) async {
    bool canVibrate = await Vibration.hasVibrator();
    if (canVibrate) {
      Vibration.vibrate(pattern: pattern);
    } else {
      log("Device does not support haptic feedback.");
    }
  }

  void _playVibration(List<int> pattern) async {
    bool canVibrate = await Vibration.hasVibrator();
    if (canVibrate) {
      Vibration.vibrate(pattern: pattern);
    } else {
      log("Device does not support haptic feedback.");
    }
  }

  void _showCreatePingModal() async {
    final newPing = await showModalBottomSheet<PingModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreatePingScreen(),
    );

    if (newPing != null) {
      setState(() {
        widget.pings.add(newPing);
        _filterPings(searchQuery); // Refresh the filtered list
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          padding: EdgeInsets.all(0),
          decoration: BoxDecoration(
            color: Color(0xff001311),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          // padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// 🔹 Header
              Container(
                padding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                decoration: BoxDecoration(
                  color: Color(0xff091F1E),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text("Cancel",
                              style: TextStyle(
                                  color: Colors.tealAccent, fontSize: 16)),
                        ),
                        Text(
                          "Send Ping",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                        ),
                        TextButton(
                          onPressed: () {},
                          child: Text("Add",
                              style: TextStyle(
                                  color: Colors.transparent, fontSize: 16)),
                        ), // Placeholder for balance in alignment
                      ],
                    ),
                    SizedBox(
                      height: 18,
                    ),

                    /// 🔹 Search Bar
                    Container(
                      decoration: BoxDecoration(
                        color: Color(0xff091F1E),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: TextField(
                        onChanged: _filterPings,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Search for a ping",
                          hintStyle: TextStyle(color: Colors.grey),
                          // border: InputBorder.none,
                          enabledBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(12), // Rounded corners
                            borderSide: BorderSide(
                              color: Colors.white24, // Light border color
                              width: 1,
                            ),
                          ),
                          suffixIcon: Icon(Icons.search, color: Colors.grey),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Color(
                                  0xFF03FFE2), // Neon blue-green focus color
                              width: 1,
                            ),
                          ),
                          // prefixIcon: Icon(Icons.search, color: Colors.grey),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 10,
                    ),
                  ],
                ),
              ),

              // SizedBox(height: 10),

              /// 🔹 Create Custom Ping Button
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 34)
                        .copyWith(bottom: 12),
                child: GestureDetector(
                  onTap: _showCreatePingModal,
                  child: Container(
                    padding: EdgeInsets.all(14),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Color(0xff091F1E),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Column(
                      children: [
                        Container(
                          height: 24,
                          width: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          child: Center(
                            child:
                                Icon(Icons.add, size: 18, color: Colors.black),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Create custom ping',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // SizedBox(height: 14),

              /// 🔹 Ping List
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ListView.builder(
                    // physics: NeverScrollableScrollPhysics(),
                    controller: scrollController,
                    itemCount: filteredPings.length,
                    itemBuilder: (context, index) {
                      final ping = filteredPings[index];

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedPing = ping;
                          });
                          _playVibration(selectedPing!.pattern);
                          // Navigator.pop(
                          //     context, ping); // ✅ Return selected ping
                        },
                        child: Container(
                          margin: EdgeInsets.symmetric(vertical: 6),
                          padding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            color: Color(0xff08201e),
                            border: Border.all(
                                color: selectedPing == ping
                                    ? Color(0xff03FFE2)
                                    : Colors.transparent),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ping.name,
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 16),
                                    ),
                                    SizedBox(height: 6),
                                    PingVisualizer(
                                        pattern:
                                            ping.pattern), // 🔹 Visual Preview
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.play_arrow,
                                    color: Colors.tealAccent),
                                onPressed: () => _playHapticPattern(
                                    ping.pattern), // 🔹 Play Vibration
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              /// 🔹 Continue Button
              SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.all(20.0).copyWith(bottom: 40),
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(
                      context, selectedPing), // Close modal without selection
                  style: ElevatedButton.styleFrom(
                    backgroundColor: selectedPing != null
                        ? Color(0xff03FFE2)
                        : Color(0xff03FFE2).withOpacity(.2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    minimumSize: Size(double.infinity, 50),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Send ping",
                          style: TextStyle(color: Colors.black, fontSize: 16)),
                      SizedBox(width: 5),
                      Icon(Icons.arrow_forward, color: Colors.black),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
