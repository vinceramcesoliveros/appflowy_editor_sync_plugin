import 'package:uuid/uuid.dart';

/// This is used to track latest local updates
/// UpdateClock are used to track the latest local updates
/// It has two functions:
/// - getLastestClock: returns the latest clock (uuid)
/// - incrementClock: increments the clock, generates a new uuid and returns it
/// - inInitialState: returns true if the clock is in initial state - no increments called yed

class UpdateClock {
  UpdateClock() {
    _clock = uuid.v4();
    _isInitialState = true;
  }

  late String _clock;
  late bool _isInitialState;
  final uuid = const Uuid();

  String getLatestClock() {
    return _clock;
  }

  String incrementClock() {
    _clock = uuid.v4();
    _isInitialState = false;
    return _clock;
  }

  bool isInitialState() {
    return _isInitialState;
  }
}
