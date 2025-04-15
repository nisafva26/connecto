import 'package:flutter/material.dart';

class ContinueButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;
  final Color color;

  const ContinueButton(
      {Key? key,
      required this.onPressed,
      this.text = "Continue",
      this.color = const Color(0xff03FFE2)})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width,
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.black,
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              text,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(width: 8),
            Icon(Icons.arrow_forward, color: Colors.black),
          ],
        ),
      ),
    );
  }
}
