import 'package:flutter_test/flutter_test.dart';
import 'package:native_tavern/presentation/router/app_router.dart';

void main() {
  test('shell tab hubs keep bottom navigation', () {
    expect(AppRoutes.isShellTabHub(Uri.parse('/')), isTrue);
    expect(AppRoutes.isShellTabHub(Uri.parse('/characters')), isTrue);
    expect(AppRoutes.isShellTabHub(Uri.parse('/play')), isTrue);
    expect(AppRoutes.isShellTabHub(Uri.parse('/ai-config')), isTrue);
    expect(AppRoutes.isShellTabHub(Uri.parse('/appearance')), isTrue);
    expect(AppRoutes.isShellTabHub(Uri.parse('/settings')), isTrue);
  });

  test('secondary pages hide bottom navigation', () {
    expect(AppRoutes.isShellTabHub(Uri.parse('/chat/abc')), isFalse);
    expect(AppRoutes.isShellTabHub(Uri.parse('/characters/abc')), isFalse);
    expect(AppRoutes.isShellTabHub(Uri.parse('/play/moments')), isFalse);
    expect(AppRoutes.isShellTabHub(Uri.parse('/personas')), isFalse);
    expect(AppRoutes.isShellTabHub(Uri.parse('/world-info')), isFalse);
    expect(AppRoutes.isShellTabHub(Uri.parse('/data-bank')), isFalse);
  });
}
