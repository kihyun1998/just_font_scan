## 0.2.0

- feat: macOS support via CoreText (`CTFontCollectionCreateFromAvailableFonts`)
- feat: weight mapping from CoreText normalized float (−1.0…1.0) to CSS weight (100–900) using Apple's `NSFontWeight` buckets
- feat: `.` prefix filter on macOS to hide system-internal fonts (e.g. `.SFUI-Regular`)
- fix: wrap each macOS scan in an Objective-C autorelease pool to drain CoreText-internal autoreleased objects (prevents ~1.3 MB/scan leak in Dart CLI processes, which have no Cocoa runloop)
- note: macOS weights are approximations — see README for caveat

## 0.1.0

- feat: system font family and weight scanning via Windows DirectWrite
- feat: `JustFontScan.scan()` returns font families sorted by name with caching
- feat: `JustFontScan.weightsFor()` queries supported weights for a specific family
- fix: COM null guards, absolute DLL paths, proper CoUninitialize for safety
