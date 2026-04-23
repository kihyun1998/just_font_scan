# Face-level 메타데이터 확장 기획

## 배경

현재 모델은 **family 단위로만** 정보를 담고 있고, face별로 달라지는 속성을 표현할 구조가 없다.

- `lib/src/models.dart:5-60` — `FontFamily { name, weights, weightAxis }` 단일 클래스. `weights`는 `List<int>` 이산 리스트 하나뿐이라 "Arial Regular vs Arial Italic vs Arial Narrow"를 구분할 방법이 없다.
- `style`(normal/italic), `stretch`(condensed/expanded), `postScriptName`, `filePath` 같은 속성은 **face마다 다르므로** family 필드로 올릴 수 없다.
- `lib/src/windows/windows_font_scanner.dart:185-219`, `lib/src/macos/macos_font_scanner.dart` — 현재 루프는 face를 돌면서도 `GetWeight()`만 집계하고 나머지 face 정보는 버린다.

결과: 폰트 피커·프리뷰·라이선스 검수·임베딩 같은 실사용 시나리오에서 "스캔 결과만으로 부족해 다시 OS에 쿼리해야 하는" 상황이 잦다. DirectWrite·CoreText 양쪽이 이미 노출하고 있는 메타데이터를 흘리고 있는 셈.

variable font 지원(v0.3.0, `weightAxis`)과 달리 이번에는 **face 단위 계층**을 도입하는 구조 변경이라 breaking change가 동반된다.

---

## 목표 / 비목표

**목표**
- face 단위 계층(`FontFace`)을 도입해 face별로 달라지는 속성을 정확히 노출한다.
- 모든 OpenType 등록 variation 축(`wght`, `wdth`, `slnt`, `ital`, `opsz`)을 family-level에서 구조화해 노출한다.
- Windows·macOS 양쪽이 **동일한 필드 집합**을 보장한다. 한쪽만 되는 속성은 이번 범위에서 제외한다.
- 파일 경로·PostScript 이름을 노출해 폰트 매칭·프리뷰·임베딩 유스케이스를 1급으로 지원한다.

**비목표 (이번 범위에서 제외, 차기 릴리즈)**
- 저작권·디자이너·라이선스·버전 등 informational string 계열 (C 계층).
- OS/2 PANOSE 기반 serif/sans 분류.
- 지원 유니코드 범위 (`IDWriteFont1::GetUnicodeRanges` / `CTFontCopyCharacterSet`).
- 폰트 메트릭스 (ascent/descent/xHeight 등).
- OpenType feature 태그(한쪽 플랫폼만 노출).
- Simulations(bold/oblique synthesis, DWrite만 노출).

---

## 데이터 모델

### Before

```dart
class FontFamily {
  final String name;
  final List<int> weights;
  final WeightAxis? weightAxis;
}

class WeightAxis { int min, max, defaultValue; }
```

### After

```dart
class FontFamily {
  final String name;

  // Variation 축은 family resource 단위 속성 — face마다 다르지 않음
  final VariationAxis? weightAxis;
  final VariationAxis? widthAxis;
  final VariationAxis? slantAxis;
  final VariationAxis? italicAxis;
  final VariationAxis? opticalSizeAxis;

  // face별 메타데이터
  final List<FontFace> faces;

  // 편의 getter — 기존 호출부 호환
  List<int> get weights =>
      (faces.map((f) => f.weight).toSet().toList()..sort());
}

class FontFace {
  final int weight;            // 1~1000
  final FontStyle style;       // enum
  final int stretch;           // 1~9 (ultra-condensed ~ ultra-expanded)
  final String faceName;       // "Regular", "Bold Italic"
  final String? postScriptName;
  final String? fullName;
  final String? filePath;      // 메모리/원격 폰트면 null
  final bool isMonospace;
  final bool isSymbol;
}

enum FontStyle { normal, italic, oblique }

class VariationAxis {
  final int min;
  final int max;
  final int defaultValue;
}

// 0.3.x 호환을 위해 typedef 유지
typedef WeightAxis = VariationAxis;
```

### 설계 판단

**1. 축은 family-level, 나머지는 face-level**
variation axis는 폰트 **리소스 파일** 단위 속성(한 .ttf 안 모든 face가 같은 축 공유)이고, weight/style/stretch는 face마다 다른 물리적 사실. 이 구분을 모델에 직접 반영한다.

**2. 축을 `Map<String, VariationAxis>`가 아니라 named field로**
등록된 축은 5개로 고정(`wght`, `wdth`, `slnt`, `ital`, `opsz`). Map으로 하면 타입 안전성·자동완성을 잃고 얻는 게 없다. 커스텀 축 지원이 필요해지면 그때 `customAxes: Map<String, VariationAxis>`를 추가한다.

**3. `weights` 필드는 getter로 유지**
기존 사용자가 `family.weights`를 참조 중이므로, `faces`에서 도출되는 편의 getter로 남긴다. 한 줄 구현이고 deprecate 하지 않는다.

**4. `WeightAxis` → `VariationAxis` 개명**
축이 여럿 생기면서 이름이 weight 전용으로 보이지 않도록 일반화. 기존 이름은 `typedef WeightAxis = VariationAxis;`로 유지해 소스 호환성 확보.

**5. 대안 검토 — flat `List<FontFace>`만 반환**
Family 개념 없이 face 행 리스트만 반환하는 구조. 쿼리는 유연하지만 UI에서 family 그룹핑을 다시 해야 하고, DirectWrite·CoreText 둘 다 **family-first API**라 네이티브와 맞지 않음. 채택하지 않는다.

---

## 플랫폼 API 매핑

### A. Face identity (🟢 쉬움)

| 필드 | Windows | macOS |
|---|---|---|
| `weight` (기존) | `IDWriteFont::GetWeight` [4] | `kCTFontWeightTrait` → CSS scale 매핑 |
| `style` | `IDWriteFont::GetStyle` [6] → enum | `kCTFontSlantTrait` 부호 + `kCTFontItalicTrait` |
| `stretch` | `IDWriteFont::GetStretch` [5] | `kCTFontWidthTrait` → 1~9 매핑 |
| `isMonospace` | `IDWriteFont1::IsMonospacedFont` | `kCTFontMonoSpaceTrait` |
| `isSymbol` | `IDWriteFont::IsSymbolFont` [7] | `kCTFontSymbolicTraits` (`kCTFontTraitSymbolic`) |
| `faceName` | `IDWriteFont::GetFaceNames` + localized string | `kCTFontSubFamilyNameKey` |

DWrite `IDWriteFont1`은 Windows 8+에서 사용 가능. `QueryInterface` 실패 시 `isMonospace = false` 폴백.

### B. 파일 & 식별자 (🟡 중간)

| 필드 | Windows | macOS |
|---|---|---|
| `filePath` | `IDWriteFontFace::GetFiles` → `IDWriteFontFile::GetReferenceKey` → `IDWriteLocalFontFileLoader::GetFilePathFromKey` | `CTFontDescriptorCopyAttribute(desc, kCTFontURLAttribute)` → `CFURL` → POSIX path |
| `postScriptName` | `IDWriteFont::GetInformationalStrings(POSTSCRIPT_NAME)` | `CTFontCopyPostScriptName` |
| `fullName` | `IDWriteFont::GetInformationalStrings(FULL_NAME)` | `CTFontDescriptorCopyAttribute(kCTFontDisplayNameAttribute)` 또는 `CTFontCopyName(kCTFontFullNameKey)` |

`filePath`는 non-local 로더(메모리/네트워크)로 로드된 폰트면 `null`. 시스템 컬렉션은 대부분 local이므로 실 영향 미미.

### C. Variation 축 확장 (🟢 쉬움 — 기존 파이프라인 재사용)

| 축 | tag | Windows | macOS |
|---|---|---|---|
| `wght` (기존) | `'wght'` = 0x74686777 | `GetFontAxisRanges` 루프 | `CTFontCopyVariationAxes` |
| `wdth` | `'wdth'` = 0x68746477 | 동일 (switch 분기 추가) | 동일 |
| `slnt` | `'slnt'` = 0x746E6C73 | 동일 | 동일 |
| `ital` | `'ital'` = 0x6C617469 | 동일 | 동일 |
| `opsz` | `'opsz'` = 0x7A73706F | 동일 | 동일 |

`lib/src/windows/windows_font_scanner.dart:266-315` `_readWghtAxisFromResource`를 일반화해 `Map<int, VariationAxis>`를 반환하도록 수정. macOS 쪽 축 수집 루프도 동일하게 일반화.

---

## 구현 단계

각 Phase는 별도 문서로 상세 체크리스트·완료 조건을 관리한다. **순차적으로 한 phase씩 완결**하고 다음으로 넘어간다.

| Phase | 주제 | 문서 |
|---|---|---|
| 1 | 모델 리팩터 (breaking) | [ROADMAP_FACE_METADATA_PHASE1.md](./ROADMAP_FACE_METADATA_PHASE1.md) |
| 2 | Windows face 메타데이터 | [ROADMAP_FACE_METADATA_PHASE2.md](./ROADMAP_FACE_METADATA_PHASE2.md) |
| 3 | macOS face 메타데이터 | [ROADMAP_FACE_METADATA_PHASE3.md](./ROADMAP_FACE_METADATA_PHASE3.md) |
| 4 | Variation 축 일반화 | [ROADMAP_FACE_METADATA_PHASE4.md](./ROADMAP_FACE_METADATA_PHASE4.md) |
| 5 | 문서 & 예제 | [ROADMAP_FACE_METADATA_PHASE5.md](./ROADMAP_FACE_METADATA_PHASE5.md) |

Phase 1 → 2 → 3 → 4 → 5 순서로 진행. 각 phase 종료 시점에 빌드·테스트가 통과해야 한다 — 중간 단계에서 빌드 깨진 상태로 두지 않는다. Phase 1의 모델 변경으로 양 플랫폼 스캐너가 일시 깨지는 문제는 Phase 1 자체에서 **최소 수정으로 빌드 유지** 후 Phase 2·3에서 실질 구현으로 대체한다.

---

## Breaking changes & 마이그레이션

### 깨지는 것
```dart
// 0.3.x
final family = FontFamily(name: 'Arial', weights: [400, 700]);
```
이 리터럴은 컴파일 에러. `weights`가 getter가 되면서 생성자 파라미터에서 빠진다.

### 마이그레이션
```dart
// 0.4.x
final family = FontFamily(
  name: 'Arial',
  faces: [
    FontFace(weight: 400, style: FontStyle.normal, ...),
    FontFace(weight: 700, style: FontStyle.normal, ...),
  ],
);
// family.weights 는 여전히 [400, 700] 반환 (getter)
```

### 왜 non-breaking 옵션을 택하지 않는가
- `faces` 옵셔널로 두고 `weights`만으로 생성하게 허용 → 내부에 "dummy FontFace" 생성 로직 생겨 모델 의미 흐려짐.
- 별도 `FontFamilyInfo` 클래스 신설 → 사용자 혼란.
- 0.x 단계 package이므로 **지금 제대로 깨고 가는 것이 장기적 유지보수에 유리.**

---

## 테스트 전략

### 유닛 테스트 (`test/just_font_scan_test.dart`)
- `FontFamily.weights` getter가 `faces`에서 정확히 도출되는지.
- 중복 weight 가진 faces(Regular + Italic 둘 다 400)에서 `weights`가 dedup 되는지.
- `FontStyle` enum equality / toString.
- 모든 variation axis 필드에 대한 `null` / non-null 동등성.
- `VariationAxis` / `WeightAxis` typedef alias 동작 확인.

### 통합 테스트 (`test/macos_scan_integration_test.dart` 확장 + Windows 추가)
- 실 시스템 폰트 스캔 후 검증:
  - `faces.length >= 1` (최소 한 face 있음)
  - 파일 경로 non-null 비율 ≥ 95%
  - Segoe UI Variable / SF Pro 같은 variable font family에서 `weightAxis`, `widthAxis` 또는 `opticalSizeAxis` 하나 이상 non-null
  - `postScriptName` 중복 없음 (전역 유일성 검증)

### 메모리 누수 (`tool/leak_check.dart`)
- face 루프당 COM 객체 추가 3~4개 (face, file, loader, informational strings) 증가 → 1500 scan에서 누수 여부 재검증. 기존 "warm 이후 delta 노이즈 수준" 기준 유지.

---

## 차기 릴리즈 여지

이번 구조가 세워지면 다음은 모두 **필드 추가만으로** 가능:

- C 계층 (copyright·designer·license 등 8개 문자열) → `FontFace`에 필드 추가 (또는 `FontFace.info: FaceInfo?` 서브 객체로 묶기)
- 메트릭스 → `FontFace.metrics: FontMetrics?` 선택적 필드
- 지원 유니코드 범위 → `FontFace.unicodeRanges: List<(int, int)>?`
- 커스텀 variation 축 → `FontFamily.customAxes: Map<String, VariationAxis>`
- PANOSE 기반 분류 → `FontFamily.category: FontCategory?` (파일 파싱 별도 모듈)

모두 기존 필드에 영향 없이 확장 가능하므로, 이번 한 번의 breaking change 이후로는 **additive-only** 진화가 가능해진다.
