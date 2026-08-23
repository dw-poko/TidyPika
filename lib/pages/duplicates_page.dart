import 'dart:async';

import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/size_formatter.dart';
import '../core/tasks.dart';
import '../l10n/strings.dart';
import '../widgets/common.dart';
import '../widgets/scan_status.dart';

class DuplicatesPage extends StatefulWidget {
  const DuplicatesPage({super.key});

  @override
  State<DuplicatesPage> createState() => _DuplicatesPageState();
}

class _DuplicatesPageState extends State<DuplicatesPage> {
  final ScanMonitor _monitor = ScanMonitor();
  final TextEditingController _path =
      TextEditingController(text: r'C:\Users');

  List<DuplicateGroup> _groups = const [];

  /// Headers and file lines in one flat list.
  ///
  /// A card per group with its files inside would put the files in a Column,
  /// and a Column builds everything it holds — so one group with a few
  /// thousand copies costs a few thousand widgets on every rebuild, most of
  /// them off screen. Flattened, the list view builds only what is visible
  /// however large a group gets.
  List<_Row> _rows = const [];

  final Set<String> _selected = <String>{};

  /// Kept as it changes rather than recomputed. Reading it used to walk every
  /// file of every group, once per rebuild, which is once per checkbox.
  int _selectedBytes = 0;
  int _wasted = 0;

  bool _recycle = true;
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

  void _scan() {
    final root = _path.text.trim();
    if (root.isEmpty) return;

    _subscription?.cancel();
    _monitor.start();
    setState(() {
      _busy = true;
      _groups = const [];
      _rows = const [];
      _selected.clear();
      _selectedBytes = 0;
      _wasted = 0;
    });

    _subscription = findDuplicatesTask(root).listen((event) {
      switch (event) {
        case TaskProgress():
          _monitor.report(event.progress);

        case TaskDone():
          final groups = (event.value! as List).cast<DuplicateGroup>();
          _monitor.finish();
          if (!mounted) return;

          final rows = <_Row>[];
          final selected = <String>{};
          var selectedBytes = 0;
          var wasted = 0;

          for (final group in groups) {
            rows.add(_GroupHeader(group));
            wasted += group.wastedSize;

            for (var i = 0; i < group.files.length; i++) {
              rows.add(_FileLine(group, group.files[i]));

              // Keep the first copy of every group so a scan never proposes
              // deleting all of them.
              if (i == 0) continue;

              selected.add(group.files[i]);
              selectedBytes += group.size;
            }
          }

          setState(() {
            _groups = groups;
            _rows = rows;
            _selected
              ..clear()
              ..addAll(selected);
            _selectedBytes = selectedBytes;
            _wasted = wasted;
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

  void _toggle(DuplicateGroup group, String path, bool checked) {
    setState(() {
      // add and remove report whether the set actually changed, which is what
      // keeps the running total from drifting on a repeated event.
      if (checked) {
        if (_selected.add(path)) _selectedBytes += group.size;
      } else {
        if (_selected.remove(path)) _selectedBytes -= group.size;
      }
    });
  }

  Future<void> _clean() async {
    final files = _selected.toList(growable: false);
    if (files.isEmpty) return;

    final confirmed = await confirmDelete(
      context,
      count: files.length,
      bytes: _selectedBytes,
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

  @override
  Widget build(BuildContext context) {
    LanguageScope.watch(context);

    final showStatus = _busy || _monitor.progress != null;

    return PageScaffold(
      title: t('dupes.title'),
      subtitle: t('dupes.subtitle'),
      action: FilledButton.icon(
        onPressed: _busy ? null : _scan,
        icon: const Icon(Icons.search, size: 18),
        label: Text(t('dupes.scan')),
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
          if (_groups.isNotEmpty) ...[
            Row(
              children: [
                Text(
                  tf('dupes.groups', [formatCount(_groups.length)]),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                Text(
                  '${t('dupes.wasted')} ${formatSize(_wasted)}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Expanded(
            child: _rows.isEmpty
                ? const EmptyState(icon: Icons.content_copy_outlined)
                : Card(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    child: ListView.builder(
                      itemCount: _rows.length,
                      itemBuilder: (context, index) => switch (_rows[index]) {
                        _GroupHeader(:final group) =>
                          _GroupHeaderTile(group: group),
                        _FileLine(:final group, :final path) =>
                          CheckboxListTile(
                            controlAffinity: ListTileControlAffinity.leading,
                            value: _selected.contains(path),
                            onChanged: _busy
                                ? null
                                : (checked) =>
                                    _toggle(group, path, checked ?? false),
                            title: Text(path, overflow: TextOverflow.ellipsis),
                          ),
                      },
                    ),
                  ),
          ),
          if (_groups.isNotEmpty) ...[
            const SizedBox(height: 16),
            CleanActionBar(
              recycle: _recycle,
              onRecycleChanged:
                  _busy ? null : (value) => setState(() => _recycle = value),
              summary: tf('quick.selected',
                  [formatCount(_selected.length), formatSize(_selectedBytes)]),
              onClean: _busy || _selected.isEmpty ? null : _clean,
            ),
          ],
        ],
      ),
    );
  }
}

/// One line of the flattened list.
sealed class _Row {
  const _Row(this.group);

  final DuplicateGroup group;
}

class _GroupHeader extends _Row {
  const _GroupHeader(super.group);
}

class _FileLine extends _Row {
  const _FileLine(super.group, this.path);

  final String path;
}

/// The band that opens a group: how big each copy is, how many there are, the
/// hash that proves it, and what keeping them all costs.
class _GroupHeaderTile extends StatelessWidget {
  const _GroupHeaderTile({required this.group});

  final DuplicateGroup group;

  @override
  Widget build(BuildContext context) {
    LanguageScope.watch(context);

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Text(
            formatSize(group.size),
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 10),
          Text(
            tf('dupes.copies', [group.files.length]),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              group.hashPrefix.toLowerCase(),
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'Consolas',
                color: scheme.outline,
              ),
            ),
          ),
          Text(
            '${t('dupes.wasted')} ${formatSize(group.wastedSize)}',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.tertiary),
          ),
        ],
      ),
    );
  }
}
