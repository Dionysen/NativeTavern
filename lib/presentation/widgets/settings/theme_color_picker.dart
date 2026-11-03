import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/native_tavern_theme.dart';

/// Opens an HSV color panel. Returns the chosen opaque color, or `null`.
Future<Color?> showThemeColorPicker(
  BuildContext context, {
  required Color initialColor,
  String? title,
  String? cancelLabel,
  String? doneLabel,
}) {
  return showDialog<Color>(
    context: context,
    builder: (context) => _ThemeColorPickerDialog(
      initialColor: initialColor,
      title: title,
      cancelLabel: cancelLabel,
      doneLabel: doneLabel,
    ),
  );
}

class _ThemeColorPickerDialog extends StatefulWidget {
  const _ThemeColorPickerDialog({
    required this.initialColor,
    this.title,
    this.cancelLabel,
    this.doneLabel,
  });

  final Color initialColor;
  final String? title;
  final String? cancelLabel;
  final String? doneLabel;

  @override
  State<_ThemeColorPickerDialog> createState() =>
      _ThemeColorPickerDialogState();
}

class _ThemeColorPickerDialogState extends State<_ThemeColorPickerDialog> {
  late HSVColor _hsv;
  late final TextEditingController _hex;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.initialColor.withValues(alpha: 1));
    _hex = TextEditingController(text: _hexOf(_hsv.toColor()));
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  void _setHsv(HSVColor next) {
    setState(() {
      _hsv = next;
      final text = _hexOf(next.toColor());
      if (_hex.text.toUpperCase() != text) {
        _hex.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      }
    });
  }

  void _setFromHex(String raw) {
    final parsed = _parseHex(raw);
    if (parsed == null) return;
    setState(() {
      _hsv = HSVColor.fromColor(Color(parsed));
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = context.appCornerRadius;
    final color = _hsv.toColor();
    final l10n = MaterialLocalizations.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      title: Text(widget.title ?? 'Color'),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: _SaturationValuePanel(
                hsv: _hsv,
                onChanged: _setHsv,
              ),
            ),
            const SizedBox(height: 16),
            _HueBar(
              hue: _hsv.hue,
              onChanged: (hue) => _setHsv(_hsv.withHue(hue)),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(radius * 0.6),
                    border: Border.all(color: theme.colorScheme.outline),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _hex,
                    maxLength: 7,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[#0-9a-fA-F]'),
                      ),
                    ],
                    decoration: const InputDecoration(
                      counterText: '',
                      hintText: '#RRGGBB',
                      isDense: true,
                    ),
                    onChanged: _setFromHex,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.cancelLabel ?? l10n.cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(color),
          child: Text(widget.doneLabel ?? l10n.okButtonLabel),
        ),
      ],
    );
  }
}

class _SaturationValuePanel extends StatelessWidget {
  const _SaturationValuePanel({
    required this.hsv,
    required this.onChanged,
  });

  final HSVColor hsv;
  final ValueChanged<HSVColor> onChanged;

  void _update(Offset local, Size size) {
    final s = (local.dx / size.width).clamp(0.0, 1.0);
    final v = 1.0 - (local.dy / size.height).clamp(0.0, 1.0);
    onChanged(hsv.withSaturation(s).withValue(v));
  }

  @override
  Widget build(BuildContext context) {
    final radius = context.appCornerRadius;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: GestureDetector(
            onPanDown: (d) => _update(d.localPosition, size),
            onPanUpdate: (d) => _update(d.localPosition, size),
            child: CustomPaint(
              painter: _SvPainter(hue: hsv.hue),
              child: Stack(
                children: [
                  Positioned(
                    left: hsv.saturation * size.width - 8,
                    top: (1 - hsv.value) * size.height - 8,
                    child: IgnorePointer(
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: hsv.toColor(),
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x66000000),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SvPainter extends CustomPainter {
  const _SvPainter({required this.hue});

  final double hue;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final hueColor = HSVColor.fromAHSV(1, hue, 1, 1).toColor();
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [Colors.white, hueColor],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _SvPainter oldDelegate) =>
      oldDelegate.hue != hue;
}

class _HueBar extends StatelessWidget {
  const _HueBar({required this.hue, required this.onChanged});

  final double hue;
  final ValueChanged<double> onChanged;

  void _update(Offset local, double width) {
    onChanged(((local.dx / width) * 360).clamp(0.0, 359.9));
  }

  @override
  Widget build(BuildContext context) {
    final radius = context.appCornerRadius;
    return SizedBox(
      height: 28,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return GestureDetector(
            onPanDown: (d) => _update(d.localPosition, width),
            onPanUpdate: (d) => _update(d.localPosition, width),
            child: CustomPaint(
              painter: _HuePainter(radius: radius),
              child: Stack(
                children: [
                  Positioned(
                    left: (hue / 360) * width - 7,
                    top: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      child: Center(
                        child: Container(
                          width: 14,
                          height: 28,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x66000000),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HuePainter extends CustomPainter {
  const _HuePainter({required this.radius});

  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.clipRRect(rrect);
    final colors = List<Color>.generate(
      7,
      (i) => HSVColor.fromAHSV(1, i * 60.0, 1, 1).toColor(),
    );
    canvas.drawRect(
      rect,
      Paint()..shader = LinearGradient(colors: colors).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _HuePainter oldDelegate) =>
      oldDelegate.radius != radius;
}

String _hexOf(Color color) {
  final value = color.toARGB32() & 0xFFFFFF;
  return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

int? _parseHex(String value) {
  final match = RegExp(r'^#?([0-9a-fA-F]{6})$').firstMatch(value.trim());
  return match == null
      ? null
      : 0xFF000000 | int.parse(match.group(1)!, radix: 16);
}
