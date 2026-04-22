# Variable Font (`wght` 축) 지원 기획

## 배경

현재 스캐너는 폰트 패밀리의 weight를 **이산 정수 리스트**(`List<int>`)로만 표현한다. OpenType 1.8 (2016)의 variable font 스펙에 정의된 **연속 weight 축**(예: Segoe UI Variable, SF Pro, Inter Variable 등)은 다음과 같은 한계로 누락된다.

- `lib/src/models.dart:13` — `FontFamily.weights` 필드는 `List<int>` 하나뿐. 연속 범위를 담을 구조가 없다.
- `lib/src/windows/windows_font_scanner.dart:181-205` — `_getFamilyWeights`는 `IDWriteFont::GetWeight()`만 호출. 축 정보를 노출하는 `IDWriteFontFace5` / `IDWriteFontResource`를 사용하지 않는다.
- `lib/src/macos/macos_font_scanner.dart:109-130` — `_copyWeight`는 `kCTFontWeightTrait` 스칼라 하나만 읽는다. `kCTFontVariationAxesAttribute`를 쿼리하지 않는다.

결과: variable font를 만나도 **폰트 파일에 선언된 named instance들의 weight**만 수집되고, `wght` 축의 연속 범위(min/max/default)는 유실된다.

variable font는 macOS 전용이 아니며 Windows 11(Segoe UI Variable, Bahnschrift)·macOS(SF Pro, New York) 모두 기본 탑재된다. 양쪽 구현 모두 필요하다.

---

## 목표 / 비목표

**목표**
- 시스템 폰트의 `wght` 축 범위를 `min` / `max` / `default` 로 노출한다.
- 기존 `weights` 필드의 의미와 호출부 호환성을 유지한다(breaking 없음).
- 플랫폼 API가 없거나 오래된 OS에서는 조용히 폴백한다.

**비목표 (추후 확장 여지만 남김)**
- `wdth` / `slnt` / `ital` / `opsz` / 커스텀 축 지원.
- 연속 weight 값으로 폰트를 실제 렌더링 / instantiate 하는 기능.
- 폰트 파일 직접 파싱(fvar 테이블 등).

---

## 데이터 모델

`lib/src/models.dart` 에 nullable 필드 하나 추가.

```dart
class FontFamily {
  final String name;
  final List<int> weights;       // 기존: 이산 weight (static + named instance)
  final WeightAxis? weightAxis;  // 신규: variable font의 연속 wght 축
  ...
}

class WeightAxis {
  final int min;           // 보통 1~1000 스케일, int로 반올림
  final int max;
  final int defaultValue;
  const WeightAxis({required this.min, required this.max, required this.defaultValue});
}
```

**의미 규약**
- `weightAxis != null` → variable font가 패밀리에 포함됨. `weights`에는 named instance들이 들어간다(비어 있을 수도 있음).
- `weightAxis == null` → 기존과 동일한 static 패밀리.
- 한 패밀리에 static face + VF face가 공존하면 둘 다 채운다(`weights`에 static weight 누적, `weightAxis`는 VF 축).
- `==` / `hashCode` / `toString` 업데이트 필요.

**왜 별도 필드인가**
- `weights`를 유니온 타입으로 바꾸면 모든 호출부가 깨진다.
- 향후 다축 확장 시 `Map<String, FontAxis> variationAxes` 로 일반화 가능하지만, 현재 스코프는 `wght`뿐이므로 오버엔지니어링 회피.

---

## 플랫폼별 구현

### macOS (CoreText) — `lib/src/macos/`

현재 `_scanDescriptor`는 이름 + weight 스칼라만 수집한다. 같은 descriptor에서 VF 축을 추가로 추출한다.

**API 경로**
1. `CTFontDescriptorCopyAttribute(desc, kCTFontVariationAxesAttribute)` → `CFArrayRef<CFDictionaryRef>?`
2. null이면 static → 기존 경로 유지.
3. null 아니면 CFArray 순회, 각 dict에서:
   - `kCTFontVariationAxisIdentifierKey` → CFNumber (Int64). FourCC `'wght'` = `0x77676874` 매칭.
   - `kCTFontVariationAxisMinimumValueKey` / `MaximumValueKey` / `DefaultValueKey` → CFNumber (Double).
4. `wght` 축 dict 발견 시 round해서 `WeightAxis` 생성.

**중복 처리**
한 패밀리에 VF descriptor가 여러 개(Roman / Italic 등) 포함될 수 있다. `weightsByFamily`와 병행하는 `axisByFamily` Map을 두고 패밀리당 **첫 번째 VF descriptor의 축만 취한다**. 이탤릭 축에 따라 wght 범위가 달라지는 경우는 실무상 드물며, 발견되면 min/max 교집합으로 보수화한다.

**바인딩 추가** (`coretext_bindings.dart`)
- extern CFString 심볼 4개: `kCTFontVariationAxesAttribute`, `kCTFontVariationAxisIdentifierKey`, `kCTFontVariationAxisMinimumValueKey`, `kCTFontVariationAxisMaximumValueKey`, `kCTFontVariationAxisDefaultValueKey`
- Int64 경로용 상수: `kCFNumberSInt64Type = 4`
- 기존 `cfDictionaryGetValue` / `cfNumberGetValue` / `cfArrayGetCount` / `cfArrayGetValueAtIndex` 는 재사용.

**성능 영향**
descriptor마다 `CopyAttribute` 1회 추가 — 대부분의 static 폰트는 null 반환으로 즉시 종료. 체감 가능 수준 아님(+5~10% 예상).

### Windows (DirectWrite) — `lib/src/windows/`

현재 `_getFamilyWeights` 루프에서 font마다 `GetWeight()`만 부른다. 같은 루프 내부에서 VF 축 추출을 시도한다.

**API 경로**
1. `IDWriteFont::CreateFontFace()` → `IDWriteFontFace*`
2. `QueryInterface(IID_IDWriteFontFace5)` 시도. 실패(Win10 1803 이전)하면 → 기존 경로 폴백.
3. `IDWriteFontFace5::HasVariations()` 가 false면 static → 축 수집 스킵.
4. true면 `GetFontResource(&IDWriteFontResource)` → `GetFontAxisCount()` + `GetFontAxisRanges(ranges, count)`
5. `DWRITE_FONT_AXIS_RANGE` 배열에서 `axisTag == 'wght'` (`0x74686777`, little-endian FourCC)인 엔트리 필터.
6. 추가로 `GetDefaultFontAxisValues()` 로 `wght`의 default 값 획득(`DWRITE_FONT_AXIS_VALUE`).
7. `FLOAT` 값들을 `int`로 반올림하여 `WeightAxis` 생성.

**중복 처리**
패밀리 내 여러 font가 같은 VF resource를 가리킬 수 있다. `IDWriteFontResource*` 포인터 값을 set에 저장해 **패밀리당 첫 번째 VF resource에서만** 축을 추출한다.

**COM lifetime**
`fontFace`, `fontFace5`(QI 결과), `fontResource` 모두 `comRelease` 필수. 기존 `try { ... } finally { comRelease(...); }` 패턴 그대로.

**바인딩 추가** (`dwrite_bindings.dart`)
- `IID_IDWriteFontFace5` GUID 상수.
- `IDWriteFontFace5` vtable offset: `HasVariations`, `GetFontResource`.
- `IDWriteFontResource` vtable offset: `GetFontAxisCount`, `GetFontAxisRanges`, `GetDefaultFontAxisValues`.
- 구조체: `DWRITE_FONT_AXIS_RANGE { UINT32 axisTag; FLOAT minValue; FLOAT maxValue; }`, `DWRITE_FONT_AXIS_VALUE { UINT32 axisTag; FLOAT value; }`.

**호환성**
`IDWriteFontFace5`는 Windows 10 1803 (build 17134, 2018년 4월) 부터. 그 이전 OS에서는 QI 실패 → `weightAxis = null` 폴백. `IDWriteFont::CreateFontFace`만 추가로 1회 호출되므로 비용은 미미.

---

## 구현 단계

### Phase 1 — 모델 (breaking 없음 확인)
- [ ] `lib/src/models.dart` — `WeightAxis` 클래스 추가, `FontFamily.weightAxis` 필드 추가.
- [ ] `==` / `hashCode` / `toString` 업데이트.
- [ ] 기존 테스트 전부 초록 유지.

### Phase 2 — macOS 구현 (바인딩 단순, 전체 플로우 먼저 검증)
- [ ] `coretext_bindings.dart` — extern 심볼 4개 + `kCFNumberSInt64Type` 추가.
- [ ] `macos_font_scanner.dart` — `_scanInPool`에 `axisByFamily` 누산기 추가, `_scanDescriptor`에서 `_copyVariationAxis` 호출.
- [ ] `_copyVariationAxis` 신설: dict 순회 → `wght` 매칭 → `WeightAxis` 반환.
- [ ] SF Pro로 눈 확인 (`tool/` 또는 `example/`에 축 출력 스크립트).

### Phase 3 — Windows 구현 (바인딩 분량 큼, PR 분리 추천)
- [ ] `dwrite_bindings.dart` — GUID, vtable offset, 구조체 typedef 추가.
- [ ] `windows_font_scanner.dart` — `_getFamilyWeights` 내부에서 VF 분기, `_copyVariationAxis` 신설.
- [ ] `IDWriteFontResource` dedupe set 도입.
- [ ] Segoe UI Variable / Bahnschrift 로 눈 확인.

### Phase 4 — 문서
- [ ] README — variable font 감지 지원 섹션 추가 (예제 출력 포함).
- [ ] CHANGELOG — non-breaking feature 추가로 표기.
- [ ] API dartdoc — `WeightAxis`, `FontFamily.weightAxis` 주석.

---

## 엣지 케이스 / 리스크

| 케이스 | 동작 |
|---|---|
| VF 인데 `wght` 축이 없음 (예: wdth만) | `weightAxis = null`, `weights`만 기존대로 |
| 같은 패밀리에 static + VF face 공존 | `weights` 누적, `weightAxis` 동시 셋 |
| Windows 10 1803 이전 | `IDWriteFontFace5` QI 실패 → 폴백 |
| 오래된 macOS | `kCTFontVariationAxesAttribute` 심볼 lookup 실패 시 폴백 (기존 extern CFString 패턴과 동일) |
| 같은 VF resource를 여러 font가 공유 | 포인터/패밀리명 기반 dedupe |
| "Inter" static 패밀리와 "Inter Variable" 패밀리 병존 | 이름이 다르면 별개 `FontFamily` — 병합하지 않음 |
| wght 범위가 named instance보다 좁음 (비정상 폰트) | 범위 그대로 노출, `weights`는 별도 필드이므로 consumer가 선택 |

---

## 검증

- **단위 테스트** — `mapWeight` 같은 순수 변환 함수 신규 없음 (축 값은 변환 없이 그대로 노출).
- **통합 스크립트** — `tool/` 에 `List<FontFamily>` 의 `weightAxis` 가 채워진 패밀리만 필터해 출력하는 스크립트. 실제 시스템에서 Segoe UI Variable / SF Pro 가 잡히는지 수동 확인.
- **회귀** — 기존 `example/` 실행 결과가 숫자 동일하게 유지되는지 확인(축 추가는 새 필드일 뿐 기존 `weights` 에 영향 없어야 함).

---

## 향후 확장 여지

- `WeightAxis` → `Map<FontAxisTag, FontAxisRange>` 형태로 일반화. `wght` 외 `wdth`/`slnt`/`opsz` 축도 같은 패턴으로 추가.
- `FontAxisTag` 를 enum 또는 `String` (4-char) 로 노출. public API 안정화 시점에 결정.
- 연속 축 값을 실제로 사용해 폰트를 instantiate 하는 건 별도 패키지 스코프 (렌더링 쪽).
