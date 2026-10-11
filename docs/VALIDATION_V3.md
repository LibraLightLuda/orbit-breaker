# ORBIT BREAKER 3.2 검증 기록

검증일: 2026-10-11 (한국 시간). Godot 4.7.1 stable. 현재 규칙은 SURVIVAL_V3.md다.

Windows 최신 배포본: build/current/OrbitBreaker.exe (116051008 bytes). SHA-256: 70354E66D53A6137FE28C4D1A3A700ADF75FA607DD4A769AF23F5F9850564E02. 직전 3.1은 build/previous/OrbitBreaker.exe, SHA-256: 1A0EBCD603638518CD4F642940B2D36A2BD703DE227333E42641783321113412. 검증 자료는 artifacts/current와 artifacts/previous다. 웹 파일 web/과 build/current/web/은 같은 세대의 동일 파일이다.

## 세 기체 검증

스트라이커의 실제 사격 중첩·최대 화력·고출력/오버드라이브 조합·피격/사격 중단 초기화·탄 수 제한, 스카우트의 대시 피해와 중복 타격 방지·가속·추진 강화·외곽 제약, 배스천의 피해 감소·근거리 반격과 밀치기·범위 밖 제외·재충전·난이도/오버드라이브 조합·환경 피해 우회를 검사했다. 재출격 초기화와 강화 중 타이머 정지도 포함한다. 기존 회복 경제·랭킹·고스트 형식을 유지한다.

| 검사 | 통과 |
| --- | ---: |
| 모델 | 35/35 |
| 생존 | 185/185 |
| 확장 전투 | 68/68 |
| 기체 고유 능력과 HUD | 38/38 |
| 36조합 자동 플레이 (3기체 × 3전장 × 4난이도) | 111/111 |
| 저장·오디오 | 122/122 |
| UI | 61/61 |
| 진행·랭킹·고스트 | 42/42 |
| 합계 | **662/662** |

실제 OpenGL 화면 검사: 1280×720과 960×540 각각 UI 79/79, 진행/고스트 46/46, 기체 HUD 41/41. 합계 332/332, 캡처 50장. 작은 화면에서 스트라이커 설명이 능력치와 겹치는 문제를 수정한 뒤 UI 캡처를 다시 검사했다. 기체 캡처는 상태를 주입한 검사 장면이며 실제 사람의 플레이 기록이 아니다.

두 플랫폼 Release 내보내기 완료. 최종 내장 데이터 Windows 실행 파일을 OpenGL로 180프레임 실행하고 실제 프로세스 종료 코드 0 및 스크립트/렌더 오류 없음 확인. 종료 때 ObjectDB 객체 2개 누수 경고가 기록됐다. 소스 검사에서도 간헐적으로 같은 경고가 나타났으며 경고를 숨기거나 오류 0과 동일시하지 않는다.

로컬 Chromium에서 최종 웹 후보의 3.2 타이틀·기체 선택 화면을 확인했다. 기존 최고 점수 205와 업적 5점 보존, 스카우트 선택/출격 후 키보드 Space로 대시와 가속 표시·외형을 확인했다. 해당 브라우저 오류·경고 로그는 비어 있었다. 최종 웹 데이터 index.pck SHA-256: D7729CEFD257D43AE3258878C87B2A4D0AAD5D17B3B93F64F337472627C1FEEA.

build.log는 필수 검사 및 최종 두 플랫폼 내보내기, ui/progression/ships-render(-small).log는 화면 검사, release-render.log와 release-status.txt는 내보낸 실행 파일, web-validation.txt는 브라우저 확인 증거다. 새 후보 검증 후 기존 최신 3.1을 직전본으로 보존했다. 오래된 3.0 배포 자료 삭제는 실행 도구의 자동 승인 검토에서 차단되어 build/retiring 및 artifacts/retiring에 남아 있다. 상세 상태는 ARTIFACT_RETENTION.md에 기록했다.

## 공개 주소

- 웹: https://libralightluda.github.io/orbit-breaker/
- 소스: https://github.com/LibraLightLuda/orbit-breaker
- Windows 3.2: https://github.com/LibraLightLuda/orbit-breaker/releases/tag/v3.2.0

Pages 작업 https://github.com/LibraLightLuda/orbit-breaker/actions/runs/38103128749 가 completed/success로 완료됐다. 공개 웹 HTTP 200 및 index.pck SHA-256 D7729CEFD257D43AE3258878C87B2A4D0AAD5D17B3B93F64F337472627C1FEEA가 로컬 최신본과 일치한다. 실제 공개 Chromium에서 VERSION 3.2 타이틀 렌더링 및 브라우저 오류/경고 없음 확인. Windows Release 업로드 digest 70354E66D53A6137FE28C4D1A3A700ADF75FA607DD4A769AF23F5F9850564E02는 로컬 최신 실행 파일과 일치한다. 게임 소스/웹 커밋은 0b2bf03이다.

## 한계

자동 플레이는 회귀와 유한 상태·종료를 검사하며 사람의 난이도 체감과 장기 밸런스를 증명하지 않는다. 이번 자동 플레이에서는 표준 9조합 모두 돌파했으나 사람의 플레이 결과와 같지 않다. 실제 사람의 기체별 상위 난이도 클리어·장기 평가, Safari/Firefox/모바일/다중 모니터는 미검증이다.

랭킹은 기기/브라우저 로컬이며 이전 기록을 초기화하지 않는다. 3.1과 3.2의 다른 기체 밸런스에서 획득한 점수가 함께 표시된다. 고스트는 기체/위성의 비행 경로이며 적·탄막·고유 능력의 전체 전투 재현은 아니다.
