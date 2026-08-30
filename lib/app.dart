import 'package:flutter/material.dart';

import 'core/win32.dart';
import 'l10n/strings.dart';
import 'pages/analyze_page.dart';
import 'pages/duplicates_page.dart';
import 'pages/home_page.dart';
import 'pages/large_files_page.dart';
import 'pages/quick_clean_page.dart';
import 'pages/reclaim_page.dart';
import 'widgets/common.dart';

class TidyPikaApp extends StatelessWidget {
  const TidyPikaApp({super.key});

  static const Color _seed = Color(0xFF2E7D5B);

  @override
  Widget build(BuildContext context) {
    return LanguageScope(
      // The theme chooses its font fallbacks by language, so it is built below
      // the scope rather than above it.
      child: Builder(
        builder: (context) {
          LanguageScope.watch(context);

          return MaterialApp(
            title: 'TidyPika',
            debugShowCheckedModeBanner: false,
            theme: _themeFor(Brightness.light),
            darkTheme: _themeFor(Brightness.dark),
            themeMode: ThemeMode.system,
            home: const AppShell(),
          );
        },
      ),
    );
  }

  /// Han characters are shared across Japanese, Chinese and Korean, and
  /// whichever font comes first draws them — Korean-shaped hanja in a Japanese
  /// window, if the chain is fixed. So the language in use leads, and the rest
  /// follow: a file path can hold any script whatever the app is set to.
  static List<String> _fallbacksFor(AppLanguage value) => switch (value) {
        AppLanguage.japanese => const [
            'Yu Gothic UI',
            'Meiryo',
            'Microsoft YaHei',
            'Malgun Gothic',
          ],
        AppLanguage.chinese => const [
            'Microsoft YaHei',
            'SimSun',
            'Yu Gothic UI',
            'Malgun Gothic',
          ],
        _ => const ['Malgun Gothic', 'Yu Gothic UI', 'Microsoft YaHei'],
      };

  ThemeData _themeFor(Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      colorScheme:
          ColorScheme.fromSeed(seedColor: _seed, brightness: brightness),
      // Segoe UI carries no CJK at all, so the fallbacks do that work.
      fontFamily: 'Segoe UI',
      fontFamilyFallback: _fallbacksFor(language.value),
      // Every input — plain fields and the menus that wrap one — shares this,
      // so they line up at the same height wherever they sit side by side.
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    );
  }
}

/// Which page the rail is showing.
///
/// Held outside the shell so a card on one page can send the reader to
/// another — the dashboard summarises what Reclaim Space controls, and saying
/// so is only useful if it can also take you there.
final ValueNotifier<int> selectedPage = ValueNotifier<int>(0);

abstract final class Pages {
  static const int home = 0;
  static const int quickClean = 1;
  static const int largeFiles = 2;
  static const int duplicates = 3;
  static const int reclaim = 4;
  static const int analyze = 5;
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  // Kept alive in an IndexedStack so scan results survive switching pages.
  static const List<Widget> _pages = [
    HomePage(),
    QuickCleanPage(),
    LargeFilesPage(),
    DuplicatesPage(),
    ReclaimPage(),
    AnalyzePage(),
  ];

  @override
  void initState() {
    super.initState();

    // After the first frame: there is no Navigator to hang a dialog on until
    // the shell is mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !isElevated()) {
        showElevationNotice(context, withLanguagePicker: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    LanguageScope.watch(context);

    final extended = MediaQuery.sizeOf(context).width >= 1000;

    return ListenableBuilder(
      listenable: selectedPage,
      builder: (context, _) => _shell(context, extended),
    );
  }

  Widget _shell(BuildContext context, bool extended) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: extended,
            minExtendedWidth: 210,
            selectedIndex: selectedPage.value,
            onDestinationSelected: (value) => selectedPage.value = value,
            leading: _Leading(extended: extended),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: t('exclude.title'),
                        icon: const Icon(Icons.block_outlined),
                        onPressed: () => showExclusions(context),
                      ),
                      const SizedBox(height: 4),
                      LanguageMenu(extended: extended),
                    ],
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
                icon: const Icon(Icons.tune_outlined),
                selectedIcon: const Icon(Icons.tune),
                label: Text(t('nav.reclaim')),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.donut_small_outlined),
                selectedIcon: const Icon(Icons.donut_small),
                label: Text(t('nav.analyze')),
              ),
            ],
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            child: IndexedStack(index: selectedPage.value, children: _pages),
          ),
        ],
      ),
    );
  }
}

class _Leading extends StatelessWidget {
  const _Leading({required this.extended});

  final bool extended;

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
            Image.asset(
              'assets/logo.png',
              width: 28,
              height: 28,
              filterQuality: FilterQuality.medium,
            ),
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
