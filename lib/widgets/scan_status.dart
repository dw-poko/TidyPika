import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/size_formatter.dart';
import '../l10n/strings.dart';

/// Holds the live state of a running scan: the latest tick plus a bounded log
/// of the targets and directories that have been walked.
class ScanMonitor extends ChangeNotifier {
  static const int _maxLogLines = 300;

  ScanProgress? progress;
  bool running = false;
  final List<String> log = [];

  String _lastDetail = '';

  void start() {
    log.clear();
    _lastDetail = '';
    progress = null;
    running = true;
    notifyListeners();
  }

  void report(ScanProgress value) {
    progress = value;

    // One line per new target or directory: a line per file would bury the log
    // and pin the UI thread.
    if (value.detail.isNotEmpty && value.detail != _lastDetail) {
      _lastDetail = value.detail;
      log.add(value.detail);
      if (log.length > _maxLogLines) log.removeAt(0);
    }

    notifyListeners();
  }

  void finish() {
    running = false;
    notifyListeners();
  }
}

class ScanStatusPanel extends StatefulWidget {
  const ScanStatusPanel({required this.monitor, this.onCancel, super.key});

  final ScanMonitor monitor;
  final VoidCallback? onCancel;

  @override
  State<ScanStatusPanel> createState() => _ScanStatusPanelState();
}

class _ScanStatusPanelState extends State<ScanStatusPanel> {
  final ScrollController _controller = ScrollController();
  int _lastLogLength = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_controller.hasClients) {
        _controller.jumpTo(_controller.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListenableBuilder(
      listenable: widget.monitor,
      builder: (context, _) {
        final monitor = widget.monitor;
        final progress = monitor.progress;

        if (monitor.log.length != _lastLogLength) {
          _lastLogLength = monitor.log.length;
          _scrollToLatest();
        }

        final stage = progress == null
            ? t('common.working')
            : t('stage.${progress.stage.name}');
        final detail = progress?.detail ?? '';

        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        detail.isEmpty ? stage : '$stage · $detail',
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
                    if (monitor.running && widget.onCancel != null) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: widget.onCancel,
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
                const SizedBox(height: 12),
                Container(
                  height: 132,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: monitor.log.isEmpty
                      ? const SizedBox.shrink()
                      : ListView.builder(
                          controller: _controller,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          itemCount: monitor.log.length,
                          itemExtent: 18,
                          itemBuilder: (context, index) => Text(
                            monitor.log[index],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: 'Consolas',
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
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
