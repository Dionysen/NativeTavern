import 'package:flutter_test/flutter_test.dart';
import 'package:native_tavern/presentation/widgets/chat/html_webview_widget.dart';

void main() {
  test('styled card HTML is treated as complex so WebView is used', () {
    const html = '''
<div style="background:#1c1c1e;border-radius:12px;padding:16px;overflow:hidden;height:240px">
  <h3>Status</h3>
  <p>Long card body that must stay fully visible after streaming ends.</p>
</div>
''';
    expect(isComplexHtml(html), isTrue);
  });

  test('webview height always grows to the latest measured content', () {
    expect(
      resolveHtmlWebViewHeight(
        currentHeight: 100,
        measuredHeight: 420,
        updateCount: 12,
      ),
      432,
    );
  });

  test('webview height ignores late shrinks that would crop content', () {
    expect(
      resolveHtmlWebViewHeight(
        currentHeight: 432,
        measuredHeight: 180,
        updateCount: 12,
      ),
      isNull,
    );
  });

  test('early layout may still correct an oversized first measurement', () {
    expect(
      resolveHtmlWebViewHeight(
        currentHeight: 800,
        measuredHeight: 240,
        updateCount: 2,
      ),
      252,
    );
  });

  test('tiny height jitter is ignored to avoid scroll flash', () {
    expect(
      resolveHtmlWebViewHeight(
        currentHeight: 432,
        measuredHeight: 422,
        updateCount: 2,
      ),
      isNull,
    );
  });

  test('css font stack quotes custom families and keeps generics bare', () {
    expect(cssFontFamilyStack('serif'), 'serif');
    expect(cssFontFamilyStack('My Font'), contains("'My Font'"));
    expect(cssFontFamilyStack(null), contains('sans-serif'));
  });

  test('html text newlines become br outside pre/script', () {
    expect(
      preserveHtmlTextNewlines('第一段\n第二段'),
      '第一段<br>\n第二段',
    );
    expect(
      preserveHtmlTextNewlines('<div>甲\n乙</div>'),
      '<div>甲<br>\n乙</div>',
    );
    expect(
      preserveHtmlTextNewlines('<pre>keep\nnewline</pre>'),
      '<pre>keep\nnewline</pre>',
    );
    // Whitespace-only nodes between blocks stay untouched.
    expect(
      preserveHtmlTextNewlines('<div>a</div>\n<div>b</div>'),
      '<div>a</div>\n<div>b</div>',
    );
  });
}
