import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_tavern/presentation/widgets/chat/chat_tail_scroll.dart';

void main() {
  testWidgets('sticks to max extent while followTail is true', (tester) async {
    final controller = ChatTailScrollController();
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
                children: [
                  const SizedBox(height: 800, child: Text('older')),
                  SizedBox(height: h, child: const Text('growing')),
                ],
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();

    final before = controller.offset;
    height.value = 400;
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(controller.position.maxScrollExtent, 0.5));
    expect(controller.offset, greaterThan(before));
  });

  testWidgets('keeps older content fixed when not following', (tester) async {
    final controller = ChatTailScrollController();
    controller.followTail = () => false;

    final height = ValueNotifier<double>(200);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<double>(
            valueListenable: height,
            builder: (context, h, _) {
              return ListView(
                controller: controller,
                children: [
                  const SizedBox(height: 800, child: Text('older')),
                  SizedBox(height: h, child: const Text('growing')),
                ],
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Park away from the tail.
    controller.jumpTo(120);
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(120, 0.5));

    height.value = 400;
    await tester.pumpAndSettle();
    // Non-reverse default keeps pixels — no yank to the tail.
    expect(controller.offset, closeTo(120, 1.0));
  });

  testWidgets('resumes stick after returning to bottom', (tester) async {
    final controller = ChatTailScrollController();
    // Zephyr: followTail is interaction-only; distanceFromEnd gates stick.
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
                children: [
                  const SizedBox(height: 800, child: Text('older')),
                  SizedBox(height: h, child: const Text('growing')),
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
    expect(controller.offset, closeTo(150, 1.0));

    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();
    height.value = 500;
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(controller.position.maxScrollExtent, 0.5));
  });
}
