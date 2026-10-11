# ORBIT BREAKER 3.4 검증 기록

검증일: 2026-10-11 (한국 시간). Godot 4.7.1 stable. 게임 규칙은 SURVIVAL_V3.md를 따른다.

## 변경 범위

외곽 2층의 피해·감속·복귀 흐름을 함께 낮췄다. 3층의 최대 기본 피해는 120 HP/초로 조정했다. 스트라이커는 정지 1.2초 후 자동포 피해 +60%의 조준 고정을 사용하며 이동·돌진·실제 피격으로 해제된다. 일반 적 생성 빈도는 1.8배, 동시 일반 적 제한은 240이다. 추적체의 좌우 포위, 질주체의 예고 돌진, 중장체의 이동 진로 차단, 포격수의 거리 유지·선회·후퇴를 구현했다.

미니맵·구역 이름·눈금·외곽 설명 배너·하단 스킬 패널을 제거했다. 경계는 색이 다른 부드러운 광륜, 위험은 화면 테두리와 복귀 화살표로 표시한다. 스킬 충전은 기체 아래의 작은 초록/금색 게이지와 마우스 버튼 그림으로 표시한다. 기존 기록·업적·설정·고스트 저장 형식을 유지한다.

## 자동 검사

| 검사 | 통과 |
| --- | ---: |
| 기본 모델 | 35/35 |
| 생존·회복·환경 피해 | 185/185 |
| 확장 전투 | 68/68 |
| 기체 개성 | 40/40 |
| 원형 공간·층별 이동·침공·적 전술·스킬 충전 | 159/159 |
| 36조합 자동 플레이 | 111/111 |
| 저장·오디오 | 122/122 |
| UI | 61/61 |
| 진행·로컬 랭킹·고스트 | 42/42 |
| 합계 | **823/823** |

시드 7의 자동 조종 결과: 표준·여유롭게·베테랑은 각각 9/9 돌파, 대붕괴는 5/9 돌파. 유한 상태와 10분 내 종료를 모든 조합에서 확인했다. 이는 한 시드의 회귀 검사이며 사람의 클리어 확률을 뜻하지 않는다.

원형 경계와 층별 연속 피해·복귀 흐름, 외곽 2층에서의 4초 이동/생존, 3층 깊은 곳에서 최대 정상 선체·재생으로 장기 체류 불가, 일반 적의 층별 생성과 강적 침공을 검사했다. 새 전술은 실제 좌표 이동으로 포위 선회·원거리 거리 유지/후퇴·예고 후 고정 방향 돌진·진로 차단을 확인했다. 스트라이커는 조준 충전/이동·돌진·피격 해제/자동포만 강화/기존 강화·오버드라이브와의 결합/일시정지/다른 기체와의 분리를 검사했다.

## 실제 표시·실행

1280×720 및 960×540 각각 UI 79/79, 진행·관전 46/46, 기체 43/43, 원형 공간·전술 166/166. 합계 **668/668**, 캡처 **64장**. 층별 색 경계·복귀 화살표, 강적 접근 표시, 기체별 충전 중/완료/효과 줄이기, 적 60기의 공격 예고가 있는 장면을 확인했다.

Windows 및 단일 스레드 Web Release 내보내기 성공. 최종 Windows 실행 파일을 실제 OpenGL에서 180프레임 실행해 종료 코드 0, 스크립트/렌더 오류 없음과 종료 경고 없음 확인. 일부 소스 검사 종료에는 ObjectDB 객체 2개 누수 경고가 간헐적으로 남는다.

Chromium에서 VERSION 3.4, 기존 localhost 최고 1,065/업적 35점 보존, 기체 선택 설명, 실제 Space 돌진과 이동, 정지 조준 +60%, 미니맵/하단 스킬 패널 제거, 기체 주변 충전 게이지를 확인했다. 외곽으로 이동 후 안쪽 돌진으로 살아서 안전 원에 복귀했고, 외곽 피해가 사라져 순회복 +0.73 HP/초로 전환됐다. 브라우저 오류·경고 로그는 비었다. 각 층 수치와 다양한 적 패턴은 모델 검사/상태 주입 캡처로 추가 검증했다.

증거: artifacts/current/build.log, *-render(-small).log, release-render.log, release-status.txt, web-validation.txt, release-hashes.json 및 PNG.

화면 검사는 테스트 저장 경로를 사용한다. 브라우저 플레이는 별도의 localhost 저장 영역이며 공개 사이트의 실제 플레이어 기록을 수정하지 않는다.

## 배포 식별

최신 Windows: build/current/OrbitBreaker.exe (116053520 bytes). SHA-256: F670C4CF121D45A13FD802FE1A54D00574D14B04A3207365E3BB682236A5BCE5.

직전 3.3: build/previous/OrbitBreaker.exe. SHA-256: 61B16382FAACD6E3AFAA4985E8D1407F8D2BCF4002598D9B44441411BEF53A7E. 이전 체크섬·안내·대응 검증 자료를 artifacts/previous와 함께 보존했다. 이동 전후 실행 파일 해시는 동일하다.

최신 웹 index.pck SHA-256: FC6DD5747980CC8229F3512A3C625E4513CD6A9B6EA7FCD7EB3CBBAE2C88B3DE. web/은 build/current/web/의 게시용 복사본이며 별도 세대가 아니다. 검사·두 플랫폼 내보내기·실제 실행·브라우저 확인 후 역할을 갱신했다.

## 공개 배포

- 웹: https://libralightluda.github.io/orbit-breaker/?v=3.4
- Windows: https://github.com/LibraLightLuda/orbit-breaker/releases/tag/v3.4.0
- 소스: https://github.com/LibraLightLuda/orbit-breaker

Pages 작업 https://github.com/LibraLightLuda/orbit-breaker/actions/runs/38106518968 가 completed/success로 완료됐다. 공개 웹 HTTP 200, index.pck SHA-256 FC6DD5747980CC8229F3512A3C625E4513CD6A9B6EA7FCD7EB3CBBAE2C88B3DE가 로컬 최신본과 일치한다. 공개 Chromium에서 로딩 후 VERSION 3.4 타이틀을 확인했고 경고·오류 로그는 비었다. 공개 사이트에서는 출격하지 않아 실제 기록을 변경하지 않았다.

Windows v3.4.0 업로드 digest F670C4CF121D45A13FD802FE1A54D00574D14B04A3207365E3BB682236A5BCE5가 로컬 최신 실행 파일과 일치한다. 직전 v3.3.0 digest도 로컬 직전본과 대조했다. 두 정상본 확인 후 v3.2.0 Release 및 첨부 파일을 정리해 GitHub 공개 Release는 v3.4.0/v3.3.0 두 세대만 남겼다. 과거 Git 소스 태그는 유지한다. 게임 소스/웹 커밋은 3ac27b2다.

공개 검증 증거: artifacts/current/public-verification.txt 및 web-validation.txt.

## 남은 한계

사람의 장기 재미·상위 난이도 밸런스, Safari/Firefox/모바일/다중 모니터는 미검증이다. 이전 랭킹 점수는 보존되므로 다른 버전 밸런스의 점수가 함께 표시된다. 고스트는 비행/위성 경로이며 적·탄막 전체 전투를 재현하지 않는다.

오래된 로컬 배포 자료 삭제는 이번 작업에서도 실행 도구의 자동 승인 검토에서 `blocked by policy`로 거부됐다. 상세 이유는 제공되지 않았다. 3.0은 build/retiring 및 artifacts/retiring, 3.1은 build/retiring-3.1 및 artifacts/retiring-3.1, 3.2는 build/retiring-3.2 및 artifacts/retiring-3.2에 삭제 대기로 남는다. 최신·직전 역할은 3.4/3.3이지만 두 세대 보관 정리는 미완료다. current/previous의 release-stdout.log·release-stderr.log, current/validation-progress.txt 임시 자료도 삭제가 거부돼 남는다. 우회 삭제나 무기한 별도 아카이브는 만들지 않았다. 게임 소스·과거 기획·플레이어 저장은 보호했다.
