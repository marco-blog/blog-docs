---
description: "003 포털 작업 목록"
---

# Tasks: 포털 (주제별 글 모아보기와 메인)

**Input**: `/specs/003-portal/`의 설계 문서 (spec.md, plan.md, research.md, data-model.md, contracts/api.md, contracts/routes.md, quickstart.md)

**Prerequisites**: 001-blog-core·002-discovery-feeds 구현 완료(blog-backend·blog-front main. 002 Phase 5~8은 `feat/002-rest`에서 진행 중이며 main 머지 후 시작, 아래 "002 의존"), plan.md, spec.md, research.md, data-model.md, contracts/, 헌법 v2.5.0, [api-guidelines.md](../../api-guidelines.md), [db/README.md](../../db/README.md)

**Tests**: 헌법 원칙 III(NON-NEGOTIABLE)에 따라 모든 스토리에 테스트 작업이 있고, 각 스토리 안에서 테스트 작업이 구현 작업보다 앞선다. 테스트를 먼저 쓰고 **실패하는 것을 확인한 뒤** 구현한다. backend·front 모두 라인 커버리지 80% 미만이면 빌드가 실패한다.

**Organization**: 사용자 스토리(US1~US5)별로 묶었다. US4는 001이 블로그 관리 뼈대를 만든 방식처럼 시스템 관리자 콘솔 뼈대와 003 메뉴(주제·포털 관리)를 함께 만든다(006 spec 머리말, 결정 표 5번). US5의 릴리스 노트 관리 API(001 contracts에 정의)는 backend만 만들고 화면은 006에 남긴다(결정 표 4번).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: 병렬 가능(다른 파일, 끝나지 않은 작업에 의존하지 않음)
- **[Story]**: 해당 사용자 스토리(US1~US5)
- 경로는 저장소 이름(`blog-backend/`, `blog-front/`)으로 시작한다(blog-docs CLAUDE.md 규칙)
- 작업 번호는 이 스펙 안에서 T001부터 센다(001·002 tasks.md와 별개)

## Path Conventions

- backend 소스: `blog-backend/src/main/java/net/java21/blog/backend/{domain}/{controller|service|repository|domain|dto|event|job}/` — 이 스펙의 새 도메인은 `topic`, `portal`, `setting`, `releasenote`, 관리자 API는 `admin/topic`, `admin/portal`, `admin/setting`, `admin/releasenote`(001 `admin/user`와 같은 구성)
- backend 테스트: `blog-backend/src/test/java/net/java21/blog/backend/{domain}/...` (Controller `*ControllerTest` = `@WebMvcTest` + `@Import(WebMvcTestSupport.class)` + `@MockitoBean`, Service `*ServiceTest` = Mockito 단위, Repository `*RepositoryTest` = H2 `@JpaRepositoryTest` + `QueryCounter.assertQueryCount`, MySQL 전용(FULLTEXT·동시 upsert)만 `@MySqlRepositoryTest`, 시각 고정은 `support/MutableClock`, 픽스처는 `support/JpaFixtures`·`support/TestEntities`, 관리자 쿠키는 `support/AuthCookies`)
- backend 리소스: `blog-backend/src/main/resources/`
- front: `blog-front/app/` (routes, components, locales, api, portal, updates, admin, i18n, seo), 단위 테스트 `blog-front/tests/unit/`, E2E `blog-front/tests/e2e/`(backend 필요 시나리오는 `tests/e2e/support/backend.ts`의 `requireBackend()`, 포털 시험 설정이 필요하면 `requirePortalTestSettings()`, 관리자는 `requireAdmin()`)
- 화면 문구는 모두 `blog-front/app/locales/{ko,en,ja,zh-CN}/{namespace}.json` 키로 쓰고 4개 언어를 같은 작업에서 넣는다(원칙 VII). 이 스펙의 새 namespace는 `portal`, `updates`, `admin`. 새 오류 코드는 `blog-front/app/api/errorCodes.ts`와 4개 언어 `errors.json`에 함께 넣는다(`tests/unit/i18n/errorCodes.test.ts`).
- backend 오류 코드는 `blog-backend/src/main/java/net/java21/blog/backend/common/error/ErrorCode.java`에 contracts/api.md 표의 이름·HTTP 상태 그대로 더한다.
- 응답 타입은 `blog-front/app/api/models.ts`에 contracts/api.md를 옮겨 적는다(OpenAPI 생성 스크립트는 001 후속 메모대로 아직 없음).

## 스키마 변경

**DDL 없음.** 003의 테이블(`topics`, `portal_curations`, `portal_exclusions`, `post_daily_stats`, `system_settings`), 001 테이블 추가 컬럼(`users.last_seen_release_version`, `blogs.portal_enabled`·`default_topic_id`·`first_published_at`, `posts.topic_id`, `post_drafts.topic_id`), 006의 릴리스 노트 테이블 3개와 인덱스·외래 키가 Crowfoot 문서 "blog 1.0"(`db/schema-mysql.sql`)에 모두 있다(plan.md "스키마 변경"의 쿼리별 대조표). 엔티티는 기존 스키마에 맞춰 만든다(`ddl-auto=validate`, `EntitySchemaValidationTest`).

**marco 승인이 필요한 것** (plan.md "스키마 변경"에 정확한 SQL):
- 제안 인덱스 3개(`idx_posts_status_visibility_published`, `idx_post_likes_created`, `idx_comments_created`): T130 성능 측정에서 필요할 때만 Crowfoot `plan_migration` → **marco 승인** → `apply_migration` 절차로 요청한다. 승인 전에는 구현하지 않는다.
- `blogs.first_published_at` 보정 UPDATE(데이터 변경, DDL 아님): T131에서 `migrations/`에 SQL로 남기고 승인 후 실행한다.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: front 번역·타입 틀, E2E 도구, 초기 주제 데이터

- [ ] T001 [P] 새 번역 namespace 파일 `blog-front/app/locales/{ko,en,ja,zh-CN}/portal.json`, `blog-front/app/locales/{ko,en,ja,zh-CN}/updates.json`, `blog-front/app/locales/{ko,en,ja,zh-CN}/admin.json`을 같은 키 집합의 뼈대로 추가(이후 작업이 키를 채움, `tests/unit/i18n/translations.test.ts`가 4개 언어 키 일치 확인)
- [ ] T002 [P] contracts/api.md 003 타입을 `blog-front/app/api/models.ts`에 추가: `TopicNode`(`names: Record<Language, string>`), `PortalCard`, `PortalHome`, `PopularTag`, `NewBlog`, `AdminTopicNode`, `Curation`, `CurationStatus`, `Exclusion`, `AdminPortalPost`, `Setting`, `ScoreWeights`, `ReleaseNoteSummary`, `ReleaseNoteDetail`, `ReleaseNoteSearchHit`, `ReleaseNoteRevision`, `Blog`의 `portalEnabled`·`defaultTopicId`, `PostDetail`·`Draft`의 `topicId`, `PublishSettings`·`DraftWrite`의 `topicId`
- [ ] T003 [P] E2E 도구 `blog-front/tests/e2e/support/backend.ts`에 추가: `requirePortalTestSettings()`(`E2E_PORTAL_TEST_SETTINGS=1`이 아니면 건너뜀), `requireAdmin()`·`adminAccount()`(`E2E_ADMIN_EMAIL`·`E2E_ADMIN_PASSWORD`, 없으면 건너뜀), `portalText(n)`(포털 최소 길이를 넘는 본문 생성), `publishPost`에 `topicId`·`thumbnail` 선택 인자, `topicIdBySlug(request, slug)`(GET /topics)
- [ ] T004 [P] 초기 주제 목록 `blog-backend/src/main/resources/portal/topics-seed.json`: research P2 표의 대분류 5개·소분류 39개(slug, 순서, ko·en·ja·zh-CN 이름 모두, 대분류 `cardColor`, `it-internet`·`mobile`·`it-product-review`의 `pinnedOnTab: true`). 티스토리 현행 목록과의 최종 대조는 marco의 운영 작업(결정 표 6번)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: 모든 스토리가 쓰는 엔티티 매핑, 포털 노출 조각, 운영 설정, 주제 트리 API, 오류 코드, 공개 경로

**⚠️ CRITICAL**: 이 Phase가 끝나기 전에는 어떤 스토리도 시작하지 않는다

### Tests for Foundation ⚠️

> 먼저 쓰고 실패를 확인한다

- [ ] T005 [P] `blog-backend/src/test/java/net/java21/blog/backend/portal/repository/PortalColumnsMappingTest.java`(`@JpaRepositoryTest`): `Topic`(부모·4개 언어 이름·`adminHidden`·`pinnedOnTab`·`cardColor`), `PortalCuration`, `PortalExclusion`(`post_id`만), `PostDailyStat`(복합 키), `SystemSetting`(JSON 값), `ReleaseNote`·`ReleaseNoteContent`·`ReleaseNoteRevision`을 저장 후 다시 읽기; 새 블로그의 `portalEnabled` true·`defaultTopic` null·`firstPublishedAt` null, `Post.topic`, `PostDraft.topicId`, `User.lastSeenReleaseVersion` 매핑
- [ ] T006 [P] `blog-backend/src/test/java/net/java21/blog/backend/portal/repository/PortalExposureRepositoryTest.java`(`@JpaRepositoryTest`): `PortalExposure.portalVisible(criteria)`가 001 노출 매트릭스 행 전부(PRIVATE·DRAFT·DELETED·작성자 SUSPENDED·WITHDRAWN·삭제된 블로그)와 FR-088 조건 다섯 가지(블로그 포털 끔, 제외 행 있음, 가입 후 `newMemberDelay` 미만 — 경계 포함, 본문 텍스트 `minContentLength` 미만 — 한글 문자 수 기준, 정상)를 거르는지, 같은 픽스처에서 자바 `PortalExposure.evaluate`의 결과·이유 목록이 쿼리 결과와 같은지, 쿼리 1회 (research P1, SC-004)
- [ ] T007 [P] `blog-backend/src/test/java/net/java21/blog/backend/setting/service/SystemSettingsServiceTest.java`: 행이 없으면 `PortalProperties` 기본값, 행이 있으면 그 값; 키별 형식·범위 검증(`portal.score-weights` 필드 누락·음수·`halfLifeHours` 0, `portal.new-member-delay` 형식·범위, 정수 범위)과 `VALIDATION_FAILED` field·`INVALID`+`params`, 모르는 키 404 `SETTING_NOT_FOUND`, 저장·삭제 후 캐시 무효화와 `PortalChangedEvent` 발행 (research P3)
- [ ] T008 [P] `blog-backend/src/test/java/net/java21/blog/backend/topic/TopicSeederTest.java`(`@JpaRepositoryTest` + `TopicSeeder`): 처음 실행 시 대분류 5·소분류 39와 초기 고정 3개, 다시 실행하면 0건 추가, 운영자가 바꾼 이름·순서·숨김을 덮어쓰지 않음, 이름 하나라도 빈 seed는 기동 실패(예외), slug 형식·중복 검사
- [ ] T009 [P] `blog-backend/src/test/java/net/java21/blog/backend/topic/repository/TopicQueryRepositoryTest.java`(`@JpaRepositoryTest`): 전체 트리를 대분류·소분류 `sort_order` 순으로 쿼리 1회, 공개 트리는 운영자 숨김 주제와 숨긴 대분류의 소분류 제외, slug로 찾기, 대분류의 소분류 id 목록(숨김 제외)
- [ ] T010 [P] `blog-backend/src/test/java/net/java21/blog/backend/topic/service/TopicServiceTest.java`: `requireSelectable(id, currentId)`(소분류·숨김 아님·부모 숨김 아님, 아니면 422 `TOPIC_NOT_SELECTABLE`, 없으면 404 `TOPIC_NOT_FOUND`, `currentId`와 같으면 검사 생략); `onTab` 판단(소분류: 숨김 아님 AND (고정 OR 글 수 ≥ 기준), 대분류: 숨김 아님 AND (고정 OR 소분류 합 ≥ 기준 OR 탭에 보이는 소분류 있음), 기준 0이면 모두 보임) (research P2, FR-147, SC-023)
- [ ] T011 [P] `blog-backend/src/test/java/net/java21/blog/backend/topic/controller/TopicControllerTest.java`: `GET /api/v1/topics` 비로그인 200 `[TopicNode]`(`names` 4개 언어, `cardColor`, `onTab`, 소분류 `children: []`)
- [ ] T012 [P] `blog-backend/src/test/java/net/java21/blog/backend/security/PortalPathsWebMvcTest.java`(테스트 컨트롤러 + `WebMvcTestSupport`, 002 `DiscoveryPathsWebMvcTest` 방식): 비로그인 허용 GET `/api/v1/topics`, `/api/v1/topics/{slug}/posts`, `/api/v1/portal`, `/api/v1/portal/latest`, `/api/v1/release-notes`, `/api/v1/release-notes/search`, `/api/v1/release-notes/{version}/revisions/{n}`; 비로그인 허용 POST `/api/v1/posts/{id}/read-complete`(Origin 검사는 받음, 403 `ORIGIN_NOT_ALLOWED`); 로그인 필요 `POST /api/v1/me/release-notes/seen`(401); `/api/v1/admin/topics`·`/api/v1/admin/portal/**`·`/api/v1/admin/settings/**`·`/api/v1/admin/release-notes/**`는 일반 회원·비로그인 404 `NOT_FOUND`
- [ ] T013 [P] `blog-front/tests/unit/portal/topics.test.ts`: 화면 언어로 이름 고르기(없으면 en → ko), slug로 찾기, 소분류의 부모 확인, 카드 색(소분류 null → 대분류, 주제 없음 → 기본 회색), 발행 설정용 그룹(대분류별 소분류)

### Implementation for Foundation

- [ ] T014 `ErrorCode.java`에 `TOPIC_NOT_FOUND`(404), `TOPIC_NOT_SELECTABLE`(422), `TOPIC_SLUG_TAKEN`(409), `TOPIC_DEPTH_EXCEEDED`(422), `CURATION_NOT_FOUND`(404), `CURATION_LIMIT_EXCEEDED`(409), `POST_NOT_PORTAL_ELIGIBLE`(422), `PORTAL_EXCLUSION_NOT_FOUND`(404), `SETTING_NOT_FOUND`(404)와 001 표의 `RELEASE_NOTE_NOT_FOUND`(404), `RELEASE_NOTE_VERSION_TAKEN`(409), `RELEASE_NOTE_REVISION_CONFLICT`(409), `RELEASE_NOTE_ONCE_PUBLISHED`(409), `RELEASE_NOTE_VERSION_LOCKED`(422) 추가: `blog-backend/src/main/java/net/java21/blog/backend/common/error/ErrorCode.java`
- [ ] T015 [P] 주제 엔티티 `blog-backend/src/main/java/net/java21/blog/backend/topic/domain/Topic.java`(parent LAZY, slug `updatable=false`, `name_ko`·`name_en`·`name_ja`·`name_zh_cn`, `card_color` `char(7)`, `BaseTimeEntity`, `rename`·`changeColor`·`hide`·`unhide`·`pin`·`unpin`·`moveTo(sortOrder)`), `blog-backend/src/main/java/net/java21/blog/backend/topic/repository/TopicRepository.java`, QueryDSL `TopicQueryRepository.java`·`TopicRow.java`, DTO `blog-backend/src/main/java/net/java21/blog/backend/topic/dto/TopicNode.java`
- [ ] T016 [P] 001 엔티티 매핑: `blog-backend/src/main/java/net/java21/blog/backend/blog/domain/Blog.java`(`portal_enabled`, `default_topic_id` LAZY `Topic`, `first_published_at`, `changePortalSettings`, `markFirstPublished(Instant)` NULL일 때만), `blog-backend/src/main/java/net/java21/blog/backend/post/domain/Post.java`(`topic_id` LAZY `Topic`, `assignTopic`), `blog-backend/src/main/java/net/java21/blog/backend/post/domain/PostDraft.java`(`topic_id` Long, 외래 키 없음), `blog-backend/src/main/java/net/java21/blog/backend/user/domain/User.java`(`last_seen_release_version`). 네 클래스의 "003 컬럼은 매핑하지 않는다" 주석을 고침
- [ ] T017 [P] 포털 엔티티 `blog-backend/src/main/java/net/java21/blog/backend/portal/domain/PortalCuration.java`(post·createdBy LAZY, 기간·순서, `reschedule`), `blog-backend/src/main/java/net/java21/blog/backend/portal/domain/PortalExclusion.java`(post LAZY UNIQUE, reason, excludedBy, `changeReason`)와 `blog-backend/src/main/java/net/java21/blog/backend/portal/repository/PortalCurationRepository.java`·`PortalExclusionRepository.java`
- [ ] T018 [P] 일별 통계 `blog-backend/src/main/java/net/java21/blog/backend/post/domain/PostDailyStat.java`(`PostDailyStatId.java` post_id·stat_date, post 쪽 `@OnDelete(CASCADE)`)와 `blog-backend/src/main/java/net/java21/blog/backend/post/repository/PostDailyStatsRepository.java`(`@Modifying` 네이티브 `upsertView(postId, date)`·`upsertReadComplete(postId, date)` — `INSERT ... ON DUPLICATE KEY UPDATE`, `deleteOlderThan(date, limit)`)
- [ ] T019 [P] 운영 설정: `blog-backend/src/main/java/net/java21/blog/backend/setting/domain/SystemSetting.java`(`value_json` `@JdbcTypeCode(SqlTypes.JSON)`, updatedBy LAZY), `blog-backend/src/main/java/net/java21/blog/backend/setting/repository/SystemSettingRepository.java`, `blog-backend/src/main/java/net/java21/blog/backend/setting/SettingKey.java`(003 키 4개, 형식 검증기·기본값 공급자), `blog-backend/src/main/java/net/java21/blog/backend/setting/service/SystemSettingsService.java`(메모리 캐시, `get`·`set`·`reset`), `blog-backend/src/main/java/net/java21/blog/backend/portal/PortalProperties.java`(`blog.portal.*`, contracts/api.md "프로퍼티"), `blog-backend/src/main/java/net/java21/blog/backend/portal/event/PortalChangedEvent.java`, `blog-backend/src/main/resources/application.yml`에 `blog.portal.*`
- [ ] T020 [P] 릴리스 노트 엔티티 `blog-backend/src/main/java/net/java21/blog/backend/releasenote/domain/ReleaseNote.java`(version·major·minor·patch, status `ReleaseNoteStatus.java` DRAFT·PUBLISHED, `current_revision_no`, `first_published_at`·`first_published_revision_no`·`published_at`, createdBy·updatedBy LAZY), `ReleaseNoteContent.java`(복합 키 `ReleaseNoteContentId.java` note·lang, `toc_json`), `ReleaseNoteRevision.java`(불변, `contents_json`), `blog-backend/src/main/java/net/java21/blog/backend/releasenote/repository/ReleaseNoteRepository.java`·`ReleaseNoteContentRepository.java`·`ReleaseNoteRevisionRepository.java`
- [ ] T021 포털 노출 조각과 캐시: `blog-backend/src/main/java/net/java21/blog/backend/portal/repository/PortalExposure.java`(`portalVisible(PortalCriteria)`, `evaluate(Post, PortalCriteria, boolean)`·`PortalIneligibility.java`), `blog-backend/src/main/java/net/java21/blog/backend/portal/service/PortalCriteria.java`·`PortalCriteriaFactory.java`(Clock + `SystemSettingsService`), `blog-backend/src/main/java/net/java21/blog/backend/portal/service/PortalCache.java`(Caffeine, `blog.portal.cache-ttl`·`cache-max-size`, `0s`면 통과, `invalidateAll`, 테스트용 `Ticker`), `PortalChangedEvent`의 `@TransactionalEventListener(AFTER_COMMIT)` 무효화 리스너 `blog-backend/src/main/java/net/java21/blog/backend/portal/event/PortalCacheInvalidator.java`
- [ ] T022 주제 서비스·API: 주제별 최근 30일 포털 노출 글 수 쿼리 `blog-backend/src/main/java/net/java21/blog/backend/portal/repository/TopicPostCountQueryRepository.java`(`PortalExposure` + `published_at >= now - topic-count-window`, `GROUP BY topic_id` 1회), `blog-backend/src/main/java/net/java21/blog/backend/topic/service/TopicService.java`(공개 트리 + `onTab`(캐시), `requireSelectable`, slug 찾기), `blog-backend/src/main/java/net/java21/blog/backend/topic/TopicSeeder.java`(`ApplicationRunner`, seed JSON 읽기, 넣은 수 로그), `blog-backend/src/main/java/net/java21/blog/backend/topic/controller/TopicController.java`(`GET /api/v1/topics`)
- [ ] T023 `blog-backend/src/main/java/net/java21/blog/backend/config/SecurityConfig.java` `PUBLIC_GET`에 `/api/v1/topics`, `/api/v1/topics/*/posts`, `/api/v1/portal`, `/api/v1/portal/latest`, `/api/v1/release-notes`, `/api/v1/release-notes/**`, `PUBLIC_POST`에 `/api/v1/posts/*/read-complete` 추가(나머지 `/api/v1/me/**`·`/api/v1/admin/**`는 기존 규칙)
- [ ] T024 [P] 새 오류 코드 문구: `blog-front/app/api/errorCodes.ts`에 T014의 14개 코드, `blog-front/app/locales/{ko,en,ja,zh-CN}/errors.json`에 4개 언어 문구
- [ ] T025 [P] 주제 도우미 `blog-front/app/portal/topics.ts`(T013의 함수들)와 `blog-front/app/portal/cardColor.ts`

**Checkpoint**: 기반 완료. `./mvnw verify`(MySQL 테스트는 환경 변수가 있을 때), `npm test -- --coverage` 통과, `EntitySchemaValidationTest`가 새 매핑으로 통과, 기동 로그에 주제 seed 결과

---

## Phase 3: User Story 1 - 포털 메인에서 글 둘러보기 (Priority: P1) 🎯 MVP

**Goal**: 방문자가 `/`에서 운영자 추천·주제 탭·인기 글 12편·최신 글(20편씩 더 보기)·인기 태그 20개·새로 시작한 블로그 6개를 보고, 영역마다 같은 블로그 글은 2편까지, 포털 노출 조건을 만족하는 글만 나오며, 스크립트 없이도 HTML에 목록이 들어 있다. 인기 점수는 최근 7일 조회·끝까지 읽음·좋아요·댓글로 계산한다.

**Independent Test**: 여러 블로그에 주제·이미지가 다른 공개 글 30편을 만든 뒤 메인을 열어 각 영역에 조건에 맞는 글만 나오고, 로그아웃 상태에서 스크립트 없이 요청해도 글 목록이 HTML에 들어 있는지 확인(quickstart #1~10).

FR: FR-034, FR-080, FR-085, FR-086, FR-087, FR-088, FR-090, FR-094, FR-095, FR-147(탭) (SC-004, SC-013, SC-014, SC-023)

### Tests for User Story 1 (backend) ⚠️

- [ ] T026 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/post/repository/PostDailyStatsRepositoryTest.java`(`@JpaRepositoryTest`): `upsertView`가 첫 호출에 행 생성(views 1)·다음 호출 증가, `upsertReadComplete`, 날짜가 다르면 새 행, `deleteOlderThan`이 기준일 전 행만 건수 단위로, 각 호출 쿼리 1회
- [ ] T027 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/post/PostDailyStatsConcurrencyTest.java`(`@MySqlRepositoryTest`): 같은 글·같은 날 `upsertView` 20회 동시 → 행 1, views 20 (research P4)
- [ ] T028 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/post/service/ViewCountServiceTest.java`에 추가: 조회수가 늘 때 같은 트랜잭션에서 오늘(UTC, `MutableClock`) `upsertView` 1회, 중복 제거로 세지 않으면 호출 없음
- [ ] T029 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/post/service/ReadCompleteServiceTest.java`: 상세를 볼 수 있는 글만(아니면 404 `POST_NOT_FOUND`, `PostExposure.isDetailVisibleTo`), 같은 방문자 키 30분 안 재요청은 세지 않음(Caffeine `Ticker`), 다른 방문자는 셈, 세면 `upsertReadComplete` 1회
- [ ] T030 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/post/controller/PostControllerTest.java`에 추가: `POST /api/v1/posts/{id}/read-complete` 비로그인 200 `result: null`, 방문자 쿠키가 없으면 발급(001 조회수 API와 같음), 404
- [ ] T031 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/post/job/PostStatsPurgeJobTest.java`: `blog.posts.stats-retention`(90일) 지난 행만 건수 단위 삭제, 처리 건수 로그
- [ ] T032 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/portal/repository/PortalCardQueryRepositoryTest.java`(`@JpaRepositoryTest`): 카드 projection(제목·요약·대표 이미지·`topicId`·블로그 handle·title·작성자 닉네임·프로필 이미지 주소·발행 시각·좋아요·댓글 수), id 목록으로 읽기(순서 유지, 포털 노출 아닌 id는 빠짐), 최신 글 후보(`published_at DESC, id DESC`, 커서 경계에서 같은 발행 시각은 id로 이어짐, `limit`), 쿼리 수가 카드 수와 무관(1회) (FR-085)
- [ ] T033 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/portal/repository/PortalSectionQueryRepositoryTest.java`(`@JpaRepositoryTest`): 인기 태그(최근 7일 발행 포털 노출 글만, 수 내림차순·같으면 이름순, 20개), 새로 시작한 블로그(`first_published_at` 30일 안, 블로그·주인 ACTIVE, 포털 켜짐, 포털 노출 글 1편 이상, 최신순 6개, 주인 프로필 포함), 지금 기간 안 추천(시작 경계 포함·종료 경계 제외, 포털 노출 아닌 글 제외, `sort_order`·id 순), 각 쿼리 1회
- [ ] T034 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/portal/repository/PopularitySignalQueryRepositoryTest.java`(`@JpaRepositoryTest`): 글별 최근 7일 조회·끝까지 읽음 합(`stat_date >= today-6`), 좋아요 수(`created_at >= now-7d`), 댓글 수(삭제·숨김 제외), 후보 글의 발행 시각·블로그·주제(포털 노출만), 각 쿼리 1회
- [ ] T035 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/portal/service/PopularityCalculatorTest.java`: 점수 = 가중합 × `2^(-age/halfLifeHours)` × 감점, 가중치를 `SystemSettingsService`에서 읽음(바꾸면 순서가 바뀜), 조회만 많은 글이 끝까지 읽음·좋아요가 많은 글보다 낮음, 오래된 글일수록 낮음, `BlogPenaltyPolicy`가 0.5를 주면 절반, 점수 0인 글 제외, 점수 내림차순·같으면 발행 최신순 (FR-086)
- [ ] T036 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/portal/service/PerBlogCapTest.java`와 `PortalCursorTest.java`: 블로그별 2편 초과 건너뛰기(순서 유지, `limit`까지, 마지막으로 살펴본 행 반환), 커서 base64url 왕복, 잘못된 커서 400 `VALIDATION_FAILED`(field `cursor`, `INVALID`) (FR-080, research P6)
- [ ] T037 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/portal/service/PortalServiceTest.java`: `home()`이 추천(제한 없음, 최대 5)·인기 12(2편 제한)·최신 20(2편 제한, `nextCursor` = 살펴본 마지막 행, 더 없으면 null)·인기 태그·새 블로그를 묶음, 빈 영역은 `[]`, `latest(cursor)`, 같은 TTL 안 두 번째 호출은 저장소를 부르지 않음, `cache-ttl=0s`면 매번 부름, `invalidateAll` 뒤 다시 계산
- [ ] T038 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/portal/controller/PortalControllerTest.java`: `GET /api/v1/portal` 비로그인 200 `PortalHome`(contracts/api.md 필드), `GET /api/v1/portal/latest?cursor=` 200 `result` 배열 + `nextCursor`(마지막이면 응답에 없음), 잘못된 커서 400
- [ ] T039 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/post/service/PostPublishServiceTest.java`에 추가: 블로그의 첫 발행이 `first_published_at`을 발행 시각으로 채움, 이미 값이 있으면 그대로(두 번째 글·수정 발행), 비공개 발행도 채움(data-model "처음 글을 발행한 시각") (FR-087)
- [ ] T040 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/portal/PortalHomeIntegrationTest.java`(`@SpringBootTest`, H2, `blog.portal.cache-ttl=0s`): 노출 매트릭스 001 행 전부와 FR-088 조건 다섯 가지의 글이 `/api/v1/portal`의 모든 영역·`/portal/latest`에 0건, 정상 글만 나옴, 한 블로그 5편이 영역마다 2편 (SC-004, SC-014)

### Tests for User Story 1 (front) ⚠️

- [ ] T041 [P] [US1] `blog-front/tests/unit/i18n/format.test.tsx`에 추가: `formatRelativeTime(iso, now, language)`가 4개 언어로 "방금"·"N분 전"·"N시간 전"·"N일 전", 7일 넘으면 날짜, 서버 시각 기준이라 SSR·hydration 결과가 같음
- [ ] T042 [P] [US1] `blog-front/tests/unit/components/PortalCard.test.tsx`: 대표 이미지(`/600x400`), 없으면 주제 카드 색 기본 이미지와 주제 이름, 제목·요약(2줄 클래스)·블로그 이름·작성자 프로필·상대 시각·좋아요·댓글 수, 카드 링크 `/{handle}/{id}`, 문구 `portal` namespace
- [ ] T043 [P] [US1] `blog-front/tests/unit/components/PortalSections.test.tsx`: `CurationSection`·`TopicTabs`(`onTab` 대분류만, 화면 언어 이름, `/topics/{slug}` 링크)·`PopularPosts`·`PopularTags`(`/tags/{name}`)·`NewBlogs`가 빈 배열이면 렌더링하지 않음, `LatestPosts`의 "더 보기"는 JS 없으면 `/?cursor=` 링크, 있으면 fetcher로 이어 붙이고 `nextCursor`가 없으면 버튼 없음
- [ ] T044 [P] [US1] `blog-front/tests/unit/routes/home.test.tsx`: loader가 `/portal`·`/topics`·`/release-notes`를 병렬 호출, `/topics`·`/release-notes` 실패 시 해당 영역만 숨김, `/portal` 실패 시 오류 경계, `?cursor=`면 `/portal/latest?cursor=`도 호출, 영역 순서(릴리스 노트 카드 자리 → 추천 → 탭 → 인기 → 최신 → 태그 → 새 블로그), 모두 비면 "첫 글을 써 보세요"(로그인 `/write`, 비로그인 `/signup`), 로그인 회원에게 "구독 피드 보기", meta(서비스명·description·og·canonical `/`, 커서가 있으면 noindex)
- [ ] T045 [P] [US1] `blog-front/tests/unit/components/ReadCompleteTracker.test.tsx`: 감시 요소가 보이면 `POST /api/v1/posts/{id}/read-complete`를 한 번만, 다시 보여도 다시 보내지 않음, `IntersectionObserver`가 없으면 아무것도 안 함, 실패는 무시; `blog-front/tests/unit/routes/postDetail.test.tsx`에 본문 뒤 추적기 배치 확인 추가
- [ ] T046 [P] [US1] E2E `blog-front/tests/e2e/portal-us1-main.spec.ts`(`requireBackend` + `requirePortalTestSettings`): Independent Test(세 블로그 30편 → 영역 순서, 영역마다 블로그 2편 이하), 비공개·삭제 글 없음, 150자 글 없음, "더 보기" 다음 20편, `javaScriptEnabled: false`로 카드 제목·meta 포함, 끝까지 읽기 후 인기 글 반영 (quickstart #2~8, #10)

### Implementation for User Story 1 (backend)

- [ ] T047 [US1] 조회 일별 집계: `blog-backend/src/main/java/net/java21/blog/backend/post/service/ViewCountService.java`의 `record`가 조회수를 올린 같은 트랜잭션에서 `PostDailyStatsRepository.upsertView`(오늘 UTC) 호출
- [ ] T048 [US1] 끝까지 읽음: `blog-backend/src/main/java/net/java21/blog/backend/post/service/ReadCompleteService.java`(별도 Caffeine 중복 캐시, `blog.posts.view-dedup-ttl`·`view-dedup-max-size`), `blog-backend/src/main/java/net/java21/blog/backend/post/controller/PostController.java`에 `POST /posts/{id}/read-complete`(방문자 키·쿠키는 조회수 API와 같은 코드 재사용)
- [ ] T049 [P] [US1] 정리 작업 `blog-backend/src/main/java/net/java21/blog/backend/post/job/PostStatsPurgeJob.java`, `blog-backend/src/main/java/net/java21/blog/backend/common/job/JobsProperties.java`에 `postStatsPurgeCron`(기본 `0 45 4 * * *`), `blog-backend/src/main/java/net/java21/blog/backend/post/PostsProperties.java`에 `statsRetention`(90d), `application.yml`에 두 값
- [ ] T050 [P] [US1] 카드·영역 쿼리: `blog-backend/src/main/java/net/java21/blog/backend/portal/repository/PortalCardQueryRepository.java`·`PortalCardRow.java`, `PortalSectionQueryRepository.java`(인기 태그·새 블로그·추천)·`PopularTagRow.java`·`NewBlogRow.java`, `PopularitySignalQueryRepository.java`·`PopularityCandidateRow.java` (모두 QueryDSL + `PortalExposure`)
- [ ] T051 [US1] 인기 점수: `blog-backend/src/main/java/net/java21/blog/backend/portal/service/BlogPenaltyPolicy.java`(인터페이스)와 `NoBlogPenaltyPolicy.java`(항상 1.0, 005가 바꿈), `ScoreWeights.java`, `PopularityCalculator.java`, `PopularitySnapshot.java`(불변 목록, 주제별 거르기)
- [ ] T052 [US1] `blog-backend/src/main/java/net/java21/blog/backend/portal/service/PerBlogCap.java`, `PortalCursor.java`, `PortalService.java`(`home`, `latest`, 캐시 키 `HOME`·`LATEST:{cursor}`·`POPULARITY`), DTO `blog-backend/src/main/java/net/java21/blog/backend/portal/dto/`(`PortalCardResponse`, `PortalHomeResponse`, `LatestSection`, `PopularTagResponse`, `NewBlogResponse`), `blog-backend/src/main/java/net/java21/blog/backend/portal/controller/PortalController.java`(`/api/v1/portal`, `/api/v1/portal/latest`, `ApiResponse.cursor`)
- [ ] T053 [US1] 첫 발행 시각: `blog-backend/src/main/java/net/java21/blog/backend/post/service/PostPublishService.java`의 `publish`가 `post.getBlog().markFirstPublished(now)` 호출(004 예약 발행도 같은 메서드를 쓰도록 주석)

### Implementation for User Story 1 (front)

- [ ] T054 [P] [US1] `blog-front/app/i18n/format.ts`에 `formatRelativeTime`·`useRelativeTime(now)`
- [ ] T055 [P] [US1] 포털 컴포넌트 `blog-front/app/components/portal/PortalCard.tsx`, `CurationSection.tsx`, `TopicTabs.tsx`, `PopularPosts.tsx`, `LatestPosts.tsx`(`useFetcher`), `PopularTags.tsx`, `NewBlogs.tsx`, `EmptyPortal.tsx`, 커서 링크 `blog-front/app/portal/cursor.ts`, 문구 `portal` namespace(4개 언어)
- [ ] T056 [US1] 포털 메인 `blog-front/app/routes/home.tsx`를 교체(loader 병렬 호출·부분 실패 처리·커서 묶음, meta, 영역 배치, "구독 피드 보기")
- [ ] T057 [US1] `blog-front/app/components/post/ReadCompleteTracker.tsx`를 `blog-front/app/routes/post-detail.tsx`의 본문 뒤에 배치(002 T081·T096 변경 뒤 머지)

**Checkpoint**: US1 Independent Test(E2E)가 통과하고 MVP로 시연 가능

---

## Phase 4: User Story 2 - 주제별로 글 보기 (Priority: P2)

**Goal**: 방문자가 `/topics/{대분류}`·`/topics/{대분류}/{소분류}`에서 그 주제의 글만 최신순·인기순으로 20편씩 보고, 검색 엔진은 주제 이름이 들어간 제목·설명·목록을 받으며, 운영자가 숨긴 주제는 404, 자동 숨김 주제는 정상으로 열린다.

**Independent Test**: "IT 인터넷" 글 3편(A 2, B 1), "모바일" 1편, 주제 없는 1편 발행 → "IT 인터넷" 페이지 3편, "지식·동향" 페이지 4편, 정렬을 바꾸면 순서가 바뀌는지 확인(quickstart #11~16).

FR: FR-078, FR-094, FR-147 (SC-011, SC-012)

### Tests for User Story 2 ⚠️

- [ ] T058 [P] [US2] `blog-backend/src/test/java/net/java21/blog/backend/portal/repository/TopicPostQueryRepositoryTest.java`(`@JpaRepositoryTest`): 소분류 글만·대분류는 소속 소분류 글 전체(운영자 숨김 소분류 제외)·주제 없는 글 제외·포털 노출만, 최신순(`published_at DESC, id DESC`), `page`·`totalCount`, 쿼리 수 고정(목록 1 + 수 1) (FR-078, AS1)
- [ ] T059 [P] [US2] `blog-backend/src/test/java/net/java21/blog/backend/portal/service/TopicPostServiceTest.java`: slug로 주제 찾기(없음·운영자 숨김·부모 숨김 → 404 `TOPIC_NOT_FOUND`), 자동 숨김 주제는 정상, `sort=popular`는 스냅숏을 주제 id 집합으로 거른 순서의 페이지(카드는 id 목록으로 한 번에), `sort` 허용 값 외 400(`params.allowed`), 캐시 키 `TOPIC:{id}:{sort}:{page}`, 같은 블로그 제한 없음 (AS2, AS4, 결정 표 11번)
- [ ] T060 [P] [US2] `blog-backend/src/test/java/net/java21/blog/backend/portal/controller/TopicPostControllerTest.java`: `GET /api/v1/topics/{slug}/posts?sort=&page=` 비로그인 200 Page<PortalCard>, 404, 400
- [ ] T061 [P] [US2] 사이트맵 확장 테스트(002 T063·T064 파일에 추가): `blog-backend/src/test/java/net/java21/blog/backend/seo/repository/SitemapQueryRepositoryTest.java`에 운영자 숨김이 아닌 주제 slug 경로(대분류·소분류 부모 slug), `blog-backend/src/test/java/net/java21/blog/backend/seo/controller/SitemapControllerTest.java`에 `/sitemap/pages.xml`의 `/topics/{major}`·`/topics/{major}/{minor}` 절대 주소(숨긴 주제 없음, `lastmod` 없음) (FR-094)
- [ ] T062 [P] [US2] `blog-front/tests/unit/routes/topic.test.tsx`: `/topics/:major`·`/topics/:major/:minor` loader가 `/topics`와 `/topics/{slug}/posts?sort=&page=` 호출, 트리에 없는 slug·부모가 다른 소분류·대분류 자리의 소분류 404, `TOPIC_NOT_FOUND` 404, 소분류 목록(`onTab`인 것과 "전체"), 정렬 전환 링크(최신순·인기순, 페이지 초기화), 페이지 이동이 `sort` 유지, 인기순 빈 상태 안내, meta(`{주제} - 서비스명`, description, og, canonical, 인기순 noindex)
- [ ] T063 [P] [US2] E2E `blog-front/tests/e2e/portal-us2-topics.spec.ts`(`requireBackend` + `requirePortalTestSettings`): Independent Test(3편·4편, 주제 없는 글 없음), 인기순 전환, `javaScriptEnabled: false`로 제목·목록 포함, 없는 주제·부모가 다른 주소 404, 메인 주제 탭에서 한 번에 대분류 페이지로 이동(SC-011) (quickstart #11~14)

### Implementation for User Story 2

- [ ] T064 [US2] `blog-backend/src/main/java/net/java21/blog/backend/portal/repository/TopicPostQueryRepository.java`(QueryDSL + `PortalExposure`, 카드 projection 재사용)
- [ ] T065 [US2] `blog-backend/src/main/java/net/java21/blog/backend/portal/service/TopicPostService.java`(최신·인기, 캐시)와 `blog-backend/src/main/java/net/java21/blog/backend/portal/controller/TopicPostController.java`(`GET /api/v1/topics/{slug}/posts`)
- [ ] T066 [P] [US2] 사이트맵: 002 `blog-backend/src/main/java/net/java21/blog/backend/seo/repository/SitemapQueryRepository.java`에 주제 경로 조회, `blog-backend/src/main/java/net/java21/blog/backend/seo/service/SitemapWriter.java`(또는 002가 만든 pages 생성 서비스)의 `pages.xml`에 주제 주소 추가 (002 T071 이후)
- [ ] T067 [US2] `blog-front/app/routes/topic.tsx`(SSR, 두 경로 공용), `blog-front/app/components/portal/TopicSubTabs.tsx`·`SortToggle.tsx`(001 `Pagination`·`PortalCard` 재사용), `blog-front/app/routes.ts`에 `route("topics/:major", "routes/topic.tsx", { id: "topic-major" })`, `route("topics/:major/:minor", "routes/topic.tsx", { id: "topic-minor" })`를 `/:handle` 계열보다 앞에, 문구 `portal` namespace

**Checkpoint**: US1·US2가 각각 독립적으로 동작

---

## Phase 5: User Story 3 - 글에 주제 지정하기 (Priority: P3)

**Goal**: 글쓴이가 발행 설정에서 블로그 카테고리와 별개로 주제(소분류)를 고르거나 고르지 않고, 블로그 기본 주제가 새 글에 미리 선택되며, 블로그 단위로 "포털에 내 글 노출"을 끌 수 있다. 발행한 글의 주제를 바꾸면 포털 주제 목록에 반영된다.

**Independent Test**: 블로그 기본 주제를 "국내여행"으로 설정 → 새 글 작성 화면에 "국내여행"이 미리 선택됨 → "선택 안 함"으로 바꿔 발행 → 포털 "국내여행" 페이지에는 없고 최신 글에는 나오는지 확인(quickstart #17~21).

FR: FR-076, FR-077, FR-089

### Tests for User Story 3 ⚠️

- [ ] T068 [P] [US3] `blog-backend/src/test/java/net/java21/blog/backend/post/service/PostDraftServiceTest.java`에 추가: `DraftWrite.topicId`를 작성 중 사본에 그대로 저장(검증 없음, null 허용), `GET /posts/{id}/draft` 응답의 `topicId`(사본 값, 사본이 없으면 발행본 값)
- [ ] T069 [P] [US3] `blog-backend/src/test/java/net/java21/blog/backend/post/service/PostPublishServiceTest.java`에 추가: 주제 선택 순서(발행 설정 → 사본 → 발행본), 사본 `null`이면 주제 없음으로 발행, 대분류 422 `TOPIC_NOT_SELECTABLE`, 운영자 숨김·부모 숨김 422, 없는 id 404 `TOPIC_NOT_FOUND`, 지금 발행본과 같은 숨김 주제로 다시 발행은 통과, 검증 실패 시 글이 바뀌지 않음 (FR-076, AS1·2·5)
- [ ] T070 [P] [US3] `blog-backend/src/test/java/net/java21/blog/backend/post/service/PostServiceTest.java`·`post/controller/PostControllerTest.java`에 `PostDetail.topicId` 추가 확인
- [ ] T071 [P] [US3] `blog-backend/src/test/java/net/java21/blog/backend/blog/service/BlogServiceTest.java`·`blog/controller/BlogControllerTest.java`에 추가: `GET /blogs/{handle}`의 `portalEnabled`·`defaultTopicId`, `PATCH`의 `portalEnabled`(null이면 400 `REQUIRED`), `defaultTopicId`(null이면 지움, 대분류·숨김 422, 없는 id 404, 같은 값 통과), 주인만(403) (FR-077, FR-089)
- [ ] T072 [P] [US3] `blog-backend/src/test/java/net/java21/blog/backend/portal/PortalTopicFlowIntegrationTest.java`(`@SpringBootTest`, H2, `cache-ttl=0s`): 주제 없이 발행 → 최신 글에 있고 주제 페이지에 없음, 주제를 바꿔 다시 발행 → 새 주제 페이지에 있고 이전 주제 페이지에 없음, 블로그 포털 끔 → 포털 어디에도 없고 `/blogs/{handle}/posts`·피드에는 있음 (AS2·4·5)
- [ ] T073 [P] [US3] `blog-front/tests/unit/components/TopicSelect.test.tsx`: 대분류별로 묶은 소분류 옵션(화면 언어 이름), "선택 안 함", 운영자 숨김 주제는 `GET /topics`에 없으므로 옵션 없음, 지금 값이 목록에 없으면(나중에 숨겨진 주제) "현재 주제(숨김)" 옵션으로 유지, 라벨 `post:topic.*`
- [ ] T074 [P] [US3] `blog-front/tests/unit/routes/write.test.tsx`에 추가: 새 글은 블로그 `defaultTopicId`가 미리 선택되고 첫 사본 저장에 `topicId` 포함, 수정 글은 그 글의 `topicId`, 발행 설정 레이어에 "카테고리"와 "주제"가 따로 있고 주제를 바꾸면 작성 중 사본을 `topicId`로 저장(카테고리 `onClassify`와 같은 방식), `TOPIC_NOT_SELECTABLE` 문구 (AS1·3)
- [ ] T075 [P] [US3] `blog-front/tests/unit/routes/manage.test.tsx`에 블로그 설정 추가: "포털에 내 글 노출" 켜기·끄기와 안내 문구, 기본 주제 선택·"선택 안 함", 저장 시 `PATCH /blogs/{handle}` `{ portalEnabled, defaultTopicId }`; `blog-front/tests/unit/routes/postDetail.test.tsx`에 주제가 있는 글의 주제 링크(`/topics/{major}/{minor}`, 화면 언어 이름)
- [ ] T076 [P] [US3] E2E `blog-front/tests/e2e/portal-us3-topic-select.spec.ts`(`requireBackend` + `requirePortalTestSettings`): Independent Test 전체, 주제 변경 후 새 주제 페이지에 나옴, 포털 끔 → 포털에 없고 블로그 홈·RSS에 있음 (quickstart #17~19, #21)

### Implementation for User Story 3

- [ ] T077 [US3] 작성 중 사본·발행 설정: `blog-backend/src/main/java/net/java21/blog/backend/post/dto/DraftWriteRequest.java`·`PublishSettingsRequest.java`에 `topicId`, `blog-backend/src/main/java/net/java21/blog/backend/post/dto/DraftResponse.java`에 `topicId`, `blog-backend/src/main/java/net/java21/blog/backend/post/service/PostDraftService.java`가 사본에 저장
- [ ] T078 [US3] `blog-backend/src/main/java/net/java21/blog/backend/post/service/PostPublishService.java`에 주제 선택·`TopicService.requireSelectable` 검증(글을 바꾸기 전)·`Post.assignTopic`, `blog-backend/src/main/java/net/java21/blog/backend/post/dto/PostDetailResponse.java`·`post/service/PostService.java`에 `topicId`
- [ ] T079 [US3] 블로그 포털 설정: `blog-backend/src/main/java/net/java21/blog/backend/blog/dto/UpdateBlogRequest.java`에 `portalEnabled`·`defaultTopicId`(Merge Patch 표시, 002 T095 뒤), `blog-backend/src/main/java/net/java21/blog/backend/blog/dto/BlogResponse.java`에 두 값, `blog-backend/src/main/java/net/java21/blog/backend/blog/service/BlogService.java`의 `update`가 `Blog.changePortalSettings` 호출
- [ ] T080 [P] [US3] `blog-front/app/components/post/TopicSelect.tsx`, `blog-front/app/components/post/PublishSettingsDialog.tsx`에 주제 선택 연결, `blog-front/app/routes/write.tsx`(loader에 `/topics`, 새 글 기본 주제, 사본 저장에 `topicId`), 문구 `post` namespace(4개 언어)
- [ ] T081 [P] [US3] `blog-front/app/routes/manage/settings.tsx`에 포털 노출·기본 주제(문구 `manage` namespace), `blog-front/app/routes/post-detail.tsx`에 주제 링크(loader에 `/topics`, 실패 시 링크 생략)

**Checkpoint**: US1~US3이 각각 독립적으로 동작

---

## Phase 6: User Story 4 - 운영자 큐레이션과 주제 관리 (Priority: P4)

**Goal**: 관리자가 시스템 관리자 콘솔(`/admin`)에서 메인 추천 글을 기간·순서와 함께 지정하고, 주제를 추가·이름 변경·순서 변경·숨김·탭 고정하며, 글을 포털에서만 제외하고, 포털 설정값(인기 점수 가중치·노출 조건값·자동 숨김 기준)을 바꾼다. 모든 변경은 작업 기록에 남고 포털에 바로 반영된다.

**Independent Test**: 관리자가 글 3편을 추천으로 지정(종료일 내일) → 메인 상단에 지정 순서대로 나옴 → 종료일이 지나면 사라지는지, 포털 제외한 글이 메인·주제 페이지에서 사라지지만 블로그에는 남는지 확인(quickstart #22~31).

FR: FR-079, FR-086, FR-088, FR-091, FR-092, FR-093, FR-147 (006 FR-097·102·106의 003 범위)

### Tests for User Story 4 ⚠️

- [ ] T082 [P] [US4] `blog-backend/src/test/java/net/java21/blog/backend/admin/topic/AdminTopicServiceTest.java`: 추가(대분류·소분류, 같은 부모의 마지막 순서, slug 형식·중복 409 `TOPIC_SLUG_TAKEN`, 소분류 아래 422 `TOPIC_DEPTH_EXCEEDED`, 없는 부모 404, 4개 언어 이름 필수·50자, 색 형식), 수정(이름 일부 언어만, 색 지움, 숨김·고정 전환, slug·부모는 요청에 없음), 순서(그 부모의 자식 전체가 아니면 400), 작업 기록 동작 코드(`TOPIC_CREATE`·`TOPIC_UPDATE`·`TOPIC_REORDER`·`TOPIC_HIDE`·`TOPIC_UNHIDE`·`TOPIC_PIN`·`TOPIC_UNPIN`, 바뀐 항목마다 한 행, 전후 값), `PortalChangedEvent` 발행 (FR-079, AS3)
- [ ] T083 [P] [US4] `blog-backend/src/test/java/net/java21/blog/backend/admin/portal/repository/CurationQueryRepositoryTest.java`(`@JpaRepositoryTest`): 상태별(ACTIVE·UPCOMING·ENDED·전체) 목록과 정렬, 작성자 닉네임 포함, 주어진 기간과 겹치는 추천 수(자기 자신 제외 옵션, 경계 `[starts, ends)`), 제외 목록(글·블로그·처리자), 쿼리 수 고정
- [ ] T084 [P] [US4] `blog-backend/src/test/java/net/java21/blog/backend/admin/portal/AdminCurationServiceTest.java`: 포털 노출 조건을 만족하지 않는 글 422 `POST_NOT_PORTAL_ELIGIBLE`(이유는 메시지), 없는 글 404, `endsAt <= startsAt` 400, 겹치는 추천 5개면 409 `CURATION_LIMIT_EXCEEDED`(수정 시 자기 제외), 응답의 `status`·`portalEligible`, 삭제, 없는 추천 404 `CURATION_NOT_FOUND`, 작업 기록 `CURATION_CREATE`·`CURATION_UPDATE`·`CURATION_DELETE`, 이벤트 발행 (FR-091, FR-092)
- [ ] T085 [P] [US4] `blog-backend/src/test/java/net/java21/blog/backend/admin/portal/AdminExclusionServiceTest.java`: PUT이 없으면 만들고 있으면 사유만 바꿈(멱등, 행 1), 사유 1~500자, 글 상태와 무관(DELETED 글도), 없는 글 404, DELETE는 행 삭제·없으면 404 `PORTAL_EXCLUSION_NOT_FOUND`, 작업 기록 `PORTAL_EXCLUDE`·`PORTAL_UNEXCLUDE`(전후 사유), 이벤트 발행; 글 조회 `GET /admin/portal/posts/{id}`의 `portalEligible`·`ineligibleReasons`·`excluded` (FR-093)
- [ ] T086 [P] [US4] `blog-backend/src/test/java/net/java21/blog/backend/admin/setting/AdminSettingServiceTest.java`: 목록(`prefix`), 저장·기본값으로(DELETE, 행 없어도 200) 응답 `Setting`(`value`·`defaultValue`·`overridden`·`updatedBy`), 작업 기록 `SETTING_CHANGE`(`target_type=SETTING`, `target_key`), `blog-backend/src/main/java/net/java21/blog/backend/admin/audit/AdminAuditService.java`의 키 대상 기록 메서드 확인
- [ ] T087 [P] [US4] 관리자 컨트롤러 테스트 `blog-backend/src/test/java/net/java21/blog/backend/admin/topic/AdminTopicControllerTest.java`, `blog-backend/src/test/java/net/java21/blog/backend/admin/portal/AdminPortalControllerTest.java`(추천·제외·글 조회), `blog-backend/src/test/java/net/java21/blog/backend/admin/setting/AdminSettingControllerTest.java`: contracts/api.md 응답 형식·상태 코드(201 + `Location`, 200 `null`, 400·404·409·422), `Cache-Control: no-store`; `blog-backend/src/test/java/net/java21/blog/backend/admin/AdminAccessWebMvcTest.java`에 003 관리자 경로의 일반 회원·권한 회수 회원 404 추가
- [ ] T088 [P] [US4] `blog-backend/src/test/java/net/java21/blog/backend/portal/PortalAdminChangeIntegrationTest.java`(`@SpringBootTest`, H2, 캐시 켬 5m + `MutableClock`·Caffeine `Ticker`): 관리자 포털 제외·주제 숨김·추천 지정·설정 변경은 다음 `/api/v1/portal` 요청에 바로 반영, 글 비공개 전환은 TTL 전에는 남고 5분 뒤 빠짐(FR-090, SC-013), 추천 종료 시각이 지나면 추천 영역에서 빠짐, 숨긴 주제 페이지 404 (AS1·2·4·5)
- [ ] T089 [P] [US4] `blog-front/tests/unit/routes/admin.test.tsx`: `/admin/**` 비로그인 `/login?next=`, 세션 role USER는 404, backend 404(권한 회수)도 404, `/admin` → `/admin/topics`, 좌측 메뉴가 주제·포털 추천·포털 제외·포털 설정 4개만, 모두 noindex
- [ ] T090 [P] [US4] `blog-front/tests/unit/routes/adminTopics.test.tsx`: 트리(숨김·실효 숨김·고정·최근 30일 글 수), 추가 폼(slug·4개 언어 이름·색) `intent=create`, 이름·색 수정, 숨김·해제, 고정·해제, 위·아래 이동이 `PUT /admin/topics/order`에 그 부모의 전체 순서를 보냄, `TOPIC_SLUG_TAKEN`·`TOPIC_DEPTH_EXCEEDED`·필드 오류 문구
- [ ] T091 [P] [US4] `blog-front/tests/unit/routes/adminCurations.test.tsx`와 `blog-front/tests/unit/admin/postRef.test.ts`: 글 주소(절대·상대)·번호에서 글 번호 꺼내기, `intent=lookup`이 `/admin/portal/posts/{id}`로 제목·노출 여부·이유 표시, 추가(기간은 화면 시간대 → UTC), 상태 탭, 수정·삭제, `CURATION_LIMIT_EXCEEDED`·`POST_NOT_PORTAL_ELIGIBLE` 문구, 노출 조건을 잃은 추천 표시
- [ ] T092 [P] [US4] `blog-front/tests/unit/routes/adminExclusions.test.tsx`(목록·제외(사유 필수)·사유 수정·해제·`PORTAL_EXCLUSION_NOT_FOUND`)와 `blog-front/tests/unit/routes/adminSettings.test.tsx`(가중치 6개 값·대기 시간(시간 단위 입력 → ISO 기간)·최소 길이·자동 숨김 기준, 기본값 표시, 저장·"기본값으로", 필드 오류 문구)
- [ ] T093 [P] [US4] E2E `blog-front/tests/e2e/portal-us4-admin.spec.ts`(`requireBackend` + `requirePortalTestSettings` + `requireAdmin`): 일반 회원 `/admin` 404, Independent Test(추천 3편 순서대로 → 종료 시각을 과거로 고치면 사라짐), 6번째 추천 409, 포털 제외 → 메인·주제 페이지에서 빠지고 블로그 홈에 남음 → 해제, 주제 이름 변경·숨김이 글쓰기 주제 목록과 메인 탭에 반영 (quickstart #22~28)

### Implementation for User Story 4 (backend)

- [ ] T094 [P] [US4] 작업 기록 키 대상: `blog-backend/src/main/java/net/java21/blog/backend/admin/audit/AdminAuditService.java`에 `recordKey(adminId, action, targetType, targetKey, before, after, requestIp)`, 003 동작 코드 상수 `blog-backend/src/main/java/net/java21/blog/backend/admin/audit/AuditActions.java`(006 data-model 표의 003 행)
- [ ] T095 [US4] 주제 관리: `blog-backend/src/main/java/net/java21/blog/backend/admin/topic/AdminTopicService.java`, `AdminTopicController.java`(`/api/v1/admin/topics`, `/order`, `/{id}`), DTO `blog-backend/src/main/java/net/java21/blog/backend/admin/topic/dto/`(`CreateTopicRequest`, `UpdateTopicRequest`(Merge Patch 표시), `TopicOrderRequest`, `AdminTopicNode`)
- [ ] T096 [US4] 추천: `blog-backend/src/main/java/net/java21/blog/backend/admin/portal/repository/CurationQueryRepository.java`·`CurationRow.java`·`ExclusionRow.java`, `blog-backend/src/main/java/net/java21/blog/backend/admin/portal/AdminCurationService.java`, `AdminCurationController.java`(`/api/v1/admin/portal/curations`), DTO `blog-backend/src/main/java/net/java21/blog/backend/admin/portal/dto/`(`CreateCurationRequest`, `UpdateCurationRequest`, `CurationResponse`)
- [ ] T097 [US4] 포털 제외·글 조회: `blog-backend/src/main/java/net/java21/blog/backend/admin/portal/AdminExclusionService.java`, `AdminExclusionController.java`(`/api/v1/admin/portal/exclusions/{postId}`), `AdminPortalPostController.java`(`/api/v1/admin/portal/posts/{id}`), DTO `ExclusionRequest`·`ExclusionResponse`·`AdminPortalPostResponse`
- [ ] T098 [US4] 운영 설정: `blog-backend/src/main/java/net/java21/blog/backend/admin/setting/AdminSettingService.java`, `AdminSettingController.java`(`/api/v1/admin/settings`, `/{key}`), DTO `SettingValueRequest`·`SettingResponse`
- [ ] T099 [P] [US4] robots: 002 `blog-backend/src/main/java/net/java21/blog/backend/seo/controller/RobotsController.java`에 `Disallow: /admin`(002 T071 이후), `blog-backend/src/test/java/net/java21/blog/backend/seo/controller/SitemapControllerTest.java`의 robots 확인에 추가

### Implementation for User Story 4 (front)

- [ ] T100 [US4] 콘솔 뼈대: `blog-front/app/admin/access.server.ts`(`requireAdmin`: 로그인·role 확인, 아니면 404 응답), `blog-front/app/admin/links.ts`(003 메뉴 4개), `blog-front/app/routes/admin/layout.tsx`(좌측 메뉴·noindex), `blog-front/app/routes/admin/index.ts`(→ `/admin/topics`), `blog-front/app/routes.ts`에 `route("admin", "routes/admin/layout.tsx", [...])`를 `/:handle` 계열보다 앞에, 문구 `admin` namespace
- [ ] T101 [P] [US4] `blog-front/app/routes/admin/topics.tsx`(트리·폼·`action` intent들)
- [ ] T102 [P] [US4] `blog-front/app/admin/postRef.ts`, `blog-front/app/routes/admin/curations.tsx`(경로 `admin/portal/curations`), `blog-front/app/routes/admin/exclusions.tsx`(경로 `admin/portal/exclusions`)
- [ ] T103 [P] [US4] `blog-front/app/routes/admin/settings.tsx`(경로 `admin/portal/settings`)

**Checkpoint**: US1~US4가 각각 독립적으로 동작. 006은 이 레이아웃·메뉴 목록에 나머지 메뉴를 더한다

---

## Phase 7: User Story 5 - 서비스 업데이트 소식(릴리스 노트) 읽기 (Priority: P5)

**Goal**: 관리자가 게시한 릴리스 노트를 포털 메인 카드(게시 14일 이내)·로그인 회원 상단 배너(마지막 확인 버전보다 새 버전, 기기 간 공유)·`/updates` 위키(버전 트리·목차·앵커·이전/다음·검색·수정 이력)로 읽는다. 화면 언어판이 없으면 en → ko 판을 표시와 함께 보여준다. 관리 API(backend)는 001 contracts대로 만들고 화면은 006에 남긴다.

**Independent Test**: 관리자가 v1.2.0(ko·en), v1.2.1(ko), v1.3.0을 게시 → 비로그인 포털 메인에 v1.3.0 카드, `/updates`에 "1.3"·"1.2" 트리, `/updates/v1.2.0#…` 앵커로 그 절이 열림, 일본어 화면에서 v1.2.0은 영어판·v1.2.1은 한국어판, 회원이 배너를 닫은 뒤 다른 기기에서도 배너가 없음(quickstart #32~42).

FR: FR-161, FR-162, FR-163, FR-164, FR-165, FR-166 (006 FR-167·168 backend API)

### Tests for User Story 5 ⚠️

- [ ] T104 [P] [US5] `blog-backend/src/test/java/net/java21/blog/backend/releasenote/service/ReleaseNoteRendererTest.java`: h2~h4에 앵커 `id`(소문자, 공백 → `-`, 기호 제거, 한글·한자·가나 유지, 같은 노트 안 중복 `-2`·`-3`), `toc`(level·text·anchor, h1·h5 제외), 001 변환·살균과 같은 결과(스크립트·`on*`·`javascript:` 제거, 동영상 허용 목록), 앵커 형식이 아닌 `id`·제목 외 요소의 `id`는 제거; `blog-backend/src/test/java/net/java21/blog/backend/content/MarkdownRendererTest.java`에 회원 글 본문은 여전히 `id`를 허용하지 않음 추가 (research P11)
- [ ] T105 [P] [US5] `blog-backend/src/test/java/net/java21/blog/backend/releasenote/repository/ReleaseNoteQueryRepositoryTest.java`(`@JpaRepositoryTest`): 게시 노트를 (major, minor, patch) 숫자 순(1.10.0 > 1.9.0), 초안 제외, 이전·다음, 최신 노트, 노트 id 목록의 언어판을 한 번에, 처음 게시 수정본부터의 수정 이력(번호·시각), 조건부 갱신(`current_revision_no = base`)의 영향 행 수, 쿼리 수 고정
- [ ] T106 [P] [US5] `blog-backend/src/test/java/net/java21/blog/backend/releasenote/repository/ReleaseNoteSearchRepositoryTest.java`(`@MySqlRepositoryTest`): `MATCH(title, content_text)`로 (노트, 언어) 일치 행, 한글 2자 낱말, 두 낱말 AND, 초안 제외
- [ ] T107 [P] [US5] `blog-backend/src/test/java/net/java21/blog/backend/admin/releasenote/AdminReleaseNoteServiceTest.java`: 만들기(DRAFT, 수정본 1, `version` 형식 `INVALID_FORMAT`, ko 필수 `contents.ko` `REQUIRED`, 한 언어판은 제목·본문 모두, 중복 409 `RELEASE_NOTE_VERSION_TAKEN`), 수정(`baseRevisionNo` 다르면 409 `RELEASE_NOTE_REVISION_CONFLICT`, 새 수정본, 언어판 키를 빼면 삭제, 게시 이력 후 버전 변경 422 `RELEASE_NOTE_VERSION_LOCKED`), 게시(처음이면 `first_published_at`·`first_published_revision_no`, 다시 게시해도 유지, 이미 게시면 변화 없음), 게시 중단, 삭제(한 번도 게시하지 않은 초안만, 아니면 409 `RELEASE_NOTE_ONCE_PUBLISHED`, 수정본 함께 삭제), 미리보기(저장 없음), 수정본 목록·내용, 모든 쓰기의 작업 기록(006 data-model)과 `PortalChangedEvent` (006 FR-167·168)
- [ ] T108 [P] [US5] `blog-backend/src/test/java/net/java21/blog/backend/releasenote/service/ReleaseNoteQueryServiceTest.java`: 언어판 대체(요청 → en → ko, `lang`·`requestedLang`), `lang` 허용 값 외 400, `portalCard`(최신 노트 `firstPublishedAt` 14일 경계, `MutableClock`), 게시 노트가 없으면 `{ items: [], portalCard: null }`, 상세 초안·없음 404 `RELEASE_NOTE_NOT_FOUND`, `revisionCount`, 수정본 상세(처음 게시 전 수정본 404, `contents_json`에서 언어판 고르고 다시 변환), 검색(고른 언어판에서만 일치한 노트, 버전 내림차순 페이지, `snippet` 160자 이내·일치 낱말 포함, `q` 2~100자 400) (FR-161, FR-162, FR-164~166)
- [ ] T109 [P] [US5] `blog-backend/src/test/java/net/java21/blog/backend/releasenote/service/ReleaseNoteSeenServiceTest.java`와 `blog-backend/src/test/java/net/java21/blog/backend/user/repository/LastSeenReleaseVersionRepositoryTest.java`(`@JpaRepositoryTest`): 게시되지 않은 버전 404, 저장값보다 높을 때만 갱신(NULL → 갱신, 같거나 낮으면 변화 없이 200), SemVer 숫자 비교(1.10.0 > 1.9.0), 읽은 값 기준 조건부 UPDATE가 동시 갱신에서 낮은 값으로 덮어쓰지 않음 (FR-163)
- [ ] T110 [P] [US5] `blog-backend/src/test/java/net/java21/blog/backend/user/service/MeQueryServiceTest.java`·`user/controller/MeControllerTest.java`에 `unseenReleaseNote` 추가: 최신 게시 노트가 마지막 확인 버전보다 높고 가입 뒤 게시면 `{ version, title }`(회원 locale 언어판, 대체 규칙), 확인 버전이 같거나 높으면 null, 가입 전 게시면 null, 노트 없으면 null, 쿼리 2회 이내 추가 (FR-163, AS2)
- [ ] T111 [P] [US5] 컨트롤러 테스트 `blog-backend/src/test/java/net/java21/blog/backend/releasenote/controller/ReleaseNoteControllerTest.java`(독자 API 6개, `{version}` 형식이 아니면 404, `/search`가 `{version}`과 겹치지 않음, `POST /me/release-notes/seen` 200 `null`·401·404)와 `blog-backend/src/test/java/net/java21/blog/backend/admin/releasenote/AdminReleaseNoteControllerTest.java`(관리 API 9개, 201 + `Location`, DELETE 200 `null`, 409·422)
- [ ] T112 [P] [US5] 사이트맵 테스트(002 파일에 추가): `blog-backend/src/test/java/net/java21/blog/backend/seo/controller/SitemapControllerTest.java`에 `/sitemap/pages.xml`의 게시 노트 `/updates/v{version}`(`lastmod` = 노트 `updated_at`, 초안 없음) (FR-164)
- [ ] T113 [P] [US5] `blog-front/tests/unit/updates/versionTree.test.ts`: `items`를 major.minor로 묶기(새 버전 위, 묶음 안도 새 버전 위), 1.10 > 1.9, 현재 버전 표시
- [ ] T114 [P] [US5] `blog-front/tests/unit/routes/updates.test.tsx`: 레이아웃(트리·검색창), `/updates` 최신 버전 본문·목차·canonical `/updates/v{최신}`, 노트 없음 안내, `?q=` 검색 결과·`VALIDATION_FAILED` 문구·noindex, `/updates/:version` 형식 오류·`RELEASE_NOTE_NOT_FOUND` 404, 로그인이면 loader가 `POST /me/release-notes/seen`, 비로그인은 안 부름, 대체 언어판 표시, 이전·다음 링크, 제목 `id`가 HTML에 그대로, "수정 이력"은 `revisionCount >= 2`일 때, `/history` 목록(관리자 이름 없음)·`/history/:revisionNo` 이전 수정본 표시, meta(제목·description·og·canonical, 이력 noindex)
- [ ] T115 [P] [US5] `blog-front/tests/unit/components/ReleaseNoteBanner.test.tsx`(버전·제목·"보기" 링크, 닫기 폼이 `/updates/seen`에 `version`·`next`, JS가 있으면 fetcher로 숨김), `blog-front/tests/unit/routes/updatesSeen.test.ts`(action이 seen API 호출 후 안전한 `next`로 리다이렉트, 외부 주소는 `/`), `blog-front/tests/unit/root.test.tsx`에 로그인 회원의 `unseenReleaseNote` 배너·비로그인 없음, `blog-front/tests/unit/components/ReleaseNoteCard.test.tsx`(포털 카드)와 `tests/unit/routes/home.test.tsx`에 `portalCard`가 있을 때 맨 위 카드
- [ ] T116 [P] [US5] `blog-front/tests/unit/lint/noDanger.test.ts`에 `dangerouslySetInnerHTML` 허용 파일로 `app/routes/updates/version.tsx`·`app/routes/updates/revision.tsx` 추가(그 밖의 파일은 여전히 실패)
- [ ] T117 [P] [US5] E2E `blog-front/tests/e2e/portal-us5-updates.spec.ts`(`requireBackend` + `requireAdmin`): 관리 API로 v1.2.0(ko·en)·v1.2.1(ko)·v1.3.0 게시 → 비로그인 메인 카드·`/updates` 트리·앵커 주소, `lang` 쿠키 ja로 언어판 대체 표시, 회원 배너 닫기 → 새 브라우저 컨텍스트에서 로그인해도 배너 없음, 초안 주소 404, 검색 (quickstart #32~36, #38~39)

### Implementation for User Story 5 (backend)

- [ ] T118 [US5] 변환: `blog-backend/src/main/java/net/java21/blog/backend/content/HtmlSanitizerPolicy.java`에 `releaseNotes()` 변형(h2~h4 `id` 앵커 정규식만 허용), `blog-backend/src/main/java/net/java21/blog/backend/releasenote/service/ReleaseNoteRenderer.java`(commonmark `AttributeProvider`로 앵커, `TocEntry.java`)
- [ ] T119 [US5] 관리 API: `blog-backend/src/main/java/net/java21/blog/backend/admin/releasenote/AdminReleaseNoteService.java`(006 data-model 저장 규칙, 작업 기록, 이벤트), `AdminReleaseNoteController.java`(`/api/v1/admin/release-notes/**`), DTO `blog-backend/src/main/java/net/java21/blog/backend/admin/releasenote/dto/`(`ReleaseNoteWriteRequest`, `UpdateReleaseNoteRequest`, `AdminReleaseNoteResponse`, `AdminReleaseNoteSummary`, `AdminRevisionResponse`, `PreviewRequest`·`PreviewResponse`)
- [ ] T120 [US5] 독자 API: `blog-backend/src/main/java/net/java21/blog/backend/releasenote/repository/ReleaseNoteQueryRepository.java`·`ReleaseNoteSearchRepository.java`(002 `MySqlFullTextFunctions.matchTitleContent`, 002 `SearchQueryParser` 재사용), `blog-backend/src/main/java/net/java21/blog/backend/releasenote/service/ReleaseNoteQueryService.java`, `ReleaseNoteLanguage.java`(대체 순서), `SemVer.java`, DTO `blog-backend/src/main/java/net/java21/blog/backend/releasenote/dto/`(`ReleaseNoteListResponse`, `ReleaseNoteSummary`, `ReleaseNoteDetailResponse`, `ReleaseNoteSearchHit`, `ReleaseNoteRevisionItem`), `blog-backend/src/main/java/net/java21/blog/backend/releasenote/controller/ReleaseNoteController.java`
- [ ] T121 [US5] 마지막 확인 버전: `blog-backend/src/main/java/net/java21/blog/backend/user/repository/UserRepository.java`에 조건부 갱신(`last_seen_release_version <=> :old`), `blog-backend/src/main/java/net/java21/blog/backend/releasenote/service/ReleaseNoteSeenService.java`, `ReleaseNoteController`에 `POST /api/v1/me/release-notes/seen`; `blog-backend/src/main/java/net/java21/blog/backend/user/service/MeQueryService.java`가 `unseenReleaseNote` 계산(`MeResponse` 주석의 "003 전까지 null" 고침)
- [ ] T122 [P] [US5] 사이트맵: 002 `SitemapQueryRepository`·`SitemapWriter`의 `pages.xml`에 게시 노트 버전 주소(002 T071 이후)

### Implementation for User Story 5 (front)

- [ ] T123 [P] [US5] `blog-front/app/updates/versionTree.ts`, `blog-front/app/components/updates/VersionTree.tsx`·`Toc.tsx`·`ReleaseNoteSearch.tsx`·`LanguageEditionNotice.tsx`, 문구 `updates` namespace(4개 언어)
- [ ] T124 [US5] `/updates` 라우트: `blog-front/app/routes/updates/layout.tsx`, `index.tsx`, `version.tsx`, `history.tsx`, `revision.tsx`, `seen.ts`, `blog-front/app/routes.ts`에 `route("updates", "routes/updates/layout.tsx", [index(...), route("seen", ...), route(":version", ...), route(":version/history", ...), route(":version/history/:revisionNo", ...)])`를 `/:handle` 계열보다 앞에, `eslint.config.js`의 `react/no-danger` 예외 목록에 두 파일
- [ ] T125 [US5] 배너·카드: `blog-front/app/components/layout/ReleaseNoteBanner.tsx`를 `blog-front/app/root.tsx` 공통 레이아웃(상단 아래)에 연결(`SessionUser.unseenReleaseNote`는 001에 이미 있음), `blog-front/app/components/portal/ReleaseNoteCard.tsx`를 `blog-front/app/routes/home.tsx` 맨 위에, 문구 `updates` namespace

**Checkpoint**: US1~US5가 각각 독립적으로 동작

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: 여러 스토리에 걸친 노출·계약·성능·운영 문서 확인

- [ ] T126 [P] `blog-backend/src/test/java/net/java21/blog/backend/integration/PortalExposureIntegrationTest.java`(`@SpringBootTest`, H2, `cache-ttl=0s`): 노출 매트릭스 001 행 전체와 FR-088 조건 다섯 가지, 포털 제외 글을 포털 메인 모든 영역·최신 커서·주제 페이지(최신·인기)·인기 태그·새 블로그·추천에서 한 번에 확인(포털 노출 0건, SC-004·013), 같은 글이 블로그 목록·RSS·사이트맵에는 그대로(포털 제외·포털 끔은 포털 열에만 영향, 001 매트릭스 주석)
- [ ] T127 [P] `blog-backend/src/test/java/net/java21/blog/backend/openapi/OpenApiContractTest.java`에 contracts/api.md의 003 엔드포인트(공개 5, 릴리스 노트 독자 6, 관리자 24)와 001 응답 확장 필드(`portalEnabled`, `defaultTopicId`, `topicId`, `unseenReleaseNote`) 확인 추가
- [ ] T128 [P] `blog-backend/src/test/java/net/java21/blog/backend/security/CacheHeadersWebMvcTest.java`에 `POST /api/v1/me/release-notes/seen`·`/api/v1/admin/**` 003 응답 `no-store` 확인 추가
- [ ] T129 [P] 운영 문서 `blog-backend/docs/operations.md`에 003 프로퍼티(`blog.portal.*`, `blog.jobs.post-stats-purge-cron`, `blog.posts.stats-retention`), 정기 작업 목록, 주제 seed와 티스토리 목록 대조 절차, 포털 설정의 우선순위(`system_settings` → 프로퍼티), 캐시 반영 시간. front 4개 언어 README(`blog-front/README.md`·`README.en.md`·`README.ja.md`·`README.zh-CN.md`)에 E2E 환경 변수(`E2E_PORTAL_TEST_SETTINGS`, `E2E_ADMIN_EMAIL`, `E2E_ADMIN_PASSWORD`)와 E2E용 backend 설정(quickstart "준비" 2)
- [ ] T130 포털 성능 확인(SC-012): 글 10만 편·회원 1만 데이터에서 `/`·주제 페이지 p95 1초 이내(캐시 기본값), 캐시를 비운 첫 계산 시간과 주요 쿼리의 `EXPLAIN`을 기록. 측정 도구는 저장소에 추가하지 않고 절차와 결과를 backend PR 설명에 기록(quickstart #44). 기준을 넘거나 10만 행 이상 전체 스캔이면 plan.md "스키마 변경"의 제안 인덱스를 Crowfoot `plan_migration`으로 만들어 **marco 승인**을 받은 뒤 db/README 절차로 반영(새 작업으로)
- [ ] T131 `blogs.first_published_at` 보정: plan.md "스키마 변경"의 UPDATE를 `blog-docs/db/migrations/NNNN-backfill-first-published-at.sql`(날짜·문서 버전·승인자 주석)로 blog-docs PR에 올리고, **marco 승인** 후 개발 DB에 실행(운영은 003 배포 때 같은 파일). 승인 전에는 실행하지 않는다
- [ ] T132 커버리지 확인: `blog-backend`의 `./mvnw verify`, `blog-front`의 `npm test -- --coverage` 모두 라인 80% 이상
- [ ] T133 `blog-docs/specs/003-portal/quickstart.md` 수동 검증 시나리오 #1~44 전체 실행(backend·front 함께 기동), 끝난 작업을 이 tasks.md에 [x]로 표시

---

## 구현 전 결정 사항 (2026-10-06 확정)

marco가 "묻지 말고 진행"하라고 해서 Claude가 기본값으로 정했다. 바꾸려면 이 표와 관련 문서를 함께 고친다.

| # | 문제 | 결정 | 반영 문서 |
|---|---|---|---|
| 1 | 포털 노출 조건을 어디에 둘지 | `PortalExposure.portalVisible(criteria)` 한 조각(= 001 `bodyVisible()` + 포털 켜짐 + 제외 없음 + 가입 후 대기 + 본문 길이)만 모든 포털 쿼리가 쓴다. 본문 길이는 `CHAR_LENGTH(content_text)`로 계산하고 길이 컬럼을 추가하지 않는다(5분 캐시로 충분). 자바 판단(`evaluate`)은 같은 규칙을 이유 목록과 함께 | research P1 |
| 2 | 반영 시간과 캐시 | Caffeine 5분(`blog.portal.cache-ttl`) 캐시. 글 상태·회원 정지·블로그 포털 끔은 5분 안 반영(FR-090), 관리자 변경(제외·추천·주제·설정·릴리스 노트)은 커밋 후 캐시 전체를 비워 즉시 반영. US3 AS5의 "바로 반영"은 FR-090의 5분 안으로 본다. HTTP 캐시 없음. 테스트·E2E는 `0s` | research P5, contracts/api.md |
| 3 | 인기 점수 공식과 가중치 | `(1·조회 + 5·끝까지 읽음 + 10·좋아요 + 8·댓글) × 2^(-발행 후 시간/48h) × 감점`, 최근 7일. 가중치·반감기·감점 비율은 `portal.score-weights`로 운영자가 바꿈. 점수는 저장하지 않고 5분마다 메모리 스냅숏 | research P4, contracts/api.md |
| 4 | 릴리스 노트 관리 API를 언제 만들지 | 001 contracts에 정의된 관리 API 9개를 003에서 backend만 구현(US5를 시험하려면 게시 경로가 필요). 관리 화면 `/admin/release-notes/**`는 006. 001 결정 8번("003·006 API는 해당 스펙 구현 때")에 따라 `unseenReleaseNote`도 003에서 채운다 | research P11, plan.md 범위 밖 |
| 5 | 관리자 기능의 범위 | 001이 블로그 관리 뼈대를 001에서 만든 것처럼, 시스템 관리자 콘솔 뼈대(`/admin` 레이아웃·접근 규칙)와 003 메뉴(주제, 포털 추천, 포털 제외, 포털 설정)를 003에서 만든다(006 spec 머리말). `/admin`은 006 대시보드 전까지 `/admin/topics`로 리다이렉트. 관리자 API는 001 공통 규칙(DB role 재확인, 아니면 404)과 001 `AdminAuditService` 사용 | research P10·P12, contracts/routes.md |
| 6 | 초기 주제 slug·색·고정 | research P2 표의 slug(대분류 `life`·`travel-food`·`culture`·`sports`·`knowledge`), 대분류 카드 색 5개, 출시 초기 탭 고정은 `it-internet`·`mobile`·`it-product-review`. 4개 언어 이름은 seed 파일에 함께. 티스토리 현행 목록과의 최종 대조는 marco의 운영 작업(seed 파일만 고침) | research P2, T004 |
| 7 | 주제 탭 자동 숨김 판단 | 소분류는 고정이거나 최근 30일 포털 노출 글 수 ≥ 기준(기본 20), 대분류는 고정이거나 소속 합 ≥ 기준이거나 탭에 보이는 소분류가 있을 때 탭에 보인다. 저장하지 않고 캐시로 계산. 자동 숨김 주제의 페이지는 정상으로 열림 | research P2, contracts/api.md `onTab` |
| 8 | 주제 이름의 언어 | `GET /topics`가 4개 언어 이름을 모두 주고 front가 화면 언어로 고른다(없으면 en → ko). 카드에는 `topicId`만 담는다 | research P2·P7 |
| 9 | 인기 점수의 신고·숨김 감점(FR-086) | 신고·숨김 데이터는 005가 만든다. 003은 `BlogPenaltyPolicy` 인터페이스와 "감점 없음" 기본 구현, `reportPenalty` 가중치만 두고 005가 구현을 바꾼다 | research P4, plan.md 범위 밖 |
| 10 | 최신 글 "더 보기"와 2편 제한 | 커서 방식(`nextCursor`, 설계 규칙 4절). 커서는 마지막으로 살펴본 행이며, 2편 제한으로 건너뛴 글은 다음 묶음에도 나오지 않는다. 묶음마다 제한을 새로 센다. JS 없이는 `/?cursor=` 링크 | research P6, contracts/api.md |
| 11 | 주제 페이지의 인기순·2편 제한 | 인기순은 최근 7일 점수가 있는 글만(점수 순), 없으면 빈 상태 안내. 같은 블로그 2편 제한은 메인 영역에만 적용(FR-080 "메인의 각 영역")하고 주제 페이지·추천에는 적용하지 않음 | research P6·P8 |
| 12 | 글 주제 지정 흐름 | 001 카테고리(T169)와 같은 규칙: 작성 중 사본에 저장(검증 없음) → 발행 때 발행 설정 → 사본 → 발행본 순으로 고르고 검증. "선택 안 함"은 사본 `topicId: null`. 지금 발행본과 같은 값(나중에 숨겨진 주제)은 검증 생략. 새 글의 블로그 기본 주제 미리 선택은 front가 첫 사본에 넣는다(backend 자동 채움 없음) | research P9, contracts/api.md |
| 13 | 추천 동시 노출 5편 검사 | 저장할 때 기간이 겹치는 추천 수를 세어 5개 이상이면 409(data-model 방식, 실제 동시 최대보다 보수적). 관리자 동시 저장은 드물어 잠금 없음. 지난 추천은 이력으로 남고 삭제할 수 있음. 추천 영역에는 2편 제한 없음 | research P10 |
| 14 | 포털 제외 API 모양 | `PUT /admin/portal/exclusions/{postId}`(멱등 생성·사유 변경, 설계 규칙 예외는 api.md에 기록), `DELETE`로 해제(행 삭제, 이력은 작업 기록). 글 상태와 무관하게 제외 가능 | contracts/api.md |
| 15 | 운영 설정 API | 키 일반 경로 `GET /admin/settings?prefix=`, `PUT·DELETE /admin/settings/{key}`(DELETE = 기본값으로). 키 목록은 코드(`SettingKey`)가 정하고 005·007이 더함. 모르는 키 404 `SETTING_NOT_FOUND` | research P3, contracts/api.md |
| 16 | 끝까지 읽음 신호 | 새 API `POST /posts/{id}/read-complete`(비로그인 허용, Origin 검사), front가 본문 끝 감시 요소로 한 번 보냄(JS 필요, 받아들인 한계). 중복 제거는 조회수와 같은 30분·방문자 키 | research P4, contracts/api.md |
| 17 | 조회 일별 집계 | 001 조회수 증가와 같은 트랜잭션에서 `post_daily_stats` upsert(H2도 지원). 90일 지난 행은 `PostStatsPurgeJob`(04:45)이 정리 | research P4 |
| 18 | "새로 시작한 블로그" 조건 | `first_published_at` 30일 이내 + 블로그·주인 ACTIVE + 포털 켜짐 + 포털 노출 글 1편 이상, 첫 발행 최신순 6개. `first_published_at`은 발행 트랜잭션에서 NULL일 때만(비공개 발행 포함, 004 예약 발행도 같은 메서드) | research P6, T053 |
| 19 | 기존 블로그의 `first_published_at` | 배포 때 한 번 보정 UPDATE(가장 이른 `published_at`). 데이터 변경이므로 `migrations/`에 SQL로 남기고 **marco 승인 후** 실행 | plan.md "스키마 변경", T131 |
| 20 | 릴리스 노트 앵커와 살균 | backend가 h2~h4에 앵커 `id`와 `toc`를 만들어 저장. 001 살균 정책에 "제목의 앵커 형식 `id`"만 더한 변형 정책을 릴리스 노트에만 씀(회원 글에는 `id` 불허 유지) | research P11, plan.md Complexity Tracking |
| 21 | 마지막 확인 버전 갱신 | `POST /me/release-notes/seen`은 게시 버전만, 저장값보다 높을 때만 읽은 값 기준 조건부 UPDATE(낮아지지 않음). 버전 페이지를 연 로그인 회원은 SSR loader가 호출(배너 닫기와 같은 효과) | research P11, contracts/routes.md |
| 22 | 릴리스 노트 검색 | 노트마다 고른 언어판 한 행에서만 FULLTEXT 일치(다른 언어판에서만 맞는 노트는 제외, 006 data-model). 002 검색어 규칙(2~100자, 낱말 5개 AND) 재사용, 결과는 버전 내림차순 | research P11 |
| 23 | 상대 시각 | front `Intl.RelativeTimeFormat`, loader가 넘긴 서버 시각 기준(SSR·hydration 일치), 7일 넘으면 날짜 | research P7, T041 |
| 24 | 스키마 변경 | DDL 없음. 제안 인덱스 3개는 T130 성능 측정에서 필요할 때만 Crowfoot로 marco 승인 후 반영(plan.md에 정확한 DDL) | plan.md "스키마 변경" |
| 25 | E2E 설정 | E2E용 backend는 `BLOG_PORTAL_CACHE_TTL=0s`, `BLOG_PORTAL_NEW_MEMBER_DELAY=PT0S`, `BLOG_PORTAL_TOPIC_AUTO_HIDE_THRESHOLD=1`로 띄우고 해당 시나리오는 `E2E_PORTAL_TEST_SETTINGS=1`일 때만. 관리자 시나리오는 `E2E_ADMIN_EMAIL`·`E2E_ADMIN_PASSWORD`(bootstrap SUPER_ADMIN)일 때만 | research P14, quickstart.md |
| 26 | 번역 namespace | 새로 `portal`(메인·카드·주제 페이지), `updates`(릴리스 노트·배너), `admin`(콘솔). 발행 설정의 주제는 `post`, 블로그 설정의 포털 항목은 `manage`, 상단은 `common` | research P12 |
| 27 | 사이트맵·robots | 002 `pages.xml`에 운영자 숨김이 아닌 주제 페이지(자동 숨김 포함)와 게시 노트 버전 주소를 더함. robots에 `Disallow: /admin`. 인기순 주제 페이지·`/?cursor=`·`/updates?q=`·수정 이력은 `noindex` | contracts/routes.md |
| 28 | 002 진행 중 작업과의 순서 | 003은 002 Phase 5~8(`feat/002-rest`)이 main에 머지된 뒤 시작. 사이트맵·robots·상단 검색창·`post-detail.tsx`·블로그 설정 파일을 함께 고치므로(아래 "002 의존") 그 뒤에 머지 | plan.md, 이 문서 |
| 29 | 다른 스펙의 일 | 보호 글·예약 발행 처리(004, 노출 조각과 `markFirstPublished`로 자동 연결), 신고 감점 데이터·숨김(005), 콘솔 대시보드·작업 기록 화면·릴리스 노트 관리 화면·나머지 메뉴(006), 외부 글 포털 노출·점수·제외·주제 글 수 합산(007), 개인화 추천·광고·실시간 인기 검색어(스펙 범위 밖) | plan.md "범위 밖" |

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: 001·002가 main에 있어야 함(002 Phase 5~8 머지 후)
- **Foundational (Phase 2)**: Setup의 모델 타입(T002)·seed(T004) 이후. 모든 스토리를 막는다
- **US1 포털 메인 (Phase 3)**: Phase 2 이후. MVP
- **US2 주제 페이지 (Phase 4)**: Phase 2 이후. 카드 projection(T050)·인기 스냅숏(T051)·캐시(T021)를 쓰므로 US1의 T050~T052 이후 권장
- **US3 주제 지정 (Phase 5)**: Phase 2(특히 `TopicService.requireSelectable` T022) 이후. US1·US2 없이도 backend 테스트 가능, E2E는 US1·US2 화면을 씀
- **US4 운영자 (Phase 6)**: Phase 2 이후. 추천·제외 결과 확인은 US1 메인 화면을 씀
- **US5 릴리스 노트 (Phase 7)**: Phase 2(릴리스 노트 엔티티 T020) 이후. 포털 카드(T125)는 US1 `home.tsx`(T056) 이후
- **Polish (Phase 8)**: 원하는 스토리가 모두 끝난 뒤

### 002 의존 (feat/002-rest에서 구현 중인 002 작업)

| 003 작업 | 기대는 002 작업 | 내용 |
|---|---|---|
| T061, T066 (주제 페이지 사이트맵), T112, T122 (버전 페이지 사이트맵) | 002 T063·T064·T071 | `seo/repository/SitemapQueryRepository`, `seo/service/SitemapWriter`, `seo/controller/SitemapController`의 `pages.xml` |
| T099 (robots `/admin`) | 002 T064·T071 | `seo/controller/RobotsController` |
| FR-095 확인(T044·T046, 상단 검색창) | 002 T066·T072 | `components/layout/Header.tsx`의 검색창(003은 고치지 않고 확인만) |
| T057, T081 (`post-detail.tsx`) | 002 T081·T096 | 관련 글·공유·피드 자동 발견 연결 뒤에 머지 |
| T079, T081 (`UpdateBlogRequest`·`BlogResponse`·`BlogService`, `manage/settings.tsx` 인접) | 002 T095·T097 | 피드 설정 필드 추가 뒤에 머지 |
| T120 (릴리스 노트 검색어 해석) | 002 T068 | `search/service/SearchQueryParser` 재사용(이미 main에 있는 `MySqlFullTextFunctions`와 함께) |
| T126~T129 (Polish 공용 파일) | 002 T098~T101 | `integration/*ExposureIntegrationTest` 방식, `OpenApiContractTest`, `CacheHeadersWebMvcTest`, `docs/operations.md` |

### User Story Dependencies

- **US1 (P1)**: Phase 2 이후. 다른 스토리에 의존하지 않음. 001의 Post·Blog·`PostExposure`·조회수, 002의 좋아요(`post_likes`)를 사용
- **US2 (P2)**: Phase 2 이후. US1의 카드·스냅숏을 재사용하지만 독립 테스트 가능(최신순은 US1 없이도 동작)
- **US3 (P3)**: Phase 2 이후. 독립 테스트 가능(주제 페이지 확인은 US2 화면)
- **US4 (P4)**: Phase 2 이후. API는 독립, 결과 확인은 US1·US2 화면
- **US5 (P5)**: Phase 2 이후. 포털 카드 외에는 다른 스토리와 독립

### Within Each User Story

- 테스트를 먼저 쓰고 실패를 확인한 뒤 구현한다(원칙 III)
- 엔티티 → 리포지토리(QueryDSL) → 서비스 → 컨트롤러 → front 라우트 → E2E
- 엔티티를 더할 때마다 `EntitySchemaValidationTest`(실제 스키마 대상 `ddl-auto=validate`)가 통과해야 한다
- 새 화면 문구·오류 코드는 같은 작업에서 4개 언어 번역을 넣는다(원칙 VII)
- 스토리의 E2E(Independent Test)가 통과해야 다음 우선순위로 넘어간다

### Parallel Opportunities

- Setup의 [P] 작업(T001~T004)은 모두 병렬
- Phase 2 테스트(T005~T013)는 모두 [P], 구현은 엔티티(T015~T020)·front 문구(T024·T025)가 병렬
- 각 스토리의 테스트 작업(backend·front)은 모두 [P]
- Phase 2 이후 US3(Phase 5), US4 backend(T094~T098), US5 backend(T118~T122)는 US1과 병렬 가능. 같은 파일(`ErrorCode`, `SecurityConfig`, `PostPublishService`(T053·T078), `BlogService`·`BlogResponse`(T079), `MeQueryService`(T121), `root.tsx`(T125), `home.tsx`(T056·T125), `post-detail.tsx`(T057·T081), `routes.ts`(T067·T100·T124), `PostControllerTest`(T030·T070), `postDetail.test.tsx`(T045·T075), `home.test.tsx`(T044·T115), `errors.json`)을 고치는 작업은 머지 순서를 맞춘다

---

## Parallel Example: User Story 1

```bash
# backend 테스트를 함께 시작:
Task: "PostDailyStatsRepositoryTest in blog-backend/src/test/java/net/java21/blog/backend/post/repository/PostDailyStatsRepositoryTest.java"
Task: "PortalCardQueryRepositoryTest in blog-backend/src/test/java/net/java21/blog/backend/portal/repository/PortalCardQueryRepositoryTest.java"
Task: "PopularityCalculatorTest in blog-backend/src/test/java/net/java21/blog/backend/portal/service/PopularityCalculatorTest.java"
Task: "PortalServiceTest in blog-backend/src/test/java/net/java21/blog/backend/portal/service/PortalServiceTest.java"

# front 테스트를 함께 시작:
Task: "PortalCard.test.tsx in blog-front/tests/unit/components/PortalCard.test.tsx"
Task: "home.test.tsx in blog-front/tests/unit/routes/home.test.tsx"
Task: "ReadCompleteTracker.test.tsx in blog-front/tests/unit/components/ReadCompleteTracker.test.tsx"
```

## Parallel Example: User Story 4

```bash
Task: "AdminTopicServiceTest in blog-backend/src/test/java/net/java21/blog/backend/admin/topic/AdminTopicServiceTest.java"
Task: "AdminCurationServiceTest in blog-backend/src/test/java/net/java21/blog/backend/admin/portal/AdminCurationServiceTest.java"
Task: "AdminExclusionServiceTest in blog-backend/src/test/java/net/java21/blog/backend/admin/portal/AdminExclusionServiceTest.java"
Task: "adminTopics.test.tsx in blog-front/tests/unit/routes/adminTopics.test.tsx"
Task: "adminCurations.test.tsx in blog-front/tests/unit/routes/adminCurations.test.tsx"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1 Setup, Phase 2 Foundational
2. Phase 3 (US1 포털 메인)
3. **멈추고 확인**: US1 Independent Test E2E, quickstart #1~10
4. 시연·배포 가능(주제 없는 글도 최신·인기 영역에 나옴)

### Incremental Delivery

1. Setup + Foundational → 기반 완료(주제 seed, `GET /topics`)
2. US1(Phase 3) → MVP
3. US2(Phase 4) → US3(Phase 5) → US4(Phase 6) → US5(Phase 7), 각 스토리의 E2E 통과 후 다음
4. Polish → 성능 측정(제안 인덱스 승인 여부), `first_published_at` 보정 승인·실행, quickstart 전체 검증

### Parallel Team Strategy

1. 함께 Setup + Foundational
2. Foundational이 끝나면:
   - 개발자 A: Phase 3(US1) → Phase 4(US2)
   - 개발자 B: Phase 5(US3) → Phase 6(US4)
   - 개발자 C: Phase 7(US5)
3. 같은 파일을 고치는 연결 작업은 머지 순서를 맞춘다(Phase Dependencies, 002 의존)

---

## Notes

- [P] = 다른 파일, 끝나지 않은 작업에 의존하지 않음
- [Story] = spec.md 사용자 스토리 추적용
- 각 PR 설명에 스펙 경로 `blog-docs/specs/003-portal`을 적는다(헌법 개발 흐름 6)
- 엔티티는 API 응답으로 직렬화하지 않고 DTO record를 쓴다. 연관관계는 모두 LAZY, 목록은 fetch join 또는 DTO projection, 목록 테스트에는 `QueryCounter`
- 004~007이 더한 컬럼(`posts.password_hash`, `portal_exclusions.external_post_id` 등)은 DB 기본값·NULL 허용이므로 003 엔티티에 매핑하지 않는다
- 포털 캐시·인기 스냅숏은 backend 1대 전제(001 R26)다. 서버를 늘리면 Redis 등으로 바꾸는 계획을 따로 세운다
- 테스트가 실패하는 것을 먼저 확인하고, 작업 단위로 커밋한다
