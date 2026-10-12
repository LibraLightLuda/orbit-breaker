"""Link each approved matrix row to production keys, consumers and current evidence."""
from pathlib import Path
import json,re
root=Path(__file__).resolve().parents[1]
manifest=json.loads((root/'art_source/asset-manifest.json').read_text(encoding='utf-8'))
rows=json.loads((root/'art_source/worklist.json').read_text(encoding='utf-8'))
rows=[r for r in rows if r['target']!='화면/사용처']
loader_status=root/'artifacts/current/art/web-loader-status.json'
loader_reviewed=loader_status.exists() and json.loads(loader_status.read_text(encoding='utf-8')).get('reviewed',False)
for row in rows:
    n=row['source_line']; target=row['target']; keys=[]
    row['baseline_matrix']='art_source/baseline/ART_ASSET_MATRIX.md'
    evidence=['artifacts/current/art/final/icon-catalog.png']
    consumer='scripts/main.gd / scripts/ui_glyph.gd / scripts/art_assets.gd'
    method='공유 자산과 콘텐츠 ID 연결, 기존 판정/정보/동작 유지'
    if 15<=n<=31:
        consumer='main.gd::_draw_arena/_draw_enemy/_draw_part_icon + UiGlyph'
        evidence=['artifacts/current/art/final/elite-statuses.png','artifacts/current/uiux/stage6/combat-late-reinforcements.png']
        if n<=17:
            ship=['striker','scout','bastion'][n-15]; keys=['ships/'+ship]
            evidence=[f'artifacts/current/uiux/stage6/combat-{ship}.png',f'artifacts/current/art/final/forms-{ship}-2.png']
        elif n<=22:
            keys=['objects/core','objects/drive','objects/shell']
            evidence=['artifacts/current/art/final/forms-striker-1.png','artifacts/current/art/final/forms-striker-2.png']
        elif n<=26: keys=['enemies/'+['chaser','runner','tank','shooter'][n-23]]
        elif n in [27,28]: keys=['enemies/'+('elite_assault' if n==27 else 'elite_artillery')]
        elif n<=30: keys=['enemies/boss']
        else:
            keys=['ui/stun']; method='새 외피와 기존 피격/빙결/마비의 정확한 상태 표식 결합; 별도 서리 쉘 셰이더는 사용하지 않음'
    elif 41<=n<=61:
        consumer='main.gd::_draw_arena, model.orbit_position/orbit_kind/shot kind'
        evidence=['artifacts/current/art/release-input/soak-03.png']
        if n in [41,42]: keys=['fx/projectile']
        elif n in [43,44,45]: keys=['objects/'+['normal','blade','frost'][n-43]]
        elif n==47: keys=['objects/missile','fx/thrust']
        elif n==48: keys=['ui/chain']
        elif n==49: keys=['fx/wave']
        elif n>=50:
            ident=re.search(r'`([^`]+)`',target)[1]; keys=['ui/'+ident]
            evidence=[f'artifacts/current/art/final/evolution-{ident}.png']
    elif 73<=n<=84:
        ident=re.search(r'`([^`]+)`',target)[1]; keys=['ui/'+ident,'fx/container']
        consumer='ItemCatalog.draw_icon / ItemIcon / main.gd field,status,direction / codex / replay'
        evidence=['artifacts/current/art/final/items-36-grades.png','artifacts/current/uiux/stage6/items-known.png']
    elif 90<=n<=93:
        consumer='main.gd::_draw_arena/_draw_direction_marker/_draw_expedition'
        keys=['objects/xp','objects/heal'] if n<=91 else ['objects/core','objects/drive','objects/shell']
        evidence=['artifacts/current/art/final/legacy-recovery-gem.png','artifacts/current/art/release-input/soak-03.png']
    elif 101<=n<=123:
        keys=['ui/'+re.search(r'`([^`]+)`',target)[1]]
        consumer='UiGlyph / main.gd::_show_upgrades/_upgrade_links / tech codex'
        evidence=['artifacts/current/art/final/icon-catalog.png','artifacts/current/art/final/upgrade-scroll.png','artifacts/current/art/final/upgrade-390x844-links-bottom.png']
    elif 133<=n<=155:
        consumer='main.gd::_draw_arena/_draw_orbital_regions/_draw_hazard/_draw_encounter/_draw_impact/_show_result'
        if 133<=n<=136:
            keys=['world/'+v for v in (['ring','storm','forge'] if n==133 else [['ring'],['storm'],['forge']][n-134])]
            evidence=['artifacts/current/art/final/sector-'+v+'.png' for v in ['ring','storm','forge']]
        elif 139<=n<=144:
            kind=['lane','blast','black_hole','planet','meteor','flare'][n-139]
            keys={'lane':[],'blast':['fx/explosion'],'black_hole':['fx/black_hole'],'planet':['objects/planet'],'meteor':['objects/meteor','fx/explosion'],'flare':['fx/wave']}[kind]
            evidence=[f'artifacts/current/art/final/event-{kind}-{state}.png' for state in ['warn','active']]
        elif n==155:
            evidence=['artifacts/current/uiux/stage6/result.png']
            method='최종 전장 정지·차광과 새 공통 패널로 전환; 저장/버튼을 지연하는 별도 fade는 추가하지 않음'
        else:
            evidence=['artifacts/current/art/final/impact-fx.png','artifacts/current/art/release-input/soak-03.png']
            method='새 표면/FX와 모델 범위·시간의 절차적 기능 표식. 경계·계기·방향선은 의도적으로 유지'
    elif 165<=n<=189:
        scene={165:'title',166:'hangar',174:'upgrades',175:'weapons',176:'items-known',177:'tech',178:'achievements',181:'result',183:'settings',184:'help'}.get(n,'combat-striker')
        evidence=[f'artifacts/current/uiux/stage6/{scene}.png']
        if n==179: evidence=['artifacts/current/art/release-input/pause.png']
        if n==180: evidence=['artifacts/current/art/final/abandon-confirm.png']
        if n==182: evidence=['artifacts/current/art/release-input/replay-4x.png','artifacts/current/art/release-input/replay-legacy-path.png']
        if n==186: evidence=['artifacts/current/art/production-comparison.png','artifacts/current/art/windows-exe-icon.png']; method='자체 SVG 앱 상징; Godot 16/32/64/128px 실제 렌더와 Windows PE 아이콘 추출 확인'
        if n==185: evidence=['artifacts/current/art/final/credits.png']
        if n==187: evidence=['artifacts/current/art/web-loader-failure.png']; method='export preset의 지속 가능한 로딩/오류 표면; 의도적으로 WASM/PCK를 뺀 별도 QA fixture'
        if n==189: evidence=['artifacts/current/uiux/stage6/menu-390x844.png','artifacts/current/art/final/upgrade-390x844-top.png','artifacts/current/art/final/upgrade-844x390-links-bottom.png']
        if n==173: evidence=['artifacts/current/art/web-combat.png']; method='Web 실제 클릭 돌진/가속/끝점 조준표 관측과 기존 입력 회귀; OS 커서 직접 조작 검증과 구분'
    for key in keys: assert key in manifest,key
    row.update(status='implemented-render-verified' if n!=187 or loader_reviewed else 'implemented-pending-error-state-review',resource_keys=keys,resource_paths=[manifest[k] for k in keys],consumer=consumer,implementation=method,evidence=evidence)
    if n==186: row['resource_paths']=['res://icon.svg']
    if n==187: row['resource_paths']=['res://assets/branding/splash.png','export_presets.cfg']
    for path in evidence:
        if n!=187 or loader_reviewed: assert (root/path).is_file(),path
(root/'art_source/worklist.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf-8')
print(f'{len(rows)} actual matrix rows mapped; {len(manifest)} production assets; loader reviewed={loader_reviewed}.')
