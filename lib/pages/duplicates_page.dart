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
  final Set<String> _selected = <String>{};
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
      _selected.clear();
    });

    _subscription = findDuplicatesTask(root).listen((event) {
      switch (event) {
        case TaskProgress():
          _monitor.report(event.progress);

        case TaskDone():
          final groups = (event.value! as List).cast<DuplicateGroup>();
          _monitor.finish();
          if (!mounted) return;
          setState(() {
            _groups = groups;
            _selected.clear();
            // Keep the first copy of every group so a scan never proposes
            // deleting all of them.
            for (final group in groups) {
              _selected.addAll(group.files.skip(1));
            }
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

  int get _selectedBytes {
    var total = 0;
    for (final group in _groups) {
      for (final file in group.files) {
        if (_selected.contains(file)) total += group.size;
      }
    }
    return total;
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
    final showStatus = _busy || _monitor.progress != null;
    final wasted = _groups.fold(0, (sum, group) => sum + group.wastedSize);

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
                  '${t('dupes.wasted')} ${formatSize(wasted)}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Expanded(
            child: _groups.isEmpty
                ? const EmptyState(icon: Icons.content_copy_outlined)
                : ListView.builder(
                    itemCount: _groups.length,
                    itemBuilder: (context, index) => _GroupCard(
                      group: _groups[index],
                      selected: _selected,
                      enabled: !_busy,
                      onToggle: (path, checked) => setState(() {
                        if (checked) {
                          _selected.add(path);
                        } else {
                          _selected.remove(path);
                        }
                      }),
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

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.selected,
    required this.enabled,
    required this.onToggle,
  });

  final DuplicateGroup group;
  final Set<String> selected;
  final bool enabled;
  final void Function(String path, bool checked) onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
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
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.tertiary),
                ),
              ],
            ),
          ),
          for (final file in group.files)
            CheckboxListTile(
              controlAffinity: ListTileControlAffinity.leading,
              value: selected.contains(file),
              onChanged: enabled
                  ? (checked) => onToggle(file, checked ?? false)
                  : null,
              title: Text(file, overflow: TextOverflow.ellipsis),
            ),
        ],
      ),
    );
  }
}
