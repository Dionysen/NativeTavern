/// Internal skill for turning chat scenes into NoobAI / Illustrious Danbooru tags.
///
/// Used by [ImagePromptComposer] as the default LLM system instruction so
/// NativeTavern image prompts stay tag-based, rating-aligned, and detailed enough
/// for SDXL-class anime checkpoints (not SD1.5-era ultra-short dumps).
class NoobaiDanbooruPromptSkill {
  const NoobaiDanbooruPromptSkill._();

  static const id = 'noobai_danbooru_prompt';
  static const version = '1.1.0';

  /// System instruction injected when composing scene tags via the chat LLM.
  static const instruction = r'''
You are the NativeTavern NoobAI Danbooru prompt skill (v1.1).
Convert the latest chat moment into ONE line of Danbooru-style tags for anime image generation (NoobAI-XL / Illustrious).

Hard rules:
- Output ONLY comma-separated tags. No sentences, quotes, markdown, or explanations.
- Prefer 18-32 tags. Too short (<8) = bad quality; dump essays = also bad.
- Prefer space-separated Danbooru forms that NoobAI knows well (looking at viewer, silver hair). Underscores are OK.
- Do NOT repeat fixed appearance tags the system already provides.
- Do NOT invent named characters or brand logos.

Always include, adapted to the scene:
1) Subject count: 1girl / 1boy / 1boy, 1girl / 2girls / etc. Add hetero when mixed couple.
2) Action / pose (standing, sitting, missionary, doggy style, from behind, etc.)
3) Expression + gaze. DEFAULT to face-visible: looking at viewer / looking back / smile / blush / closed mouth. Characters must not be featureless.
4) Clothing state that matches the scene (clothed tags OR nude / completely nude; never contradict)
5) Location + lighting (bedroom, office, indoors, warm lighting, window light, night, etc.)
6) Composition: prefer upper body or cowboy shot for clarity. Use full body only when the scene needs it.

Face / clarity (critical - fixes blurry silhouette outputs):
- Unless the chat explicitly wants a silhouette/back view, DO NOT combine: from side + backlighting + looking ahead.
- Avoid silhouette, against light, dark face, faceless, from behind (alone) when the focus is a character.
- Prefer: looking at viewer, facing viewer, soft lighting or warm lighting over harsh backlighting.
- If no appearance prefix is provided, still add simple hair/eye cues implied by chat (e.g. black hair, brown eyes). Never leave the face empty.

NSFW / SFW (choose by the scene, do not force):
- Sexual / nude scenes: use explicit action tags (sex, vaginal, nude, pussy, penis, cum, etc.). Do NOT keep contradicting clothes.
- SFW scenes: keep clothing SFW. Do NOT add sex/nude tags.
- Never output vague fillers like fuck, hot, sexy as the only action tags.

Forbidden weak fillers: beautiful face, perfect body, detailed eyes, anime style as a substitute for real pose/location tags.
Also avoid stacking too many atmosphere tags (mist + dew + wind + cinematic lighting + depth of field) that wash out the character.
''';

  /// Quality shell for final ComfyUI prompt. `{prompt}` = scene+appearance body.
  /// `{rating}` is replaced with rating:safe|sensitive|questionable|explicit.
  static const commonPrefix =
      'masterpiece, best quality, very awa, absurdres, {prompt}, {rating}';

  static const negativePrompt =
      'worst quality, low quality, lowres, bad hands, mutated hands, extra digits, '
      'bad anatomy, ugly, deformed, disfigured, signature, username, watermark, '
      'character fusion, face merge, fused faces, censored, mosaic censoring, '
      'text, logo, multiple views, blurry, silhouette, faceless, dark face, '
      'against light, underexposed';

  /// Empty by default - NoobAI prefers real scene tags over beauty fluff.
  static const beautyBoost = '';

  /// Explicit / sexual content markers (substring match on lowercased tags).
  static const explicitMarkers = <String>[
    'rating:explicit',
    'nsfw',
    'sex',
    'nude',
    'completely_nude',
    'completely nude',
    'pussy',
    'penis',
    'vaginal',
    'anal',
    'oral',
    'fellatio',
    'cunnilingus',
    'paizuri',
    'cum',
    'nipples',
    'areolae',
    'spread_legs',
    'spread legs',
    'masturbation',
    'handjob',
    'footjob',
    'ahegao',
    'after_sex',
    'after sex',
    'penetration',
    'doggy_style',
    'doggy style',
    'missionary',
    'cowgirl',
    'reverse_cowgirl',
  ];

  static const questionableMarkers = <String>[
    'rating:questionable',
    'lingerie',
    'underwear',
    'panties',
    'bra',
    'bikini',
    'cleavage',
    'sideboob',
    'underboob',
    'skirt_lift',
    'skirt lift',
    'undressing',
    'partially_nude',
    'partially nude',
  ];

  /// Picks a NoobAI rating tag from assembled scene/appearance text.
  static String resolveRatingTag(String tags) {
    final lower = tags.toLowerCase();
    if (explicitMarkers.any(lower.contains)) return 'rating:explicit';
    if (questionableMarkers.any(lower.contains)) {
      return 'rating:questionable';
    }
    if (lower.contains('rating:sensitive')) return 'rating:sensitive';
    if (lower.contains('rating:safe')) return 'rating:safe';
    return 'rating:safe';
  }

  static bool looksExplicit(String tags) =>
      resolveRatingTag(tags) == 'rating:explicit';
}
