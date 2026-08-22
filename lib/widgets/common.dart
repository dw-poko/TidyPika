import 'package:flutter/material.dart';

import '../core/disk_scanner.dart';
import '../core/models.dart';
import '../core/size_formatter.dart';
import '../l10n/strings.dart';

class PageScaffold extends StatelessWidget {
  const PageScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (action != null) ...[const SizedBox(width: 16), action!],
            ],
          ),
          const SizedBox(height: 20),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({required this.icon, super.key});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text(t('common.empty'), style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            t('common.emptyHint'),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class RiskChip extends StatelessWidget {
  const RiskChip({required this.risk, super.key});

  final Risk risk;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final (Color background, Color foreground) = switch (risk) {
      Risk.low => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      Risk.medium => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      Risk.high => (scheme.errorContainer, scheme.onErrorContainer),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        t('risk.${risk.name}'),
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: foreground),
      ),
    );
  }
}

/// Path entry with a quick-jump menu of the drives currently attached. A native
/// folder picker would mean a plugin with its own native build, which this app
/// does not otherwise need.
class PathField extends StatelessWidget {
  const PathField({
    required this.controller,
    required this.enabled,
    super.key,
  });

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: t('common.folder'),
        suffixIcon: PopupMenuButton<String>(
          enabled: enabled,
          icon: const Icon(Icons.storage_outlined),
          tooltip: t('common.browse'),
          onSelected: (value) => controller.text = value,
          itemBuilder: (context) {
            List<DiskInfo> disks;
            try {
              disks = getDisks();
            } catch (_) {
              disks = const [];
            }

            return [
              for (final disk in disks)
                PopupMenuItem<String>(
                  value: disk.root,
                  child: Text('${disk.root}  ·  ${formatSize(disk.free)} '
                      '${t('home.free')}'),
                ),
            ];
          },
        ),
      ),
    );
  }
}

/// Recycle-Bin toggle, selection summary and the delete button, shared by every
/// page that can remove files.
class CleanActionBar extends StatelessWidget {
  const CleanActionBar({
    required this.recycle,
    required this.onRecycleChanged,
    required this.summary,
    required this.onClean,
    super.key,
  });

  final bool recycle;
  final ValueChanged<bool>? onRecycleChanged;
  final String summary;
  final VoidCallback? onClean;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Switch(value: recycle, onChanged: onRecycleChanged),
        const SizedBox(width: 10),
        Text(t('quick.recycle')),
        const Spacer(),
        Flexible(
          child: Text(
            summary,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const SizedBox(width: 16),
        FilledButton.icon(
          onPressed: onClean,
          icon: const Icon(Icons.delete_outline, size: 18),
          label: Text(t('quick.clean')),
        ),
      ],
    );
  }
}

Future<bool> confirmDelete(
  BuildContext context, {
  required int count,
  required int bytes,
  required bool useRecycleBin,
}) async {
  final body = tf(
    useRecycleBin ? 'confirm.recycle' : 'confirm.permanent',
    [formatCount(count), formatSize(bytes)],
  );

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.delete_outline),
      title: Text(t('confirm.title')),
      content: Text(body),
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

  return confirmed ?? false;
}

Future<void> showCleanResult(BuildContext context, CleanResult result) {
  var text = tf(
    'result.body',
    [formatCount(result.deleted), formatSize(result.freedBytes)],
  );
  if (result.errors.isNotEmpty) {
    text = '$text\n${tf('result.errors', [formatCount(result.errors.length)])}';
  }

  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.check_circle_outline),
      title: Text(t('result.title')),
      content: Text(text),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t('result.close')),
        ),
      ],
    ),
  );
}

Future<void> showErrorDialog(BuildContext context, String message) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.error_outline),
      title: Text(t('error.title')),
      content: Text(message),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t('result.close')),
        ),
      ],
    ),
  );
}
