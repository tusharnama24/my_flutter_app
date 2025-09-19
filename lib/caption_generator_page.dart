import 'package:flutter/material.dart';
import 'openai_service.dart';

class CaptionGeneratorPage extends StatefulWidget {
  @override
  _CaptionGeneratorPageState createState() => _CaptionGeneratorPageState();
}

class _CaptionGeneratorPageState extends State<CaptionGeneratorPage> {
  final OpenAIService _openAIService = OpenAIService();
  final TextEditingController _textController = TextEditingController();

  String _caption = '';
  String _hashtags = '';
  bool _isLoading = false;

  void _generate() async {
    setState(() {
      _caption = '';
      _hashtags = '';
      _isLoading = true;
    });

    try {
      final caption = await _openAIService.generateCaption(_textController.text);
      final hashtags = await _openAIService.generateHashtagsAndEmojis(_textController.text);

      setState(() {
        _caption = caption;
        _hashtags = hashtags;
      });
    } catch (e) {
      setState(() {
        _caption = 'Error generating caption.';
        _hashtags = '';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('AI Caption Generator')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _textController,
              decoration: InputDecoration(
                labelText: 'Describe your fitness post',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isLoading ? null : _generate,
              child: _isLoading ? CircularProgressIndicator() : Text('Generate Caption'),
            ),
            SizedBox(height: 24),
            if (_caption.isNotEmpty) ...[
              Text('Caption:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(_caption),
              SizedBox(height: 16),
              Text('Hashtags & Emojis:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(_hashtags),
            ]
          ],
        ),
      ),
    );
  }
}
