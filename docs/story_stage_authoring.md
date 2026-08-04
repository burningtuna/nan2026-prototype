# 스토리 스테이지 편집

`scenes/story_map_test.tscn`을 Godot 편집기에서 열면 별도 맵 에디터 없이 2D 화면과 Inspector로 스테이지를 구성할 수 있다.

## 배치 노드

- `StoryWalkableArea`: Polygon2D의 점을 편집해 기체가 진입할 수 있는 영역을 만든다. 여러 개를 배치하면 합집합으로 처리한다.
- `StoryBlocker`: 위치와 `blocker_size`로 통행 및 사격을 막는 직사각형 지형을 만든다.
- `StoryDestructibleCover`: `maximum_durability`가 0이 되면 통행과 사격 차단이 해제되는 엄폐물이다.
- `StorySpawnPoint`: 마커 위치에 고정 로드아웃 기체를 생성한다. `PREPLACED`는 시작 배치, `TRIGGERED`는 `spawn_group`이 같은 트리거가 실행될 때 배치한다.
- `StoryTriggerArea`: `area_size` 안에 플레이어가 들어오면 증원 배치, 캠페인 플래그 저장과 시스템 메시지를 실행한다.

## 새 스테이지 만들기

1. `story_map_test.tscn`을 복제한다.
2. `StoryStage.stage_id`와 `SampleAssembly.arena`를 변경한다.
3. `WalkableArea`의 폴리곤 점을 2D 화면에서 편집한다.
4. `Spawns`, `Triggers`, `Geometry` 아래의 기존 노드를 복제하고 Inspector 값을 변경한다.
5. 씬을 직접 실행해 배치와 트리거를 확인한다.

`StorySpawnPoint`의 여섯 파츠 필드는 `data/mech_parts.json`의 ID를 사용한다. 빈 팔 또는 백팩 슬롯은 빈 문자열로 둔다. 출격 가능한 로드아웃이 아니거나 존재하지 않는 ID를 사용하면 실행 시 오류를 출력하고 해당 유닛을 생성하지 않는다.

트리거의 `campaign_flag`는 `GameSession.set_story_flag()`를 통해 `user://story_progress.json`에 즉시 저장된다. 다음 스테이지에서는 `GameSession.story_flag(&"flag_name")`으로 읽는다.

현재 이동 제약은 폴리곤 외부 진입과 직사각형 장애물 통과를 막는다. AI 경로 탐색은 포함하지 않으므로 복잡한 미로보다 넓은 주 경로와 짧은 우회로를 사용한다.
