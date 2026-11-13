import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/providers/moment_providers.dart';
import 'package:native_tavern/presentation/providers/moments_compose_draft_provider.dart';
import 'package:native_tavern/presentation/providers/persona_providers.dart';
import 'package:native_tavern/presentation/router/app_router.dart';
import 'package:native_tavern/presentation/screens/play/moments_palette.dart';
import 'package:native_tavern/presentation/widgets/common/desktop_caption.dart';

/// Full-page moments composer. Owned by go_router so play-hub switches can
/// replace it instead of stacking above the shell child.
class MomentsComposeScreen extends ConsumerStatefulWidget {
  const MomentsComposeScreen({super.key});

  @override
  ConsumerState<MomentsComposeScreen> createState() =>
      _MomentsComposeScreenState();
}

class _MomentsComposeScreenState extends ConsumerState<MomentsComposeScreen> {
  late final TextEditingController _controller;
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(momentsComposeDraftProvider);
    _controller = TextEditingController(text: draft?.body ?? '');
    _imagePath = draft?.imagePath;
    final path = _imagePath;
    if (path != null && path.isNotEmpty && !File(path).existsSync()) {
      _imagePath = null;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _hasContent =>
      _controller.text.trim().isNotEmpty ||
      (_imagePath != null && _imagePath!.isNotEmpty);

  /// Keep the draft slot current so leave guards see unsaved text.
  void _syncDraftSlot() {
    final drafts = ref.read(momentsComposeDraftProvider.notifier);
    if (_hasContent) {
      drafts.save(body: _controller.text, imagePath: _imagePath);
    } else {
      drafts.clear();
    }
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.playMoments);
    }
  }

  Future<void> _submit() async {
    if (!_hasContent) return;
    final l10n = AppLocalizations.of(context);
    final persona = ref.read(activePersonaProvider).asData?.value;
    final selfName = momentsPersonaName(persona, l10n.momentsAuthorMe);
    final service = ref.read(momentServiceProvider);

    await ref.read(momentsComposeDraftProvider.notifier).clear();

    final imagePath =
        _imagePath == null ? null : await service.importImage(_imagePath!);
    await service.publishPlayerPost(
      body: _controller.text.trim(),
      imagePath: imagePath,
      authorName: selfName,
    );
    ref.invalidate(pagedMomentFeedProvider);
    if (mounted) _leave();
  }

  Future<void> _pickPhoto() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image == null || !mounted) return;
    setState(() => _imagePath = image.path);
    _syncDraftSlot();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = MomentsPalette.of(context);
    final captionActive = DesktopCaptionScope.isActive(context);
    final topInset = captionActive
        ? DesktopCaptionScope.titleBarHeightOf(context)
        : MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: palette.cell,
      body: Column(
        children: [
          SizedBox(height: topInset),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
            child: Row(
              children: [
                TextButton(
                  onPressed: _leave,
                  child: Text(l10n.cancel),
                ),
                const Spacer(),
                FilledButton(
                  key: const Key('moments-compose-send'),
                  onPressed: _hasContent ? _submit : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: MomentsPalette.send,
                    disabledBackgroundColor: MomentsPalette.sendDisabled,
                    foregroundColor: MomentsPalette.onMedia,
                    disabledForegroundColor: MomentsPalette.onSendDisabled,
                  ),
                  child: Text(l10n.momentsCompose),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                TextField(
                  key: const Key('moments-compose-body'),
                  controller: _controller,
                  maxLines: 6,
                  onChanged: (_) {
                    setState(() {});
                    _syncDraftSlot();
                  },
                  decoration: InputDecoration(
                    hintText: l10n.momentsComposeHint,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _imagePath == null
                      ? InkWell(
                          key: const Key('moments-compose-photo'),
                          onTap: _pickPhoto,
                          child: Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              border: Border.all(color: palette.divider),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Icon(
                              Icons.add,
                              size: 36,
                              color: palette.time,
                            ),
                          ),
                        )
                      : GestureDetector(
                          key: const Key('moments-compose-photo'),
                          onTap: _pickPhoto,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: Image.file(
                              File(_imagePath!),
                              width: 96,
                              height: 96,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
