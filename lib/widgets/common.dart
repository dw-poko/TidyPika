import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../core/disk_scanner.dart';
import '../core/models.dart';
import '../core/size_formatter.dart';
import '../core/win32.dart';
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
    LanguageScope.watch(context);
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
    LanguageScope.watch(context);
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
    LanguageScope.watch(context);

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
    LanguageScope.watch(context);

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

/// Language picker.
///
/// Every option is written in its own language, so the list reads the same
/// whichever one is set — someone who cannot read the current one can still
/// find their way back out of it.
class LanguageMenu extends StatelessWidget {
  const LanguageMenu({this.extended = true, super.key});

  final bool extended;

  @override
  Widget build(BuildContext context) {
    LanguageScope.watch(context);

    final scheme = Theme.of(context).colorScheme;
    final current = language.value;

    return PopupMenuButton<AppLanguage>(
      tooltip: t('action.language'),
      position: PopupMenuPosition.under,
      onSelected: setLanguage,
      itemBuilder: (context) => [
        for (final option in AppLanguage.values)
          PopupMenuItem<AppLanguage>(
            value: option,
            child: Row(
              children: [
                SizedBox(
                  width: 26,
                  child: option == current
                      ? Icon(Icons.check, size: 16, color: scheme.primary)
                      : null,
                ),
                Text(option.label),
              ],
            ),
          ),
      ],
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: extended ? 14 : 8,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.translate, size: 18),
            if (extended) ...[
              const SizedBox(width: 8),
              Text(current.label),
            ],
          ],
        ),
      ),
    );
  }
}

/// Said once at startup, before anything is scanned.
///
/// Without elevation the Windows folders are not merely undeletable — much of
/// what is in them cannot even be listed, so the scan under-reports and the
/// numbers look wrong rather than restricted.
Future<void> showElevationNotice(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => const _ElevationNotice(),
  );
}

class _ElevationNotice extends StatelessWidget {
  const _ElevationNotice();

  @override
  Widget build(BuildContext context) {
    LanguageScope.watch(context);

    return AlertDialog(
      icon: const Icon(Icons.shield_outlined),
      title: Text(t('elevate.title')),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // This is the first thing the app says, and it may be saying it in
            // a language the reader does not have.
            const Align(
              alignment: Alignment.centerRight,
              child: LanguageMenu(),
            ),
            const SizedBox(height: 14),
            Text(t('elevate.body')),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t('elevate.continue')),
        ),
        FilledButton.icon(
          onPressed: () {
            if (relaunchElevated()) exit(0);
          },
          icon: const Icon(Icons.shield_outlined, size: 18),
          label: Text(t('result.elevate')),
        ),
      ],
    );
  }
}

Future<void> showCleanResult(BuildContext context, CleanResult result) {
  return showDialog<void>(
    context: context,
    builder: (context) => _CleanResultDialog(result: result),
  );
}

/// What happened, including what did not happen and why.
///
/// A count of failures on its own leaves nothing to act on: a file held open
/// by Explorer, one the Windows folders will not surrender without elevation,
/// and one this app refused to touch all look the same. Each is named here,
/// and the one case with a remedy — access denied while running unelevated —
/// offers it.
class _CleanResultDialog extends StatelessWidget {
  const _CleanResultDialog({required this.result});

  final CleanResult result;

  static const int _limit = 200;

  @override
  Widget build(BuildContext context) {
    LanguageScope.watch(context);

    final theme = Theme.of(context);
    final errors = result.errors;
    final shown = errors.length > _limit ? errors.sublist(0, _limit) : errors;
    final hidden = errors.length - shown.length;

    // isElevated() is a cheap token query, and a dialog is built rarely.
    final offerElevation = result.needsElevation && !isElevated();

    return AlertDialog(
      icon: const Icon(Icons.check_circle_outline),
      title: Text(t('result.title')),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tf('result.body',
                  [formatCount(result.deleted), formatSize(result.freedBytes)]),
            ),
            if (errors.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                tf('result.failures', [formatCount(errors.length)]),
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final entry in result.failureCounts.entries)
                    _ReasonChip(reason: entry.key, count: entry.value),
                ],
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 190),
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: shown.length + (hidden > 0 ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == shown.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            tf('result.moreFailures', [formatCount(hidden)]),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        );
                      }

                      return _FailedFile(error: shown[index]);
                    },
                  ),
                ),
              ),
              if (offerElevation) ...[
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        t('result.elevateHint'),
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        if (offerElevation)
          TextButton.icon(
            // The elevated copy takes over from here; two windows on the same
            // build would only fight over the same directories.
            onPressed: () {
              if (relaunchElevated()) exit(0);
            },
            icon: const Icon(Icons.shield_outlined, size: 18),
            label: Text(t('result.elevate')),
          ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t('result.close')),
        ),
      ],
    );
  }
}

class _ReasonChip extends StatelessWidget {
  const _ReasonChip({required this.reason, required this.count});

  final CleanFailure reason;
  final int count;

  @override
  Widget build(BuildContext context) {
    LanguageScope.watch(context);

    final scheme = Theme.of(context).colorScheme;
    final (Color background, Color foreground) = switch (reason) {
      CleanFailure.accessDenied => (
          scheme.errorContainer,
          scheme.onErrorContainer,
        ),
      CleanFailure.inUse => (
          scheme.tertiaryContainer,
          scheme.onTertiaryContainer,
        ),
      _ => (scheme.secondaryContainer, scheme.onSecondaryContainer),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '${t('failure.${reason.name}')}  ${formatCount(count)}',
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: foreground),
      ),
    );
  }
}

class _FailedFile extends StatelessWidget {
  const _FailedFile({required this.error});

  final CleanError error;

  @override
  Widget build(BuildContext context) {
    LanguageScope.watch(context);

    final theme = Theme.of(context);

    return Tooltip(
      message: error.path,
      waitDuration: const Duration(milliseconds: 500),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.basename(error.path),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(
                    p.dirname(error.path),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              t('failure.${error.reason.name}'),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
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
