import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_tavern/presentation/widgets/chat/chat_tail_scroll.dart';

void main() {
  testWidgets('reverse tail sticks while followTail is true', (tester) async {
    final controller = ChatTailScrollController(reverse: true);
    var follow = true;
    controller.followTail = () => follow;

    final height = ValueNotifier<double>(200);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<double>(
            valueListenable: height,
            builder: (context, h, _) {
              return ListView(
                controller: controller,
                reverse: true,
                children: [
                  SizedBox(height: h, child: const Text('growing')),
                  const SizedBox(height: 800, child: Text('older')),
                ],
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(controller.offset, closeTo(0, 0.5));

    height.value = 400;
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(0, 0.5));

    // Scroll away from the bottom (reverse: higher offset = older content).
    follow = false;
    controller.jumpTo(120);
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(120, 0.5));

    height.value = 600;
    await tester.pumpAndSettle();
    // Must not yank back to the tail while followTail is false.
    expect(controller.offset, greaterThan(50));
  });

  testWidgets('reverse tail resumes stick after returning to bottom',
      (tester) async {
    final controller = ChatTailScrollController(reverse: true);
    controller.followTail = () => true;

    final height = ValueNotifier<double>(200);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<double>(
            valueListenable: height,
            builder: (context, h, _) {
              return ListView(
                controller: controller,
                reverse: true,
                children: [
                  SizedBox(height: h, child: const Text('growing')),
                  const SizedBox(height: 800, child: Text('older')),
                ],
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    controller.jumpTo(150);
    await tester.pumpAndSettle();
    height.value = 350;
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(50));

    controller.jumpTo(0);
    await tester.pumpAndSettle();
    height.value = 500;
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(0, 0.5));
  });
}
