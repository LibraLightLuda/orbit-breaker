# Orbit Breaker — Sites 중심 아키텍처 재검토

> 후속 실제 구현과 검증 상태: [Sites 구현·검증 보고서](SITES_IMPLEMENTATION_REPORT.md). 이 문서는 당시 설계 판단과 검증 게이트를 보존한다.

검토일: **2026-10-17 KST**. 범위: 설계·기술 타당성, 기존 코드/감사 대조, 읽기 전용 원격 확인, 제한된 로컬 재현. 이 문서는 배포 완료 보고서가 아니다.

## 1. 최상위 요구와 결정

**게임 클라이언트와 온라인 서비스를 ChatGPT Sites 안에서 운영하는 것을 최우선 목표로 한다.** GitHub는 소스 관리에 사용할 수 있다. GitHub Pages/Release 배포와 외부 Linux 서버를 필수 구성으로 삼았던 이전 계획은 이 목표보다 우선하지 않는다. AWS Lightsail 준비안은 참고 자료로만 남기며 가입·리소스 생성·과금·도메인 확보를 다음 작업의 전제로 삼지 않는다.

여기서 Sites 단독 운영은 사용자가 별도 Cloudflare/AWS 계정이나 상주 서버를 운영하지 않고, Sites가 제공·관리하는 런타임과 D1/R2로 이용자 서비스를 제공한다는 뜻이다. Sites 내부가 Cloudflare 기반이라는 사실은 별도 인프라 도입으로 세지 않는다. 반대로 별도 Workers/DO 계정, TURN, 외부 전투 호스트, 켜 둔 개발 PC는 외부 의존성이다. 소스 관리와 다운로드형 독립 백업은 서비스의 실시간 실행 의존성과 구분한다.

현재 결론은 다음과 같다.

1. **기존 Godot 웹게임, 랭킹, 고스트의 배포·조회·저장을 Sites에 모으는 방향을 채택한다.** 기존 Sites 프로젝트와 D1/R2, Godot 내보내기 및 클라이언트를 재사용한다. 대용량 자산 배포와 데이터 이전은 아래 게이트를 통과해야 한다.
2. **현재 Linux 전투 서버를 그대로 Sites에서 실행하는 방식은 지원된 배포 계약과 맞지 않는다.** 방마다 네이티브 Godot 프로세스와 TCP 리스너를 띄우는 부분을 파일 복사나 URL 변경으로 이전할 수 없다.
3. **서버 권위 공식 솔로·2인 협동의 Sites 단독 운영은 아직 입증되지 않았다.** WebSocket 지원은 확인했지만, Sites가 방의 단일 실행 주체를 제공하는지와 기존 전투 모델을 그 런타임에서 실행할 수 있는지는 별개다. 불가능을 일반화하지도, 가능을 약속하지도 않는다.
4. 방 조정 기능과 전투 모델 실행을 먼저 작은 실증으로 판별한다. 통과한 경우에만 전투의 Sites 이전을 진행한다. 실패하거나 공식 지원을 확인하지 못하면 전투 개통을 보류하고 선택지를 제시한다. **외부 서버 도입이나 클라이언트 권위 전환은 자동 후속 조치가 아니다.**

게임 규칙은 [SURVIVAL_V3.md](SURVIVAL_V3.md), 실제 배포 결과는 [VALIDATION_V3.md](VALIDATION_V3.md), 배포 자료 보관은 [ARTIFACT_RETENTION.md](ARTIFACT_RETENTION.md)를 계속 따른다. 익명 경기 게시판, 공식 결과의 서버 권위, 웹/Windows 호환, 기존 개인 저장·고스트 판독을 유지한다. 호스팅 변경을 계정 도입이나 게임 재작성의 근거로 삼지 않는다.

## 2. 확인한 현재 구현과 증거

| 구성 | 실제 코드/자료 | 판단 |
|---|---|---|
| Godot 클라이언트 | `scripts/main.gd`, `online_client.gd`, `online_config.gd`, `online_menu.gd`, `online_motion.gd`, `online_replay.gd` | 웹/Windows 공통 구현을 보존. 공개 `API_URL`은 아직 빈 값 |
| 공유 전투 | `scripts/online_world.gd` 365줄, `run_model.gd` 1,934줄, GameContent 의존성 | 기존 모델을 호출하는 구조. 작은 이동 함수만 옮기면 전체 전투가 이전되는 구조가 아님 |
| 전투 호스트 | `server/gateway.mjs:104` 부근, `server/match_server.gd` | 방마다 `spawn(godot, ...)`, loopback TCP, 60Hz 모델, 20Hz 상태, 5Hz 고스트, 2초 청크 |
| 영속화 | `server/store.mjs`, `schema.sql`, `contract.mjs`, `backup*.mjs` | 로컬 SQLite/파일 outbox와 Sites 미러를 함께 사용. 파일 기반 전송·복구 책임을 재설계해야 함 |
| 기존 Sites | `server/ranking/.openai/hosting.json`, `app/[...path]/route.ts`, `db/schema.ts`, `drizzle/` | Vinext/Worker + D1 `DB` + R2 `BUCKET`. 새 랭킹 프로젝트를 만들 이유 없음 |
| 독립 감사 | [ONLINE_INDEPENDENT_AUDIT.md](ONLINE_INDEPENDENT_AUDIT.md), [수정 계획](ONLINE_REMEDIATION_PLAN.md), `docs/audits/online-20261016/` | F1~F7, G1~G3를 유지. 호스팅 변경으로 감사 통과가 되지 않음 |
| 후보/정상 배포 | [ONLINE_VALIDATION.md](ONLINE_VALIDATION.md), [VALIDATION_V3.md](VALIDATION_V3.md) | 온라인 후보와 정상 로컬 clarity 세대, 과거 GitHub 공개본을 구분 |

이번에 직접 확인한 내용:

- Sites 관리 도구: 기존 프로젝트 `appgprj_6ad16bc1fe7c819185c816d7f37b2222`, active/public, 저장 버전 2. [현재 랭킹 Sites](https://orbit-breaker-records.chrcra89.chatgpt.site).
- 로그인 없는 `GET /v1/config`와 `GET /v1/rankings`: 각각 HTTP 200. 기본 순위 응답은 `items: []`. 특정 보드가 비어 있다는 사실을 전체 D1/R2가 비었다는 증거로 해석하지 않는다.
- 해당 Sites 자신의 Origin을 보낸 `GET /v1/config`: HTTP 403, `origin not allowed`. 소스의 허용 목록에도 Sites 자체 주소가 없다. 같은 출처 GET은 Origin 헤더를 생략할 수 있으므로 모든 GET이 실패한다고 단정하지 않는다. Origin이 붙는 POST와 향후 WebSocket까지 반드시 다시 검사한다.
- 기존 `repro-model.gd`를 Godot 4.7.1로 실행, exit 0. **결함이 없다는 통과가 아니라 결함 재현 성공**이다. F1: true 입력 다음 false 입력에서 dash/overdrive가 false로 덮임. F7: dash 잔여 0.01초가 0.2초로 복원되고 위치 차이 28.8800048828125px. leave 후 재시도 타이머 29.5초/0.8초 잔류도 관찰.
- 현재 `web/index.wasm`과 온라인 후보 WASM은 각각 39,513,091 bytes, 약 37.68MiB. `web/index.pck`는 19,395,368 bytes, 후보 PCK는 19,442,628 bytes. 정상본과 후보를 혼합하지 않는다.
- WASM의 로컬 모듈 분석은 성공했으며 함수 import 337개가 있다. 이것은 Node에서 모듈 구조를 읽은 결과다. Workers에서 Godot를 실행했다는 증거가 아니다. 웹 로더에는 브라우저 그래픽/저장 의존성이 있다. `variant/thread_support=false`는 현재 웹 내보내기 설정이다.
- 현재 `server/ranking/node_modules`는 없다. 이번에 설치·빌드·사이트 재배포를 수행하지 않았다.

기존 감사의 F2~F6 장애 실험과 전체 검사 수치는 해당 감사의 증거로 사용했다. 이번에 그 전체 실험이나 D1/R2 쓰기·삭제를 재실행했다고 주장하지 않는다. Linux 서버, 원격 전투, 12시간 부하, 실물 기기 및 사람 2인 완주는 여전히 별도 검증 대상이다.

## 3. 공식 지원, 기반 플랫폼 기능, 미확인의 경계

| 항목 | 근거와 상태 | 설계에 반영할 내용 |
|---|---|---|
| 웹 앱·게임·호환 기존 프로젝트 호스팅 | [Sites 공식 안내](https://learn.chatgpt.com/docs/sites?surface=web)에서 확인 | Godot 웹 내보내기를 먼저 활용. React 게임으로 재작성하지 않음 |
| HTTP/HTTPS/WebSocket | 같은 공식 문서에서 명시적으로 지원 | WSS 후보를 유지. 전송 지원과 방 상태 공유를 별개로 검증 |
| raw inbound/outbound TCP | 같은 문서에서 미지원 | 현재 TCP 포트 개방/프록시와 네이티브 서버 구성을 그대로 이전하지 않음 |
| D1/R2 | [공식 데이터 안내](https://learn.chatgpt.com/docs/sites/data-and-connections), 설치된 Sites 저장소 계약, 현재 바인딩에서 확인 | D1은 경기/순위/전송 상태, R2는 고스트·큰 자산. D1 사이트당 10GB, R2 고정 저장 한도 없음은 무료·무제한 요청/트래픽을 뜻하지 않음 |
| Worker 런타임 | 설치된 Sites 1.0.1 스킬은 Cloudflare Workers, isolate당 128MB와 HTTP 기반 외부 연결을 명시. 배포 계약은 Worker 엔트리 또는 정적 출력 | Linux ELF, systemd, OS 프로세스 실행 환경으로 간주하지 않음. Node 호환 표시는 완전한 Node/OS 호환이 아님 |
| Durable Objects 또는 동등한 방 조정 기능 | Cloudflare에는 [여러 WebSocket 사용자를 한 객체에서 조정하는 기능](https://developers.cloudflare.com/durable-objects/best-practices/websockets/)이 있음. **이번에 확인한 Sites 공식 안내/manifest/도구에서는 DO 생성·binding·migration 지원 계약을 확보하지 못함** | Cloudflare 기능을 Sites 제공 기능으로 치환하지 않음. manifest에 임의 필드를 쓰고 지원됐다고 판정하지 않음 |
| 서버측 WASM | [Cloudflare 공식 WASM 안내](https://developers.cloudflare.com/workers/runtime-apis/webassembly/)는 지원을 설명하지만 Worker 스레딩은 미지원, WASI는 실험적 | Godot 웹 WASM을 그대로 전투 Worker로 쓸 수 있다는 근거가 아님. Sites 번들·모듈 허용과 headless 모델 실행을 따로 실증 |
| 자산/메모리/CPU 제한 | [Cloudflare Workers 한도](https://developers.cloudflare.com/workers/platform/limits/)에서 static 단일 파일 25MiB, isolate 메모리 128MB 확인 | Sites 계정의 실제 정책을 별도 확인. 37.68MiB WASM을 일반 static 경로에 무검증 투입하지 않음. 브라우저 메모리에는 Worker 128MB를 적용하지 않음 |
| 영속 스케줄·백업·요청 제한 | 설치된 Sites 스킬에 연결된 예약 작업 경로는 있으나 현재 사이트의 linked automations는 빈 배열 | 예약 작업 존재와 무인 실행 성공을 구분. cron/Queue/DO alarm/WAF/rate-limit binding은 별도 지원 확인 없이 전제하지 않음 |

Cloudflare 공식 일반 한도·기능은 기반 기술의 참고 근거이지 이 Sites 프로젝트의 과금제·리전·CPU 예산·DO 사용 권한 보증이 아니다. 특히 예전 Workers 번들 한도나 무료 플랜 수치를 Sites에 그대로 적용하지 않는다. 한국 지연, 동시 50명, 월 약 10만원은 측정 전 약속하지 않는다. Sites의 저장·공유·로그인 기능을 위해 OpenAI 모델 API나 새 API 키가 필요한 설계도 아니다.

확인한 설치 계약: [Sites 스킬](C:/Users/home/.codex/plugins/cache/openai-curated-remote/sites/1.0.1/skills/sites/SKILL.md), [저장소](C:/Users/home/.codex/plugins/cache/openai-curated-remote/sites/1.0.1/skills/sites/references/storage.md), [예약 업데이트](C:/Users/home/.codex/plugins/cache/openai-curated-remote/sites/1.0.1/skills/sites/references/recurring-updates.md). 웹 문서와 설치된 계약, 현 프로젝트에서 실제 실행한 범위를 분리한다.

## 4. 채택할 Sites 중심 구조

**하나의 기존 Sites 주소를 이용자 진입점과 영속 데이터의 기준점으로 사용한다.**

| 경로/역할 | 권장 구성 | 현재 구현 재사용 |
|---|---|---|
| `/game/` | Godot HTML/JS/WASM/PCK. 지원 정적 출력 + 큰 파일의 동일 출처 R2 스트리밍 | 기존 내보내기와 로더, 아트·오디오·게임·UI |
| `/` 또는 `/rankings` | 기존 랭킹 화면, 게임으로 이동 | 기존 `app/page.tsx` |
| `/v1/config` | protocol/rules 및 실제 사용 가능한 기능 표시 | 기존 route 확장. 전투 실증 전 방 생성 기능을 활성화하지 않음 |
| `/v1/rankings`, `/v1/runs/:id` | D1에서 일관된 순위/완료 결과/고스트 상태 조회 | 기존 schema, 필터, 동점·시즌 규칙. 경기 상세 GET 추가 |
| `/v1/replays/:id/...` | D1 완료 상태 확인 후 R2에서 검증된 청크 제공 | 기존 route/manifest/해시·크기 검사/관전기 |
| `/v1/rooms`, `/play/:code` | 실증을 통과한 Sites 방 조정 + 권위 전투 실행 | HTTP/WS 메시지 의미와 GDScript 클라이언트 유지. 현재 미확정 경계 |
| 결과 확정/고스트 완료/정리 | 신뢰된 서버 실행 경로에서 D1/R2로 처리 | 멱등 저장·서명·검증 개념 재사용. OS 파일 outbox를 영속 작업 상태로 대체 |
| Windows 배포 | 필요하면 동일 Sites에서 최신 검증 실행 파일/ZIP/체크섬 다운로드 | Godot Windows 빌드 보존. 큰 파일 R2 응답과 다운로드 검증 필요 |

기존 Sites ID와 D1/R2 바인딩 이름을 유지한다. 기존 프레임워크를 유지하는 편이 작은 변경이다. 설치된 간이 Worker ESM starter는 정적 외부 자산을 그대로 복사하는 구성이 아니므로 대형 Godot 배포의 무수정 대안으로 선택하지 않는다.

### 게임 파일과 데이터의 이전

- 먼저 Sites가 실제로 처리하는 단일 파일/전체 archive 한도를 확인한다. 지원 경로에서 기존 WASM을 그대로 전달할 수 있으면 그 경로를 쓴다. 일반 static 제한에 걸리면 **기존 Sites R2에 원본 바이트를 넣고 Worker가 같은 URL 체계로 스트리밍**한다. R2 전체 파일을 `arrayBuffer()`로 읽어 메모리에 올리는 방법은 피한다.
- 배포 세대/내용 해시가 있는 자산 키와 검증된 파일 목록을 사용한다. HTML/JS/WASM/PCK가 다른 세대를 섞지 않도록 동일 세트로 전환한다. WASM은 `application/wasm`, JS는 올바른 MIME, 고스트 gzip은 기존 클라이언트가 직접 해제하므로 `application/octet-stream` 및 원본 압축 바이트/해시 계약을 유지한다.
- 큰 게임 파일을 기존 `/internal/replays`에 올리지 않는다. 이 경로는 고스트용 1MiB 제한과 이름 규칙이 있다. 정식 자산 업로드 경로를 먼저 확인하고, 없다면 서버 권한으로 제한한 별도 자산 적재 경로를 설계·검증한다. 일반 방문자 업로드 경로로 만들지 않는다.
- 브라우저의 API 기본 주소는 배포된 게임과 같은 Sites origin으로, Windows는 명시적인 Sites HTTPS 주소로 설정한다. 자체 Origin·허용된 이전 Origin·Origin 없는 네이티브 요청을 구분하고 실제 POST/OPTIONS/WSS를 검사한다. CORS를 인증 또는 점수 신뢰 경계로 사용하지 않는다.
- GitHub Pages에서 Sites로 주소가 바뀌면 브라우저 개인 저장소가 자동 이동하지 않는다. `SaveStore`의 `user://profile/records_v2.json`, 설정, 로컬 고스트에 대해 구 출처에서 내보내기 → 신 출처에서 검증 후 가져오기 절차를 준비한다. 기존 저장 형식을 바꾸거나 구 데이터를 지우지 않는다. 원본 접근이 필요한 이전 절차가 끝나기 전에 이전 게임 진입점을 닫지 않는다.
- 기존 D1 데이터·ID·rules·season·result_hash와 구형 고스트 판독을 유지한다. 기본 순위가 비어 있다는 이유로 DB를 초기화하지 않는다. 신규 열은 추가형 migration으로, 적용된 migration은 수정하지 않는다. **실패한 배포도 migration을 이미 적용했을 수 있으므로** 코드 롤백만으로 DB까지 되돌아갔다고 가정하지 않는다.

### 전투 서버 역할의 대체 가능성

| 기존 역할 | Sites에서 가능한 대체 방향 | 필수 조건 |
|---|---|---|
| HTTPS API/로비 설정/버전 거부 | Worker route | 방 생성 rate limit·짧은 수명의 참가/resume 권한·입장 상한 |
| 여러 연결이 같은 방을 소유 | Sites가 실제 제공하는 DO 또는 동등한 단일 방 실행 주체 | 별도 계정 없이 binding/수명주기/재배포 지원 확인 |
| `RunModel`/`OnlineWorld`의 60Hz 판정 | 엔진/모델을 재사용한 Worker 호환 실행 모듈을 먼저 실험 | 브라우저 DOM/그래픽/OS 호출 없이 동일 규칙 실행, 메모리·CPU·시간 제약 충족 |
| 파일 기록/outbox/재시도 | D1의 불변 결과와 작업 상태, R2의 제한된 청크 | 중간 종료 이후 재개, 멱등성, 누락/고아 정리, 실제 실행 가능한 재시도 트리거 |
| 완료 후 결과/고스트 조회 | Sites D1/R2를 직접 기준으로 사용 | 방 메모리/프로세스가 없어져도 조회 가능 |
| 유지보수/백업 | 검증된 Sites 예약 작업 + 제한된 운영 API/암호화 export | 닫힌 사이트에서도 실제 실행 확인. 같은 Site의 R2 복사만으로 독립 재해 백업을 주장하지 않음 |

모든 방을 일반 Worker의 전역 `Map`에 저장하는 설계는 채택하지 않는다. 서로 다른 요청/연결이 같은 isolate에 간다는 보장이 없고 재배포·회수로 상태가 사라질 수 있다. D1/R2의 존재도 60Hz 전투의 단일 실행 주체를 자동으로 제공하지 않는다.

DO는 유력한 검증 후보이지 미리 정한 필수 구현 기술이 아니다. 다른 공식 지원 방식이 동일한 단일 소유·순서·복구 계약을 충족하면 비교한다. D1에 매 입력을 저장하고 polling하는 방식은 별도 비교 실험이 가능하지만 기본안으로 삼지 않는다. 2인×60Hz 입력만으로 한 방에 시간당 최대 432,000개 논리 입력이며, 20Hz 상태 방송·쿼리·고스트 비용은 별도다. 이 숫자는 Sites 과금 단위가 아닌 프로토콜 산술이다.

기존 Godot headless 실행 파일은 Linux 프로세스용이고 웹 WASM도 브라우저용이다. WASM 확장자만으로 서버 실행 호환을 보장하지 않는다. 모델 전용 빌드/엔진 어댑터로 GDScript를 재사용할 수 있는지 먼저 확인한다. 이 방법이 실패하면 TypeScript 등으로 모델 전체를 포팅하는 것은 약 2,300줄의 핵심 모델 외 콘텐츠·RNG·재생·경계 사례까지 동치 검사가 필요한 별도 큰 작업이다. 전투 일부를 흉내 낸 데모를 기존 게임 이전 성공으로 인정하지 않는다.

## 5. 최소 기술 실증과 통과/중단 기준

아래는 **앞으로 실행할 검증 계획**이다. 현재 공개 Sites에는 새 경로·데이터·WS 방을 배포하지 않았다. 실제 Sites의 binding·업그레이드·수명주기를 검증하려면 서버 코드를 배포해야 한다. 로컬 Wrangler/Miniflare 성공은 이 단계의 대체 증거가 아니다. 기존 public 사이트의 audience를 변경하지 않고, 격리된 검증 경로/데이터를 쓸지 별도 비공개 검증 Site를 쓸지는 구현 시작 때 정한다. 별도 Site가 필요해도 운영용 ID를 교체하지 않는다.

| 게이트/우선순위 | 방법·남길 증거 | 성공 기준 | 실패/미확인 시 |
|---|---|---|---|
| S0 / P0: 지원 계약 | Sites 공식 문서·native 도구·번들 출력에서 자산, WS, 방 조정 binding/마이그레이션, CPU/메모리/과금·무인 작업 지원 확인 | 사용할 기능의 정식 경로와 실제 계정 권한 확인. 모호한 설정이 배포 중 조용히 제거되지 않음 | DO/동등 기능 지원이 불명확하면 공유 전투 구현에 착수하지 않고 지원 확인 항목으로 남김. 부재를 영구 불가능으로 단정하지 않음 |
| S1 / P0: 기존 게임 호스팅 | 후보의 실제 37.68MiB WASM/PCK 세트로 static 또는 R2 스트리밍. cold/warm 로딩·재로드·실패 복구, 전체 파일 SHA/MIME/길이·캐시 검증 | 원본 바이트 일치, 실제 출격·전투·강화·소리·저장/복귀. 기존 성능 대비 p95 퇴행≤10% 목표. 웹 클라이언트가 GitHub/외부 asset 주소에 의존하지 않음 | 자산 경로를 조정. Sites 자산 전달이 끝내 불가하면 전체 게임 호스팅 완료로 표시하지 않음 |
| S2 / P0: WSS와 방 소유 | 2개 독립 브라우저/네트워크 + 네이티브 클라이언트로 동일 방 연결. 다른 방 격리, reconnect, 동시 join, idle/wake, 재배포/강제 재시작 | 2클라이언트가 같은 authoritative 방 sequence 관찰, 최대 2명, 타 방 누출 0, 중복 입장/오래된 resume 차단. 회수 시 명시적 복구 또는 안전 중단 | 단순 echo 성공만으로 합격 금지. 지원된 공유 상태가 없거나 split brain 발생하면 서버 권위 전투 경로 중단 |
| S3 / P0: 기존 전투 모델 실행 | 엔진/모델 재사용 모듈을 실제 지원 런타임에서 실행. 동일 seed·입력·선택 trace를 기존 headless와 대조 | score/ticks/피해/선택/적 생성·사망/구조/최종 작전 결과 일치. 부동소수 허용오차는 사전 정의하고 판정 차이는 0. 고정 60Hz, 브라우저/OS 호출 없음 | 메모리·CPU·모듈 제약 또는 동치 실패 시 포팅 규모/대안을 보고. 자동으로 게임을 새로 만들지 않음 |
| S4 / P1: 결과·고스트 저장 | 점수→pending ghost→청크→complete 각 단계에서 D1/R2 실패·누락·손상·중복·실행 종료 주입. 다른 실행 주체에서 조회 | 유효 점수 정확히 1건. 다른 결과 409. 점수는 고스트 실패와 독립. complete는 모든 청크 크기/해시 검증 후만. expired/failed/pending 표시 일치 | F4/F5/F6와 저장 계약 수정 전 게시/관전 개통 보류 |
| S5 / P1: 입력·예측·복구 | F1/F2/F3/F7 재현을 올바른 기대값의 회귀 검사로 전환. 메뉴/포커스 이동, 300ms input 중지+ping, 지터, 결과 유실/재시작 | 버튼 정확히 1회, 250ms input 만료 후 중립, 입력 적용 ACK, 정확한 dash 잔여·방향, 결과 복구/이력 중복 0 | 기존 버그를 새 런타임에 복제한 구현은 합격 불가 |
| S6 / P2: 실제 전투·수용량 | 웹↔웹, Windows EXE↔EXE, 웹↔EXE. 2방부터 최대 밀도·기록 포함 12h, 네트워크 장애와 실물 기기 | RTT80ms/지터20ms/손실1%에서 입력 p95≤150ms, 보정 p95≤13px/p99≤52px. RTT200ms/손실3%에서 경고·복구·안전 중단. 틱 지연 누적/자원 초과 0, 클라이언트 기존 p95 퇴행≤10% | 측정된 입장 상한만 허용. 50명으로 올리지 않음. CPU/메모리의 실제 Sites 한도가 불명확하면 운영 승인 보류 |
| S7 / P2: 운영/복구 | 닫힌 사이트의 예약 작업, rate limit/입장 차단, 운영자 숨김, pending/orphan 정리, 비어 있지 않은 백업 복원 | F6 정상/미전송 데이터 손실 0, 점수 RPO24h/RTO4h 실측, 고스트 복구 범위 별도 명시, 비밀 비노출, 사용량 계측과 운영 예산 충족 | 자동 일정 등록만으로 성공 처리 금지. 독립 백업이 없으면 해당 복구 목표 미달로 표시 |
| S8 / P3: 배포 이전 | 소스·protocol·rules·자산 manifest를 고정해 후보 검사, 실제 Sites URL/Windows 다운로드 hash와 3조합 확인, 저장 이전 | 기존 프로필/구형 replay 호환, 새 세대의 검증 증거 대응, 정상본 보존 후 전환, 구배포 정리 상태 명시 | 실패 후보로 current/기존 공개본을 교체하거나 삭제하지 않음 |

S2와 S3는 둘 다 통과해야 한다. 전투 tick 중에는 idle hibernation 절약을 가정하지 않는다. HTTP/WS 생존 시간, CPU 실행 예산, 벽시계 시간은 각각 측정한다. 기존 Linux의 CPU 여유30%/메모리70% 기준을 Worker 전체 호스트 사용률로 옮겨 적지 않고, 실제 노출된 isolate/실행 예산과 틱 시간에 맞춰 여유를 계측한다. 30초 재접속/250ms 입력 만료 같은 게임 계약은 별도로 유지한다.

S3의 비교 trace는 난수 상태·순서·시간·입력 seq를 포함한다. 기존 5Hz 시각 고스트는 입력 로그도 완전한 시뮬레이션 checkpoint도 아니므로 모델 동치나 서버 재시작 복구를 그것만으로 검증하지 않는다. 최초 버전에서는 실행 주체 장애 시 안전 중단을 유지해도 되며, 완료 결과는 반드시 복구 가능해야 한다.

각 실증은 소스 commit 또는 변경본 해시, Sites version/deployment, protocol/rules, seed/input fixture, 클라이언트 조합, 측정 원시값, 실패 이유를 남긴다. 정식 지원 부재·계정 제한·예산 초과·게임 동치 실패를 서로 다른 판정으로 기록한다.

## 6. 감사 결함 7개와 새 아키텍처의 관계

| 결함 | Sites 이전의 영향 | 수정/의존성 및 종료 조건 |
|---|---|---|
| F1 P1 버튼 입력 유실 | 런타임 교체로 사라지지 않음. 현 코드 재현 | 최신 이동과 미소비 버튼/aim 분리, action ID와 실제 적용 ACK. S3의 모델 어댑터 계약 전에 고정하고 S5에서 중복·순서 검사 |
| F2 P1 heartbeat가 이동 갱신 | WS를 지원해도 그대로 발생 | 연결 heartbeat와 마지막 유효 input 시간을 분리. 서버 250ms 중립화 + 화면 이탈 중립 입력. S5 |
| F3 P1 종료 결과 복구 누락 | Worker 재시작/배포로 더 중요 | ended result 재송신 + D1 `/v1/runs/:id` 복구, 만료 있는 resume, 기기 이력/게시 멱등. S4→S5 |
| F4 P1 고스트 장애가 점수 차단 | 로컬 outbox 제거만으로 해결되지 않음 | 불변 결과와 가변 ghost 상태/청크 작업 분리. `result_hash` 새 계약은 version을 두고 기존 hash 보존. D1 확정 뒤 R2 상태 전이. S4 |
| F5 P1 전역 조회 단절 | 단일 Sites 기준 저장소로 구조적 해결 가능 | 순위·경기·manifest·청크 모두 D1/R2 기준. 방 메모리·로컬 DB 없이 동일 run 조회 회귀 필수. S4 |
| F6 P1 고아 고스트 용량 누적 | 디스크 고아가 R2 미완료 객체/영속 작업 고아로 바뀔 수 있음 | active/pending/complete/failed/orphan 구분, 유예·소유/버전 검사·용량 예산, 경합 안전 정리. 활성/미전송/정상 자료 보호. S4→S7 |
| F7 P2 돌진 예측 오차 | 공통 클라이언트를 유지하므로 남음. 현 코드 재현 | live state에 정확한 dash 잔여/방향·처리 ACK. 구형 시각 고스트는 보존. S3 계약→S5→S6 |

F1~F3/F7은 호스트 선택과 무관한 공통 프로토콜/클라이언트 수정이다. F4~F6은 **Sites를 기준 저장소로 정한 뒤** 수정해 폐기할 로컬 파일 큐에 과도하게 투자하지 않는다. 기존 Linux 경로를 비교 기준으로 남기는 동안 필요한 데이터 보존 수정은 유지한다.

G1은 실제 Sites 전투와 세 클라이언트 조합 검사로 바뀐다. G2는 Sites CPU/메모리·요청·WS·R2 트래픽/비용 실측 및 공개 API 남용 방어로 바뀐다. G3는 데이터가 있는 D1 복구와 독립 백업·R2 복구 범위 확인으로 유지한다. 기존 Linux/Caddy 실행 검사는 Sites 단독 경로의 필수 조건에서 제외한다. 외부 호스트 대안을 나중에 승인한 경우에만 다시 필요하다.

이전 시 추가로 확인한 항목은 F1~F7에 번호를 덧붙여 감사 결과를 바꾸지 않고 **이전 위험**으로 관리한다: 자체 Origin 403, 25MiB 일반 static 한도 대비 큰 WASM, 출처 변경에 따른 개인 저장 이전, 규칙/자산 세대 혼합, 제공되지 않은 DO/cron 기능을 가정하는 위험.

## 7. 우선순위별 구현 순서와 범위

| 단계 | 작업과 결과물 | 선행/완료 조건 |
|---|---|---|
| P0-A | S0 기능·한도 표 확정, 기존 Sites와 소스 연결 확인. 정상본과 온라인 후보 manifest 구분 | 새 서버·계정 생성 없이 시작. 지원 미확인은 명시 |
| P0-B | S1 자산 경로 + 자체 Origin/주소 설정의 격리 실증 | 실제 Godot 후보 로딩 확인. 이 단계는 전투 개통 성공과 구분 |
| P0-C | S2 방 조정과 S3 모델 재사용 실증 | 지원된 최소 방/최소 모델부터 시작. 두 게이트가 통과해야 완전한 Sites 전투 구현 결정 |
| P1-A | F1/F2/F3/F7 공통 계약 수정과 회귀, live state/ACK/protocol 버전 확정 | 기존 headless를 비교 기준으로 사용. 구형 클라이언트는 안전한 버전 거부, 구형 저장/고스트는 판독 |
| P1-B | F4/F5/F6 저장 상태 분리, 경기 상세 GET, Sites 우선 조회, 추가형 DB migration | P0-A 및 불변 result/hash 계약. S4 통과. old data/backups 호환 |
| P1-C | P0-C 통과 시에만 Sites 전투 실행·방 입장·완료 경로 연결 | 기존 Godot 게임/자산/UI 유지. 전체 모델 동치·S5 통과 |
| P2 | 운영자 최소 통제, 실제 무인 재시도·retention, 백업/복구, 비용·입장 제한, S6/S7 | 새 관측 플랫폼은 불필요. 네이티브/모바일/사람 검증과 합성 검사 구분 |
| P3 | S8 후보→검증→실제 URL 확인→서비스 전환→최신 한 세대 정리, 문서/다운로드 갱신 | 원본 저장 이전 경로 확보, 새 정상본 입증 전 구본 삭제 금지 |

먼저 고칠 파일 범위는 `online_config.gd`, `online_client.gd`, `main.gd`, `online_motion.gd`, 필요 live snapshot 필드, `server/ranking/app/[...path]/route.ts`, `db/schema.ts`/추가 migration, `contract.mjs`의 결과/해시 계약과 대응 테스트다. 후속 영향을 받는 곳은 `online_replay.gd`, `save_store.gd`, 백업 도구, `tools/build.ps1`/웹 shell/배포 manifest, 운영·검증 문서다. 기존 테스트/fixture는 새 의미에 맞게 보완하며 결함을 assert하는 감사 스크립트를 제품 통과 검사로 그대로 쓰지 않는다.

보존할 것: 기존 Godot 전투/표현/UI/아트/오디오, 웹·Windows 클라이언트, 개인 저장과 구형 ghost 판독, 익명 게시 규칙, Sites 프로젝트와 데이터, 기존 감사 원문·과거 설계. 다시 사용할 것: 입력/선택/구조/결과 메시지 계약, SQL·순위 필터·멱등성 테스트·replay fixture·백업 형식. 바뀔 것: OS 프로세스/포트/파일 큐 역할, 서비스 주소/Origin/자산 전달, 서버 실행 환경에 맞춘 영속 작업·운영 절차.

별도 프레임워크 교체, 계정/자동 매칭/과금/새 관측 서비스, 전체 클라이언트 재작성은 이번 목표에 필요하지 않다. 더 작은 중간 단계는 **Sites에서 기존 게임 실행 + 랭킹/고스트 조회·저장 기반을 먼저 완료하고 신규 공식 경기 접수는 비활성으로 두는 것**이다. 이는 최종 2인 협동 목표의 대체 완료가 아니라 선택 가능한 중간 공개 범위다.

## 8. Sites 단독 전투가 성립하지 않을 때

| 선택지 | 유지되는 것 | 제한과 승인 대상 |
|---|---|---|
| Sites만 유지, 전투 개통 보류 | 게임 클라이언트·로컬 플레이·기존 검증 결과의 랭킹/고스트 | 외부 의존성 0. 새 서버 권위 공식 솔로/협동은 제공하지 못함. 축소 공개 범위로만 표시 |
| Sites + 최소 전투 실행 서비스 하나 | 클라이언트/사이트/API·D1/R2는 Sites, 기존 headless 모델 재사용 | Sites 내부 실행 불가가 확인된 책임만 밖으로 분리. 최소 세션/복구용 저장 필요량도 산정. 특정 업체/Lightsail을 자동 선정하지 않으며 사용자 승인 전 생성/연결 금지 |
| Sites 중심의 사용자 호스트 협동 | 기존 Godot 모델을 사용자 기기에서 실행할 가능성 | 호스트 신뢰·이탈·백그라운드·NAT 문제. 기존 서버 권위 공식 랭킹과 동등하지 않음. WebRTC는 signaling만으로 완결되지 않으며 TURN 등 외부 의존성이 필요할 수 있음. 제품 규칙 변경 승인 필요 |

브라우저가 계산한 결과에 서버 서명을 덧붙이거나, 두 참가자가 같은 점수를 보냈다는 이유만으로 공식 결과로 인정하지 않는다. 5Hz 고스트를 받아 형식/해시만 확인하는 것도 권위 검증이 아니다. 사후 재시뮬레이션 대안은 신뢰된 런타임의 전체 모델 실행·완전한 입력 로그·비용 검증이 필요하므로 현재 실행 문제를 자동 해결하지 않는다.

## 9. 배포·보관·인계 기준

이번 작업은 문서 변경만 수행하며 게임 소스·빌드·실제 Sites·데이터·권한을 변경하지 않는다. 향후 배포도 정상 실행 파일/체크섬/안내/대응 증거 보존 → 후보 필수 검사·export·실행 → Sites 실제 검증 및 전환 → 이전 배포/대응 검증/임시 백업 정리 순서다. 같은 버전명이어도 해시가 다르면 새 세대다.

Sites/R2의 버전 자산에도 한 세대 정책을 적용한다. 단, 전환 검증 중에는 이전 정상 세트가 필요하며 성공 후 제거한다. Sites 플랫폼 자체 저장 버전의 개별 삭제 기능이나 데이터와 코드 버전의 관계가 미확인이면 정리 가능 범위를 먼저 확인한다. 삭제 불가능한 플랫폼 이력은 남은 항목/이유로 기록하고, 이를 숨기기 위해 Site 자체나 플레이어 데이터를 삭제하지 않는다. 독립 백업·플레이어 데이터·과거 설계 문서는 배포 산출물 정리 대상이 아니다.

최종 구현 인계에는 S0~S8의 실제 상태, 수정한 F번호, 공식 문서와 계정 지원 근거, source/build/deployment 해시, 실제 운영 상한, 원격/GUI/실물/사람 검사 범위, 비용·복구 결과, 남은 제한을 기록한다. **현재의 설계 타당성 검토를 Sites 전투 구현 완료 또는 전체 온라인 출시 승인으로 사용하지 않는다.**
