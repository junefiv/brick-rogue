# VFX 구현 현황 · 0.4.0

## 전투에 연결된 항목

- 기본 패시브 12종: 파워·발사 시 관통·격자 폭탄·번개·결빙·CRITICAL!·월 차지·부식·보물상자·분열·공명·리바운드.
- 기본 액티브 8종: 반사 레이저·폭격·빙결·표적·오버클럭·십자 펄스·유도탄·에코 발사.
- 기존 관통 폭탄과 궤도 폭격도 새 폭발·광선 에셋을 사용한다.
- 멀티 볼 구매는 패시브 슬롯을 차지하지 않는다. 이전 멀티 볼 데이터는 저장 호환용으로 남아 있다.

## 연출 라이브러리와 전투 규칙의 구분

융합 66+28종은 각각 별도 타임라인을 가지며 VFX STUDIO에서 선택·재생할 수 있다. `fusion_choreography.gd`는 피해를 계산하지 않는 연출 라이브러리다. 게임의 기존 융합 시스템에는 아직 94개 전체의 피해·조건·밸런스 규칙이 연결되어 있지 않다. 새로운 융합 94개를 모두 전투에서 획득할 수 있다는 의미가 아니다.

기본 스킬의 스튜디오 화면에서 **이 기본 스킬 테스트**를 누르면 해당 Lv.5 스킬만 장착한 전투 랩이 열린다. 기본 연출 20종은 실제 전투에서 확인할 수 있다. 융합의 스튜디오 화면은 연출 미리보기다.

## 렌더링 구조

- 직접 제작한 SVG 텍스처 13개: 화살·공·폭탄·미사일·금화·섬광·결정·얼음 프레임·빔·고리·파티클 및 아틀라스.
- 폭발 12프레임, 보물상자 6프레임: AnimatedSprite2D와 AtlasTexture.
- 지속 공·벽돌: Sprite2D. 불꽃과 부식·공명 표면: ShaderMaterial.
- 타격 파편: GPUParticles2D. 액션 글자·폭탄 낙하·금화 분출: Tween.
- 고정 풀: 효과 Actor 48개, 공 표시 128개. 모드별 동시 효과 20/32/48개.
- LOW/섬광 줄이기는 파티클과 불꽃 꼬리를 줄인다. 피해 계산에는 영향이 없다.
- 원본 SVG와 `tools/build_vfx_assets.py`를 포함한다. 외부 상용 에셋은 사용하지 않았다.

## 재현

Godot 4.7.2에서 프로젝트를 연 뒤 실행한다. 메뉴 하단 VFX STUDIO에서 이전/다음/다시 재생을 누른다.

테스트 스크립트: `tests/run_tests.gd`, `tests/ui_test.gd`, `tests/vfx_rules.gd`, `tests/vfx_scene_test.gd`.

검증 결과: 기존 규칙 71개, UI 16개, 신규 VFX 규칙 21개 통과. 114개 연출의 실제 Godot 렌더링 및 고정 풀 크기 검사를 통과했다. Windows AMD OpenGL에서 20초 부하 실행 평균 28.75FPS, 관측 최악 프레임 46.36ms였다. 이 값은 모바일 성능 검증이 아니다. SM-F966N에 0.4.0 업데이트 설치 및 앱 실행을 확인했다. 실행 직후 로그에서 스크립트·셰이더·치명적 오류는 발견되지 않았다. 장시간 모바일 전투 성능은 별도 검증이 필요하다.

## 융합 연출 목록

| ID | 이름 | 상태 |
|---|---|---|
| power__pierce | 초관통포 | 전용 타임라인 · 스튜디오 재생 |
| power__blast | 과충전 핵폭발 | 전용 타임라인 · 스튜디오 재생 |
| power__lightning | 고전압 코어 | 전용 타임라인 · 스튜디오 재생 |
| power__frost | 빙결 분쇄기 | 전용 타임라인 · 스튜디오 재생 |
| power__critical | 초월 코어 | 전용 타임라인 · 스튜디오 재생 |
| power__wall | 반사 증폭기 | 전용 타임라인 · 스튜디오 재생 |
| power__corrosion | 용해 코어 | 전용 타임라인 · 스튜디오 재생 |
| power__bounty | 현상금 사냥꾼 | 전용 타임라인 · 스튜디오 재생 |
| power__split | 중포 분열체 | 전용 타임라인 · 스튜디오 재생 |
| power__resonance | 공명 증폭로 | 전용 타임라인 · 스튜디오 재생 |
| power__ricochet | 반동 발전기 | 전용 타임라인 · 스튜디오 재생 |
| pierce__blast | 관통 폭탄 | 전용 타임라인 · 스튜디오 재생 |
| pierce__lightning | 전도 관통 | 전용 타임라인 · 스튜디오 재생 |
| pierce__frost | 빙창 | 전용 타임라인 · 스튜디오 재생 |
| pierce__critical | 사형선 | 전용 타임라인 · 스튜디오 재생 |
| pierce__wall | 궤도 절삭기 | 전용 타임라인 · 스튜디오 재생 |
| pierce__corrosion | 부식 천공 | 전용 타임라인 · 스튜디오 재생 |
| pierce__bounty | 추적 관통탄 | 전용 타임라인 · 스튜디오 재생 |
| pierce__split | 분열 창 | 전용 타임라인 · 스튜디오 재생 |
| pierce__resonance | 공명 터널 | 전용 타임라인 · 스튜디오 재생 |
| pierce__ricochet | 재진입 화살 | 전용 타임라인 · 스튜디오 재생 |
| blast__lightning | 플라즈마 폭풍 | 전용 타임라인 · 스튜디오 재생 |
| blast__frost | 빙폭 | 전용 타임라인 · 스튜디오 재생 |
| blast__critical | 치명적 연쇄폭발 | 전용 타임라인 · 스튜디오 재생 |
| blast__wall | 반향 폭탄 | 전용 타임라인 · 스튜디오 재생 |
| blast__corrosion | 산성 폭탄 | 전용 타임라인 · 스튜디오 재생 |
| blast__bounty | 황금 폭약 | 전용 타임라인 · 스튜디오 재생 |
| blast__split | 집속탄 | 전용 타임라인 · 스튜디오 재생 |
| blast__resonance | 공명 폭뢰 | 전용 타임라인 · 스튜디오 재생 |
| blast__ricochet | 리바운드 폭격 | 전용 타임라인 · 스튜디오 재생 |
| lightning__frost | 빙뢰 | 전용 타임라인 · 스튜디오 재생 |
| lightning__critical | 천벌 | 전용 타임라인 · 스튜디오 재생 |
| lightning__wall | 벽면 송전 | 전용 타임라인 · 스튜디오 재생 |
| lightning__corrosion | 부식 전류 | 전용 타임라인 · 스튜디오 재생 |
| lightning__bounty | 현상금 뇌격 | 전용 타임라인 · 스튜디오 재생 |
| lightning__split | 분기 번개 | 전용 타임라인 · 스튜디오 재생 |
| lightning__resonance | 공명 낙뢰 | 전용 타임라인 · 스튜디오 재생 |
| lightning__ricochet | 반동 뇌격 | 전용 타임라인 · 스튜디오 재생 |
| frost__critical | 빙결 처형 | 전용 타임라인 · 스튜디오 재생 |
| frost__wall | 빙하 도탄 | 전용 타임라인 · 스튜디오 재생 |
| frost__corrosion | 동상 부식 | 전용 타임라인 · 스튜디오 재생 |
| frost__bounty | 냉동 현상금 | 전용 타임라인 · 스튜디오 재생 |
| frost__split | 서리 분신 | 전용 타임라인 · 스튜디오 재생 |
| frost__resonance | 빙정 공명 | 전용 타임라인 · 스튜디오 재생 |
| frost__ricochet | 서리 반동 | 전용 타임라인 · 스튜디오 재생 |
| critical__wall | 리코셰 헤드샷 | 전용 타임라인 · 스튜디오 재생 |
| critical__corrosion | 괴사 치명타 | 전용 타임라인 · 스튜디오 재생 |
| critical__bounty | 잭팟 | 전용 타임라인 · 스튜디오 재생 |
| critical__split | 치명적 분신 | 전용 타임라인 · 스튜디오 재생 |
| critical__resonance | 임계 공명 | 전용 타임라인 · 스튜디오 재생 |
| critical__ricochet | 치명적 재진입 | 전용 타임라인 · 스튜디오 재생 |
| wall__corrosion | 산성 궤적 | 전용 타임라인 · 스튜디오 재생 |
| wall__bounty | 은행 사격 | 전용 타임라인 · 스튜디오 재생 |
| wall__split | 거울 군단 | 전용 타임라인 · 스튜디오 재생 |
| wall__resonance | 반향 공명 | 전용 타임라인 · 스튜디오 재생 |
| wall__ricochet | 왕복 동력로 | 전용 타임라인 · 스튜디오 재생 |
| corrosion__bounty | 역병 현상금 | 전용 타임라인 · 스튜디오 재생 |
| corrosion__split | 감염 분열체 | 전용 타임라인 · 스튜디오 재생 |
| corrosion__resonance | 부식 공진 | 전용 타임라인 · 스튜디오 재생 |
| corrosion__ricochet | 산성 반동 | 전용 타임라인 · 스튜디오 재생 |
| bounty__split | 복제 채굴기 | 전용 타임라인 · 스튜디오 재생 |
| bounty__resonance | 공명 채권 | 전용 타임라인 · 스튜디오 재생 |
| bounty__ricochet | 보물 재도전 | 전용 타임라인 · 스튜디오 재생 |
| split__resonance | 공명 증식체 | 전용 타임라인 · 스튜디오 재생 |
| split__ricochet | 반동 증식체 | 전용 타임라인 · 스튜디오 재생 |
| resonance__ricochet | 반동 공명 | 전용 타임라인 · 스튜디오 재생 |
| laser__bomb | 궤도 폭격 | 전용 타임라인 · 스튜디오 재생 |
| laser__freeze | 빙결 광선 | 전용 타임라인 · 스튜디오 재생 |
| laser__mark | 정밀 소각 | 전용 타임라인 · 스튜디오 재생 |
| laser__overclock | 초광속 포격 | 전용 타임라인 · 스튜디오 재생 |
| laser__pulse | 프리즘 절단 | 전용 타임라인 · 스튜디오 재생 |
| laser__missile | 광학 유도탄 | 전용 타임라인 · 스튜디오 재생 |
| laser__echo | 잔류 광선 | 전용 타임라인 · 스튜디오 재생 |
| bomb__freeze | 빙하 폭격 | 전용 타임라인 · 스튜디오 재생 |
| bomb__mark | 유도 궤도탄 | 전용 타임라인 · 스튜디오 재생 |
| bomb__overclock | 포화 폭격 | 전용 타임라인 · 스튜디오 재생 |
| bomb__pulse | 충격파 폭탄 | 전용 타임라인 · 스튜디오 재생 |
| bomb__missile | 집속 미사일 | 전용 타임라인 · 스튜디오 재생 |
| bomb__echo | 지연 폭격 | 전용 타임라인 · 스튜디오 재생 |
| freeze__mark | 빙결 사냥 | 전용 타임라인 · 스튜디오 재생 |
| freeze__overclock | 극저온 과급 | 전용 타임라인 · 스튜디오 재생 |
| freeze__pulse | 절대 영도 | 전용 타임라인 · 스튜디오 재생 |
| freeze__missile | 빙창 미사일 | 전용 타임라인 · 스튜디오 재생 |
| freeze__echo | 이중 한파 | 전용 타임라인 · 스튜디오 재생 |
| mark__overclock | 헌터 프로토콜 | 전용 타임라인 · 스튜디오 재생 |
| mark__pulse | 처형 좌표 | 전용 타임라인 · 스튜디오 재생 |
| mark__missile | 섬멸 지정 | 전용 타임라인 · 스튜디오 재생 |
| mark__echo | 끈질긴 추적 | 전용 타임라인 · 스튜디오 재생 |
| overclock__pulse | 과급 펄스 | 전용 타임라인 · 스튜디오 재생 |
| overclock__missile | 극초음속 탄막 | 전용 타임라인 · 스튜디오 재생 |
| overclock__echo | 트윈 드라이브 | 전용 타임라인 · 스튜디오 재생 |
| pulse__missile | 격자 섬멸 | 전용 타임라인 · 스튜디오 재생 |
| pulse__echo | 공명 포격 | 전용 타임라인 · 스튜디오 재생 |
| missile__echo | 귀환 미사일 군단 | 전용 타임라인 · 스튜디오 재생 |
