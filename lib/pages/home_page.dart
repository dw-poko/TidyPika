import 'package:flutter/material.dart';

import '../core/disk_scanner.dart';
import '../core/hibernation.dart';
import '../core/models.dart';
import '../core/size_formatter.dart';
import '../core/win32.dart';
import '../l10n/strings.dart';
import '../widgets/common.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<DiskInfo> _disks = const [];
  HibernationInfo? _hibernation;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    List<DiskInfo> disks;
    try {
      disks = getDisks();
    } catch (_) {
      disks = const [];
    }

    HibernationInfo? hibernation;
    try {
      hibernation = readHibernation();
    } catch (_) {
      hibernation = null;
    }

    setState(() {
      _disks = disks;
      _hibernation = hibernation;
    });
  }

  Future<void> _setHibernation(bool enabled) async {
    final info = _hibernation;
    if (info == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _HibernationConfirm(info: info, enabling: enabled),
    );
    if (confirmed != true || !mounted) return;

    // powercfg refuses without elevation, so ask before running it into a
    // failure the user can do nothing about from here.
    if (!isElevated()) {
      await showElevationNotice(context, messageKey: 'hiber.needsAdmin');
      return;
    }

    setState(() => _busy = true);
    final result = await setHibernation(enabled: enabled);
    if (!mounted) return;
    setState(() => _busy = false);

    if (result.exitCode != 0) {
      // powercfg says why in the language Windows is installed in, which is
      // more use here than anything this app could guess.
      final output = '${result.stdout}\n${result.stderr}'.trim();
      await showErrorDialog(
        context,
        output.isEmpty
            ? '${t('hiber.failed')}\n\nexit code ${result.exitCode}'
            : '${t('hiber.failed')}\n\n$output',
      );
      if (!mounted) return;
    }

    _load();
  }

  @override
  Widget build(BuildContext context) {
    LanguageScope.watch(context);

    return PageScaffold(
      title: t('home.title'),
      subtitle: t('home.subtitle'),
      action: OutlinedButton.icon(
        onPressed: _load,
        icon: const Icon(Icons.refresh, size: 18),
        label: Text(t('home.refresh')),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_hibernation != null) ...[
            _HibernationCard(
              info: _hibernation!,
              busy: _busy,
              onChanged: _busy ? null : _setHibernation,
            ),
            const SizedBox(height: 16),
          ],
          Expanded(
            child: _disks.isEmpty
                ? const EmptyState(icon: Icons.storage_outlined)
                : GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 360,
                      mainAxisExtent: 152,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: _disks.length,
                    itemBuilder: (context, index) =>
                        _DiskCard(disk: _disks[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _DiskCard extends StatelessWidget {
  const _DiskCard({required this.disk});

  final DiskInfo disk;

  @override
  Widget build(BuildContext context) {
    LanguageScope.watch(context);

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final percent = disk.usedPercent;

    final barColor = percent < 60
        ? scheme.primary
        : percent < 85
            ? scheme.tertiary
            : scheme.error;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.storage_outlined,
                    size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  disk.root,
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  formatSize(disk.free),
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 6),
                Text(
                  t('home.free'),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percent / 100,
                minHeight: 6,
                color: barColor,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    tf('home.usage',
                        [formatSize(disk.used), formatSize(disk.total)]),
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
                Text(
                  '${percent.toStringAsFixed(1)}%',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// What the hibernation file is costing, and the switch that decides whether
/// it exists at all.
class _HibernationCard extends StatelessWidget {
  const _HibernationCard({
    required this.info,
    required this.busy,
    required this.onChanged,
  });

  final HibernationInfo info;
  final bool busy;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    LanguageScope.watch(context);

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
        child: Row(
          children: [
            Icon(
              Icons.bedtime_outlined,
              size: 20,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('hiber.title'), style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    info.enabled ? info.path : t('hiber.none'),
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            // Size and state are read separately, so an enabled feature whose
            // file could not be measured shows as on with no figure rather
            // than as off.
            if (info.size != null) ...[
              const SizedBox(width: 12),
              Text(
                formatSize(info.size!),
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(width: 16),
            if (busy)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Switch(value: info.enabled, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _HibernationConfirm extends StatelessWidget {
  const _HibernationConfirm({required this.info, required this.enabling});

  final HibernationInfo info;
  final bool enabling;

  String _body() {
    if (enabling) return t('hiber.bodyOn');

    final size = info.size;
    return size == null
        ? tf('hiber.bodyOffUnknown', [info.path])
        : tf('hiber.bodyOff', [info.path, formatSize(size)]);
  }

  @override
  Widget build(BuildContext context) {
    LanguageScope.watch(context);

    return AlertDialog(
      icon: const Icon(Icons.bedtime_outlined),
      title: Text(t(enabling ? 'hiber.confirmOn' : 'hiber.confirmOff')),
      content: SizedBox(
        width: 440,
        child: Text(_body()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(t('common.cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(t(enabling ? 'hiber.enable' : 'hiber.disable')),
        ),
      ],
    );
  }
}
