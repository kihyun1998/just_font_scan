# Phase 4 — Variation 축 일반화

> 상위 기획: [ROADMAP_FACE_METADATA.md](./ROADMAP_FACE_METADATA.md)

## 목적

현재 `wght` 축만 추출되는 로직을 OpenType 등록 5개 축(`wght`, `wdth`, `slnt`, `ital`, `opsz`) 모두로 확장한다. 스캐너는 축 전체를 내부 레코드로 수집하고, 모델에서는 5개 named field로 노출한다.

## 선행 조건

- **Phase 1 완료**: `VariationAxis` 타입과 `FontFamily`의 5개 축 필드 선언 필요
- Phase 2·3 완료 후 진행 (이 phase는 face 루프를 건드리지 않지만 스캐너 파일을 공유하므로 순차 진행)

## 변경 대상 파일

- `lib/src/windows/windows_font_scanner.dart` — `_tryReadWghtAxis` / `_readWghtAxisFromResource` 일반화
- `lib/src/windows/dwrite_bindings.dart` — 추가 축 태그 상수
- `lib/src/macos/macos_font_scanner.dart` — `_copyWghtAxis` 일반화
- `lib/src/macos/coretext_bindings.dart` — 필요시 tag 상수
- `test/axis_tag_test.dart` — 신설. FOUR_CC 엔디언 검증
- `tool/scan_variable.dart` — 5축 모두 출력하도록 갱신

## Task 체크리스트

### 축 태그 상수

- [x] `dwrite_bindings.dart`에 FOUR_CC (리틀 엔디언) 상수 4개 추가
  - [x] `kDWriteFontAxisTagWidth = 0x68746477` (`'wdth'`)
  - [x] `kDWriteFontAxisTagSlant = 0x746e6c73` (`'slnt'`)
  - [x] `kDWriteFontAxisTagItalic = 0x6c617469` (`'ital'`)
  - [x] `kDWriteFontAxisTagOpticalSize = 0x7a73706f` (`'opsz'`)
- [x] CoreText big-endian tag 상수 4개 추가
  - [x] `kOpenTypeWdthTag = 0x77647468`
  - [x] `kOpenTypeSlntTag = 0x736c6e74`
  - [x] `kOpenTypeItalTag = 0x6974616c`
  - [x] `kOpenTypeOpszTag = 0x6f70737a`
- [x] `test/axis_tag_test.dart`에서 두 엔디언 포맷 교차 검증 — 12개 테스트 전부 통과

### Windows 스캐너 일반화

- [x] 스캐너 파일 상단에 `_AxisSet` 내부 레코드 타입 도입 (`weight`, `width`, `slant`, `italic`, `opticalSize` 5 nullable 필드)
- [x] `_emptyAxisSet` 상수 + `_axisSetIsEmpty(set)` 헬퍼
- [x] `_tryReadWghtAxis` → `_tryReadAllAxes` 개명, 반환 타입 `_AxisSet`로 변경
- [x] `_readWghtAxisFromResource` → `_readAllAxesFromResource` 개명
  - [x] `GetFontAxisRanges` 결과를 tag별 `Map<int, double>`로 분기해 5개 축 모두 수집
  - [x] `GetDefaultFontAxisValues`도 동일하게 tag 분기
  - [x] `_isRegisteredAxisTag` 헬퍼로 5개 태그만 필터 통과
- [x] `_getFamilyFacesAndAxis` → `_getFamilyFacesAndAxes` 개명, `_AxisSet` 반환
- [x] 호출부(`_scanFamily`)에서 `FontFamily` 생성 시 5개 필드 주입
- [x] 첫 face에서 축 추출 성공하면 이후 face들에서는 재호출하지 않는 기존 최적화 유지 (family resource 단위라 동일)

### macOS 스캐너 일반화

- [x] 스캐너 파일 상단에 동일한 `_AxisSet` 레코드 타입 도입 (Windows와 대칭)
- [x] `_copyWghtAxis` → `_copyAllAxes` 개명
  - [x] 단일 `axesArray` 순회에서 switch로 5개 태그 매칭
  - [x] 각 축은 `_readAxisRange` 헬퍼로 (min, max, default) 추출
- [x] `_scanDescriptor` 시그니처 `Map<String, VariationAxis>` → `Map<String, _AxisSet>`
- [x] family 그룹핑 시점에 5개 축 필드 `FontFamily`에 주입
- [x] 기존 "italic과 roman descriptor가 같은 축 보고" 최적화 유지 — 첫 non-empty hit만 받고 나머지 skip

### 테스트

- [x] 태그 상수 엔디언 검증 (신설)
  - [x] DirectWrite 5개 태그가 little-endian 바이트 패킹과 일치
  - [x] CoreText 5개 태그가 big-endian 바이트 패킹과 일치
  - [x] Windows/macOS 태그 값이 서로 다른 엔디언임을 교차 확인
- [x] 실 Windows 스캔 결과로 5축 동시 추출 확인 (`tool/scan_variable.dart`)
  - 14 VF family 전원에서 `wght`·`wdth`·`slnt`·`ital` 4축 모두 non-null
  - Segoe UI Variable(3종) + Sitka(6종) = 9개 family에서 `opsz` 추가로 non-null
  - Bahnschrift `wdth: 75–100`이 실제 가변 범위로 확인됨
- [ ] macOS 실 머신에서 다축 검증 필요
  - [ ] `SF Pro`: `wght` + `opsz` 동시 non-null 기대
  - [ ] `New York`: 비슷한 다축 케이스
- [x] 공통 unit 테스트 (Windows에서 실행 가능)
  - [x] 태그 상수가 FOUR_CC 인코딩 정확한지 (리틀/빅 엔디언 차이 검증)
  - [x] 5개 필드 equality·hashCode·toString이 `FontFamily`에 정상 반영 (Phase 1에서 추가한 `all five variation axes` 테스트)

## 완료 조건

- [x] `dart test` 전 케이스 통과 (72/72)
- [x] `dart analyze` warning 0 (lib + example 둘 다)
- [x] `dart format --set-exit-if-changed` 통과
- [x] `tool/scan_variable.dart`가 5개 축 모두 출력 — Windows 수동 확인 완료
- [x] 성능 회귀 없음 — face당 API 호출 수 불변 (axes array 한 번 조회해서 루프로 5개 tag 매칭). 1500 scan 누수 체크 round1→3 delta 4.54→1.03→0.73 MB (감소 추세, warm-up heap 성장으로 판단 — 누수 아님)
- [ ] **macOS 실 머신 검증** — Windows 세션에서는 수행 불가

## 실전에서 발견한 특이점

### 다수 폰트가 "가변이지만 범위 고정" 축을 선언

Cascadia Code, Noto Sans KR 같은 VF에서 `wdth`, `slnt`, `ital` 축이 모두 `min=max=default`인 단일값으로 선언됨. 예:
```
Cascadia Code:
  wght: min=200, max=700, default=400   ← 실제 가변
  wdth: min=100, max=100, default=100   ← 고정
  slnt: min=0,   max=0,   default=0     ← 고정
  ital: min=0,   max=0,   default=0     ← 고정
```

폰트가 "내가 이 축을 지원한다고 선언은 했지만 한 값만 제공한다"는 의미. 이게 `null`이 아닌 이유는 폰트 파일이 실제로 `fvar` 테이블에 해당 축을 기입해둔 결과 그대로이기 때문. UI에서 슬라이더 만들 때 `min == max`면 슬라이더 숨기는 식의 처리는 호출자 책임.

### `opsz` 축의 단위

`wght`·`wdth`는 CSS 스케일(100~1000, 50~200 등)이지만 `opsz`는 **포인트 단위**. Segoe UI Variable Display의 `opsz: 5~36`은 "5pt~36pt 범위 폰트"라는 뜻. `VariationAxis`는 단일 int 필드만 있어서 축마다 단위가 다르다는 점을 모델이 직접 표현하지 않음 — Phase 5 문서에서 명시.

### `slnt` 음수 범위

이번 Windows 환경에서는 발견되지 않았지만(모든 VF의 slnt가 0~0), 일반적으로 `slnt`는 `-20~0`처럼 **음수 범위**를 가짐. `VariationAxis.min`이 음수 정수를 허용하는지는 Phase 1 테스트(`supports negative ranges (e.g. slnt)`)에서 이미 확인됨.

## 위험 / 주의사항

- DWrite FOUR_CC는 **리틀 엔디언** 패킹, CoreText tag는 **빅 엔디언**. 같은 "wdth"인데 상수 값이 다름 — 상수 정의 위치·주석에 엔디언 명시 완료 + `test/axis_tag_test.dart`에서 교차 검증.
- `slnt` 축은 value가 **음수**인 폰트가 다수 (`-20.0` ~ `0.0`). `VariationAxis.min/max`가 음수 들어가도 모델이 허용하는지 확인 — `int` 타입이라 문제 없고, 기존 `VariationAxis` 테스트의 `supports negative ranges` 케이스에서 검증됨.
- `ital` 축은 사실상 0.0 또는 1.0 이진값 (부분값도 허용하지만 렌더링 폰트는 0/1만 선언). 이것도 `VariationAxis`로 똑같이 표현해도 의미상 어색하지 않음 — 별도 타입 만들지 않기로 결정.
- `opsz`(optical size)는 weight 스케일과 달리 **포인트 단위**(예: 8~144). int 반올림 시 단위 의미가 섞이는 점은 `VariationAxis` dartdoc에 명시 완료 (Phase 1의 "Units depend on the axis" 설명).
- axes 수집 비용은 family당 1회 — face 개수에 비례하지 않음. 성능 영향 미미.
