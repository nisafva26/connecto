import 'package:flutter/material.dart';
import 'package:loading_indicator/loading_indicator.dart';

class ContinueButtonWithLoading extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;
  final bool isLoading;
  final Color color;

  const ContinueButtonWithLoading({
    Key? key,
    required this.onPressed,
    this.text = "Continue",
    this.color = const Color(0xff03FFE2),
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: isLoading
            ? SizedBox(
                height: 40,
                child: LoadingIndicator(
                  indicatorType: Indicator.ballBeat,
                  colors: [Colors.black],
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    text,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward, color: Colors.black),
                ],
              ),
      ),
    );
  }
}
