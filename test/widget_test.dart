import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json_viewer/main.dart';
import 'package:json_viewer/src/json_tree_view.dart';

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

  testWidgets('opens initial file as tree and toggles nodes', (tester) async {
    await tester.pumpWidget(const JsonViewerApp());
    await tester.pumpAndSettle();

    expect(find.text('sample.json'), findsOneWidget);
    // Top level is expanded, so the nested "name" is visible.
    expect(find.textContaining('"Ada"'), findsOneWidget);

    await tester.tap(find.textContaining('"user"'));
    await tester.pumpAndSettle();
    expect(find.textContaining('"Ada"'), findsNothing);
  });

  testWidgets('edit, validate and save', (tester) async {
    await tester.pumpWidget(const JsonViewerApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_outlined));
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

    ScrollPosition treePosition() => tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byType(JsonTreeView),
            matching: find.byType(Scrollable),
          ),
        )
        .position;

    expect(treePosition().pixels, 0);
    await tester.drag(find.byType(TextField), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(treePosition().pixels, greaterThan(0));
  });
}
