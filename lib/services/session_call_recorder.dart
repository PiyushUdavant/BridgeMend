import 'dart:developer' as developer;
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// Records local microphone audio during a voice session for post-call STT.
class SessionCallRecorder {
  final AudioRecorder _recorder = AudioRecorder();
  String? _path;
  bool _isRecording = false;

  bool get isRecording => _isRecording;

  Future<bool> start() async {
    if (_isRecording) return true;

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        developer.log('SessionCallRecorder: microphone permission denied');
        return false;
      }
    }

    final dir = await getTemporaryDirectory();
    _path =
        '${dir.path}/mend_call_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: _path!,
    );

    _isRecording = true;
    developer.log('SessionCallRecorder: started $_path');
    return true;
  }

  /// Stops recording and returns the audio file if it exists and has content.
  Future<File?> stop() async {
    if (!_isRecording) {
      return _existingFile();
    }

    final stoppedPath = await _recorder.stop();
    _isRecording = false;

    final path = stoppedPath ?? _path;
    _path = null;

    if (path == null) return null;

    final file = File(path);
    if (!await file.exists()) return null;

    final length = await file.length();
    if (length < 1024) {
      developer.log(
        'SessionCallRecorder: file too small ($length bytes), skipping upload',
      );
      try {
        await file.delete();
      } catch (_) {}
      return null;
    }

    developer.log('SessionCallRecorder: saved ${file.path} ($length bytes)');
    return file;
  }

  Future<File?> _existingFile() async {
    if (_path == null) return null;
    final file = File(_path!);
    if (await file.exists()) return file;
    return null;
  }

  Future<void> dispose() async {
    if (_isRecording) {
      await _recorder.stop();
      _isRecording = false;
    }
    await _recorder.dispose();
  }
}
