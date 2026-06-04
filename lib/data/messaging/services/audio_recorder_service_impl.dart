import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:memovault/domain/messaging/services/audio_recorder_service.dart';

class AudioRecorderServiceImpl implements AudioRecorderService {
  final _recorder = AudioRecorder();

  bool _isRecording = false;
  DateTime? _startTime;
  final List<double> _amplitudes = [];

  final _amplitudeController = StreamController<double>.broadcast();
  StreamSubscription<Amplitude>? _ampSubscription;

  @override
  bool get isRecording => _isRecording;

  @override
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  @override
  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  @override
  Future<void> start() async {
    if (_isRecording) return;

    final hasPerm = await hasPermission();
    if (!hasPerm) {
      throw StateError('Microphone recording permission not granted.');
    }

    final tempDir = await getTemporaryDirectory();
    final fileName = 'rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
    final filePath = '${tempDir.path}/$fileName';

    _amplitudes.clear();
    _startTime = DateTime.now();

    await _ampSubscription?.cancel();
    _ampSubscription = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 100))
        .listen((amp) {
      // Normalize dBFS (typically -100 to 0) to [0, 100]
      final db = amp.current;
      double normalized = 0.0;
      if (db.isFinite && !db.isNaN) {
        normalized = (db + 100.0).clamp(0.0, 100.0);
      }
      _amplitudes.add(normalized);
      _amplitudeController.add(normalized);
    });

    const config = RecordConfig(
      encoder: AudioEncoder.aacLc,
      bitRate: 128000,
      sampleRate: 44100,
    );

    await _recorder.start(config, path: filePath);
    _isRecording = true;
  }

  @override
  Future<RecordingResult?> stop() async {
    if (!_isRecording) return null;

    final path = await _recorder.stop();
    _isRecording = false;

    await _ampSubscription?.cancel();
    _ampSubscription = null;

    if (path == null) return null;

    final durationMs = _startTime != null
        ? DateTime.now().difference(_startTime!).inMilliseconds
        : 0;
    final durationSec =
        (durationMs / 1000.0).round().clamp(1, double.maxFinite.toInt());

    // Downsample amplitude list to exactly 30 points
    final downsampled = _downsampleAmplitudes(_amplitudes, 30);
    final waveformStr = downsampled.join(',');

    return RecordingResult(
      path: path,
      durationSeconds: durationSec,
      waveform: waveformStr,
    );
  }

  List<int> _downsampleAmplitudes(List<double> samples, int targetPoints) {
    if (samples.isEmpty) {
      return List.filled(targetPoints, 0);
    }
    if (samples.length <= targetPoints) {
      final list = samples.map((s) => s.round().clamp(0, 100)).toList();
      while (list.length < targetPoints) {
        list.add(0);
      }
      return list;
    }

    final result = <int>[];
    final double bucketSize = samples.length / targetPoints;
    for (int i = 0; i < targetPoints; i++) {
      final int start = (i * bucketSize).floor();
      final int end = ((i + 1) * bucketSize).floor().clamp(0, samples.length);

      if (start >= end) {
        result.add(
            samples[start.clamp(0, samples.length - 1)].round().clamp(0, 100));
        continue;
      }

      double sum = 0.0;
      for (int j = start; j < end; j++) {
        sum += samples[j];
      }
      result.add((sum / (end - start)).round().clamp(0, 100));
    }
    return result;
  }

  @override
  Future<void> dispose() async {
    await _ampSubscription?.cancel();
    await _amplitudeController.close();
    await _recorder.dispose();
  }
}
