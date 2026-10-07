---
description: "002 구독과 탐색 작업 목록"
---

# Tasks: 구독과 탐색 (좋아요·구독·피드·검색·RSS)

**Input**: `/specs/002-discovery-feeds/`의 설계 문서 (spec.md, plan.md, research.md, data-model.md, contracts/api.md, contracts/routes.md, quickstart.md)

**Prerequisites**: 001-blog-core 구현 완료(blog-backend·blog-front main), plan.md, spec.md, research.md, data-model.md, contracts/, 헌법 v2.5.0, [api-guidelines.md](../../api-guidelines.md), [db/README.md](../../db/README.md)

**Tests**: 헌법 원칙 III(NON-NEGOTIABLE)에 따라 모든 스토리에 테스트 작업이 있고, 각 스토리 안에서 테스트 작업이 구현 작업보다 앞선다. 테스트를 먼저 쓰고 **실패하는 것을 확인한 뒤** 구현한다. backend·front 모두 라인 커버리지 80% 미만이면 빌드가 실패한다.

**Organization**: 사용자 스토리별로 묶었다. US1은 plan.md 구현 순서의 1·1a 단계를 두 Phase로 나눴다(좋아요·구독·구독 피드 / 알림). 스토리가 없는 FR-068(관련 글)·FR-069(공유)는 "탐색" 스토리인 US2에 붙여 별도 Phase로 뒀다(아래 "구현 전 결정 사항" 18번).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: 병렬 가능(다른 파일, 끝나지 않은 작업에 의존하지 않음)
- **[Story]**: 해당 사용자 스토리(US1~US3)
- 경로는 저장소 이름(`blog-backend/`, `blog-front/`)으로 시작한다(blog-docs CLAUDE.md 규칙)
- 작업 번호는 이 스펙 안에서 T001부터 센다(001 tasks.md와 별개)

## Path Conventions

- backend 소스: `blog-backend/src/main/java/net/java21/blog/backend/{domain}/{controller|service|repository|domain|dto|event|job}/` — 이 스펙의 새 도메인은 `like`, `subscription`, `notification`, `search`, `syndication`, `seo`
- backend 테스트: `blog-backend/src/test/java/net/java21/blog/backend/{domain}/...` (Controller `*ControllerTest` = `@WebMvcTest` + `@Import(WebMvcTestSupport.class)` + `@MockitoBean`, Service `*ServiceTest` = Mockito 단위, Repository `*RepositoryTest` = H2 `@JpaRepositoryTest` + `QueryCounter.assertQueryCount`, MySQL 전용(FULLTEXT·동시성)만 `@MySqlRepositoryTest`, 시각 고정은 `support/MutableClock`, 픽스처는 `support/JpaFixtures`·`support/TestEntities`)
- backend 리소스: `blog-backend/src/main/resources/`
- front: `blog-front/app/` (routes, components, locales, api, seo, share, server), 단위 테스트 `blog-front/tests/unit/`, E2E `blog-front/tests/e2e/`(backend 필요 시나리오는 `tests/e2e/support/backend.ts`의 `requireBackend()`)
- 화면 문구는 모두 `blog-front/app/locales/{ko,en,ja,zh-CN}/{namespace}.json` 키로 쓰고 4개 언어를 같은 작업에서 넣는다(원칙 VII). 이 스펙의 새 namespace는 `discovery`, `notification`. 새 오류 코드는 `blog-front/app/api/errorCodes.ts`와 4개 언어 `errors.json`에 함께 넣는다(`tests/unit/i18n/errorCodes.test.ts`).
- backend 오류 코드는 `blog-backend/src/main/java/net/java21/blog/backend/common/error/ErrorCode.java`에 contracts/api.md 표의 이름·HTTP 상태 그대로 더한다.
- 응답 타입은 `blog-front/app/api/models.ts`에 contracts/api.md를 옮겨 적는다(OpenAPI 생성 스크립트는 001 후속 메모대로 아직 없음).

## 스키마 변경

없음. 002의 테이블(`post_likes`, `blog_subscriptions`, `notifications`), 001 테이블 추가 컬럼(`blogs.subscriber_count`·`feed_item_count`·`feed_content_mode`, `posts.like_count`), FULLTEXT 인덱스 3개와 보조 인덱스·외래 키가 Crowfoot 문서 "blog 1.0"(`db/schema-mysql.sql`)에 모두 있다(plan.md "스키마 변경"의 쿼리별 대조표). 엔티티는 기존 스키마에 맞춰 만들며(`ddl-auto=validate`, `EntitySchemaValidationTest`), 작업 중 스키마 변경이 필요해지면 새 작업을 만들어 [db/README.md](../../db/README.md) 절차(data-model·erd.md 수정 → Crowfoot 문서 → `plan_migration` → **marco 승인** → `apply_migration` → `migrations/NNNN-*.sql` → `schema-mysql.sql`·backend 테스트 스냅숏 갱신 → 엔티티)를 따른다.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: 새 의존성과 front 공통 틀

- [x] T001 [P] ROME `com.rometools:rome` 2.1.0(프로퍼티 `rome.version`)을 `blog-backend/pom.xml`에 추가(research D6, plan Complexity Tracking)
- [x] T002 [P] 새 번역 namespace 파일 `blog-front/app/locales/{ko,en,ja,zh-CN}/discovery.json`, `blog-front/app/locales/{ko,en,ja,zh-CN}/notification.json`을 같은 키 집합의 뼈대로 추가(이후 작업이 키를 채움, `tests/unit/i18n/translations.test.ts`가 4개 언어 키 일치 확인)
- [x] T003 [P] contracts/api.md 002 타입을 `blog-front/app/api/models.ts`에 추가: `LikeState`, `SubscriptionState`, `FeedPost`, `Notification`(`type`은 `string`으로 받아 모르는 값 허용), `SearchPost`, `FeedContentMode`, `Blog`의 `subscriberCount`·`subscribedByMe`·`feedItemCount`·`feedContentMode`, `PostDetail`의 `likeCount`·`likedByMe`
- [x] T004 [P] front 설정 `BLOG_KAKAO_JS_KEY`: `blog-front/.env.example`에 자리표시자와 설명, `blog-front/app/config.server.ts`에 `kakaoJsKey(env)`(빈 값이면 null), 테스트 `blog-front/tests/unit/server/config.test.ts`에 경우 추가

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: 모든 스토리가 쓰는 엔티티 매핑, MATCH 함수, 공개 경로, 오류 코드

**⚠️ CRITICAL**: 이 Phase가 끝나기 전에는 어떤 스토리도 시작하지 않는다

### Tests for Foundation ⚠️

> 먼저 쓰고 실패를 확인한다

- [x] T005 [P] `blog-backend/src/test/java/net/java21/blog/backend/blog/repository/DiscoveryColumnsMappingTest.java`(`@JpaRepositoryTest`): 새 블로그의 `subscriberCount` 0·`feedItemCount` 20·`feedContentMode` FULL, `Blog.changeFeedSettings(30, SUMMARY)` 저장 후 다시 읽기, 새 글의 `likeCount` 0, 카운터 필드는 엔티티 저장으로 바뀌지 않음(읽기 전용)
- [x] T006 [P] `blog-backend/src/test/java/net/java21/blog/backend/common/persistence/MySqlFullTextFunctionsTest.java`(`@MySqlRepositoryTest`): QueryDSL `numberTemplate("match_title_content({0},{1},{2})")`·`match_title`·`match_tag`가 `MATCH(...) AGAINST (? IN BOOLEAN MODE)`로 실행되어 스냅숏 스키마의 FULLTEXT 인덱스로 글·태그를 찾음(한글 2자 낱말, `+"..."` 구문)
- [x] T007 [P] `blog-backend/src/test/java/net/java21/blog/backend/security/DiscoveryPathsWebMvcTest.java`(테스트 컨트롤러 + `WebMvcTestSupport`, 001 `AuthenticationWebMvcTest` 방식): 비로그인 허용 GET `/api/v1/search/posts`, `/api/v1/posts/{id}/related`, `/{handle}/rss`, `/{handle}/atom`, `/{handle}/category/{id}/rss`, `/sitemap.xml`, `/sitemap/posts-1.xml`, `/robots.txt`; 로그인 필요(401 `UNAUTHENTICATED` 공통 틀) `GET /api/v1/me/feed`, `GET /api/v1/me/notifications`, `PUT·DELETE /api/v1/me/likes/{id}`, `PUT·DELETE /api/v1/me/subscriptions/{handle}`; PUT·DELETE는 Origin 검사(403 `ORIGIN_NOT_ALLOWED`)
- [x] T008 [P] `blog-front/tests/unit/server/backend-proxy.test.ts`에 002 경우 추가: GET·HEAD `/marco/rss`, `/marco/atom`, `/marco/category/12/rss`, `/sitemap.xml`, `/sitemap/posts-1.xml`, `/robots.txt`는 backend로, `/marco/rss/x`·`/marco/category/x/rss`·`POST /marco/rss`·`/search`·`/feed`·`/notifications`는 front로(contracts/routes.md "프록시")

### Implementation for Foundation

- [x] T009 `ErrorCode.java`에 `NOTIFICATION_NOT_FOUND`(404), `CANNOT_SUBSCRIBE_OWN_BLOG`(422) 추가: `blog-backend/src/main/java/net/java21/blog/backend/common/error/ErrorCode.java`
- [x] T010 [P] 엔티티 매핑: `blog-backend/src/main/java/net/java21/blog/backend/blog/domain/Blog.java`에 `subscriber_count`(읽기 전용 `insertable=false, updatable=false`, `@ColumnDefault("0")`), `feed_item_count` INT(10·20·30·50), `feed_content_mode` VARCHAR(10)와 enum `blog-backend/src/main/java/net/java21/blog/backend/blog/domain/FeedContentMode.java`(FULL·SUMMARY), `changeFeedSettings(int, FeedContentMode)`(허용 값 검사); `blog-backend/src/main/java/net/java21/blog/backend/post/domain/Post.java`에 `like_count` 읽기 전용. 두 클래스의 "002 컬럼은 매핑하지 않는다" 주석을 고침
- [x] T011 [P] MATCH 함수 등록 `blog-backend/src/main/java/net/java21/blog/backend/common/persistence/MySqlFullTextFunctions.java`(Hibernate 7 `FunctionContributor`: `match_title_content(a, b, q)`, `match_title(a, q)`, `match_tag(a, q)` → `MATCH(...) AGAINST (? IN BOOLEAN MODE)`, 반환 Double)와 `blog-backend/src/main/resources/META-INF/services/org.hibernate.boot.model.FunctionContributor` (research D4)
- [x] T012 `blog-backend/src/main/java/net/java21/blog/backend/config/SecurityConfig.java` `PUBLIC_GET`에 `/api/v1/search/**`, `/api/v1/posts/{id}/related`, `/*/rss`, `/*/atom`, `/*/category/*/rss`, `/sitemap.xml`, `/sitemap/**`, `/robots.txt` 추가(나머지 `/api/v1/me/**`는 기존 규칙대로 로그인 필요)
- [x] T013 [P] 새 오류 코드 문구: `blog-front/app/api/errorCodes.ts`에 `NOTIFICATION_NOT_FOUND`, `CANNOT_SUBSCRIBE_OWN_BLOG`, `blog-front/app/locales/{ko,en,ja,zh-CN}/errors.json`에 4개 언어 문구

**Checkpoint**: 기반 완료. `./mvnw verify`(MySQL 테스트는 환경 변수가 있을 때), `npm test -- --coverage` 통과, `EntitySchemaValidationTest`가 새 매핑으로 통과

---

## Phase 3: User Story 1 - 좋아요, 구독, 구독 피드 (Priority: P1) 🎯 MVP

**Goal**: 로그인 회원이 글에 좋아요를 누르고 취소하며, 다른 블로그를 구독·취소하고, 구독한 블로그들의 공개 글을 `/feed`에서 최신순으로 본다. 자기 블로그는 구독할 수 없다.

**Independent Test**: 회원 B가 회원 A의 블로그를 구독 → A가 새 글 발행 → B의 `/feed` 맨 위에 그 글이 보이고, 좋아요를 누르면 수가 1 늘고 다시 누르면 1 줄어드는지 확인(quickstart #1~9).

FR: FR-030, FR-031, FR-032

### Tests for User Story 1 (backend) ⚠️

- [x] T014 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/like/repository/PostLikeRepositoryTest.java`(`@JpaRepositoryTest`): `insertIgnore(userId, postId, now)`가 처음 1·다시 0, `delete`가 1·0, `changeLikeCount(postId, ±1)`이 원자적 UPDATE이고 0 밑으로 내려가지 않으며 `posts.updated_at`을 바꾸지 않음(피드 ETag·사이트맵 lastmod 보호), `existsByUserIdAndPostId`, 각 호출이 쿼리 1회(`QueryCounter`)
- [x] T015 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/like/PostLikeConcurrencyTest.java`(`@MySqlRepositoryTest` + `PostLikeService`): 같은 회원·같은 글로 `like` 20회 동시 → `post_likes` 행 1, `like_count` 1, 이어서 `unlike` 20회 동시 → 행 0, `like_count` 0 (quickstart #2, research D1)
- [x] T016 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/like/service/PostLikeServiceTest.java`: 발행되었고 상세를 볼 수 있는 글만(`PostExposure.isDetailVisibleTo`, 아니면 404 `POST_NOT_FOUND`: 남의 PRIVATE·DRAFT·DELETED, 정지·탈퇴 작성자, 삭제된 블로그), 자기 글 좋아요 허용, 이미 누른 글은 수를 바꾸지 않고 같은 응답, 취소는 글 상태와 무관(비공개로 바뀐 글도), 없는 글 404, 응답 `{ postId, liked, likeCount }` (FR-030, AS1)
- [x] T017 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/like/controller/PostLikeControllerTest.java`: `PUT·DELETE /api/v1/me/likes/{postId}` 200 공통 틀과 `result` 형식, 비로그인 401, 404, `Cache-Control: no-store`
- [x] T018 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/subscription/repository/BlogSubscriptionRepositoryTest.java`(`@JpaRepositoryTest`): `insertIgnore`·`delete` 영향 행 수, `changeSubscriberCount(blogId, ±1)`(0 밑 금지, `blogs.updated_at` 불변), 회원의 구독 전체 삭제 + 해당 블로그들 수 감소가 블로그 수와 무관한 쿼리 수, 블로그 id 목록의 구독 행 삭제
- [x] T019 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/subscription/repository/SubscriptionFeedQueryRepositoryTest.java`(`@JpaRepositoryTest`): 구독한 블로그의 "목록 노출 가능" 글만(구독하지 않은 블로그, PRIVATE·DRAFT·DELETED, 작성자 SUSPENDED·WITHDRAWN, 삭제된 블로그 제외), 발행 최신순·같은 시각은 id 내림차순, `page`·`totalCount`, 블로그 handle·title과 작성자 닉네임·프로필 포함, 쿼리 수가 구독 수·글 수와 무관(목록 1 + 수 1) (FR-032, AS4, Edge Cases)
- [x] T020 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/subscription/SubscriptionConcurrencyTest.java`(`@MySqlRepositoryTest` + `SubscriptionService`): 같은 회원·블로그로 구독 20회 동시 → 행 1, `subscriber_count` 1, 이벤트 1회
- [x] T021 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/subscription/service/SubscriptionServiceTest.java`: 블로그가 없거나 삭제·주인 정지·탈퇴면 404 `BLOG_NOT_FOUND`, 내가 가진 블로그(첫 블로그든 다른 블로그든)면 422 `CANNOT_SUBSCRIBE_OWN_BLOG`, 이미 구독이면 같은 응답·이벤트 없음, 새로 구독했을 때만 `BlogSubscribedEvent`(구독자 id, 블로그 id) 발행, 취소는 삭제·정지 블로그에도 되고 없는 handle은 404, 응답 `{ handle, subscribed, subscriberCount }` (FR-031, AS2·3)
- [x] T022 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/subscription/controller/SubscriptionControllerTest.java`: `PUT·DELETE /api/v1/me/subscriptions/{handle}`, `GET /api/v1/me/feed?page=&size=`(Page<FeedPost> 필드: PostSummary + `blog`·`author`, `hasDraft` false), 401·404·422, `Cache-Control: no-store`
- [x] T023 [P] [US1] 001 응답 확장 테스트: `blog-backend/src/test/java/net/java21/blog/backend/post/service/PostServiceTest.java`에 `likeCount`·`likedByMe`(비로그인 null, 누름 true, 안 누름 false), `blog-backend/src/test/java/net/java21/blog/backend/blog/service/BlogServiceTest.java`에 `subscriberCount`·`subscribedByMe`(같은 규칙)·`feedItemCount`·`feedContentMode`, 두 컨트롤러 테스트(`post/controller/PostControllerTest.java`, `blog/controller/BlogControllerTest.java`)에 필드와 `Cache-Control: private, no-cache`
- [x] T024 [P] [US1] 정리 규칙 테스트: `blog-backend/src/test/java/net/java21/blog/backend/user/service/AccountServiceTest.java`에 탈퇴 시 그 회원의 구독 행 삭제·각 블로그 `subscriber_count` 감소(같은 트랜잭션, 좋아요 행은 유지), `blog-backend/src/test/java/net/java21/blog/backend/post/job/TrashPurgeJobTest.java`에 보관 기간이 지난 삭제 블로그의 `blog_subscriptions` 행 삭제와 영구 삭제되는 글의 `post_likes` 삭제(H2는 `@OnDelete` CASCADE) (결정 3, data-model blog_subscriptions)

### Tests for User Story 1 (front) ⚠️

- [x] T025 [P] [US1] `blog-front/tests/unit/components/LikeButton.test.tsx`: 좋아요 수·눌림 상태 표시, 로그인 회원은 `intent=like|unlike` 폼, 비로그인은 `/login?next={현재 경로}` 링크, fetcher 응답으로 수 갱신, 문구 `discovery` namespace
- [x] T026 [P] [US1] `blog-front/tests/unit/components/SubscribeButton.test.tsx`: 구독자 수, 구독·구독 중(취소) 전환, 비로그인은 로그인 링크, 내 블로그(세션의 `blogs`에 handle이 있음)면 버튼 없이 수만 표시
- [x] T027 [P] [US1] `blog-front/tests/unit/routes/postDetail.test.tsx`에 추가: `action`의 `intent=like` → `PUT /me/likes/{id}`, `unlike` → `DELETE`, 기존 댓글 intent는 그대로, 비로그인 `action`은 로그인 화면으로, `POST_NOT_FOUND` 오류 문구
- [x] T028 [P] [US1] `blog-front/tests/unit/routes/blogHome.test.tsx`에 추가: `action` `intent=subscribe|unsubscribe` → `PUT·DELETE /me/subscriptions/{handle}`, `CANNOT_SUBSCRIBE_OWN_BLOG` 문구, 구독자 수 표시
- [x] T029 [P] [US1] `blog-front/tests/unit/routes/feed.test.tsx`: 비로그인은 `/login?next=/feed`, loader가 `/me/feed?page=` 호출, 글마다 블로그 이름(블로그 홈 링크)·제목(글 링크)·요약·발행일, 빈 상태 안내, 페이지 이동, meta noindex
- [x] T030 [P] [US1] E2E `blog-front/tests/e2e/discovery-us1-like-subscribe-feed.spec.ts`: Independent Test 전체(A·B·C 가입, B가 A·C 구독 → 발행 → `/feed` 순서, 비공개 글 없음), 좋아요 누름·새로 고침·취소, 비로그인 로그인 링크, A 화면에 구독 버튼 없음 (quickstart #1, #3, #5, #7)

### Implementation for User Story 1 (backend)

- [x] T031 [P] [US1] 좋아요 엔티티 `blog-backend/src/main/java/net/java21/blog/backend/like/domain/PostLike.java`(복합 키 `PostLikeId.java` user_id·post_id, user·post LAZY, post 쪽 `@OnDelete(CASCADE)`, `created_at`)와 `blog-backend/src/main/java/net/java21/blog/backend/like/repository/PostLikeRepository.java`(`@Modifying` 네이티브 `INSERT IGNORE`, 삭제, `changeLikeCount` — 001 `CommentRepository.changeCommentCount`처럼 `updatedAt = updatedAt`으로 수정 시각 유지)
- [x] T032 [US1] `blog-backend/src/main/java/net/java21/blog/backend/like/service/PostLikeService.java`(`like`, `unlike`, `isLikedBy`), DTO `blog-backend/src/main/java/net/java21/blog/backend/like/dto/LikeStateResponse.java`, `blog-backend/src/main/java/net/java21/blog/backend/like/controller/PostLikeController.java`(`/api/v1/me/likes/{postId}`)
- [x] T033 [P] [US1] 구독 엔티티 `blog-backend/src/main/java/net/java21/blog/backend/subscription/domain/BlogSubscription.java`(`BlogSubscriptionId.java` user_id·blog_id, LAZY, `created_at`)와 `blog-backend/src/main/java/net/java21/blog/backend/subscription/repository/BlogSubscriptionRepository.java`(`INSERT IGNORE`, 삭제, `changeSubscriberCount`, 회원 구독 전체 삭제 + 블로그별 수 감소, 블로그 id 목록 삭제)
- [x] T034 [US1] `blog-backend/src/main/java/net/java21/blog/backend/subscription/repository/SubscriptionFeedQueryRepository.java`(QueryDSL, `PostExposure.listable()`, DTO projection `FeedPostRow.java`)
- [x] T035 [US1] `blog-backend/src/main/java/net/java21/blog/backend/subscription/event/BlogSubscribedEvent.java`, `blog-backend/src/main/java/net/java21/blog/backend/subscription/service/SubscriptionService.java`(구독·취소·구독 여부·구독 피드, 태그는 `TagQueryRepository.findTagNames`), DTO `blog-backend/src/main/java/net/java21/blog/backend/subscription/dto/`(`SubscriptionStateResponse`, `FeedPostResponse`), `blog-backend/src/main/java/net/java21/blog/backend/subscription/controller/SubscriptionController.java`(`/api/v1/me/subscriptions/{handle}`, `/api/v1/me/feed`)
- [x] T036 [US1] 001 응답 확장: `blog-backend/src/main/java/net/java21/blog/backend/post/dto/PostDetailResponse.java`(`likeCount`, `likedByMe`)·`post/service/PostService.java`(`detail`에서 좋아요 여부 1회 조회)·`post/controller/PostController.java`; `blog-backend/src/main/java/net/java21/blog/backend/blog/dto/BlogResponse.java`(`subscriberCount`, `subscribedByMe`, `feedItemCount`, `feedContentMode`)·`blog/service/BlogService.java`(`get(handle, viewerId)`)·`blog/controller/BlogController.java`(`@CurrentUser` 선택 주입), 두 GET에 `Cache-Control: private, no-cache`
- [x] T037 [US1] 정리 연결: `blog-backend/src/main/java/net/java21/blog/backend/user/service/AccountService.java`의 `withdraw`가 구독 전체 삭제·수 감소를 같은 트랜잭션에서 호출, `blog-backend/src/main/java/net/java21/blog/backend/post/repository/TrashPurgeRepository.java`의 `purgeBlogs`가 `blog_subscriptions`를 먼저 삭제

### Implementation for User Story 1 (front)

- [x] T038 [P] [US1] `blog-front/app/components/post/LikeButton.tsx`, `blog-front/app/components/blog/SubscribeButton.tsx`(`useFetcher` 폼, JS 없으면 일반 POST), 문구 `discovery` namespace(4개 언어)
- [x] T039 [US1] `blog-front/app/routes/post-detail.tsx`(좋아요 표시·`action` intent `like|unlike`, 001 댓글 intent 유지)와 `blog-front/app/routes/blog-home.tsx`(구독자 수·구독 버튼·`action` intent `subscribe|unsubscribe`, 내 블로그 판정은 root 세션 `blogs`)
- [x] T040 [US1] 구독 피드 `blog-front/app/routes/feed.tsx`(`requireUser`, SSR, noindex)와 목록 `blog-front/app/components/post/FeedPostList.tsx`(001 `PostList`·`Pagination` 재사용), `blog-front/app/routes.ts`에 `route("feed", "routes/feed.tsx")`를 `/:handle` 계열보다 앞에

**Checkpoint**: US1 Independent Test(E2E)가 통과하고 MVP로 시연 가능

---

## Phase 4: User Story 1 (계속) - 알림 (Priority: P1)

**Goal**: 회원은 내 글의 새 댓글과 새 구독자 알림을 화면 언어로 모아 보고 읽음 처리한다. 상단에 안 읽은 수가 보인다. 이후 스펙(004·005·007)이 종류만 더할 수 있는 틀을 만든다.

**Independent Test**: C가 A의 글에 댓글 → A의 상단 배지 1 → `/notifications`에서 화면 언어 문구로 보이고 누르면 그 댓글로 이동하며 읽음 처리, A가 자기 글에 쓴 댓글은 알림이 없음, B의 구독은 NEW_SUBSCRIBER 1건(quickstart #10~14).

FR: FR-033

### Tests for 알림 ⚠️

- [x] T041 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/notification/repository/NotificationQueryRepositoryTest.java`(`@JpaRepositoryTest`): 내 알림 최신순 페이지 + `actor`(상태 포함)·`blog`(handle·title)를 알림 수와 무관한 쿼리 수로(목록 1 + 수 1), 안 읽은 수, 내 알림만 읽음 처리(다른 회원 id는 0행), 일괄 읽음(`ids` 일부·생략 시 전부, 이미 읽은 것은 그대로), 같은 actor·blog의 NEW_SUBSCRIBER가 기간 안에 있는지, `created_at < cutoff` 건수 단위 삭제, 회원 id 목록의 알림 삭제
- [x] T042 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/notification/service/NotificationEventListenerTest.java`: `CommentCreatedEvent` → 글이 속한 블로그 주인에게 NEW_COMMENT(`blog_id`=그 블로그, `target`=COMMENT/댓글 id, `params`={postId, postTitle}), 댓글 작성자가 주인이면 만들지 않음, 답글도 같은 규칙; `BlogSubscribedEvent` → 블로그 주인에게 NEW_SUBSCRIBER(`params`={blogTitle}), `subscriber-dedup-window`(24h, `MutableClock`) 안의 같은 알림이 있으면 만들지 않음; 저장 중 예외는 로그만 남기고 던지지 않음 (research D3)
- [x] T043 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/notification/NotificationAfterCommitIntegrationTest.java`(`@SpringBootTest`, H2): 댓글 작성이 커밋되면 알림 1건, 댓글 트랜잭션이 롤백되면 0건, 구독 성공 시 1건·이미 구독 중이면 0건, 알림 저장 실패를 일으켜도 댓글 API는 201
- [x] T044 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/notification/service/NotificationServiceTest.java`: 목록 매핑(탈퇴 actor → `withdrawn: true`·닉네임·프로필 null, actor 없음 → null), 남의 알림·없는 알림 읽음 404 `NOTIFICATION_NOT_FOUND`, 이미 읽음이면 그대로 200, 일괄 `ids` 100개 초과 400 `VALIDATION_FAILED`, `action`이 `MARK_READ`가 아니면 400
- [x] T045 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/notification/controller/NotificationControllerTest.java`: `GET /api/v1/me/notifications`, `POST /api/v1/me/notifications/{id}/read`, `POST /api/v1/me/notifications/bulk` 응답 형식(contracts/api.md `Notification`), 401·404·400
- [x] T046 [P] [US1] 정리 작업 테스트: `blog-backend/src/test/java/net/java21/blog/backend/notification/job/NotificationPurgeJobTest.java`(`retention` 90일 지난 알림만 건수 단위 삭제, 처리 건수 로그), `blog-backend/src/test/java/net/java21/blog/backend/user/job/PrivacyPurgeJobTest.java`에 파기되는 회원이 받은 알림 삭제 추가 (data-model notifications)
- [x] T047 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/user/service/MeQueryServiceTest.java`와 `user/controller/MeControllerTest.java`에 `unreadNotificationCount` 추가(쿼리 1회 추가)
- [x] T048 [P] [US1] `blog-front/tests/unit/routes/notifications.test.tsx`: 비로그인 로그인 화면으로, loader `/me/notifications?page=`, 종류별 문구 `notification:types.NEW_COMMENT`(actor 닉네임·글 제목 보간)·`NEW_SUBSCRIBER`, 모르는 `type`은 `notification:types.UNKNOWN`, 탈퇴 actor는 "탈퇴한 회원", 안 읽은 표시, `intent=read`는 `POST /me/notifications/{id}/read` 뒤 `/{handle}/{postId}#comment-{id}` 또는 `/{handle}`로 리다이렉트, `intent=read-all`은 bulk, 날짜는 001 `useDateFormat`, meta noindex
- [x] T049 [P] [US1] `blog-front/tests/unit/root.test.tsx`에 추가: 로그인 회원 상단에 "구독 피드"(`/feed`)와 알림(`/notifications`) 링크, 안 읽은 수 배지(0이면 없음, 100 이상 "99+"), 비로그인에는 없음
- [x] T050 [P] [US1] E2E `blog-front/tests/e2e/discovery-us1-notifications.spec.ts`: Independent Test 전체와 구독·취소·재구독 시 알림 1건, 화면 언어 en으로 문구 확인 (quickstart #10~13)

### Implementation for 알림

- [x] T051 [P] [US1] 알림 엔티티 `blog-backend/src/main/java/net/java21/blog/backend/notification/domain/Notification.java`(user·actor·blog LAZY, `type` VARCHAR(30), `target_type`·`target_id`, `params_json` `@JdbcTypeCode(SqlTypes.JSON)` `Map<String, Object>`, `read_at`, `BaseTimeEntity`), `NotificationType.java`(NEW_COMMENT, NEW_SUBSCRIBER), `NotificationTargetType.java`(COMMENT, BLOG), `blog-backend/src/main/java/net/java21/blog/backend/notification/repository/NotificationRepository.java`, QueryDSL `NotificationQueryRepository.java`·`NotificationRow.java`
- [x] T052 [US1] 댓글 이벤트: `blog-backend/src/main/java/net/java21/blog/backend/comment/event/CommentCreatedEvent.java`(commentId, postId, postTitle, blogId, blogOwnerId, authorId)를 `blog-backend/src/main/java/net/java21/blog/backend/comment/service/CommentService.java`의 `create`에서 `ApplicationEventPublisher`로 발행, `CommentServiceTest`에 발행 확인 추가
- [x] T053 [US1] `blog-backend/src/main/java/net/java21/blog/backend/notification/NotificationsProperties.java`(`blog.notifications.retention` 90d, `subscriber-dedup-window` 24h)와 `blog-backend/src/main/java/net/java21/blog/backend/notification/service/NotificationEventListener.java`(`@TransactionalEventListener(AFTER_COMMIT)` + `@Transactional(REQUIRES_NEW)`, 001 `MailService`의 커밋 후 처리와 같은 방식, 예외는 로그)
- [x] T054 [US1] `blog-backend/src/main/java/net/java21/blog/backend/notification/service/NotificationService.java`, DTO `blog-backend/src/main/java/net/java21/blog/backend/notification/dto/`(`NotificationResponse`, `BulkNotificationRequest`, `BulkNotificationResponse`), `blog-backend/src/main/java/net/java21/blog/backend/notification/controller/NotificationController.java`
- [x] T055 [US1] 정리 작업 `blog-backend/src/main/java/net/java21/blog/backend/notification/job/NotificationPurgeJob.java`(`blog.jobs.notification-purge-cron` 기본 `0 15 4 * * *`, `blog.jobs.purge-batch-size`), `blog-backend/src/main/java/net/java21/blog/backend/common/job/JobsProperties.java`에 cron 추가, `blog-backend/src/main/java/net/java21/blog/backend/user/job/PrivacyPurgeJob.java`에 알림 삭제, `blog-backend/src/main/resources/application.yml`에 `blog.notifications.*`·`blog.jobs.notification-purge-cron`
- [x] T056 [US1] `blog-backend/src/main/java/net/java21/blog/backend/user/dto/MeResponse.java`에 `unreadNotificationCount`, `blog-backend/src/main/java/net/java21/blog/backend/user/service/MeQueryService.java`에서 계산
- [x] T057 [P] [US1] `blog-front/app/routes/notifications.tsx`(SSR, `action` intent `read`·`read-all`), `blog-front/app/components/notification/NotificationItem.tsx`(종류별 문구·링크·탈퇴 회원), `blog-front/app/routes.ts`에 `route("notifications", ...)`, 문구 `notification` namespace(4개 언어, `types.NEW_COMMENT`·`types.NEW_SUBSCRIBER`·`types.UNKNOWN`)
- [x] T058 [US1] 상단 연결: `blog-front/app/auth/session.server.ts`의 `SessionUser`에 `unreadNotificationCount`, `blog-front/app/root.tsx`가 상단에 넘김, `blog-front/app/components/layout/Header.tsx`에 "구독 피드"·알림 링크와 배지, 문구 `common` namespace

**Checkpoint**: US1 전체(좋아요·구독·구독 피드·알림) 완료

---

## Phase 5: User Story 2 - 검색과 검색 엔진 노출 (Priority: P2)

**Goal**: 방문자가 키워드로 서비스 전체 공개 글을 검색하고(제목·본문·태그, 보호 글은 제목만), 검색 엔진이 사이트맵·robots로 공개 글을 찾으며, 공개 글 상세는 스크립트 없이도 제목·본문·요약을 담는다.

**Independent Test**: 공개 글 여러 편과 비공개 글 1편을 만든 뒤 검색 결과에 공개 글만 나오는지, 스크립트 없이 요청해도 본문이 포함되는지 확인(quickstart #15~20).

FR: FR-035, FR-037 (SC-007)

### Tests for User Story 2 ⚠️

- [x] T059 [P] [US2] `blog-backend/src/test/java/net/java21/blog/backend/search/service/SearchQueryParserTest.java`: 앞뒤 공백 제거 후 2~100자(아니면 `TOO_SHORT`·`TOO_LONG` + `params`), 공백 분리·2자 미만 낱말 버림·최대 5개, 남는 낱말이 없으면 `TOO_SHORT`, BOOLEAN MODE 연산자 문자(`+ - < > ( ) ~ * " @`) 제거, 결과 `+"스프링" +"부트"` (research D4)
- [x] T060 [P] [US2] `blog-backend/src/test/java/net/java21/blog/backend/search/repository/PostSearchRepositoryTest.java`(`@MySqlRepositoryTest`): 제목·본문·태그 각각의 일치, 두 낱말 AND, 노출 매트릭스 001 행 전부(PRIVATE·DRAFT·DELETED·작성자 SUSPENDED·WITHDRAWN·삭제된 블로그) 제외, 발행 최신순, `page`·`totalCount`, 블로그 handle·title 포함, 행마다 `bodyVisible` 표시, 쿼리 수 고정(목록 1 + 수 1) (FR-035, AS1·2, SC-004)
- [x] T061 [P] [US2] `blog-backend/src/test/java/net/java21/blog/backend/search/service/PostSearchServiceTest.java`: 해석된 검색어로 저장소 호출, 태그 일괄 조회(`findTagNames` 1회), `bodyVisible`이 false인 행(004 보호 글 자리)은 `summary`·`thumbnailUrl` null, `size` 최대 50
- [x] T062 [P] [US2] `blog-backend/src/test/java/net/java21/blog/backend/search/controller/SearchControllerTest.java`: `GET /api/v1/search/posts?q=` 비로그인 200 Page<SearchPost>, `q` 없음·1자·101자 400 `VALIDATION_FAILED`(`fieldErrors[0].field` = `q`)
- [x] T063 [P] [US2] `blog-backend/src/test/java/net/java21/blog/backend/seo/repository/SitemapQueryRepositoryTest.java`(`@JpaRepositoryTest`): 본문 노출 가능 글만 id 순 n번째 묶음(`urls-per-file`=2로 확인), 전체 수, 본문 노출 가능 글이 있는 블로그와 그 최근 발행 시각, 쿼리 수 고정
- [x] T064 [P] [US2] `blog-backend/src/test/java/net/java21/blog/backend/seo/controller/SitemapControllerTest.java`: `/sitemap.xml`(sitemapindex: pages와 posts-1…N, 글이 없으면 pages만), `/sitemap/pages.xml`(`/`, `/terms`, `/privacy`, 블로그 홈), `/sitemap/posts-{n}.xml`(범위 밖 404), XML 파싱 가능·sitemaps.org 네임스페이스·`loc`은 `blog.base-url` 절대 주소·`lastmod` W3C 날짜, `Content-Type: application/xml`, `Cache-Control: no-cache`; `/robots.txt` 차단 규칙과 `Sitemap:` 줄(research D5)
- [x] T065 [P] [US2] `blog-front/tests/unit/routes/search.test.tsx`: `q`가 없으면 API를 부르지 않고 검색창만, loader `/search/posts?q=&page=`, 결과(제목 링크·블로그 이름·요약·발행일, `summary`가 null이면 제목만), `TOO_SHORT`·`TOO_LONG` 입력란 문구, 페이지 이동이 `q`를 유지, 결과 없음 안내, meta `"{q}" 검색 - 서비스명`·noindex
- [x] T066 [P] [US2] `blog-front/tests/unit/root.test.tsx`에 추가: 상단 검색창이 `GET /search`로 `q`를 보내는 일반 폼(JS 없이 동작), `/search` 화면에서는 현재 `q`가 채워짐
- [x] T067 [P] [US2] E2E `blog-front/tests/e2e/discovery-us2-search-seo.spec.ts`: Independent Test(공개 3·비공개 1 → 공개만), 글 휴지통 이동 후 결과에서 빠짐, `javaScriptEnabled: false`로 글 상세에 제목·본문·description 포함, `/robots.txt`·`/sitemap.xml`·`/sitemap/posts-1.xml`에 공개 글만 (quickstart #15, #17~19). FULLTEXT가 필요하므로 backend가 MySQL일 때만 실행

### Implementation for User Story 2

- [x] T068 [US2] `blog-backend/src/main/java/net/java21/blog/backend/search/SearchProperties.java`(`blog.search.max-terms` 5, `min-term-length` 2)와 `blog-backend/src/main/java/net/java21/blog/backend/search/service/SearchQueryParser.java`(검증 실패는 `fieldErrors`가 있는 `VALIDATION_FAILED`)
- [x] T069 [US2] `blog-backend/src/main/java/net/java21/blog/backend/search/repository/PostSearchRepository.java`(QueryDSL + T011 MATCH 함수 + `PostExposure.listable()`·`bodyVisible()`, research D4의 세 조건, DTO projection `SearchPostRow.java`)
- [x] T070 [US2] `blog-backend/src/main/java/net/java21/blog/backend/search/service/PostSearchService.java`, DTO `blog-backend/src/main/java/net/java21/blog/backend/search/dto/SearchPostResponse.java`, `blog-backend/src/main/java/net/java21/blog/backend/search/controller/SearchController.java`(`/api/v1/search/posts`)
- [x] T071 [P] [US2] 사이트맵·robots: `blog-backend/src/main/java/net/java21/blog/backend/seo/SitemapProperties.java`(`blog.sitemap.urls-per-file` 50000), `seo/repository/SitemapQueryRepository.java`, `seo/service/SitemapWriter.java`(StAX), `seo/controller/SitemapController.java`, `seo/controller/RobotsController.java`(모두 `blog-backend/src/main/java/net/java21/blog/backend/` 아래, URL은 `SiteProperties.url`), `application.yml`에 `blog.search.*`·`blog.sitemap.*`
- [x] T072 [P] [US2] `blog-front/app/routes/search.tsx`(SSR, `q`·`page`), `blog-front/app/routes.ts`에 `route("search", ...)`, `blog-front/app/components/layout/Header.tsx`에 검색창, 문구 `discovery` namespace

**Checkpoint**: US1·US2가 각각 독립적으로 동작

---

## Phase 6: User Story 2 (계속) - 관련 글과 공유 (FR-068, FR-069)

**Goal**: 글 상세에 같은 블로그의 관련 글(최대 5편)과 주소 복사·카카오톡·X·페이스북 공유를 붙이고, 공유 미리보기 정보(제목·요약·대표 이미지)를 SSR로 담는다.

**Independent Test**: 태그·카테고리가 겹치는 글들을 만든 뒤 글 상세의 관련 글 순서와 제외 규칙, 공유 버튼의 링크·복사·카카오톡(키 설정 시)을 확인(quickstart #21~23).

FR: FR-068, FR-069

### Tests for 관련 글·공유 ⚠️

- [x] T073 [P] [US2] `blog-backend/src/test/java/net/java21/blog/backend/post/repository/RelatedPostQueryRepositoryTest.java`(`@JpaRepositoryTest`): 같은 블로그의 본문 노출 가능 글만, 자기 자신 제외, 점수(겹치는 태그 수 + 같은 카테고리 1) 내림차순·같으면 발행 최신순, 점수 0 제외, 최대 5편, 다른 블로그 글 제외, 쿼리 수 고정 (FR-068, quickstart #21)
- [x] T074 [P] [US2] `blog-backend/src/test/java/net/java21/blog/backend/post/service/RelatedPostServiceTest.java`(볼 수 없는 기준 글 404 `POST_NOT_FOUND`, 태그 일괄 조회)와 `post/controller/PostControllerTest.java`에 `GET /api/v1/posts/{id}/related` 비로그인 200 `[PostSummary]`·404
- [x] T075 [P] [US2] `blog-front/tests/unit/components/RelatedPosts.test.tsx`(목록·빈 배열이면 영역 없음)와 `blog-front/tests/unit/components/ShareButtons.test.tsx`(X·페이스북 링크에 주소·제목이 인코딩되어 들어가고 `target="_blank" rel="noopener noreferrer"`, 복사는 Clipboard API·실패 시 주소 입력란, 키가 없으면 카카오톡 버튼 없음)
- [x] T076 [P] [US2] `blog-front/tests/unit/share/kakao.test.ts`: 첫 클릭 때만 SDK `<script>`를 `integrity`·`crossorigin`과 함께 한 번 넣음, `Kakao.init(key)` 한 번, `Kakao.Share.sendDefault` 피드 템플릿(제목·요약·절대 주소 대표 이미지 1200x630·글 주소), 로드 실패 시 오류 문구
- [x] T077 [P] [US2] `blog-front/tests/unit/server/securityHeaders.test.ts`에 추가: 키가 있을 때만 `script-src`에 `https://t1.kakaocdn.net`, `connect-src 'self' https://kapi.kakao.com`, 없으면 001과 같은 CSP; `blog-front/tests/unit/routes/postDetail.test.tsx`에 추가: 관련 글 API 실패해도 글 표시, 대표 이미지가 없으면 `twitter:card=summary`
- [x] T078 [P] [US2] E2E `blog-front/tests/e2e/discovery-related-share.spec.ts`: 관련 글 순서·제외(quickstart #21), 주소 복사(클립보드 권한 부여), X·페이스북 링크 주소, `og:*` 메타(quickstart #22~23). 카카오톡은 `BLOG_KAKAO_JS_KEY`가 없으면 버튼이 없는지만 확인

### Implementation for 관련 글·공유

- [x] T079 [US2] `blog-backend/src/main/java/net/java21/blog/backend/post/repository/RelatedPostQueryRepository.java`(QueryDSL 집계, `PostExposure.bodyVisible()`), `blog-backend/src/main/java/net/java21/blog/backend/post/service/RelatedPostService.java`, `blog-backend/src/main/java/net/java21/blog/backend/post/controller/PostController.java`에 `GET /posts/{id}/related`
- [x] T080 [P] [US2] `blog-front/app/components/post/RelatedPosts.tsx`, `blog-front/app/components/post/ShareButtons.tsx`, `blog-front/app/share/kakao.client.ts`(SDK 버전·SRI 해시 상수 고정), 문구 `discovery` namespace
- [x] T081 [US2] 연결: `blog-front/app/routes/post-detail.tsx` loader에 `/posts/{id}/related`(실패 시 `[]`)·영역 배치, `blog-front/app/root.tsx`가 `kakaoJsKey`를 브라우저로 넘김, `blog-front/app/server/securityHeaders.ts`·`blog-front/server.ts`에 키 유무에 따른 CSP 옵션, `blog-front/app/seo/meta.ts`에 이미지가 없을 때 `twitter:card=summary`

**Checkpoint**: 글 상세의 관련 글·공유 완료, US2 전체 완료

---

## Phase 7: User Story 3 - RSS·Atom 피드로 블로그 구독하기 (Priority: P3)

**Goal**: 블로그·카테고리별 RSS 2.0, 블로그 Atom 1.0 피드를 표준에 맞게 제공하고(목록 노출 가능 글만, 전문/요약·글 수 설정, 보호 글은 제목·링크만), 변경이 없으면 304, 페이지는 피드를 자동 발견할 수 있게 알린다.

**Independent Test**: 공개 글 3편과 비공개 글 1편 작성 → 피드 검증기로 블로그 피드 주소 확인 → 공개 글 3편만 설정한 형태(전문/요약)로 들어 있는지 확인(quickstart #24~31).

FR: FR-044~048 (SC-008)

### Tests for User Story 3 ⚠️

- [x] T082 [P] [US3] `blog-backend/src/test/java/net/java21/blog/backend/syndication/repository/FeedItemQueryRepositoryTest.java`(`@JpaRepositoryTest`): 블로그의 "목록 노출 가능" 글만 발행 최신순 `limit`개, 카테고리 조건은 하위 카테고리 포함, 다른 블로그 카테고리는 결과 없음, 버전 조회(id·updated_at만)와 본문 조회가 각각 쿼리 1회, 본문 노출 가능 여부 표시 (FR-045, FR-047, AS3·5)
- [x] T083 [P] [US3] `blog-backend/src/test/java/net/java21/blog/backend/syndication/service/FeedContentUrlRewriterTest.java`: `src="/media/..."`, `href="/marco/12"`를 `blog.base-url` 절대 주소로, 이미 절대 주소·`//`·`#`·`mailto:`는 그대로, 속성 따옴표 두 종류
- [x] T084 [P] [US3] `blog-backend/src/test/java/net/java21/blog/backend/syndication/service/FeedServiceTest.java`: FULL은 본문 HTML(절대 주소), SUMMARY는 요약, 본문 노출 가능이 아닌 글은 제목·링크·시각만, 카테고리 피드 제목 `{카테고리} - {블로그}`, 소개가 없으면 description=제목, ETag가 같은 입력에서 같고 글 수정·비공개 전환·피드 설정·블로그 제목 변경에서 바뀜, 없는 블로그·삭제·주인 정지·탈퇴 404 `BLOG_NOT_FOUND`, 다른 블로그 카테고리 404 `CATEGORY_NOT_FOUND`
- [x] T085 [P] [US3] `blog-backend/src/test/java/net/java21/blog/backend/syndication/writer/RssFeedWriterTest.java`와 `AtomFeedWriterTest.java`: ROME `SyndFeedInput`으로 다시 읽기, RSS 필수 요소(`title`·`link`·`description`·`atom:link rel=self`·`lastBuildDate`), 항목 `guid isPermaLink=true` 유일·`pubDate` RFC 822·`dc:creator`·`category`, 이메일 없음; Atom `id`·`updated` RFC 3339·`author/name`·`link rel=self/alternate`·`content type=html` 또는 `summary`; 제목의 `&`·`<`·이모지 이스케이프, 빈 피드도 유효 (SC-008)
- [x] T086 [P] [US3] `blog-backend/src/test/java/net/java21/blog/backend/syndication/controller/FeedControllerTest.java`: `/{handle}/rss`·`/{handle}/atom`·`/{handle}/category/{id}/rss` 비로그인 200과 `Content-Type`(`application/rss+xml`·`application/atom+xml`; charset UTF-8), `ETag`·`Last-Modified`·`Cache-Control: no-cache`, 같은 `If-None-Match`면 304 본문 없음, 404는 공통 틀 JSON
- [x] T087 [P] [US3] 피드 설정 API 테스트: `blog-backend/src/test/java/net/java21/blog/backend/blog/service/BlogServiceTest.java`·`blog/controller/BlogControllerTest.java`에 `PATCH /blogs/{handle}` `feedItemCount`(10·20·30·50 아니면 400 `INVALID` + `params.allowed`, null이면 `REQUIRED`)·`feedContentMode`(FULL·SUMMARY), 주인만(403), 응답에 반영 (FR-046)
- [x] T088 [P] [US3] `blog-front/tests/unit/seo/feedLinks.test.ts`(블로그·카테고리 피드 `<link rel="alternate">` 메타 설명자, 절대 주소, 제목 번역)와 `blog-front/tests/unit/routes/blogHome.test.tsx`·`categoryTagLists.test.tsx`·`postDetail.test.tsx`에 각 화면 meta의 RSS·Atom 링크 확인 추가 (FR-048, AS4)
- [x] T089 [P] [US3] `blog-front/tests/unit/routes/manageFeed.test.tsx`(현재 설정 표시, 저장 시 `PATCH /blogs/{handle}`, `INVALID` 문구, RSS·Atom·카테고리 피드 주소 안내, noindex)와 `blog-front/tests/unit/routes/manage.test.tsx`에 좌측 메뉴 "피드 설정" 추가 확인
- [x] T090 [P] [US3] E2E `blog-front/tests/e2e/discovery-us3-rss-atom.spec.ts`: Independent Test(공개 3·비공개 1·임시저장 1 → RSS·Atom에 공개 3편), 요약·10개 설정 반영, 카테고리 RSS, ETag로 304 → 비공개 전환 후 200에서 빠짐, 페이지 `<head>`의 자동 발견 링크, 없는 블로그 404 (quickstart #24~28, #31)

### Implementation for User Story 3

- [x] T091 [US3] `blog-backend/src/main/java/net/java21/blog/backend/syndication/repository/FeedItemQueryRepository.java`(QueryDSL, `PostExposure`, DTO `FeedItemRow.java`·`FeedVersionRow.java`)
- [x] T092 [P] [US3] `blog-backend/src/main/java/net/java21/blog/backend/syndication/service/FeedContentUrlRewriter.java`
- [x] T093 [US3] `blog-backend/src/main/java/net/java21/blog/backend/syndication/service/FeedService.java`(블로그·카테고리 확인, `FeedSnapshot` 생성, ETag·Last-Modified 계산)와 ROME 작성기 `blog-backend/src/main/java/net/java21/blog/backend/syndication/writer/RssFeedWriter.java`·`AtomFeedWriter.java`(DC 모듈 `dc:creator`, `atom:link rel=self`)
- [x] T094 [US3] `blog-backend/src/main/java/net/java21/blog/backend/syndication/controller/FeedController.java`(`/{handle}/rss`, `/{handle}/atom`, `/{handle}/category/{categoryId}/rss`, `ServletWebRequest.checkNotModified`)
- [x] T095 [US3] 피드 설정: `blog-backend/src/main/java/net/java21/blog/backend/blog/dto/UpdateBlogRequest.java`에 `feedItemCount`·`feedContentMode`(Merge Patch 표시), `blog-backend/src/main/java/net/java21/blog/backend/blog/service/BlogService.java`의 `update`가 `Blog.changeFeedSettings` 호출
- [x] T096 [P] [US3] `blog-front/app/seo/feedLinks.ts`를 `blog-front/app/routes/blog-home.tsx`·`blog-front/app/routes/blog-category.tsx`·`blog-front/app/routes/post-detail.tsx`의 `meta`에 연결, 링크 제목 `discovery:feedLink.*`
- [x] T097 [P] [US3] `blog-front/app/routes/manage/feed.tsx`(피드 설정 폼·피드 주소 안내), `blog-front/app/routes.ts`의 `:handle/manage` 아래 `route("feed", ...)`, `blog-front/app/manage/links.ts` 메뉴 항목, 문구 `manage` namespace(4개 언어)

**Checkpoint**: US1~US3이 각각 독립적으로 동작

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: 여러 스토리에 걸친 노출·계약·성능·문서 확인

- [x] T098 [P] `blog-backend/src/test/java/net/java21/blog/backend/integration/DiscoveryExposureIntegrationTest.java`(`@SpringBootTest`, H2): 노출 매트릭스 001 행 전체(PRIVATE·DRAFT·DELETED·작성자 SUSPENDED·WITHDRAWN·삭제된 블로그)를 구독 피드·RSS·Atom·카테고리 RSS·사이트맵·관련 글·좋아요(404)에서 한 번에 확인(주인 외 노출 0건, SC-004). 검색은 T060이 MySQL에서 확인
- [x] T099 [P] `blog-backend/src/test/java/net/java21/blog/backend/openapi/OpenApiContractTest.java`에 contracts/api.md의 002 `/api/v1` 엔드포인트(메서드·경로)와 001 응답 확장 필드 확인 추가
- [x] T100 [P] `blog-backend/src/test/java/net/java21/blog/backend/security/CacheHeadersWebMvcTest.java`에 `/api/v1/me/**` 002 응답 `no-store`, `GET /blogs/{handle}`·`GET /posts/{id}` `private, no-cache`, 피드·사이트맵 `no-cache` 확인 추가
- [x] T101 [P] 운영 문서 `blog-backend/docs/operations.md`에 002 프로퍼티(`blog.search.*`, `blog.notifications.*`, `blog.jobs.notification-purge-cron`, `blog.sitemap.*`), MySQL `ngram_token_size=2` 확인, 정기 작업 목록 추가. front 4개 언어 README(`blog-front/README.md`·`README.en.md`·`README.ja.md`·`README.zh-CN.md`)에 `BLOG_KAKAO_JS_KEY`와 Kakao Developers 도메인 등록 안내
- [ ] T102 검색 성능 확인(SC-007): 글 10만 편 데이터에서 `GET /api/v1/search/posts` p95 2초 이내(자주 쓰는 낱말·드문 낱말·두 낱말). 측정 도구는 저장소에 추가하지 않고 절차와 결과를 backend PR 설명에 기록(quickstart #20) — (측정함, backend PR #18: 드문 낱말 p95 146ms, 30% 빈도 낱말 1.9초, 60% 이상 빈도 낱말 3.8~4.9초로 기준 미달. 후속 결정 필요)
- [ ] T103 피드 검증(SC-008): `/{handle}/rss`, `/{handle}/atom`, 카테고리 RSS를 W3C Feed Validation Service로 검증해 오류 0건, 결과를 PR 설명에 기록(quickstart #29) — (수동, 배포 후: 공개 주소가 있어야 W3C 검증 가능)
- [x] T104 커버리지 확인: `blog-backend`의 `./mvnw verify`, `blog-front`의 `npm test -- --coverage` 모두 라인 80% 이상
- [ ] T105 `blog-docs/specs/002-discovery-feeds/quickstart.md` 수동 검증 시나리오 #1~32 전체 실행(backend·front 함께 기동), 끝난 작업을 이 tasks.md에 [x]로 표시 — (수동, 배포 후)

---

## 구현 전 결정 사항 (2026-10-06 확정)

marco가 "묻지 말고 진행"하라고 해서 Claude가 기본값으로 정했다. 바꾸려면 이 표와 관련 문서를 함께 고친다.

| # | 문제 | 결정 | 반영 문서 |
|---|---|---|---|
| 1 | 좋아요·구독 API 모양(토글 vs 자원) | 본인 자원 `PUT·DELETE /me/likes/{postId}`, `PUT·DELETE /me/subscriptions/{handle}`. 둘 다 멱등이며 200 + 현재 상태·수. DELETE가 설계 규칙(`result: null`, 없으면 404)과 다른 이유는 api.md에 기록 | contracts/api.md, research D1 |
| 2 | 좋아요할 수 있는 글 | 발행되었고 요청한 회원이 상세를 볼 수 있는 글. 자기 글도 허용. 취소는 글 상태와 무관(비공개로 바뀐 뒤에도 취소 가능) | research D1 |
| 3 | 탈퇴 회원의 구독·좋아요 | 탈퇴(`DELETE /me`) 트랜잭션에서 구독 행 삭제·`subscriber_count` 감소. 좋아요 행과 `like_count`는 유지(data-model) | research D1, T024·T037 |
| 4 | 구독 피드 목록 방식 | 페이지(`page`·`totalCount`). 커서 방식은 003 포털 무한 스크롤 때 검토 | research D2, contracts/api.md |
| 5 | 내 구독 목록 화면 | 만들지 않는다(스펙에 없음). 구독 취소는 블로그 홈 버튼과 API로 한다. 정지된 블로그의 구독 행은 남지만 피드에 나오지 않는다 | 이 표 |
| 6 | 알림 받는 사람·중복 | NEW_COMMENT는 글이 속한 블로그의 주인에게만(답글 대상 댓글 작성자에게는 보내지 않음, 자기 댓글 제외). NEW_SUBSCRIBER는 같은 구독자·블로그 알림이 24시간(`subscriber-dedup-window`) 안에 있으면 만들지 않음 | research D3, contracts/api.md |
| 7 | 알림 생성 시점·실패 | 커밋 후 동기 이벤트 리스너(`AFTER_COMMIT` + `REQUIRES_NEW`). 실패해도 댓글·구독은 성공, 로그만 남김. backend enum은 002의 두 종류만, 나머지는 해당 스펙이 추가 | research D3 |
| 8 | 안 읽은 알림 수 전달 | `GET /me`에 `unreadNotificationCount` 필드 추가(root loader가 이미 호출). 읽음은 단건 `POST /me/notifications/{id}/read`와 일괄 `POST /me/notifications/bulk`. 알림 삭제 API는 없음(스펙에 없음, 90일 정리) | contracts/api.md |
| 9 | 검색어 해석·정렬 | 2~100자, 공백으로 나눈 2자 이상 낱말 최대 5개를 모두 포함(AND, 낱말별 구문 일치). 낱말은 필드(제목+본문 / 태그 / 보호 글 제목)별로 맞추므로 낱말이 서로 다른 필드에 흩어진 글은 나오지 않음(받아들인 한계). 정렬은 발행 최신순(관련도 정렬 없음) | research D4 |
| 10 | 검색 구현 방식 | Hibernate `FunctionContributor`로 MATCH 함수를 등록해 QueryDSL + `PostExposure`로 작성(노출 규칙 한 곳). 검색 Repository 테스트는 `@MySqlRepositoryTest`만 | research D4, plan Complexity Tracking |
| 11 | 보호 글(004) 처리 시점 | 002는 `listable()`·`bodyVisible()`만 쓰고 보호 글 분기(검색 제목만, 피드 제목·링크만, 사이트맵 제외, 목록 summary null)를 코드에 미리 둔다. PROTECTED 값과 그 테스트 데이터는 004가 `PostVisibility`·`LISTABLE_VISIBILITIES`에 더할 때 확인 | research D4·D6 |
| 12 | 피드·사이트맵·관련 글 캐시 | 서버 캐시 없음(001 R15 "5분 캐시", R21 "10분 캐시"를 바꿈). 비공개 전환·정지가 다음 요청에 바로 반영되어야 SC-004를 지킨다. 피드는 ETag·Last-Modified로 304, `Cache-Control: no-cache` | research D5·D6·D8 |
| 13 | 카테고리 피드 형식·범위 | 001 routes.md 목록대로 카테고리는 RSS만(카테고리 Atom 없음). 상위 카테고리 피드는 하위 카테고리 글 포함(001 결정 4와 같음) | research D6, contracts/api.md |
| 14 | 피드 본문 | FULL은 `content_html`(상대 주소를 `blog.base-url` 절대 주소로 바꿈), SUMMARY는 `summary`. 작성자는 닉네임만(RSS `dc:creator`), 이메일 없음. 오류 응답 본문은 공통 틀 JSON | research D6, contracts/api.md |
| 15 | 카운터와 수정 시각 | `like_count`·`subscriber_count` 증감은 `updated_at`을 바꾸지 않는다(001 `changeCommentCount`와 같이 `updatedAt = updatedAt`). 좋아요 하나로 피드 ETag·사이트맵 lastmod가 바뀌지 않게 | T014·T018 |
| 16 | 사이트맵 구성·robots | 색인 + `pages.xml`(`/`, `/terms`, `/privacy`, 공개 글이 있는 블로그 홈) + `posts-{n}.xml`(5만 개씩). `changefreq`·`priority` 없음. robots는 로그인·개인 화면과 `/search`·`/feed`·`/notifications` 차단 | research D5 |
| 17 | 카카오톡 공유 설정 | front 환경 변수 `BLOG_KAKAO_JS_KEY`, 없으면 버튼 숨김. SDK는 클릭 시 CDN에서 SRI와 함께 지연 로딩, CSP는 키가 있을 때만 카카오 출처 추가. Kakao Developers 도메인 등록은 marco의 운영 작업 | research D9, plan Complexity Tracking |
| 18 | 스토리가 없는 FR-068·069 | "탐색" 스토리인 US2에 붙여 Phase 6으로 둔다(US2 Independent Test와 별도 확인) | 이 문서 |
| 19 | 번역 namespace | 새로 `discovery`(좋아요·구독·구독 피드·검색·관련 글·공유·피드 링크 제목), `notification`(종류별 문구 + `types.UNKNOWN`). 피드 설정은 기존 `manage`, 상단 링크는 `common` | research D10 |
| 20 | 피드 설정 API | 별도 API 대신 `PATCH /blogs/{handle}`에 `feedItemCount`·`feedContentMode` 추가, `GET /blogs/{handle}`이 값을 줌. 허용 값이 아니면 `INVALID` | contracts/api.md |
| 21 | 스키마 변경 | 필요 없음(002 테이블·컬럼·인덱스가 모두 `schema-mysql.sql`에 있음). 구현 중 필요해지면 Crowfoot로 marco 승인 후 반영 | plan.md "스키마 변경" |
| 22 | 다른 스펙의 일 | 포털 검색창·인기 점수(최근 7일 좋아요)·"구독 피드 보기" 링크는 003, PROTECTED·SCHEDULED·블로그 내 검색·차단 시 구독 해제·백업 알림은 004, HIDDEN·신고 처리 알림은 005, 관리자 콘솔은 006, 외부 블로그 알림은 007에서 한다 | plan.md "범위 밖" |

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: 바로 시작(001이 main에 있어야 함)
- **Foundational (Phase 2)**: Setup의 ROME(T001)·모델 타입(T003) 이후. 모든 스토리를 막는다
- **US1 좋아요·구독·구독 피드 (Phase 3)**: Phase 2 이후. MVP
- **US1 알림 (Phase 4)**: Phase 3의 구독 이벤트(T035) 이후(NEW_SUBSCRIBER). NEW_COMMENT 부분(T052)은 Phase 2 이후 바로 가능
- **US2 검색·검색 엔진 (Phase 5)**: Phase 2(특히 MATCH 함수 T011) 이후. US1과 독립
- **관련 글·공유 (Phase 6)**: Phase 2 이후. US1의 `post-detail.tsx` 변경(T039)과 같은 파일이라 그 뒤에 머지
- **US3 RSS·Atom (Phase 7)**: Phase 2(ROME, 피드 설정 매핑 T010) 이후. US1·US2와 독립
- **Polish (Phase 8)**: 원하는 스토리가 모두 끝난 뒤

### User Story Dependencies

- **US1 (P1)**: Phase 2 이후. 다른 스토리에 의존하지 않음. 001의 Post·Blog·Comment·`PostExposure`를 사용
- **US2 (P2)**: Phase 2 이후. US1만 없어도 독립 테스트 가능(검색·사이트맵은 001 데이터만 사용)
- **US3 (P3)**: Phase 2 이후. US1·US2 없이도 독립 테스트 가능

### Within Each User Story

- 테스트를 먼저 쓰고 실패를 확인한 뒤 구현한다(원칙 III)
- 엔티티 → 리포지토리(QueryDSL) → 서비스 → 컨트롤러 → front 라우트 → E2E
- 엔티티를 더할 때마다 `EntitySchemaValidationTest`(실제 스키마 대상 `ddl-auto=validate`)가 통과해야 한다
- 새 화면 문구·오류 코드는 같은 작업에서 4개 언어 번역을 넣는다(원칙 VII)
- 스토리의 E2E(Independent Test)가 통과해야 다음 우선순위로 넘어간다

### Parallel Opportunities

- Setup의 [P] 작업(T001~T004)은 모두 병렬
- Phase 2 테스트(T005~T008)는 모두 [P], 구현은 엔티티 매핑(T010)·MATCH 함수(T011)·front 문구(T013)가 병렬
- 각 스토리의 테스트 작업(backend·front)은 모두 [P]
- Phase 2 이후 Phase 3(US1), Phase 5(US2), Phase 7(US3)은 사람이 여럿이면 병렬. 같은 파일(`ErrorCode`, `SecurityConfig`, `BlogService`·`BlogResponse`(T036·T095), `post-detail.tsx`(T039·T081·T096), `blog-home.tsx`(T039·T096), `Header.tsx`(T058·T072), `routes.ts`, `discovery.json`)을 고치는 작업은 머지 순서를 맞춘다

---

## Parallel Example: User Story 1

```bash
# backend 테스트를 함께 시작:
Task: "PostLikeRepositoryTest in blog-backend/src/test/java/net/java21/blog/backend/like/repository/PostLikeRepositoryTest.java"
Task: "PostLikeServiceTest in blog-backend/src/test/java/net/java21/blog/backend/like/service/PostLikeServiceTest.java"
Task: "SubscriptionFeedQueryRepositoryTest in blog-backend/src/test/java/net/java21/blog/backend/subscription/repository/SubscriptionFeedQueryRepositoryTest.java"
Task: "SubscriptionServiceTest in blog-backend/src/test/java/net/java21/blog/backend/subscription/service/SubscriptionServiceTest.java"

# front 테스트를 함께 시작:
Task: "LikeButton.test.tsx in blog-front/tests/unit/components/LikeButton.test.tsx"
Task: "SubscribeButton.test.tsx in blog-front/tests/unit/components/SubscribeButton.test.tsx"
Task: "feed.test.tsx in blog-front/tests/unit/routes/feed.test.tsx"

# 엔티티를 함께 만들기:
Task: "PostLike in blog-backend/src/main/java/net/java21/blog/backend/like/domain/PostLike.java"
Task: "BlogSubscription in blog-backend/src/main/java/net/java21/blog/backend/subscription/domain/BlogSubscription.java"
```

## Parallel Example: User Story 3

```bash
Task: "FeedItemQueryRepositoryTest in blog-backend/src/test/java/net/java21/blog/backend/syndication/repository/FeedItemQueryRepositoryTest.java"
Task: "FeedContentUrlRewriterTest in blog-backend/src/test/java/net/java21/blog/backend/syndication/service/FeedContentUrlRewriterTest.java"
Task: "RssFeedWriterTest in blog-backend/src/test/java/net/java21/blog/backend/syndication/writer/RssFeedWriterTest.java"
Task: "feedLinks.test.ts in blog-front/tests/unit/seo/feedLinks.test.ts"
Task: "manageFeed.test.tsx in blog-front/tests/unit/routes/manageFeed.test.tsx"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1 Setup, Phase 2 Foundational
2. Phase 3 (US1 좋아요·구독·구독 피드)
3. **멈추고 확인**: US1 Independent Test E2E, quickstart #1~9
4. 시연·배포 가능

### Incremental Delivery

1. Setup + Foundational → 기반 완료
2. US1(Phase 3) → MVP
3. 알림(Phase 4) → US1 완성
4. US2(Phase 5) → 관련 글·공유(Phase 6) → US3(Phase 7), 각 스토리의 E2E 통과 후 다음
5. Polish → quickstart 전체 검증

### Parallel Team Strategy

1. 함께 Setup + Foundational
2. Foundational이 끝나면:
   - 개발자 A: Phase 3 → Phase 4(US1)
   - 개발자 B: Phase 5(US2) → Phase 6
   - 개발자 C: Phase 7(US3)
3. 같은 파일을 고치는 연결 작업은 머지 순서를 맞춘다(Phase Dependencies)

---

## Notes

- [P] = 다른 파일, 끝나지 않은 작업에 의존하지 않음
- [Story] = spec.md 사용자 스토리 추적용
- 각 PR 설명에 스펙 경로 `blog-docs/specs/002-discovery-feeds`를 적는다(헌법 개발 흐름 6)
- 엔티티는 API 응답으로 직렬화하지 않고 DTO record를 쓴다. 연관관계는 모두 LAZY, 목록은 fetch join 또는 DTO projection, 목록 테스트에는 `QueryCounter`
- 003~007이 더한 컬럼(`blogs.portal_enabled`, `posts.topic_id` 등)은 DB 기본값이 있으므로 002 엔티티에도 매핑하지 않는다
- 테스트가 실패하는 것을 먼저 확인하고, 작업 단위로 커밋한다
