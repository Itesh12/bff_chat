import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:memovault/domain/messaging/services/audio_player_service.dart';
import 'package:memovault/domain/messaging/services/audio_recorder_service.dart';

class FakeAudioPlayerService implements AudioPlayerService {
  AudioPlayerState _state = AudioPlayerState.stopped;
  double _speed = 1.0;
  
  final _stateController = StreamController<AudioPlayerState>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration>.broadcast();

  @override
  AudioPlayerState get state => _state;

  @override
  Stream<AudioPlayerState> get stateStream => _stateController.stream;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<Duration> get durationStream => _durationController.stream;

  @override
  double get playbackSpeed => _speed;

  @override
  Future<void> play(String localPath) async {
    _state = AudioPlayerState.playing;
    _stateController.add(_state);
    _durationController.add(const Duration(seconds: 10));
    _positionController.add(Duration.zero);
  }

  @override
  Future<void> pause() async {
    _state = AudioPlayerState.paused;
    _stateController.add(_state);
  }

  @override
  Future<void> resume() async {
    _state = AudioPlayerState.playing;
    _stateController.add(_state);
  }

  @override
  Future<void> stop() async {
    _state = AudioPlayerState.stopped;
    _stateController.add(_state);
    _positionController.add(Duration.zero);
  }

  @override
  Future<void> seek(Duration position) async {
    _positionController.add(position);
  }

  @override
  Future<void> setSpeed(double speed) async {
    _speed = speed;
  }

  @override
  Future<void> dispose() async {
    await _stateController.close();
    await _positionController.close();
    await _durationController.close();
  }
}

class FakeAudioRecorderService implements AudioRecorderService {
  bool _isRecording = false;
  final _ampController = StreamController<double>.broadcast();

  @override
  bool get isRecording => _isRecording;

  @override
  Stream<double> get amplitudeStream => _ampController.stream;

  @override
  Future<bool> hasPermission() async {
    return true;
  }

  @override
  Future<void> start() async {
    _isRecording = true;
    _ampController.add(20.0);
  }

  @override
  Future<RecordingResult?> stop() async {
    _isRecording = false;
    return const RecordingResult(
      path: '/mock/path/audio.m4a',
      durationSeconds: 5,
      waveform: '10,20,30,40,50,40,30,20,10',
    );
  }

  @override
  Future<void> dispose() async {
    await _ampController.close();
  }
}

void main() {
  group('Audio Service Interface and State Machine Tests', () {
    test('FakeAudioPlayerService transitions states and reports speed correctly', () async {
      final player = FakeAudioPlayerService();

      expect(player.state, AudioPlayerState.stopped);
      expect(player.playbackSpeed, 1.0);

      // Verify play transitions state
      final stateExpectations = [
        AudioPlayerState.playing,
        AudioPlayerState.paused,
        AudioPlayerState.playing,
        AudioPlayerState.stopped,
      ];
      int stateIndex = 0;
      
      final subscription = player.stateStream.listen((state) {
        expect(state, stateExpectations[stateIndex++]);
      });

      await player.play('/mock/local/voice.m4a');
      expect(player.state, AudioPlayerState.playing);

      await player.pause();
      expect(player.state, AudioPlayerState.paused);

      await player.resume();
      expect(player.state, AudioPlayerState.playing);

      await player.setSpeed(1.5);
      expect(player.playbackSpeed, 1.5);

      await player.stop();
      expect(player.state, AudioPlayerState.stopped);

      await subscription.cancel();
      await player.dispose();
    });

    test('FakeAudioRecorderService triggers permissions, records, and yields recording results', () async {
      final recorder = FakeAudioRecorderService();

      expect(recorder.isRecording, false);

      final hasPermission = await recorder.hasPermission();
      expect(hasPermission, true);

      final ampCompleter = Completer<double>();
      final ampSub = recorder.amplitudeStream.listen((amp) {
        if (!ampCompleter.isCompleted) {
          ampCompleter.complete(amp);
        }
      });

      await recorder.start();
      expect(recorder.isRecording, true);

      final ampVal = await ampCompleter.future;
      expect(ampVal, 20.0);

      final result = await recorder.stop();
      expect(recorder.isRecording, false);
      expect(result, isNotNull);
      expect(result!.durationSeconds, 5);
      expect(result.waveform, '10,20,30,40,50,40,30,20,10');

      await ampSub.cancel();
      await recorder.dispose();
    });
  });
}
