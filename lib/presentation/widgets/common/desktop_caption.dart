import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:native_tavern/presentation/theme/native_tavern_theme.dart';

/// Windows immersive caption. Inactive on every other platform, and inactive
/// in tests, because the runner must answer [immersiveTitleBar] first.
class DesktopCaptionScope extends InheritedWidget {
  const DesktopCaptionScope({
    super.key,
    required this.active,
    required super.child,
  });

  final bool active;

  static bool isActive(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<DesktopCaptionScope>();
    return scope?.active ?? false;
  }

  @override
  bool updateShouldNotify(DesktopCaptionScope oldWidget) =>
      active != oldWidget.active;
}

abstract final class DesktopCaptionMetrics {
  static const double buttonWidth = 46;
  static const double stripWidth = buttonWidth * 3;
}

/// Turns the top toolbar band into the window title bar on Windows.
///
/// Min, max, and close stay system buttons (reported back to the window) so
/// snap layouts keep working. Empty space in the band drags the window.
class DesktopCaptionHost extends StatefulWidget {
  const DesktopCaptionHost({super.key, required this.child});

  final Widget child;

  @override
  State<DesktopCaptionHost> createState() => _DesktopCaptionHostState();
}

class _DesktopCaptionHostState extends State<DesktopCaptionHost> {
  static const _channel = MethodChannel('native_tavern/window');
  static const _dragSlop = 4.0;

  final _minimizeKey = GlobalKey();
  final _maximizeKey = GlobalKey();
  final _closeKey = GlobalKey();

  bool _active = false;
  bool _maximized = false;
  int? _pointer;
  Offset? _down;
  bool _dragging = false;
  DateTime? _lastTapAt;
  Offset? _lastTapPosition;

  bool get _windows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  @override
  void initState() {
    super.initState();
    if (!_windows) return;
    _channel.setMethodCallHandler(_onMethodCall);
    _enable();
  }

  @override
  void dispose() {
    if (_windows) {
      _channel.setMethodCallHandler(null);
    }
    super.dispose();
  }

  Future<void> _onMethodCall(MethodCall call) async {
    if (call.method == 'windowState' && mounted) {
      setState(() => _maximized = call.arguments == true);
    }
  }

  Future<void> _enable() async {
    try {
      final enabled = await _channel.invokeMethod<bool>('immersiveTitleBar');
      if (!mounted || enabled != true) return;
      setState(() => _active = true);
      _scheduleReport();
    } on MissingPluginException {
      // Widget tests and runners without the caption hook keep the system bar.
    } catch (_) {}
  }

  void _scheduleReport() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _active) _reportButtons();
    });
  }

  Future<void> _reportButtons() async {
    List<double>? rect(GlobalKey key) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached || !box.hasSize) return null;
      final topLeft = box.localToGlobal(Offset.zero);
      final dpr = MediaQuery.devicePixelRatioOf(context);
      final size = box.size;
      return [
        topLeft.dx * dpr,
        topLeft.dy * dpr,
        (topLeft.dx + size.width) * dpr,
        (topLeft.dy + size.height) * dpr,
      ];
    }

    final minimize = rect(_minimizeKey);
    final maximize = rect(_maximizeKey);
    final close = rect(_closeKey);
    if (minimize == null || maximize == null || close == null) return;
    try {
      await _channel.invokeMethod<void>('setCaptionButtons', {
        'min': minimize,
        'max': maximize,
        'close': close,
      });
    } catch (_) {}
  }

  bool _onControl(Offset global) {
    try {
      final result = HitTestResult();
      GestureBinding.instance.hitTestInView(
        result,
        global,
        View.of(context).viewId,
      );
      for (final entry in result.path) {
        final target = entry.target;
        if (target is RenderEditable) return true;
        if (target is RenderSemanticsAnnotations) {
          final props = target.properties;
          if (props.button == true ||
              props.link == true ||
              props.textField == true ||
              props.slider == true) {
            return true;
          }
        }
      }
    } catch (_) {
      return false;
    }
    return false;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (!_active || event.position.dy >= kToolbarHeight) return;
    if (event.buttons != kPrimaryButton) return;
    if (_onControl(event.position)) return;
    _pointer = event.pointer;
    _down = event.position;
    _dragging = false;
  }

  void _onPointerMove(PointerMoveEvent event) {
    final down = _down;
    if (!_active || event.pointer != _pointer || down == null || _dragging) {
      return;
    }
    if ((event.position - down).distance < _dragSlop) return;
    _dragging = true;
    _lastTapAt = null;
    _invoke('startDragging');
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer != _pointer) return;
    final down = _down;
    final dragged = _dragging;
    _pointer = null;
    _down = null;
    _dragging = false;
    if (!_active || down == null || dragged) return;
    final now = DateTime.now();
    final last = _lastTapAt;
    final lastPosition = _lastTapPosition;
    if (last != null &&
        lastPosition != null &&
        now.difference(last) < const Duration(milliseconds: 350) &&
        (event.position - lastPosition).distance < 8) {
      _lastTapAt = null;
      _lastTapPosition = null;
      _invoke('toggleMaximize');
      return;
    }
    _lastTapAt = now;
    _lastTapPosition = event.position;
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    _down = null;
    _dragging = false;
  }

  Future<void> _invoke(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (!_windows) {
      return DesktopCaptionScope(active: false, child: widget.child);
    }

    final theme = Theme.of(context);
    final themed = _active
        ? theme.copyWith(
            appBarTheme: theme.appBarTheme.copyWith(
              actionsPadding: const EdgeInsetsDirectional.only(
                end: ChromeControls.appBarActionsEndPadding +
                    DesktopCaptionMetrics.stripWidth,
              ),
            ),
          )
        : theme;

    return DesktopCaptionScope(
      active: _active,
      child: Theme(
        data: themed,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Listener(
              behavior: HitTestBehavior.deferToChild,
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUp,
              onPointerCancel: _onPointerCancel,
              child: widget.child,
            ),
            if (_active)
              Positioned(
                top: 0,
                right: 0,
                child: _CaptionButtons(
                  minimizeKey: _minimizeKey,
                  maximizeKey: _maximizeKey,
                  closeKey: _closeKey,
                  maximized: _maximized,
                  onReport: _scheduleReport,
                  onMinimize: () => _invoke('minimize'),
                  onMaximize: () => _invoke('toggleMaximize'),
                  onClose: () => _invoke('close'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CaptionButtons extends StatefulWidget {
  const _CaptionButtons({
    required this.minimizeKey,
    required this.maximizeKey,
    required this.closeKey,
    required this.maximized,
    required this.onReport,
    required this.onMinimize,
    required this.onMaximize,
    required this.onClose,
  });

  final GlobalKey minimizeKey;
  final GlobalKey maximizeKey;
  final GlobalKey closeKey;
  final bool maximized;
  final VoidCallback onReport;
  final VoidCallback onMinimize;
  final VoidCallback onMaximize;
  final VoidCallback onClose;

  @override
  State<_CaptionButtons> createState() => _CaptionButtonsState();
}

class _CaptionButtonsState extends State<_CaptionButtons> {
  @override
  void initState() {
    super.initState();
    widget.onReport();
  }

  @override
  void didUpdateWidget(covariant _CaptionButtons oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.onReport();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    // These buttons sit above the navigator, so tooltips (which need an
    // Overlay) cannot be used here. The label stays on the button itself.
    return Material(
      type: MaterialType.transparency,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CaptionButton(
            buttonKey: widget.minimizeKey,
            icon: Icons.remove,
            tooltip:
                _captionLabel(context, hans: '最小化', hant: '最小化', en: 'Minimize'),
            color: color,
            onPressed: widget.onMinimize,
          ),
          _CaptionButton(
            buttonKey: widget.maximizeKey,
            icon: widget.maximized ? Icons.filter_none : Icons.crop_square,
            tooltip: widget.maximized
                ? _captionLabel(context, hans: '还原', hant: '還原', en: 'Restore')
                : _captionLabel(
                    context, hans: '最大化', hant: '最大化', en: 'Maximize'),
            color: color,
            onPressed: widget.onMaximize,
          ),
          _CaptionButton(
            buttonKey: widget.closeKey,
            icon: Icons.close,
            tooltip:
                _captionLabel(context, hans: '关闭', hant: '關閉', en: 'Close'),
            color: color,
            onPressed: widget.onClose,
          ),
        ],
      ),
    );
  }
}

class _CaptionButton extends StatelessWidget {
  const _CaptionButton({
    required this.buttonKey,
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onPressed,
  });

  final GlobalKey buttonKey;
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: SizedBox(
        key: buttonKey,
        width: DesktopCaptionMetrics.buttonWidth,
        height: kToolbarHeight,
        child: InkWell(
          onTap: onPressed,
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

String _captionLabel(
  BuildContext context, {
  required String hans,
  required String hant,
  required String en,
}) {
  final locale = Localizations.localeOf(context);
  if (locale.languageCode != 'zh') return en;
  final traditional = locale.scriptCode == 'Hant' ||
      locale.countryCode == 'TW' ||
      locale.countryCode == 'HK' ||
      locale.countryCode == 'MO';
  return traditional ? hant : hans;
}
