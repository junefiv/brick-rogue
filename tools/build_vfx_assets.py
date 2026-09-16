"""Rebuild original, editable vector atlases. No external art/license dependencies."""
from pathlib import Path
import math, random, json, re

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets' / 'vfx'
OUT.mkdir(parents=True, exist_ok=True)
DEFS = '''<defs>
<radialGradient id="glow"><stop stop-color="#fffef2"/><stop offset=".24" stop-color="#ffe596" stop-opacity=".95"/><stop offset=".55" stop-color="#ff7a20" stop-opacity=".6"/><stop offset="1" stop-color="#ff3214" stop-opacity="0"/></radialGradient>
<radialGradient id="metal" cx=".3" cy=".22"><stop stop-color="#f2fbff"/><stop offset=".3" stop-color="#b4d5e5"/><stop offset=".65" stop-color="#47627b"/><stop offset="1" stop-color="#101a30"/></radialGradient>
<linearGradient id="gold" x2=".8" y2="1"><stop stop-color="#fff9c2"/><stop offset=".25" stop-color="#ffe96c"/><stop offset=".5" stop-color="#d88b19"/><stop offset=".72" stop-color="#ffdc5a"/><stop offset="1" stop-color="#6f350f"/></linearGradient>
<linearGradient id="ice" x2=".65" y2="1"><stop stop-color="#f4ffff"/><stop offset=".32" stop-color="#b5f6ff"/><stop offset=".63" stop-color="#5abbea" stop-opacity=".85"/><stop offset="1" stop-color="#204c99" stop-opacity=".6"/></linearGradient>
<linearGradient id="wood" x2="0" y2="1"><stop stop-color="#b56b34"/><stop offset=".45" stop-color="#6d321e"/><stop offset="1" stop-color="#281322"/></linearGradient>
<radialGradient id="white"><stop stop-color="#ffffff"/><stop offset=".25" stop-color="#e4faff" stop-opacity=".95"/><stop offset="1" stop-color="#a4eaff" stop-opacity="0"/></radialGradient>
</defs>'''

def svg(name, body, w=128, h=128):
    (OUT / (name + '.svg')).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{DEFS}{body}</svg>', encoding='utf-8')

svg('orb', '<circle cx="64" cy="64" r="60" fill="url(#white)" opacity=".45"/><circle cx="64" cy="64" r="35" fill="url(#metal)" stroke="#e8ffff" stroke-width="3"/><ellipse cx="54" cy="49" rx="14" ry="8" fill="white" opacity=".85"/>')
svg('arrow', '<path d="M8 38L58 52 54 12 122 64 54 116 58 76 8 90 29 64Z" fill="#073555" stroke="#56daff" stroke-width="3"/><path d="M25 44L67 56 63 28 109 64 63 100 67 73 25 83 42 64Z" fill="url(#ice)"/><path d="M43 62L102 64 65 37 72 58Z" fill="white"/><path d="M42 67L101 64 64 89 71 72Z" fill="#349ac9"/>')
svg('bomb', '<path d="M67 32Q53 5 81 14Q101 21 92 5" fill="none" stroke="#b69a68" stroke-width="6"/><path d="M92 1L96 8 107 4 99 14 108 19 96 18 91 27 89 16 79 14 88 9Z" fill="#fff8c0"/><rect x="51" y="30" width="26" height="20" rx="4" fill="url(#gold)"/><circle cx="64" cy="79" r="39" fill="url(#metal)" stroke="#102038" stroke-width="3"/><ellipse cx="51" cy="63" rx="14" ry="8" fill="#e1f7ff" opacity=".6"/><path d="M35 89Q64 110 93 89" fill="none" stroke="#ff6c29" stroke-width="7"/><path d="M60 66L71 77 65 89 54 78Z" fill="#ffc242"/>')
svg('coin', '<ellipse cx="68" cy="65" rx="42" ry="48" fill="#663507"/><ellipse cx="61" cy="60" rx="42" ry="48" fill="url(#gold)" stroke="#ffe48a" stroke-width="3"/><ellipse cx="61" cy="60" rx="31" ry="37" fill="none" stroke="#8b5414" stroke-width="3"/><path d="M61 34L79 60 61 86 43 60Z" fill="#fff2a1" stroke="#ac731e" stroke-width="3"/>')
svg('spark', '<circle cx="64" cy="64" r="62" fill="url(#glow)"/><path d="M64 2L71 49 101 19 79 56 126 64 80 72 105 107 72 80 64 127 55 80 19 109 49 73 1 64 48 55 23 20 56 48Z" fill="#fff6d4"/><path d="M64 25L71 57 104 64 71 71 64 107 56 71 24 64 56 56Z" fill="white"/>')
svg('particle', '<circle cx="64" cy="64" r="63" fill="url(#white)"/>')
svg('shard', '<path d="M60 2L109 49 83 113 29 127 14 46Z" fill="url(#ice)" stroke="#d6ffff" stroke-width="2"/><path d="M60 2L53 56 14 46M53 56L83 113M53 56L109 49" fill="none" stroke="#fff" stroke-opacity=".7" stroke-width="3"/><path d="M60 2L53 56 109 49Z" fill="white" opacity=".35"/>')
svg('ring', '<circle cx="64" cy="64" r="48" fill="none" stroke="#6fbaff" stroke-opacity=".15" stroke-width="18"/><circle cx="64" cy="64" r="48" fill="none" stroke="#cefbff" stroke-width="3"/><circle cx="64" cy="64" r="41" fill="none" stroke="#77cfff" stroke-opacity=".65" stroke-width="2"/>')
svg('missile', '<path d="M8 55L44 54 83 38 120 64 83 90 44 74 8 73 27 64Z" fill="url(#metal)" stroke="#18334f" stroke-width="3"/><path d="M86 40L120 64 86 88Z" fill="#ff5944"/><path d="M25 51L34 18 64 50M25 77L34 110 64 78" fill="#c2e5f2" stroke="#3d617b" stroke-width="3"/>')
svg('beam', '<rect width="256" height="64" fill="none"/><path d="M0 32L18 12H240L256 32 240 52H18Z" fill="#57a7ff" opacity=".15"/><path d="M0 32L24 22H244L256 32 244 42H24Z" fill="#8bd6ff" opacity=".45"/><path d="M0 32L24 28H250L256 32 250 36H24Z" fill="#fff"/>',256,64)

# Ice frame: transparent center protects HP readability; facets extend outside brick.
rng = random.Random(17)
ice = '<path d="M12 18L50 10 82 15 118 8 158 17 149 93 111 100 75 93 20 103Z" fill="#8cdcff" opacity=".14"/>'
for x,y,s in [(15,20,20),(44,12,16),(118,12,18),(145,25,20),(17,80,18),(138,84,19)]:
    ice += f'<path d="M{x} {y-s}L{x+s*.7} {y} {x+s*.4} {y+s} {x-s*.6} {y+s*.6} {x-s*.8} {y-s*.3}Z" fill="url(#ice)" stroke="#e1ffff" stroke-width="1.2"/><path d="M{x} {y-s}L{x} {y+s} {x+s*.7} {y}" fill="#e9ffff" opacity=".4"/>'
for x in [24,41,65,110,134]:
    length=rng.randint(12,26)
    ice+=f'<path d="M{x-6} 90L{x+6} 88 {x+1} {90+length}Z" fill="url(#ice)" stroke="#c9faff" stroke-width=".7"/>'
ice += '<path d="M18 26L33 34 27 51M142 31L124 39 132 52M32 87L45 74M131 88L119 72" fill="none" stroke="#d6fbff" stroke-width="1.5" opacity=".8"/>'
svg('ice_frame',ice,168,124)

# Six-frame treasure chest opening atlas, separate lid perspective in each frame.
frames=[]
for i in range(6):
    lid_y=40-i*4
    lid_h=40-i*3
    b='<ellipse cx="64" cy="110" rx="57" ry="10" fill="#000" opacity=".4"/>'
    b+='<path d="M12 59L111 59 116 102 104 115 22 115 12 103Z" fill="url(#wood)" stroke="#201222" stroke-width="3"/>'
    b+='<path d="M18 78H108M19 92H109M27 109H102" stroke="#d6984c" stroke-opacity=".4" stroke-width="2"/>'
    b+='<path d="M25 63H36V114H25ZM88 63H100V114H88Z" fill="url(#gold)" stroke="#754714" stroke-width="2"/>'
    if i:
        b+=f'<ellipse cx="64" cy="63" rx="47" ry="16" fill="#160e20"/><ellipse cx="64" cy="60" rx="40" ry="{10+i}" fill="#ffcf4a" opacity="{i*.11}"/>'
    b+=f'<path d="M11 {lid_y+lid_h}V{lid_y+15}Q11 {lid_y-8} 63 {lid_y-8}Q116 {lid_y-8} 116 {lid_y+15}V{lid_y+lid_h}Z" fill="url(#wood)" stroke="#251626" stroke-width="3"/>'
    b+=f'<path d="M27 {lid_y+lid_h}V{lid_y-3}H38V{lid_y+lid_h}ZM89 {lid_y+lid_h}V{lid_y-3}H101V{lid_y+lid_h}Z" fill="url(#gold)"/>'
    b+=f'<path d="M12 {lid_y+lid_h}H116" stroke="#ffdf78" stroke-width="5"/><rect x="55" y="{lid_y+lid_h-6}" width="19" height="22" rx="3" fill="url(#gold)" stroke="#7d4e19" stroke-width="2"/><circle cx="64" cy="{lid_y+lid_h+4}" r="3" fill="#41291e"/>'
    frames.append(f'<g transform="translate({128*i},0)">{b}</g>')
svg('chest_atlas',''.join(frames),768,128)

# Twelve-frame hand-shaped explosion atlas, layered lobes and burning fragments.
frames=[]
for i in range(12):
    t=i/11
    b=''
    radius=14+43*min(1,t*2)
    alpha=(1-t)**.65
    b+=f'<circle cx="64" cy="64" r="{min(63,radius+12)}" fill="url(#glow)" opacity="{alpha}"/>'
    for j in range(11):
        a=j*math.tau/11+.18
        d=radius*.53
        x,y=64+math.cos(a)*d,64+math.sin(a)*d
        r=(15+7*math.sin(j*3.1))*min(1,(t+.15)*3)*(1-t*.55)
        b+=f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r:.1f}" fill="{["#ff5623","#ff9138","#ffd576"][j%3]}" opacity="{alpha:.3f}"/>'
    b+=f'<circle cx="64" cy="64" r="{max(0,25*(1-t*1.6))}" fill="#fff9d3" opacity="{alpha}"/>'
    for j in range(7):
        a=j*math.tau/7
        x,y=64+math.cos(a)*radius,64+math.sin(a)*radius
        b+=f'<path d="M{x:.1f} {y:.1f}l{math.cos(a)*6:.1f} {math.sin(a)*6:.1f}" stroke="#ffeeb7" stroke-width="{max(1,4*(1-t))}" opacity="{alpha}"/>'
    frames.append(f'<g transform="translate({i*128},0)">{b}</g>')
svg('explosion_atlas',''.join(frames),1536,128)

# Catalog order corresponds exactly to the approved triangular combination tables.
text=(ROOT/'docs'/'스킬_이펙트_애니메이션_기획.md').read_text(encoding='utf-8-sig')
passives=['power','pierce','blast','lightning','frost','critical','wall','corrosion','bounty','split','resonance','ricochet']
actives=['laser','bomb','freeze','mark','overclock','pulse','missile','echo']
names=['파워 코어','관통','폭발','연쇄 번개','서리','크리티컬','월 차지','부식','현상금 회로','분열 코어','공명 코어','리바운드','레이저','폭격','빙결 파동','표적 지정','오버클럭','펄스 캐논','유도 미사일','에코 발사']
catalog=[]
for key,name in zip(passives+actives,names):
    catalog.append(dict(id=key,name=name,category='passive' if key in passives else 'active',sources=[key],description='기본 스킬 전용 연출'))
rebound_names=['반동 발전기','재진입 화살','리바운드 폭격','반동 뇌격','서리 반동','치명적 재진입','왕복 동력로','산성 반동','보물 재도전','반동 증식체','반동 공명']
for section,end,ids,category in [('# 5. 패시브 융합','# 6. 액티브 융합',passives,'passive_fusion'),('# 6. 액티브 융합','# 7.',actives,'active_fusion')]:
    block=text.split(section,1)[1].split(end,1)[0]
    rows=[(m[0].strip(),m[1].strip()) for m in re.findall(r'^\| ([^|]+) \| ([^|]+) \|$',block,re.M) if m[0].strip()!='융합']
    pairs=[(a,b) for i,a in enumerate(ids) for b in ids[i+1:]]
    assert len(rows)==len(pairs),(len(rows),len(pairs))
    for (name,desc),(a,b) in zip(rows,pairs):
        if b=='ricochet':
            name=rebound_names[ids.index(a)]
            desc=f'바닥에서 반사한 공에 {names[passives.index(a)]} 연출을 결합. REBOUND 텍스트와 재진입 궤적 표시.'
        catalog.append(dict(id=a+'__'+b,name=name,category=category,sources=[a,b],description=desc))
assert len(catalog)==114
(ROOT/'data'/'vfx_catalog.json').write_text(json.dumps(catalog,ensure_ascii=False,indent=2),encoding='utf-8')
(OUT/'LICENSE.txt').write_text('Original project artwork, authored for Rogue Breaker. SVG sources and build script included. No third-party artwork.\n',encoding='utf-8')
print(f'Built {len(list(OUT.glob("*.svg")))} SVG assets / atlases; {len(catalog)} effect recipes.')
