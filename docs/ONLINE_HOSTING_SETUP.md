# 첫 공개 게임 서버 준비

> 2026-10-17: **참고용 과거 준비안**으로 전환한다. 현재 목표는 [ChatGPT Sites 중심 운영](SITES_ARCHITECTURE_REVIEW.md)이다. 아래 AWS 가입·Lightsail 생성·도메인·GitHub 배포 절차는 현재 실행 계획에서 제외한다. Sites 단독 전투의 기술 실증 결과와 사용자 승인 없이 외부 서버를 도입하지 않는다.

2026-10-16 KST. 사용자는 호스팅 계정이 없다고 확인했다. 아래는 선정한 배포안이며, 아직 계정·유료 서버·도메인을 생성하거나 결제하지 않았다. 게임 구현/후보 검증 결과와 실제 공개 운영을 구분한다.

## 선정한 구성

| 항목 | 배포안 |
|---|---|
| 서비스 | AWS Lightsail |
| 우선 리전 | 서울 `ap-northeast-2` |
| 인스턴스 이름 | `luda-orbit-breaker` |
| 운영체제 | Ubuntu LTS, Linux x86_64; 실제 콘솔에서 지원하는 버전 확인 |
| 요금제 | Compute Optimized, 2vCPU·4GB RAM·160GB SSD, public IPv4 포함 |
| 기본요금 | 월 US$42; 세금·환율·백업·도메인·전송 초과 비용 별도 |
| 초기 입장 상한 | 2방(최대4명); 실제 원격 검사 결과에 따라 낮추며 50명 수용량을 가정하지 않음 |
| 실행 패키지 | `build/candidate/server/`의 Linux 전용 Godot + Node 서비스 |

AWS는 compute-optimized 구성을 지속적인 전용 CPU 성능이 필요한 게임 서버 등에 적합한 상품으로 설명한다. 이 프로젝트는 60Hz 전투 프로세스를 계속 실행하므로 해당 구성을 우선 선택했다. 서울 리전을 우선하되 실제 계정 콘솔에서 상품 가용성과 최종 요금을 확인한 뒤 생성한다. 일반형의 CPU 버스트 크레딧을 장시간 처리 능력으로 가정하지 않는다. 이는 현재 프로젝트와 공개 자료에 근거한 선정이며 실제 지연/수용량 승인을 대신하지 않는다. [전용 CPU 설명](https://aws.amazon.com/about-aws/whats-new/2026/04/lightsail-compute-optimized-instances/), [공식 요금](https://aws.amazon.com/lightsail/pricing/), [지원 리전](https://docs.aws.amazon.com/lightsail/latest/userguide/access-lightsail.html).

월10만원 예산은 환율·세금·추가 사용료까지 포함해 실제 청구 예상액으로 확인한다. 무료 크레딧/체험 자격은 가정하지 않는다. 유료 리소스 생성 전에 구성을 확인하며 아직 비용 발생 리소스는 만들지 않았다.

## 지금 사용자가 할 일

1. [AWS 공식 가입 화면](https://portal.aws.amazon.com/billing/signup)을 연다.
2. 본인 이메일, 연락처, 결제 정보와 본인 확인을 서비스 화면에서 직접 완료한다. 계정 표시 이름은 `Luda Orbit Breaker`로 사용할 수 있다.
3. 비밀번호·결제 정보·인증번호·비밀키를 채팅에 보내지 않는다. 가입 후에는 `AWS 가입 완료`라고 알려주면 된다. 이 단계에서 서버나 도메인을 직접 고를 필요는 없다.

AWS의 독립 계정 생성은 AWS CLI/API로 수행할 수 없으며 공식 가입 절차가 필요하다. 계정 가입 완료만으로 이 작업 환경에 서버 제어 권한이 생기는 것은 아니다. 이후 브라우저 로그인 또는 제한된 운영 접근을 별도로 연결한다. [공식 가입 절차](https://docs.aws.amazon.com/accounts/latest/reference/getting-started.html).

## 계정 연결 후 실행할 작업

1. 서울의 실제 상품 가용성·Linux x86_64·월 예상액을 확인해 인스턴스를 생성한다. 서버 이름 자체는 등록된 인터넷 주소가 아니다.
2. 고정 주소와 HTTPS용 실제 도메인을 확정한다. 등록 가능 여부·비용을 확인하기 전 특정 도메인을 확보한 것처럼 안내하지 않는다.
3. 기존 `orbit-breaker.service`와 `Caddyfile`을 사용해 Node 24, 전용 사용자, 영속 데이터 디렉터리, HTTPS/WSS와 제한된 SSH 접근을 구성한다. 게임 서버 내부 포트는 외부에 열지 않는다.
4. 기존 Sites 서명/백업 설정은 서버의 비공개 환경 파일로 연결한다. 클라이언트에는 공개 HTTPS 주소만 넣는다.
5. 실제 Linux 시작·웹/Windows 조합·고스트·장애/백업·12시간 부하 검사를 수행한다. 합격한 입장 상한만 운영한다.
6. 확정된 API 주소로 웹/Windows를 재빌드하고 필수 검사 후 GitHub Pages/Release를 승격한다. 공개 파일 해시와 실제 URL을 확인한 뒤 보관 정책을 적용한다.

상세 운영 계약은 [ONLINE_OPERATIONS.md](ONLINE_OPERATIONS.md), 현재 구현/검증 결과는 [ONLINE_VALIDATION.md](ONLINE_VALIDATION.md)를 따른다. 익명 랭킹 Sites와 게임 서버 호스팅용 AWS 계정은 별개다. 플레이어에게 AWS/ChatGPT 계정 로그인을 요구하지 않는다.
