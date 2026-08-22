import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/size_formatter.dart';
import '../l10n/strings.dart';

/// Holds the live state of a running scan.
class ScanMonitor extends ChangeNotifier {
  ScanProgress? progress;
  bool running = false;

  void start() {
    progress = null;
    running = true;
    notifyListeners();
  }

  void report(ScanProgress value) {
    progress = value;
    notifyListeners();
  }

  void finish() {
    running = false;
    notifyListeners();
  }
}

/// A single strip: what is happening, how far along, and a way to stop.
class ScanStatusPanel extends StatelessWidget {
  const ScanStatusPanel({required this.monitor, this.onCancel, super.key});

  final ScanMonitor monitor;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
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
