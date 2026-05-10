import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  static const String baseUrl = 'http://127.0.0.1:8000';
  
  // static const String baseUrl = 'http://192.168.160.1:8000'; // ye method ky liye use karny ky to use in mobile device

  final http.Client _client;

  Future<String> uploadPdf({
    required List<int> fileBytes,
    required String fileName,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload'),
      );

      request.files.add(
        http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          'Upload failed with status ${response.statusCode}: ${response.body}',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const ApiException(
          'Upload response was not a valid JSON object.',
        );
      }

      final sessionId = decoded['session_id'] ?? decoded['sessionId'];
      if (sessionId is! String || sessionId.isEmpty) {
        throw const ApiException(
          'Upload response did not include a session id.',
        );
      }

      return sessionId;
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException('Failed to upload PDF: $error');
    }
  }

  Future<String> askQuestion({
    required String sessionId,
    required String question,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/chat'),
        headers: const <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(<String, String>{
          'session_id': sessionId,
          'question': question,
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          'Chat request failed with status ${response.statusCode}: ${response.body}',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const ApiException('Chat response was not a valid JSON object.');
      }

      final answer = decoded['answer'];
      if (answer is! String || answer.isEmpty) {
        throw const ApiException('Chat response did not include an answer.');
      }

      return answer;
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException('Failed to ask question: $error');
    }
  }

  Future<List<dynamic>> fetchSessions() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/sessions'),
        headers: const <String, String>{'Accept': 'application/json'},
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          'Fetch sessions failed with status ${response.statusCode}: ${response.body}',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        throw const ApiException(
          'Sessions response was not a valid JSON array.',
        );
      }

      return decoded;
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException('Failed to fetch sessions: $error');
    }
  }

  Future<List<dynamic>> fetchChatHistory(String sessionId) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/chat/$sessionId'),
        headers: const <String, String>{'Accept': 'application/json'},
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          'Fetch chat history failed with status ${response.statusCode}: ${response.body}',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        throw const ApiException(
          'Chat history response was not a valid JSON array.',
        );
      }

      return decoded;
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException('Failed to fetch chat history: $error');
    }
  }

  Future<void> deleteSession(String sessionId) async {
    try {
      final response = await _client.delete(
        Uri.parse('$baseUrl/sessions/$sessionId'),
        headers: const <String, String>{'Accept': 'application/json'},
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          'Delete session failed with status ${response.statusCode}: ${response.body}',
        );
      }
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException('Failed to delete session: $error');
    }
  }

  Future<String> processUrl(String url) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/process_url'),
        headers: const <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(<String, String>{'url': url}),
      );

      if (response.statusCode == 400) {
        final decoded = jsonDecode(response.body);
        final detail = decoded['detail'];
        throw ApiException(
          detail is String ? detail : 'Failed to process URL.',
        );
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          'Process URL failed with status ${response.statusCode}: ${response.body}',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const ApiException('URL response was not a valid JSON object.');
      }

      final sessionId = decoded['session_id'] ?? decoded['sessionId'];
      if (sessionId is! String || sessionId.isEmpty) {
        throw const ApiException('URL response did not include a session id.');
      }

      return sessionId;
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException('Failed to process URL: $error');
    }
  }

  Future<String> processText(String text, String filename) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/process_text'),
        headers: const <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(<String, String>{
          'text': text,
          'filename': filename,
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          'Process text failed with status ${response.statusCode}: ${response.body}',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const ApiException('Text response was not a valid JSON object.');
      }

      final sessionId = decoded['session_id'] ?? decoded['sessionId'];
      if (sessionId is! String || sessionId.isEmpty) {
        throw const ApiException('Text response did not include a session id.');
      }

      return sessionId;
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException('Failed to process text: $error');
    }
  }
}

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
