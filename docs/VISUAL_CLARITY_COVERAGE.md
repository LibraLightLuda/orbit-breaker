# 선명도 개선 자산 검수표

2026-10-16 · clarity-20261016. 전체 95개 등록 자산의 처리와 실제 렌더 검수 연결. 전 항목의 바인딩·가시영역·알파/피벗 검사를 통과하고 `artifacts/current/visual/all-textures.png`에 렌더했다. 상태별 대표 사용처는 `final-art/`·`screens/`·`browser/` 캡처와 기존 공유 렌더 경로 회귀로 확인했다. 모든 자산×모든 상태를 각각 사람 손으로 플레이한 검수는 아니다. 최종 판정과 한계는 [구현·검증 보고서](VISUAL_CLARITY_IMPLEMENTATION_REPORT.md)와 `artifacts/current/verification.json`을 따른다.

| 자산 | 처리 | 검사 사용처 |
| --- | --- | --- |
| `enemies/boss` | baked silhouette and material contrast | 전투/정예·보스 상태/전술·최종 작전; 전체 자산 gallery/바인딩/가시영역 검사 |
| `enemies/chaser` | baked silhouette and material contrast | 전투/정예·보스 상태/전술·최종 작전; 전체 자산 gallery/바인딩/가시영역 검사 |
| `enemies/elite_artillery` | baked silhouette and material contrast | 전투/정예·보스 상태/전술·최종 작전; 전체 자산 gallery/바인딩/가시영역 검사 |
| `enemies/elite_assault` | baked silhouette and material contrast | 전투/정예·보스 상태/전술·최종 작전; 전체 자산 gallery/바인딩/가시영역 검사 |
| `enemies/runner` | baked silhouette and material contrast | 전투/정예·보스 상태/전술·최종 작전; 전체 자산 gallery/바인딩/가시영역 검사 |
| `enemies/shooter` | baked silhouette and material contrast | 전투/정예·보스 상태/전술·최종 작전; 전체 자산 gallery/바인딩/가시영역 검사 |
| `enemies/tank` | baked silhouette and material contrast | 전투/정예·보스 상태/전술·최종 작전; 전체 자산 gallery/바인딩/가시영역 검사 |
| `fx/black_hole` | soft core separation | 전투/재해/이동/효과 줄이기; 전체 자산 gallery/바인딩/가시영역 검사 |
| `fx/container` | baked silhouette and material contrast | 전투/재해/이동/효과 줄이기; 전체 자산 gallery/바인딩/가시영역 검사 |
| `fx/explosion` | soft core separation | 전투/재해/이동/효과 줄이기; 전체 자산 gallery/바인딩/가시영역 검사 |
| `fx/projectile` | projectile radius preserved; explicit core rim | 전투/재해/이동/효과 줄이기; 전체 자산 gallery/바인딩/가시영역 검사 |
| `fx/spark` | soft core separation | 전투/재해/이동/효과 줄이기; 전체 자산 gallery/바인딩/가시영역 검사 |
| `fx/thrust` | soft core separation | 전투/재해/이동/효과 줄이기; 전체 자산 gallery/바인딩/가시영역 검사 |
| `fx/wave` | soft core separation | 전투/재해/이동/효과 줄이기; 전체 자산 gallery/바인딩/가시영역 검사 |
| `objects/axe` | baked silhouette and material contrast | 월드/무장/픽업/장착/도감; 전체 자산 gallery/바인딩/가시영역 검사 |
| `objects/blade` | baked silhouette and material contrast | 월드/무장/픽업/장착/도감; 전체 자산 gallery/바인딩/가시영역 검사 |
| `objects/core` | baked silhouette and material contrast | 월드/무장/픽업/장착/도감; 전체 자산 gallery/바인딩/가시영역 검사 |
| `objects/drive` | baked silhouette and material contrast | 월드/무장/픽업/장착/도감; 전체 자산 gallery/바인딩/가시영역 검사 |
| `objects/frost` | baked silhouette and material contrast | 월드/무장/픽업/장착/도감; 전체 자산 gallery/바인딩/가시영역 검사 |
| `objects/heal` | baked silhouette and material contrast | 월드/무장/픽업/장착/도감; 전체 자산 gallery/바인딩/가시영역 검사 |
| `objects/meteor` | baked silhouette and material contrast | 월드/무장/픽업/장착/도감; 전체 자산 gallery/바인딩/가시영역 검사 |
| `objects/mine` | baked silhouette and material contrast | 월드/무장/픽업/장착/도감; 전체 자산 gallery/바인딩/가시영역 검사 |
| `objects/missile` | baked silhouette and material contrast | 월드/무장/픽업/장착/도감; 전체 자산 gallery/바인딩/가시영역 검사 |
| `objects/normal` | baked silhouette and material contrast | 월드/무장/픽업/장착/도감; 전체 자산 gallery/바인딩/가시영역 검사 |
| `objects/planet` | baked silhouette and material contrast | 월드/무장/픽업/장착/도감; 전체 자산 gallery/바인딩/가시영역 검사 |
| `objects/sentry` | baked silhouette and material contrast | 월드/무장/픽업/장착/도감; 전체 자산 gallery/바인딩/가시영역 검사 |
| `objects/shell` | baked silhouette and material contrast | 월드/무장/픽업/장착/도감; 전체 자산 gallery/바인딩/가시영역 검사 |
| `objects/xp` | baked silhouette and material contrast | 월드/무장/픽업/장착/도감; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ships/bastion` | baked silhouette and material contrast | 3기체 전투/회전/선체 조합/메뉴/고스트; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ships/scout` | baked silhouette and material contrast | 3기체 전투/회전/선체 조합/메뉴/고스트; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ships/striker` | baked silhouette and material contrast | 3기체 전투/회전/선체 조합/메뉴/고스트; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/achievement` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/aegis` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/battery` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/blade` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/blizzard` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/bounty` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/burst` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/cataclysm` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/chain` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/citadel` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/core` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/dash` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/dash_hits` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/drive` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/ellipse` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/emp` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/focus_amp` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/focus_memory` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/fortune` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/frenzy` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/frost` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/guard_pulse` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/guard_reserve` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/haste` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/hatchet` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/heal` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/insight` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/lancer` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/magnet` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/minefield` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/missile` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/normal` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/nova` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/orbit` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/orbit_range` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/outer` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/outer_kills` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/overdrive` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/power` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/pulse` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/rail` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/rapid` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/relaxed` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/repair` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/restore` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/returns` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/salvo` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/scout_drive` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/scout_lance` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/sentry` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/shell` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/shield` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/speed` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/storm` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/stun` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/superorbit` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/survive` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/trinity` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/veteran` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/vitality` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `ui/wake` | stronger diagram strokes and quieter corner marks | 메뉴/전체 페이지/카드/전투 표식; 전체 자산 gallery/바인딩/가시영역 검사 |
| `world/forge` | source retained; contrast separated in space shader | 3전장/메뉴/전투 배경; 전체 자산 gallery/바인딩/가시영역 검사 |
| `world/ring` | source retained; contrast separated in space shader | 3전장/메뉴/전투 배경; 전체 자산 gallery/바인딩/가시영역 검사 |
| `world/storm` | source retained; contrast separated in space shader | 3전장/메뉴/전투 배경; 전체 자산 gallery/바인딩/가시영역 검사 |
