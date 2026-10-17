# 최신 로컬 검증 결과: 3.19 / clarity-20261016 (2026-10-16)

## 2026-10-18 공개 랭킹·웹 클라이언트 게시

공개 랭킹 Site 버전 3 배포와 API 7검사를 완료했다. GitHub 웹 클라이언트는 공개 랭킹 API로 연결하고 Sites/로컬 개발의 동일 출처 연결을 유지한다. 게임 전체 검사 후 최종 연결 회귀·재내보내기·소스/출력 해시를 검증했다. 온라인 권위 전투·공식 도전·2인 협동은 미제공 상태로 명시한다. 이번 공개 게시 대상은 웹과 랭킹 서비스이며 기존 정상 로컬 `build/current`는 유지한다. 실제 GitHub 게시·원격 파일 대조 결과와 남은 자료는 [게시 보고서](PUBLICATION_20261018.json)를 따른다. 아래는 이전 세대의 역사 기록이다.

[선명도 구현·검증 보고서](VISUAL_CLARITY_IMPLEMENTATION_REPORT.md) · [전체 95개 자산 검수표](VISUAL_CLARITY_COVERAGE.md). 플레이어 표시 42→52, 객체 실루엣/재질·픽업 가시영역·위험 경계·탄 중심 그리기 순서를 개선했다. 최종 linear/mipmap 비활성, 모바일 DPR 1. 모델·게임 콘텐츠·저장·고스트·업적·터치 제어 6개 원본과 실제 네이티브 플레이어 프로필 해시를 보존했다.

기존 headless 회귀 24묶음 3,840개, Python 17개, 새 선명도 441개, 네이티브 시작 전 107,328개, 전투 472개, 모바일 UI 2,982개, 전체 아트 317개가 통과했다. 시작 전 수치는 반복 레이아웃 assertion을 포함한다. 필수 검사부터 최종 내보내기까지 소스/자산/검사/도구/설정 685개 파일의 해시가 일치한다. Windows EXE 실제 창 생성·정상 종료/exit 0, 생산 Web 실제 출격/전투/강화/정지와 모바일 크기 네 가지 배치·회전을 확인했다. 합성 브라우저 입력과 별도 WebAssembly 입력 7/7은 실물 터치 검사와 구분한다. bootstrap 이후 설치한 오류 감시 중 오류 0개이며 전체 콘솔 이력 검사는 아니다.

동일 장비·장면에서 새로 측정한 300샘플×3회 네이티브 전체 전투 p95 중앙값은 9.916→9.668ms(-2.50%)로 10% 퇴행 기준을 통과했다. 단일 프레임 최대는 전 165.424ms/후 153.698ms이며 모든 프레임의 60fps를 보장하지 않는다. 모델 스트레스 평균 5.675/p95 10.008/최대 37.780ms, 보고된 텍스처 최대 70,734,411 bytes로 128MiB 이내다. 실제 Web QA p95는 23.9~44.4ms로 흔들렸으며 실물 모바일 성능 보증이 아니다. 미채택 DPR 1.5/2의 짧은 드래그 오인 실패 대조도 원시 기록에 포함했다.

Windows SHA-256 `1363DFF57C0B3FF8264F95EB52FDD71F4E289AAFD807F18EA7D337F24272B2FC`. Web PCK SHA-256 `24F2E97FBBCDCF3BA483ECE0C6152197A56B9C5A977A344772D366CBD2F5ACA4`. `build/current`·`artifacts/current`·`web/`가 대응한다. 정상본 보존→후보 검사/실행→교체/해시 재확인→이전 배포본·교체용 백업 정리를 완료했다. 이번 임시 `artifacts/clarity-work`도 정리했으나 과거 정책 차단 잔여 15개는 재시도하지 않아 전체 자료 정리는 미완료다. 정확한 범위는 `retention-status.json`·`file-inventory.json`을 따른다.

이번 선명도 세대의 공개 게시/원격 push는 수행하지 않았다. 아래 공개 v3.19.0 기록은 이전 audit-20261014 세대이며 아래 `artifacts/current` 참조도 당시 증거 경로의 역사 기록이다. 보관 규칙에 따라 그 이전 로컬 증거는 새 세대 검증 후 정리했다. 실물 휴대폰·Safari/iOS·저사양·장시간 사람 플레이/청취 및 사용자의 최종 미적 수용은 확인하지 않았다.

---

## 이전 검증 결과: 3.19 / audit-20261014 (공개 확인 2026-10-16)

## 2026-10-16 GitHub 공개 배포 완료

소스 32개 파일의 전투 확장·검수 보완을 커밋 [`79cae4c68ea71cb6a3255e9be6e5cb7ae2d70f73`](https://github.com/LibraLightLuda/orbit-breaker/commit/79cae4c68ea71cb6a3255e9be6e5cb7ae2d70f73)로 main에 반영했다. [GitHub Pages 작업 38546865017](https://github.com/LibraLightLuda/orbit-breaker/actions/runs/38546865017) 성공을 확인했으며 [웹 플레이](https://libralightluda.github.io/orbit-breaker/)와 [릴리즈 v3.19.0](https://github.com/LibraLightLuda/orbit-breaker/releases/tag/v3.19.0)을 공개했다.

공개 Web 9개 파일·기본 주소 HTML과 릴리즈 다운로드 6개를 실제 HTTP로 내려받아 SHA-256/바이트 수를 대조했고 모두 일치했다. Windows EXE와 Web PCK는 아래 로컬 검증본 그대로이며, ZIP·플레이 안내만 공개 주소로 갱신했다. 공개 Chrome DevTools 브라우저의 2048×970 CSS viewport에서 버전 3.19 메인 화면과 출격 준비 화면 전환을 스크린샷으로 확인했다. 전환 입력은 관찰한 버튼 위치에 보낸 합성 DOM MouseEvent다. 해당 동작 중 window error/unhandled rejection은 0개였지만 전체 콘솔을 수집한 검사는 아니며, 공개 모바일·실물 터치·장시간 전투/청취 검증으로 취급하지 않는다. 이전 로컬 브라우저/네이티브 검사 범위는 아래와 같다.

새 공개본 검증 후 이전 v3.18.3-audio-ui 첨부 6개를 삭제했다. 소스 태그·릴리즈 이력은 보존했다. Actions Pages artifact는 1일 보관 기간이 이미 만료되어 잔여 0개이며 이번 완료 단계에서 artifact를 직접 삭제하지 않았다. 로컬 정책 차단 임시 자료 15개는 재시도하지 않았고 전체 임시 자료 정리는 미완료다. 근거는 `artifacts/current/github-publication.json`, `public-web-hashes.json`, `public-release-assets.json`, `public-play-status.json`, `public-retention.json`, `retention-status.json`이다.

## 2026-10-14 로컬 후보·최신본 검증

[코드 검수 보완·검증 보고서](CODE_AUDIT_IMPLEMENTATION_REPORT.md). 오디오 불변성의 실제 진행/정상 종료, 제작 정보 전체 페이지의 뷰포트 터치, 원시 성능 수치 기반 판정, 소스·검사·출력 해시 연결, 손상 고스트 방어, 전술 선택 음악과 리플레이 보간을 보완했다. 기존 3.19 게임 수치·보상·난수·기록/고스트 형식은 유지한다.

최종 headless 회귀 24묶음 3,840개와 별도 Python 검증 13개, 실제 시작 전 렌더/터치 107,328개, 전투 화면/입력 472개, 성능 측정을 포함한 네이티브 아트 검사 320개가 통과했다. 시작 전 검사 수는 반복 레이아웃 assertion을 포함하며 서로 다른 사용자 시나리오 수가 아니다. 검사 시작부터 내보내기 완료까지 런타임·자산·테스트·도구·설정 677개 파일의 해시가 일치했고, 최종 배포 파일 15개·불변 증거 57개와 Windows/Web ZIP의 내용도 교체 후 재확인했다.

모델/고스트 스트레스는 평균 5.244ms, p95 9.222ms, 최대 13.168ms였다. 실제 20ms 지연을 넣은 실패 대조 검사에서 p95 30.204ms가 16.667ms 물리 프레임 예산을 초과해 종료 코드 1로 거부됐다. 전체 전투+렌더+HUD+고스트는 RTX 4070 Ti / 1600×900 / Dummy 오디오의 300샘플×3회에서 p95 중앙값 9.546ms였다. 동일 fixture의 이전 검증 완료 세대 기록 9.649ms 대비 약 1.07% 감소했으며, 이전 baseline을 이번에 새로 실행한 A/B 검사는 아니다. 리플레이 계산만 비교한 별도 검사에서는 4.063→1.322ms로 약 67.46% 감소했다. 전체 화면 FPS 개선율을 뜻하지 않는다.

최종 Windows EXE의 실제 창 생성·정상 OS 종료/exit 0와 플레이어 프로필 해시 불변을 확인했다. Codex 내장 브라우저의 1280×720에서 메인→출격→강화 선택→ESC 정지→TAB 도감, 390×844에서 설정/라이선스 1→4페이지, 844×390에서 회전/복귀를 확인했으며 콘솔 오류/경고는 0개다. 모바일 크기의 브라우저 입력은 클릭 기반이다. 전체 페이지 터치는 별도 Godot 네이티브 뷰포트 검사이며 실물 휴대폰 검증이 아니다.

최신 로컬본은 `build/current`, 대응 증거는 `artifacts/current`, Web 복사본은 `web/`다. Windows SHA-256 `DCC4FE1CFF548FBF778E1D808972B98ED559A023C3A5B9041205E5D6F0D2BC88`. Web PCK `E63EA3688FA094A03387F3011E0124578DA79A879949C5613A6CD84C17B98807`. 정상본 보존→후보 검사/실행→교체/해시 재확인→이전 정상본/교체용 백업 정리 순서를 따랐다. 현재 배포 경로는 한 세대지만, 과거 정책 차단 12개와 이번 임시 폴더 3개의 삭제가 차단되어 전체 자료 정리는 미완료다. 정확한 경로/사유는 `artifacts/current/retention-status.json`과 [보관 규칙](ARTIFACT_RETENTION.md)을 따른다. 공개 게시/원격 push는 수행하지 않았다. 실물 휴대폰·Safari/iOS·저사양·장시간 사람 플레이/청취 수용은 미검증이다.

---

## 이전 로컬 검증 결과: 3.19 / combat-20261014 (2026-10-14)

[전투 확장 구현·검증 보고서](COMBAT_IMPLEMENTATION_REPORT.md). 진화6분기·보스 약점·환경 역이용·선택형 최종 작전 구현과 Windows/Web 후보 검증·최신본 교체 완료.

최종 24묶음 110,520개, 새 기능 194/194, 실제 새 화면/입력 472/472 통과. 같은 환경의 전투+렌더+HUD+고스트 p95 중앙값 9.428→9.649ms(+2.34%). 최종 EXE 정상 실행/종료, Web 로컬 브라우저, 실제 플레이어 프로필 해시 불변을 확인했다. 실제 범위는 verification.json·native-release.json·browser-status.json이다.

최신본 build/current, 증거 artifacts/current. Windows SHA-256 3A8D00DE5960846F6DFED49F7FA8E14DDEE5DD0E57F4BA3387FADD11BB230130. Web PCK 967D4DD786A0771145CFDA1C315ED4E53C2D1F4845906DBE99B70509DACE8029. 정상본 보존→후보 검증→교체→이전 세대 정리 순서를 따랐으며 잔여 정리는 retention-status.json이 기준이다. 공개 게시하지 않았다. 실물 휴대폰·Safari/iOS·저사양·장시간 사람 밸런스 수용은 미검증이다.

---
아래는 이전 세대 기록이다.

## 2026-10-14 사운드·시작 전 모바일 UI 공개 배포 완료

전체 변경 431파일과 음원 195개·독자 제작 소스를 커밋 `db122e2bf157f50993c9efcb7bd3d6cef1e5e5f4`로 main에 게시했다. [릴리즈 v3.18.3-audio-ui](https://github.com/LibraLightLuda/orbit-breaker/releases/tag/v3.18.3-audio-ui)와 [웹 플레이](https://libralightluda.github.io/orbit-breaker/) 공개 완료. 게임 표시 버전 3.18.3, 검증된 EXE/PCK 바이트는 유지하며 ZIP 안내만 공개 주소로 갱신했다.

Pages 작업 [38492355622](https://github.com/LibraLightLuda/orbit-breaker/actions/runs/38492355622) 성공. 공개 Web 9파일·기본 HTML과 릴리즈 6첨부의 크기/SHA-256이 최종 로컬본과 일치한다. 공개 Chromium 390×844·844×390에서 메인·설정·페이지/복귀·기체/전장 선택·회전 상태 유지와 콘솔 오류/경고 0을 확인했다. 이전 릴리즈 첨부 6개와 이전 Pages artifact 1개는 신규 공개본 검증 후 정리했다. 소스 태그와 릴리즈 이력은 보존했다.

기존 회귀 3,100개와 시작 전 실제 렌더 106,496개는 최신 로컬 검사 결과이며, 이번 공개 smoke를 장시간 플레이나 실물 휴대폰/사람의 청취 수용으로 취급하지 않는다. 최종 근거는 `artifacts/current/github-publication.json`, `public-web-hashes.json`, `public-release-assets.json`, `public-retention.json`, `public-play-status.json`이다.

# 최신 로컬 검증 결과: 3.18.3 / pregame-20261014 (2026-10-14)

[시작 전 모바일 UI 검수 보고](PREGAME_MOBILE_REPORT.md). 메인·출격 준비·기록·도감·도움말·설정·라이선스의 가로/세로 흐름을 개선했다. 고정 탭·복귀·출격과 페이지 이동으로 세로 스크롤 없이 선택한다. 카드 밖으로 분리되던 긴 조건을 같은 카드에 묶고, 이름 입력 포커스와 선택을 회전 후 복원한다. 진행 중 UI는 이번 검수에서 제외했다.

기존 회귀 3,100개와 시작 전 실제 렌더 106,496개를 통과했다. 8개 콘텐츠 크기, 기본 화면 상태 120개와 전체 페이지, 기록 8개·랭킹 10개, 실제 Viewport 터치·hit test·화면 경계·고정 메뉴 겹침·회전 상태를 검사했다. Windows 내보낸 EXE 창 생성·정상 종료/exit 0·오류 없음, 실제 프로필 해시 불변을 확인했다. Chromium Web의 최종 검수 범위는 `browser-status.json`을 따른다.

최신 로컬본은 `build/current`, 대응 증거는 `artifacts/current`, 게시용 복사본은 `web/`다. Windows SHA-256 `8AFC0A2BAE31F3221EF4C7F05566F676D41DB9476E393143B93055E79BFEB40A`, Web PCK `7B002A57489D9B6AE95F3B2524FB16567DACA59EC9110688ACF8F459F5548DE9`. 기존 정상본 보존 → 후보 검사·내보내기·실행·해시 → 교체 → 이전 세대 정리 순서를 지켰다. 과거 정책 차단 임시 자료는 재시도하지 않았으며 `retention-status.json`에 남긴다. 공개 사이트/릴리즈/push는 수행하지 않았다.

실물 휴대폰·Safari/iOS·소프트 키보드/IME 실기기·노치/주소창의 기기별 동작은 미검증이다. 아래 결과는 과거 세대 기록이다.

---

# 최신 로컬 검증 결과: 3.18.3 / audio-20261014 (2026-10-14)

[사운드 구현·검증 보고서](SOUND_IMPLEMENTATION_REPORT.md). 독자 제작 cue136개·음원195개(9,192,418바이트), 3레이어 전투 음악·전장 환경음·UI/전투/아이템/파츠/미션/재해·체력/붕괴/외곽 경고를 적용했다. 게임 규칙·난수·기존 저장/고스트 형식을 보존했다.

전체23묶음 3100개(오디오551개 포함), 실제 렌더16사례2534개, 내장 음원/제외 검사383개 통과. 물리 커서 두 크기와 전체화면도 통과했다. Windows 10분 실제 Master 캡처, 최종 Web 실제 출력 기록, 자연 전투/강화/재개/패배·설정·첫 입력 오디오 활성화, 콘솔 오류·경고0을 확인했다. 실제 플레이어 프로필 해시 불변이다. Windows 내장 pack은 동일4.7.1 엔진에서 실제 렌더/오디오와 정상 종료를 확인했다. release EXE는 headless 시작 종료 및 실제 렌더 시작을 확인했다. 강제 --quit-after 렌더 종료의 엔진 리소스 경고는 성공 판정에서 제외하며 보고서에 남겼다.

Windows SHA-256 `B2D149A5EE333EFBE3316B1BD2DA79725F465E16C938A6EAD3D9CA2A7E25353E`. Web PCK `6D6CF5D543069E5243EF5569960B436046FCF95E71EE4C8028390D2E6AF0C1A5`. 최신본은 `build/current`, 증거 `artifacts/current`, 게시용 로컬 복사본 `web/`이다. 공개 사이트/릴리즈/원격 push는 수행하지 않았다. 아래 공개 결과는 이전 공개 세대의 역사다.

통합 출력 Windows -26.77 LUFS-I/-7.23dBTP, Web -30.94 LUFS-I/-16.58dBTP. 10분 캡처 최대14효과음. RTX4070Ti 합성 부하의 ON 프레임 p95 중앙값10.569ms이며 저사양/모바일 성능 보증은 아니다. 사람 청취 수용·실물 휴대폰·Safari/iOS·장시간 사람 플레이는 미검증이다. 최신 한 세대 교체/정리와 과거 정책 차단 임시7디렉터리·5로그의 잔존은 최종 retention-status/file-inventory가 기준이다.

---

# 최신 검증 결과: 3.18.3 / feedback-20261013 (2026-10-13)

사용자 모바일 피드백 1~5를 반영했다. [구현과 검증 범위](MOBILE_FEEDBACK_3183.md). 출격 준비 선택 시 떨림을 제거했고 메인·출격 준비·강화 선택을 가로/세로 한 화면에 배치했다. 길게 드래그 후 놓은 방향 돌진, 두 번 탭 오버드라이브, 가장자리 보급/파츠 안내를 적용했다. 세로 회전 안내 가림과 긴 강화 설명 줄 겹침도 실제 브라우저에서 발견해 수정했다.

전체 22묶음 2571개, 최종 모바일 2982개(8개 크기), 실제 viewport 터치 42개, 렌더 16사례 2534개, 아트 316개 통과. 전투·데이터·저장·고스트 원본이 동일함을 확인하고 전체 회귀 결과를 유지했으며, 이후 UI 배치 수정은 모바일·전체 렌더·아트·Windows/Web export·최종 EXE 실행 검사를 다시 통과했다. 실제 플레이어 프로필 불변을 확인했다. 후보 Chromium에서 자연 강화·긴 설명·회전·카드 선택·전투 재개·정지를 확인했고 콘솔 오류/경고0이다.

현재 정상본은 `build/current`, 대응 증거는 `artifacts/current`. Windows SHA-256 `82B7CF017639B020C9922945476F64CB57C9390A996071513AB8BA7206F943AB`. Web PCK `FADD8592B14C972A2129F3BD7CEE23ABF5EECFF5881B714A366CD831568626A1`. 기존 정상본을 보존하고 후보 검증/내보내기/실행/해시 성공 후 교체했으며 이전 최신본과 retiring을 정리했다. 배포본은 최신 한 세대다. 기존 정책 차단 임시5경로에 이번 `artifacts/feedback-candidate` 정리 차단을 더해 임시6개 디렉터리와 진단 로그5개가 남았다. 삭제 우회/재시도는 하지 않았다. [v3.18.3 릴리즈](https://github.com/LibraLightLuda/orbit-breaker/releases/tag/v3.18.3)와 [공개 웹](https://libralightluda.github.io/orbit-breaker/?v=3.18.3) 게시 및 공개 플레이 검증 완료. 소스 커밋 `822b1911a62f6bafe2533245fbd9c17d3aa6216a`, Pages 작업 `38365053828` 성공. 공개9파일/기본 HTML과 릴리즈6첨부 SHA-256이 일치한다. 공개 Chromium에서 기체/전장 선택·전투·자연 강화·회전·카드 선택·정지를 확인했고 콘솔 오류/경고0이다. 신규 공개본 검증 후 이전 릴리즈 첨부6개와 이전 Pages artifact1개를 정리하고 소스 태그/릴리즈 이력을 보존했다.

물리 휴대폰·Safari·저사양 성능·장시간 사람 플레이는 미검증이다.

---
아래는 과거 기록이며 현재 상태는 위 결과가 우선한다.

# 최신 검증 결과: 3.18.2 / mobile-20261013 (2026-10-13)

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

## 온라인 확장 후보 검증

온라인 확장의 실제 증거/미검증 사항은 [ONLINE_VALIDATION.md](ONLINE_VALIDATION.md)에 기록한다. 익명 랭킹 Sites를 공개 배포했으며 전투 서버의 공개 배포·실제 Windows 실행 파일 조합 완주·원격 수용량 검사가 남아 있다. 이 상태를 정식 온라인 서비스 배포 완료로 취급하지 않는다. 기존 검증 완료 배포본은 보존한다.
