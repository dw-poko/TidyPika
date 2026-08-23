import 'package:flutter/material.dart';

import 'core/win32.dart';
import 'l10n/strings.dart';
import 'pages/analyze_page.dart';
import 'pages/duplicates_page.dart';
import 'pages/home_page.dart';
import 'pages/large_files_page.dart';
import 'pages/quick_clean_page.dart';
import 'widgets/common.dart';

class TidyPikaApp extends StatelessWidget {
  const TidyPikaApp({super.key});

  static const Color _seed = Color(0xFF2E7D5B);

  @override
  Widget build(BuildContext context) {
    return LanguageScope(
      child: MaterialApp(
        title: 'TidyPika',
        debugShowCheckedModeBanner: false,
        theme: _themeFor(Brightness.light),
        darkTheme: _themeFor(Brightness.dark),
        themeMode: ThemeMode.system,
        home: const AppShell(),
      ),
    );
  }

  ThemeData _themeFor(Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: brightness),
      // Segoe UI carries no Hangul, so Malgun Gothic backs it for Korean.
      fontFamily: 'Segoe UI',
      fontFamilyFallback: const ['Malgun Gothic'],
      // Every input — plain fields and the menus that wrap one — shares this,
      // so they line up at the same height wherever they sit side by side.
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  // Kept alive in an IndexedStack so scan results survive switching pages.
  static const List<Widget> _pages = [
    HomePage(),
    QuickCleanPage(),
    LargeFilesPage(),
    DuplicatesPage(),
    AnalyzePage(),
  ];

  @override
  void initState() {
    super.initState();

    // After the first frame: there is no Navigator to hang a dialog on until
    // the shell is mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !isElevated()) showElevationNotice(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    LanguageScope.watch(context);

    final scheme = Theme.of(context).colorScheme;
    final extended = MediaQuery.sizeOf(context).width >= 1000;

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: extended,
            minExtendedWidth: 210,
            selectedIndex: _index,
            onDestinationSelected: (value) => setState(() => _index = value),
            leading: _Leading(extended: extended, color: scheme.primary),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: extended
                      ? OutlinedButton.icon(
                          onPressed: toggleLanguage,
                          icon: const Icon(Icons.translate, size: 18),
                          label: Text(t('action.language')),
                        )
                      : IconButton(
                          onPressed: toggleLanguage,
                          tooltip: t('action.language'),
                          icon: const Icon(Icons.translate),
                        ),
                ),
              ),
            ),
            destinations: [
              NavigationRailDestination(
                icon: const Icon(Icons.dashboard_outlined),
                selectedIcon: const Icon(Icons.dashboard),
                label: Text(t('nav.home')),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.cleaning_services_outlined),
                selectedIcon: const Icon(Icons.cleaning_services),
                label: Text(t('nav.quick')),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.folder_open_outlined),
                selectedIcon: const Icon(Icons.folder_open),
                label: Text(t('nav.large')),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.content_copy_outlined),
                selectedIcon: const Icon(Icons.content_copy),
                label: Text(t('nav.duplicates')),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.donut_small_outlined),
                selectedIcon: const Icon(Icons.donut_small),
                label: Text(t('nav.analyze')),
              ),
            ],
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: IndexedStack(index: _index, children: _pages)),
        ],
      ),
    );
  }
}

class _Leading extends StatelessWidget {
  const _Leading({required this.extended, required this.color});

  final bool extended;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 10),
      child: SizedBox(
        width: extended ? 178 : 40,
        child: Row(
          mainAxisAlignment:
              extended ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome, color: color),
            if (extended) ...[
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'TidyPika',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
