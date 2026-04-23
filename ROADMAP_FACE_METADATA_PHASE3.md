# Phase 3 — macOS face 메타데이터

> 상위 기획: [ROADMAP_FACE_METADATA.md](./ROADMAP_FACE_METADATA.md)

## 목적

CoreText에서 face별 속성을 추출해 `FontFace`를 채운다. 현재 `macos_font_scanner.dart`는 descriptor 루프에서 family 단위로 **weight Set만 집계**하고 나머지 face 정보를 버리고 있다. 이를 face 리스트 그대로 보존하도록 재설계한다.

## 선행 조건

- **Phase 1 완료**: `FontFace`·`FontStyle`·`VariationAxis` 모델 필요

## 변경 대상 파일

- `lib/src/macos/coretext_bindings.dart` — attribute·trait 키 상수 추가
- `lib/src/macos/macos_font_scanner.dart` — descriptor 루프 전면 재작성
- `test/macos_stretch_mapping_test.dart` — stretch bucket 매핑 유닛 테스트 신설

## Task 체크리스트

### 바인딩 (`coretext_bindings.dart`)

- [x] 속성 키 상수 추가
  - [x] `kCTFontURLAttribute` — 파일 경로 (CFURL)
  - [x] `kCTFontStyleNameAttribute` — faceName ("Regular", "Bold Italic")
  - [x] `kCTFontDisplayNameAttribute` — fullName
  - [x] `kCTFontNameAttribute` — postScriptName (canonical PostScript name)
- [x] Trait 키
  - [x] `kCTFontWidthTrait` — stretch 계산 소스 (−1.0 ~ 1.0)
  - [x] `kCTFontSlantTrait` — italic/oblique 판별 보조 소스
  - [x] `kCTFontSymbolicTrait` — bitmask
- [x] Symbolic trait 상수 (`CTFontSymbolicTraits`)
  - [x] `kCTFontTraitItalic = 1 << 0`
  - [x] `kCTFontTraitBold = 1 << 1`
  - [x] `kCTFontTraitExpanded = 1 << 5`
  - [x] `kCTFontTraitCondensed = 1 << 6`
  - [x] `kCTFontTraitMonoSpace = 1 << 10`
  - [x] `kCTFontClassMaskTrait = 0xF << 28`
  - [x] `kCTFontClassSymbolic = 12 << 28`
- [x] 함수 바인딩
  - [x] `CFURLGetFileSystemRepresentation(url, resolveAgainstBase, buffer, maxBufLen)` — POSIX path 추출 (더 단순한 UTF-8 경로)
  - [x] `CFNumberGetValue` 의 Int32 오버로드 — `CTFontSymbolicTraits` 읽기용
  - [x] `CTFontCreateWithFontDescriptor` — 필요하지 않음. `kCTFontNameAttribute`가 PostScript name을 직접 주므로 CTFont 생성 생략 가능
- [x] `MacFontBindings`에 새 키 8개 필드 추가 + `load()`에서 resolve

### 스캐너 (`macos_font_scanner.dart`)

- [x] 집계 자료구조 변경
  - [x] `Map<String, Set<int>>` → `Map<String, List<FontFace>>` (facesByFamily)
- [x] `_scanDescriptor`에서 face 필드 전부 수집
  - [x] traits dict 한 번만 열어서 weight/stretch/slant/symbolic 4개 필드 추출 (`_readWeightFromTraits`, `_readStretchFromTraits`, `_readSlantFromTraits`, `_readSymbolicFromTraits`)
  - [x] `_copyStringAttribute`로 faceName·postScriptName·fullName 일관 추출
  - [x] `_copyFilePath`로 URL attribute → `CFURLGetFileSystemRepresentation` → UTF-8 Dart String
- [x] style 유도 로직 — `_deriveStyle(italicBit, slant)`
  - [x] italicBit true → italic
  - [x] italicBit false + |slant| > 0.05 → oblique
  - [x] else → normal
- [x] isMonospace·isSymbol — symbolic bitmask에서 bit/class 추출
- [x] family 그룹핑 후 `FontFamily(faces: [...], weightAxis: ...)` 생성
- [x] variation axis 로직 (`_copyWghtAxis`)은 Phase 4에서 일반화 — 이 phase에서는 기존 로직 그대로 유지

### 헬퍼 유틸

- [x] `mapStretch(double) → int` — CoreText의 −1.0~1.0 범위를 DWrite 1~9 스케일과 동일한 버킷으로 매핑
  - 공식: `(normalized * 4 + 5).round().clamp(1, 9)`
  - 앵커: −1.0 → 1 (Ultra-Condensed), 0.0 → 5 (Normal), 1.0 → 9 (Ultra-Expanded)
  - NaN / 범위 밖 값은 5 (Normal)로 폴백
- [x] `_deriveStyle(bool, double) → FontStyle` — italic/oblique/normal 결정
- [x] `_copyFilePath(desc, arena) → String?` — `CFURLGetFileSystemRepresentation` 사용 (4096 바이트 버퍼, PATH_MAX 여유 + α)
- [x] `_readSymbolicFromTraits` — CFNumber Int32로 읽고 `& 0xFFFFFFFF`로 unsigned 재해석

### CTFont lifetime

- [x] `CTFontCreateWithFontDescriptor` 사용 자체 불필요화 — descriptor의 `kCTFontNameAttribute`가 이미 PostScript name을 제공. CTFont 생성·해제 비용 및 누수 위험 제거.

## 테스트

- [x] `test/macos_stretch_mapping_test.dart` 신설
  - anchor 값 5개 (−1.0, −0.5, 0.0, 0.5, 1.0)
  - intermediate bucket 4개 (−0.75, −0.25, 0.25, 0.75)
  - off-bucket nearest-snap 3개
  - NaN·infinity·out-of-range 폴백 5개
  - clamp boundary 2개
  - **총 19개 테스트 추가** — 전 케이스 통과
- [ ] 실 macOS 머신에서 수동 검증 필요 (본 Phase는 Windows 머신에서 작성되어 CoreText end-to-end 확인 불가):
  - [ ] `SF Pro` / `Helvetica Neue` family가 여러 `FontFace` 포함
  - [ ] 각 face의 `filePath`이 `/System/Library/Fonts/` 또는 `/Library/Fonts/` 아래 경로
  - [ ] `Menlo`: `isMonospace == true`
  - [ ] `Helvetica Neue`의 Italic face: `style == FontStyle.italic`
  - [ ] `postScriptName` 전역 유일성 (중복 없음)
  - [ ] autorelease pool 기반 누수 방지 회귀 없음 — scan당 증가량 0 수렴
- [ ] `test/macos_weight_mapping_test.dart` 회귀 없이 그대로 통과 (Windows에서도 실행 가능: 41개 기존 + 19개 신규 = 60/60 통과)

## 완료 조건

- [x] `dart test` 전 케이스 통과 (60/60 — Phase 1·2 포함)
- [x] `dart analyze` warning 0 (lib + example 둘 다)
- [x] `dart format --set-exit-if-changed` 통과
- [ ] **macOS 실 머신에서 `dart test` + 수동 scan 검증** — 본 Windows 세션에서는 수행 불가, 커밋 전 맥 환경에서 확인 필요
- [ ] autorelease pool 기반 누수 방지 회귀 없음 (macOS 측정 필요)

## 구현 중 결정 사항

### PostScript name 추출 경로
원 기획서에서는 "descriptor → CTFont 변환 후 `CTFontCopyPostScriptName`" 흐름을 제안했으나, `kCTFontNameAttribute`가 **이미 canonical PostScript name을 반환**한다는 점을 확인하고 CTFont 생성 단계 제거. face당 1회의 CFCreate·CFRelease 절약 + autorelease pool 외부에서 생성할 위험 원천 차단.

### Stretch mapping 공식
Windows의 `DWRITE_FONT_STRETCH` (1~9 정수)와 CoreText의 `kCTFontWidthTrait` (−1.0~1.0 연속)을 **동일한 9단계 스케일**로 맞추기 위해 선형 매핑 채택. 단순 공식 `(normalized * 4 + 5).round().clamp(1, 9)`는 아래 anchor에서 정확한 값을 만들어냄:

| normalized | stretch | 명칭 |
|---|---|---|
| −1.0 | 1 | Ultra-Condensed |
| −0.75 | 2 | Extra-Condensed |
| −0.5 | 3 | Condensed |
| −0.25 | 4 | Semi-Condensed |
| 0.0 | 5 | Normal |
| 0.25 | 6 | Semi-Expanded |
| 0.5 | 7 | Expanded |
| 0.75 | 8 | Extra-Expanded |
| 1.0 | 9 | Ultra-Expanded |

### Italic vs Oblique 구분 threshold
CoreText는 "designed italic vs synthesized slant"를 명시적 플래그로 주지 않음. 대신 symbolic trait의 italic bit와 slant scalar 값을 조합해 근사:
- `italicBit == true` (CoreText가 italic이라고 인식함) → `FontStyle.italic`
- `italicBit == false`면서 `|slant| > 0.05` (무시할 수 없는 기울기) → `FontStyle.oblique`
- 둘 다 아니면 `FontStyle.normal`

threshold 0.05는 "rendering rounding이 만든 0.02 수준의 noise는 normal로 취급, 실제 기울기 있는 값만 oblique로 분류"하는 경험값. 실 macOS에서 검증 필요.

### Symbolic trait int32 → uint32 재해석
`CFNumberGetValue`는 unsigned 타입을 지원하지 않음. `CTFontSymbolicTraits`는 `uint32_t`로 선언되어 있지만 `kCTFontClassMaskTrait` 같은 고비트 값은 Int32로 읽으면 음수로 나옴. `out.value & 0xFFFFFFFF`로 64-bit unsigned 영역으로 옮겨 비트 비교 정확성 확보.

## 위험 / 주의사항 (원본 + 사후 보강)

- `CTFontCopyPostScriptName`는 결국 호출 안 함 (위 결정 사항 참조) — descriptor attribute 경로가 더 깔끔.
- symbolic trait의 italic bit와 slant scalar 값이 **불일치**하는 폰트가 있음 (italic bit 켜져 있는데 slant가 0.0). `_deriveStyle`는 italicBit 우선 신뢰하도록 구현.
- stretch 스케일링이 Windows DWrite(1~9 정수)와 모양 맞아야 모델 필드 단일. 두 플랫폼 공통 버킷을 `mapStretch` 함수에 확정 — Phase 2에서 DWrite가 리턴하는 1~9 값과 동일 범위.
- `kCTFontURLAttribute`가 모든 descriptor에 존재하는 건 아님. 메모리 폰트·임베디드 폰트면 `null` 반환 가능 — `filePath` nullable 설계와 일치.
- autorelease pool 바깥에서 descriptor attribute 호출 시 ~수십 KB/scan 누수 가능. 기존 `inAutoreleasePool` 래퍼 내부에서만 호출 유지 — 모든 신규 `_copyStringAttribute`·`_copyFilePath`는 기존 scan 루프 안에서 실행되므로 자동으로 풀 안에서 돌아감.
- **본 Phase는 Windows에서 작성됨** — CoreText 코드 실행·검증은 macOS 머신에서 별도로 진행 필수. 구현 중 결정 사항(threshold 0.05, stretch 공식 등)은 실 데이터로 재조정 가능성 있음.
