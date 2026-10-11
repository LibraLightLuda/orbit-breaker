# ORBIT BREAKER 3.1 검증 기록

검증일: 2026-10-11 (한국 시간). Godot 4.7.1 stable. 현재 규칙은 SURVIVAL_V3.md다.

현재 Windows 배포본: build/current/OrbitBreaker.exe (116049200 bytes). SHA-256: 1A0EBCD603638518CD4F642940B2D36A2BD703DE227333E42641783321113412. 내장 데이터 Release를 실제 OpenGL로 180프레임 실행했고 종료 코드 0 및 오류 없음 확인. 직전 정상본은 build/previous/OrbitBreaker.exe에 보존했다. 직전 SHA-256은 6DECA51300CB7324FC0B871DA54A1FE2021BAEA916BD13332327975B563CC30B이며 이동 전후 일치한다. 검증 자료는 artifacts/current와 artifacts/previous다. 웹 파일은 web/ 및 build/current/web/이며 같은 세대의 동일 파일이다. GitHub Pages 공개와 실브라우저 렌더링 확인을 완료했다.

## 검증 범위

기본 전투/성장/회복/붕괴 회귀, 40개 업적의 누적 및 중복 방지, 이름 정규화, 난이도 해금, 점수 배율, 난이도별 개인 최고 10명, 저장 실패 롤백, 고스트 직렬화/검증/관전/탐색/일시정지, 카메라 좌표와 외곽 복귀 흐름을 검사한다.

실제 OpenGL UI는 1280×720과 960×540에서 확인한다. 테스트의 저장 경로는 실제 플레이어 기록과 분리한다. 새 화면을 포함한 캡처는 상태 주입 검사 장면이며 사람의 실전 플레이 기록이 아니다.

브라우저 로컬 후보에서 실제 키/마우스 입력으로 출격 → 외곽 이동/카메라 추적 → 종료 → 업적/이름별 랭킹 저장 → 랭킹에서 고스트 재생을 확인했다. 페이지 새로고침 후 최고 점수 205와 업적 5점이 유지됐다. 이 경로에서 브라우저 오류·경고 로그는 없었다. 공개 주소에서도 최종 게임 타이틀의 실제 렌더링 및 오류·경고 없음 확인을 완료했다.

## 한계

랭킹은 기기/브라우저 로컬 저장이다. 업적·난이도 해금은 기기 내 공유하고 이름은 랭킹의 개인 기록을 구분한다. 서버/계정/교차 기기 동기화는 사용하지 않는다. 고스트는 기체/위성 비행 기록이며 적·탄막의 전체 전투 리플레이는 아니다.

실제 사람의 상위 난이도 클리어·장기 밸런스 평가, Safari/Firefox/모바일/다중 모니터 호환성은 별도 미검증이다. 자동 플레이는 유한 상태와 종료·회귀를 검사하며 사람의 난이도 체감 또는 모든 기체의 상위 난이도 클리어 가능성을 증명하지 않는다.

## 최종 검사 결과

| 검사 | 통과 |
| --- | ---: |
| 모델 | 35/35 |
| 생존 | 185/185 |
| 확장 전투 | 68/68 |
| 36조합 자동 플레이 (3기체 × 3전장 × 4난이도) | 111/111 |
| 저장·오디오 | 122/122 |
| UI | 61/61 |
| 진행·랭킹·고스트 | 42/42 |
| 합계 | **624/624** |

OpenGL 화면 검사는 두 해상도(1280×720, 960×540) 각각 기존 UI 79/79, 새 진행/관전 UI 46/46 통과. 최종 화면 캡처 44장. build.log가 최종 전체 검사 및 두 플랫폼 내보내기 기록이고 render.log, render-small.log, progression-render.log, progression-small.log, release-render.log, web-validation.txt가 실행 증거다.

소스 타이틀 종료 시 ObjectDB 객체 2개 누수 경고가 기록됐다. 스크립트 오류는 없으며 내보낸 최종 실행 파일의 별도 180프레임 실행에는 이 경고와 오류가 없었다. 이 경고를 숨기거나 오류 0과 같은 의미로 취급하지 않는다.

최종 웹 파일을 다시 연 뒤 기존 점수 205/업적 5점과 이름별 랭킹 및 고스트 재생을 재확인했다. 한글 글꼴 가중치를 수정하여 최종 후보의 정상 표시를 확인했다.

## 공개 배포

- 웹: https://libralightluda.github.io/orbit-breaker/
- 소스: https://github.com/LibraLightLuda/orbit-breaker
- Windows 다운로드: https://github.com/LibraLightLuda/orbit-breaker/releases/tag/v3.1.0
- Pages 작업: https://github.com/LibraLightLuda/orbit-breaker/actions/runs/38102205941 (completed / success).
- 공개 웹 HTTP 200 및 실제 Chromium 렌더링 확인. 브라우저 오류·경고 로그 없음. 공개 index.pck의 SHA-256 E17535F8E7918B093A36A599100C05E278AF6EBBBA87301E2067F9D6BD87D89E 는 로컬 최종 후보와 일치한다.
- GitHub Release의 OrbitBreaker.exe 업로드 digest는 1A0EBCD603638518CD4F642940B2D36A2BD703DE227333E42641783321113412 로 로컬 최신 실행 파일과 일치한다.
- 최초 공개 게임 소스/웹 커밋: 61dbbec. 이후 문서 커밋은 게임 코드와 내보낸 바이너리를 변경하지 않는다.
