import 'package:native_tavern/data/models/ai_preset.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';

/// Localized display name / description for built-in AI presets.
extension AIPresetL10n on AIPreset {
  String localizedName(AppLocalizations l10n) {
    if (!isBuiltIn) return name;
    return switch (id) {
      'default' => l10n.aiPresetDefaultName,
      'creative' => l10n.aiPresetCreativeName,
      'precise' => l10n.aiPresetPreciseName,
      'deterministic' => l10n.aiPresetDeterministicName,
      'longform' => l10n.aiPresetLongFormName,
      'mirostat' => l10n.aiPresetMirostatName,
      _ => name,
    };
  }

  String? localizedDescription(AppLocalizations l10n) {
    if (!isBuiltIn) return description;
    return switch (id) {
      'default' => l10n.aiPresetDefaultDescription,
      'creative' => l10n.aiPresetCreativeDescription,
      'precise' => l10n.aiPresetPreciseDescription,
      'deterministic' => l10n.aiPresetDeterministicDescription,
      'longform' => l10n.aiPresetLongFormDescription,
      'mirostat' => l10n.aiPresetMirostatDescription,
      _ => description,
    };
  }
}
