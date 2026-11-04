import 'package:flutter/widgets.dart';

/// Scroll controller that can pin to the chat "tail" (newest messages) while
/// content grows during streaming — ported from Zephyr's AI chat view.
///
/// When [reverse] is true (NativeTavern message list), the visual bottom is
/// [ScrollPosition.minScrollExtent] (typically 0). When false, the bottom is
/// [ScrollPosition.maxScrollExtent].
class ChatTailScrollController extends ScrollController {
  ChatTailScrollController({this.reverse = true});

  /// Whether the owning [ListView] / [ScrollView] uses `reverse: true`.
  final bool reverse;

  /// When true, dimension growth keeps the viewport glued to the tail.
  bool Function() followTail = () => false;

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return ChatTailScrollPosition(
      physics: physics,
      context: context,
      oldPosition: oldPosition,
      reverse: reverse,
      followTail: () => followTail(),
    );
  }
}

/// Pins to the newest-message edge when [followTail] is active and the user
/// was already at that edge before content grew.
class ChatTailScrollPosition extends ScrollPositionWithSingleContext {
  ChatTailScrollPosition({
    required super.physics,
    required super.context,
    super.oldPosition,
    required this.reverse,
    required this.followTail,
  });

  final bool reverse;
  final bool Function() followTail;

  @override
  bool correctForNewDimensions(
    ScrollMetrics oldPosition,
    ScrollMetrics newPosition,
  ) {
    final distanceFromBottom = reverse
        ? oldPosition.pixels - oldPosition.minScrollExtent
        : oldPosition.maxScrollExtent - oldPosition.pixels;
    // A thumb-drag jumpTo runs before this correction, while [oldPosition]
    // can still be the pre-jump metrics parked at the end. Only keep the tail
    // when the live offset has not moved away from that end.
    final pixelsUnchanged = (pixels - oldPosition.pixels).abs() <= 1;
    final stick = followTail() && distanceFromBottom <= 1 && pixelsUnchanged;
    if (!stick) {
      return super.correctForNewDimensions(oldPosition, newPosition);
    }
    final target =
        reverse ? newPosition.minScrollExtent : newPosition.maxScrollExtent;
    if ((target - pixels).abs() <= 0.5) return true;
    correctPixels(target);
    return false;
  }
}
