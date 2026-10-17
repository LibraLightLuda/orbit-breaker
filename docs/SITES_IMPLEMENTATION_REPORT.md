# Orbit Breaker — Sites 통합 구현·검증 결과

2026-10-17 KST. 기준은 `SITES_ARCHITECTURE_REVIEW.md`와 2026-10-16 독립 감사다. 기존 미커밋 변경 위에 필요한 수정을 추가했다. 기존 정상 `build/current`, `artifacts/current`, `web/` 및 공개 운영 Site를 승격·삭제·덮어쓰기하지 않았다.

## 판정

**7개 감사 결함을 수정하고 회귀 검사를 추가했다. Sites 비공개 검증 환경에서 Godot 웹게임, D1/R2, 랭킹·고스트 저장/조회, WSS 왕복을 실행했다. Sites 내부의 서버 권위 전투·2인 협동 개통은 미완료다.**

기존 Godot 전투 모델·표현·아트·오디오와 고스트 v1 판독을 재사용했다. 게임을 다른 엔진으로 다시 만들지 않았다. 실시간 통신 protocol은 2로 올렸으며 구형 클라이언트는 안전하게 버전 불일치로 거부한다. 기존 기록·시즌 rules·온라인 고스트 version 1은 유지한다.

현재 결과는 공개 승인 전의 구현/검증 후보다. 외부 사용자가 전체 서비스를 이용할 수 있는 공개 출시 완료로 표시하지 않는다.

## 수정 결과

| 감사 | 수정 | 회귀 근거 |
|---|---|---|
| F1 버튼 유실 | 최신 이동과 미소비 dash/overdrive를 분리. 버튼 시점 aim과 seq를 유지하고 틱에서 한 번 소비. ACK는 소비한 입력 기준 | Godot `test_online_regressions.gd`: true→false, 역방향 aim, 중복 seq, 버튼별 한 번 소비 |
| F2 오래된 이동 | 마지막 검증 입력 시각을 heartbeat와 분리. 250ms 후 중립. 메뉴·포커스 이탈에도 중립 전송 | 같은 회귀의 300ms 만료. 실제 서버 통신 회귀 및 브라우저 협동 이동 |
| F3 완료 복구 | ended 재접속에 완료 결과 재송신. 경기 ID로 HTTP 복구. 만료 있는 기기 세션, 재접속 seq 복원, leave 타이머 초기화 | 실제 Godot 서버에 종료 후 resume, HTTP 결과 200. 기기 기록은 기존 ID 중복 제거 경로 사용 |
| F4 점수 차단 | 결과를 먼저 D1에 멱등 저장하고 고스트 pending/complete/failed를 별도 갱신. 누락/손상 로컬 파일은 failed로 종료, 일시 원격 장애는 재시도 | Node 장애 회귀: 청크가 없어도 점수 보존. Sites 완료 전 청크 크기·SHA 검사. 가변 고스트 상태는 새 결과 해시에서 제외 |
| F5 전역 조회 단절 | 경기 상세·manifest·청크도 Sites 우선. 명시적인 장애 캐시 대안 유지 | 로컬 DB가 빈 gateway에서 다른 Sites 경기 조회 200. 실제 비공개 D1/R2 경기·고스트 조회 |
| F6 고아 파일 | 활성 방·미전송 결과를 보호하고 오래된 orphan/failed 디렉터리 회수. 진행 방의 고스트 예산 예약. R2 정리도 orphan/failed를 구분 | 작은 용량 경계의 오래된 고아 회수. 활성 자산 세대 삭제 거부·이전 자산 세대 정리 회귀 |
| F7 돌진 예측 | 시각 고스트와 별도로 live dash 잔여시간·방향을 전달/복원 | 0.01초 상태 복원 후 원본 모델과 위치 차이 <0.001px. 구형 시각 고스트 형식은 유지 |

구형 로컬 결과/백업의 hash를 일괄 재작성하지 않는다. 중복 결과는 불변 경기 필드를 비교하고 과거 저장 hash를 유지한다. Sites는 기존 결과의 hash를 반환해 후속 고스트 갱신이 같은 레코드에 연결되게 한다. 점수·난이도·시간 등 다른 결과는 409로 거부한다.

## Sites 통합

- 원본 운영 Site: `appgprj_6ad16bc1fe7c819185c816d7f37b2222`, public/active, 버전 2 유지. 원본 `.openai/hosting.json` ID를 바꾸지 않았다.
- 별도 비공개 검증 Site: `appgprj_6ad30c6c16a08191829d78ec1f3c777d`.
- 주소: [비공개 검증 Site](https://orbit-breaker-sites-validation.chrcra89.chatgpt.site). 소유자 전용 비공개 배포이며 공개 운영이 아니다.
- 서버 코드 저장 버전 4, 소스 `eb98dfc57a438f415bb0ed3b85923d83ce0b74b1`, 배포 `appgdep_6ad31253edd48191aad081d5b54681ac`, native 결과 succeeded.
- 지원된 Sites source helper로 소스를 저장/푸시하고 tar를 생성한 뒤 버전 저장과 비공개 배포를 각각 실행했다. Windows 포장 도구의 bash 검색·tar 드라이브 문자 문제는 실행 환경의 PATH/TAR_OPTIONS로 해결했다. 원본 plugin 파일은 수정하지 않았다.

기존 Vinext route의 실제 처리를 `server/ranking/lib/records.mjs`로 공유해 로컬 회귀와 Worker가 같은 코드를 실행한다. D1/R2 바인딩과 SQL 스키마를 유지했으며 파괴적 migration은 없다. 기존 프레임워크 build 소스의 누락을 복구하고 루트 ignore 규칙을 수정해 이 소스가 보존되게 했다. `.gdignore`로 Sites 의존성이 Godot 게임 import에 섞이지 않게 했다.

큰 파일은 R2에 1MiB 파트로 적재하고 manifest를 검증한 뒤 current를 전환한다. Worker는 backpressure를 유지하며 원본 파일을 연속 스트림으로 전달한다. 37.68MiB WASM을 일반 static 단일 파일 제한에 의존해 배포하지 않는다. 비밀키와 Sites 서비스 접근 토큰은 서버/세션 메모리에서만 사용하며 게임·소스·보고서에 넣지 않았다.

실제 실행에서 발견해 추가 수정한 호환성 문제:

1. `/game/`이 프레임워크에서 `/game`으로 정규화돼 로더의 상대 경로가 깨졌다. Worker가 게임 경로를 먼저 처리하고 `/game`을 `/game/`으로 안내하도록 수정했다.
2. 자체 Sites Origin을 거부하던 정책을 수정했다. CORS를 점수 인증으로 사용하지 않는다.
3. Sites가 압축한 JSON을 브라우저 fetch가 해제한 뒤 Godot HTTPRequest가 다시 해제해 `stream_peer_gzip.cpp`/JSON 오류가 발생했다. 웹의 세 HTTPRequest에서 자동 gzip 해제를 끄고, 고스트의 명시적인 gzip 검증/해제는 유지했다.
4. Sites 응답 HTML은 관리 스크립트 삽입으로 원본 hash와 달라진다. Godot bootstrap 포함을 별도 확인하고, JS/WASM/PCK/이미지/worklet의 원본 바이트는 각각 SHA로 비교한다. HTML까지 원본과 동일하다고 표시하지 않는다.
5. 비공개 자동 검증은 Sites 서비스 접근 헤더를 사용했다. 초기 오디오 worklet 401은 브라우저 컨텍스트에도 비공개 접근을 적용한 후 해소됐다. 이는 공개 플레이어에게 토큰을 배포하는 구현이 아니다.

## 실제 검사와 증거

주요 작업 증거는 `artifacts/sites-work/`에 있다. 최종 출처/빌드 상태는 아래 최종 검사 절을 따른다.

| 검사 | 확인 범위 | 한계 |
|---|---|---|
| Node 회귀 9개 | 실제 Godot WS, 종료 복구, 결과·고스트 장애 분리, 빈 캐시 조회, 고아 정리, 구형 hash, 자산 파트/활성 세대 보호, 백업 | GUI·실물 기기 증거와 구분 |
| Godot 신규 회귀 10개 | F1/F2/F7 및 재접속 타이머 | 원격 지연 p95 측정이 아님 |
| 온라인 UI 560개 | 기존 화면·터치 영역 회귀 | 실제 휴대폰 터치가 아님 |
| Chrome 155.0.8059.82 + Edge 155.0.4283.45 | 실제 Godot 클라이언트로 동일 방 참가·준비·두 기체 표시·이동. 같은 서버 tick 1786까지 수신, 총 3111 state 관찰 | 로컬 권위 서버를 사용. 서로 다른 제품이지만 둘 다 Chromium 계열. 장시간 사람 완주 아님 |
| 두 브라우저 완료 fixture | 실제 Godot 서버의 2초 축소 경기에서 동일 ID/점수/120틱 결과 수신 | 브라우저의 합성 WS 클라이언트 검사. 실제 GUI 전체 경기 완주와 구분 |
| 실제 웹 완료 복구 | Chrome의 Godot 클라이언트에서 첫 result 프레임만 차단한 뒤 새로고침. 저장된 세션으로 같은 서버 결과를 다시 받아 완료 화면 표시 | 2초 fixture. 30초 재접속 계약 안의 복구이며 장시간 서비스 장애 복구를 보장하지 않음 |
| 실제 Sites 저장소 | D1/R2 쓰기·읽기·삭제 probe, 서버 생성 경기의 등록·조회, 고스트 완료·다운로드 SHA 일치 | 비공개 검증 데이터. 원본 공개 DB에 테스트 점수를 게시하지 않음 |
| 실제 Sites WSS | TLS WebSocket echo 왕복 성공 | 공유 방·권위 전투 실행 성공을 뜻하지 않음 |
| 실제 Sites 게임 | 타이틀·출격 준비·싱글플레이 이동/돌진 렌더 | 실물 모바일 성능·사람 오디오 수용은 별도 |
| 실제 Sites 랭킹 화면 | Edge의 사이트 화면 및 Chrome의 Godot 클라이언트에서 협동/폭풍 보드를 선택해 검증 편대의 기록 표시 | 검증 데이터 보드이며 사람 단위 계정 랭킹이 아님 |
| 실제 Godot 고스트 관전 | Sites manifest/청크를 받아 관전기로 재생. 압축 수정 후 브라우저/엔진 오류 0 | 2초 서버 생성 fixture의 관전. 긴 경기의 사람 관전 품질 검증과 구분 |

주요 파일: `node-tests-final.log`, `regressions-final.log`, `online-ui-final.log`, `full-build-final.log`, `sites-verification-final.json`, `sites-browser-final.json`, `browser-local.json`, `browser-fixture.json`, `browser-result-recovery.json`, `browser-result-recovery.png`, `chrome-coop.png`, `edge-coop.png`, `sites-title.png`, `sites-singleplay.png`, `sites-edge-ranking.png`, `sites-godot-ranking-final.png`, `sites-godot-ghost-final.png`. 최초 실패/수정 전 증거도 같은 작업 디렉터리에 남겨 원인과 재검사를 구분한다.

검증된 R2 이전 자산 세대 `e47596f3…`, `803b49db…`, `f79364d3…`의 파트 64개씩, 총 192개를 회수했다. 현재 게임 자산 세대는 `3e2a520ff15e875eb7d92c956a2f6815025876046394bc165007b6401adb4695`이며 최종 후보 PCK와 일치한다. 현재 세대 삭제는 관리 API에서 거부한다. 회귀의 재접속 파일 경로는 별도의 테스트 경로를 사용해 사용자 세션을 삭제하지 않는다.

## 남은 기술적 제약과 공개 조건

실제 런타임은 WebSocket=true, DOM=false, 공유 방 binding=false를 반환했다. 생성된 Worker 설정의 Durable Object bindings/migrations도 비어 있다. 확인한 Sites 계약에는 DO/동등한 방 실행 주체를 프로비저닝하는 지원 경로가 없으며, 현재 네이티브 Godot 프로세스를 실행할 OS 환경도 없다. **Sites 전체가 영구적으로 협동을 지원할 수 없다는 일반 결론이 아니라, 현재 제공된 기능으로 기존 권위 전투를 이전하는 경로를 확보하지 못했다는 판정**이다.

`RunModel`/`OnlineWorld` 전체를 다른 언어로 재작성하거나 사용자가 판정하는 협동으로 바꾸지 않았다. Sites가 전투 미제공을 명시하면 공식 도전/협동 생성 버튼을 비활성화하고 랭킹·고스트를 이용할 수 있게 한다. 외부 AWS/Workers/TURN/개발 PC 상시 운영을 배포 대안으로 연결하지 않았다.

공개 승인 전 추가 조건은 권위 전투의 지원된 실행 경로, 원격 세 클라이언트 조합·네트워크 품질·12h 수용량/비용, 운영 API 남용 방어와 운영자 통제, 비어 있지 않은 독립 백업 복원, 실물 기기/사람 검증이다. 기존 브라우저 출처의 개인 기록이 Sites로 자동 이전되는 것은 아니며 가져오기 절차도 공개 전 별도 완료해야 한다.

R2 게임 자산은 새 세대 검증 후 HMAC 관리 경로로 이전 세대만 정리하며 현재 세대는 삭제를 거부한다. Sites 플랫폼 자체 저장 버전의 개별 삭제 도구는 현재 제공되지 않는다. 그 이력은 이유를 명시해 남기며 Site 전체나 플레이어 데이터를 삭제하지 않는다. 정상 배포본의 최신 한 세대 원칙을 피하기 위한 별도 아카이브는 만들지 않았다.

## 최종 검사 상태

압축 수정 후 실제 Sites Godot 클라이언트에서 협동/폭풍 랭킹의 검증 기록 표시 → manifest/청크 다운로드 → 2초 고스트 관전까지 성공했다. 최종 후보 PCK를 배포한 뒤 같은 경로를 다시 실행했고 엔진/JSON/브라우저 오류 0개를 확인했다. 이 검사는 `sites-godot-ranking-final.png`, `sites-godot-ghost-final.png`, `sites-browser-final.json`에 대응한다. 자동 입력 후에는 화면 전경 상태와 실제 렌더를 확인해 단순 네트워크 요청 성공을 관전 성공으로 대체하지 않았다.

최종 원격 자산 9개 중 HTML을 제외한 8개는 후보 원본과 바이트 단위 SHA가 일치한다. HTML은 Sites 관리 스크립트 삽입을 확인했으며 Godot bootstrap을 별도로 검사했다. D1/R2 probe, WSS echo, 서버 생성 점수 21의 경기·고스트 완료 및 다운로드 해시 검사가 최종 배포에서도 통과했다. 랭킹 화면 관전에는 별도의 협동 검증 기록(점수 0, 120틱)을 사용했다.

**최종 전체 빌드 exit 0.** 웹 HTTP 압축 수정과 테스트 세션 파일 격리를 고정한 소스로 필수 검사·렌더·Windows/Web/Linux export·메인 장면 실행·소스 일치 확인을 완료했다. Python 17개, Node 9개, 신규 Godot 회귀 10개, 온라인 UI 560개, 밸런스 111개, 시작 전 UI 107,400개 assertion 등이 통과했다. 시작 전 수치는 반복 레이아웃 검사를 포함하며 서로 다른 107,400개 사용자 시나리오라는 뜻이 아니다.

`build/candidate/candidate-validation.json`의 소스 **849개**, 출력 **21개**, 총 **870개** SHA를 실제 파일로 다시 대조해 불일치 **0개**를 확인했다. `artifacts/sites-work/candidate-summary.json`과 `site-proof.json`이 대응 요약이다. candidate의 complete는 고정 소스 빌드 완료이며 전체 온라인 서비스 출시 승인과 구분한다.

- Windows EXE SHA-256: `12892C534DE0AD0D08C1C0F61DE0C25A448A9D47A9FCE4A598988681A5F4BC81`
- Web PCK SHA-256: `77157B975113E8FF7339A30F98D56F36D4140A93EA4CC18A6EC5B40490657F73`
- 기존 정상 EXE `1363DFF5…` 및 `web/index.pck` `24F2E97F…`는 이전 검증본과 일치한다. current 승격·공개 전환은 하지 않았다.

최초 전체 실행은 검사·내보내기 후 소스 inventory 변경을 검출해 승인하지 않았다. 중간 실행들은 브라우저에서 발견한 수정과 테스트 격리를 반영하기 위해 중단했으며 assertion 실패나 모델 불안정으로 분류하지 않는다. 최종 고정 실행의 결과만 위 후보 승인 근거로 사용한다. 원격 12h·물리 기기·사람 2인 완주·실제 Windows GUI 3조합은 미완료다.
