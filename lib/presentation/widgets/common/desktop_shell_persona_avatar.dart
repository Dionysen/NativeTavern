import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_tavern/data/models/persona.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/providers/persona_providers.dart';
import 'package:native_tavern/presentation/router/app_router.dart';
import 'package:native_tavern/presentation/router/shell_navigation.dart';
import 'package:native_tavern/presentation/widgets/common/desktop_caption.dart';

/// Visual size of the rail caption avatar (fixed; independent of title-bar height).
const double _railCaptionAvatarDiameter = 38;

/// Active persona shortcut in the navigation rail caption strip (three-pane).
class DesktopShellPersonaAvatar extends ConsumerStatefulWidget {
  const DesktopShellPersonaAvatar({
    super.key,
    required this.titleBarHeight,
    required this.railOnLeadingEdge,
  });

  final double titleBarHeight;
  final bool railOnLeadingEdge;

  @override
  ConsumerState<DesktopShellPersonaAvatar> createState() =>
      _DesktopShellPersonaAvatarState();
}

class _DesktopShellPersonaAvatarState
    extends ConsumerState<DesktopShellPersonaAvatar> {
  final _avatarKey = GlobalKey();

  bool get _macLeadingRail =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.macOS &&
      widget.railOnLeadingEdge &&
      DesktopCaptionScope.isActive(context);

  void _openPopover() {
    final box = _avatarKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final anchor = box.localToGlobal(Offset.zero) & box.size;
    final persona = ref.read(activePersonaProvider).valueOrNull;
    final capturedContext = context;
    showDesktopShellPersonaPopover(
      context: capturedContext,
      anchor: anchor,
      persona: persona,
      railOnLeadingEdge: widget.railOnLeadingEdge,
      onOpenSettings: () {
        Navigator.of(capturedContext, rootNavigator: true).pop();
        capturedContext.openShell(AppRoutes.personas);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final personaAsync = ref.watch(activePersonaProvider);
    const diameter = _railCaptionAvatarDiameter;

    Widget avatarBody(Persona? persona) {
      return _PersonaAvatarCircle(persona: persona, diameter: diameter);
    }

    final child = personaAsync.when(
      loading: () => _PersonaAvatarCircle(
        persona: null,
        diameter: diameter,
        loading: true,
      ),
      error: (_, __) => avatarBody(null),
      data: avatarBody,
    );

    final button = Semantics(
      button: true,
      label: l10n.personas,
      child: Tooltip(
        message: l10n.personas,
        child: Material(
          key: _avatarKey,
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _openPopover,
            child: Padding(
              padding: const EdgeInsets.all(1),
              child: child,
            ),
          ),
        ),
      ),
    );

    return SizedBox(
      height: widget.titleBarHeight,
      width: double.infinity,
      child: _macLeadingRail
          ? Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: 2),
                child: button,
              ),
            )
          : Center(child: button),
    );
  }
}

class _PersonaAvatarCircle extends StatelessWidget {
  const _PersonaAvatarCircle({
    required this.persona,
    required this.diameter,
    this.loading = false,
  });

  final Persona? persona;
  final double diameter;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = diameter / 2;

    if (loading) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: scheme.surfaceContainerHighest,
        child: Icon(
          Icons.person_outline,
          size: diameter * 0.55,
          color: scheme.onSurfaceVariant,
        ),
      );
    }

    final name = persona?.name ?? '';
    final initial =
        name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'U';
    ImageProvider? image;
    final path = persona?.avatarPath;
    if (path != null && path.isNotEmpty && !kIsWeb) {
      final file = File(path);
      if (file.existsSync()) {
        image = FileImage(file);
      }
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      backgroundImage: image,
      child: image == null
          ? Text(
              initial,
              style: TextStyle(
                fontSize: diameter * 0.44,
                fontWeight: FontWeight.w600,
                color: scheme.onPrimaryContainer,
              ),
            )
          : null,
    );
  }
}

/// Compact persona summary card anchored to the rail avatar.
void showDesktopShellPersonaPopover({
  required BuildContext context,
  required Rect anchor,
  required Persona? persona,
  required bool railOnLeadingEdge,
  required VoidCallback onOpenSettings,
}) {
  final l10n = AppLocalizations.of(context);
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  final media = MediaQuery.of(context);
  const cardWidth = 300.0;
  const gap = 6.0;

  const estimatedCardHeight = 220.0;
  var top = anchor.bottom + gap;
  if (top + estimatedCardHeight > media.size.height - 8) {
    top = anchor.top - estimatedCardHeight - gap;
  }
  top = top.clamp(8.0, media.size.height - estimatedCardHeight - 8);

  var left = railOnLeadingEdge
      ? anchor.right - cardWidth
      : anchor.center.dx - cardWidth / 2;
  if (left + cardWidth > media.size.width - 8) {
    left = media.size.width - cardWidth - 8;
  }
  if (left < 8) left = 8;

  final name = persona?.name ?? l10n.default_;
  final description = persona?.description.trim() ?? '';

  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.12),
    pageBuilder: (_, __, ___) => const SizedBox.shrink(),
    transitionBuilder: (dialogContext, animation, _, __) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return FadeTransition(
        opacity: curved,
        child: Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              width: cardWidth,
              child: ScaleTransition(
                alignment: railOnLeadingEdge
                    ? Alignment.topLeft
                    : Alignment.topRight,
                scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
                child: Material(
                  elevation: 6,
                  shadowColor: Colors.black.withValues(alpha: 0.2),
                  color: scheme.surfaceContainerHigh,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: scheme.outlineVariant.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _PersonaAvatarCircle(
                              persona: persona,
                              diameter: 72,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            description,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        FilledButton(
                          onPressed: onOpenSettings,
                          child: Text(l10n.personas),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
