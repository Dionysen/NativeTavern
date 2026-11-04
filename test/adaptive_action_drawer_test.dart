import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_tavern/presentation/widgets/common/adaptive_action_drawer.dart';

void main() {
  testWidgets('AdaptiveActionMenuButton opens drawer and selects action',
      (tester) async {
    String? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AdaptiveActionMenuButton<String>(
              tooltip: 'More',
              onSelected: (value) => selected = value,
              itemBuilder: (context) => const [
                AdaptiveActionDrawerItem(
                  value: 'load',
                  leading: Icon(Icons.list),
                  title: Text('Load'),
                ),
                AdaptiveActionDrawerItem(
                  value: 'delete',
                  leading: Icon(Icons.delete_outline),
                  title: Text('Delete'),
                  destructive: true,
                  showDividerAbove: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Load'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(selected, 'delete');
  });
}
