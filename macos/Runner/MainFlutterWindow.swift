import Cocoa
import CoreText
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var allowProgrammaticZoom = false
  private var dragMouseUpMonitor: Any?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    // Zephyr-style immersive title bar: content draws under traffic lights.
    self.styleMask.insert(.fullSizeContentView)
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true
    // Drag / double-click zoom only via Flutter caption chrome. Keeping the
    // window movable lets the system title-bar band steal gestures from rail
    // and AppBar controls that sit in that strip.
    self.isMovable = false
    self.isMovableByWindowBackground = false
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    // Match Windows/Linux: phone-like floor so desktop can preview mobile UI.
    self.contentMinSize = NSSize(width: 360, height: 640)

    RegisterGeneratedPlugins(registry: flutterViewController)
    registerWindowChannel(flutterViewController)
    registerSystemFontsChannel(flutterViewController)

    super.awakeFromNib()
  }

  /// Flutter caption chrome maximizes via `zoom(_:)`; the system title-bar
  /// double-click calls `performZoom` directly. Allow only the programmatic
  /// path so controls in the title-bar strip do not toggle zoom.
  override func zoom(_ sender: Any?) {
    allowProgrammaticZoom = true
    super.zoom(sender)
    allowProgrammaticZoom = false
  }

  override func performZoom(_ sender: Any?) {
    guard allowProgrammaticZoom else { return }
    super.performZoom(sender)
  }

  private func registerWindowChannel(_ controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "native_tavern/window",
      binaryMessenger: controller.engine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(
          FlutterError(
            code: "unavailable",
            message: "Window was released.",
            details: nil
          )
        )
        return
      }
      switch call.method {
      case "immersiveTitleBar":
        result(true)
      case "metrics":
        result(self.chromeMetrics())
      case "startDragging":
        self.beginChromeDrag()
        result(nil)
      case "toggleMaximize":
        self.zoom(nil)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// `performDrag` requires a movable window; enable only for the drag that
  /// Flutter started, then lock again on mouse-up.
  private func beginChromeDrag() {
    guard let event = currentEvent else { return }
    isMovable = true
    performDrag(with: event)
    if dragMouseUpMonitor != nil { return }
    dragMouseUpMonitor = NSEvent.addLocalMonitorForEvents(
      matching: [.leftMouseUp]
    ) { [weak self] event in
      self?.endChromeDrag()
      return event
    }
  }

  private func endChromeDrag() {
    if let dragMouseUpMonitor {
      NSEvent.removeMonitor(dragMouseUpMonitor)
      self.dragMouseUpMonitor = nil
    }
    isMovable = false
  }

  /// Distances from the Flutter content view origin so toolbar chrome can
  /// share a vertical center with the native traffic lights.
  private func chromeMetrics() -> [String: Double] {
    contentView?.layoutSubtreeIfNeeded()
    guard
      let closeButton = standardWindowButton(.closeButton),
      let zoomButton = standardWindowButton(.zoomButton),
      let contentView
    else {
      return ["centerY": 14, "leading": 80]
    }
    let closeInWindow = closeButton.convert(closeButton.bounds, to: nil)
    let zoomInWindow = zoomButton.convert(zoomButton.bounds, to: nil)
    let contentInWindow = contentView.convert(contentView.bounds, to: nil)
    let centerY = contentInWindow.maxY - closeInWindow.midY
    let leading = zoomInWindow.maxX - contentInWindow.minX + 8
    return [
      "centerY": Double(centerY),
      "leading": Double(leading),
    ]
  }

  private func registerSystemFontsChannel(
    _ controller: FlutterViewController
  ) {
    let channel = FlutterMethodChannel(
      name: "native_tavern/system_fonts",
      binaryMessenger: controller.engine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard self != nil else {
        result(
          FlutterError(
            code: "unavailable",
            message: "Window was released.",
            details: nil
          )
        )
        return
      }
      switch call.method {
      case "listFonts":
        DispatchQueue.global(qos: .userInitiated).async {
          let fonts = Self.listSystemFonts()
          DispatchQueue.main.async { result(fonts) }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func listSystemFonts() -> [[String: String]] {
    let manager = NSFontManager.shared
    var fonts: [[String: String]] = []
    var seen = Set<String>()
    for family in manager.availableFontFamilies.sorted() {
      if family.hasPrefix(".") || !seen.insert(family.lowercased()).inserted {
        continue
      }
      guard let font = representativeFont(in: family),
            let url = CTFontCopyAttribute(font, kCTFontURLAttribute) as? URL
      else {
        continue
      }
      let path = url.path
      guard !path.isEmpty, FileManager.default.isReadableFile(atPath: path)
      else {
        continue
      }
      fonts.append(["family": family, "path": path])
    }
    return fonts
  }

  private static func representativeFont(in family: String) -> CTFont? {
    let manager = NSFontManager.shared
    if let font = manager.font(
      withFamily: family,
      traits: [],
      weight: 5,
      size: 12
    ) {
      return font as CTFont
    }
    guard let members = manager.availableMembers(ofFontFamily: family),
          let first = members.first,
          let postScript = first.first as? String,
          let font = NSFont(name: postScript, size: 12)
    else {
      return nil
    }
    return font as CTFont
  }
}
