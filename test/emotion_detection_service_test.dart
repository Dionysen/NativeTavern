import 'package:flutter_test/flutter_test.dart';
import 'package:native_tavern/data/models/sprite.dart';
import 'package:native_tavern/domain/services/emotion_detection_service.dart';

void main() {
  final service = EmotionDetectionService();

  group('EmotionDetectionService.detectEmotion', () {
    test('empty text is neutral', () {
      expect(service.detectEmotion(''), SpriteEmotion.neutral);
      expect(service.detectEmotion('   '), SpriteEmotion.neutral);
    });

    test('picks the emotion with the highest weight', () {
      expect(
        service.detectEmotion('She smiles and laughs happily.'),
        SpriteEmotion.happy,
      );
      expect(
        service.detectEmotion('He shouted, furious and angry.'),
        SpriteEmotion.angry,
      );
      expect(
        service.detectEmotion('A quiet room with a closed door.'),
        SpriteEmotion.neutral,
      );
    });
  });

  group('EmotionDetectionService confidence', () {
    test('empty text has zero confidence', () {
      final result = service.detectEmotionWithConfidence('');
      expect(result.emotion, SpriteEmotion.neutral);
      expect(result.confidence, 0);
    });

    test('a single matching emotion is fully confident', () {
      final result = service.detectEmotionWithConfidence('She smiles.');
      expect(result.emotion, SpriteEmotion.happy);
      expect(result.confidence, 1);
    });

    test('detectAllEmotions sorts by confidence and ignores empty input', () {
      expect(
        service.detectAllEmotions('').single.emotion,
        SpriteEmotion.neutral,
      );

      final results = service.detectAllEmotions('She smiles, then cries.');
      expect(results.first.confidence, greaterThanOrEqualTo(results.last.confidence));
      expect(
        results.map((result) => result.emotion),
        containsAll([SpriteEmotion.happy, SpriteEmotion.sad]),
      );
    });
  });

  group('EmotionDetectionService.detectEmotionFromAction', () {
    test('reads *action* and (action) before the rest of the line', () {
      expect(
        service.detectEmotionFromAction('Hello. *smiles warmly*'),
        SpriteEmotion.happy,
      );
      expect(
        service.detectEmotionFromAction('Wait. (gasps)'),
        SpriteEmotion.surprised,
      );
    });

    test('returns null when no action marker carries an emotion', () {
      expect(service.detectEmotionFromAction('She smiles.'), isNull);
      expect(service.detectEmotionFromAction('*walks to the door*'), isNull);
    });
  });
}
