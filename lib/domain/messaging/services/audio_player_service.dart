import 'dart:async';

enum AudioPlayerState { stopped, playing, paused, completed }

abstract interface class AudioPlayerService {
  /// Start playback of a local decrypted audio file.
  Future<void> play(String localPath);

  /// Pause current playback.
  Future<void> pause();

  /// Resume from paused state.
  Future<void> resume();

  /// Stop playback and reset position.
  Future<void> stop();

  /// Seek to a specific duration in the audio.
  Future<void> seek(Duration position);

  /// Set the playback speed (e.g. 1.0, 1.5, 2.0).
  Future<void> setSpeed(double speed);

  /// The current state of the player.
  AudioPlayerState get state;

  /// Stream of playback state transitions.
  Stream<AudioPlayerState> get stateStream;

  /// Stream of current playback duration position ticks.
  Stream<Duration> get positionStream;

  /// Stream of total audio duration.
  Stream<Duration> get durationStream;

  /// Current playback speed.
  double get playbackSpeed;

  /// Release underlying resources.
  Future<void> dispose();
}
