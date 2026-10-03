import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json_viewer/src/json_text_controller.dart';

const doc =
    '{\n  "a": {\n    "b": "{not a bracket}"\n  },\n  "c": [1, 2],\n  "d": [\n    3\n  ]\n}';

void main() {
  test('finds multi-line pairs and ignores brackets in strings', () {
    final pairs = findFoldablePairs(doc);
    String block(int s) => doc.substring(s, pairs[s]! + 1);
    expect(pairs.length, 3); // root, "a", "d" ("c" is single-line)
    expect(block(doc.indexOf('{', 1)), '{\n    "b": "{not a bracket}"\n  }');
    expect(block(doc.indexOf('[\n')), '[\n    3\n  ]');
  });

  test('folds survive edits before them and open on edits inside', () {
    final c = JsonEditingController(text: doc);
    final d = doc.indexOf('[\n');
    c.toggleFold(d);
    expect(c.isFolded(d), isTrue);

    // Insert text before the block: the fold moves along.
    c.value = TextEditingValue(text: 'xx$doc');
    expect(c.isFolded(d + 2), isTrue);

    // Edit inside the block: it opens.
    final inside = c.text.indexOf('3');
    c.value = TextEditingValue(
      text: c.text.replaceRange(inside, inside + 1, '4'),
    );
    expect(c.hasFolds, isFalse);
  });

  test('moving the caret into a fold opens it', () {
    final c = JsonEditingController(text: doc);
    final a = doc.indexOf('{', 1);
    c.toggleFold(a);
    c.selection = TextSelection.collapsed(offset: a + 5);
    expect(c.isFolded(a), isFalse);
  });

  testWidgets('folded span keeps the text length and collapses lines', (
    tester,
  ) async {
    final c = JsonEditingController(text: doc);
    late TextSpan span;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            c.foldAll();
            span = c.buildTextSpan(context: context, withComposing: false);
            return const SizedBox();
          },
        ),
      ),
    );
    var length = 0;
    var visibleNewlines = 0;
    span.visitChildren((s) {
      if (s is TextSpan && s.text != null) {
        length += s.text!.length;
        if (s.style?.fontSize != 0.01) {
          visibleNewlines += '\n'.allMatches(s.text!).length;
        }
      } else if (s is WidgetSpan) {
        length += 1;
      }
      return true;
    });
    expect(length, doc.length);
    // Root stays open, "a" and "d" are folded onto one line each.
    expect(visibleNewlines, 4);
  });
}
