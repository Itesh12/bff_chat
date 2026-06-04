class RecordingResult {
  final String path;
  final int durationSeconds;
  final String waveform; // Comma-separated scaling points (e.g. "10,15,45...")

  const RecordingResult({
    required this.path,
    required this.durationSeconds,
    required this.waveform,
  });
}

abstract interface class AudioRecorderService {
  /// Request microphone record permissions.
  Future<bool> hasPermission();

  /// Starts audio recording.
  Future<void> start();

  /// Stops recording and returns file path, duration, and waveform data.
  Future<RecordingResult?> stop();

  /// Reactive status flag.
  bool get isRecording;

  /// Exposes live volume amplitude stream for UI visualizers.
  Stream<double> get amplitudeStream;

  /// Disposes resources.
  Future<void> dispose();
}
