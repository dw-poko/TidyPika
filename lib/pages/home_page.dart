import 'package:flutter/material.dart';

import '../core/disk_scanner.dart';
import '../core/models.dart';
import '../core/size_formatter.dart';
import '../l10n/strings.dart';
import '../widgets/common.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<DiskInfo> _disks = const [];

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
    setState(() => _disks = disks);
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
              itemBuilder: (context, index) => _DiskCard(disk: _disks[index]),
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
