// Dompat İndirici için temel widget testi.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yt_downloader/main.dart';

void main() {
  testWidgets('Ana ekran render testi', (WidgetTester tester) async {
    await tester.pumpWidget(const DompatApp());

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Dompat İndirici'), findsOneWidget);
  });
}
