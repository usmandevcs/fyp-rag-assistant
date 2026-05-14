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

  Future<Map<String, dynamic>> askQuestion({
    required String sessionId,
    required String question,
    List<String>? pinnedMessages,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/chat'),
        headers: const <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{
          'session_id': sessionId,
          'question': question,
          'pinned_messages': pinnedMessages ?? <String>[],
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

      // Parse sources list; default to empty if absent or wrong type
      final rawSources = decoded['sources'];
      final sources = rawSources is List
          ? rawSources.whereType<String>().toList()
          : <String>[];

      // Parse follow_ups list
      final rawFollowUps = decoded['follow_ups'];
      final followUps = rawFollowUps is List
          ? rawFollowUps.whereType<String>().toList()
          : <String>[];

      // Parse chart data
      final rawChartData = decoded['chart_data'];
      final chartData = rawChartData is List ? rawChartData : <dynamic>[];

      return <String, dynamic>{
        'answer': answer,
        'sources': sources,
        'follow_ups': followUps,
        'chart_data': chartData,
      };
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException('Failed to ask question: $error');
    }
  }

  /// Ask a question across multiple document sessions via `/chat_multi`.
  Future<Map<String, dynamic>> askMultiQuestion({
    required List<String> sessionIds,
    required String question,
    List<String>? pinnedMessages,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/chat_multi'),
        headers: const <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{
          'session_ids': sessionIds,
          'question': question,
          'pinned_messages': pinnedMessages ?? <String>[],
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          'Multi-chat request failed with status ${response.statusCode}: ${response.body}',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const ApiException(
          'Multi-chat response was not a valid JSON object.',
        );
      }

      final answer = decoded['answer'];
      if (answer is! String || answer.isEmpty) {
        throw const ApiException(
          'Multi-chat response did not include an answer.',
        );
      }

      final rawSources = decoded['sources'];
      final sources = rawSources is List
          ? rawSources.whereType<String>().toList()
          : <String>[];

      final rawFollowUps = decoded['follow_ups'];
      final followUps = rawFollowUps is List
          ? rawFollowUps.whereType<String>().toList()
          : <String>[];

      final rawChartData = decoded['chart_data'];
      final chartData = rawChartData is List ? rawChartData : <dynamic>[];

      return <String, dynamic>{
        'answer': answer,
        'sources': sources,
        'follow_ups': followUps,
        'chart_data': chartData,
      };
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException('Failed to ask multi-document question: $error');
    }
  }

  /// Fetch a structured summary from `/summary/{session_id}`.
  /// Returns a map with keys: overview, key_findings, critical_data_points, conclusion.
  Future<Map<String, dynamic>> fetchStructuredSummary(String sessionId) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/summary/$sessionId'),
        headers: const <String, String>{'Accept': 'application/json'},
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          'Summary request failed with status ${response.statusCode}: ${response.body}',
        );
      }

      dynamic decoded = jsonDecode(response.body);
      if (decoded is String) {
        decoded = jsonDecode(decoded);
      }

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }

      throw const ApiException(
        'Summary response was not a valid JSON object.',
      );
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException('Failed to fetch structured summary: $error');
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

  /// Send recorded audio to `/chat_voice` for transcription + RAG answer.
  /// Returns a map with `question`, `answer`, and `sources`.
  Future<Map<String, dynamic>> sendVoiceMessage({
    required String sessionId,
    required List<int> audioBytes,
    required String fileName,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/chat_voice'),
      );

      // session_id is sent as a form field (File(...) in FastAPI)
      request.fields['session_id'] = sessionId;

      request.files.add(
        http.MultipartFile.fromBytes('audio', audioBytes, filename: fileName),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          'Voice chat failed with status ${response.statusCode}: ${response.body}',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const ApiException(
          'Voice chat response was not a valid JSON object.',
        );
      }

      final question = decoded['question'];
      final answer = decoded['answer'];
      if (question is! String || answer is! String) {
        throw const ApiException(
          'Voice chat response missing question or answer.',
        );
      }

      final rawSources = decoded['sources'];
      final sources = rawSources is List
          ? rawSources.whereType<String>().toList()
          : <String>[];

      final rawChartData = decoded['chart_data'];
      final chartData = rawChartData is List ? rawChartData : <dynamic>[];

      return <String, dynamic>{
        'question': question,
        'answer': answer,
        'sources': sources,
        'chart_data': chartData,
      };
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException('Failed to send voice message: $error');
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

  Future<Map<String, dynamic>> getApiStatus() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/api/status'),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          'API status request failed with status ${response.statusCode}: ${response.body}',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const ApiException('API status response was not a valid JSON object.');
      }

      return decoded;
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException('Failed to fetch API status: $error');
    }
  }
}

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
