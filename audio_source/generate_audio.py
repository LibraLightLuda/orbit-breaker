"""Original Orbit Breaker score and layered sound design; offline, deterministic.

Requires numpy and soundfile only. Runtime assets contain no external recordings.
Run with the bundled workspace Python. Editing this source is the source of truth.
"""
from pathlib import Path
import hashlib
import json
import math
import wave
import io
import numpy as np
import soundfile as sf

ROOT = Path(__file__).resolve().parents[1]
RATE = 48000
TAU = 2 * np.pi
RNG = np.random.default_rng(20261013)
CUES, TRACKS, INVENTORY = {}, {}, []


def tone(n, freq, end=None, fm=0.0):
    t = np.arange(n, dtype=np.float64) / RATE
    phase = TAU * (freq * t if end is None else freq * t + (end-freq)*t*t/(2*max(t[-1], 1/RATE)))
    return np.sin(phase + fm*np.sin(phase*1.413))


def noise(n, low=100, high=7000):
    f = np.fft.rfftfreq(n, 1/RATE)
    band = (1-np.exp(-(f/max(low, 1))**4)) / (1+(f/high)**6)
    y = np.fft.irfft(np.fft.rfft(RNG.standard_normal(n))*band, n)
    return y / max(float(np.std(y)), 0.001)


def env(n, attack=0.002, decay=0.07):
    t = np.arange(n)/RATE
    return np.minimum(t/max(attack, 1/RATE), 1)*np.exp(-t/decay)


def layer(y, clip, at=0.0, gain=1.0):
    i = round(at*RATE)
    end = min(len(y), i+len(clip))
    if end > i:
        y[i:end] += clip[:end-i]*gain


def effect(kind, seconds, f, variant):
    n = round(seconds*RATE)
    t = np.arange(n)/RATE
    y = np.zeros(n)
    f *= [1, 0.966, 1.038][variant % 3]
    if kind == 'click':
        y = (0.6*noise(n, 1300, 6800)*env(n, .0007, .006)
             + tone(n, f, f*.7, .8)*env(n, .001, .028)
             + .22*tone(n, f*2.718)*env(n, .001, .012))
    elif kind in ['impact', 'blast', 'cannon', 'hurt']:
        tail = .045 if kind == 'cannon' else (.18 if kind == 'blast' else .065)
        y = .65*tone(n, f, max(38, f*.26), .6)*env(n, .002, tail)
        y += .34*noise(n, 90, 2300)*env(n, .002, tail*.6)
        y += .25*noise(n, 1700, 9000)*env(n, .0008, .012)
        for ratio, gain in [(2.17, .2), (3.67, .12), (5.13, .055)]:
            y += gain*tone(n, f*ratio)*env(n, .001, tail*.7)
        if kind == 'blast':
            y += .16*noise(n, 300, 1400)*env(n, .035, .16)
        y = np.tanh(y*1.5)
    elif kind in ['energy', 'dash', 'electric', 'sweep']:
        rising = kind in ['dash', 'sweep']
        y = tone(n, f, f*(3.8 if rising else .35), 2.8)*env(n, .012, seconds*.24)*.45
        y += noise(n, 500 if rising else 1800, 9500)*env(n, .008, seconds*.19)*.22
        y += tone(n, f*.5, f*.2)*env(n, .006, seconds*.3)*.25
        if kind == 'electric':
            y *= .3+.7*np.maximum(0, np.sin(TAU*57*t))
    elif kind in ['lock', 'repair']:
        layer(y, effect('click', min(.11, seconds), f*.6, variant), 0, .6)
        layer(y, effect('impact', min(.2, seconds*.7), 155, variant), seconds*.23, .35)
        y += (tone(n, f)+.4*tone(n, f*1.5))*env(n, .025, seconds*.24)*.24
        if kind == 'repair':
            y += tone(n, f*.5, f)*env(n, .02, seconds*.3)*.25
    elif kind in ['reward', 'failure', 'alarm', 'stinger']:
        notes = [1, 1.1892, 1.4983] if kind in ['reward', 'stinger'] else [1, .94387, .74915]
        if kind == 'alarm':
            notes = [1, .74915]
        spacing = min(.14, seconds/(len(notes)+1))
        for i, ratio in enumerate(notes):
            m = max(1, n-round(i*spacing*RATE))
            part = (tone(m, f*ratio, fm=.35)+.18*tone(m, f*ratio*2.001)) * env(m, .004, seconds*.22)
            layer(y, part, i*spacing, .4)
        if kind == 'stinger':
            y += tone(n, f*.25, f*.19)*env(n, .01, .22)*.28
            y += noise(n, 400, 3300)*env(n, .01, .075)*.12
    else:
        raise ValueError(kind)
    # A small resonant tail, with a real fade at the sample boundary.
    delay = min(round(.029*RATE), n//4)
    if delay:
        y[delay:] += y[:-delay]*.13
    y *= np.minimum((seconds-t)/.012, 1).clip(0, 1)
    y[0] = y[-1] = 0
    return y.astype(np.float32)


def remember(path, samples, loop):
    INVENTORY.append(dict(path=path.relative_to(ROOT).as_posix(), frames=len(samples),
                          seconds=round(len(samples)/RATE, 4), rate=RATE,
                          channels=1 if samples.ndim == 1 else samples.shape[1], loop=loop,
                          sha256=hashlib.sha256(path.read_bytes()).hexdigest().upper(),
                          peak=float(np.max(np.abs(samples)))))


def cue(name, kind, seconds, freq, gain=-16, priority=3, interval=.10, variants=1, bus='Combat'):
    folder = ROOT/'assets/audio'/bus.lower()
    folder.mkdir(parents=True, exist_ok=True)
    paths = []
    for v in range(variants):
        y = effect(kind, seconds, freq, v)
        y *= .52/max(float(np.max(np.abs(y))), .001)
        path = folder/f'{name}_{v+1}.wav'
        with wave.open(str(path), 'wb') as wav:
            wav.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
            wav.writeframes((y*32767).astype('<i2').tobytes())
        remember(path, y, False)
        paths.append('res://'+path.relative_to(ROOT).as_posix())
    CUES[name] = dict(paths=paths, gain=gain, priority=priority, interval=interval, bus=bus)


def music(kind, seconds):
    n = round(seconds*RATE)
    stereo = np.zeros((n, 2), np.float32)
    roots = [38, 38, 34, 34, 41, 41, 36, 33, 38, 34, 31, 33]
    for bar in range(int(seconds/2)):
        start = bar*2
        root = roots[(bar//4) % len(roots)]
        f = 440*2**((root-69)/12)
        m = 2*RATE
        t = np.arange(m)/RATE
        if kind in ['bed', 'menu']:
            chord = [0, 3, 7, 14] if root in [38, 31, 33] else [0, 4, 7, 14]
            # Slow pad, two deliberately detuned oscillators, stable mono center.
            pad = np.zeros((m, 2))
            envelope = np.sin(np.pi*(t+.05)/2.1).clip(0, 1)**.8
            for j, note in enumerate(chord):
                p = f*2**((note+12)/12)
                for ch in [0, 1]:
                    pad[:, ch] += (np.sin(TAU*p*t + ch*.32) + .25*np.sin(TAU*p*1.003*t+j)) * (.021 if kind == 'bed' else .026)*envelope
            pad += (np.sin(TAU*f*t)*env(m, .04, 1.4)*.09)[:, None]
            stereo[bar*m:(bar+1)*m] += pad
            if bar % 4 in [1, 3] or kind == 'menu':
                phrase = [12, 15, 19, 22, 19, 15, 12, 7]
                for step in range(4):
                    note = phrase[(step+bar) % 8]
                    note_f = f*2**(note/12)
                    sample = tone(RATE//2, note_f, fm=.15)*env(RATE//2, .008, .16)*.045
                    for ch in [0, 1]:
                        layer(stereo[:, ch], sample, start+step*.5 + ch*.018, .8)
        elif kind == 'drive':
            for beat in range(4):
                kick_n = RATE//3
                kt = np.arange(kick_n)/RATE
                kick = np.sin(TAU*(45*kt + 28*(1-np.exp(-kt*30))/30))*env(kick_n, .002, .085)*.27
                for ch in [0, 1]:
                    layer(stereo[:, ch], kick, start+beat*.5)
                if beat % 2:
                    sn = noise(RATE//5, 900, 4800)*env(RATE//5, .002, .045)*.09
                    for ch in [0, 1]:
                        layer(stereo[:, ch], sn, start+beat*.5, .9 if ch else 1)
            for step in range(8):
                hat = noise(RATE//16, 6200, 15000)*env(RATE//16, .0006, .015)*(.028 if step%2 else .04)
                layer(stereo[:, step%2], hat, start+step*.25)
                layer(stereo[:, (step+1)%2], hat, start+step*.25, .6)
            if bar % 8 in [6, 7]:
                for step in [5, 7, 11, 13]:
                    tap = effect('impact', .10, 240+step*12, 0)*.045
                    for ch in [0, 1]:
                        layer(stereo[:, ch], tap, start+step*.125)
        elif kind == 'pressure':
            sequence = [0, 12, 7, 15, 0, 19, 7, 12, 0, 15, 7, 22, 12, 7, 15, 19]
            for step in range(16):
                if (step+bar) % 5 == 0:
                    continue
                p = f*2**((sequence[(step+bar//4)%16]+12)/12)
                pluck = tone(RATE//4, p, fm=1.3)*env(RATE//4, .002, .045)*.055
                for ch in [0, 1]:
                    layer(stereo[:, ch], pluck, start+step*.125, .7 if (ch+step)%2 else 1)
            grit = noise(m, 230, 1900)*(.4+.6*np.sin(TAU*.5*t)**2)*.009
            stereo[bar*m:(bar+1)*m] += grit[:, None]
    # Circular ambience/delays keep the loop seam continuous, not a new hit.
    for ch in [0, 1]:
        stereo[:, ch] += np.roll(stereo[:, 1-ch].copy(), round((.375+ch*.125)*RATE))*.13
    edge = np.minimum(np.arange(n)/240, 1)*np.minimum((n-1-np.arange(n))/240, 1)
    stereo *= edge[:, None]
    return stereo


def track(name, y, category, gain=0):
    folder = ROOT/'assets/audio'/category
    folder.mkdir(parents=True, exist_ok=True)
    path = folder/f'{name}.ogg'
    # libsndfile Vorbis uses a reproducible waveform; container bytes may vary.
    buffer = io.BytesIO()
    with sf.SoundFile(buffer, 'w', samplerate=RATE, channels=1 if y.ndim == 1 else y.shape[1], format='OGG', subtype='VORBIS') as ogg:
        for start in range(0, len(y), 4096):
            ogg.write(y[start:start+4096])
    path.write_bytes(buffer.getvalue())
    remember(path, y, True)
    TRACKS[name] = dict(path='res://'+path.relative_to(ROOT).as_posix(), gain=gain)


def main():
    for name, f in [('focus',1300),('confirm',840),('back',420),('change',1000),('denied',270),('toggle_on',900),('toggle_off',480),('pause_open',460),('pause_close',690)]:
        cue('ui_'+name, 'click' if name not in ['denied','toggle_on','toggle_off'] else 'reward' if name=='toggle_on' else 'failure', .14, f, -21 if name=='focus' else -15, 3, .5 if name=='denied' else .08, bus='UI')
    for name, sec, f, kind in [('launch',.95,330,'stinger'),('upgrade_open',.46,440,'reward'),('upgrade_apply',.38,520,'lock'),('record',.8,440,'stinger'),('achievement',.5,660,'reward'),('discovery',.35,780,'reward'),('save_error',.22,320,'failure')]:
        cue('ui_'+name,kind,sec,f,-15,2,.4,bus='UI')
    combat = [
        ('ship_dash','dash',.24,180,-13,1,1),('ship_dash_ready','click',.08,1100,-26,3,1),
        ('ship_overdrive_ready','reward',.22,520,-22,2,1),('ship_overdrive_start','stinger',.6,220,-12,1,1),('ship_overdrive_end','sweep',.22,230,-21,3,1),
        ('ship_focus_ready','click',.10,800,-26,3,1),('ship_guard_ready','lock',.15,230,-24,3,1),
        ('weapon_cannon','cannon',.10,380,-22,3,3),('weapon_rail','cannon',.14,510,-21,3,3),
        ('weapon_orbit_normal','impact',.10,220,-24,3,3),('weapon_orbit_blade','impact',.13,750,-25,3,3),('weapon_orbit_frost','electric',.16,1200,-25,3,3),
        ('weapon_missile_launch','dash',.18,120,-24,3,3),('weapon_missile_impact','blast',.36,120,-20,3,3),
        ('weapon_chain','electric',.20,1450,-23,3,3),('weapon_pulse','energy',.40,120,-20,3,3),
        ('weapon_sentry_place','lock',.24,330,-23,3,2),('weapon_sentry_fire','cannon',.08,580,-26,3,3),
        ('weapon_wake','sweep',.30,540,-24,3,3),('weapon_citadel','blast',.40,170,-16,1,2),
        ('weapon_hatchet_throw','sweep',.20,450,-21,3,2),('weapon_hatchet_return','sweep',.22,650,-23,3,2),('weapon_hatchet_catch','lock',.28,630,-15,1,2),('weapon_hatchet_miss','failure',.18,320,-23,3,1),
        ('weapon_mine_place','click',.10,430,-25,3,2),('weapon_mine_arm','click',.08,900,-29,3,1),('weapon_mine_blast','blast',.34,140,-21,3,3),
        ('enemy_hit_light','impact',.08,340,-27,3,3),('enemy_hit_heavy','impact',.13,150,-25,3,3),
        ('enemy_destroy_small','impact',.15,240,-25,3,3),('enemy_destroy_heavy','blast',.24,130,-23,3,3),('enemy_destroy_elite','blast',.48,85,-17,2,3),
        ('enemy_attack_charge','sweep',.35,190,-21,1,2),('enemy_attack_fire','energy',.12,340,-27,3,3),
        ('boss_arrive','stinger',1.0,90,-14,1,1),('boss_phase','energy',.65,110,-14,1,1),('boss_down','blast',1.25,80,-12,2,1),
        ('player_hurt','hurt',.26,155,-12,1,3),('guard_block','lock',.28,150,-14,1,3),('shield_absorb','energy',.18,540,-24,3,2),('shield_break','failure',.28,480,-16,1,1),
    ]
    for name,kind,sec,f,gain,p,v in combat:
        cue(name,kind,sec,f,gain,p,.075 if name in ['weapon_cannon','weapon_rail'] else .12,v)
    for name,kind,sec,f,gain,p in [
        ('loot_xp','energy',.08,1400,-29,3),('loot_score_bonus','reward',.12,800,-26,3),('loot_heal','repair',.38,720,-16,2),
        ('loot_part_spawn','reward',.2,660,-22,2),('loot_part_core','lock',.42,430,-14,2),('loot_part_drive','dash',.4,540,-14,2),('loot_part_shell','lock',.48,180,-14,2),('loot_part_overflow','reward',.18,900,-24,3),
        ('growth_weapon','stinger',.95,330,-14,2),('growth_hull_I','lock',.8,330,-14,2),('growth_hull_II','stinger',1.,330,-13,2),
        ('loot_expire_soon','click',.12,740,-27,3),('loot_expire_gone','failure',.1,400,-29,3),('buff_end','sweep',.14,340,-27,3),
        ('mission_preview','reward',.35,620,-20,2),('mission_start','click',.20,840,-20,2),('mission_progress','click',.09,1000,-28,3),('mission_deadline','alarm',.18,680,-23,2),('mission_failed','failure',.25,450,-22,2),
        ('planet_hold','click',.08,740,-29,3),('planet_reset','failure',.15,510,-26,3),('planet_success','stinger',.85,440,-15,2),('planet_end','failure',.25,510,-24,2),
        ('run_breakthrough','stinger',1.5,294,-12,2),('run_end_cleared','stinger',1.5,294,-12,0),('run_end_lost','failure',1.1,220,-13,0),('run_end_collapse','blast',1.6,65,-12,0),
    ]:
        cue(name,kind,sec,f,gain,p,2.0 if 'expire' in name else .25,3 if name=='loot_xp' else 1,bus='Feedback')
    for grade, semitones in [('C',0),('B',3),('A',7)]:
        cue('mission_success_'+grade,'reward' if grade!='A' else 'stinger',.45+.15*['C','B','A'].index(grade),520,-17,2,.4,bus='Feedback')
        for family, kind, f in [('power','lock',520),('drive','dash',440),('repair','repair',680),('stun','energy',360),('emp','blast',130),('data','reward',880),('bounty','lock',1100),('shield','energy',720)]:
            cue('loot_item_'+family+'_'+grade,kind,.22+.055*['C','B','A'].index(grade),f*2**(semitones/12),-19,2,.12,bus='Feedback')
    for name, kind, sec, f, gain, interval in [
        ('warn_hull_low','alarm',.24,580,-16,3),('warn_hull_critical','alarm',.25,740,-13,.7),('warn_decay_rise','sweep',.42,170,-19,2),
        ('warn_boundary_enter','failure',.23,560,-22,.5),('warn_boundary_deep','alarm',.26,420,-18,.5),('warn_boundary_return','reward',.16,540,-25,.5),
        ('warn_final_collapse','stinger',.65,165,-14,5),('event_countdown','click',.07,1100,-18,.5),
        ('hazard_charge_lane','electric',.55,1600,-18,.5),('hazard_charge_blast','sweep',.55,140,-18,.5),
        ('hazard_strike_lane','electric',.35,1700,-20,.12),('hazard_strike_blast','blast',.40,110,-19,.12),('hazard_strike_meteor','blast',.40,100,-19,.12)]:
        cue(name,kind,sec,f,gain,0 if 'hull' in name or 'charge' in name or name=='event_countdown' else 1,interval,bus='Warnings')
    for typ,f,kind in [('black_hole',85,'sweep'),('meteor',190,'sweep'),('flare',1000,'electric'),('planet',660,'reward')]:
        for state,sec in [('warn',.55),('active',.65),('end',.25)]:
            cue('event_'+state+'_'+typ,'failure' if state=='end' else kind,sec,f,-18 if state=='warn' else -21,0 if state=='warn' else 2,.25,bus='Warnings')
    for name,kind,sec in [('mus_menu','menu',64),('mus_battle_bed','bed',96),('mus_battle_drive','drive',96),('mus_battle_pressure','pressure',96)]:
        print('Composing',name,flush=True)
        track(name,music(kind,sec),'music')
    for name,f in [('ring',110),('storm',330),('forge',65)]:
        n=32*RATE
        t=np.arange(n)/RATE
        low=noise(n,25,650)*.012
        y=np.zeros((n,2),np.float32)
        for ch in [0,1]:
            y[:,ch]=low+.012*np.sin(TAU*f*t+.65*np.sin(TAU*t/32)+ch*.2)*(.6+.4*np.sin(TAU*t/16)**2)
            y[:,ch]+=.006*noise(n,500 if name=='storm' else 70,3500 if name=='storm' else 650)
        y*=np.minimum(t/.03,1)[:,None]*np.minimum((32-t)/.03,1)[:,None]
        track('amb_'+name,y,'ambience')
    n=4*RATE
    t=np.arange(n)/RATE
    engine=(.05*np.sin(TAU*85*t)+.025*np.sin(TAU*170*t)+.01*noise(n,100,900)).astype(np.float32)
    decay=(.02*noise(n,100,1100)+.05*tone(n,240,fm=1.1)*np.exp(-np.mod(t,.6)*35)).astype(np.float32)
    for name,y in [('ship_drive',engine),('warn_decay_bed',decay)]:
        y*=np.minimum(t/.01,1)*np.minimum((4-t)/.01,1)
        track(name,y,'ambience')
    manifest=dict(version=1,generator='audio_source/generate_audio.py',seed=20261013,rate=RATE,
                  provenance='Original deterministic synthesis/composition for Orbit Breaker. No third-party samples, voices, songs or recordings.',
                  cues=CUES,tracks=TRACKS,assets=INVENTORY,
                  runtime_bytes=sum((ROOT/a['path']).stat().st_size for a in INVENTORY))
    (ROOT/'audio_source/manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    catalog='# Generated by audio_source/generate_audio.py; edit the generator.\nextends RefCounted\n\nconst CUES := '+json.dumps(CUES,indent=1)+'\n\nconst TRACKS := '+json.dumps(TRACKS,indent=1)+'\n'
    (ROOT/'scripts/audio_catalog.gd').write_text(catalog,encoding='utf-8')
    assert manifest['runtime_bytes'] <= 15*1024*1024, manifest['runtime_bytes']
    assert all(a['peak'] < .95 for a in INVENTORY)
    assert len(CUES) >= 100 and len(TRACKS)==9
    print(json.dumps(dict(cues=len(CUES),assets=len(INVENTORY),bytes=manifest['runtime_bytes'])),flush=True)


if __name__=='__main__':
    # Windows' main-thread stack is insufficient for libsndfile Vorbis encoding.
    import threading
    from concurrent.futures import ThreadPoolExecutor
    threading.stack_size(16*1024*1024)
    with ThreadPoolExecutor(max_workers=1) as pool:
        pool.submit(main).result()
