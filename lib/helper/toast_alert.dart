import 'package:flutter/material.dart';

// void showTopAlert(BuildContext context, String message) {
//   final overlay = Overlay.of(context);
//   final overlayEntry = OverlayEntry(
//     builder: (_) => Positioned(
//       top: MediaQuery.of(context).padding.top + 10,
//       left: 20,
//       right: 20,
//       child: Material(
//         color: Colors.transparent,
//         child: Container(
//           padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
//           decoration: BoxDecoration(
//             color: Color(0xFF38CB89),
//             borderRadius: BorderRadius.circular(16),
//           ),
//           child: Row(
//             children: [
//               Icon(Icons.check_circle_outline, color: Colors.white),
//               SizedBox(width: 12),
//               Expanded(
//                 child: Text(
//                   message,
//                   style: TextStyle(color: Colors.white, fontSize: 16),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     ),
//   );

//   overlay.insert(overlayEntry);

//   Future.delayed(Duration(seconds: 2), () => overlayEntry.remove());
// }

import 'dart:async';
import 'package:flutter/material.dart';

enum TopAlertType { success, error, info }

class TopAlertOverlay {
  static void show(
    BuildContext context,
    String message, {
    TopAlertType type = TopAlertType.success,
    Duration duration = const Duration(seconds: 2),
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (_) => _TopAlertWidget(
        message: message,
        type: type,
        duration: duration,
        onClose: () {
          overlayEntry.remove();
        },
      ),
    );

    overlay.insert(overlayEntry);
  }
}

class _TopAlertWidget extends StatefulWidget {
  final String message;
  final TopAlertType type;
  final Duration duration;
  final VoidCallback onClose;

  const _TopAlertWidget({
    Key? key,
    required this.message,
    required this.type,
    required this.duration,
    required this.onClose,
  }) : super(key: key);

  @override
  State<_TopAlertWidget> createState() => _TopAlertWidgetState();
}

class _TopAlertWidgetState extends State<_TopAlertWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  Color get backgroundColor {
    switch (widget.type) {
      case TopAlertType.success:
        return Color(0xFF38CB89);
      case TopAlertType.error:
        return Colors.red;
      case TopAlertType.info:
        return Colors.blueAccent;
    }
  }

  IconData get icon {
    switch (widget.type) {
      case TopAlertType.success:
        return Icons.check_circle_outline;
      case TopAlertType.error:
        return Icons.error_outline;
      case TopAlertType.info:
        return Icons.info_outline;
    }
  }

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );

    _offsetAnimation =
        Tween<Offset>(begin: Offset(0, -1.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();

    Future.delayed(widget.duration, () async {
      await _controller.reverse();
      widget.onClose();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 20,
      right: 20,
      child: SlideTransition(
        position: _offsetAnimation,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.message,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500,
                      height: 1.71,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
