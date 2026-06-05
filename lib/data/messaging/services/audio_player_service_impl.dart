import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:memovault/domain/messaging/services/audio_player_service.dart';

class AudioPlayerServiceImpl implements AudioPlayerService {
  final _player = AudioPlayer();
  double _speed = 1.0;

  final _stateController = StreamController<AudioPlayerState>.broadcast();
  StreamSubscription<PlayerState>? _stateSub;

  AudioPlayerServiceImpl() {
    _stateSub = _player.onPlayerStateChanged.listen((state) {
      _stateController.add(_mapState(state));
    });
  }

  AudioPlayerState _mapState(PlayerState state) {
    switch (state) {
      case PlayerState.playing:
        return AudioPlayerState.playing;
      case PlayerState.paused:
        return AudioPlayerState.paused;
      case PlayerState.stopped:
        return AudioPlayerState.stopped;
      case PlayerState.completed:
        return AudioPlayerState.completed;
      default:
        return AudioPlayerState.stopped;
    }
  }

  @override
  AudioPlayerState get state => _mapState(_player.state);

  @override
  Stream<AudioPlayerState> get stateStream => _stateController.stream;

  @override
  Stream<Duration> get positionStream => _player.onPositionChanged;

  @override
  Stream<Duration> get durationStream => _player.onDurationChanged;

  @override
  double get playbackSpeed => _speed;

  @override
  Future<void> play(String localPath) async {
    await _player.play(DeviceFileSource(localPath));
    // Apply speed preference when playing new audio
    if (_speed != 1.0) {
      await setSpeed(_speed);
    }
  }

  @override
  Future<void> pause() async {
    await _player.pause();
  }

  @override
  Future<void> resume() async {
    await _player.resume();
  }

  @override
  Future<void> stop() async {
    await _player.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  @override
  Future<void> setSpeed(double speed) async {
    _speed = speed;
    await _player.setPlaybackRate(speed);
  }

  @override
  Future<void> dispose() async {
    await _stateSub?.cancel();
    await _stateController.close();
    await _player.dispose();
  }
}
