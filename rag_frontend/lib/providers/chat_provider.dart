import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';

enum LoadingType { none, document, link, text, chat }

class ChatProvider extends ChangeNotifier {
  ChatProvider({ApiService? apiService})
    : _apiService = apiService ?? ApiService();

  static const String _sessionIdKey = 'session_id';
  static const String _filenameKey = 'file_name';

  final ApiService _apiService;

  final List<Map<String, String>> _messages = <Map<String, String>>[];
  final List<Map<String, dynamic>> _pastSessions = <Map<String, dynamic>>[];
  bool _isLoading = false;
  LoadingType _loadingType = LoadingType.none;
  String? _sessionId;
  String? _filename;
  String? _errorMessage;
  String? generatedSummaryText;

  List<Map<String, String>> get messages =>
      List<Map<String, String>>.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  LoadingType get loadingType => _loadingType;
  String? get sessionId => _sessionId;
  String? get filename => _filename;
  String? get errorMessage => _errorMessage;
  List<Map<String, dynamic>> get pastSessions =>
      List<Map<String, dynamic>>.unmodifiable(_pastSessions);

  Future<void> init() async {
    final preferences = await SharedPreferences.getInstance();
    _sessionId = preferences.getString(_sessionIdKey);
    _filename = preferences.getString(_filenameKey);
    _errorMessage = null;
    generatedSummaryText = null;
    notifyListeners();
    await loadPastSessions();
  }

  Future<void> loadPastSessions() async {
    try {
      final sessions = await _apiService.fetchSessions();
      _pastSessions.clear();
      for (final session in sessions) {
        if (session is Map<String, dynamic>) {
          _pastSessions.add(session);
        }
      }
    } catch (error) {
      _errorMessage = _formatError(error);
    } finally {
      notifyListeners();
    }
  }

  Future<void> loadSession(String newSessionId, String filename) async {
    _isLoading = true;
    _sessionId = newSessionId;
    _filename = filename;
    notifyListeners();

    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_sessionIdKey, newSessionId);
      await preferences.setString(_filenameKey, filename);

      _messages.clear();
      generatedSummaryText = null;

      final chatHistory = await _apiService.fetchChatHistory(newSessionId);
      for (final item in chatHistory) {
        if (item is Map<String, dynamic>) {
          final question = item['question'];
          final answer = item['answer'];

          if (question is String) {
            _messages.add(<String, String>{'role': 'user', 'text': question});
          }
          if (answer is String) {
            _messages.add(<String, String>{
              'role': 'assistant',
              'text': answer,
            });
          }
        }
      }
      _errorMessage = null;
    } catch (error) {
      _errorMessage = _formatError(error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> clearSession() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_sessionIdKey);
    await preferences.remove(_filenameKey);

    _messages.clear();
    _sessionId = null;
    _filename = null;
    generatedSummaryText = null;
    _isLoading = false;
    _loadingType = LoadingType.none;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> pickAndUploadFile() async {
    _setLoading(true, type: LoadingType.document);
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
      await preferences.setString(_filenameKey, pickedFile.name);

      _sessionId = sessionId;
      _filename = pickedFile.name;
      _messages.clear();
      generatedSummaryText = null;
      _errorMessage = null;
      // Refresh the list of past sessions so the sidebar reflects this new upload
      await loadPastSessions();
    } catch (error) {
      _errorMessage = _formatError(error);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> sendMessage(
    String text, {
    bool isSummaryRequest = false,
  }) async {
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
    _setLoading(true, type: LoadingType.chat);
    _errorMessage = null;

    try {
      final answer = await _apiService.askQuestion(
        sessionId: _sessionId!,
        question: trimmedText,
      );

      _messages.add(<String, String>{'role': 'assistant', 'text': answer});
      if (isSummaryRequest) {
        generatedSummaryText = answer;
      }
    } catch (error) {
      _errorMessage = _formatError(error);
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value, {LoadingType type = LoadingType.none}) {
    _isLoading = value;
    _loadingType = value ? type : LoadingType.none;
    notifyListeners();
  }

  Future<void> removeSession(String sessionId) async {
    try {
      await _apiService.deleteSession(sessionId);
      _pastSessions.removeWhere((session) => session['session_id'] == sessionId);

      // If the deleted session is the current one, clear current session
      if (_sessionId == sessionId) {
        await clearSession();
      }

      notifyListeners();
    } catch (error) {
      _errorMessage = _formatError(error);
      notifyListeners();
    }
  }

  Future<void> processUrl(String url) async {
    _setLoading(true, type: LoadingType.link);
    _errorMessage = null;

    try {
      final sessionId = await _apiService.processUrl(url);

      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_sessionIdKey, sessionId);
      await preferences.setString(_filenameKey, url);

      _sessionId = sessionId;
      _filename = url;
      _messages.clear();
      generatedSummaryText = null;
      _errorMessage = null;
      // Refresh the list of past sessions so the sidebar reflects this new entry
      await loadPastSessions();
    } catch (error) {
      _errorMessage = _formatError(error);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> processText(String text, String title) async {
    _setLoading(true, type: LoadingType.text);
    _errorMessage = null;

    try {
      final sessionId = await _apiService.processText(text, title);

      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_sessionIdKey, sessionId);
      await preferences.setString(_filenameKey, title);

      _sessionId = sessionId;
      _filename = title;
      _messages.clear();
      generatedSummaryText = null;
      _errorMessage = null;
      // Refresh the list of past sessions so the sidebar reflects this new entry
      await loadPastSessions();
    } catch (error) {
      _errorMessage = _formatError(error);
    } finally {
      _setLoading(false);
    }
  }

  String _formatError(Object error) {
    if (error is ApiException) {
      return error.message;
    }

    return error.toString();
  }
}
