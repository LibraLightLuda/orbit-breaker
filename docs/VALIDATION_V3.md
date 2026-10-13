# 최신 검증 결과: 3.18.2 / mobile-20261013 (2026-10-13)

모바일 Web 드래그 이동·탭 돌진·두 번 탭 오버드라이브, 가로/세로 HUD·카메라, 가로 전체화면 요청과 세로 안내를 구현했다. 기존 미커밋 7영역 모션 개선을 함께 보존했다. 로컬 최신본 교체 완료, GitHub/Pages 배포 준비 중. [모바일 구현·검증 보고](MOBILE_WEB_REPORT.md).

21묶음2557 회귀, native 터치42, 데스크톱 입력14, 실제16화면2536, 아트325, 모션601/576프레임, WebAssembly 터치5 통과. 최종 Web 부하3회씩 p95 혼합13.8/14.4/13.6ms, 일반10.8/10.3/10.6ms. Windows 정상 실행/종료·프로필 불변 확인. 물리 휴대폰·Safari·저사양 장치 및 전체화면 회전 잠금의 실기기 동작은 미검증이다.

최신본 `build/current`, 증거 `artifacts/current/mobile`와 `verification.json`, 전체 목록 `file-inventory.json`. Windows SHA-256 `8AE93D875BE76E77153E04746729C6A3D3CF24DEEFEE3F3E9D9637CA168F1A99`. Web PCK `DAA90D44EE4253E938674914FD1E30C6018DA52D22C636F7DB378B1C8C3255FF`. 이전 정상본 보존→새본 검증→교체→이전 배포/증거 정리 순서를 지켰다. 과거 정책 차단 임시5경로는 재시도하지 않고 retention-status에 남겼다. 게임 규칙·밸런스·저장·고스트 형식은 3.18을 유지한다.

---
아래는 과거 시점 기록이며 현재 상태는 위 결과가 우선한다.

# 최신 검증 결과: motion-20261013 (2026-10-13)

**7영역 구현·실제 렌더/Windows·Web 검증·로컬 최신본 교체 완료.** 자세한 결과와 미검증 한계는 [모션 개선 최종 보고](MOTION_IMPLEMENTATION_REPORT.md)를 따른다. 현재 실행본은 `build/current`, 증거는 `artifacts/current`. 모션601/실제16화면2536/아트325/10분 자연전투·고스트34 통과, Web 혼합최대밀도 p95 14.6~14.9ms. Windows SHA-256 `1F4D0FCBE22227C3C7DA024AB2ECBF9ADDAA97F322D25E39C0AF7D44ECB2F74C`. 공개 사이트는 이전 v3.18.1이며 이번 모션 세대는 로컬 검증본이다. 다시 재개할 때 완료 검사를 반복하지 말고 이 세대의 manifest와 변경분을 먼저 비교한다. 임시 정리5경로는 blocked by policy로 미완료이며 `retention-status.json`에 기록했다.

---
아래는 이전 검증·과정 기록이다. 현재 상태는 위 결과가 우선한다.

# ORBIT BREAKER 3.18 — art-20261012 최종 로컬 검증

2026-10-12. 게임 규칙은 [SURVIVAL_V3](SURVIVAL_V3.md), 아트 결정/제작 비교/실제 화면 평가는 [구현 보고서](ART_IMPLEMENTATION_REPORT.md),125개 행의 상태는 `art_source/worklist.json`을 따른다.

## 적용 범위

세라믹·흑연 기체, 흑요석·적색 코어의 침공체,3전장의 깊은 우주 표면, 물리 장비·모듈·드롭·FX,61개 벡터 도해를 전체 메뉴·전투·신/구 관전에 적용했다.95개 아트 리소스와2개 브랜딩 리소스다. Blender와Imagegen의 실제 Godot A/B를 거쳐 주 기체 제작 방식을 변경했다. 정확한 판정 경계·계기·기능 기호는 절차적 표현을 유지한다. 작은 강화 메뉴의 선택 카드/조건 스크롤과 로더 오류 표면까지 확인했다.

## 실제 검증

- 자동 검사 **2,546/2,546**(20묶음), 실제 화면 회귀 **2,532/2,532**(16사례), 아트 계약·렌더 **325/325**, native 입력 **14/14**, 10분 자연 전투·신/구 고스트 **34/34** 통과.
- 1600×900 Windows/RTX4070 Ti/Compatibility 통합 전투: 준비60 + 측정300표본×3회, p95 **9.844/9.91/9.972ms**, p99 10.600~11.015ms, 최대18.653ms. 모델·렌더·HUD·고스트 캡처 포함, Dummy 오디오로 음소거.
- 내장 Chromium/WebGL 통합 전투: 준비60 + 측정360표본×3회, p95 **14.9/14.4/14.4ms**, p99 **17.7/16.2/16.6ms**. 최종 브라우저의 논리 viewport 1280×1261, draw call 1065~1076. 적243·탄240·경험치300, 합성 최대 설치물. 전투 시간 진행과 고스트35프레임을 각 회 검증했다. 총1080표본 중33.3ms 초과1회(최대39.8ms), 나머지 두 회 최대26.0/24.5ms. 반복적인 초과는 없었으나 단발 지연을 숨기지 않는다. 브라우저 스케줄링 포함 수치다.
- 동일 QA 장면/논리1280×720의 이전 Git 소스 대조: 기존 p95 27.919/29.439/29.275ms, 새 그래픽9.524/9.951/9.811ms. 텍스처16,092,791→70,726,227bytes(**+54,633,436bytes, 약52.1MiB**). Godot static 할당99,743,581→98,920,374bytes(-823,207bytes). 현재 전체 텍스처 약67.5MiB, 1600×900 아트 검사에서는68.1MiB로128MiB 예산 이내. static은 전체 프로세스 RSS가 아니며 Web static의0은 측정 불가로 취급한다.
- Web PCK **14,252,700bytes**, 기존6,943,544 대비+7,309,156bytes. Web 전체 파일 증가7,329,208bytes로 신규 다운로드20MiB 예산 이내.
- 보호된 원본 소스/fixture **59개 해시 동일**. 모델·콘텐츠·저장·고스트·업적·오디오 코드 유지. 기존 메뉴 흐름의 작은 화면 배치는 정보 누락을 고치기 위해 수정하고 회귀했다. 실제 사용자 프로필3파일의 실행 전후 해시 동일.
- 최종 Windows Release180프레임 종료0, 정확한 실행 파일 SHA 검증. 실제 exe 제목 캡처와 PE 아이콘 추출 확인. Web 실제 메뉴·출격·전투·일시정지·도감·강화 및 로딩/오류 화면 확인. Windows 하드웨어 클릭 검증과 native 엔진 입력 하네스는 구분한다.

자동 검사는 게임 기능과 데이터 보호를 검증한다. 실제 렌더/움직임 검토는 별도이며 기체3종·적7종·3전장·12진화·36보급등급·6위험의 예고/작용·작은 메뉴·정지/배속/seek 증거를 확인했다. 자체6개 품질 축은 각4/5, 관찰된 치명 결함0이다. 테스트 통과나 이미지 생성만으로 미술 품질을 판정하지 않았다.

## 배포·보관

최신 로컬 세대는 **3.18 / art-20261012**다. `build/current/OrbitBreaker.exe`, Windows/Web ZIP, `build/current/web`와 `web/`, 대응 증거 `artifacts/current`가 최종본이다.

Windows SHA-256: `15D4D4098BD767B8B8D63C5550749387DC57FC091651285BCB7BA5F37FF77939`. Web PCK: `DA1B5DACF6A8FBDE1E05D481BBC12845F82D19418E3374B6C03A8D83E984FAF0`.

기존 정상 실행 파일·해시·안내·증거를 retiring에 먼저 보존하고 후보 검증/내보내기/실행/해시 일치를 확인한 뒤 교체했다. 교체 후 이전 세대와 임시 백업을 정리했다. 최신 한 세대 정책을 지키며 원본 계획·제작 소스·미커밋 변경·플레이어 데이터는 보존했다. 최종 목록은 `artifacts/current/file-inventory.json`, `release-hashes.json`, `retention-status.json`, `verification.json`이다.


## 미확인/잔여

- Windows Computer Use의 FrameArrived/window 캡처가2회 시간 초과했다. 좌표를 추측해 조작하지 않았으며, 실제 exe 실행/엔진 movie 캡처와 같은 Godot 버전의 입력 하네스로 검증했다. OS 하드웨어 직접 조작을 완료했다고 주장하지 않는다.
- 일부 정상 종료 로그에 기존2 ObjectDB 인스턴스 경고가 남는다. 추가 QA는 스크립트를 두 번 붙여 오디오 객체를 고아로 만들던 문제를 고쳐 오류 없이 종료했다. 진단 실패 로그는 원인 기록으로 남겼다.
- 저사양 실제 장치·Safari/Firefox·사람의 장시간 플레이/미적 수용·실제 오디오 청취는 확인하지 않았다. 자체 시각 평가4/5는 상용 등급 인증이나 사용자 승인이 아니다.
- 공개 GitHub/Pages 게시가 후속 사용자 요청으로 완료됐다. 최신 공개 릴리즈는v3.18.1이며 상세 근거는 아래 공개 배포 절을 따른다.
- 계획 조사 Temp `C:\Users\home\AppData\Local\Temp\orbit-breaker-art-review-20261012`는 과거 자동 승인 검토의 `blocked by policy`로 삭제가 실행되지 않았다. 우회/재시도하지 않았으며 임시 정리 잔여로 명시한다.

최종 보관 확인: 추가 QA 임시 정리는 자동 승인 검토에서 `blocked by policy`로 거부되어 실행되지 않았다. 남은 경로는 `artifacts/candidate`(검증 art 자료만 있으며 후보 실행 파일 없음), `art_source/web_qa_project`, `art_source/memory_baseline_project`다. 최종 증거는 `artifacts/current`에 합쳐 보존했다. 정상 배포본은 build/current 한 세대이며 이전 배포 세대 정리는 완료됐지만 이 임시 정리는 미완료다. 삭제를 다른 방법으로 우회하지 않았다.

## 2026-10-12 공개 배포 완료

사용자의 후속 게시 요청으로 전체 작업268파일을 커밋 `d268760bcddcb9f93d40f2321a4b68df1b0193df`에 반영하고 main에 푸시했다. [v3.18.1 릴리즈](https://github.com/LibraLightLuda/orbit-breaker/releases/tag/v3.18.1)와 [웹 플레이](https://libralightluda.github.io/orbit-breaker/)가 공개됐다. 게임 규칙/게임 내 표시 버전3.18과 검증된 실행 파일은 유지한다. Pages 작업38241917579 성공, 공개 Web9파일 SHA-256이 로컬 검증본과 모두 일치한다. 릴리즈6첨부의 GitHub SHA-256 digest도 로컬 파일과 대조했다.

공개 Chromium에서 새 타이틀·출격 준비·전투 진행(27초/41처치)·강화2회 선택·ESC정지·무기도감과복귀를 직접 확인했다. 이는 짧은 공개 배포 smoke 검사이며 기존10분/native/성능 검사와 구분한다. Space/E 입력 전달만으로 공개 사이트에서 스킬 소비까지 별도 확인했다고 주장하지 않는다. 기존 릴리즈4첨부와 구Pages아티팩트1개는 새 공개본 검증 후 정리했고 소스 태그/릴리즈 이력은 보존했다. Windows/Web ZIP의 PLAY 안내는 공개 주소로 갱신하고 재패키징·내용/해시를 검증했다. 실행 파일과 Web 게임 파일 바이트는 그대로다.

최종 공개 근거는 `artifacts/current/github-publication.json`, `public-retention.json`, `art/public-web-hashes.json`, `art/public-release-assets.json`과 공개 화면 캡처다. 이전 절의 게시 전 상태는 이 후속 결과로 대체한다. 로컬 QA 임시 폴더와 계획 조사Temp의 기존 정책 차단은 그대로 남아 있다.
