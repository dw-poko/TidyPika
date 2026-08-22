import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../core/models.dart';
import '../core/size_formatter.dart';
import '../core/tasks.dart';
import '../l10n/strings.dart';
import '../widgets/common.dart';
import '../widgets/scan_status.dart';

class LargeFilesPage extends StatefulWidget {
  const LargeFilesPage({super.key});

  @override
  State<LargeFilesPage> createState() => _LargeFilesPageState();
}

class _LargeFilesPageState extends State<LargeFilesPage> {
  final ScanMonitor _monitor = ScanMonitor();
  final TextEditingController _path = TextEditingController(text: r'C:\');

  List<FileEntry> _results = const [];
  final Set<String> _selected = <String>{};
  int _minSizeMb = 50;
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
      _results = const [];
      _selected.clear();
    });

    _subscription =
        scanLargeFilesTask(root, _minSizeMb * 1024 * 1024).listen((event) {
      switch (event) {
        case TaskProgress():
          _monitor.report(event.progress);

        case TaskDone():
          final results = (event.value! as List).cast<FileEntry>();
          _monitor.finish();
          if (!mounted) return;
          setState(() {
            _results = results;
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
    final files = _results
        .where((entry) => _selected.contains(entry.path))
        .toList(growable: false);
    if (files.isEmpty) return;

    final bytes = files.fold(0, (sum, entry) => sum + entry.size);

    final confirmed = await confirmDelete(
      context,
      count: files.length,
      bytes: bytes,
      useRecycleBin: _recycle,
    );
    if (!confirmed || !mounted) return;

    _monitor.start();
    setState(() => _busy = true);

    _subscription = cleanTask(
      files.map((entry) => entry.path).toList(),
      _recycle,
    ).listen((event) async {
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
    final showStatus = _busy || _monitor.log.isNotEmpty;
    final selectedBytes = _results
        .where((entry) => _selected.contains(entry.path))
        .fold(0, (sum, entry) => sum + entry.size);

    return PageScaffold(
      title: t('large.title'),
      subtitle: t('large.subtitle'),
      action: FilledButton.icon(
        onPressed: _busy ? null : _scan,
        icon: const Icon(Icons.search, size: 18),
        label: Text(t('large.scan')),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: PathField(controller: _path, enabled: !_busy)),
              const SizedBox(width: 12),
              DropdownMenu<int>(
                initialSelection: _minSizeMb,
                enabled: !_busy,
                width: 180,
                label: Text(t('large.minSize')),
                onSelected: (value) {
                  if (value != null) setState(() => _minSizeMb = value);
                },
                dropdownMenuEntries: const [
                  DropdownMenuEntry(value: 10, label: '10 MB +'),
                  DropdownMenuEntry(value: 50, label: '50 MB +'),
                  DropdownMenuEntry(value: 100, label: '100 MB +'),
                  DropdownMenuEntry(value: 500, label: '500 MB +'),
                  DropdownMenuEntry(value: 1024, label: '1 GB +'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (showStatus) ...[
            ScanStatusPanel(
              monitor: _monitor,
              onCancel: _busy ? _cancel : null,
            ),
            const SizedBox(height: 16),
          ],
          Expanded(
            child: _results.isEmpty
                ? const EmptyState(icon: Icons.folder_open_outlined)
                : Card(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    child: ListView.separated(
                      itemCount: _results.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final entry = _results[index];
                        return CheckboxListTile(
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: _selected.contains(entry.path),
                          onChanged: _busy
                              ? null
                              : (checked) => setState(() {
                                    if (checked ?? false) {
                                      _selected.add(entry.path);
                                    } else {
                                      _selected.remove(entry.path);
                                    }
                                  }),
                          title: Text(
                            p.basename(entry.path),
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            p.dirname(entry.path),
                            overflow: TextOverflow.ellipsis,
                          ),
                          secondary: Text(
                            formatSize(entry.size),
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        );
                      },
                    ),
                  ),
          ),
          if (_results.isNotEmpty) ...[
            const SizedBox(height: 16),
            CleanActionBar(
              recycle: _recycle,
              onRecycleChanged:
                  _busy ? null : (value) => setState(() => _recycle = value),
              summary: tf('quick.selected',
                  [formatCount(_selected.length), formatSize(selectedBytes)]),
              onClean: _busy || _selected.isEmpty ? null : _clean,
            ),
          ],
        ],
      ),
    );
  }
}
