import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_message.dart';
import '../services/api_service.dart';

enum LoadingType { none, document, link, text, chat, voice, summary }

class ChatProvider extends ChangeNotifier {
  ChatProvider({ApiService? apiService})
    : _apiService = apiService ?? ApiService();

  static const String _sessionIdKey = 'session_id';
  static const String _filenameKey = 'file_name';

  final ApiService _apiService;

  final List<ChatMessage> _messages = <ChatMessage>[];
  final List<Map<String, dynamic>> _pastSessions = <Map<String, dynamic>>[];
  bool _isLoading = false;
  LoadingType _loadingType = LoadingType.none;
  String? _sessionId;
  String? _filename;
  String? _errorMessage;
  String? generatedSummaryText;

  // --- Structured summary state ---
  Map<String, dynamic>? _structuredSummary;

  // --- "Ready to chat" one-shot popup flag ---
  bool _showReadyPopup = false;

  // --- Voice Mode state ---
  final AudioRecorder _recorder = AudioRecorder();
  final FlutterTts _tts = FlutterTts();
  bool _isRecording = false;
  bool _isProcessingVoice = false;
  bool _ttsInitialized = false;
  String? _currentRecordingPath;

  // --- Multi-document chat state ---
  final List<String> _selectedSessionIds = <String>[];
  final List<String> _pinnedMessages = <String>[];

  List<ChatMessage> get messages => List<ChatMessage>.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  LoadingType get loadingType => _loadingType;
  String? get sessionId => _sessionId;
  String? get filename => _filename;
  String? get errorMessage => _errorMessage;
  bool get isRecording => _isRecording;
  bool get isProcessingVoice => _isProcessingVoice;
  List<String> get selectedSessionIds =>
      List<String>.unmodifiable(_selectedSessionIds);
  List<String> get pinnedMessages => List<String>.unmodifiable(_pinnedMessages);
  bool get isMultiDocMode => _selectedSessionIds.length > 1;
  Map<String, dynamic>? get structuredSummary => _structuredSummary;
  bool get showReadyPopup => _showReadyPopup;
  Map<String, dynamic>? get apiStatus => _apiStatus;

  Map<String, dynamic>? _apiStatus;

  /// Consume the one-shot popup flag (returns true once, then resets).
  bool consumeReadyPopup() {
    if (!_showReadyPopup) return false;
    _showReadyPopup = false;
    return true;
  }
  List<Map<String, dynamic>> get pastSessions =>
      List<Map<String, dynamic>>.unmodifiable(_pastSessions);

  // -------------------------------------------------------
  // Multi-document selection
  // -------------------------------------------------------

  /// Add or remove a session from the multi-doc selection.
  void toggleSessionSelection(String sessionId) {
    if (_selectedSessionIds.contains(sessionId)) {
      _selectedSessionIds.remove(sessionId);
    } else {
      _selectedSessionIds.add(sessionId);
    }
    notifyListeners();
  }

  /// Clear all multi-doc selections.
  void clearSessionSelection() {
    _selectedSessionIds.clear();
    notifyListeners();
  }

  void togglePinMessage(String message) {
    if (_pinnedMessages.contains(message)) {
      _pinnedMessages.remove(message);
    } else {
      _pinnedMessages.add(message);
    }
    notifyListeners();
  }

  /// Lock the assistant bubble to static markdown after the typewriter finishes.
  void markMessageAnimationFinished(ChatMessage message) {
    message.isAnimationFinished = true;
    notifyListeners();
  }

  Future<void> init() async {
    final preferences = await SharedPreferences.getInstance();
    _sessionId = preferences.getString(_sessionIdKey);
    _filename = preferences.getString(_filenameKey);
    _errorMessage = null;
    generatedSummaryText = null;
    notifyListeners();
    await loadPastSessions();
    await _initTts();
    await fetchApiStatus();
  }

  Future<void> fetchApiStatus() async {
    try {
      final status = await _apiService.getApiStatus();
      _apiStatus = status;
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching API status: $e');
    }
  }

  // -------------------------------------------------------
  // TTS
  // -------------------------------------------------------

  Future<void> _initTts() async {
    if (_ttsInitialized) return;
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.48);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      _ttsInitialized = true;
    } catch (_) {
      // TTS not available on this platform — degrade gracefully
    }
  }

  Future<void> _speakText(String text) async {
    if (!_ttsInitialized) return;
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {
      // Ignore TTS playback errors
    }
  }

  Future<void> stopTts() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  // -------------------------------------------------------
  // Audio recording
  // -------------------------------------------------------

  Future<void> startRecording() async {
    if (_isRecording || kIsWeb) return;

    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        _errorMessage = 'Microphone permission is required for voice mode.';
        notifyListeners();
        return;
      }

      final dir = await getTemporaryDirectory();
      _currentRecordingPath =
          '${dir.path}/vesper_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: _currentRecordingPath!,
      );

      _isRecording = true;
      _errorMessage = null;
      notifyListeners();
    } catch (error) {
      _errorMessage = 'Failed to start recording: $error';
      _isRecording = false;
      notifyListeners();
    }
  }

  Future<void> stopRecordingAndSend() async {
    if (!_isRecording) return;

    String? path;
    try {
      path = await _recorder.stop();
    } catch (error) {
      _isRecording = false;
      _errorMessage = 'Failed to stop recording: $error';
      notifyListeners();
      return;
    }

    _isRecording = false;
    notifyListeners();

    try {
      if (path == null || path.isEmpty) {
        _errorMessage = 'Recording failed — no audio captured.';
        notifyListeners();
        return;
      }
      await _sendVoiceFile(path);
    } catch (error) {
      _errorMessage = _formatError(error);
      notifyListeners();
    }
  }

  Future<void> cancelRecording() async {
    if (!_isRecording) return;
    try {
      final path = await _recorder.stop();
      _isRecording = false;
      notifyListeners();
      if (path != null && path.isNotEmpty) {
        try {
          final file = File(path);
          if (await file.exists()) await file.delete();
        } catch (e) {
          debugPrint('Voice cancel: failed to delete temp file: $e');
        }
      }
    } catch (error) {
      _isRecording = false;
      _errorMessage = 'Failed to cancel recording: $error';
      notifyListeners();
    }
  }

  Future<void> _sendVoiceFile(String filePath) async {
    if (_sessionId == null || _sessionId!.isEmpty) {
      _errorMessage = 'Upload a document before using voice mode.';
      notifyListeners();
      return;
    }

    _isProcessingVoice = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final file = File(filePath);
      final audioBytes = await file.readAsBytes();
      final fileName = filePath.split(RegExp(r'[\\/]')).last;

      final result = await _apiService.sendVoiceMessage(
        sessionId: _sessionId!,
        audioBytes: audioBytes,
        fileName: fileName,
      );

      final question = result['question'] as String;
      final answer = result['answer'] as String;
      final sources = result['sources'] as List<String>;
      final sourcesText = sources.isNotEmpty ? sources.join(', ') : '';

      _messages.add(ChatMessage(role: 'user', text: '🎤 $question'));

      _messages.add(
        ChatMessage(
          role: 'assistant',
          text: answer,
          sources: sourcesText.isNotEmpty ? sourcesText : null,
        ),
      );

      try {
        await _speakText(answer);
      } catch (e) {
        debugPrint('TTS after voice response: $e');
      }
    } catch (error) {
      _errorMessage = _formatError(error);
    } finally {
      _isProcessingVoice = false;
      notifyListeners();
      fetchApiStatus();
      try {
        final file = File(filePath);
        if (await file.exists()) await file.delete();
      } catch (e) {
        debugPrint('Voice temp file cleanup: $e');
      }
    }
  }

  // -------------------------------------------------------
  // Existing methods (unchanged)
  // -------------------------------------------------------

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
            _messages.add(ChatMessage(role: 'user', text: question));
          }
          if (answer is String) {
            _messages.add(
              ChatMessage(
                role: 'assistant',
                text: answer,
                isAnimationFinished: true,
              ),
            );
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
    _structuredSummary = null;
    _isLoading = false;
    _loadingType = LoadingType.none;
    _errorMessage = null;
    notifyListeners();
  }

  /// Fetch a structured summary from the backend and store it in state.
  Future<void> requestStructuredSummary() async {
    if (_sessionId == null || _sessionId!.isEmpty) {
      _errorMessage = 'Upload a document before requesting a summary.';
      notifyListeners();
      return;
    }

    _setLoading(true, type: LoadingType.summary);
    _errorMessage = null;
    _structuredSummary = null;

    try {
      final result =
          await _apiService.fetchStructuredSummary(_sessionId!);
      _structuredSummary = result;
    } catch (error) {
      _errorMessage = _formatError(error);
    } finally {
      _setLoading(false);
    }
  }

  /// Dismiss the structured summary dashboard without downloading.
  void dismissSummary() {
    _structuredSummary = null;
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
      _showReadyPopup = true;
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

    // Multi-doc mode: need at least 2 selected sessions
    // Single-doc mode: need an active session
    if (!isMultiDocMode && (_sessionId == null || _sessionId!.isEmpty)) {
      _errorMessage = 'Upload a PDF before asking questions.';
      notifyListeners();
      return;
    }

    _messages.add(ChatMessage(role: 'user', text: trimmedText));
    _setLoading(true, type: LoadingType.chat);
    _errorMessage = null;

    try {
      final Map<String, dynamic> result;

      if (isMultiDocMode) {
        // Query across multiple documents
        result = await _apiService.askMultiQuestion(
          sessionIds: _selectedSessionIds,
          question: trimmedText,
          pinnedMessages: _pinnedMessages,
        );
      } else {
        // Single-document flow (unchanged)
        result = await _apiService.askQuestion(
          sessionId: _sessionId!,
          question: trimmedText,
          pinnedMessages: _pinnedMessages,
        );
      }

      final answer = result['answer'] as String;
      final sources = result['sources'] as List<String>;
      final sourcesText = sources.isNotEmpty ? sources.join(', ') : '';
      final followUps = result['follow_ups'] as List<String>? ?? <String>[];
      final chartData = result['chart_data'] as List<dynamic>?;

      _messages.add(
        ChatMessage(
          role: 'assistant',
          text: answer,
          sources: sourcesText.isNotEmpty ? sourcesText : null,
          followUps: followUps.isNotEmpty ? List<String>.from(followUps) : null,
          chartData: chartData,
        ),
      );
      if (isSummaryRequest) {
        generatedSummaryText = answer;
      }
    } catch (error) {
      _errorMessage = _formatError(error);
    } finally {
      _setLoading(false);
      fetchApiStatus();
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
      _showReadyPopup = true;
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
      _showReadyPopup = true;
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

  @override
  void dispose() {
    _recorder.dispose();
    _tts.stop();
    super.dispose();
  }
}
