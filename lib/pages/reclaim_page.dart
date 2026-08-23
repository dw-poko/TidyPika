import 'package:flutter/material.dart';

import '../core/disk_scanner.dart';
import '../core/hibernation.dart';
import '../core/pagefile.dart';
import '../core/size_formatter.dart';
import '../core/win32.dart';
import '../l10n/strings.dart';
import '../widgets/common.dart';

/// The space Windows sets aside for itself.
///
/// Neither of these is a file to be found and deleted: the hibernation file
/// and the paging file exist because a setting says they should, so the page
/// shows what each costs and changes the setting.
class ReclaimPage extends StatefulWidget {
  const ReclaimPage({super.key});

  @override
  State<ReclaimPage> createState() => _ReclaimPageState();
}

class _ReclaimPageState extends State<ReclaimPage> {
  HibernationInfo? _hibernation;
  PagefileInfo? _pagefile;
  bool _busy = false;
  bool _pageBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    HibernationInfo? hibernation;
    try {
      hibernation = readHibernation();
    } catch (_) {
      hibernation = null;
    }

    PagefileInfo? pagefile;
    try {
      pagefile = readPagefile();
    } catch (_) {
      pagefile = null;
    }

    setState(() {
      _hibernation = hibernation;
      _pagefile = pagefile;
    });
  }

  Future<void> _changePagefile() async {
    final info = _pagefile;
    if (info == null) return;

    final choice = await showDialog<_PagefileChoice>(
      context: context,
      builder: (context) => _PagefileDialog(info: info),
    );
    if (choice == null || !mounted) return;

    if (!isElevated()) {
      await showElevationNotice(context, messageKey: 'page.needsAdmin');
      return;
    }

    setState(() => _pageBusy = true);

    final pending = switch (choice.mode) {
      PagefileMode.custom => setPagefileCustom(
          initialMb: choice.initialMb,
          maximumMb: choice.maximumMb,
        ),
      PagefileMode.none => setPagefileNone(),
      _ => setPagefileAutomatic(),
    };

    final result = await pending;
    if (!mounted) return;
    setState(() => _pageBusy = false);

    if (result.exitCode != 0) {
      final output = '${result.stdout}\n${result.stderr}'.trim();
      await showErrorDialog(
        context,
        output.isEmpty
            ? '${t('page.failed')}\n\nexit code ${result.exitCode}'
            : '${t('page.failed')}\n\n$output',
      );
    } else {
      // Nothing on disk changes until the next boot, so say so rather than
      // letting a refreshed card that looks unchanged read as a failure.
      await showNoticeDialog(
        context,
        title: t('page.rebootTitle'),
        body: t('page.reboot'),
      );
    }

    if (!mounted) return;
    _load();
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
      title: t('reclaim.title'),
      subtitle: t('reclaim.subtitle'),
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
            const SizedBox(height: 12),
          ],
          if (_pagefile != null) ...[
            _PagefileCard(
              info: _pagefile!,
              busy: _pageBusy,
              onChange: _pageBusy ? null : _changePagefile,
            ),
          ],
          const Spacer(),
        ],
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

  String _subtitle() => switch (info.state) {
        HibernationState.on => info.path,
        HibernationState.off => t('hiber.none'),
        HibernationState.unknown => t('hiber.unknown'),
      };

  @override
  Widget build(BuildContext context) {
    LanguageScope.watch(context);

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // A switch has two positions and no way to sit between them, so when the
    // state could not be read it is left alone rather than shown in a position
    // that would be a guess.
    final known = info.state != HibernationState.unknown;

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
                    _subtitle(),
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
              Switch(
                value: info.enabled,
                onChanged: known ? onChanged : null,
              ),
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

/// What the paging file is costing, how Windows is set to size it, and the way
/// in to changing that.
class _PagefileCard extends StatelessWidget {
  const _PagefileCard({
    required this.info,
    required this.busy,
    required this.onChange,
  });

  final PagefileInfo info;
  final bool busy;
  final VoidCallback? onChange;

  String _modeLabel() => switch (info.mode) {
        PagefileMode.automatic => t('page.auto'),
        PagefileMode.systemManaged => t('page.system'),
        PagefileMode.none => t('page.none'),
        PagefileMode.unknown => t('page.unknown'),
        PagefileMode.custom => _customLabel(),
      };

  String _customLabel() {
    final entry = info.entries.firstWhere(
      (entry) => !entry.isAutomatic && !entry.isSystemManaged,
      orElse: () => const PagefileEntry(path: ''),
    );

    return tf('page.custom', [entry.initialMb ?? 0, entry.maximumMb ?? 0]);
  }

  String _subtitle() {
    if (info.mode == PagefileMode.unknown) return t('page.unknown');
    if (info.mode == PagefileMode.none && info.files.isEmpty) {
      return t('page.none');
    }

    // What is on disk when there is anything, otherwise what is configured:
    // a setting made and not yet rebooted into has no file to point at.
    final where = info.files.isNotEmpty
        ? info.files.join(', ')
        : [for (final entry in info.entries) entry.path].join(', ');

    return where.isEmpty ? _modeLabel() : '$where  ·  ${_modeLabel()}';
  }

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
            Icon(Icons.memory, size: 20, color: scheme.onSurfaceVariant),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('page.title'), style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    _subtitle(),
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (info.totalSize > 0) ...[
              const SizedBox(width: 12),
              Text(
                formatSize(info.totalSize),
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
              OutlinedButton(
                onPressed: onChange,
                child: Text(t('page.change')),
              ),
          ],
        ),
      ),
    );
  }
}

/// What the dialog decided. [mode] is only ever automatic, custom or none —
/// systemManaged and unknown describe a machine, not a choice.
class _PagefileChoice {
  const _PagefileChoice(this.mode, {this.initialMb = 0, this.maximumMb = 0});

  final PagefileMode mode;
  final int initialMb;
  final int maximumMb;
}

class _PagefileDialog extends StatefulWidget {
  const _PagefileDialog({required this.info});

  final PagefileInfo info;

  @override
  State<_PagefileDialog> createState() => _PagefileDialogState();
}

class _PagefileDialogState extends State<_PagefileDialog> {
  static const List<PagefileMode> _options = [
    PagefileMode.automatic,
    PagefileMode.custom,
    PagefileMode.none,
  ];

  late PagefileMode _choice;
  late final TextEditingController _initial;
  late final TextEditingController _maximum;
  String? _error;

  @override
  void initState() {
    super.initState();

    final entry = widget.info.entries.firstWhere(
      (entry) => !entry.isAutomatic && !entry.isSystemManaged,
      orElse: () => const PagefileEntry(path: ''),
    );

    _choice = switch (widget.info.mode) {
      PagefileMode.custom => PagefileMode.custom,
      PagefileMode.none => PagefileMode.none,
      _ => PagefileMode.automatic,
    };

    // Defaults for a machine that has never had a range set by hand.
    _initial = TextEditingController(text: '${entry.initialMb ?? 2048}');
    _maximum = TextEditingController(text: '${entry.maximumMb ?? 8192}');
  }

  @override
  void dispose() {
    _initial.dispose();
    _maximum.dispose();
    super.dispose();
  }

  String _label(PagefileMode mode) => switch (mode) {
        PagefileMode.custom =>
          tf('page.optionCustom', [systemDriveRoot()]),
        PagefileMode.none => t('page.optionNone'),
        _ => t('page.optionAuto'),
      };

  void _apply() {
    if (_choice != PagefileMode.custom) {
      Navigator.of(context).pop(_PagefileChoice(_choice));
      return;
    }

    final initial = int.tryParse(_initial.text.trim()) ?? 0;
    final maximum = int.tryParse(_maximum.text.trim()) ?? 0;

    if (initial <= 0 || maximum < initial) {
      setState(() => _error = t('page.invalidSize'));
      return;
    }

    Navigator.of(context).pop(
      _PagefileChoice(
        PagefileMode.custom,
        initialMb: initial,
        maximumMb: maximum,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    LanguageScope.watch(context);

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AlertDialog(
      icon: const Icon(Icons.memory),
      title: Text(t('page.dialogTitle')),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final option in _options)
              ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: () => setState(() {
                  _choice = option;
                  _error = null;
                }),
                leading: Icon(
                  _choice == option
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: _choice == option ? scheme.primary : scheme.outline,
                ),
                title: Text(_label(option)),
              ),
            if (_choice == PagefileMode.custom) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _initial,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: t('page.initial'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _maximum,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: t('page.maximum'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (_choice == PagefileMode.none) ...[
              const SizedBox(height: 8),
              Text(
                t('page.noneWarning'),
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              t('page.reboot'),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t('common.cancel')),
        ),
        FilledButton(onPressed: _apply, child: Text(t('page.apply'))),
      ],
    );
  }
}
