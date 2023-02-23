import 'dart:async';

import 'package:flutter/material.dart';

class CountdownTimer extends StatefulWidget {
  final int duration;
  final VoidCallback onFinish;

  const CountdownTimer(
      {super.key, required this.duration, required this.onFinish});

  @override
  State<CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<CountdownTimer> {
  late Timer _timer;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.duration;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 0) {
        timer.cancel();
        widget.onFinish();
      } else {
        setState(() {
          _remainingSeconds--;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Text('$_remainingSeconds seconds left');
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
}
