import 'dart:async';

import 'package:flutter/material.dart';

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
            _selected
              ..clear()
              ..addAll(List.generate(results.length, (i) => i));
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
                      itemBuilder: (context, index) {
                        final result = _results[index];
                        return CheckboxListTile(
                          controlAffinity: ListTileControlAffinity.leading,
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
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  result.target.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 10),
                              RiskChip(risk: result.target.risk),
                            ],
                          ),
                          subtitle: Text(
                            result.target.description,
                            overflow: TextOverflow.ellipsis,
                          ),
                          secondary: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                formatSize(result.totalSize),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                tf('status.scanned',
                                    [formatCount(result.files.length)]),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
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
}
