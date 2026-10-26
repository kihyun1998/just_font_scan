// Platform-agnostic upper bounds used by all native scanners to guard against
// corrupt or absurd values returned by platform APIs.

/// Maximum sane font name length in UTF-16 code units.
const int kMaxFontNameLength = 32767;

/// Maximum sane font family count.
const int kMaxFontFamilyCount = 10000;

/// Maximum sane variation-axis count per font.
const int kMaxFontAxisCount = 64;
