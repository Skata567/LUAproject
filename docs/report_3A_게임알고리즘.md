# [게임알고리즘(3A)] 기말과제 보고서

## 1. 개요 및 요구사항 매핑표
- **프로젝트 명**: Schattenverlies (그림자 던전)
- **개발 환경**: Lua 5.1 / Love2D 11.5
- **요구사항 매핑표**:
  - [x] 필수 폴더 구조 준수 (src, tests, docs, worklogs 등)
  - [x] 주요 기능 구현
  - [x] 안정성 및 예외 케이스 대응

## 2. 아키텍처 및 모듈 구조
*(주요 파일들의 역할과 어떻게 상호작용하는지 아키텍처를 간략히 서술합니다.)*
- `project/src/main.lua`: 진입점 및 메인 게임 루프, 화면 렌더링, 입력 처리
- `project/src/data/`:
  - `enemy_db.lua`: 적 및 보스 몬스터 데이터 (30종의 일반 적, 4종 보스) [분리 완료]
  - `enemy_races.lua`: 종족별 상성(약점/저항) 및 속성 연산 데이터 [분리 완료]
  - `races.lua`, `classes.lua`: 플레이어 종족 및 직업 (20x20=400종 빌드)
  - `constants.lua`, `drop_tables.lua`: 아이템 드롭 가중치 및 게임 상수
- `project/src/systems/`:
  - `combat.lua`: DCSS 스타일 전투 데미지 연산 및 스킬 계산
  - `ai.lua`: FSM 기반 적 의사결정 및 A* 경로 탐색 알고리즘
  - `party.lua`: 동료 AI 및 경험치/전리품 분배 시스템
  - `map_generator.lua`: 셀룰러 오토마타/BSP 혼합 절차적 던전 생성
  - `quest.lua`, `religion.lua`: 퀘스트 추적 및 신앙 스탯 보정 시스템
- `project/src/`:
  - `inventory.lua`, `equipment.lua`, `item.lua`: 그리드 방식(Tarkov 스타일) 인벤토리 및 장비 관리
  - `fov.lua`, `camera.lua`: Bresenham Raycasting 기반 시야(FOV) 연산 및 카메라 뷰
- `project/tests/`: 핵심 로직을 독립적으로 검증하는 테스트 하네스 (`main.lua`를 통해 14개 테스트 자동 검증)

## 3. 품질 개선 내용 및 한계
*(성능 문제, 로직 에러 등을 어떻게 해결했는지, 남은 한계가 무엇인지 기술합니다.)*
- **개선 내용**: 
  - 절차적 렌더링 도입: 기존 `love.graphics.points`에서 발생하는 11.5 버전 호환 및 블랙스크린 이슈를 해결하고자 `generateProceduralTileset`을 고안해 가상의 타일셋 캔버스를 생성 후 렌더링.
  - 전장의 안개 및 카메라(FOV): Bresenham Raycasting 기반 시야각 알고리즘(`fov.lua`)을 도입하여 타일별 `visibleMap` 및 `exploredMap`을 동적으로 갱신, 플레이어를 따라다니는 카메라 이동 시스템을 구현해 100x100 대형 맵 탐험의 긴장감을 극대화.
  - 다이나믹 바이옴(Biome) 맵 제너레이터: 던전 생성 시 아이템과 몬스터 스폰 테이블(`e.biomes` 필터링)을 실시간 변경하도록 맵 알고리즘 개편.
  - 전면적 아키텍처 리팩토링 및 캡슐화 완성: `main.lua` 단일 파일(약 4500줄)에 집중된 거대 로직을 분할. 의존성 주입(DI) 및 명시적 컨텍스트 객체 전달 패턴으로 치환하여 런타임 안정성을 달성.
  - 적 의사결정 모델(FSM 및 A*): 벽을 뚫고 지나가는 버그를 수정하고, 상태 전이(IDLE, WANDER, CHASE, FLEE) 기반의 FSM을 도입. 추적 및 도망 시 코너에 걸리지 않도록 정통 **A* (A-Star) 길찾기 알고리즘**을 구현함.
- **알려진 이슈 및 한계점**:
  1. A* 길찾기 알고리즘이 100x100 대형 맵에서 잦은 빈도로 연산될 경우 프레임 지연이 발생할 수 있어 최대 탐색 깊이(Iteration Limit)를 200으로 강제 제한했습니다. 이로 인해 극도로 복잡한 미로 구조에서는 타겟을 포기하고 배회(WANDER) 상태로 빠질 수 있는 최적화 트레이드오프가 존재합니다.
  2. `main.lua` 모놀리식 구조: 기존 4,385줄에 달하던 거대 파일을 완화하기 위해 `enemy_db.lua`, `enemy_races.lua` 등 데이터 및 로직 모듈을 지속적으로 분리하는 아키텍처 개선을 진행 중입니다. (Lua 5.1의 60 upvalue 제한 등 컴파일 한계를 회피하기 위함)
  3. 테스트 커버리지 확장 중이나, 전체 UI/렌더링 로직(Drawing)까지는 Test Framework로 자동화하지 못하여 시뮬레이션 테스트(`qa_simulation.lua`)로 모듈 레벨에서만 검증하고 있습니다.

## 4. 데모 영상
- **영상 링크**: (유튜브 등 영상 링크 입력)
