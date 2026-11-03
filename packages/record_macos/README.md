# record_macos (NativeTavern patch)

Vendored from `record_macos` 1.2.2 with one change: SPM/CocoaPods macOS
deployment target raised from 10.15 to 13.0 so `auAudioUnit` compiles under
Flutter's Swift Package Manager integration.

Remove this override once upstream declares macOS 13+ or guards that API.
