# Phase 1 — 모델 리팩터 (breaking)

> 상위 기획: [ROADMAP_FACE_METADATA.md](./ROADMAP_FACE_METADATA.md)

## 목적

`FontFamily` 단일 계층을 `FontFamily → FontFace` 2계층 구조로 재설계하고, 기존 `WeightAxis`를 `VariationAxis`로 일반화한다. 이 phase는 **플랫폼 코드를 건드리지 않고 모델·테스트만** 다룬다.

## 선행 조건

없음. 다른 모든 Phase의 기반이 되는 최초 작업.

## 변경 대상 파일

- `lib/src/models.dart` — 전면 재작성
- `lib/just_font_scan.dart` — export 추가
- `test/just_font_scan_test.dart` — 전면 재작성
- `lib/src/font_scanner.dart` — 시그니처 점검 (변경 없을 가능성 높음)

## Task 체크리스트

### 모델 정의

- [x] `FontStyle` enum 추가: `normal`, `italic`, `oblique`
- [x] `VariationAxis` 클래스 추가 (기존 `WeightAxis` 내용 그대로, 이름만 일반화)
  - [x] `min`, `max`, `defaultValue: int`
  - [x] `==` / `hashCode` / `toString`
- [x] `typedef WeightAxis = VariationAxis;` — 0.3.x 호환
- [x] `FontFace` 클래스 추가
  - [x] 필드: `weight`, `style`, `stretch`, `faceName`, `postScriptName?`, `fullName?`, `filePath?`, `isMonospace`, `isSymbol`
  - [x] `==` / `hashCode` / `toString`
- [x] `FontFamily` 재작성
  - [x] 기존 필드 `weights`·`weightAxis` 제거 (필드로서)
  - [x] 신규 필드: `name`, `weightAxis?`, `widthAxis?`, `slantAxis?`, `italicAxis?`, `opticalSizeAxis?`, `faces`
  - [x] `weights` getter: `faces.map((f) => f.weight).toSet().toList()..sort()`
  - [x] `==` / `hashCode` / `toString` — axis 5개·faces 포함

### Export

- [x] `lib/just_font_scan.dart`에 `FontFace`, `FontStyle`, `VariationAxis` 노출 확인 (`export 'src/models.dart';` 한 줄이면 충분)

### 테스트 재작성

- [x] `test/just_font_scan_test.dart`에 `FontFace` 팩토리 헬퍼 추가 (보일러플레이트 감소용)
  ```dart
  FontFace _face({int weight = 400, FontStyle style = FontStyle.normal, ...}) => ...;
  ```
- [x] `FontFamily` 생성자·속성 테스트 리팩터
- [x] `FontFamily.weights` getter 테스트 (중복 face 2개에서 dedup·정렬 확인)
- [x] `FontStyle` enum equality·toString
- [x] `VariationAxis` 테스트 기존 `WeightAxis` 테스트 그대로
- [x] `WeightAxis` typedef alias가 런타임에 동등한지 확인 — `VariationAxis(...) is WeightAxis` 같은 assertion

## 스캐너 임시 수정 (빌드 유지용)

Phase 1 종료 시점에 전체 빌드가 통과해야 하므로, 모델 변경으로 깨지는 플랫폼 스캐너를 **임시로 최소 수정**한다. 실질 구현은 Phase 2·3에서 교체.

- [x] `windows_font_scanner.dart` — 기존 `weightSet` 수집 루프는 유지하되, family 생성부에서 weight별 더미 `FontFace` 리스트를 만들어 주입
  ```dart
  final faces = weights.map((w) => FontFace(
    weight: w, style: FontStyle.normal, stretch: 5,
    faceName: '', postScriptName: null, fullName: null,
    filePath: null, isMonospace: false, isSymbol: false,
  )).toList();
  return FontFamily(name: name, faces: faces, weightAxis: axis);
  ```
- [x] `macos_font_scanner.dart` — 동일한 더미 매핑
- [x] `// TODO(phase2/3): 실제 face 메타데이터 수집으로 교체` 주석 명시
- [x] `example/` 코드가 `FontFamily.weights` getter만 쓰고 있으면 수정 불필요, 그 외는 임시 보강

## 완료 조건

- [x] `dart test test/just_font_scan_test.dart` 전 케이스 통과 (16/16)
- [x] `dart analyze` warning 0 (lib + example 둘 다)
- [x] `dart format --set-exit-if-changed lib test` 통과
- [x] `dart run tool/scan_variable.dart` 실행 성공 (face는 더미지만 family·axis 출력은 Phase 0과 동일, 217 family / 14 variable)
- [x] 예제 앱(`example/`) 빌드 통과 (`dart analyze` 기준)

## 위험 / 주의사항

- `FontFamily` 생성자에 face 없이 weights만 넘기던 기존 호출부(예제 앱·툴 스크립트)가 전부 깨진다. 위 임시 수정 범위에 모두 포함되는지 점검 필수.
- `weights` getter에서 `faces`가 빈 리스트면 `[]` 반환. 기존 코드는 `List<int>`가 비어 있을 경우를 가정하지 않을 수 있음 — README·CHANGELOG에서 "`weights.isEmpty` 가능" 명시.
- `typedef WeightAxis = VariationAxis;`는 Dart 2.13+ 기능. `pubspec.yaml`의 `environment.sdk` 최소 버전 점검. → SDK `>=3.0.0 <4.0.0`로 충분.
