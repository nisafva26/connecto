import 'package:flutter/material.dart';

class CustomSwitcher extends StatelessWidget {
  final Function(int) onIndexChanged;
  CustomSwitcher({required this.onIndexChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      margin: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black54, // Adjust the background color as needed
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildOption(context, 'Friends', 0),
          _buildOption(context, 'Circles', 1),
        ],
      ),
    );
  }

  Widget _buildOption(BuildContext context, String title, int index) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onIndexChanged(index),
        child: Container(
          decoration: BoxDecoration(
            color: index == 0 ? Colors.teal : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              color: index == 0 ? Colors.white : Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
