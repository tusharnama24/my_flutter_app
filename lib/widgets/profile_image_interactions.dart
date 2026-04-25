import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

Future<File?> editProfileImageWithInstagramStyle(
  BuildContext context, {
  required String imagePath,
  required String outputNamePrefix,
}) async {
  final Uint8List? editedBytes = await Navigator.push<Uint8List>(
    context,
    MaterialPageRoute(
      builder: (_) => _ProfileImageEditorPage(imagePath: imagePath),
    ),
  );

  if (editedBytes == null) return null;

  final file = File(
    '${Directory.systemTemp.path}${Platform.pathSeparator}${outputNamePrefix}_${DateTime.now().millisecondsSinceEpoch}.jpg',
  );
  return file.writeAsBytes(editedBytes, flush: true);
}

void openProfileMediaPreview(
  BuildContext context, {
  required ImageProvider image,
  required String heroTag,
}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => _ProfileMediaPreviewPage(
        image: image,
        heroTag: heroTag,
      ),
    ),
  );
}

class _ProfileImageEditorPage extends StatelessWidget {
  final String imagePath;

  const _ProfileImageEditorPage({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: ProImageEditor.file(
        File(imagePath),
        configs: const ProImageEditorConfigs(
          imageGeneration: ImageGenerationConfigs(
            outputFormat: OutputFormat.jpg,
            maxOutputSize: Size(1600, 1600),
          ),
        ),
        callbacks: ProImageEditorCallbacks(
          onImageEditingComplete: (Uint8List bytes) async {
            if (!context.mounted) return;
            Navigator.pop(context, bytes);
          },
        ),
      ),
    );
  }
}

class _ProfileMediaPreviewPage extends StatelessWidget {
  final ImageProvider image;
  final String heroTag;

  const _ProfileMediaPreviewPage({
    required this.image,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: Hero(
              tag: heroTag,
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Image(
                  image: image,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
