import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json_viewer/main.dart';
import 'package:json_viewer/src/readable_view.dart';

void main() {
  const channel = MethodChannel('json_viewer/file');
  final saved = <Map<Object?, Object?>>[];
  const sample = '{"user": {"name": "Ada", "age": 36}, "tags": ["a"]}';
  var content = sample;

  setUp(() {
    saved.clear();
    content = sample;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'getInitialFile':
              return {
                'name': 'sample.json',
                'content': content,
                'uri': 'content://test/sample.json',
              };
            case 'saveFile':
              saved.add(call.arguments as Map<Object?, Object?>);
              return null;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('opens initial file in readable view', (tester) async {
    await tester.pumpWidget(const JsonViewerApp());
    await tester.pumpAndSettle();

    expect(find.text('sample.json'), findsOneWidget);
    expect(find.text('User'), findsOneWidget); // section heading
    expect(find.text('Ada'), findsOneWidget); // no quotes
    expect(find.text('36'), findsOneWidget);
  });

  testWidgets('tree view toggles nodes', (tester) async {
    await tester.pumpWidget(const JsonViewerApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Tree view'));
    await tester.pumpAndSettle();

    // Top level is expanded, so the nested "name" is visible.
    expect(find.textContaining('"Ada"'), findsOneWidget);
    await tester.tap(find.textContaining('"user"'));
    await tester.pumpAndSettle();
    expect(find.textContaining('"Ada"'), findsNothing);
  });

  testWidgets('tapping a value in split view selects it in the editor', (
    tester,
  ) async {
    await tester.pumpWidget(const JsonViewerApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.vertical_split_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ada'));
    await tester.pumpAndSettle();
    final editor = tester.widget<TextField>(find.byType(TextField));
    final selection = editor.controller!.selection;
    expect(selection.textInside(sample), '"Ada"');
  });

  testWidgets('edit, validate and save', (tester) async {
    await tester.pumpWidget(const JsonViewerApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit as text'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '{"a": }');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('Line 1, column 7'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '{"a": 1}');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('Valid JSON'), findsOneWidget);
    expect(find.text('•'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.save_outlined));
    await tester.pumpAndSettle();
    expect(saved.single['content'], '{"a": 1}');
    expect(saved.single['uri'], 'content://test/sample.json');
    expect(find.text('•'), findsNothing);
  });

  testWidgets('split view scrolls both panes together', (tester) async {
    final entries = List.generate(150, (i) => '  "key$i": $i').join(',\n');
    content = '{\n$entries\n}';
    await tester.pumpWidget(const JsonViewerApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.vertical_split_outlined));
    await tester.pumpAndSettle();

    ScrollPosition viewerPosition() => tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byType(ReadableJsonView),
            matching: find.byType(Scrollable),
          ),
        )
        .position;

    expect(viewerPosition().pixels, 0);
    await tester.drag(find.byType(TextField), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(viewerPosition().pixels, greaterThan(0));
  });

  testWidgets('form editor: new document, add a list of objects', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);
    await tester.pumpWidget(const JsonViewerApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();
    expect(find.text('Add field'), findsOneWidget);

    // Add a list called "modules".
    await tester.tap(find.text('Add field'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'modules');
    await tester.tap(find.text('List'));
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    // First item: a group with a "title" field.
    await tester.tap(find.text('Add item'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Group'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add field').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'title');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Analysis');
    await tester.pump(const Duration(seconds: 1));

    // Second item copies the fields of the first.
    await tester.tap(find.text('Add item (same fields)'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit as text'));
    await tester.pumpAndSettle();
    final editor = tester.widget<TextField>(find.byType(TextField));
    expect(
      editor.controller!.text,
      '{\n  "modules": [\n    {\n      "title": "Analysis"\n    },\n'
      '    {\n      "title": ""\n    }\n  ]\n}',
    );

    // Undo is available back in the form.
    await tester.tap(find.text('Form'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Add item (same fields)'), findsOneWidget);
    expect(find.text('#2'), findsNothing);
  });

  testWidgets('raw text view shows the file exactly as stored', (tester) async {
    await tester.pumpWidget(const JsonViewerApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Raw text'));
    await tester.pumpAndSettle();
    String shown() => tester
        .widget<SelectableText>(find.byType(SelectableText))
        .textSpan!
        .toPlainText();
    expect(shown(), sample);

    await tester.tap(find.text('Formatted'));
    await tester.pumpAndSettle();
    expect(shown(), startsWith('{\n  "user": {'));
  });
}
