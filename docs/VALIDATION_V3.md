# ORBIT BREAKER 3.3 검증 기록

검증일: 2026-10-11 (한국 시간). Godot 4.7.1 stable. 통합 게임 기획의 기준은 SURVIVAL_V3.md다.

## 배포 식별

최신 Windows: build/current/OrbitBreaker.exe (116054544 bytes). SHA-256: 61B16382FAACD6E3AFAA4985E8D1407F8D2BCF4002598D9B44441411BEF53A7E.

직전 3.2: build/previous/OrbitBreaker.exe. SHA-256: 70354E66D53A6137FE28C4D1A3A700ADF75FA607DD4A769AF23F5F9850564E02. 기존 체크섬·안내·대응 검증 자료를 함께 보존한다. 자료는 artifacts/current 및 artifacts/previous다. web/은 build/current/web/과 같은 세대의 게시용 복사본이다.

웹 index.pck SHA-256: 9CA558E4747E9A6578423F81AE0C61B8A52F2B3C97365CA2C0AD94CB48AB1F50.

## 자동 검사

| 검사 | 통과 |
| --- | ---: |
| 기본 모델 | 35/35 |
| 생존·회복·환경 피해 | 185/185 |
| 확장 전투 | 68/68 |
| 기체 개성 | 38/38 |
| 원형 활동영역·외곽층·침공 생성·스킬 충전 | 150/150 |
| 36조합 자동 플레이 | 111/111 |
| 저장·오디오 | 122/122 |
| UI | 61/61 |
| 진행·로컬 랭킹·고스트 | 42/42 |
| 합계 | **812/812** |

원형 면적이 원래 직사각형의 정확히 2배인지, 8방향의 안전 영역과 같은 간격의 세 층, 사각 포괄 범위 모서리의 위험 판정, 층별 피해·감속·복귀 흐름, 최대 정상 선체와 수리·무적으로도 3층에 체류하지 못하는지를 확인했다. 일반 적의 층별 생성, 강적의 3층 밖 생성/경고/느린 접근, 기체 근처 생성 회피, 원형 전장에 맞춘 폭발·전기 통로, 기체별 강화 적용 대시 충전과 강화 중 정지를 포함한다.

자동 조종도 이전 사각 경계의 강제 이동을 원형 복귀로 갱신했다. 여유롭게 9조합 모두, 표준 9조합 중 8조합이 돌파했다. 이는 한 시드의 회귀 검사 결과이며 사람의 클리어 가능성이나 장기 밸런스 평가가 아니다.

## 실제 표시·실행 확인

1280×720과 960×540 각각 UI 79/79, 진행·관전 46/46, 기체 41/41, 원형 궤도 156/156. 총 **644/644**, 캡처 **62장**이다. 상태 주입으로 층별 경계·피해 경고·복귀 화살표·강적 접근 방향/거리·항법도·50% 충전·준비 완료·효과 줄이기를 확인했다. 경계 이름이 기체와 겹치지 않도록 조정하고, 하단 충전 상태와 입력 설명을 구분한 후 해당 화면 검사를 반복했다.

Windows와 Web Release 내보내기 성공. 내장 데이터 Windows 실행 파일을 실제 OpenGL로 180프레임 실행하고 실제 프로세스 종료 코드 0 및 스크립트/렌더 오류 없음 확인. 종료 때 ObjectDB 객체 2개 누수 경고가 남으며 소스 검사에서도 간헐적으로 같은 경고가 발생한다.

Chromium에서 최종 3.3 후보의 타이틀과 원형 활동영역·항법도·스킬 패널을 확인했다. 기존 로컬 최고 205/업적 5점 보존 후 실제 키보드 Space와 이동으로 돌진 재충전 32%/2.0초, 오버드라이브 34% 표시를 관찰했다. 외곽 이동을 이어가 30초에 외곽 손상으로 종료하고 점수 1065·업적 35점 결과가 저장됐다. 해당 브라우저 경고/오류 로그는 비어 있었다. 강적 침공과 모든 층의 세부 상태는 자동 모델 및 네이티브 상태 주입 화면으로 검증했다.

증거: artifacts/current/build.log, ui/progression/ships/orbital-render(-small).log, release-render.log, release-status.txt, web-validation.txt 및 PNG. 플레이어의 실제 저장 경로는 테스트가 수정하지 않는다. 브라우저 조작은 테스트용 localhost 저장 영역이다.

## 공개 배포

- 웹: https://libralightluda.github.io/orbit-breaker/
- Windows 3.3: https://github.com/LibraLightLuda/orbit-breaker/releases/tag/v3.3.0
- 소스: https://github.com/LibraLightLuda/orbit-breaker

Pages 작업 https://github.com/LibraLightLuda/orbit-breaker/actions/runs/38104901866 가 completed/success로 완료됐다. 공개 웹 HTTP 200 및 index.pck SHA-256 9CA558E4747E9A6578423F81AE0C61B8A52F2B3C97365CA2C0AD94CB48AB1F50가 로컬 최신본과 일치한다. 실제 공개 Chromium에서 로딩 완료 뒤 VERSION 3.3 타이틀 표시 및 오류/경고 로그 없음 확인. Windows 업로드 digest 61B16382FAACD6E3AFAA4985E8D1407F8D2BCF4002598D9B44441411BEF53A7E 역시 로컬 최신 실행 파일과 일치한다. 게임 소스/웹 커밋은 cdd8a3f이다. GitHub 공개 Release는 최신 v3.3.0과 직전 v3.2.0만 유지하도록 v3.1.0 배포/첨부 파일을 정리했으며 Git의 과거 소스 태그는 유지했다.

## 한계와 정리 상태

실제 사람의 장기 밸런스·상위 난이도 평가, Safari/Firefox/모바일/다중 모니터는 미검증이다. 랭킹은 로컬이며 이전 점수를 초기화하지 않아 서로 다른 기체·공간 밸런스의 점수가 함께 표시된다. 고스트는 비행/위성 경로이며 적·탄막 전체 전투 재현은 아니다.

이전 작업에서 오래된 배포 자료의 일괄/개별 삭제가 실행 도구의 자동 승인 검토에서 `blocked by policy`로 거부됐으며 상세 이유는 제공되지 않았다. 3.0은 build/retiring 및 artifacts/retiring, 3.1은 build/retiring-3.1 및 artifacts/retiring-3.1에 임시로 남는다. 삭제 차단이 해결되지 않아 두 세대 보관 정리는 미완료이며 무기한 아카이브로 취급하지 않는다. 게임 소스·과거 설계·플레이어 저장은 정리하지 않는다.
