import 'dart:async';

import 'package:flutter/material.dart';

import '../app.dart';
import '../core/disk_scanner.dart';
import '../core/hibernation.dart';
import '../core/history.dart';
import '../core/models.dart';
import '../core/pagefile.dart';
import '../core/size_formatter.dart';
import '../core/storage_events.dart';
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

  /// Bytes and item count, or null when the shell would not say.
  (int, int)? _recycleBin;

  /// Hibernation plus paging file: what Windows has set aside on its own
  /// account. Null while neither could be read.
  int? _reserved;

  History _history = const History(samples: [], lastClean: null);
  bool _emptying = false;
  StreamSubscription<void>? _changes;

  @override
  void initState() {
    super.initState();
    _load();

    // The dashboard is kept alive in an IndexedStack, so without this it goes
    // on showing the free space it read at startup however much has been
    // cleaned since.
    _changes = storageChanged.listen((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _changes?.cancel();
    super.dispose();
  }

  void _load() {
    List<DiskInfo> disks;
    try {
      disks = getDisks();
    } catch (_) {
      disks = const [];
    }

    // A sample a day on the system drive is what makes a week comparable.
    final system = systemDriveRoot();
    for (final disk in disks) {
      if (disk.root != system) continue;

      recordFreeSpace(disk.free);
      break;
    }

    // Read before the setState rather than inside it: these touch the shell,
    // the registry and a file, and none of that belongs in a callback whose
    // job is to hand over finished values.
    final recycleBin = readRecycleBin();
    final reserved = _reservedBytes();
    final history = readHistory();

    setState(() {
      _disks = disks;
      _recycleBin = recycleBin;
      _reserved = reserved;
      _history = history;
    });
  }

  /// Only counts what could actually be read. A machine that will not report
  /// its paging file should show the hibernation file alone rather than a
  /// total quietly missing a piece of itself.
  int? _reservedBytes() {
    var total = 0;
    var known = false;

    try {
      final size = readHibernation().size;
      if (size != null) {
        total += size;
        known = true;
      }
    } catch (_) {
      // Left out of the total.
    }

    try {
      final pagefile = readPagefile();
      if (pagefile.totalSize > 0) {
        total += pagefile.totalSize;
        known = true;
      }
    } catch (_) {
      // Left out of the total.
    }

    return known ? total : null;
  }

  Future<void> _emptyRecycleBin() async {
    final bin = _recycleBin;
    if (bin == null || bin.$2 <= 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline),
        title: Text(t('home.recycleConfirm')),
        content: SizedBox(
          width: 420,
          child: Text(
            tf('home.recycleConfirmBody',
                [formatCount(bin.$2), formatSize(bin.$1)]),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(t('confirm.ok')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _emptying = true);
    final emptied = emptyRecycleBin();
    if (!mounted) return;
    setState(() => _emptying = false);

    if (emptied) announceStorageChanged();

    if (!emptied) {
      await showErrorDialog(context, t('home.recycleFailed'));
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
          // Fixed-width tiles in a Wrap rather than a Row: on a narrow window
          // they reflow onto a second line instead of squeezing their numbers
          // out of shape.
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _RecycleTile(
                info: _recycleBin,
                busy: _emptying,
                onEmpty: _emptyRecycleBin,
              ),
              _ReservedTile(bytes: _reserved),
              _TrendTile(history: _history),
              _LastCleanTile(record: _history.lastClean),
            ],
          ),
          const SizedBox(height: 18),
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

/// Shared shape for the four numbers across the top of the dashboard: what it
/// is, the figure, a line of context, and — where there is something to do
/// about it — a way to act or a place to go.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    this.action,
    this.onTap,
    this.muted = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final String detail;
  final Widget? action;
  final VoidCallback? onTap;

  /// Draws the figure in the quieter colour, for a tile with nothing to report.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SizedBox(
      width: 268,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                    if (onTap != null)
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        value,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: muted ? scheme.outline : null,
                        ),
                      ),
                    ),
                    if (action != null) action!,
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecycleTile extends StatelessWidget {
  const _RecycleTile({
    required this.info,
    required this.busy,
    required this.onEmpty,
  });

  final (int, int)? info;
  final bool busy;
  final VoidCallback onEmpty;

  @override
  Widget build(BuildContext context) {
    LanguageScope.watch(context);

    final bin = info;
    if (bin == null) {
      return _Tile(
        icon: Icons.delete_outline,
        label: t('home.recycle'),
        value: '—',
        detail: t('home.recycleUnknown'),
        muted: true,
      );
    }

    return _Tile(
      icon: Icons.delete_outline,
      label: t('home.recycle'),
      value: formatSize(bin.$1),
      detail: tf('home.recycleCount', [formatCount(bin.$2)]),
      muted: bin.$2 == 0,
      action: busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : TextButton(
              onPressed: bin.$2 > 0 ? onEmpty : null,
              child: Text(t('home.recycleEmpty')),
            ),
    );
  }
}

class _ReservedTile extends StatelessWidget {
  const _ReservedTile({required this.bytes});

  final int? bytes;

  @override
  Widget build(BuildContext context) {
    LanguageScope.watch(context);

    final total = bytes;

    return _Tile(
      icon: Icons.lock_outline,
      label: t('home.reserved'),
      value: total == null ? '—' : formatSize(total),
      detail: t('home.reservedHint'),
      muted: total == null,
      onTap: () => selectedPage.value = Pages.reclaim,
    );
  }
}

class _TrendTile extends StatelessWidget {
  const _TrendTile({required this.history});

  final History history;

  @override
  Widget build(BuildContext context) {
    LanguageScope.watch(context);

    final change = history.freeChangeOver(7);
    if (change == null) {
      return _Tile(
        icon: Icons.timeline,
        label: t('home.trend'),
        value: '—',
        detail: t('home.trendNone'),
        muted: true,
      );
    }

    // Free space going up is room recovered; going down is room spent.
    return _Tile(
      icon: Icons.timeline,
      label: t('home.trend'),
      value: '${change < 0 ? '−' : '+'}${formatSize(change.abs())}',
      detail: change < 0 ? t('home.trendUsed') : t('home.trendFreed'),
      muted: change == 0,
    );
  }
}

class _LastCleanTile extends StatelessWidget {
  const _LastCleanTile({required this.record});

  final CleanRecord? record;

  static String _whenText(DateTime at) {
    final now = DateTime.now();
    final days = DateTime(now.year, now.month, now.day)
        .difference(DateTime(at.year, at.month, at.day))
        .inDays;

    return switch (days) {
      <= 0 => t('home.today'),
      1 => t('home.yesterday'),
      _ => tf('home.daysAgo', [days]),
    };
  }

  @override
  Widget build(BuildContext context) {
    LanguageScope.watch(context);

    final last = record;
    if (last == null) {
      return _Tile(
        icon: Icons.history,
        label: t('home.lastClean'),
        value: '—',
        detail: t('home.lastCleanNever'),
        muted: true,
      );
    }

    return _Tile(
      icon: Icons.history,
      label: t('home.lastClean'),
      value: formatSize(last.bytes),
      detail: '${_whenText(last.at)}  ·  '
          '${tf('status.scanned', [formatCount(last.files)])}',
    );
  }
}
