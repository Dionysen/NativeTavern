import 'package:flutter/material.dart';
import 'package:native_tavern/presentation/widgets/common/app_viewport.dart';

/// Moves custom full-screen page actions to UIKit's preferred physical edge.
class AdaptiveScaffold extends StatefulWidget {
  const AdaptiveScaffold({
    super.key,
    required this.appBar,
    required this.body,
    this.appBarVisible = true,
  });

  final AppBar appBar;
  final Widget body;

  /// When false, the top app bar collapses (side controls stay on vertical-bar layouts).
  final bool appBarVisible;

  @override
  State<AdaptiveScaffold> createState() => _AdaptiveScaffoldState();
}

class _AdaptiveScaffoldState extends State<AdaptiveScaffold>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 200);

  late final AnimationController _hideController;

  @override
  void initState() {
    super.initState();
    _hideController = AnimationController(
      vsync: this,
      duration: _duration,
      value: widget.appBarVisible ? 0 : 1,
    );
  }

  @override
  void didUpdateWidget(covariant AdaptiveScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.appBarVisible == oldWidget.appBarVisible) return;
    if (widget.appBarVisible) {
      _hideController.reverse();
    } else {
      _hideController.forward();
    }
  }

  @override
  void dispose() {
    _hideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layout = WindowLayoutScope.maybeOf(context);
    final edge = layout?.verticalBarEdge;
    final sharedBar = layout != null && layout.barWidth > 0;
    final barWidth = sharedBar ? layout.barWidth : 56.0;
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final leading = widget.appBar.leading ??
        (widget.appBar.automaticallyImplyLeading && canPop
            ? const BackButton()
            : null);

    Widget controls() => ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: Padding(
            padding: sharedBar ? layout.barPadding : EdgeInsets.zero,
            child: SafeArea(
              top: !sharedBar,
              bottom: !sharedBar,
              left: !sharedBar,
              right: !sharedBar,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    if (leading != null) leading,
                    ...?widget.appBar.actions,
                  ],
                ),
              ),
            ),
          ),
        );

    return AnimatedBuilder(
      animation: _hideController,
      builder: (context, _) {
        final visibleFactor = 1.0 - _hideController.value;
        final topInset = MediaQuery.paddingOf(context).top;

        return Scaffold(
          appBar: edge == null
              ? PreferredSize(
                  preferredSize: Size.fromHeight(
                    widget.appBar.preferredSize.height * visibleFactor,
                  ),
                  child: ClipRect(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      heightFactor: visibleFactor,
                      child: widget.appBar,
                    ),
                  ),
                )
              : null,
          // Fixed element slots preserve the draft, focus, and message scroll
          // position as the native toolbar changes between horizontal/vertical.
          body: Row(
            textDirection: TextDirection.ltr,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: edge == VerticalBarEdge.left ? barWidth : 0,
                child: edge == VerticalBarEdge.left ? controls() : null,
              ),
              Expanded(
                child: Column(
                  children: [
                    SizedBox(
                      height: edge == null
                          ? 0
                          : (kToolbarHeight + topInset) * visibleFactor,
                      child: edge == null
                          ? null
                          : ClipRect(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                heightFactor: visibleFactor,
                                child: SizedBox(
                                  height: kToolbarHeight + topInset,
                                  child: AppBar(
                                    title: widget.appBar.title,
                                    automaticallyImplyLeading: false,
                                    backgroundColor:
                                        widget.appBar.backgroundColor,
                                    foregroundColor:
                                        widget.appBar.foregroundColor,
                                  ),
                                ),
                              ),
                            ),
                    ),
                    Expanded(child: widget.body),
                  ],
                ),
              ),
              SizedBox(
                width: edge == VerticalBarEdge.right ? barWidth : 0,
                child: edge == VerticalBarEdge.right ? controls() : null,
              ),
            ],
          ),
        );
      },
    );
  }
}
