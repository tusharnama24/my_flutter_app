import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:classic_1/services/cloudinary_service.dart'; // Cloudinary helper class

class AddPostPage extends StatefulWidget {
  @override
  _AddPostPageState createState() => _AddPostPageState();
}

class _AddPostPageState extends State<AddPostPage> {
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final CloudinaryService _cloudinaryService = CloudinaryService();

  List<XFile> _selectedImages = [];
  List<XFile> _selectedVideos = [];
  bool _isLoading = false;

  /// Pick multiple images
  Future<void> _pickImages() async {
    final List<XFile>? images = await _picker.pickMultiImage();
    if (images != null) {
      setState(() {
        _selectedImages = images;
      });
    }
  }

  /// Pick single video
  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() {
        _selectedVideos = [video];
      });
    }
  }

  /// Upload and save post
  Future<void> _submitPost() async {
    if (_selectedImages.isEmpty && _selectedVideos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please select at least one image or a video.")),
      );
      return;
    }

    if (_captionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter a caption.")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      List<Map<String, dynamic>> mediaList = [];

      for (var image in _selectedImages) {
        String? url = await _cloudinaryService.uploadMedia(image.path, isVideo: false);
        if (url != null) {
          mediaList.add({ 'type': 'image', 'url': url });
        }
      }

      for (var video in _selectedVideos) {
        String? url = await _cloudinaryService.uploadMedia(video.path, isVideo: true);
        if (url != null) {
          mediaList.add({ 'type': 'video', 'url': url });
        }
      }

      await FirebaseFirestore.instance.collection("posts").add({
        // New unified media array
        "media": mediaList,
        // Back-compat for existing UI that may still read images
        "images": mediaList.where((m) => m['type'] == 'image').map<String>((m) => m['url'] as String).toList(),
        "caption": _captionController.text,
        "location": _locationController.text,
        "createdAt": FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Post uploaded successfully!")),
      );

      // Reset form
      setState(() {
        _selectedImages = [];
        _selectedVideos = [];
        _captionController.clear();
        _locationController.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Post'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              /// Location
              TextField(
                controller: _locationController,
                decoration: InputDecoration(
                  hintText: 'Add Location',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  contentPadding:
                  EdgeInsets.symmetric(vertical: 2, horizontal: 10),
                  suffixIcon: Icon(Icons.location_on),
                ),
              ),
              SizedBox(height: 16),

              /// Image Picker Button
              GestureDetector(
                onTap: _pickImages,
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.black),
                          ),
                          child: Icon(Icons.add,
                              size: 40, color: Colors.black, weight: 2),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Add Post',
                          style: TextStyle(fontSize: 20, color: Colors.black),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16),

              /// Video Picker Button
              GestureDetector(
                onTap: _pickVideo,
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.video_library, color: Colors.black),
                        SizedBox(width: 8),
                        Text('Add Video', style: TextStyle(color: Colors.black)),
                        if (_selectedVideos.isNotEmpty) ...[
                          SizedBox(width: 12),
                          Text('(1 selected)', style: TextStyle(color: Colors.black54)),
                        ]
                      ],
                    ),
                  ),
                ),
              ),

              /// Selected Images Preview
              _selectedImages != null && _selectedImages!.isNotEmpty
                  ? Container(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages!.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 4.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_selectedImages![index].path),
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                ),
              )
                  : SizedBox(),

              SizedBox(height: 16),

              /// Caption
              TextField(
                controller: _captionController,
                decoration: InputDecoration(
                  hintText: 'Add Caption',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLines: 3,
              ),
              SizedBox(height: 30),

              /// Submit Button
              ElevatedButton(
                onPressed: _isLoading ? null : _submitPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? CircularProgressIndicator(color: Colors.black)
                    : Text(
                  'Submit',
                  style: TextStyle(fontSize: 16, color: Colors.black),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
