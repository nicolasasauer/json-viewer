import 'package:flutter/material.dart';

import 'src/viewer_page.dart';

void main() => runApp(const JsonViewerApp());

class JsonViewerApp extends StatefulWidget {
  const JsonViewerApp({super.key});

  @override
  State<JsonViewerApp> createState() => _JsonViewerAppState();
}

class _JsonViewerAppState extends State<JsonViewerApp> {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeData _theme(Brightness brightness) => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blueGrey,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.neutral,
    ),
    appBarTheme: const AppBarTheme(scrolledUnderElevation: 0),
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JSON Viewer',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: _themeMode,
      home: Builder(
        builder: (context) => ViewerPage(
          onToggleTheme: () => setState(() {
            final dark = Theme.of(context).brightness == Brightness.dark;
            _themeMode = dark ? ThemeMode.light : ThemeMode.dark;
          }),
        ),
      ),
    );
  }
}
