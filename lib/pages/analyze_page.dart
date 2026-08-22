import 'dart:async';

import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/size_formatter.dart';
import '../core/tasks.dart';
import '../l10n/strings.dart';
import '../widgets/common.dart';
import '../widgets/scan_status.dart';

class AnalyzePage extends StatefulWidget {
  const AnalyzePage({super.key});

  @override
  State<AnalyzePage> createState() => _AnalyzePageState();
}

class _AnalyzePageState extends State<AnalyzePage> {
  final ScanMonitor _monitor = ScanMonitor();
  final TextEditingController _path = TextEditingController(text: r'C:\');

  List<DirectoryEntry> _entries = const [];
  bool _busy = false;
  StreamSubscription<TaskEvent>? _subscription;

  @override
  void dispose() {
    _subscription?.cancel();
    _monitor.dispose();
    _path.dispose();
    super.dispose();
  }

  void _cancel() {
    _subscription?.cancel();
    _subscription = null;
    _monitor.finish();
    setState(() => _busy = false);
  }

  void _analyze() {
    final root = _path.text.trim();
    if (root.isEmpty) return;

    _subscription?.cancel();
    _monitor.start();
    setState(() {
      _busy = true;
      _entries = const [];
    });

    _subscription = analyzeDirectoryTask(root).listen((event) {
      switch (event) {
        case TaskProgress():
          _monitor.report(event.progress);

        case TaskDone():
          final entries = (event.value! as List).cast<DirectoryEntry>();
          _monitor.finish();
          if (!mounted) return;
          setState(() {
            _entries = entries;
            _busy = false;
          });

        case TaskFailure():
          _monitor.finish();
          if (!mounted) return;
          setState(() => _busy = false);
          showErrorDialog(context, event.message);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showStatus = _busy || _monitor.progress != null;
    final total = _entries.fold(0, (sum, entry) => sum + entry.size);

    return PageScaffold(
      title: t('analyze.title'),
      subtitle: t('analyze.subtitle'),
      action: FilledButton.icon(
        onPressed: _busy ? null : _analyze,
        icon: const Icon(Icons.donut_small_outlined, size: 18),
        label: Text(t('analyze.run')),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PathField(controller: _path, enabled: !_busy),
          const SizedBox(height: 16),
          if (showStatus) ...[
            ScanStatusPanel(
              monitor: _monitor,
              onCancel: _busy ? _cancel : null,
            ),
            const SizedBox(height: 16),
          ],
          if (_entries.isNotEmpty) ...[
            Row(
              children: [
                Text(
                  tf('analyze.folders', [formatCount(_entries.length)]),
                  style: theme.textTheme.titleSmall,
                ),
                const Spacer(),
                Text(formatSize(total), style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Expanded(
            child: _entries.isEmpty
                ? const EmptyState(icon: Icons.donut_small_outlined)
                : Card(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    child: ListView.separated(
                      itemCount: _entries.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) => _DirectoryRow(
                        entry: _entries[index],
                        total: total,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _DirectoryRow extends StatelessWidget {
  const _DirectoryRow({required this.entry, required this.total});

  final DirectoryEntry entry;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final share = total > 0 ? entry.size * 100 / total : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w500),
                ),
                Text(
                  tf('status.scanned', [formatCount(entry.fileCount)]),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 90,
            child: Text(
              formatSize(entry.size),
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: share / 100,
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 42,
                  child: Text(
                    '${share.toStringAsFixed(1)}%',
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
