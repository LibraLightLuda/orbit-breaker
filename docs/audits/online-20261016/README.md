# 감사 증거와 재현

이 폴더는 2026-10-16 독립 감사 문서의 부록이다. 제품 구현이나 별도 배포 세대가 아니다. 게임 실행 파일/개인 저장 데이터/비밀키를 복사하지 않았다.

- `original-design.md`, `approved-plan.md`: 이전 설계 대화의 원문. 사용자 후속 변경을 구분하는 근거.
- `baseline.json`, `implementation-preserved.json`: 감사 시작 파일 SHA-256과 기존 파일 변경 0 검사. 시작 시 이미 미커밋 변경이 존재했다.
- `candidate-hashes.json`: 이전 후보의 소스837/출력21 재계산. 실행/출시 승인으로 해석하지 않는다.
- `suite-results.json`, 개별 `.log`: 이번에 독립 재실행한 기존 검사. node6 + Godot13묶음 통과, online_soak만 150초 timeout.
- `network-results.json`: 입장 제한, 과도 입력 방어, 완료 재접속, orphan 용량, 원격 고스트 경로, 공개 read-only API.
- `failure-results.json`: 실제 서버 heartbeat-only 이동과 누락 고스트의 점수 업로드 차단.
- `model-findings.log`: 원본 handler 버튼 덮어쓰기, dash 시간/위치 오차, leave 타이머 관찰.
- `public-ranking.png`: 실제 공개 사이트의 협동 필터/빈 기록 화면.

실행 위치는 프로젝트 루트이며 Godot 경로는 설치 환경에 맞게 바꾼다. Node 24.14.0과 Godot 4.7.1로 실행했다.

```powershell
python docs/audits/online-20261016/run_suites.py
node docs/audits/online-20261016/repro-network.mjs
node docs/audits/online-20261016/repro-failures.mjs
& 'D:\Antigravity\GodotGameProject\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://docs/audits/online-20261016/repro-model.gd
```

주의: `run_suites.py`는 baseline을 다시 만든다. 원본 감사 증거를 보존하려면 재검사 결과를 다른 감사 폴더에 기록한다. Node 재현은 19881~19886/19891~19893 loopback 포트를 쓰고 고유 임시 DB를 생성한다. 테스트 비밀은 상수 `audit-only` 등으로 운영 키가 아니다. 띄운 gateway PID의 프로세스 트리만 종료한다. 공개 사이트에는 GET만 수행한다.

초기 실행에서 감사 도구의 cp949 출력 오류와 solo fixture의 존재하지 않는 upgrade 대기를 수정했다. 이는 제품 결함으로 집계하지 않았다. 144Hz 송신 합성 검사의 1008 종료도 정상 60Hz 물리 클라이언트 결함으로 집계하지 않는다. 입장 경쟁 결과 201/503/503은 제한 정상 동작의 증거다.

고아 파일 재현은 실제 10GiB를 채우지 않고 64bytes 임계값과 128bytes 잔여를 사용했다. 원격 고스트/업로드 장애는 로컬 가짜 Sites로 재현했다. 실제 클라우드 파일 손상, 운영 데이터 삭제, 외부 부하 공격은 수행하지 않았다.

재현 스크립트 일부는 결함의 현재 동작을 assert한다. 수정 후에는 기대 동작을 검사하는 정식 회귀 테스트로 전환해야 하며 이 로그를 수정 완료 증거로 재사용하지 않는다.
