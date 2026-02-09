import 'dart:io';
import 'package:path_provider/path_provider.dart';

class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;
  LoggerService._internal();

  File? _logFile;
  String? _logFilePath;
  bool _initialized = false;

  static const String _logFileName = 'app_debug.log';

  Future<void> init() async {
    if (_initialized && _logFile != null && _logFile!.existsSync()) return;

    try {
      final directory = await getApplicationDocumentsDirectory();
      _logFilePath = '${directory.path}/$_logFileName';
      _logFile = File(_logFilePath!);

      // Create directory if it doesn't exist
      if (!directory.existsSync()) {
        await directory.create(recursive: true);
      }

      // Create the file if it doesn't exist
      if (!_logFile!.existsSync()) {
        await _logFile!.create(recursive: true);
      }

      _initialized = true;
      log('Logger initialized. Log file: $_logFilePath', LogLevel.info);
    } catch (e) {
      print('Failed to initialize logger: $e');
      _initialized = false;
    }
  }

  void log(String message, LogLevel level) {
    if (!_initialized || _logFile == null) {
      print('Logger not initialized. Message: $message');
      return;
    }

    final timestamp = DateTime.now().toIso8601String();
    final logEntry = '[$timestamp] [${level.name.toUpperCase()}] $message\n';

    try {
      _logFile!.writeAsStringSync(logEntry, mode: FileMode.append);
      // Also print to console for debugging during development
      print('[${level.name.toUpperCase()}] $message');
    } catch (e) {
      print('Failed to write to log file: $e');
      print('[${level.name.toUpperCase()}] $message'); // Fallback to console
    }
  }

  void debug(String message) => log(message, LogLevel.debug);
  void info(String message) => log(message, LogLevel.info);
  void warning(String message) => log(message, LogLevel.warning);
  void error(String message) => log(message, LogLevel.error);

  Future<String> getLogContent() async {
    // Try to initialize if not ready
    if (!_initialized || _logFile == null) {
      await init();
    }

    if (!_initialized || _logFile == null || !_logFile!.existsSync()) {
      return 'Logger not initialized or log file does not exist. Path: ${_logFilePath ?? "unknown"}';
    }
    try {
      return await _logFile!.readAsString();
    } catch (e) {
      return 'Error reading log file: $e';
    }
  }

  Future<void> clearLogs() async {
    if (_initialized && _logFile != null) {
      try {
        await _logFile!.writeAsString('');
      } catch (e) {
        print('Failed to clear logs: $e');
      }
    }
  }

  Future<String> getLogFilePath() async {
    if (!_initialized || _logFilePath == null) {
      final directory = await getApplicationDocumentsDirectory();
      return '${directory.path}/$_logFileName';
    }
    return _logFilePath!;
  }

  Future<int> getLogFileSize() async {
    if (!_initialized || _logFile == null || !_logFile!.existsSync()) {
      return 0;
    }
    try {
      return await _logFile!.length();
    } catch (e) {
      return 0;
    }
  }
}

enum LogLevel { debug, info, warning, error }

// Global instance for easy access
final logger = LoggerService();
