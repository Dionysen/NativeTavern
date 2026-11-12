import 'package:flutter/material.dart';
import 'package:native_tavern/presentation/widgets/common/app_viewport.dart';
import 'package:native_tavern/presentation/widgets/common/desktop_caption.dart';
import 'package:native_tavern/presentation/widgets/common/desktop_layout.dart';

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
  static const _leadingWidth = 56.0;

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
    // In wide three-pane, chat sits in the secondary column — use a normal
    // in-pane AppBar (no iOS shared vertical-bar chrome, no back-to-list).
    final threePane = ThreePaneScope.isActive(context);
    final edge = threePane ? null : layout?.verticalBarEdge;
    final sharedBar =
        !threePane && layout != null && layout.barWidth > 0;
    final barWidth = sharedBar ? layout.barWidth : 56.0;
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final captionInset = DesktopCaptionScope.leadingInsetOf(context);
    final captionActive = DesktopCaptionScope.isActive(context);
    final leading = threePane
        ? null
        : widget.appBar.leading ??
            (widget.appBar.automaticallyImplyLeading && canPop
                ? const BackButton()
                : null);

    Widget controls() => ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: Padding(
            padding: sharedBar ? layout.barPadding : EdgeInsets.zero,
            child: SafeArea(
              top: !sharedBar && !captionActive,
              bottom: !sharedBar,
              left: !sharedBar,
              right: !sharedBar,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    if (captionActive)
                      SizedBox(
                        height: DesktopCaptionScope.titleBarHeightOf(context),
                      ),
                    if (leading != null) leading,
                    ...?widget.appBar.actions,
                  ],
                ),
              ),
            ),
          ),
        );

    // Prefer an explicit leading inset over ambient MediaQuery.padding.left:
    // PreferredSize/ClipRect chrome around this AppBar does not always keep
    // SafeArea clear of macOS traffic lights, and double-padding would shove
    // the title too far right.
    final topAppBar = threePane
        ? AppBar(
            title: widget.appBar.title,
            actions: widget.appBar.actions,
            backgroundColor: widget.appBar.backgroundColor,
            foregroundColor: widget.appBar.foregroundColor,
            automaticallyImplyLeading: false,
          )
        : AppBar(
            leading: leading == null
                ? null
                : captionInset > 0
                    ? Padding(
                        padding: EdgeInsetsDirectional.only(start: captionInset),
                        child: leading,
                      )
                    : leading,
            leadingWidth: leading != null && captionInset > 0
                ? (widget.appBar.leadingWidth ??
                        Theme.of(context).appBarTheme.leadingWidth ??
                        _leadingWidth) +
                    captionInset
                : widget.appBar.leadingWidth,
            automaticallyImplyLeading: false,
            title: widget.appBar.title,
            actions: widget.appBar.actions,
            backgroundColor: widget.appBar.backgroundColor,
            foregroundColor: widget.appBar.foregroundColor,
          );

    Widget appBarChild = topAppBar;
    if (captionInset > 0) {
      final media = MediaQuery.of(context);
      appBarChild = MediaQuery(
        data: media.copyWith(
          padding: media.padding.copyWith(left: 0),
        ),
        child: topAppBar,
      );
    }

    return AnimatedBuilder(
      animation: _hideController,
      builder: (context, _) {
        final visibleFactor = 1.0 - _hideController.value;
        final topInset = MediaQuery.paddingOf(context).top;

        return Scaffold(
          appBar: edge == null
              ? PreferredSize(
                  preferredSize: Size.fromHeight(
                    topAppBar.preferredSize.height * visibleFactor,
                  ),
                  child: ClipRect(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      heightFactor: visibleFactor,
                      child: appBarChild,
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
                    Expanded(
                      child: captionInset > 0
                          ? MediaQuery(
                              data: MediaQuery.of(context).copyWith(
                                padding: MediaQuery.of(context)
                                    .padding
                                    .copyWith(left: 0),
                              ),
                              child: widget.body,
                            )
                          : widget.body,
                    ),
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
