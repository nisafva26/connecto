import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class ShotstackService {
  final String _apiKey = 'cBuRAlBocgmncdTsFUnMrhQbBLXmHFHPMWjxZEt6';
  final String _apiUrl = 'https://api.shotstack.io/stage/render';

  Future<String?> createVideo(List<String> imageUrls, String musicUrl) async {
    final uuid = Uuid().v4();
    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': _apiKey,
      },
      body: jsonEncode({
        'timeline': {
          'background': '#000000',
          'tracks': [
            {
              'clips': imageUrls
                  .asMap()
                  .entries
                  .map((entry) => {
                        'asset': {
                          'type': 'image',
                          'src': entry.value,
                        },
                        'start': (entry.key * 3).toDouble(), // 3 sec/image
                        'length': 3,
                      })
                  .toList()
            },
            // {
            //   'clips': [
            //     {
            //       'asset': {
            //         'type': 'audio',
            //         'src': musicUrl,
            //       },
            //       'start': 0,
            //       'length': imageUrls.length * 3,
            //     }
            //   ]
            // }
          ]
        },
        'output': {
          'format': 'mp4',
          'resolution': 'sd',
        }
      }),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return data['response']['id'];
    } else {
      print('Error: ${response.body}');
      return null;
    }
  }
}
