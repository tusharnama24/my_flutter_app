import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class FullScreenCameraPage extends StatefulWidget {
  final List<CameraDescription> cameras;

  const FullScreenCameraPage({super.key, required this.cameras});

  @override
  State<FullScreenCameraPage> createState() => _FullScreenCameraPageState();
}

class _FullScreenCameraPageState extends State<FullScreenCameraPage> {
  late CameraController _controller;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.cameras.first,
      ResolutionPreset.high,
      enableAudio: true,
    );
    _controller.initialize().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    final photo = await _controller.takePicture();
    if (!mounted) return;
    Navigator.pop(context, photo); // 🔥 return image
  }

  Future<void> _toggleVideo() async {
    if (_isRecording) {
      final video = await _controller.stopVideoRecording();
      if (!mounted) return;
      Navigator.pop(context, video);
    } else {
      await _controller.startVideoRecording();
      setState(() => _isRecording = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: CameraPreview(_controller)),

          // Close button
          Positioned(
            top: 40,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: _takePhoto,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _toggleVideo,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _isRecording ? Colors.red : Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isRecording ? Icons.stop : Icons.videocam,
                      color: _isRecording ? Colors.white : Colors.black,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
