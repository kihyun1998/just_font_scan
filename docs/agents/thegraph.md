# thegraph

## What this project is

A pure `dart:ffi` package that scans system font families, faces, variation axes and file paths through DirectWrite (Windows) and CoreText (macOS), with no native build step.

## References

| Source | Informs | Reached by | Binding |
|---|---|---|---|
| Windows SDK headers (`dwrite.h`, `dwrite_1.h`, `dwrite_3.h`) | how it works: vtable slot order, GUIDs, enum values | the headers: raw | binding |
| Microsoft Learn DirectWrite docs | how it works | the published docs: **summarized** | binding |
| Apple CoreText (`CTFont`, `CTFontDescriptor`, `NSFontWeight`) | how it works | SDK headers: raw; developer.apple.com: **summarized** | binding |
| OpenType spec (1.8+ variable fonts) | how it works: axis tags and ranges | the published spec: **summarized** | binding |

## Release

`pub-ready`
