import 'dart:async';

import 'package:flutter/widgets.dart';

/// A 1-second game clock mixed into a game's [State]. Pauses automatically when
/// the app is backgrounded (and resumes if it was running), satisfying the
/// "pause loops when backgrounded" performance rule. Remember to call
/// [initClock] in `initState` and [disposeClock] in `dispose`.
mixin GameClock<T extends StatefulWidget> on State<T>, WidgetsBindingObserver {
  Timer? _timer;
  int _elapsed = 0;
  bool _running = false;
  bool _wasRunningOnPause = false;

  int get elapsedSeconds => _elapsed;
  bool get clockRunning => _running;

  void initClock() => WidgetsBinding.instance.addObserver(this);

  void startClock() {
    if (_running) return;
    _running = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsed++;
      if (mounted) setState(() {});
    });
  }

  void stopClock() {
    _running = false;
    _timer?.cancel();
    _timer = null;
  }

  void resetClock() {
    stopClock();
    _elapsed = 0;
  }

  void disposeClock() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _wasRunningOnPause = _running;
      stopClock();
    } else if (_wasRunningOnPause) {
      _wasRunningOnPause = false;
      startClock();
    }
    super.didChangeAppLifecycleState(state);
  }
}
