import 'package:flutter/material.dart';
import 'package:inf_orc_kit/inf_orc_kit.dart';
import 'package:flutter_test/flutter_test.dart';

DocumentQuad _full300() => DocumentQuad(
      topLeft: Offset.zero,
      topRight: const Offset(300, 0),
      bottomRight: const Offset(300, 300),
      bottomLeft: const Offset(0, 300),
    );

void main() {
  testWidgets('dragging a corner handle reports updated quad',
      (tester) async {
    DocumentQuad? reported;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          height: 300,
          child: QuadEditor(
            imageSize: const Size(300, 300),
            quad: _full300(),
            onChanged: (q) => reported = q,
          ),
        ),
      ),
    ));

    // Grab the top-left handle and drag it inward (positions derived
    // from the laid-out widget so contain-fit scaling can't break us).
    final origin = tester.getTopLeft(find.byType(QuadEditor));
    final gesture = await tester.startGesture(origin + const Offset(5, 5));
    await gesture.moveTo(origin + const Offset(60, 40));
    await gesture.up();
    await tester.pump();

    expect(reported, isNotNull);
    // The corner jumps to the drop point: display (60, 40) mapped back
    // into image pixels (scale derived from laid-out size).
    final boxSize = tester.getSize(find.byType(QuadEditor));
    final s = boxSize.width / 300;
    expect(reported!.topLeft.dx, closeTo(60 / s, 0.5));
    expect(reported!.topLeft.dy, closeTo(40 / s, 0.5));
    // Other corners untouched.
    expect(reported!.bottomRight, const Offset(300, 300));
  });

  testWidgets('tap far from handles reports nothing', (tester) async {
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          height: 300,
          child: QuadEditor(
            imageSize: const Size(300, 300),
            quad: _full300(),
            onChanged: (_) => calls++,
          ),
        ),
      ),
    ));

    await tester.tapAt(tester.getCenter(find.byType(QuadEditor)));
    await tester.pump();
    expect(calls, 0);
  });
}
