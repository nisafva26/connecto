import 'package:connecto/feature/pings/model/ping_model.dart';
import 'package:connecto/feature/pings/widgets/ping_visulaizer.dart';
import 'package:flutter/material.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CreatePingScreen extends StatefulWidget {
  @override
  _CreatePingScreenState createState() => _CreatePingScreenState();
}

class _CreatePingScreenState extends State<CreatePingScreen> {
  final TextEditingController _pingNameController = TextEditingController();
  int? _selectedPatternIndex;

  final List<List<int>> hapticPatterns = [
    [100, 200, 100], // Short pulses
    [300, 100, 400], // Medium pulse
    [500, 100, 200], // Strong pulse
    [100, 100, 100, 300], // Patterned vibration
    [200, 500, 200, 100], // Slow-medium
  ];

  void _playVibration(List<int> pattern) async {
    // bool canVibrate = await Vibrate.canVibrate;
    // if (canVibrate) {
    //   Vibrate.vibrateWithPauses(pattern.map((d) => Duration(milliseconds: d)).toList());
    // }
  }

  void _savePing() {
    if (_pingNameController.text.isNotEmpty && _selectedPatternIndex != null) {
      Navigator.pop(
          context,
          PingModel(
              id: 'ping 4',
              name: _pingNameController.text,
              pattern: hapticPatterns[_selectedPatternIndex!],
              isCustom: true,
              createdAt: DateTime.now()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Color(0xff001311),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// 🔹 Header
              Container(
                decoration: BoxDecoration(
                  color: Color(0xFF091F1E),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                padding:
                    EdgeInsets.only(top: 16, bottom: 20, right: 23, left: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios,
                          color: Theme.of(context).colorScheme.primary),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      "Create custom ping",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text("Cancel",
                          style: TextStyle(
                              color: Colors.tealAccent, fontSize: 16)),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),

              /// 🔹 Ping Name Input
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ping name',
                        style: TextStyle(
                          color: const Color(0xFFF2F2F2),
                          fontSize: 14,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w500,
                          height: 1.43,
                        ),
                      ),
                      SizedBox(height: 6),
                      TextField(
                        controller: _pingNameController,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          fillColor: Color(0xff08201E),
                          filled: true,
                          hintText: "Enter ping name",
                          hintStyle: TextStyle(color: Colors.grey),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.tealAccent),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                                color: Color(0xff0E3735), width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                BorderSide(color: Color(0xFF03FFE2), width: 1),
                          ),
                        ),
                      ),
                      SizedBox(height: 38),

                      /// 🔹 Select Ping Haptics
                      Text(
                        'Select ping haptics',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      SizedBox(height: 10),
                      Expanded(
                        child: ListView.builder(
                          itemCount: hapticPatterns.length,
                          itemBuilder: (context, index) {
                            return GestureDetector(
                              onTap: () {
                                setState(() => _selectedPatternIndex = index);
                                _playVibration(hapticPatterns[index]);
                              },
                              child: Container(
                                margin: EdgeInsets.only(bottom: 12),
                                padding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Color(0xff091F1E),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: _selectedPatternIndex == index
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                          : Colors.transparent),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                        child: PingVisualizer(
                                            pattern: hapticPatterns[index])),
                                    IconButton(
                                      icon: Icon(Icons.play_arrow,
                                          color: Colors.tealAccent),
                                      onPressed: () =>
                                          _playVibration(hapticPatterns[index]),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      /// 🔹 Save & Send Button
                      SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _savePing,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.tealAccent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          minimumSize: Size(double.infinity, 50),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("Save and send ping",
                                style: TextStyle(
                                    color: Colors.black, fontSize: 16)),
                            SizedBox(width: 5),
                            Icon(Icons.arrow_forward, color: Colors.black),
                          ],
                        ),
                      ),
                      SizedBox(height: 30),
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
