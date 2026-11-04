import 'package:flutter/widgets.dart';

/// Scroll controller that pins to the chat tail while content grows during
/// streaming — matched to Zephyr's `_AiChatTailScrollController`.
///
/// Expects a **non-reverse** scroll view where the newest messages sit at
/// [ScrollPosition.maxScrollExtent]. Keeping [pixels] unchanged while scrolled
/// up naturally freezes the viewport; sticking only runs when already at the
/// end.
class ChatTailScrollController extends ScrollController {
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
      followTail: () => followTail(),
    );
  }
}

/// Pins to [ScrollMetrics.maxScrollExtent] when [followTail] is active and the
/// user was already at that edge before content grew.
class ChatTailScrollPosition extends ScrollPositionWithSingleContext {
  ChatTailScrollPosition({
    required super.physics,
    required super.context,
    super.oldPosition,
    required this.followTail,
  });

  final bool Function() followTail;

  @override
  bool correctForNewDimensions(
    ScrollMetrics oldPosition,
    ScrollMetrics newPosition,
  ) {
    final distanceFromEnd = oldPosition.maxScrollExtent - oldPosition.pixels;
    // A thumb-drag jumpTo runs before this correction, while [oldPosition]
    // can still be the pre-jump metrics parked at the end. Only keep the tail
    // when the live offset has not moved away from that end.
    final pixelsUnchanged = (pixels - oldPosition.pixels).abs() <= 1;
    final stick = followTail() && distanceFromEnd <= 1 && pixelsUnchanged;
    if (!stick) {
      return super.correctForNewDimensions(oldPosition, newPosition);
    }
    final target = newPosition.maxScrollExtent;
    if ((target - pixels).abs() <= 0.5) return true;
    correctPixels(target);
    return false;
  }
}
