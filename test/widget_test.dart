import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:global_mir/main.dart';
import 'package:global_mir/scoring.dart';

/// Taps the rating button [value] on the domain row named [domain].
Future<void> rate(WidgetTester tester, String domain, double value) async {
  final Finder row = find.ancestor(
    of: find.text(domain),
    matching: find.byType(DomainRow),
  );
  expect(row, findsOneWidget, reason: 'domain row for $domain');
  await tester.tap(find.descendant(of: row, matching: find.text(fmt(value))));
  await tester.pumpAndSettle();
}

/// The large global rating readout in the result panel.
String globalReadout(WidgetTester tester) {
  final Text t = tester.widget<Text>(find.descendant(
    of: find.byType(ResultPanel),
    matching: find.byWidgetPredicate((Widget w) =>
        w is Text &&
        w.style?.fontSize ==
            Typography.englishLike2021.displayMedium?.fontSize),
  ));
  return t.data!;
}

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const GlobalMirApp());
    await tester.pumpAndSettle();
  }

  testWidgets('starts with every domain at 0 and a global rating of 0',
      (WidgetTester tester) async {
    await pumpApp(tester);

    expect(find.byType(DomainRow), findsNWidgets(kDomains.length));
    expect(globalReadout(tester), '0');
    expect(find.text('All domains are 0.'), findsOneWidget);
    expect(find.text('Rule 1'), findsOneWidget);
  });

  testWidgets('rating one domain 0.5 gives a global rating of 0.5 by rule 2',
      (WidgetTester tester) async {
    await pumpApp(tester);
    await rate(tester, 'Memory', 0.5);

    expect(globalReadout(tester), '0.5');
    expect(find.text('Rule 2'), findsOneWidget);
  });

  testWidgets('a lone moderate domain gives a global rating of 1 by rule 3B',
      (WidgetTester tester) async {
    await pumpApp(tester);
    await rate(tester, 'Language', 2);

    expect(globalReadout(tester), '1');
    expect(find.text('Rule 3B'), findsOneWidget);
  });

  testWidgets('a unique maximum with another non-zero domain drops one level',
      (WidgetTester tester) async {
    await pumpApp(tester);
    await rate(tester, 'Language', 2);
    await rate(tester, 'Orientation', 0.5);

    expect(globalReadout(tester), '1');
    expect(find.text('Rule 3C'), findsOneWidget);
  });

  testWidgets('a repeated maximum keeps the global rating at that maximum',
      (WidgetTester tester) async {
    await pumpApp(tester);
    await rate(tester, 'Judgment and Problem Solving', 2);
    await rate(tester, 'Psychiatric Symptoms', 2);

    expect(globalReadout(tester), '2');
    expect(find.text('Rule 3D'), findsOneWidget);
  });

  testWidgets('the running sum tracks the domain ratings',
      (WidgetTester tester) async {
    await pumpApp(tester);
    expect(find.text('Sum of domain ratings'), findsOneWidget);

    await rate(tester, 'Memory', 3);
    await rate(tester, 'Home Life', 0.5);

    expect(
      find.descendant(of: find.byType(ResultPanel), matching: find.text('3.5')),
      findsOneWidget,
    );
  });

  testWidgets('reset returns every domain to 0', (WidgetTester tester) async {
    await pumpApp(tester);
    await rate(tester, 'Memory', 3);
    expect(globalReadout(tester), '1');

    await tester.tap(find.byTooltip('Reset all domains to 0'));
    await tester.pumpAndSettle();

    expect(globalReadout(tester), '0');
  });

  testWidgets('loading a published scenario scores it in the calculator',
      (WidgetTester tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Examples'));
    await tester.pumpAndSettle();
    expect(
      find.text('10 of 10 scenarios match the published global rating'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Scenario 10'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scenario 10'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(Chip, 'Scenario 10'), findsOneWidget);
    expect(globalReadout(tester), '3');
    expect(find.text('Rule 3D'), findsOneWidget);
  });

  testWidgets('the rules tab lists every rule and domain',
      (WidgetTester tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Rules'));
    await tester.pumpAndSettle();

    expect(find.text('Global rating rules'), findsOneWidget);
    for (final String id in <String>['1', '2', '3A', '3B', '3C', '3D']) {
      expect(find.text(id), findsWidgets, reason: 'rule $id');
    }
    for (int i = 0; i < kDomains.length; i++) {
      expect(find.text('${i + 1}. ${kDomains[i]}'), findsOneWidget);
    }
  });

  testWidgets('the result panel links to the terms, which open the About tab',
      (WidgetTester tester) async {
    await pumpApp(tester);

    final Finder link = find.text('Terms of use and disclaimer');
    expect(link, findsOneWidget);
    await tester.tap(link);
    await tester.pumpAndSettle();

    expect(find.byType(AboutTab), findsOneWidget);
    expect(find.text('Read before use'), findsOneWidget);
  });

  testWidgets('the About tab carries the disclaimer, privacy and licence terms',
      (WidgetTester tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();

    for (final String heading in <String>[
      'Read before use',
      'What this tool does',
      'Medical disclaimer',
      'Privacy: nothing leaves your browser',
      'No warranty',
      'References',
      'Version and source',
    ]) {
      await tester.scrollUntilVisible(find.text(heading), 200,
          scrollable: find.byType(Scrollable).last);
      expect(find.text(heading), findsOneWidget, reason: heading);
    }
  });

  testWidgets('the layout works at phone width', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const GlobalMirApp());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(DomainRow), findsWidgets);
  });
}
