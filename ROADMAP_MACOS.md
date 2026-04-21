# just_font_scan — macOS 지원 기획서

## 1. 개요

현재 `just_font_scan`은 Windows(DirectWrite)만 지원한다. 이 기획서는 **macOS 지원 추가**를 위한 구현 설계를 정의한다. 기존 Windows 구현과 동일한 공개 API(`JustFontScan.scan()`, `weightsFor()`)를 유지하면서, macOS 전용 백엔드를 `lib/src/macos/`에 추가한다.

**기준 커밋**: `bfedb5a` (main branch)

---

## 2. 목표 / 비목표

### 2.1 목표

- macOS에서 `JustFontScan.scan()`이 시스템 폰트 family 목록과 각 family의 supported weights를 반환한다.
- Windows와 **동일한 `FontFamily` 모델**을 반환한다 (신규 타입 추가 없음).
- **FFI-only** 구현. 추가 native build step, CocoaPods, Swift bridge 없음.
- 기존 공개 API는 변경하지 않는다. `Platform.isMacOS` 분기만 추가.
- 실패 시 throw 대신 빈 리스트(Windows 구현 규약 일치).

### 2.2 비목표

- iOS / Linux 지원 (별도 계획).
- 사용자 설치 폰트와 시스템 폰트의 구분.
- Italic / stretch / style 속성 노출.
- 비동기 스캔 API (`scanAsync()` 등) — 이는 향후 과제.
- 폰트 파일 경로나 PostScript name 노출.

---

## 3. 아키텍처

### 3.1 디스패치 포인트

`lib/src/font_scanner.dart`의 `_scan()` 분기에 macOS 케이스를 추가한다.

```dart
static List<FontFamily> _scan() {
  if (Platform.isWindows) {
    return windows.scanFonts();
  }
  if (Platform.isMacOS) {
    return macos.scanFonts();
  }
  return const [];
}
```

### 3.2 파일 구조 (추가분)

```
lib/src/macos/
  coretext_bindings.dart       # CoreFoundation + CoreText FFI 바인딩
  macos_font_scanner.dart      # scanFonts() 본체 (Windows와 동일한 시그니처)
```

`windows/` 디렉터리와 대칭 구조를 유지한다. 파일당 책임은 Windows 구현과 동일:
- `*_bindings.dart`: 순수 FFI typedef, DynamicLibrary, 상수, 저수준 헬퍼
- `*_font_scanner.dart`: 스캔 흐름, 에러 처리, `FontFamily` 변환

### 3.3 공개 API 영향

공개 API **변경 없음**. 다음만 수정:

- `lib/src/font_scanner.dart`: macOS 분기 + import 추가
- `pubspec.yaml`: `platforms:` 에 `macos:` 추가
- `README.md`: macOS를 "Supported"로 변경, weight 정밀도 caveat 추가
- `CHANGELOG.md`: `0.2.0` 항목에 macOS 지원 추가

---

## 4. CoreText API 선택

### 4.1 사용할 프레임워크

| 프레임워크 | 경로 | 용도 |
|---|---|---|
| CoreFoundation | `/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation` | CFArray / CFDictionary / CFString / CFNumber / CFRelease |
| CoreText       | `/System/Library/Frameworks/CoreText.framework/CoreText`             | CTFontCollection / CTFontDescriptor 및 관련 상수 |

`DynamicLibrary.open()`에 **절대 경로**를 사용한다 (Windows의 System32 절대 경로 전략과 동일, W-1 DLL hijacking 완화와 같은 원칙).

### 4.2 핵심 API 호출 흐름

```
CTFontCollectionCreateFromAvailableFonts(NULL)
  → CTFontCollectionRef (owned)

CTFontCollectionCreateMatchingFontDescriptors(coll)
  → CFArrayRef<CTFontDescriptorRef> (owned)

for each CTFontDescriptorRef desc in array:
  family = CTFontDescriptorCopyAttribute(desc, kCTFontFamilyNameAttribute)
           → CFStringRef (owned)
  traits = CTFontDescriptorCopyAttribute(desc, kCTFontTraitsAttribute)
           → CFDictionaryRef (owned)
  weightNum = CFDictionaryGetValue(traits, kCTFontWeightTrait)
              → CFNumberRef (borrowed; do NOT release)
  normalizedWeight = CFNumberGetValue(weightNum, kCFNumberFloat64Type, &out)
  → normalizedWeight (−1.0 ~ 1.0) 를 CSS weight로 스냅

  CFRelease(family), CFRelease(traits)

CFRelease(array), CFRelease(coll)
```

### 4.3 Family grouping

`CTFontCollectionCreateMatchingFontDescriptors`는 **face 단위**(예: "Source Code Pro Bold", "Source Code Pro Light" 각각 별개 descriptor)로 반환한다. family 이름으로 `Map<String, Set<int>>`에 weight를 누적 후 `FontFamily`로 빌드한다. 이는 Windows의 `IDWriteFontFamily` 수준 그룹핑과 결과적으로 동일해진다.

---

## 5. Weight 매핑 전략

### 5.1 문제

- Windows(DirectWrite): `DWRITE_FONT_WEIGHT`는 정수 `100, 200, ..., 950`. 1:1 매핑.
- macOS(CoreText): `kCTFontWeightTrait`는 **float −1.0 ~ 1.0**, 연속값. 폰트마다 임의의 float이 올 수 있음.

### 5.2 스냅 테이블 (Apple 공식 NSFontWeight 상수)

Apple이 공개한 `NSFontWeight` / `UIFontWeight` 상수 기준.

| CSS weight | macOS normalized | Apple 상수 |
|---|---|---|
| 100 | −0.80 | UltraLight |
| 200 | −0.60 | Thin |
| 300 | −0.40 | Light |
| 400 |  0.00 | Regular |
| 500 |  0.23 | Medium |
| 600 |  0.30 | Semibold |
| 700 |  0.40 | Bold |
| 800 |  0.56 | Heavy |
| 900 |  0.62 | Black |

### 5.3 매핑 알고리즘

```
mapWeight(double normalized) -> int:
  반올림이 아닌 "최근접 버킷"(|normalized − bucket| 최소) 선택
  동률일 경우 더 낮은 weight(가벼운 쪽) 선택
```

- 950 은 생성하지 않는다. CoreText는 950 상당의 공식 상수가 없다.
- 범위 밖 값(−1.0 < x, x > 1.0 또는 NaN)은 400으로 폴백 후 해당 family는 스킵하지 않고 추가 (robustness).

### 5.4 정밀도 caveat (문서화 필요)

macOS는 Windows와 달리 **근사치**다. 예를 들어 `normalized = 0.36`인 폰트는 600(0.30)과 700(0.40) 사이이며, 0.36은 700에 더 가까우므로 700으로 스냅된다. README에 명시한다.

---

## 6. 필터링 규칙

다음 descriptor는 **스킵**한다:

| 조건 | 이유 |
|---|---|
| family 이름이 `.` 로 시작 (예: `.SFUI-Regular`, `.AppleSystemUIFont`) | Apple 시스템 내부 폰트, 사용자가 직접 지정할 수 없음 |
| family 이름이 비어있거나 null | 깨진 descriptor |
| 이름 길이 > `kMaxFontNameLength` (32767, Windows와 공유 상수) | 메모리 guard |

Windows의 `@` prefix 필터는 macOS에서는 해당되지 않는다.

---

## 7. FFI 바인딩 상세

### 7.1 타입 alias

CoreFoundation의 `CFTypeRef` 계열 포인터는 전부 **`Pointer<Void>`** 로 취급한다. Windows가 COM을 `Pointer<IntPtr>`로 다루는 것과 대응되는 FFI 관용. 개별 타입은 주석으로만 구분.

```dart
typedef CFTypeRef = Pointer<Void>;
// 의미적 alias (컴파일상 동일):
// CFArrayRef, CFDictionaryRef, CFStringRef, CFNumberRef,
// CTFontCollectionRef, CTFontDescriptorRef
```

### 7.2 CoreFoundation 바인딩

| 심볼 | 시그니처 (Dart FFI) | 비고 |
|---|---|---|
| `CFRelease` | `Void Function(CFTypeRef)` | null 방어 래퍼 제공 |
| `CFArrayGetCount` | `IntPtr Function(CFArrayRef)` | CFIndex = signed long |
| `CFArrayGetValueAtIndex` | `Pointer<Void> Function(CFArrayRef, IntPtr)` | **borrowed** return |
| `CFDictionaryGetValue` | `Pointer<Void> Function(CFDictionaryRef, Pointer<Void>)` | **borrowed** return |
| `CFStringGetLength` | `IntPtr Function(CFStringRef)` | UTF-16 unit 길이 |
| `CFStringGetCString` | `Int32 Function(CFStringRef, Pointer<Utf8>, IntPtr, Uint32)` | UTF-8 추출, 성공 시 1 |
| `CFStringGetMaximumSizeForEncoding` | `IntPtr Function(IntPtr, Uint32)` | UTF-8 버퍼 계산 |
| `CFNumberGetValue` | `Uint8 Function(CFNumberRef, Int32, Pointer<Double>)` | `kCFNumberFloat64Type = 13`, bool 반환 |

`kCFStringEncodingUTF8 = 0x08000100`.

### 7.3 CoreText 바인딩

| 심볼 | 시그니처 (Dart FFI) |
|---|---|
| `CTFontCollectionCreateFromAvailableFonts` | `CFTypeRef Function(CFDictionaryRef)` (options NULL) |
| `CTFontCollectionCreateMatchingFontDescriptors` | `CFTypeRef Function(CTFontCollectionRef)` |
| `CTFontDescriptorCopyAttribute` | `CFTypeRef Function(CTFontDescriptorRef, CFStringRef)` |

### 7.4 extern CFStringRef 상수 (까다로운 지점)

`kCTFontFamilyNameAttribute`, `kCTFontTraitsAttribute`, `kCTFontWeightTrait`는 **함수가 아니라 extern global CFStringRef**다. `lookupFunction`이 아니라 다음처럼 역참조로 값을 읽는다:

```dart
final symbol = coreText.lookup<Pointer<CFTypeRef>>('kCTFontFamilyNameAttribute');
final cfStringRef = symbol.value; // 실제 CFStringRef
```

3개 상수 모두 **CoreText 라이브러리 로드 시 1회 읽어서 캐싱**한다 (매 스캔마다 lookup하지 않음).

### 7.5 DynamicLibrary 로더

```dart
DynamicLibrary loadCoreFoundation() => DynamicLibrary.open(
  '/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation');

DynamicLibrary loadCoreText() => DynamicLibrary.open(
  '/System/Library/Frameworks/CoreText.framework/CoreText');
```

Windows의 `_system32Path()` 와 동일한 "절대 경로 원칙".

---

## 8. 메모리 관리 (Create/Copy/Get 규칙)

CoreFoundation의 소유권 규칙을 **엄격히** 따른다:

| 함수명 접두사 | 소유권 | 해제 책임 |
|---|---|---|
| `Create*` / `*Copy*` | 호출자 소유 | `CFRelease` 필수 |
| `*Get*` | 소유권 없음 (borrowed) | **해제 금지** |

따라서:
- ✅ CFRelease 대상: `CTFontCollectionCreateFromAvailableFonts` 결과, `...CreateMatchingFontDescriptors` 결과, `CTFontDescriptorCopyAttribute` 결과 (family string, traits dict 각각)
- ❌ CFRelease 금지: `CFArrayGetValueAtIndex`(descriptor 포인터), `CFDictionaryGetValue`(weight CFNumber)

### 8.1 Arena 패턴

Windows 구현의 `using((arena) => ...)` 패턴과 대응되는 구조가 CF에는 없다 (CFAutoreleasePool은 Obj-C ARC 레이어). 대신 **`try/finally` 쌍**으로 각 CFRelease를 짝지어 호출한다. `arena` 는 UTF-8 버퍼 등 순수 네이티브 메모리에만 사용한다.

```dart
final coll = createFromAvailableFonts(nullptr);
if (coll.address == 0) return const [];
try {
  final array = createMatching(coll);
  if (array.address == 0) return const [];
  try {
    return _scanArray(array, arena);
  } finally {
    cfRelease(array);
  }
} finally {
  cfRelease(coll);
}
```

---

## 9. 에러 처리 / 실패 모드

Windows 규약과 동일하게 **throw 금지, 빈 리스트 반환**.

| 실패 모드 | 동작 |
|---|---|
| `DynamicLibrary.open` 실패 | `scanFonts()` 가 `[]` 반환 |
| `CTFontCollectionCreateFromAvailableFonts` null 반환 | `[]` |
| extern 상수 lookup 실패 | `[]` (바인딩 초기화에서 throw → catch → `[]`) |
| 개별 descriptor 속성 추출 실패 | 해당 descriptor 스킵, 나머지는 계속 |
| UTF-8 변환 실패 | 해당 descriptor 스킵 |
| CFNumber 추출 실패 | 해당 face의 weight를 400(Regular)로 폴백 |

최상위 `scanFonts()`는 Windows와 동일하게 `try { ... } catch (_) { return const []; }` 로 감싼다.

---

## 10. 공유 상수 정리

현재 `windows/dwrite_bindings.dart`에 있는 상수 중 **플랫폼 무관**한 것들은 `lib/src/limits.dart`(신규)로 이관 고려:

| 상수 | 이동? |
|---|---|
| `kMaxFontNameLength = 32767` | ✅ 이관 (macOS에서도 사용) |
| `kMaxFontFamilyCount = 10000` | ✅ 이관 |
| `kMaxFontCount = 1000` | ✅ 이관 |
| `kDWriteFontWeightMin/Max` | ❌ Windows 전용, 유지 |

이관은 **선택사항**이며 1차 구현에서는 macOS 파일에 동일 상수를 복붙해도 무방 (두 파일이라 복붙 비용 낮음).

---

## 11. 구현 단계

### Phase A — FFI 바인딩
1. `coretext_bindings.dart` 작성
   - `loadCoreFoundation()`, `loadCoreText()`
   - CF 함수 typedef + lookupFunction
   - CT 함수 typedef + lookupFunction
   - extern CFStringRef 3개 상수 캐시
   - `cfRelease()` null 방어 래퍼

### Phase B — 스캐너 본체
2. `macos_font_scanner.dart` 작성
   - `scanFonts()` 엔트리 + try/catch
   - 컬렉션 → 디스크립터 배열 획득
   - 배열 순회, family 이름 + weight 추출, Map에 누적
   - `Map<String, Set<int>>` → `List<FontFamily>` 변환 + 이름순 정렬 + 스킵 필터 적용

### Phase C — 디스패치 & 메타
3. `font_scanner.dart` 에 `Platform.isMacOS` 분기 추가
4. `pubspec.yaml` `platforms:` 에 `macos:` 추가
5. `README.md` 플랫폼 표 업데이트 + weight 근사치 caveat 추가
6. `CHANGELOG.md` `0.2.0` 항목

### Phase D — 테스트
7. 단위 테스트: weight 매핑 함수 (표 기반 입력→출력 검증)
8. macOS 통합 테스트 (실기기 검증; CI 환경 없으면 manual)
9. 빈 결과 / 시스템 프레임워크 미존재 시뮬레이션은 skip (FFI 특성상 mocking 어려움)

---

## 12. 테스트 계획

### 12.1 순수 Dart 단위 테스트

- `mapWeight()` 입력/출력 표: `-0.80 → 100`, `-0.79 → 100`, `-0.70 → 150? no, 최근접 버킷`, `-0.5 → 300(−0.4)와 200(−0.6) 동률시 200`, `0.35 → 600(0.30)와 700(0.40) 동률시 600` 등 경계 케이스 포함
- `_listEquals`, `FontFamily` 기존 테스트는 변경 불필요

### 12.2 macOS 실기기 integration

- `JustFontScan.scan().isNotEmpty` 확인
- 대표 family 존재 확인: `Helvetica`, `Menlo`, `SF Pro` 계열 중 최소 1개
- 시스템 내부 폰트(`.`시작)가 결과에 **없음** 확인
- `weightsFor('Helvetica')` 에 400, 700 포함 확인 (Light/Bold 등은 시스템 버전 의존)

### 12.3 비회귀

- Windows 테스트는 변경 없이 그대로 통과해야 함.
- 공개 API 시그니처 diff 금지.

---

## 13. 리스크 / 오픈 이슈

| 리스크 | 완화 |
|---|---|
| extern CFStringRef 상수 lookup이 플랫폼 버전마다 달라질 가능성 | 현재까지 macOS 10.5+ 안정 API. lookup 실패 시 `[]` 폴백. |
| `kCTFontWeightTrait` 값이 벤더 폰트마다 불규칙 (예: 0.37) | 최근접 스냅 + README에 "근사치" caveat. 정확한 값이 필요한 사용자는 별도 이슈로 대응. |
| System UI 폰트(`.SFUI-*`)가 macOS 버전에 따라 공개되거나 숨겨지는 변동 | `.` prefix 필터로 일관되게 숨김. |
| Italic/Condensed가 같은 family 이름으로 묶이면 weight 집합에 노이즈 | 1차에서는 수용. 향후 `kCTFontSymbolicTrait`로 italic/condensed 플래그를 노출하는 `FontFace` 모델 확장을 별도 로드맵으로 분리. |
| PostScript name 대 family name 혼동 (예: "Helvetica Neue" vs "HelveticaNeue") | 항상 `kCTFontFamilyNameAttribute`만 사용 (PostScript name은 건드리지 않음). |
| FFI에서 `CFIndex`(platform-dependent long) ↔ Dart `IntPtr` 크기 일치 | macOS는 64-bit 고정 지원이므로 문제 없음. 32-bit macOS는 비지원 명시. |

---

## 14. 향후 확장 (본 기획서 범위 밖)

- `FontFace` 수준 정보(italic, stretch, PostScript name) 노출
- 950 weight 지원 (현재 macOS 매핑에서는 생성되지 않음)
- 비동기 API (`scanAsync`) — Isolate + FFI
- Linux (fontconfig) 백엔드
- 사용자 설치 vs 시스템 폰트 구분 플래그

---

## 15. 수용 기준 (Definition of Done)

- [ ] macOS 실기기에서 `JustFontScan.scan()` 이 500+ 개의 family를 반환한다 (Ventura 이상 기준).
- [ ] 반환된 리스트에 `.` 로 시작하는 family가 **0개**.
- [ ] Windows 기존 테스트 전부 통과 (비회귀).
- [ ] `mapWeight` 단위 테스트 100% 통과.
- [ ] `pubspec.yaml` 에 `macos:` 플랫폼 선언.
- [ ] README 에 macOS "Supported" + weight 근사 caveat.
- [ ] 메모리 누수 점검: `leaks` 명령 또는 Instruments 로 `CFRelease` 누락 없음 확인.
