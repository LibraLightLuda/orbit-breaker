# 온라인 운영

> 최신 후보·비공개 배포·검증 증거와 공개 조건은 [Sites 구현·검증 보고서](SITES_IMPLEMENTATION_REPORT.md)에 기록한다. 원본 공개 Site는 버전 2로 유지했으며 외부 서버를 만들지 않았다.

> 2026-10-17 운영 목표 변경: [Sites 중심 재검토](SITES_ARCHITECTURE_REVIEW.md)를 우선한다. 아래 Linux/Caddy/systemd·GitHub 배포 절차는 기존 구현의 참고이며 Sites 단독 경로의 선행 조건이 아니다. 실제 Sites 전투 지원·자산 전달·영속 작업·복구를 검증한 뒤 운영 계약을 갱신한다. 현재 서비스 개통 상태를 변경한 것은 아니다.

익명 랭킹 Sites는 공개 배포했다: https://orbit-breaker-records.chrcra89.chatgpt.site . 프로젝트 ID는 `appgprj_6ad16bc1fe7c819185c816d7f37b2222`이며 `server/ranking/.openai/hosting.json`에 고정되어 있다. 공개 전투 서버는 아직 미배포다. 개발용 주소를 공개 서비스 주소로 안내하지 않는다.

## 운영 원칙

- GitHub Pages/Web와 Releases/Windows는 같은 통신·규칙 버전으로 배포한다. 호환되지 않는 클라이언트는 입장 전에 업데이트를 안내한다.
- 월 약 10만 원을 우선하고 실측한 경기 수만 입장시킨다. 진행 경기를 비용 때문에 강제 종료하지 않는다.
- Sites에는 익명 경기 게시/조회 API를 제공한다. ChatGPT 사용자 계정/토큰을 요구하지 않는다. 서버 업로드/운영자 권한은 별도 비밀로 보호하고 클라이언트에 넣지 않는다.
- 서버 완료 결과는 로컬 재전송 대기 자료에 먼저 기록하고 원격 확인 후 정리한다. 같은 경기 재전송은 동일 결과로 처리한다.
- Sites/D1 복구 권한과 실제 복원 검사를 확보한다. 일일 7개/주간 4개 암호화 백업을 독립 위치에 보관한다. RPO 24시간/RTO 4시간 목표를 실측한다.
- 신규 입장 중지 → 기존 경기 종료 대기 → 후보 검사/교체 → 공개 URL 확인 → 구버전 산출물 정리를 따른다. ARTIFACT_RETENTION.md의 최신 한 세대 규칙과 차단 잔여 기록을 따른다.

## 장애와 시즌

진행 중 전투 프로세스 장애는 중단으로 표시한다. 고스트는 완료 전 재생하지 않으며 업로드 실패가 완료 점수를 지우지 않는다. 시즌은 한국 시간 월 단위로 시작 시 배정한다. 익명 게시판 v1에서는 완료한 과거 시즌 기록의 뒤늦은 공개도 허용한다. 확정 시즌 스냅샷·보상은 도입하지 않았다. 규칙이 다른 점수는 합치지 않는다.

실제 서비스 자격 증명/호스트 접근이 없는 경우 구현 가능한 로컬 작업을 계속하고 공개 운영은 미검증으로 표시한다. 실물 휴대폰·Safari/iOS·사람 협동 검증을 자동 검사로 대체하지 않는다.

## 로컬 실행과 공개 호스트

Node 24 이상과 Godot 4.7.1이 필요하다. 프로젝트 루트에서 `node server/gateway.mjs`로 개발 API(127.0.0.1:8788)를 실행한다. Windows 클라이언트는 ORBIT_API_URL 환경 변수, 로컬 웹은 127.0.0.1/localhost 개발 주소로 연결한다. 공개 클라이언트는 online_config.gd의 API_URL을 실제 HTTPS 주소로 구성한 후 빌드한다.

Linux 호스트에는 프로젝트 서버 코드와 Godot 실행 환경을 설치하고 전용 orbit-breaker 사용자·/var/lib/orbit-breaker 데이터 디렉터리를 준비한다. server/.env.example을 바탕으로 /etc/orbit-breaker.env를 작성하며 소유자만 읽도록 권한을 설정한다. ORBIT_GODOT·ORBIT_PUBLIC_URL·ORBIT_ALLOWED_ORIGINS·검증된 ORBIT_MAX_ROOMS를 실제 환경에 맞춘다. Caddyfile과 orbit-breaker.service를 사용하며 HTTP/WSS는 443번 외부 연결만 사용한다. 테스트용 ORBIT_MATCH_SCRIPT는 외부 바인딩과 Sites 연결 환경에서 거부된다.

`build/candidate/server/`는 Linux 전용 실행 파일과 Node 런타임 코드의 배포 후보다. ORBIT_GODOT은 이 디렉터리의 `OrbitBreakerServer.x86_64` 절대 경로로 지정한다. Godot 4.7 기본 내보내기에서는 `--script` 등 경로 덮어쓰기 옵션이 비활성화될 수 있으므로 전용 서버 feature의 `OrbitMatchServer` main loop와 빈 서버 장면으로 자체 시작한다. `tools/test_dedicated_boot.ps1`는 내보낸 전용 PCK를 `--script` 없이 부팅해 READY와 무오류 종료를 검사한다. 이 검사는 Windows 에디터 런타임에서 수행하며 Linux 실행 자체를 대신하지 않는다. [Godot 명령행 문서](https://docs.godotengine.org/en/latest/tutorials/editor/command_line_tutorial.html)의 extended 옵션 제한과 실제 4.7.1 내보내기 help를 함께 확인했다.

암호화 DB 백업은 ORBIT_BACKUP_KEY를 안전하게 설정하고 `node server/backup.mjs backup <records.sqlite> <새 백업 파일>`로 만든다. 복원은 별도의 비어 있는 경로에 `restore <백업 파일> <새 records.sqlite>`를 실행해 무결성을 검사한다. 실행 중 서비스 DB를 덮어쓰지 않는다. 키 분실 시 백업을 복구할 수 없다. 클라우드 D1의 별도 복원 검사와 R2 보존 작업은 공개 운영 검사에 포함한다.

## 이번 구현의 실행 방법

사용자 요청에 따른 서버/배포 식별자는 `luda-orbit-breaker`로 정한다. 이 이름 자체가 등록된 인터넷 도메인이나 실제 SSH 호스트를 의미하지 않는다. 사용할 호스팅 계정/실제 서버가 연결되면 해당 업체의 발급 주소 또는 사용자가 소유한 도메인을 확정해 `ORBIT_PUBLIC_URL`, Caddy의 도메인 환경 값, 클라이언트 `OnlineConfig.API_URL`에 반영한다. 기존 익명 랭킹 Sites의 실제 주소와 프로젝트 ID는 유지한다.

Windows에서 `powershell -ExecutionPolicy Bypass -File tools/start_online_local.ps1 -OpenGame`으로 개발 전투 서버와 후보 게임을 실행한다. 서버 콘솔을 유지하고 웹은 http://127.0.0.1:8788/game/ 로 연다. 이 주소는 같은 컴퓨터에서만 유효하다. 프로젝트의 실제 서버 코드를 실행하며 공개 인터넷 멀티플레이 주소가 아니다.

성능 비교의 재현 자료는 `artifacts/online-work/perf-comparison/run-comparison.ps1`과 `performance-comparison.json`이다. 비교용 변경 전/후 코드, 공통 의존 자료와 원래 검사에서 분리한600프레임 측정 구간을 보존한다. `prepare-fix.ps1`은 채택하지 않은 진단용 임시 스크립트이며 최종 측정/배포에 사용하지 않는다. 실제 수정은 공격력의 프레임당 재사용이고 고스트 식별자 추적 방식은 그대로 유지했다.

비교 검사를 마친 뒤 다음 임시 자료의 정리를 시도했으나 자동 승인 검토가 실행 전에 `blocked by policy`로 거부했다. 기존 Sites 캐시 차단과 별도이며 이 경로들을 다른 도구로 다시 삭제하지 않았다: `artifacts/online-work/perf-comparison/baseline/assets`, `baseline/.godot`, `current/assets`, `current/.godot`, `prepare-fix.ps1`(뒤4개는 같은 `perf-comparison/` 기준). 실제 게임의 `assets/`와 플레이어 저장 데이터는 대상이 아니었다. 앞서 차단된 Sites 캐시4개와 과거15개 차단 경로에 관한 기록도 유지한다. 이 잔여 자료를 정리 완료로 표시하지 않는다.

Sites 원본은 `server/ranking/`이다. 수정할 때 이 원본을 격리된 Sites 체크아웃에 복사하여 설치·빌드·푸시·버전 저장·배포한다. Sites 플러그인의 원본 저장소 자격 증명은 만료되는 작업용이며 클라이언트에 전달하거나 파일에 저장하지 않는다. `server/.env`는 Git에서 제외한 서버 설정이며 기록 서버 서명/백업 키를 포함한다. 키를 문서·클라이언트·릴리즈에 넣지 않는다.

실제 Sites API 검사는 `node --env-file-if-exists=server/.env tools/verify_online_site.mjs`다. 공개 점수를 생성하지 않고 익명 접근·CORS·위조 차단·실제 D1/R2 왕복을 확인한다.

클라우드 메타데이터 백업은 `node --env-file-if-exists=server/.env server/backup_cloud.mjs backup <새 파일.enc>`다. 복원은 `restore <파일.enc>`로 수행하며 기존 경기 ID와 결과 해시가 충돌하면 기존 자료를 보존하고 실패한다. 이 도구는 공개 게시 이름과 게시 여부도 복구한다. 백업은 AES-256-GCM, 일관된 SQLite 스냅샷, 기존 파일 덮어쓰기 금지를 사용한다. R2 고스트 바이트를 별도로 백업하지 않으므로 R2 손실 시 점수는 복구해도 고스트 재생은 불가능할 수 있다.

점검할 때 서버에서 운영 키를 `X-Orbit-Key` 헤더에 넣어 로컬 `POST /internal/drain`을 호출한다. 신규 경기만 막고 기존 방은 유지한다. 프로세스 종료 신호도 같은 방식으로 시작하며 기본 600초를 기다린다. systemd는 main 프로세스에 먼저 종료 신호를 보내며 660초 뒤까지 기다린다. 강제 종료된 진행 경기는 공식 결과를 만들지 않는다.

고스트 일반 자료는 7일, 보드별 상위20은 시즌 종료 후90일이다. 점수는 삭제하지 않는다. 로컬 고스트 10GiB 상한과 2방 제한은 시작값이며 50명 수용량이 검증됐다는 의미가 아니다. API·정적 게임을 위해 비밀 환경·서버 내부 경로를 외부에 노출하지 않는다.

공개 HTTPS 주소로 시작할 때 ORBIT_INTERNAL_KEY는 필수다. Caddy 직결 구성을 사용하고 ORBIT_TRUST_PROXY=loopback을 설정한다. Caddy는 X-Orbit-Client-IP를 실제 접속 주소로 덮어쓰며 Node는 loopback에서 온 유효 IP만 요청 제한에 사용한다. 다른 프록시/CDN을 추가할 때 실제 방문자 주소와 신뢰 경계를 다시 검사한다. 방 생성은 주소별 분당6회, 일반 HTTP는 분당240회다. 대규모 공격 방어와 수용량은 원격 운영 검사 대상이다.

## 외부 환경 때문에 아직 필요한 작업

2026-10-16에 사용자가 호스팅 계정이 없다고 확인했다. 최초 배포안은 `luda-orbit-breaker` 이름의 AWS Lightsail 서울·Linux x86_64·Compute Optimized 2vCPU/4GB(기본 월US$42, 부대 비용 별도)다. 실제 서버/도메인 생성과 결제는 아직 수행하지 않았다. 사용자 가입 단계와 이후 배포 순서는 [ONLINE_HOSTING_SETUP.md](ONLINE_HOSTING_SETUP.md)를 따른다. 이 결정은 게임 소스나 기존 검증 후보를 변경하지 않는다.

- 실제 Linux SSH 접속 및 HTTPS/WSS 도메인. 클라이언트의 공개 API 주소는 이 값이 확정된 뒤 넣는다.
- 독립 백업 위치·스케줄·일일7/주간4 정리와 복구 시간 실측. 현재 로컬의 암호화 검증 백업은 운영 자동 백업이 아니다.
- 세 실제 클라이언트 조합 완주, 원격 지연/수용량, 12h 실행, 실물 휴대폰·Safari/iOS·사람 협동 검증.
- 최종 후보 검증 후 GitHub Pages/Release 교체와 공개 해시 확인. 기존 공개 게임은 연결 업데이트 전 상태를 유지한다.

보관 정책상 최종 공개 승격이 끝난 뒤 `artifacts/online-work`의 설치 캐시·임시 체크아웃·임시 패키지를 정리한다. 진행 중 후보와 실제 검증 자료를 완료 배포본으로 표시하지 않는다. 이전에 삭제 차단된 15개 경로는 재시도하지 않는다.

이번 작업의 `artifacts/online-work/site/node_modules`, `.next`, `.wrangler`, `.sites-runtime` 캐시 제거는 자동 승인 검토에서 `blocked by policy`로 실행 전 거부됐다. 원본/최신 Site 패키지와 함께 해당 캐시도 남아 있다. 다른 삭제 방법으로 우회하지 않았다.
