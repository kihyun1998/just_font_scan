# Phase 2 — Windows face 메타데이터

> 상위 기획: [ROADMAP_FACE_METADATA.md](./ROADMAP_FACE_METADATA.md)

## 목적

DirectWrite에서 face별 속성을 추출해 `FontFace`를 채운다. 현재 `windows_font_scanner.dart`의 face 루프가 `GetWeight` 하나만 호출하는 구조를 face 전체 메타데이터 수집으로 확장한다.

## 선행 조건

- **Phase 1 완료**: `FontFace`·`FontStyle`·`VariationAxis` 모델 사용 가능해야 함

## 변경 대상 파일

- `lib/src/windows/dwrite_bindings.dart` — 바인딩 추가
- `lib/src/windows/windows_font_scanner.dart` — face 루프 재작성
- `test/just_font_scan_test.dart` — 필요시 Windows-전용 통합 테스트 추가

## Task 체크리스트

### 바인딩 (`dwrite_bindings.dart`)

- [x] `IDWriteFont` vtable 슬롯 추가
  - [x] [5] `GetStretch` → `DWRITE_FONT_STRETCH` (Int32)
  - [x] [6] `GetStyle` → `DWRITE_FONT_STYLE` (Int32: 0=Normal, 1=Oblique, 2=Italic)
  - [x] [7] `IsSymbolFont` → `BOOL`
  - [x] [8] `GetFaceNames` → `IDWriteLocalizedStrings**`
  - [x] [9] `GetInformationalStrings(id, **strings, *exists)` — PostScript/Full name 용
- [x] `DWRITE_INFORMATIONAL_STRING_ID` 상수
  - [x] `DWRITE_INFORMATIONAL_STRING_FULL_NAME = 16` *(기획서의 초안값 4는 오기였음 — MS SDK 실제 값은 16)*
  - [x] `DWRITE_INFORMATIONAL_STRING_POSTSCRIPT_NAME = 17` *(초안값 12도 오기 — 실제 값은 17)*
- [x] `IDWriteFont1` 지원
  - [x] IID: `{acd16696-8c14-4f5d-877e-fe3fc1d32738}` — 검증 완료
  - [x] `allocIIDWriteFont1(Arena arena)` 헬퍼
  - [x] `IsMonospacedFont` — vtable slot 17 (IDWriteFont 14 슬롯 + GetMetrics/GetPanose/GetUnicodeRanges 후)
  - [x] QI 실패시 폴백 (`false`)
- [x] `IDWriteFontFace` → 파일 경로 추출
  - [x] `GetFiles(*count, files)` 래퍼 — slot 4, 2-phase 호출 (nullptr → count → alloc → files)
  - [x] `IDWriteFontFile::GetReferenceKey(**key, *keySize)` — slot 3
  - [x] `IDWriteFontFile::GetLoader(**loader)` — slot 4
  - [x] `IDWriteLocalFontFileLoader` IID + QI
  - [x] `GetFilePathLengthFromKey` — slot 4
  - [x] `GetFilePathFromKey` — slot 5 (UTF-16 → Dart String)

### 스캐너 (`windows_font_scanner.dart`)

- [x] `_scanFamily` → face 루프 재구성
  - [x] 각 face에서 `FontFace` 구성
  - [x] weight·stretch·style·faceName·isMonospace·isSymbol 추출
  - [x] postScriptName·fullName 추출 (실패시 `null`)
  - [x] filePath 추출 (loader가 local이 아니면 폴백 파서로 전환)
- [x] family 반환부 수정: `FontFamily(name, faces: [...], weightAxis: ...)` 로
- [x] 기존 weightSet dedup 로직 제거 — `faces`에 원본 face 리스트 그대로 유지 (같은 weight·다른 style이 별도 face로 유지됨)
- [x] variation axis 수집은 기존 `_tryReadWghtAxis` 그대로 유지 (Phase 4에서 일반화)
- [x] `_tryGetFontFilePath(font, arena)` 헬퍼 신설 — face 경유 파일 경로 추출

### 헬퍼 유틸

- [x] `_dwriteStyleToEnum(int raw) → FontStyle` 매핑 (0→normal, 1→oblique, 2→italic)
- [x] `_dwriteStretchToInt(int raw) → int` (1~9 범위 외 값은 5로 폴백)
- [x] `_getInformationalString(font, id, arena) → String?` — 공통화
- [x] `_getFaceName(font, arena) → String?` — GetFaceNames + 기존 _getLocalizedString 재사용
- [x] `_tryIsMonospace(font, arena) → bool` — IDWriteFont1 QI 래퍼
- [x] `_extractPathFromSystemKey(key, keySize) → String?` — Windows 11 font-cache 로더 폴백

## 실전에서 발견한 이슈

### `IDWriteLocalFontFileLoader` QI가 Windows 11에서 실패

Windows 10 후기 빌드 + Windows 11의 **Font Cache Service**가 내부적으로 독점 로더로 시스템 폰트를 서빙하게 되면서, `QueryInterface(IID_IDWriteLocalFontFileLoader)`가 전 폰트에서 `E_NOINTERFACE` 반환. → `GetFilePathFromKey` 경로 자체 사용 불가.

**해결**: `IDWriteFontFile::GetReferenceKey`가 돌려주는 키 바이트를 직접 파싱. 시스템 폰트 캐시 로더의 키 포맷은 **2가지 레이아웃**:

- **Layout A — 시스템 폰트** (e.g. Arial):
  - `[0..7]` FILETIME (마지막 수정시각)
  - `[8..9]` UINT16 태그 = `0x002A`
  - `[10..N]` WCHAR 파일명 (디렉터리 제외)
  - `[N..N+1]` UTF-16 NUL

- **Layout B — 사용자 설치·앱 패키지 폰트** (e.g. Pretendard, Cascadia Code from Windows Terminal):
  - `[0..7]` FILETIME
  - `[8..N]` WCHAR 절대 경로 (`C:\...` 또는 `\\...`)
  - `[N..N+1]` UTF-16 NUL

두 레이아웃은 offset 8의 첫 WCHAR로 구분:
- `0x002A` → Layout A (`%SystemRoot%\Fonts\{filename}`으로 조합, LOCALAPPDATA 폴더도 확인)
- ASCII 알파벳(드라이브 레터) 또는 `\\`(UNC) → Layout B (그대로 사용)

먼저 QI 시도, 실패시 폴백으로 자동 전환. 217 family / 1165 face 기준 **filePath 100% 커버리지** 확인.

### DWrite의 합성 oblique face

DirectWrite는 italic face가 없는 family에 대해 **합성(synthesized) oblique** face를 자동으로 리포트. 예를 들어 Arial family는 실제 파일 8개인데 DWrite는 14개 face를 노출 (oblique 6개 추가). 이들은 `postScriptName`·`filePath`가 원본과 동일 — `scan_faces.dart`에서 PostScript 중복 401건은 이 합성 face의 예상된 결과. 필터링은 이번 범위 밖 (`GetSimulations` 호출로 판별 가능하지만 "리얼한 face만" 노출하는 건 별도 설계 결정).

## 테스트

- [x] 스캔 결과에서 face별 필드 검증 (수동)
  - [x] `Arial` family: Regular + Italic + Bold + Bold Italic 모두 존재
  - [x] 각 face의 `filePath` non-null, 실제 `.ttf`/`.otf` 파일로 resolve
  - [x] `Cascadia Mono`: `isMonospace == true`
  - [x] `Segoe UI`: `italic` style 가진 face 존재
- [x] `tool/scan_faces.dart` 신설 — family·face별 출력 + 커버리지 통계 + PostScript 중복 검출
- [x] `tool/leak_check.dart` 재실행 — face당 COM 호출 증가에도 누수 없음
  - [x] 1500 scan 기준 round간 delta < ±0.3 MB (이전 baseline 대비 회귀 없음)

## 완료 조건

- [x] `dart test` 전 케이스 통과 (41/41)
- [x] `dart analyze` warning 0 (lib + example 둘 다)
- [x] Windows 실 머신에서 `dart run tool/scan_faces.dart` 출력이 예상대로 — 217 family / 1165 face, filePath 100%
- [x] 메모리 누수 회귀 없음 (기준: 1500 scan 후 ±1MB 이내 노이즈)

## 위험 / 주의사항 (원본 + 사후 보강)

- `IDWriteFontFile::GetReferenceKey`의 key 포맷은 **문서화되지 않음**. 현재 파서는 실 관찰 기반 — 미래의 Windows 업데이트에서 포맷이 바뀔 가능성 있음. 두 layout을 방어적으로 검증(드라이브 레터 범위, NUL 터미네이터, 홀수 바이트 체크) 후 파싱.
- `IDWriteFont::GetInformationalStrings`는 `exists` out 파라미터가 `FALSE`로 돌아올 수 있음. 이 경우 해당 필드는 `null`.
- `DWRITE_FONT_STYLE`의 순서가 직관과 반대: 1=Oblique, 2=Italic. 매핑 실수 주의 — 테스트에서 "Oblique"로 뜨는 face가 맞게 `FontStyle.oblique`로 변환되는지 수동 확인 완료.
- vtable slot 번호는 `dwrite.h` / `dwrite_1.h` 선언 순서대로. `IDWriteFont1::IsMonospacedFont`는 14 (IDWriteFont base) + 3 (GetMetrics, GetPanose, GetUnicodeRanges) = slot 17.
- face마다 FontFace 추출 → family당 2~4배 COM call. 메모리 누수는 없지만 성능 체감은 측정 필요 — 현재 `JustFontScan._cache`가 1회 스캔 후 캐싱하므로 실사용 영향 미미.
- DWrite의 합성 oblique face는 "진짜" face가 아님을 사용자에게 알릴지 결정 — 현재는 DWrite가 주는 그대로 노출. 필요시 Phase 5에서 `GetSimulations` 기반 필터 옵션 추가 고려.
