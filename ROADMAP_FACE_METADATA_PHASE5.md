# Phase 5 — 문서 & 예제

> 상위 기획: [ROADMAP_FACE_METADATA.md](./ROADMAP_FACE_METADATA.md)

## 목적

Phase 1~4로 노출된 새 데이터 모델을 README·CHANGELOG·예제 앱에 반영한다. 사용자가 업그레이드 경로를 명확히 이해하고, 예제만 보고도 새 API의 전형적 사용 패턴을 익힐 수 있게 한다.

## 선행 조건

- **Phase 1~4 모두 완료**: 모델·양 플랫폼 스캐너·축 일반화 전부 반영된 상태

## 변경 대상 파일

- `README.md` — 전면 개정
- `CHANGELOG.md` — 0.4.0 엔트리 추가
- `pubspec.yaml` — 버전·description 갱신
- `example/lib/main.dart` — 변경 불필요 (MaterialApp shell만 있음)
- `example/lib/font_family_tile.dart` — face 리스트 expansion 추가
- `example/lib/font_list_page.dart` — 5축 필터 + 모노스페이스 필터
- `example/lib/variable_preview.dart` — `WeightAxis` → `VariationAxis`
- `tool/scan_variable.dart` — Phase 4에서 이미 5축 출력으로 갱신 완료

## Task 체크리스트

### pubspec.yaml

- [x] version: `0.3.0` → `0.4.0`
- [x] description 갱신 — "faces, variation axes, and file paths" 추가

### CHANGELOG

- [x] `0.4.0` 엔트리 작성
  - [x] **Breaking**: `FontFamily` 생성자 시그니처 변경. `weights` → `faces`로 전환. 마이그레이션 스니펫 첨부.
  - [x] **Breaking**: `WeightAxis` → `VariationAxis` 개명, typedef로 소스 호환성 유지.
  - [x] **Added**: `FontFace` (weight, style, stretch, faceName, postScriptName, fullName, filePath, isMonospace, isSymbol)
  - [x] **Added**: `FontFamily.widthAxis` / `slantAxis` / `italicAxis` / `opticalSizeAxis`
  - [x] **Added**: `FontStyle` enum
  - [x] **Added**: `mapStretch` helper
  - [x] **Fixed**: Windows 11 font-cache 서비스 로더 QI 우회 (reference key 파싱)
- [x] 버전 번호 확정 — 0.4.0 (breaking 있으므로 minor 상향)

### README

- [x] 상단 요약에 face·파일 경로·5축 지원 추가
- [x] `FontFace` 섹션 신설 (9 필드 테이블)
- [x] `FontStyle` 섹션 신설
- [x] `WeightAxis` 섹션을 `VariationAxis`로 개명, 축별 단위 테이블 추가
- [x] `FontFamily` 테이블에 5개 축 필드·`faces`·`weights` getter 정리
- [x] Variable fonts 섹션을 "5축" 관점으로 확장
- [x] File path resolution 섹션 신설 — Windows 11 폴백 동작 설명
- [x] "What this package does not provide" 섹션 — 비목표 명시 (informational strings, metrics, Unicode ranges, OT features, PANOSE classification)
- [x] Usage 예제 갱신 — face iteration, italic 필터, monospace 필터, 다축 VF 감지
- [x] Migration from 0.3.x 섹션 신설 — breaking change 스니펫

### 예제 앱

- [x] `font_family_tile.dart`
  - [x] face 개수 chip
  - [x] monospace / symbol 플래그 chip (family에 하나라도 있으면 표시)
  - [x] VF 배지를 `"VF · wght wdth slnt ..."` 형식으로 확장 (5축 모두 반영)
  - [x] "Show face details" expansion — face별 weight·style·stretch·postScriptName·filePath 노출
  - [x] 기존 `wght` 슬라이더 UX 유지 (`VariablePreview` 그대로)
- [x] `font_list_page.dart`
  - [x] "Variable only" 필터를 5축 전체로 확장 (`_hasAnyAxis` 헬퍼)
  - [x] "Monospace only" 필터 추가
  - [x] 검색바를 세로 배치로 변경 (두 FilterChip 수용)
- [x] `variable_preview.dart` — `WeightAxis` 타입 참조를 `VariationAxis`로 변경
- [x] `main.dart` — 변경 불필요

### 도구

- [x] `tool/scan_variable.dart` — Phase 4에서 이미 5축·커버리지 통계 출력하도록 갱신됨
- [x] `tool/scan_faces.dart` — Phase 2에서 face별 출력·커버리지 통계로 동작 중

## 완료 조건

- [x] `dart analyze` warning 0 (lib + example 둘 다)
- [x] `dart format --set-exit-if-changed` 통과
- [x] `dart test` 72/72 통과
- [x] `dart pub publish --dry-run` 경고 없음 (1 warning은 git status 비cleaness 관련으로 무관, 1 hint는 pub.dev 최종 공개 버전과 괴리로 무관)
- [x] README 스니펫의 모든 타입·메서드 이름이 실제 API와 일치
- [x] CHANGELOG가 pub.dev 표시 형식 (`## 0.4.0` 헤더, Breaking/Added/Fixed 구분) 준수
- [ ] `flutter run` (example 앱)이 Windows·macOS 양쪽에서 정상 구동 — Windows 빌드는 별도 검증, macOS는 macOS 머신 필요

## 구현 중 결정 사항

### face 상세 노출을 expansion 패턴으로 구현
face가 10개 넘는 family(Arial 14, Segoe UI 18)는 tile이 너무 높아짐. expansion toggle로 기본 접은 상태 → 필요시 펼치기. 기본 tile은 family name·VF axis summary·face 개수·flag chips·weights chip row + `wght` 슬라이더(가변이면)로 구성해 한눈에 훑기 좋게.

### Multi-axis slider는 이번 scope 밖
`wdth`·`slnt`·`opsz`마다 슬라이더를 동적 생성하는 UI는 구현량 큰 데 비해 실용성 제한적 (대부분 VF의 부가 축은 `min=max`인 고정값). 기본 `wght` 슬라이더만 유지하고 다축 슬라이더는 추후 과제로 남김. `VariationAxis` 객체 자체는 5개 모두 접근 가능하므로 사용자가 직접 `FontVariation` 리스트를 만들 수 있음.

### Monospace 필터는 family 단위
"face 중 하나라도 monospace면 family를 통과"로 구현. Consolas처럼 모든 face가 monospace인 family와, 일부만 그런 family 모두 걸러짐. face-level 필터는 expansion 내부에서 보여주는 것으로 충분.

### "Variable only" 정의 확장
0.3.x에서는 `weightAxis != null`만 체크했으나, Cascadia/Noto 같은 VF에서 `wght`·`wdth`·`slnt`·`ital` 4축이 동시에 선언되므로 5축 중 하나라도 non-null이면 통과하도록 확장. 현재 Windows 스캔 결과 기준 "variable" 판정이 동일 개수(14)를 유지 — 모든 VF가 최소 `wght`를 선언하기 때문.

## 위험 / 주의사항

- Phase 1의 임시 더미 face 처리가 Phase 2·3에서 실질 구현으로 교체됐는지 Phase 5 시작 전 재확인 완료. 예제 코드가 더미 가정에 의존하는 부분 없음.
- `VariationAxis`의 단위(weight·width·slant·optical size)가 축마다 다르다는 점을 README의 "Units depend on the axis" 테이블로 명시 — 오해 방지.
- `FontFace` 필드 9개 중 `filePath`만 실 머신 조건에 따라 `null` 비율 편차 큼 (예제 앱에서는 null일 경우 해당 줄 자체를 생략하는 식으로 처리).
- pub.dev 점수 유지 — dartdoc 커버리지는 Phase 1에서 모든 public 타입에 ///-주석 추가 완료. example 경로·README 섹션 모두 체크.
- 버전 bump 결정: breaking change 있지만 0.x 단계이므로 0.4.0으로 minor bump. `1.0.0`으로 stable 승격은 마이그레이션 피드백 수집 후 별도 릴리즈에서.
