import "package:dynamic_system_colors/dynamic_system_colors.dart";
import "package:flex_seed_scheme/flex_seed_scheme.dart";
import "package:flutter/material.dart";
import "package:material_symbols_icons/symbols.dart";
import "package:unimusic/components/app_sidebar.dart";
import "package:unimusic/components/music_player.dart";
import "package:unimusic/utils/layout.dart";
import "package:unimusic/services/database/database.dart";
import "package:unimusic/services/music_manager.dart";
import "package:unimusic/services/provider_registry.dart";
import "package:unimusic/services/theme_service.dart";
import "package:unimusic/services/music_providers/music_provider.dart";
import "package:unimusic/views/home_view.dart";
import "package:unimusic/views/library_view.dart";
import "package:unimusic/views/search_view.dart";
import "package:unimusic/views/pages/settings_page.dart";
import "package:unimusic/components/bottom_sheet_bar.dart";
import "package:just_audio_background/just_audio_background.dart";
import "package:provider/provider.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await JustAudioBackground.init(
    androidNotificationChannelId: "app.unimusic.channel.audio",
    androidNotificationChannelName: "UniMusic Audio Playback",
    androidNotificationOngoing: true,
  );

  await DatabaseHelper.instantiate();

  final themeService = await ThemeService.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeService),
        ChangeNotifierProvider(create: (_) => ProviderRegistry()),
        ChangeNotifierProvider(create: (_) => MusicManager()),
      ],
      child: const UniMusicApp(),
    ),
  );
}

class UniMusicApp extends StatelessWidget {
  const UniMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    final seedColor = context.watch<ThemeService>().seedColor;

    return DynamicColorBuilder(
      builder: (lightScheme, darkScheme) {
        ThemeData applyCommon(ThemeData theme) => theme.copyWith(
          visualDensity: VisualDensity.standard,
          // ignore: deprecated_member_use It's kinda dumb that it marks option for NEW behaviour as deprecated
          sliderTheme: const SliderThemeData(year2023: false),

          iconTheme: theme.iconTheme.copyWith(
            fill: 1,
            applyTextScaling: true,
            opticalSize: 28,
            grade: 200,
          ),

          tooltipTheme: theme.tooltipTheme.copyWith(
            waitDuration: const Duration(seconds: 1),
          ),

          // Flutter on desktop defaults to keeping the default mouse cursor over clickable widgets,
          // but I want the cursor to indicate interactivity, so I set it to pointer for all clickable buttons
          iconButtonTheme: const IconButtonThemeData(
            style: ButtonStyle(mouseCursor: WidgetStateMouseCursor.clickable),
          ),
          textButtonTheme: const TextButtonThemeData(
            style: ButtonStyle(mouseCursor: WidgetStateMouseCursor.clickable),
          ),
          filledButtonTheme: const FilledButtonThemeData(
            style: ButtonStyle(mouseCursor: WidgetStateMouseCursor.clickable),
          ),
          outlinedButtonTheme: const OutlinedButtonThemeData(
            style: ButtonStyle(mouseCursor: WidgetStateMouseCursor.clickable),
          ),
          listTileTheme: const ListTileThemeData(
            mouseCursor: WidgetStateMouseCursor.clickable,
          ),
          checkboxTheme: const CheckboxThemeData(
            mouseCursor: WidgetStateMouseCursor.clickable,
          ),
          radioTheme: const RadioThemeData(
            mouseCursor: WidgetStateMouseCursor.clickable,
          ),
        );

        return MaterialApp(
          title: "UniMusic",

          theme: applyCommon(
            ThemeData.from(
              useMaterial3: true,
              colorScheme: seedColor != null
                  ? SeedColorScheme.fromSeeds(
                      brightness: Brightness.light,
                      primaryKey: seedColor,
                      tones: FlexTones.vividSurfaces(Brightness.light),
                    )
                  : lightScheme ??
                        ColorScheme.fromSeed(seedColor: Colors.lightBlue),
            ),
          ),
          darkTheme: applyCommon(
            ThemeData.from(
              useMaterial3: true,
              colorScheme: seedColor != null
                  ? SeedColorScheme.fromSeeds(
                      brightness: Brightness.dark,
                      primaryKey: seedColor,
                      tones: FlexTones.vividSurfaces(Brightness.dark),
                    )
                  : darkScheme ??
                        ColorScheme.fromSeed(
                          brightness: Brightness.dark,
                          seedColor: Colors.lightBlue,
                        ),
            ),
          ),

          themeMode: ThemeMode.system,

          home: const MainPage(),
        );
      },
    );
  }
}

/// The top-level views of the app, used to key navigators, icons, and labels.
enum AppView {
  home(
    icon: Symbols.home_rounded,
    selectedIcon: Symbols.home_rounded,
    label: "Home",
    page: HomeView(),
  ),
  search(
    icon: Symbols.search_rounded,
    selectedIcon: Symbols.search_rounded,
    label: "Search",
    page: SearchView(),
  ),
  library(
    icon: Symbols.library_music_rounded,
    selectedIcon: Symbols.library_music_rounded,
    label: "Library",
    page: LibraryView(),
  ),
  settings(
    icon: Symbols.settings_rounded,
    selectedIcon: Symbols.settings_rounded,
    label: "Settings",
    page: SettingsPage(),
  );

  /// The views shown in the compact (mobile) bottom navigation bar.
  static const compactViews = [AppView.home, AppView.search, AppView.library];

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Widget page;

  const AppView({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.page,
  });
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  AppView _currentView = AppView.home;
  LibraryItemType _selectedLibraryType = LibraryItemType.songs;
  double _sidebarWidth = AppSidebar.defaultWidth;

  static const double _minSidebarWidth = 160.0;

  final _navigatorKeys = {
    for (final view in AppView.values)
      view: GlobalKey<NavigatorState>(debugLabel: view.name),
  };

  final _libraryNavigatorKeys = {
    for (final itemType in LibraryItemType.values)
      itemType: GlobalKey<NavigatorState>(
        debugLabel: "library-${itemType.name}",
      ),
  };

  late final Map<AppView, Widget> _navigators = {
    for (final view in AppView.values)
      view: Navigator(
        key: _navigatorKeys[view],
        onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => view.page),
      ),
  };

  late final Map<LibraryItemType, Widget> _libraryNavigators = {
    for (final itemType in LibraryItemType.values)
      itemType: Navigator(
        key: _libraryNavigatorKeys[itemType],
        onGenerateRoute: (_) => MaterialPageRoute(
          builder: (_) => LibraryView(fixedItemType: itemType),
        ),
      ),
  };

  void _popNavigatorToRoot(AppView view) {
    final navigator = _navigatorKeys[view]!.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.popUntil((route) => route.isFirst);
    }
  }

  void _popLibraryNavigatorToRoot(LibraryItemType itemType) {
    final navigator = _libraryNavigatorKeys[itemType]?.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.popUntil((route) => route.isFirst);
    }
  }

  void _onCompactDestinationSelected(int index) {
    final view = AppView.compactViews[index];
    if (view == _currentView) {
      _popNavigatorToRoot(view);
      return;
    }
    setState(() => _currentView = view);
  }

  /// Handle platform back button by popping the active nested navigator.
  void _handleBackButton(bool didPop, Object? _) {
    if (didPop) return;
    final navigator = _navigatorKeys[_currentView]!.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isExpanded = MediaQuery.sizeOf(context).width >= expandedBreakpoint;

    final expandedViews = IndexedStack(
      index: AppView.values.indexOf(_currentView),
      children: [
        for (final view in AppView.values)
          if (view == AppView.library)
            IndexedStack(
              index: LibraryItemType.values.indexOf(_selectedLibraryType),
              children: [
                for (final itemType in LibraryItemType.values)
                  _libraryNavigators[itemType]!,
              ],
            )
          else
            _navigators[view]!,
      ],
    );

    final compactViews = IndexedStack(
      index: AppView.compactViews
          .indexOf(_currentView)
          .clamp(0, AppView.compactViews.length - 1),
      children: [for (final view in AppView.compactViews) _navigators[view]!],
    );

    if (isExpanded) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: _handleBackButton,
        child: Scaffold(
          body: Stack(
            children: [
              Row(
                children: [
                  SizedBox(
                    width: _sidebarWidth,
                    child: AppSidebar(
                      items: [
                        for (final view in [AppView.home, AppView.search])
                          AppSidebarItem(
                            icon: view.icon,
                            selectedIcon: view.selectedIcon,
                            label: view.label,
                            selected: _currentView == view,
                            onTap: () {
                              if (_currentView == view) {
                                _popNavigatorToRoot(view);
                              }
                              setState(() => _currentView = view);
                            },
                          ),
                        const AppSidebarSectionHeader("Library"),
                        for (final itemType in LibraryItemType.values)
                          AppSidebarItem(
                            icon: itemType.icon,
                            selectedIcon: itemType.icon,
                            label: "${itemType.name}s",
                            selected:
                                _currentView == AppView.library &&
                                _selectedLibraryType == itemType,
                            onTap: () {
                              if (_currentView == AppView.library &&
                                  _selectedLibraryType == itemType) {
                                _popLibraryNavigatorToRoot(itemType);
                              }
                              setState(() {
                                _currentView = AppView.library;
                                _selectedLibraryType = itemType;
                              });
                            },
                          ),
                      ],
                      bottomItems: [
                        AppSidebarItem(
                          icon: AppView.settings.icon,
                          selectedIcon: AppView.settings.selectedIcon,
                          label: AppView.settings.label,
                          selected: _currentView == AppView.settings,
                          onTap: () {
                            if (_currentView == AppView.settings) {
                              _popNavigatorToRoot(AppView.settings);
                            }
                            setState(() => _currentView = AppView.settings);
                          },
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        MediaQuery(
                          data: MediaQuery.of(context).copyWith(
                            padding: MediaQuery.paddingOf(context).copyWith(
                              bottom: MusicPlayer.collapsedFloatingHeight,
                            ),
                          ),
                          child: expandedViews,
                        ),
                        const MusicPlayer(floating: true),
                      ],
                    ),
                  ),
                ],
              ),
              // Drag handle — sits at the sidebar's right edge, lets the
              // user resize the sidebar by dragging horizontally.
              Positioned(
                left: _sidebarWidth - 4,
                top: 0,
                bottom: 0,
                width: 8,
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        _sidebarWidth = (_sidebarWidth + details.delta.dx)
                            .clamp(_minSidebarWidth, AppSidebar.defaultWidth);
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _handleBackButton,
      child: Scaffold(
        body: compactViews,
        bottomNavigationBar: BottomSheetBar(
          sheet: const MusicPlayer(),
          bar: NavigationBar(
            destinations: [
              for (final view in AppView.compactViews)
                NavigationDestination(
                  icon: Icon(view.icon, fill: 0),
                  selectedIcon: Icon(view.selectedIcon),
                  label: view.label,
                ),
            ],
            selectedIndex: AppView.compactViews
                .indexOf(_currentView)
                .clamp(0, AppView.compactViews.length - 1),
            onDestinationSelected: _onCompactDestinationSelected,
          ),
        ),
      ),
    );
  }
}
