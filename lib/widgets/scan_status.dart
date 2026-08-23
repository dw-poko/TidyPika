import 'dart:async';

import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/size_formatter.dart';
import '../l10n/strings.dart';

/// Holds the live state of a running scan.
class ScanMonitor extends ChangeNotifier {
  ScanProgress? progress;
  bool running = false;

  DateTime? _startedAt;
  Duration? _took;
  Timer? _ticker;

  /// Time on the clock: counting while a scan runs, and the total once it
  /// stops. Null before anything has been started.
  Duration? get elapsed {
    if (_took != null) return _took;

    final started = _startedAt;
    return started == null ? null : DateTime.now().difference(started);
  }

  void start() {
    progress = null;
    running = true;
    _startedAt = DateTime.now();
    _took = null;

    // Progress arrives in bursts and a slow directory can go quiet for
    // seconds, so the clock has to move on its own or it reads as stopped.
    _ticker?.cancel();
    _ticker = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => notifyListeners(),
    );

    notifyListeners();
  }

  void report(ScanProgress value) {
    progress = value;
    notifyListeners();
  }

  /// Called when a scan ends, whether it finished or was cancelled. Either way
  /// the time it took is the time it ran.
  void finish() {
    _ticker?.cancel();
    _ticker = null;

    final started = _startedAt;
    if (started != null) _took = DateTime.now().difference(started);

    running = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

/// A single strip: what is happening, how far along, and a way to stop.
class ScanStatusPanel extends StatelessWidget {
  const ScanStatusPanel({required this.monitor, this.onCancel, super.key});

  final ScanMonitor monitor;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    LanguageScope.watch(context);

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListenableBuilder(
      listenable: monitor,
      builder: (context, _) {
        final progress = monitor.progress;
        final stage = progress == null
            ? t('common.working')
            : t('stage.${progress.stage.name}');

        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        stage,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    if (monitor.elapsed case final elapsed?) ...[
                      const SizedBox(width: 12),
                      Text(
                        _elapsedText(elapsed),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                    if (progress != null && progress.processed > 0) ...[
                      const SizedBox(width: 12),
                      Text(
                        tf('status.scanned', [formatCount(progress.processed)]),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                    if (progress != null && !progress.isIndeterminate) ...[
                      const SizedBox(width: 12),
                      Text(
                        '${progress.percent.toStringAsFixed(0)}%',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                    if (monitor.running && onCancel != null) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: onCancel,
                        child: Text(t('common.cancel')),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    value: progress == null || progress.isIndeterminate
                        ? null
                        : progress.percent / 100,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Seconds while a scan is short enough for them to matter, minutes once it
/// is not.
String _elapsedText(Duration elapsed) {
  final (minutes, seconds) = elapsedParts(elapsed);

  return minutes == 0
      ? tf('time.seconds', [seconds.toStringAsFixed(1)])
      : tf('time.minutes', [minutes, seconds.toStringAsFixed(0)]);
}
