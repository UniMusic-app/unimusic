import 'package:dynamic_system_colors/dynamic_system_colors.dart';
import 'package:flutter/material.dart';
import 'package:unimusic/services/database/database.dart';
import 'package:unimusic/services/music_manager.dart';
import 'package:unimusic/views/home_view.dart';
import 'package:unimusic/views/library_view.dart';
import 'package:unimusic/views/search_view.dart';
import 'package:unimusic/components/bottom_sheet_bar.dart';
import 'package:unimusic/components/music_player/music_player.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';

const appName = "UniMusic";
const appVersion = "0.0.1";

Future<void> main() async {
  await JustAudioBackground.init(
    androidNotificationChannelId: "app.unimusic.channel.audio",
    androidNotificationChannelName: "UniMusic Audio Playback",
    androidNotificationOngoing: true,
  );

  await DatabaseHelper.instantiate();

  runApp(ChangeNotifierProvider(create: (context) => MusicManager(), child: const UniMusicApp()));
}

class UniMusicApp extends StatelessWidget {
  const UniMusicApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightScheme, darkScheme) {
        return MaterialApp(
          title: 'UniMusic',

          theme: ThemeData(
            visualDensity: VisualDensity.standard,
            useMaterial3: true,
            colorScheme: lightScheme ?? ColorScheme.fromSeed(seedColor: Colors.lightBlue),
          ),
          darkTheme: ThemeData(
            visualDensity: VisualDensity.standard,
            useMaterial3: true,
            colorScheme:
                darkScheme ??
                ColorScheme.fromSeed(brightness: Brightness.dark, seedColor: Colors.lightBlue),
          ),
          themeMode: ThemeMode.system,

          home: const MainPage(),
        );
      },
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentView = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentView,
        children: [
          Navigator(
            onGenerateRoute: (settings) =>
                MaterialPageRoute(builder: (context) => const HomeView()),
          ),
          Navigator(
            onGenerateRoute: (settings) =>
                MaterialPageRoute(builder: (context) => const SearchView()),
          ),
          Navigator(
            onGenerateRoute: (settings) =>
                MaterialPageRoute(builder: (context) => const LibraryView()),
          ),
        ],
      ),

      bottomNavigationBar: BottomSheetBar(
        sheet: const MusicPlayer(),
        bar: NavigationBar(
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home), label: "Home"),
            NavigationDestination(icon: Icon(Icons.search), label: "Search"),
            NavigationDestination(icon: Icon(Icons.library_music), label: "Library"),
          ],

          selectedIndex: _currentView,
          onDestinationSelected: (index) {
            setState(() {
              _currentView = index;
            });
          },
        ),
      ),
    );
  }
}
