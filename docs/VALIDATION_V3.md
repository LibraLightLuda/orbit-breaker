# ORBIT BREAKER 3.5 검증 기록

검증일: 2026-10-11 (한국 시간). Godot 4.7.1 stable. 게임 규칙은 SURVIVAL_V3.md를 따른다.

## 변경 범위

Windows 기본 창을 1280×720에서 1600×900으로 키웠다. 논리 화면 1280×720, 최소 창 960×540, 16:9 비율·창 크기 변경·F11 전체 화면은 유지한다.

전체 원형 전장을 반지름·지름 기준 3.4의 80%로 줄였다. 활동 반지름 약 611→489px, 외곽층 폭 각 180→144px, 전체 외곽 반지름 약 1151→921px다. 면적은 64%다. 일반 적과 강적의 생성 여유 거리도 같은 비율로 조정했다. 기체 크기·이동 속도·층별 피해·복귀 흐름의 상대 강도·적 생성 빈도는 유지해 위험 구역까지의 이동 거리가 짧아진다. 기존 로컬 랭킹·업적·설정·고스트 형식은 보존한다.

## 자동 검사

| 검사 | 통과 |
| --- | ---: |
| 기본 모델 | 35/35 |
| 생존·회복·환경 피해 | 185/185 |
| 확장 전투 | 68/68 |
| 기체 개성 | 40/40 |
| 원형 공간·층별 이동·침공·적 전술·스킬 충전 | 162/162 |
| 36조합 자동 플레이 | 111/111 |
| 저장·오디오 | 122/122 |
| UI | 61/61 |
| 진행·로컬 랭킹·고스트 | 42/42 |
| 합계 | **826/826** |

시드 7의 자동 조종 결과: 표준 9/9, 여유롭게 9/9, 베테랑 7/9, 대붕괴 6/9 돌파. 모든 조합에서 유한 상태와 10분 내 종료를 확인했다. 이는 한 시드의 회귀 검사이며 사람의 클리어 확률을 뜻하지 않는다.

원형 경계와 층별 연속 피해·복귀 흐름, 외곽 2층에서의 4초 이동/생존, 3층 깊은 곳에서 최대 정상 선체·재생으로 장기 체류 불가, 일반 적의 층별 생성과 강적 침공을 검사했다. 새 전술은 실제 좌표 이동으로 포위 선회·원거리 거리 유지/후퇴·예고 후 고정 방향 돌진·진로 차단을 확인했다. 스트라이커는 조준 충전/이동·돌진·피격 해제/자동포만 강화/기존 강화·오버드라이브와의 결합/일시정지/다른 기체와의 분리를 검사했다.

## 실제 표시·실행

1600×900 기본 창과 960×540에서 각각 UI 79/79, 진행·관전 46/46, 기체 43/43, 원형 공간·전술·창 크기 170/170을 확인했다. 합계 **676/676**, 캡처 **64장**. 큰 창 검사는 해상도 인수를 지정하지 않고 실행했고 DisplayServer.window_get_size()가 실제로 (1600,900)인지 검사했다. 작은 창에서도 실제 (960,540)을 확인했다. 축소된 활동영역·세 외곽층·위험 표시·기체 주변 스킬 게이지의 배치를 확인했다.

Windows 및 단일 스레드 Web Release 내보내기 성공. 최종 Windows 실행 파일을 실제 OpenGL에서 기본 창 크기로 180프레임 실행해 종료 코드 0, 스크립트/렌더 오류 없음 확인. 종료 시 기존 ObjectDB 객체 2개 누수 경고가 남으며 소스 실행에서도 같은 경고가 발생한다.

최종 웹 후보를 Chromium에서 실행해 VERSION 3.5, 기존 localhost 최고1,065/업적35점 보존, 축소된 원형 전장과 실제 이동을 확인했다. 키보드로 3초 이동 후 외곽 피해5.57HP/초와 복귀 화살표를 확인했고, 안쪽 돌진 귀환 후 외곽 손상이 사라져 순회복+0.75HP/초로 바뀌었다. 브라우저 오류·경고 로그는 비었다.

증거: artifacts/current/build.log, *-render(-small).log, release-render.log, release-status.txt, web-validation.txt, release-hashes.json 및 PNG.

화면 검사는 별도 테스트 저장 경로를 사용한다. 브라우저 플레이는 localhost 테스트 저장 영역을 사용한다.

## 배포 식별

최신 Windows: build/current/OrbitBreaker.exe (116053536 bytes). SHA-256: 3F4809C9D0F6365637C8EF3B8E1AF80C53AC80CAEA23B047A8FA8402277E8264.

직전 3.4: build/previous/OrbitBreaker.exe. SHA-256: F670C4CF121D45A13FD802FE1A54D00574D14B04A3207365E3BB682236A5BCE5. 이전 체크섬·안내·대응 검증 자료를 artifacts/previous와 함께 보존했고 이동 전후 해시가 동일하다.

최신 웹 index.pck SHA-256: DFF0DE40CED527D5EA33ED1CF0F3C19653D2126D0B36D4178448F33E1B6FC512. web/은 build/current/web/의 게시용 복사본이며 별도 세대가 아니다. 모든 필수 검사·내보내기·Windows 실행·브라우저 확인 후 역할을 갱신했다.

## 공개 배포

- 웹: https://libralightluda.github.io/orbit-breaker/?v=3.5
- Windows: https://github.com/LibraLightLuda/orbit-breaker/releases/tag/v3.5.0
- 소스: https://github.com/LibraLightLuda/orbit-breaker

Pages 작업 https://github.com/LibraLightLuda/orbit-breaker/actions/runs/38107544018 가 completed/success로 완료됐다. 공개 웹 HTTP200, index.pck SHA-256 DFF0DE40CED527D5EA33ED1CF0F3C19653D2126D0B36D4178448F33E1B6FC512가 로컬 최신본과 일치한다. 공개 Chromium에서 로딩 완료 후 VERSION3.5 타이틀, 오류·경고 로그 없음 확인. 공개 사이트에서는 출격하지 않아 실제 기록을 변경하지 않았다.

Windows v3.5.0 업로드 digest 3F4809C9D0F6365637C8EF3B8E1AF80C53AC80CAEA23B047A8FA8402277E8264가 로컬 최신 실행 파일과 일치한다. 직전 v3.4.0 digest도 로컬 직전본과 대조했다. 두 정상본 확인 뒤 v3.3.0 Release·첨부 파일을 제거해 공개 Release는 v3.5.0/v3.4.0 두 세대만 남겼다. 과거 소스 태그는 유지한다. 게임 소스/웹 커밋은 7dca472다.

공개 증거: artifacts/current/public-verification.txt 및 web-validation.txt.

## 남은 한계

사람의 장기 재미·상위 난이도 밸런스, Safari/Firefox/모바일/다중 모니터는 미검증이다. 이전 랭킹 점수는 보존되므로 다른 버전 밸런스의 점수가 함께 표시된다. 고스트는 비행/위성 경로이며 적·탄막 전체 전투를 재현하지 않는다.

오래된 로컬 배포 자료 삭제가 이번 작업에서도 실행 도구의 자동 승인 검토에서 `blocked by policy`로 거부됐다. 상세 사유는 제공되지 않았다. 3.0은 build/retiring 및 artifacts/retiring, 3.1·3.2·3.3은 각각 build/retiring-3.1·retiring-3.2·retiring-3.3 및 대응 artifacts 디렉터리에 삭제 대기로 남는다. 최신·직전 역할은 3.5/3.4지만 로컬 두 세대 보관 정리는 미완료다. current/previous의 release-stdout.log·release-stderr.log, previous/validation-progress.txt 임시 자료도 남는다. 우회 삭제나 무기한 별도 아카이브를 만들지 않았다. 소스·과거 기획·플레이어 저장은 보호한다.
