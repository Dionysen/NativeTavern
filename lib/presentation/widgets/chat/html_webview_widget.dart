import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:native_tavern/presentation/theme/app_theme.dart';
import 'package:native_tavern/presentation/widgets/chat/dialogue_quote_style.dart';
import 'package:url_launcher/url_launcher.dart';

/// Survives ListView recycle so scrolling back does not collapse to a stub height.
final Map<String, double> _htmlWebViewHeightCache = <String, double>{};

/// Cached font file bytes for post-load FontFace injection.
final Map<String, Uint8List> _htmlWebViewFontBytesCache = <String, Uint8List>{};

/// Keeps a bounded set of HTML WebViews alive so nearby scroll does not
/// tear down native platform views (the main scroll-flash source).
class _HtmlWebViewKeepAliveGate {
  static const int maxKeepAlive = 8;
  static final List<String> _lru = <String>[];
  static final Map<String, VoidCallback> _listeners = <String, VoidCallback>{};

  static bool isKept(String key) => _lru.contains(key);

  static void touch(String key, VoidCallback onChanged) {
    _listeners[key] = onChanged;
    _lru.remove(key);
    _lru.add(key);
    while (_lru.length > maxKeepAlive) {
      final evicted = _lru.removeAt(0);
      // Notify the evicted WebView so it can drop keep-alive and be recycled.
      _listeners.remove(evicted)?.call();
    }
  }

  static void release(String key) {
    _listeners.remove(key);
    _lru.remove(key);
  }
}

/// Widget that renders HTML content using a WebView for full CSS support
///
/// This widget uses flutter_inappwebview to render complex HTML content
/// with full CSS support including flexbox, grid, shadows, transitions, etc.
class HtmlWebViewWidget extends StatefulWidget {
  final String htmlContent;
  final Color backgroundColor;
  final Color textColor;
  /// Color applied to quoted dialogue via `.nt-dialogue` spans.
  final Color? dialogueColor;
  final double? fontSize;
  /// CSS line-height multiplier for body text.
  final double lineHeight;
  /// Bottom margin for paragraphs, in logical pixels.
  final double paragraphSpacing;
  final VoidCallback? onLongPress;
  /// Unique key to force rebuild when content changes significantly
  final String? contentKey;
  /// Strip opaque character-card fills/colors so the chat theme shows through.
  final bool neutralizeStyle;
  /// Force body text to [fontFamily], ignoring card-authored font-family rules.
  final bool overrideFont;
  /// App UI font family (FontLoader id or generic like `serif`).
  final String? fontFamily;
  /// Font file used to inject `@font-face` so WebView can load custom fonts.
  final String? fontPath;

  const HtmlWebViewWidget({
    super.key,
    required this.htmlContent,
    this.backgroundColor = Colors.transparent,
    this.textColor = AppTheme.textPrimary,
    this.dialogueColor,
    this.fontSize,
    this.lineHeight = 1.5,
    this.paragraphSpacing = 8,
    this.onLongPress,
    this.contentKey,
    this.neutralizeStyle = true,
    this.overrideFont = false,
    this.fontFamily,
    this.fontPath,
  });

  @override
  State<HtmlWebViewWidget> createState() => _HtmlWebViewWidgetState();
}

class _HtmlWebViewWidgetState extends State<HtmlWebViewWidget>
    with AutomaticKeepAliveClientMixin {
  double _contentHeight = 100; // Initial height - start smaller, will expand
  final double _minHeight = 50; // Minimum height to prevent collapse
  bool _isLoading = true;
  bool _restoredFromCache = false;
  bool _hasError = false;
  String? _errorMessage;
  InAppWebViewController? _webViewController;
  int _heightUpdateCount = 0; // Track number of height updates
  bool _imagesLoaded = false;

  @override
  bool get wantKeepAlive {
    final key = widget.contentKey;
    return key != null && _HtmlWebViewKeepAliveGate.isKept(key);
  }

  @override
  void initState() {
    super.initState();
    _restoreCachedHeight();
    _claimKeepAlive();
    // Auto-hide loading after timeout
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    });
  }

  void _restoreCachedHeight() {
    final key = widget.contentKey;
    if (key == null) return;
    final cached = _htmlWebViewHeightCache[key];
    if (cached == null || cached <= _minHeight) return;
    _contentHeight = cached;
    _restoredFromCache = true;
    _isLoading = false;
  }

  void _cacheHeight(double height) {
    final key = widget.contentKey;
    if (key == null || height <= _minHeight) return;
    _htmlWebViewHeightCache[key] = height;
  }

  void _claimKeepAlive() {
    final key = widget.contentKey;
    if (key == null) return;
    _HtmlWebViewKeepAliveGate.touch(key, _onKeepAliveChanged);
  }

  void _onKeepAliveChanged() {
    if (mounted) updateKeepAlive();
  }

  @override
  void dispose() {
    debugPrint('🌐 WebView disposing');
    final key = widget.contentKey;
    if (key != null) {
      _HtmlWebViewKeepAliveGate.release(key);
    }
    // Clear the controller reference to prevent issues with disposed WebView
    _webViewController = null;
    super.dispose();
  }

  @override
  void didUpdateWidget(HtmlWebViewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.contentKey != oldWidget.contentKey) {
      if (oldWidget.contentKey != null) {
        _HtmlWebViewKeepAliveGate.release(oldWidget.contentKey!);
      }
      _restoreCachedHeight();
      _claimKeepAlive();
    }
    // Check if content has changed (important for swipe switching)
    final contentChanged = widget.htmlContent != oldWidget.htmlContent;
    // Check if contentKey has changed (e.g., streaming ended)
    final keyChanged =
        widget.contentKey != oldWidget.contentKey && widget.contentKey != null;
    final styleChanged = widget.neutralizeStyle != oldWidget.neutralizeStyle ||
        widget.overrideFont != oldWidget.overrideFont ||
        widget.fontFamily != oldWidget.fontFamily ||
        widget.fontPath != oldWidget.fontPath ||
        widget.textColor != oldWidget.textColor ||
        widget.dialogueColor != oldWidget.dialogueColor ||
        widget.fontSize != oldWidget.fontSize ||
        widget.lineHeight != oldWidget.lineHeight ||
        widget.paragraphSpacing != oldWidget.paragraphSpacing;

    if (contentChanged || keyChanged || styleChanged) {
      debugPrint(
        '🌐 didUpdateWidget: contentChanged=$contentChanged, keyChanged=$keyChanged',
      );
      debugPrint(
        '🌐 Old key: ${oldWidget.contentKey}, New key: ${widget.contentKey}',
      );
      _reloadContent();
    }
  }

  /// Track if a reload is in progress to prevent multiple simultaneous reloads
  bool _isReloading = false;

  void _reloadContent() async {
    // Prevent multiple simultaneous reloads
    if (_isReloading) {
      debugPrint('🌐 Reload already in progress, skipping');
      return;
    }

    if (_webViewController != null && mounted) {
      _isReloading = true;
      debugPrint('🌐 Starting content reload');

      final cached = widget.contentKey == null
          ? null
          : _htmlWebViewHeightCache[widget.contentKey!];
      setState(() {
        // Keep prior / cached height so the list does not collapse while reload.
        if (cached != null && cached > _minHeight) {
          _contentHeight = cached;
          _restoredFromCache = true;
          _isLoading = false;
        } else {
          _isLoading = true;
        }
        _heightUpdateCount = 0;
        _imagesLoaded = false;
      });

      try {
        // Reload the WebView with updated content
        await _webViewController!.loadData(
          data: _buildHtml(),
          mimeType: 'text/html',
          encoding: 'utf-8',
          baseUrl: WebUri('about:blank'),
        );
        debugPrint('🌐 Content reload completed');
      } catch (e) {
        debugPrint('🌐 Error reloading content: $e');
        // If loading fails, we should still hide the loading indicator
        if (mounted) {
          setState(() => _isLoading = false);
        }
      } finally {
        _isReloading = false;
      }
    } else {
      debugPrint(
        '🌐 Cannot reload: controller=${_webViewController != null}, mounted=$mounted',
      );
    }
  }

  /// Request height update from JavaScript
  void _requestHeightUpdate() async {
    if (_webViewController != null && mounted) {
      try {
        await _webViewController!.evaluateJavascript(source: 'sendHeight();');
      } catch (e) {
        debugPrint('🌐 Error requesting height update: $e');
      }
    }
  }

  /// Load the app UI font into the WebView after the page is up.
  ///
  /// Windows WebView2 blocks `file://` fonts for `NavigateToString` pages, and
  /// inlining multi‑MB base64 in the initial HTML hits `参数错误`. Chunked
  /// `FontFace` injection avoids both.
  Future<void> _injectAppFontIfNeeded(InAppWebViewController controller) async {
    if (!widget.overrideFont || kIsWeb) return;
    final family = widget.fontFamily;
    if (family == null || family.isEmpty) return;

    final stack = cssFontFamilyStack(family);
    final path = widget.fontPath;
    try {
      if (path != null && path.isNotEmpty) {
        var bytes = _htmlWebViewFontBytesCache[path];
        if (bytes == null) {
          final loaded = await File(path).readAsBytes();
          bytes = Uint8List.fromList(loaded);
          _htmlWebViewFontBytesCache[path] = bytes;
        }
        if (bytes.isEmpty) {
          debugPrint('🌐 App font file empty: $path');
        } else {
          await controller.evaluateJavascript(source: 'window.__ntFontChunks=[];');
          const chunkSize = 240 * 1024;
          for (var i = 0; i < bytes.length; i += chunkSize) {
            final end = math.min(i + chunkSize, bytes.length);
            final chunk = base64Encode(bytes.sublist(i, end));
            await controller.evaluateJavascript(
              source: "window.__ntFontChunks.push('$chunk');",
            );
          }
          final mime = _htmlFontMimeType(path);
          final familyJson = jsonEncode(family);
          final stackJson = jsonEncode(stack);
          await controller.evaluateJavascript(source: '''
(async function() {
  try {
    var family = $familyJson;
    var stack = $stackJson;
    var b64 = (window.__ntFontChunks || []).join('');
    window.__ntFontChunks = null;
    if (b64) {
      var face = new FontFace(family, 'url(data:$mime;base64,' + b64 + ')');
      await face.load();
      document.fonts.add(face);
    }
    document.documentElement.style.setProperty('font-family', stack, 'important');
    if (document.body) {
      document.body.style.setProperty('font-family', stack, 'important');
    }
    var root = document.getElementById('measure-root');
    if (root) root.style.setProperty('font-family', stack, 'important');
    if (typeof sendHeight === 'function') sendHeight();
  } catch (e) {
    console.error('nt font inject failed', e);
  }
})();
''');
          debugPrint('🌐 Injected app font "$family" (${bytes.length} bytes)');
          return;
        }
      }

      // Generic family (serif / system) or missing file: CSS stack only.
      final stackJson = jsonEncode(stack);
      await controller.evaluateJavascript(source: '''
(function() {
  var stack = $stackJson;
  document.documentElement.style.setProperty('font-family', stack, 'important');
  if (document.body) {
    document.body.style.setProperty('font-family', stack, 'important');
  }
  var root = document.getElementById('measure-root');
  if (root) root.style.setProperty('font-family', stack, 'important');
})();
''');
    } catch (e) {
      debugPrint('🌐 App font inject error: $e');
    }
  }

  /// Build the complete HTML document
  String _buildHtml() {
    final effectiveFontSize = widget.fontSize ?? 14.0;
    final lineHeight = widget.lineHeight;
    final paragraphSpacing = widget.paragraphSpacing;
    final textColorHex = _colorToHex(widget.textColor);
    final dialogueColorHex = _colorToHex(
      widget.dialogueColor ?? widget.textColor,
    );
    final scheme = Theme.of(context).colorScheme;
    final blockquoteBgHex = _colorToHex(scheme.secondaryContainer);
    final blockquoteBarHex = _colorToHex(scheme.secondary);
    final blockquoteTextHex = _colorToHex(scheme.onSecondaryContainer);
    // Prefer theme bubble color over pure transparent: native WebViews often
    // still paint an opaque white plate even with transparentBackground=true.
    final surfaceHex = _colorToHex(widget.backgroundColor);
    final pageBackground = widget.neutralizeStyle ? surfaceHex : 'transparent';
    final bodyFontFamily = cssFontFamilyStack(
      widget.overrideFont ? widget.fontFamily : null,
    );
    final content = wrapDialogueQuotesInHtml(
      preserveHtmlTextNewlines(
        widget.htmlContent.replaceAllMapped(
          RegExp(r'<details\b', caseSensitive: false),
          (match) => '<details open',
        ),
      ),
    );

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    * {
      box-sizing: border-box;
      -webkit-tap-highlight-color: transparent;
    }
    html, body {
      margin: 0;
      padding: 0;
      background: $pageBackground !important;
      background-color: $pageBackground !important;
      color: $textColorHex;
      font-family: $bodyFontFamily;
      font-size: ${effectiveFontSize}px;
      line-height: $lineHeight;
      width: 100%;
      height: auto !important;
      min-height: 0 !important;
      max-height: none !important;
      overflow: visible !important;
      word-wrap: break-word;
      overflow-wrap: anywhere;
    }
    .nt-dialogue {
      color: $dialogueColorHex;
      font-weight: 700;
    }
    #measure-root {
      display: flow-root;
      width: 100%;
      padding: 8px;
      height: auto !important;
      max-height: none !important;
      overflow: visible !important;
    }
    details, details[open], summary {
      overflow: visible;
    }
    img {
      max-width: 100%;
      height: auto;
      border-radius: 8px;
      display: block;
      min-height: 50px;
      background: linear-gradient(90deg, rgba(60,60,60,0.3) 25%, rgba(80,80,80,0.3) 50%, rgba(60,60,60,0.3) 75%);
      background-size: 200% 100%;
      animation: imageLoading 1.5s infinite;
    }
    img[data-loaded="true"] {
      background: none;
      animation: none;
      min-height: auto;
    }
    @keyframes imageLoading {
      0% { background-position: 200% 0; }
      100% { background-position: -200% 0; }
    }
    a {
      color: #7C4DFF;
      text-decoration: underline;
    }
    h1, h2, h3, h4, h5, h6 {
      margin-top: 0.5em;
      margin-bottom: 0.3em;
      font-weight: bold;
    }
    h1 { font-size: 1.8em; }
    h2 { font-size: 1.5em; }
    h3 { font-size: 1.3em; }
    h4 { font-size: 1.1em; }
    p {
      margin: 0 0 ${paragraphSpacing}px 0;
    }
    blockquote {
      margin: 0.5em 0;
      padding: 8px 12px;
      color: $blockquoteTextHex;
      font-style: italic;
      background: $blockquoteBgHex;
      border-radius: 0 4px 4px 0;
      border-left: 3px solid $blockquoteBarHex;
    }
    ::-webkit-scrollbar {
      width: 6px;
      height: 6px;
    }
    ::-webkit-scrollbar-track {
      background: transparent;
    }
    ::-webkit-scrollbar-thumb {
      background: rgba(255,255,255,0.2);
      border-radius: 3px;
    }
  </style>
</head>
<body>
<div id="measure-root">
$content
</div>
${widget.neutralizeStyle ? '''
<style id="nt-html-chrome-reset">
  /* Character cards often ship opaque fills/colors that fight the chat theme.
     Placed after content so it wins over embedded <style> / inline rules.
     Use the theme bubble surface (not pure transparent) so a non-transparent
     native WebView plate does not flash white on dark themes. */
  html, body {
    background: $surfaceHex !important;
    background-color: $surfaceHex !important;
  }
  #measure-root,
  #measure-root *:not(img):not(svg):not(canvas):not(video):not(source) {
    background: transparent !important;
    background-color: transparent !important;
    background-image: none !important;
  }
  #measure-root {
    color: $textColorHex !important;
  }
  #measure-root *:not(img):not(svg):not(canvas):not(video):not(source) {
    color: inherit !important;
  }
  #measure-root .nt-dialogue {
    color: $dialogueColorHex !important;
    font-weight: 700 !important;
  }
</style>
''' : ''}
${widget.overrideFont ? '''
<style id="nt-html-font-override">
  /* Force app UI font on body text only; keep monospace for code. */
  html, body, #measure-root {
    font-family: $bodyFontFamily !important;
  }
  #measure-root * {
    font-family: inherit !important;
  }
  #measure-root pre,
  #measure-root code,
  #measure-root kbd,
  #measure-root samp,
  #measure-root tt,
  #measure-root pre *,
  #measure-root code * {
    font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, 'Liberation Mono', monospace !important;
  }
</style>
''' : ''}
<script>
  var heightSent = false;
  var lastSentHeight = 0;
  var allImagesLoaded = false;
  
  function getContentHeight() {
    var root = document.getElementById('measure-root') || document.body;
    var rect = root.getBoundingClientRect();
    return Math.ceil(Math.max(
      rect.height || 0,
      root.scrollHeight || 0,
      root.offsetHeight || 0,
      document.body.scrollHeight || 0,
      document.body.offsetHeight || 0
    ));
  }
  
  function sendHeight() {
    try {
      var height = getContentHeight();
      if (!heightSent || Math.abs(height - lastSentHeight) >= 1) {
        if (window.flutter_inappwebview) {
          console.log('Sending height: ' + height);
          window.flutter_inappwebview.callHandler('contentHeight', height);
          lastSentHeight = height;
          heightSent = true;
        }
      }
    } catch (e) {
      console.error('Error sending height:', e);
    }
  }
  
  function notifyImagesLoaded() {
    if (!allImagesLoaded) {
      allImagesLoaded = true;
      setTimeout(sendHeight, 100);
      
      try {
        if (window.flutter_inappwebview) {
          window.flutter_inappwebview.callHandler('imagesLoaded', true);
        }
      } catch (e) {
        console.error('Error notifying images loaded:', e);
      }
    }
  }
  
  // Force reload an image by resetting its src
  function forceReloadImage(img) {
    var src = img.src;
    if (src && src.length > 0 && !src.startsWith('data:')) {
      // Add cache-busting query parameter
      var separator = src.indexOf('?') > -1 ? '&' : '?';
      var newSrc = src + separator + '_t=' + Date.now();
      console.log('Force reloading image: ' + src);
      img.src = newSrc;
    }
  }
  
  // Check if an image is truly loaded and rendered
  function isImageReady(img) {
    // Check if it has actual dimensions
    if (!img.complete) return false;
    if (img.naturalWidth === 0 || img.naturalHeight === 0) return false;
    // Also check rendered dimensions
    var rect = img.getBoundingClientRect();
    return rect.width > 0 && rect.height > 0;
  }
  
  // Wait for all images to load with retries
  function waitForImages() {
    var images = document.querySelectorAll('img');
    console.log('Found ' + images.length + ' images to load');
    
    if (images.length === 0) {
      sendHeight();
      notifyImagesLoaded();
      return;
    }
    
    var loadedCount = 0;
    var totalImages = images.length;
    var retryAttempts = {};
    var maxRetries = 3;
    
    function imageLoaded(img, index) {
      loadedCount++;
      img.setAttribute('data-loaded', 'true');
      console.log('Image ' + index + ' loaded (' + loadedCount + '/' + totalImages + ')');
      setTimeout(sendHeight, 50);
      
      if (loadedCount >= totalImages) {
        console.log('All images loaded!');
        setTimeout(function() {
          sendHeight();
          notifyImagesLoaded();
        }, 200);
      }
    }
    
    function checkImage(img, index) {
      if (isImageReady(img)) {
        imageLoaded(img, index);
      } else if (img.complete) {
        // Image claims to be complete but has no dimensions
        // This often happens with network images - try to reload
        retryAttempts[index] = (retryAttempts[index] || 0) + 1;
        if (retryAttempts[index] <= maxRetries) {
          console.log('Image ' + index + ' complete but not rendered, retry ' + retryAttempts[index]);
          setTimeout(function() {
            if (!isImageReady(img)) {
              forceReloadImage(img);
            } else {
              imageLoaded(img, index);
            }
          }, 500 * retryAttempts[index]);
        } else {
          console.log('Image ' + index + ' failed after retries - URL: ' + (img.src || 'unknown').substring(0, 100));
          img.style.minHeight = '100px';
          img.style.backgroundColor = 'rgba(100,100,100,0.3)';
          img.style.animation = 'none';
          img.setAttribute('data-loaded', 'true');
          loadedCount++;
          setTimeout(sendHeight, 50);
          if (loadedCount >= totalImages) {
            setTimeout(function() {
              sendHeight();
              notifyImagesLoaded();
            }, 200);
          }
        }
      } else {
        // Image is still loading
        img.onload = function() {
          setTimeout(function() {
            if (isImageReady(img)) {
              imageLoaded(img, index);
            } else {
              checkImage(img, index);
            }
          }, 100);
        };
        img.onerror = function(e) {
          var errorInfo = {
            url: this.src,
            complete: this.complete,
            naturalWidth: this.naturalWidth,
            naturalHeight: this.naturalHeight,
            event: e ? JSON.stringify(e, Object.getOwnPropertyNames(e)) : 'no event'
          };
          console.log('Image ' + index + ' error (attempt ' + ((retryAttempts[index] || 0) + 1) + '): ' + JSON.stringify(errorInfo));
          
          // Retry mechanism - don't immediately mark as loaded
          retryAttempts[index] = (retryAttempts[index] || 0) + 1;
          if (retryAttempts[index] <= maxRetries) {
            console.log('Retrying image ' + index + ' in ' + (500 * retryAttempts[index]) + 'ms');
            setTimeout(function() {
              // Force reload the image
              var src = img.src;
              if (src && src.length > 0 && !src.startsWith('data:')) {
                var separator = src.indexOf('?') > -1 ? '&' : '?';
                var newSrc = src.split('?')[0] + separator + '_retry=' + retryAttempts[index] + '&_t=' + Date.now();
                console.log('Reloading image ' + index + ': ' + newSrc.substring(0, 80));
                img.src = newSrc;
              }
            }, 500 * retryAttempts[index]);
          } else {
            // Max retries reached, give up
            console.log('Image ' + index + ' failed after ' + maxRetries + ' retries, giving up');
            this.style.display = 'none';
            imageLoaded(img, index);
          }
        };
      }
    }
    
    images.forEach(function(img, index) {
      checkImage(img, index);
    });
    
    // Final fallback
    setTimeout(function() {
      if (!allImagesLoaded) {
        console.log('Fallback: forcing completion after timeout');
        sendHeight();
        notifyImagesLoaded();
      }
    }, 8000);
  }
  
  // Periodic check for unloaded images
  function checkUnloadedImages() {
    var images = document.querySelectorAll('img');
    var unloaded = 0;
    images.forEach(function(img, index) {
      if (!isImageReady(img) && img.src && !img.src.startsWith('data:')) {
        unloaded++;
        console.log('Image ' + index + ' still not loaded: ' + img.src.substring(0, 50));
      }
    });
    if (unloaded > 0) {
      console.log(unloaded + ' images still unloaded');
    }
    return unloaded;
  }
  
  // Delay image loading to ensure WebView network is ready
  function deferImageLoading() {
    var images = document.querySelectorAll('img');
    images.forEach(function(img) {
      // Only defer external images (not data URIs)
      if (img.src && !img.src.startsWith('data:') && !img.getAttribute('data-deferred')) {
        img.setAttribute('data-original-src', img.src);
        img.setAttribute('data-deferred', 'true');
        img.removeAttribute('src');
      }
    });
  }
  
  // Load deferred images after delay
  function loadDeferredImages() {
    var images = document.querySelectorAll('img[data-original-src]');
    console.log('Loading ' + images.length + ' deferred images');
    images.forEach(function(img, index) {
      var originalSrc = img.getAttribute('data-original-src');
      if (originalSrc) {
        console.log('Setting src for image ' + index + ': ' + originalSrc.substring(0, 50));
        img.src = originalSrc;
        img.removeAttribute('data-original-src');
      }
    });
  }
  
  function observeLayoutChanges() {
    var root = document.getElementById('measure-root');
    if (root && window.ResizeObserver) {
      new ResizeObserver(function() { sendHeight(); }).observe(root);
    }
    document.addEventListener('toggle', function() {
      setTimeout(sendHeight, 50);
    }, true);
  }

  function init() {
    document.querySelectorAll('details').forEach(function(d){ d.open = true; });
    deferImageLoading();
    observeLayoutChanges();
    sendHeight();
    setTimeout(sendHeight, 150);
    setTimeout(sendHeight, 300);
    
    // Load images after a short delay to ensure WebView is fully ready
    setTimeout(function() {
      loadDeferredImages();
      waitForImages();
    }, 200);
    
    setTimeout(sendHeight, 500);
    setTimeout(sendHeight, 1000);
    setTimeout(function() {
      sendHeight();
      checkUnloadedImages();
    }, 2000);
    setTimeout(function() {
      sendHeight();
      checkUnloadedImages();
    }, 4000);
  }
  
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
  
  window.onload = function() {
    setTimeout(sendHeight, 100);
    setTimeout(sendHeight, 500);
  };
</script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final fullHtml = _buildHtml();
    // Avoid spinner flash when height is already known from a prior visit.
    final showLoading = _isLoading && !_restoredFromCache;

    if (_hasError) {
      // Prefer readable text over an empty black WebView plate.
      final plain = widget.htmlContent
          .replaceAll(RegExp(r'<[^>]+>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      return GestureDetector(
        onLongPress: widget.onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            plain.isEmpty ? 'Failed to render HTML content' : plain,
            style: TextStyle(
              color: widget.textColor,
              fontSize: widget.fontSize ?? 14,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onLongPress: widget.onLongPress,
      // No AnimatedContainer: height animation during recycle caused list flash.
      child: Container(
        color: widget.neutralizeStyle
            ? widget.backgroundColor
            : Colors.transparent,
        clipBehavior: Clip.none,
        constraints: BoxConstraints(
          minHeight: _minHeight,
        ),
        height: _contentHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            InAppWebView(
              initialData: InAppWebViewInitialData(
                data: fullHtml,
                mimeType: 'text/html',
                encoding: 'utf-8',
                baseUrl: WebUri('about:blank'),
              ),
              initialSettings: InAppWebViewSettings(
                transparentBackground: true,
                disableHorizontalScroll: true,
                disableVerticalScroll:
                    true, // Disable scroll, we adjust container height
                supportZoom: false,
                javaScriptEnabled: true,
                mediaPlaybackRequiresUserGesture: false,
                allowsInlineMediaPlayback: true,
                useShouldOverrideUrlLoading: true,
                allowsBackForwardNavigationGestures: false,
                iframeAllowFullscreen: false,
              ),
              onWebViewCreated: (controller) {
                debugPrint('🌐 WebView created');
                _webViewController = controller;

                // Handler for content height updates
                controller.addJavaScriptHandler(
                  handlerName: 'contentHeight',
                  callback: (args) {
                    if (args.isEmpty || !mounted) return;
                    final height = (args[0] as num).toDouble();
                    _heightUpdateCount++;
                    final resolved = resolveHtmlWebViewHeight(
                      currentHeight: _contentHeight,
                      measuredHeight: height,
                      updateCount: _heightUpdateCount,
                    );
                    if (resolved == null) {
                      debugPrint(
                        '🌐 Skipping height: $height (current=$_contentHeight, #$_heightUpdateCount)',
                      );
                      return;
                    }
                    debugPrint(
                      '🌐 Updating height: $_contentHeight -> $resolved (update #$_heightUpdateCount)',
                    );
                    setState(() {
                      _contentHeight = resolved;
                      _isLoading = false;
                      _restoredFromCache = true;
                    });
                    _cacheHeight(resolved);
                  },
                );

                // Handler for images loaded notification
                controller.addJavaScriptHandler(
                  handlerName: 'imagesLoaded',
                  callback: (args) {
                    debugPrint('🌐 Images loaded notification received');
                    if (mounted && !_imagesLoaded) {
                      setState(() {
                        _imagesLoaded = true;
                      });
                      // Request final height update after images loaded
                      Future.delayed(const Duration(milliseconds: 200), () {
                        if (mounted) _requestHeightUpdate();
                      });
                    }
                  },
                );
              },
              onLoadStart: (controller, url) {
                debugPrint('🌐 WebView load start: $url');
              },
              onLoadStop: (controller, url) async {
                debugPrint('🌐 WebView load stop: $url');
                if (mounted) {
                  setState(() => _isLoading = false);
                }
                // Re-apply theme surface after load; card CSS may fight us.
                if (widget.neutralizeStyle) {
                  final surfaceHex = _colorToHex(widget.backgroundColor);
                  await controller.evaluateJavascript(source: '''
                    document.documentElement.style.setProperty('background','$surfaceHex','important');
                    document.documentElement.style.setProperty('background-color','$surfaceHex','important');
                    if (document.body) {
                      document.body.style.setProperty('background','$surfaceHex','important');
                      document.body.style.setProperty('background-color','$surfaceHex','important');
                    }
                  ''');
                }
                await _injectAppFontIfNeeded(controller);
                // Trigger height calculation
                await controller.evaluateJavascript(source: 'sendHeight();');

                // Additional height checks after load
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (mounted) _requestHeightUpdate();
                });
                Future.delayed(const Duration(milliseconds: 800), () {
                  if (mounted) _requestHeightUpdate();
                });
              },
              onLoadError: (controller, url, code, message) {
                debugPrint('🌐 WebView error: $code - $message');
                if (mounted) {
                  setState(() {
                    _hasError = true;
                    _errorMessage = message;
                    _isLoading = false;
                  });
                }
              },
              onConsoleMessage: (controller, consoleMessage) {
                debugPrint('🌐 Console: ${consoleMessage.message}');
              },
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                final url = navigationAction.request.url;
                if (url != null && url.toString() != 'about:blank') {
                  final uri = Uri.tryParse(url.toString());
                  if (uri != null) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                  return NavigationActionPolicy.CANCEL;
                }
                return NavigationActionPolicy.ALLOW;
              },
            ),
            if (showLoading)
              const Positioned.fill(
                child: ColoredBox(
                  color: Colors.transparent,
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _colorToHex(Color color) {
    final r = (color.r * 255).round();
    final g = (color.g * 255).round();
    final b = (color.b * 255).round();
    return 'rgba($r, $g, $b, ${color.a})';
  }
}

/// Check if HTML content is complex enough to warrant WebView rendering
bool isComplexHtml(String html) {
  // Check for complex CSS features that flutter_html doesn't support well
  final complexPatterns = [
    RegExp(r'display:\s*flex', caseSensitive: false),
    RegExp(r'display:\s*grid', caseSensitive: false),
    RegExp(r'box-shadow:', caseSensitive: false),
    RegExp(r'transition:', caseSensitive: false),
    RegExp(r'transform:', caseSensitive: false),
    RegExp(r'animation:', caseSensitive: false),
    RegExp(r'@keyframes', caseSensitive: false),
    RegExp(r'object-fit:', caseSensitive: false),
    RegExp(r'background:\s*linear-gradient', caseSensitive: false),
    RegExp(r'background:\s*radial-gradient', caseSensitive: false),
    RegExp(r'overflow:\s*(hidden|auto|scroll)', caseSensitive: false),
    RegExp(r'height:\s*\d+', caseSensitive: false),
    RegExp(r'<[^>]+style="[^"]{10,}"', caseSensitive: false),
  ];
  
  for (final pattern in complexPatterns) {
    if (pattern.hasMatch(html)) {
      return true;
    }
  }
  
  // Check for multiple nested divs with styles (likely a complex layout)
  final styledDivCount = RegExp(r'<div[^>]*style="[^"]*"[^>]*>', caseSensitive: false)
      .allMatches(html)
      .length;
  if (styledDivCount >= 3) {
    return true;
  }
  
  return false;
}

/// Decide the Flutter WebView height from a JS content measurement.
/// Always grows to fit content; only shrinks during the first few measurements
/// so ResizeObserver noise does not make the chat list jump while scrolling.
double? resolveHtmlWebViewHeight({
  required double currentHeight,
  required double measuredHeight,
  required int updateCount,
}) {
  if (measuredHeight <= 10 || measuredHeight >= 50000) return null;
  final newHeight = measuredHeight + 12;
  final diff = (newHeight - currentHeight).abs();
  // Ignore sub-pixel / tiny jitter that still caused list flash.
  if (diff < 8) return null;
  if (newHeight > currentHeight) return newHeight;
  if (updateCount <= 3) return newHeight;
  return null;
}

/// Convert literal newlines inside HTML **text nodes** into `<br>` tags.
///
/// Browsers collapse `\n` in normal HTML flow, so character-card messages that
/// rely on source newlines (without `<br>`/`<p>`) render as one wall of text.
/// Skips `pre` / `script` / `style` / `textarea` / `Status_block` so those
/// keep raw content (status panels become one Markdown code fence later).
///
/// Also leaves Markdown fenced code (` ``` ` / `~~~`) untouched: converting
/// those newlines to `<br>` and later back to `\n\n` would insert blank lines
/// inside code blocks (huge vertical gaps that ignore chat spacing settings).
String preserveHtmlTextNewlines(String html) {
  if (!html.contains('\n') && !html.contains('\r')) return html;

  // Protect fenced code so prose newline→<br> never rewrites fence interiors.
  final fences = <String>[];
  final withPlaceholders = html.replaceAllMapped(
    RegExp(r'(```[^\n]*\n[\s\S]*?```|~~~[^\n]*\n[\s\S]*?~~~)'),
    (match) {
      final index = fences.length;
      fences.add(match.group(0)!);
      return '\u0000MD_FENCE_$index\u0000';
    },
  );

  final out = StringBuffer();
  final tagRe = RegExp(r'<!--.*?-->|<[^>]+>', dotAll: true);
  var cursor = 0;
  var skipDepth = 0;
  final openSkip = RegExp(
    r'^<\s*(pre|script|style|textarea|status_block)\b',
    caseSensitive: false,
  );
  final closeSkip = RegExp(
    r'^<\s*/\s*(pre|script|style|textarea|status_block)\s*>',
    caseSensitive: false,
  );

  void writeText(String text) {
    if (skipDepth > 0) {
      out.write(text);
      return;
    }
    // Pure whitespace between tags is layout noise; block elements already
    // separate. Only prose text nodes need explicit <br> for source newlines.
    if (text.trim().isEmpty) {
      out.write(text);
      return;
    }
    out.write(
      text
          .replaceAll('\r\n', '\n')
          .replaceAll('\r', '\n')
          .replaceAll('\n', '<br>\n'),
    );
  }

  for (final match in tagRe.allMatches(withPlaceholders)) {
    if (match.start > cursor) {
      writeText(withPlaceholders.substring(cursor, match.start));
    }
    final tag = match.group(0)!;
    out.write(tag);
    if (openSkip.hasMatch(tag) && !RegExp(r'/>\s*$').hasMatch(tag)) {
      skipDepth++;
    } else if (closeSkip.hasMatch(tag) && skipDepth > 0) {
      skipDepth--;
    }
    cursor = match.end;
  }
  if (cursor < withPlaceholders.length) {
    writeText(withPlaceholders.substring(cursor));
  }

  var result = out.toString();
  for (var i = 0; i < fences.length; i++) {
    result = result.replaceFirst('\u0000MD_FENCE_$i\u0000', fences[i]);
  }
  return result;
}

/// CSS `font-family` stack for HTML WebViews.
String cssFontFamilyStack(String? family) {
  const systemStack =
      "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif";
  if (family == null || family.isEmpty) return systemStack;
  switch (family) {
    case 'serif':
    case 'sans-serif':
    case 'monospace':
    case 'cursive':
    case 'fantasy':
    case 'system-ui':
      return family;
  }
  final escaped = family.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
  return "'$escaped', $systemStack";
}

String _htmlFontMimeType(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.woff2')) return 'font/woff2';
  if (lower.endsWith('.woff')) return 'font/woff';
  if (lower.endsWith('.otf')) return 'font/otf';
  return 'font/ttf';
}