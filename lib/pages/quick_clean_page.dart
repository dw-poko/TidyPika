import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../core/models.dart';
import '../core/size_formatter.dart';
import '../core/tasks.dart';
import '../l10n/strings.dart';
import '../widgets/common.dart';
import '../widgets/scan_status.dart';

class QuickCleanPage extends StatefulWidget {
  const QuickCleanPage({super.key});

  @override
  State<QuickCleanPage> createState() => _QuickCleanPageState();
}

class _QuickCleanPageState extends State<QuickCleanPage> {
  final ScanMonitor _monitor = ScanMonitor();

  List<ScanResult> _results = const [];
  final Set<int> _selected = <int>{};

  /// Rows whose file list is open. Selection and expansion are deliberately
  /// separate: the checkbox picks what gets deleted, the row itself only shows
  /// what is inside.
  final Set<int> _expanded = <int>{};

  /// Sorted copies of each row's files, built on first expand. A cache folder
  /// can hold tens of thousands of entries, so this does not belong in build.
  final Map<int, List<FileEntry>> _byLargest = <int, List<FileEntry>>{};

  bool _recycle = true;
  bool _busy = false;
  StreamSubscription<TaskEvent>? _subscription;

  @override
  void dispose() {
    _subscription?.cancel();
    _monitor.dispose();
    super.dispose();
  }

  void _cancel() {
    _subscription?.cancel();
    _subscription = null;
    _monitor.finish();
    setState(() => _busy = false);
  }

  void _scan() {
    _subscription?.cancel();
    _monitor.start();
    setState(() {
      _busy = true;
      _results = const [];
      _selected.clear();
      _expanded.clear();
      _byLargest.clear();
    });

    _subscription = scanTempFiles().listen((event) {
      switch (event) {
        case TaskProgress():
          _monitor.report(event.progress);

        case TaskDone():
          final all = (event.value! as List).cast<ScanResult>();
          final results =
              all.where((result) => result.files.isNotEmpty).toList();

          _monitor.finish();
          if (!mounted) return;
          setState(() {
            _results = results;
            // Nothing starts ticked. Every target here is safe to clean but
            // not every one is wanted, and a list that arrives pre-selected
            // invites a delete nobody read first.
            _selected.clear();
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

  Future<void> _clean() async {
    final files = <String>[];
    var bytes = 0;

    for (final index in _selected) {
      for (final file in _results[index].files) {
        files.add(file.path);
        bytes += file.size;
      }
    }

    if (files.isEmpty) return;

    final confirmed = await confirmDelete(
      context,
      count: files.length,
      bytes: bytes,
      useRecycleBin: _recycle,
    );
    if (!confirmed || !mounted) return;

    _monitor.start();
    setState(() => _busy = true);

    _subscription = cleanTask(files, _recycle).listen((event) async {
      switch (event) {
        case TaskProgress():
          _monitor.report(event.progress);

        case TaskDone():
          _monitor.finish();
          if (!mounted) return;
          setState(() => _busy = false);
          await showCleanResult(context, event.value! as CleanResult);
          if (mounted) _scan();

        case TaskFailure():
          _monitor.finish();
          if (!mounted) return;
          setState(() => _busy = false);
          await showErrorDialog(context, event.message);
      }
    });
  }

  void _toggleExpanded(int index) {
    setState(() {
      // remove() reports whether the row was open, so this is the toggle.
      if (!_expanded.remove(index)) _expanded.add(index);
    });
  }

  List<FileEntry> _largestFirst(int index) => _byLargest.putIfAbsent(
        index,
        () => [..._results[index].files]
          ..sort((a, b) => b.size.compareTo(a.size)),
      );

  int get _selectedBytes => _selected.fold(
        0,
        (sum, index) => sum + _results[index].totalSize,
      );

  int get _selectedFiles => _selected.fold(
        0,
        (sum, index) => sum + _results[index].files.length,
      );

  @override
  Widget build(BuildContext context) {
    LanguageScope.watch(context);

    final showStatus = _busy || _monitor.progress != null;

    return PageScaffold(
      title: t('quick.title'),
      subtitle: t('quick.subtitle'),
      action: FilledButton.icon(
        onPressed: _busy ? null : _scan,
        icon: const Icon(Icons.search, size: 18),
        label: Text(t('quick.scan')),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showStatus) ...[
            ScanStatusPanel(
              monitor: _monitor,
              onCancel: _busy ? _cancel : null,
            ),
            const SizedBox(height: 16),
          ],
          Expanded(
            child: _results.isEmpty
                ? const EmptyState(icon: Icons.cleaning_services_outlined)
                : Card(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    child: ListView.separated(
                      itemCount: _results.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: _row,
                    ),
                  ),
          ),
          if (_results.isNotEmpty) ...[
            const SizedBox(height: 16),
            CleanActionBar(
              recycle: _recycle,
              onRecycleChanged: _busy
                  ? null
                  : (value) => setState(() => _recycle = value),
              summary: tf('quick.selected',
                  [formatCount(_selectedFiles), formatSize(_selectedBytes)]),
              onClean: _busy || _selected.isEmpty ? null : _clean,
            ),
          ],
        ],
      ),
    );
  }

  /// One scanned target: the checkbox that picks it for deletion, and — when
  /// the row is open — the files it stands for.
  Widget _row(BuildContext context, int index) {
    final theme = Theme.of(context);
    final result = _results[index];
    final expanded = _expanded.contains(index);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          onTap: () => _toggleExpanded(index),
          leading: Checkbox(
            value: _selected.contains(index),
            onChanged: _busy
                ? null
                : (checked) => setState(() {
                      if (checked ?? false) {
                        _selected.add(index);
                      } else {
                        _selected.remove(index);
                      }
                    }),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  t('target.${result.target.id}'),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              RiskChip(risk: result.target.risk),
            ],
          ),
          subtitle: Text(
            t('target.${result.target.id}.desc'),
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatSize(result.totalSize),
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    tf('status.scanned', [formatCount(result.files.length)]),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Tooltip(
                message:
                    expanded ? t('common.hideFiles') : t('common.showFiles'),
                child: AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: Icon(
                    Icons.expand_more,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (expanded) _FileList(files: _largestFirst(index)),
      ],
    );
  }
}

/// The files behind one row, largest first.
///
/// Only the first [_limit] are drawn. The list sits inside the page's own
/// scroll view, so every row it holds is laid out at once; a temp folder with
/// forty thousand entries would stall the frame, and the tail of that list is
/// noise anyway since files are not selected individually here.
class _FileList extends StatelessWidget {
  const _FileList({required this.files});

  final List<FileEntry> files;

  static const int _limit = 200;

  @override
  Widget build(BuildContext context) {
    LanguageScope.watch(context);

    final theme = Theme.of(context);
    final shown = files.length > _limit ? files.sublist(0, _limit) : files;
    final hidden = files.length - shown.length;

    return Container(
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      padding: const EdgeInsets.fromLTRB(56, 10, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final file in shown) _FileRow(file: file),
          if (hidden > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                tf('common.more', [formatCount(hidden)]),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({required this.file});

  final FileEntry file;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Both lines are clipped to keep the row height fixed, so the full path
    // has to be reachable some other way.
    return Tooltip(
      message: file.path,
      waitDuration: const Duration(milliseconds: 500),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                Icons.insert_drive_file_outlined,
                size: 15,
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.basename(file.path),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(
                    p.dirname(file.path),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              formatSize(file.size),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
