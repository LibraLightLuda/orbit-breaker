# 최신 검증 결과: 3.18.2 / mobile-20261013 (2026-10-13)

전체 요청 구현·검증·공개 배포를 완료했다. 자동으로 제작/빌드/승격을 반복하지 말고 최신 manifest와 변경분을 먼저 비교한다.

모바일 Web 드래그 이동·탭 돌진·두 번 탭 오버드라이브, 가로/세로 HUD·카메라, 가로 전체화면 요청과 세로 안내를 구현했다. 기존 미커밋 7영역 모션 개선을 함께 보존했다. 로컬 최신본 교체·GitHub/Pages 공개 및 공개 플레이 검증 완료. [모바일 구현·검증 보고](MOBILE_WEB_REPORT.md).

21묶음2557 회귀, native 터치42, 데스크톱 입력14, 실제16화면2536, 아트325, 모션601/576프레임, WebAssembly 터치5 통과. 최종 Web 부하3회씩 p95 혼합13.8/14.4/13.6ms, 일반10.8/10.3/10.6ms. Windows 정상 실행/종료·프로필 불변 확인. 물리 휴대폰·Safari·저사양 장치 및 전체화면 회전 잠금의 실기기 동작은 미검증이다.

최신본 `build/current`, 증거 `artifacts/current/mobile`와 `verification.json`, 전체 목록 `file-inventory.json`. Windows SHA-256 `8AE93D875BE76E77153E04746729C6A3D3CF24DEEFEE3F3E9D9637CA168F1A99`. Web PCK `DAA90D44EE4253E938674914FD1E30C6018DA52D22C636F7DB378B1C8C3255FF`. 이전 정상본 보존→새본 검증→교체→이전 배포/증거 정리 순서를 지켰다. 과거 정책 차단 임시5경로는 재시도하지 않고 retention-status에 남겼다. 게임 규칙·밸런스·저장·고스트 형식은 3.18을 유지한다.

## 2026-10-13 공개 배포 검증 완료

[웹 플레이](https://libralightluda.github.io/orbit-breaker/)와 [v3.18.2 릴리즈](https://github.com/LibraLightLuda/orbit-breaker/releases/tag/v3.18.2)에 전체 작업을 게시했다. 게임/모션/모바일 소스 커밋은 `42d1118b3076a7f7d4363bef95a65bdec42390d0`, 최종 Web 게시 커밋은 `90323c994f8ab85e1446a3951d8e5245e18f7089`, Pages 작업 `38355587594` 성공. 태그/게임 코드와 생성된 배포 파일을 구분해 기록한다. Git의 HTML CRLF→LF 변환으로 최초 공개 해시가 달라지는 문제를 발견했고 `.gitattributes`로 Web 원본 바이트 보존을 적용했다. 게임 코드·검증 EXE·ZIP은 바꾸지 않았다.

공개 Web9파일과 기본 주소 HTML의 SHA-256이 로컬 검증본과 일치하고, 릴리즈6첨부의 GitHub digest/크기도 모두 일치한다. 공개 Chromium 모바일 크기에서 타이틀·격납고·출격·이동·돌진 버튼 발동·정지·도감 복귀·자연 강화 카드 클릭/전투 재개·세로 강화 버튼·전투 중 회전 자동 정지를 직접 확인했다. 오류·경고 콘솔0. 이는 짧은 공개 smoke 검사이며 물리 휴대폰 터치/성능 또는 장시간 사람 플레이가 아니다.

신규 공개본 검증 후 구버전 릴리즈 첨부6개와 이전 Pages artifact2개를 정리하고 소스 태그/릴리즈 이력은 보존했다. 최종 근거는 `artifacts/current/github-publication.json`, `public-web-hashes.json`, `public-release-assets.json`, `public-retention.json`, `mobile/public-play-status.json`과 공개 화면이다. 기존 정책 차단 임시5경로는 재시도하지 않았다.

---
아래는 과거 시점 기록이며 현재 상태는 위 결과가 우선한다.

# 최신 검증 결과: motion-20261013 (2026-10-13)

**7영역 구현·실제 렌더/Windows·Web 검증·로컬 최신본 교체 완료.** 자세한 결과와 미검증 한계는 [모션 개선 최종 보고](MOTION_IMPLEMENTATION_REPORT.md)를 따른다. 현재 실행본은 `build/current`, 증거는 `artifacts/current`. 모션601/실제16화면2536/아트325/10분 자연전투·고스트34 통과, Web 혼합최대밀도 p95 14.6~14.9ms. Windows SHA-256 `1F4D0FCBE22227C3C7DA024AB2ECBF9ADDAA97F322D25E39C0AF7D44ECB2F74C`. 공개 사이트는 이전 v3.18.1이며 이번 모션 세대는 로컬 검증본이다. 다시 재개할 때 완료 검사를 반복하지 말고 이 세대의 manifest와 변경분을 먼저 비교한다. 임시 정리5경로는 blocked by policy로 미완료이며 `retention-status.json`에 기록했다.

---
아래는 이전 검증·과정 기록이다. 현재 상태는 위 결과가 우선한다.

# 2026-10-13 플레이 피드백 모션 개선 최종 검증 중

7영역의 구현과 Web 배칭 개선을 완료했다. 혼합 최대 밀도 Web의 마지막 사전 측정은 p95 14.6~15.0ms로 목표를 통과했다. 최종 리뷰에서 메뉴 전환 호출/차광막 리사이즈, 고스트 보간 시간·추진 속도·이전 피격 잔류, 효과 감소 폭발/XP 경로를 보완했다. `tools/verify_motion_delivery.py`가 실제 모션·16화면 회귀·아트/Windows 성능·혼합 밀도·10분 자연 전투/고스트·두 플랫폼 export·실행본을 순차 확인한다. 단계별 결과는 `artifacts/candidate/motion/final-gates.json`에 즉시 기록한다. 이 파일의 complete가 true이고 별도의 최종 Web 실행·성능까지 통과하기 전에는 승격하지 않는다. 기존 build/current의 EXE SHA-256 `15D4D4098BD767B8B8D63C5550749387DC57FC091651285BCB7BA5F37FF77939`를 보호한다. 종료된 로컬 서버만 재시작했으며 기존 작업 결과는 보존했다. 아래는 이전 시점의 과정 기록이다.

기존 검증본 build/current 및 artifacts/current를 보존한다. 신규 연출은 아직 검증·승격 전이다. 7영역 코드를 main에 통합했고 모션594검사를 통과했다. 실제 Godot576프레임/48초(타이틀24초,3기체전투18초,중력5초,UI1초)가 artifacts/candidate/motion에 있다. 전체 빌드20그룹/후보 Windows·Web export 성공. Windows 기존 최대밀도3회 p95 10.38~10.50ms. 해상도 검사에서 옛 단색 마커·정적 배경에 고정된 픽셀 테스트를 발견해 새 표현에 맞는 가독성/채움 검사로 수정했다. Web 혼합최대밀도 p95 18.7~19.1ms로 목표초과하여 적기체·체력바 배칭을 추가하고 재측정 중이다. 최종 렌더/출력/성능은 아직 승격 전이다. 7개 피드백 영역 모두 이번 작업 범위다. 게임 모델/저장/고스트 형식은 변경하지 않는다. 아래 완료 기록은 이전 art-20261012 세대이며 이번 변경의 합격 근거로 쓰지 않는다.

# Orbit Breaker 그래픽 개편 — 최종 재개 체크포인트

2026-10-12. **로컬 구현·검증·승격 완료**. 사용자 확인 중단 원인:5시간 사용량 한도. 제품 크래시를 확인한 것은 아니다. 기존 미커밋 변경과 완성 자산을 유지했다.

최신 로컬 세대는 **3.18 / art-20261012**다. `build/current/OrbitBreaker.exe`, Windows/Web ZIP, `build/current/web`와 `web/`, 대응 증거 `artifacts/current`가 최종본이다.

Windows SHA-256: `15D4D4098BD767B8B8D63C5550749387DC57FC091651285BCB7BA5F37FF77939`. Web PCK: `DA1B5DACF6A8FBDE1E05D481BBC12845F82D19418E3374B6C03A8D83E984FAF0`.

기존 정상 실행 파일·해시·안내·증거를 retiring에 먼저 보존하고 후보 검증/내보내기/실행/해시 일치를 확인한 뒤 교체했다. 교체 후 이전 세대와 임시 백업을 정리했다. 최신 한 세대 정책을 지키며 원본 계획·제작 소스·미커밋 변경·플레이어 데이터는 보존했다. 최종 목록은 `artifacts/current/file-inventory.json`, `release-hashes.json`, `retention-status.json`, `verification.json`이다.


전체125개 행 완료,95개 아트+2개 브랜딩. 자동2546/렌더2532/아트325/native입력14/10분자연전투·신구고스트34 통과. 통합 Windows p95 9.844/9.91/9.972ms, Web p95 14.9/14.4/14.4ms. Web1080표본 중33.3ms 초과1회. `verification.json`, `art/memory-comparison.json`, `art/runtime-status.json`이 정확한 수치/증거다.

추가 계측의 QA 장면은 main 스크립트를 두 번 초기화해 SoundBank 객체가 남던 문제를 수정했다. 이전 소스의 `_draw_enemy` 인자가 하나인 차이는 비교 fixture에만 반영했다. 두 비교 모두 실제 시간 진행/고스트 캡처와 오류 없는 종료를 확인했다. 게임 생산 코드/최신 실행 파일은 바꾸지 않았다.

재개 시 `production-source-hashes.json`, `release-hashes.json`과 실제 파일을 먼저 비교한다. 모든 체크포인트가 완료되어 있으므로 제작/빌드/승격을 자동 재실행하지 않는다. `integrate.py`는1회 마이그레이션 기록이다. 기존 `promote_art_release.ps1`는 이전 세대 SHA를 보호하는 이번 전환용이며 현재본에 무작정 재실행하지 않는다. 새 생산 변경이 생기면 영향받는 검증·내보내기부터 새 후보를 만든다.

잔여 한계는 [최종 보고서](ART_IMPLEMENTATION_REPORT.md)에 구분했다. Temp 정리는 blocked by policy, Windows OS 직접 클릭/저사양/다른 브라우저/사람 평가는 미확인이다. 공개 게시와 짧은 웹 smoke 검사는 아래 후속 결과로 완료했다.

---
## 중단 전 과정 기록 (최종 상태 아님)

# 그래픽 개편 재개 기록

최신 체크포인트: 로컬 `build/current` / `artifacts/current`를 art-20261012로 승격했다. 실행 파일 SHA-256은 15D4D4098BD767B8B8D63C5550749387DC57FC091651285BCB7BA5F37FF77939. 이전 정상본/증거는 보존·교체·해시 확인 뒤 정리했고 build/artifacts에는 current만 있었다. 아래는 과정 기록이다. 제작 목록125행, 아트325검사, 자동2546/화면2532, 10분 자연 전투+고스트34검사는 통과했다. 현재 전달 전 추가 검사로 최대 밀도 계측에 main._physics_process의 HUD/고스트 캡처까지 포함하도록 하네스를 보강했다. 생산 게임 코드는 바꾸지 않았으며, 추가 결과를 기존 검증본에 합친 뒤 문서/최종 목록을 갱신한다.

2026-10-12. 승인 계획의 범위를 유지하며 구현과 검증을 계속한다. 기존 미커밋 변경은 보존했다.

- 제작/연결: 런타임 94개 자산, 세 기체/7개 적/3개 전장/무장·모듈·FX/61개 벡터 도해. 전체 메뉴·전투·고스트의 공통 사용처 적용.
- 도구 비교: Blender 5.2.2 Cycles 실제 렌더와 내장 Imagegen 원본을 Godot에서 비교. 주 기체/적은 Imagegen, 소형 무장/모듈은 Blender, UI는 직접 SVG를 채택했다.
- 통과: 전체 자동 빌드 검사/Windows·Web 후보 내보내기, 16개 실제 렌더 회귀 케이스. 그래픽 294개 렌더 검사와 Windows 최대 밀도 3회 계측은 통과했으며 최종 메모리 기록 보강 후 재확인 예정.
- 미완료: Web 최대 밀도 성능, Windows 실행본 직접 조작, 최종 시각 검수·행별 제작표 증거 연결·후보 승격/보관 정리.
- 마지막 관측: 내장 Chromium Web QA 240적/240탄/300결정의 프레임 p95 45.3~46.2ms, 모델 p95 1.9ms. 부모 RAF p95 47.9ms. 목표 미달이므로 완료/승격 보류. 타이틀 기준선과 비교해 렌더 비용을 조사한다.
- 프로세스/중단: 빌드 및 QA Web export는 정상 완료, 로컬 서버 127.0.0.1:8765는 살아 있다. 반복 실행 중인 Godot/Blender는 없다. 대화 중단의 직접 원인은 저장소 로그에서 확인되지 않았다. 재시작/재설계 없이 현 상태에서 안전하게 재개 가능하다.
- 정상 배포: build/current의 기존 3.18은 그대로 유지한다. candidate는 아직 미승격. 외부 사이트/릴리즈는 게시하지 않았다.

- 추가 진단: Web 타이틀 RAF p95 8.1ms/p99 8.1ms, 33.3ms 초과 0회. 최대 밀도 렌더 병목으로 좁혔다. 공통 회전 스프라이트의 draw_set_transform 변경을 단일 textured primitive로 바꿔 배칭 개선 후 재검증 중이다. 원본 생성 스크립트도 함께 수정했다.
- Windows 직접 조작: 후보 실행은 성공했으나 Computer Use의 FrameArrived/window capture가 연속 2회 시간 초과했다. 캡처 없는 좌표 입력은 수행하지 않았다. 내보낸 바이너리 실행 로그/고정 프레임 캡처와 직접 조작을 구분한다.

최종 완료 상태는 ART_IMPLEMENTATION_REPORT.md와 art_source/worklist.json으로 갱신한다. 이 파일의 중간 결과만으로 전체 품질 합격을 주장하지 않는다.

최종 보관 확인: 추가 QA 임시 정리는 자동 승인 검토에서 `blocked by policy`로 거부되어 실행되지 않았다. 남은 경로는 `artifacts/candidate`(검증 art 자료만 있으며 후보 실행 파일 없음), `art_source/web_qa_project`, `art_source/memory_baseline_project`다. 최종 증거는 `artifacts/current`에 합쳐 보존했다. 정상 배포본은 build/current 한 세대이며 이전 배포 세대 정리는 완료됐지만 이 임시 정리는 미완료다. 삭제를 다른 방법으로 우회하지 않았다.

## 2026-10-12 공개 배포 완료

사용자의 후속 게시 요청으로 전체 작업268파일을 커밋 `d268760bcddcb9f93d40f2321a4b68df1b0193df`에 반영하고 main에 푸시했다. [v3.18.1 릴리즈](https://github.com/LibraLightLuda/orbit-breaker/releases/tag/v3.18.1)와 [웹 플레이](https://libralightluda.github.io/orbit-breaker/)가 공개됐다. 게임 규칙/게임 내 표시 버전3.18과 검증된 실행 파일은 유지한다. Pages 작업38241917579 성공, 공개 Web9파일 SHA-256이 로컬 검증본과 모두 일치한다. 릴리즈6첨부의 GitHub SHA-256 digest도 로컬 파일과 대조했다.

공개 Chromium에서 새 타이틀·출격 준비·전투 진행(27초/41처치)·강화2회 선택·ESC정지·무기도감과복귀를 직접 확인했다. 이는 짧은 공개 배포 smoke 검사이며 기존10분/native/성능 검사와 구분한다. Space/E 입력 전달만으로 공개 사이트에서 스킬 소비까지 별도 확인했다고 주장하지 않는다. 기존 릴리즈4첨부와 구Pages아티팩트1개는 새 공개본 검증 후 정리했고 소스 태그/릴리즈 이력은 보존했다. Windows/Web ZIP의 PLAY 안내는 공개 주소로 갱신하고 재패키징·내용/해시를 검증했다. 실행 파일과 Web 게임 파일 바이트는 그대로다.

최종 공개 근거는 `artifacts/current/github-publication.json`, `public-retention.json`, `art/public-web-hashes.json`, `art/public-release-assets.json`과 공개 화면 캡처다. 이전 절의 게시 전 상태는 이 후속 결과로 대체한다. 로컬 QA 임시 폴더와 계획 조사Temp의 기존 정책 차단은 그대로 남아 있다.
