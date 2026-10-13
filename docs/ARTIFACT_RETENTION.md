# 배포본·검증 자료 보관 규칙

적용일: 2026-10-11. 사용자가 최신 배포 버전만 보관하도록 변경했다. 기존의 최신·직전 두 세대 보관 규칙보다 이 규칙이 우선한다.

## 보관 범위

`build`와 `artifacts`에는 **최신 검증 완료 배포본 한 세대만** 유지한다. 최신 실행 파일·체크섬·플레이 안내·대응 최종 검증 명세·빌드/실행 로그·화면 캡처를 함께 보관한다. Windows와Web은 같은 제품 버전의 플랫폼별 산출물이며 별도 세대가 아니다. `web/`은 최신Web 게시용 복사본이다.

직전본을 포함한 모든 구버전 실행 파일·대응 검증 자료와 불필요한 임시 자료를 정리한다. 별도 아카이브로 구버전 배포본을 무기한 보존하지 않는다. 게임 소스·과거 설계 문서·소스 이력·플레이어 저장 데이터·설정은 삭제 대상이 아니다. 제품 버전 이름이 같아도 실행 파일SHA-256이 달라진 검증 완료 배포본으로 교체하면 이전 산출물은 정리 대상이다.

## 배포 갱신 순서

1. 현재 최신 정상본의 실행 파일·체크섬·안내·검증 자료를 확인하고 보존한다. 검증되지 않은 후보로 덮어쓰거나 먼저 삭제하지 않는다.
2. 새 후보를 `build/candidate`와`artifacts/candidate`에 별도로 준비하고 필수 검사·내보내기·실행·체크섬 확인을 완료한다. 갱신 작업 중에만 정상본과 후보의 일시 공존을 허용한다.
3. 실패하면 현재 정상본을 유지하고 실패 후보·임시 자료를 정리한다. 성공하면 새 후보를 최신본으로 교체하고 산출물·검증 자료·해시의 대응을 다시 확인한다.
4. 교체 성공 확인 후 이전 최신본·직전본·모든 더 오래된 배포 자료와 임시 백업을 정리한다. 별도 상시 직전본을 남기지 않는다.
5. 최종 한 세대의 파일 목록·SHA-256과 검증 명세를 갱신한다. 정리가 차단되면 남은 위치와 정확한 사유를 기록하며, 한 세대 정리가 완료됐다고 표시하지 않는다.

## 현재 최신본 (2026-10-12)

최신 로컬 세대는 **3.18 / art-20261012**다. `build/current/OrbitBreaker.exe`, Windows/Web ZIP, `build/current/web`와 `web/`, 대응 증거 `artifacts/current`가 최종본이다.

Windows SHA-256: `15D4D4098BD767B8B8D63C5550749387DC57FC091651285BCB7BA5F37FF77939`. Web PCK: `DA1B5DACF6A8FBDE1E05D481BBC12845F82D19418E3374B6C03A8D83E984FAF0`.

기존 정상 실행 파일·해시·안내·증거를 retiring에 먼저 보존하고 후보 검증/내보내기/실행/해시 일치를 확인한 뒤 교체했다. 교체 후 이전 세대와 임시 백업을 정리했다. 최신 한 세대 정책을 지키며 원본 계획·제작 소스·미커밋 변경·플레이어 데이터는 보존했다. 최종 목록은 `artifacts/current/file-inventory.json`, `release-hashes.json`, `retention-status.json`, `verification.json`이다.

계획 조사 Temp 삭제 차단은 배포 세대 정리와 구분한다. 공개 사이트와 v3.18.1 릴리즈에 이번 아트 세대가 반영됐다.

최종 보관 확인: 추가 QA 임시 정리는 자동 승인 검토에서 `blocked by policy`로 거부되어 실행되지 않았다. 남은 경로는 `artifacts/candidate`(검증 art 자료만 있으며 후보 실행 파일 없음), `art_source/web_qa_project`, `art_source/memory_baseline_project`다. 최종 증거는 `artifacts/current`에 합쳐 보존했다. 정상 배포본은 build/current 한 세대이며 이전 배포 세대 정리는 완료됐지만 이 임시 정리는 미완료다. 삭제를 다른 방법으로 우회하지 않았다.

## 2026-10-12 공개 배포 완료

사용자의 후속 게시 요청으로 전체 작업268파일을 커밋 `d268760bcddcb9f93d40f2321a4b68df1b0193df`에 반영하고 main에 푸시했다. [v3.18.1 릴리즈](https://github.com/LibraLightLuda/orbit-breaker/releases/tag/v3.18.1)와 [웹 플레이](https://libralightluda.github.io/orbit-breaker/)가 공개됐다. 게임 규칙/게임 내 표시 버전3.18과 검증된 실행 파일은 유지한다. Pages 작업38241917579 성공, 공개 Web9파일 SHA-256이 로컬 검증본과 모두 일치한다. 릴리즈6첨부의 GitHub SHA-256 digest도 로컬 파일과 대조했다.

공개 Chromium에서 새 타이틀·출격 준비·전투 진행(27초/41처치)·강화2회 선택·ESC정지·무기도감과복귀를 직접 확인했다. 이는 짧은 공개 배포 smoke 검사이며 기존10분/native/성능 검사와 구분한다. Space/E 입력 전달만으로 공개 사이트에서 스킬 소비까지 별도 확인했다고 주장하지 않는다. 기존 릴리즈4첨부와 구Pages아티팩트1개는 새 공개본 검증 후 정리했고 소스 태그/릴리즈 이력은 보존했다. Windows/Web ZIP의 PLAY 안내는 공개 주소로 갱신하고 재패키징·내용/해시를 검증했다. 실행 파일과 Web 게임 파일 바이트는 그대로다.

최종 공개 근거는 `artifacts/current/github-publication.json`, `public-retention.json`, `art/public-web-hashes.json`, `art/public-release-assets.json`과 공개 화면 캡처다. 이전 절의 게시 전 상태는 이 후속 결과로 대체한다. 로컬 QA 임시 폴더와 계획 조사Temp의 기존 정책 차단은 그대로 남아 있다.


## 2026-10-13 모션 세대 전환

`motion-20261013`의 모든 필수 검사·실행·해시 일치 후 `build/current`, `artifacts/current`를 교체했다. 이전 build/artifacts/web retiring3폴더는 교체 검증 후 삭제했다. 로컬 배포본은 최신 한 세대다. 비교용 `motion_baseline_project` 삭제도 자동 승인 검토에서 blocked by policy로 거부되어, 기존 차단4경로와 함께 총5개 임시 경로가 남았다. `retention-status.json`의 removed/retained_scratch와 `file-inventory.json`이 현재 실물 기준이다. 기존 계획·소스·플레이어 저장/설정은 보존했다.


## 2026-10-13 모바일 세대 전환

최신은 **3.18.2 / mobile-20261013**. 기존 정상 EXE·체크섬·안내·대응 증거를 retiring에 먼저 보존하고 새 필수 검사/Windows·Web export/실행/해시 검증 후 current를 교체했다. 교체 후 retiring3폴더와 이번 mobile-candidate를 정리했다. 최신 Windows SHA-256 `8AE93D875BE76E77153E04746729C6A3D3CF24DEEFEE3F3E9D9637CA168F1A99`. 로컬 정상 배포본은 한 세대다. 기존 정책 차단 임시5경로는 재시도하지 않았으며 retained_scratch에 남아 있다. 신규 공개본 검증 후 GitHub 구버전 첨부6개와 이전 Pages artifact2개를 정리했고 최신 릴리즈6첨부/Pages artifact1개를 확인했다. 소스·설계 이력·플레이어 데이터는 보존했다.


## 2026-10-13 모바일 피드백 세대 전환

최신 로컬 세대는 **3.18.3 / feedback-20261013**. 필수 검사·Windows/Web 내보내기·최종 실행·해시 검증 후 current를 교체했다. 이전 실행 파일·체크섬·안내·증거를 retiring에 보존하고 새 정상본 확인 후 정리했다. Windows SHA-256 `82B7CF017639B020C9922945476F64CB57C9390A996071513AB8BA7206F943AB`. 배포본은 최신 한 세대다. 기존 정책 차단 임시5경로와 이번 `artifacts/feedback-candidate` 삭제 차단으로 임시6경로가 남았다. 자동 승인 검토가 복합 삭제 명령을 blocked by policy로 거부했으며 해당 삭제를 우회/재시도하지 않았다. 소스/설계/플레이어 데이터는 보존했다. GitHub/Pages 검증은 진행 중이다.
