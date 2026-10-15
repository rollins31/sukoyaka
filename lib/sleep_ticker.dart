import 'dart:async';

import 'package:flutter/widgets.dart';

/// Rebuilds [builder] once a second while [active], so a live sleep
/// session's elapsed time stays current without rebuilding the whole app.
class SleepTicker extends StatefulWidget {
  const SleepTicker({super.key, required this.active, required this.builder});

  final bool active;
  final WidgetBuilder builder;

  @override
  State<SleepTicker> createState() => _SleepTickerState();
}

class _SleepTickerState extends State<SleepTicker> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(SleepTicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.active) {
      _timer ??= Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
