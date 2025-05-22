import 'dart:io';
import 'package:connecto/feature/video_creation/service/shotstack_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
// <- Replace with your path

class VideoFromPhotosScreen extends StatefulWidget {
  const VideoFromPhotosScreen({super.key});

  @override
  State<VideoFromPhotosScreen> createState() => _VideoFromPhotosScreenState();
}

class _VideoFromPhotosScreenState extends State<VideoFromPhotosScreen> {
  final ImagePicker _picker = ImagePicker();
  List<File> _selectedImages = [];
  bool _isLoading = false;
  String? _videoId;

  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages = images.map((xfile) => File(xfile.path)).toList();
      });
    }
  }

  Future<void> _submitToShotstack() async {
    setState(() => _isLoading = true);

    // TODO: Replace with your actual music URL and upload image URLs to cloud storage (like Firebase Storage)
    final imageUrls = _selectedImages
        .map((f) => 'https://example.com/${f.path.split("/").last}')
        .toList();
    final musicUrl = 'https://www.youtube.com/watch?v=3yBgLxgwS1U';

    final videoId = await ShotstackService().createVideo([
      'https://images.filmibeat.com/img/popcorn/profile_photos/mammootty-20231225114212-2447.jpg',
      'https://images.filmibeat.com/img/popcorn/profile_photos/mammootty-20231225114212-2447.jpg',
      'https://static.toiimg.com/thumb/msid-119080330,width-400,resizemode-4/119080330.jpg'
    ], musicUrl);

    setState(() {
      _isLoading = false;
      _videoId = videoId;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Create Video from Photos')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton.icon(
              onPressed: _pickImages,
              icon: Icon(Icons.photo_library),
              label: Text('Pick Images'),
            ),
            const SizedBox(height: 12),
            if (_selectedImages.isNotEmpty)
              SizedBox(
                height: 100,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _selectedImages
                      .map((file) => Padding(
                            padding: const EdgeInsets.all(4.0),
                            child:
                                Image.file(file, width: 100, fit: BoxFit.cover),
                          ))
                      .toList(),
                ),
              ),
            const SizedBox(height: 24),
            if (_isLoading)
              Center(child: CircularProgressIndicator())
            else
              ElevatedButton(
                onPressed:
                    _selectedImages.isNotEmpty ? _submitToShotstack : null,
                child: Text('Generate Video'),
              ),
            if (_videoId != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text('Video submitted. ID: $_videoId'),
              ),
          ],
        ),
      ),
    );
  }
}
