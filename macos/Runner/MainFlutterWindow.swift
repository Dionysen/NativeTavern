import Cocoa
import CoreText
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    // Match Windows/Linux: phone-like floor so desktop can preview mobile UI.
    self.contentMinSize = NSSize(width: 360, height: 640)

    RegisterGeneratedPlugins(registry: flutterViewController)
    registerSystemFontsChannel(flutterViewController)

    super.awakeFromNib()
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
