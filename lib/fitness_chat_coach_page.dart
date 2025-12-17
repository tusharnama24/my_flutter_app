import 'package:flutter/material.dart';
import 'openai_service.dart';

class FitnessChatCoachPage extends StatefulWidget {
  @override
  _FitnessChatCoachPageState createState() => _FitnessChatCoachPageState();
}

class _FitnessChatCoachPageState extends State<FitnessChatCoachPage> {
  final OpenAIService _openAIService = OpenAIService();
  final TextEditingController _questionController = TextEditingController();

  String _answer = '';
  bool _isLoading = false;

  void _askCoach() async {
    setState(() {
      _answer = '';
      _isLoading = true;
    });

    try {
      final answer = await _openAIService.chatFitnessCoach(_questionController.text);
      setState(() {
        _answer = answer;
      });
    } catch (e) {
      setState(() {
        _answer = 'Error getting response from coach.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Fitness Chat Coach')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _questionController,
              decoration: InputDecoration(
                labelText: 'Ask your fitness question',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isLoading ? null : _askCoach,
              child: _isLoading ? CircularProgressIndicator() : Text('Ask Coach'),
            ),
            SizedBox(height: 24),
            if (_answer.isNotEmpty)
              Text(
                _answer,
                style: TextStyle(fontSize: 16),
              )
          ],
        ),
      ),
    );
  }
}
