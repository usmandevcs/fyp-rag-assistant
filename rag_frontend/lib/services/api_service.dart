import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiService {
	ApiService({http.Client? client}) : _client = client ?? http.Client();

	static const String baseUrl = 'http://127.0.0.1:8000';

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
				http.MultipartFile.fromBytes(
					'file',
					fileBytes,
					filename: fileName,
				),
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
				throw const ApiException('Upload response was not a valid JSON object.');
			}

			final sessionId = decoded['session_id'] ?? decoded['sessionId'];
			if (sessionId is! String || sessionId.isEmpty) {
				throw const ApiException('Upload response did not include a session id.');
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
}

class ApiException implements Exception {
	const ApiException(this.message);

	final String message;

	@override
	String toString() => message;
}
