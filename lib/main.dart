import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'screens/reader_screen.dart';
import 'screens/starting_verse_screen.dart';
import 'services/database_service.dart';
import 'services/widget_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Pre-initialize database on startup
  await DatabaseService.instance.database;

  // Check if opened from Home Screen Widget
  final launchedFromWidget = await HomeWidget.initiallyLaunchedFromHomeWidget();
  final savedVerseId = await WidgetService.getSavedVerseIndex();

  runApp(QudumanApp(
    initialVerseId: savedVerseId,
    launchedDirectlyToReader: launchedFromWidget != null,
  ));
}

class QudumanApp extends StatelessWidget {
  final int initialVerseId;
  final bool launchedDirectlyToReader;

  const QudumanApp({
    super.key,
    required this.initialVerseId,
    required this.launchedDirectlyToReader,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quduman',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark, // Clean distraction-free dark theme by default
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: const Color(0xFF1B4332), // Deep Quranic Forest Green
        fontFamily: 'Roboto',
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF2D6A4F),
        scaffoldBackgroundColor: const Color(0xFF121413),
      ),
      home: launchedDirectlyToReader
          ? ReaderScreen(initialVerseId: initialVerseId)
          : const StartingVerseScreen(),
    );
  }
}
