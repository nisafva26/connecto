import 'package:url_launcher/url_launcher.dart';

Future<void> openMapsDirections(double lat, double lng) async {
  final url = Uri.parse(
    "https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving",
  );

  if (await canLaunchUrl(url)) {
    await launchUrl(url, mode: LaunchMode.externalApplication);
  } else {
    throw 'Could not launch maps for location: $lat, $lng';
  }
}