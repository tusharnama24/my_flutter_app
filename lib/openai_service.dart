import 'dart:convert';
import 'package:http/http.dart' as http;

class OpenAIService {
  final String apiKey = 'YOUR_OPENAI_API_KEY'; // Replace with your OpenAI API key here

  Future<String> generateCaption(String prompt) async {
    final url = Uri.parse('https://api.openai.com/v1/chat/completions');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };

    final body = jsonEncode({
      'model': 'gpt-4o-mini',
      'messages': [
        {'role': 'user', 'content': 'Generate a catchy fitness caption for: $prompt'}
      ],
      'max_tokens': 60,
      'temperature': 0.7,
    });

    final response = await http.post(url, headers: headers, body: body);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final text = data['choices'][0]['message']['content'];
      return text.trim();
    } else {
      throw Exception('Failed to generate caption');
    }
  }

  Future<String> generateHashtagsAndEmojis(String prompt) async {
    final url = Uri.parse('https://api.openai.com/v1/chat/completions');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };

    final body = jsonEncode({
      'model': 'gpt-4o-mini',
      'messages': [
        {
          'role': 'user',
          'content': 'Suggest relevant hashtags and emojis for a fitness post about: $prompt'
        }
      ],
      'max_tokens': 40,
      'temperature': 0.7,
    });

    final response = await http.post(url, headers: headers, body: body);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final text = data['choices'][0]['message']['content'];
      return text.trim();
    } else {
      throw Exception('Failed to generate hashtags and emojis');
    }
  }

  Future<String> chatFitnessCoach(String userQuestion) async {
    final url = Uri.parse('https://api.openai.com/v1/chat/completions');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };

    final body = jsonEncode({
      'model': 'gpt-4o-mini',
      'messages': [
        {
          'role': 'system',
          'content': 'You are a helpful fitness coach giving advice on workouts, nutrition, and health.'
        },
        {
          'role': 'user',
          'content': userQuestion
        }
      ],
      'max_tokens': 150,
      'temperature': 0.8,
    });

    final response = await http.post(url, headers: headers, body: body);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final text = data['choices'][0]['message']['content'];
      return text.trim();
    } else {
      throw Exception('Failed to get response from fitness coach');
    }
  }
}
