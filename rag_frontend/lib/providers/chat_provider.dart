import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';

class ChatProvider extends ChangeNotifier {
  ChatProvider({ApiService? apiService}) : _apiService = apiService ?? ApiService();

  static const String _sessionIdKey = 'session_id';

  final ApiService _apiService;

  final List<Map<String, String>> _messages = <Map<String, String>>[];
  bool _isLoading = false;
  String? _sessionId;
  String? _errorMessage;

  List<Map<String, String>> get messages => List<Map<String, String>>.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  String? get sessionId => _sessionId;
  String? get errorMessage => _errorMessage;

  Future<void> init() async {
    final preferences = await SharedPreferences.getInstance();
    _sessionId = preferences.getString(_sessionIdKey);
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> clearSession() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_sessionIdKey);

    _messages.clear();
    _sessionId = null;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> pickAndUploadFile() async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: <String>['pdf'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        _errorMessage = 'No PDF file was selected.';
        notifyListeners();
        return;
      }

      final pickedFile = result.files.single;
      final bytes = pickedFile.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw const ApiException('The selected PDF could not be read.');
      }

      final sessionId = await _apiService.uploadPdf(
        fileBytes: bytes,
        fileName: pickedFile.name,
      );

      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_sessionIdKey, sessionId);

      _sessionId = sessionId;
      _messages.clear();
      _errorMessage = null;
    } catch (error) {
      _errorMessage = _formatError(error);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> sendMessage(String text) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      _errorMessage = 'Question cannot be empty.';
      notifyListeners();
      return;
    }

    if (_sessionId == null || _sessionId!.isEmpty) {
      _errorMessage = 'Upload a PDF before asking questions.';
      notifyListeners();
      return;
    }

    _messages.add(<String, String>{'role': 'user', 'text': trimmedText});
    _setLoading(true);
    _errorMessage = null;

    try {
      final answer = await _apiService.askQuestion(
        sessionId: _sessionId!,
        question: trimmedText,
      );

      _messages.add(<String, String>{'role': 'assistant', 'text': answer});
    } catch (error) {
      _errorMessage = _formatError(error);
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  String _formatError(Object error) {
    if (error is ApiException) {
      return error.message;
    }

    return error.toString();
  }
}