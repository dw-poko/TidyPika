import 'dart:async';

import 'package:flutter/material.dart';

import 'package:path/path.dart' as p;

import '../core/models.dart';
import '../core/paths.dart';
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

  /// The files lying directly in the folder, behind the row that stands for
  /// them.
  List<FileEntry> _looseFiles = const [];

  /// Whether that row is open. Folders are opened by going into them; the
  /// loose files have nowhere to go, so they unfold in place.
  bool _looseOpen = false;

  /// The folder the results belong to. The path field is where a scan is
  /// started from; this is where it actually got to, and the crumbs are read
  /// off it rather than kept as a separate stack — typing a path and clicking
  /// into one then behave the same.
  String _current = '';

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

  void _analyze() => _analyzePath(_path.text.trim());

  void _analyzePath(String root) {
    if (root.isEmpty) return;

    _subscription?.cancel();
    _monitor.start();
    _path.text = root;
    setState(() {
      _busy = true;
      _entries = const [];
      _looseFiles = const [];
      _looseOpen = false;
      _current = root;
    });

    _subscription = analyzeDirectoryTask(root).listen((event) {
      switch (event) {
        case TaskProgress():
          _monitor.report(event.progress);

        case TaskDone():
          final report = event.value! as DirectoryReport;
          _monitor.finish();
          if (!mounted) return;
          setState(() {
            _entries = report.entries;
            _looseFiles = report.files;
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
    LanguageScope.watch(context);

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
          if (_current.isNotEmpty) ...[
            const SizedBox(height: 10),
            _Breadcrumbs(
              path: _current,
              onSelected: _busy ? null : _analyzePath,
            ),
          ],
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
                      itemBuilder: (context, index) {
                        final entry = _entries[index];

                        if (!entry.isLooseFiles) {
                          return _DirectoryRow(
                            entry: entry,
                            total: total,
                            onOpen:
                                _busy ? null : () => _analyzePath(entry.path),
                          );
                        }

                        // The loose files have nowhere to descend to, so the
                        // row unfolds where it stands.
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _DirectoryRow(
                              entry: entry,
                              total: total,
                              expanded: _looseOpen,
                              onOpen: _busy
                                  ? null
                                  : () => setState(
                                        () => _looseOpen = !_looseOpen,
                                      ),
                            ),
                            if (_looseOpen)
                              _LooseFileList(
                                files: _looseFiles,
                                total: entry.fileCount,
                              ),
                          ],
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// The folder path as a row of steps, each one a way back to it.
class _Breadcrumbs extends StatelessWidget {
  const _Breadcrumbs({required this.path, required this.onSelected});

  final String path;
  final ValueChanged<String>? onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final crumbs = pathCrumbs(path);

    return SizedBox(
      height: 32,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: crumbs.length,
        itemBuilder: (context, index) {
          final (label, target) = crumbs[index];
          final last = index == crumbs.length - 1;

          return Row(
            children: [
              if (index > 0)
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: scheme.outline,
                ),
              TextButton(
                onPressed: last ? null : () => onSelected?.call(target),
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  disabledForegroundColor: scheme.onSurface,
                ),
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: last ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DirectoryRow extends StatelessWidget {
  const _DirectoryRow({
    required this.entry,
    required this.total,
    required this.onOpen,
    this.expanded,
  });

  final DirectoryEntry entry;
  final int total;
  final VoidCallback? onOpen;

  /// Null for a folder, which is entered rather than unfolded.
  final bool? expanded;

  @override
  Widget build(BuildContext context) {
    LanguageScope.watch(context);

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final share = total > 0 ? entry.size * 100 / total : 0.0;

    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              switch (expanded) {
                null => Icons.folder_outlined,
                true => Icons.expand_less,
                false => Icons.expand_more,
              },
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.isLooseFiles ? t('analyze.loose') : entry.name,
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
      ),
    );
  }
}

/// The files lying directly in the folder, largest first.
///
/// Only the first pageful travels back from the scan, so anything past it is
/// reported as a count rather than left unmentioned.
class _LooseFileList extends StatelessWidget {
  const _LooseFileList({required this.files, required this.total});

  final List<FileEntry> files;

  /// Every loose file, listed or not.
  final int total;

  @override
  Widget build(BuildContext context) {
    LanguageScope.watch(context);

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hidden = total - files.length;

    return Container(
      width: double.infinity,
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      padding: const EdgeInsets.fromLTRB(46, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final file in files)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Tooltip(
                      message: file.path,
                      waitDuration: const Duration(milliseconds: 500),
                      child: Text(
                        p.basename(file.path),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    formatSize(file.size),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          if (hidden > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                tf('common.more', [formatCount(hidden)]),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}
