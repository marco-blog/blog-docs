# Implementation Plan: 구독과 탐색 (좋아요·구독·피드·검색·RSS)

**Branch**: `002-discovery-feeds` (계획 문서는 `docs/002-plan`) | **Date**: 2026-10-06 | **Spec**: [spec.md](./spec.md)

**Status**: Phase 1 완료 (research, contracts, quickstart, tasks 작성). 다음 단계는 `/speckit-analyze` 후 `/speckit-implement`.

**Input**: Feature specification from `/specs/002-discovery-feeds/spec.md`

## Summary

001 위에 "재방문"과 "발견" 경로를 더한다. 회원은 글에 좋아요를 누르고 다른 블로그를 구독해 구독 피드(`/feed`)로 새 글을 모아 보며, 새 댓글·새 구독자 알림(`/notifications`)을 받는다(US1, FR-030~033). 방문자는 서비스 전체 공개 글을 검색하고(`/search`), 검색 엔진은 사이트맵·robots로 공개 글을 찾는다(US2, FR-035·037). 독자는 가입 없이 블로그 RSS 2.0·Atom 1.0 피드(블로그·카테고리별, 전문/요약·글 수 설정)를 리더로 구독한다(US3, FR-044~048). 글 상세에는 같은 블로그의 관련 글과 공유 버튼(주소 복사·카카오톡·X·페이스북)을 붙인다(FR-068·069).

기술 접근: 좋아요·구독은 `INSERT IGNORE` + 원자적 카운터 UPDATE로 멱등하게, 알림은 커밋 후 도메인 이벤트로 만든다. 검색은 이미 만들어 둔 MySQL FULLTEXT ngram 인덱스를 Hibernate 함수 등록 + QueryDSL로 써서 노출 조건을 001 `PostExposure` 한 곳에 둔다. 피드는 ROME으로 쓰고 ETag 조건부 응답(304)을 주며, 피드·사이트맵·관련 글은 비공개 전환이 바로 반영되도록 서버 캐시를 두지 않는다. 세부 근거는 [research.md](./research.md).

## Technical Context

**Language/Version**: backend Java 21 / front TypeScript 5.9, Node.js 22 LTS (001과 같음)

**Primary Dependencies**:
- backend(001 그대로): Spring Boot 4.1.1(Web MVC, Security, Data JPA, Validation), QueryDSL OpenFeign 7.7, Hibernate 7, Caffeine, springdoc-openapi 3.1. **새로**: ROME `com.rometools:rome` 2.1.0(D6)
- front(001 그대로): React 19, React Router 8.4 framework 모드, Vite 8, Express 5, i18next + react-i18next. **새로**: Kakao JavaScript SDK 2.x(CDN 지연 로딩, npm 의존성 아님, D9)

**Storage**: MySQL 8(InnoDB, utf8mb4, ngram_token_size=2). 002의 테이블·컬럼·인덱스(`post_likes`, `blog_subscriptions`, `notifications`, `blogs.subscriber_count`·`feed_item_count`·`feed_content_mode`, `posts.like_count`, FULLTEXT 3개)는 Crowfoot 문서 "blog 1.0"(`db/schema-mysql.sql`)에 이미 있다. 아래 "스키마 변경" 참고

**Testing**: 001과 같음. JUnit 5, `@WebMvcTest`, Mockito, `@JpaRepositoryTest`(H2) + `QueryCounter`, MySQL 전용(FULLTEXT 검색, 좋아요·구독 동시성)만 `@MySqlRepositoryTest`, `@SpringBootTest`는 노출 통합 확인만, JaCoCo 라인 80%. front Vitest(80%) + Playwright E2E(실제 backend)

**Target Platform**: Linux 서버 1대(backend 1대 전제, 001 R26), 최신 데스크톱/모바일 브라우저, RSS 리더(Feedly, Inoreader 등)

**Project Type**: 웹 서비스(REST API + SSR 웹 앱), 저장소 3개

**Performance Goals**: 검색 결과 p95 2초(SC-007, 글 10만 편). 구독 피드·알림 목록은 001 목록과 같은 수준(쿼리 수 고정, 인덱스 사용). 피드 리더의 반복 요청은 304로 가볍게(Edge Cases)

**Constraints**: 비공개·삭제·숨김 글과 정지·탈퇴 회원 글 노출 0건(SC-004, 001 글 노출 매트릭스, 구독 피드·검색·RSS·Atom·사이트맵·관련 글 포함), W3C 피드 검증 오류 0건(SC-008), 커버리지 80%, 번역 누락 0건, N+1 금지

**Scale/Scope**: 회원 1만, 글 10만. 새 API 10개 + 피드·사이트맵·robots 경로 7개, 새 화면 4개, 001 화면 변경 4곳

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| 원칙 | 확인 | 결과 |
|---|---|---|
| I. 스펙이 먼저다 | spec.md 확정(NEEDS CLARIFICATION 0개, checklist 통과). 이 plan은 FR-030~033, 035, 037, 044~048, 068, 069만 다루고, 모호한 점은 tasks.md "구현 전 결정 사항"에 기본값으로 기록(marco "묻지 말고 진행") | 통과 |
| II. 세 저장소, 두 실행 파트 | 피드·사이트맵은 backend가 만들고 front 서버가 프록시(001 R4). 새 실행 파트·외부 검색 엔진·큐 없음 | 통과 |
| III. 테스트 우선·커버리지 | 각 스토리의 테스트 작업이 구현보다 앞섬, 인수 시나리오마다 테스트(tasks.md), H2 + 쿼리 수 확인, MySQL 전용만 `@MySqlRepositoryTest`, Testcontainers 없음, 80% 게이트 유지 | 통과 |
| IV. 보안과 공개 범위 | 모든 목록·검색·피드·사이트맵·관련 글이 `PostExposure`의 `listable()`·`bodyVisible()`만 사용(검색도 함수 등록으로 같은 조각 사용), 서버 캐시 없음, 쓰기 API는 본인 자원(`/me/...`)·블로그 주인 검증, 피드 HTML은 001에서 살균된 본문만 사용 | 통과 |
| V. SSR | `/search`는 SSR, 블로그 홈·글 상세·카테고리의 자동 발견 링크와 공유 메타 태그가 SSR HTML에 포함, 좋아요·구독 폼은 JS 없이 동작 | 통과 |
| VI. 단순함 | 캐시·큐·검색 엔진 추가 없음. 새 라이브러리 2개(ROME, Kakao SDK)는 Complexity Tracking에 기록 | 통과 |
| VII. 다국어 우선 | 새 문구는 `discovery`·`notification` namespace와 `manage`·`errors`에 4개 언어로, 알림 문구는 front가 `type`+`params`로 생성(backend는 코드만), 새 오류 코드 2개 번역 | 통과 |
| 기술 제약 | Java 21, Spring Boot 4, JPA + QueryDSL(OpenFeign), N+1 금지, Crowfoot 스키마(변경 없음), 공통 응답 틀(예외는 피드·사이트맵, 설계 규칙 4절), `blog.*` 프로퍼티 | 통과 |

**Phase 1 이후 재확인**: research, contracts(api.md, routes.md), quickstart, tasks 작성 후 원칙 I~VII을 다시 점검했고 위반 없음. 설계 규칙과 다른 두 곳(좋아요·구독 DELETE 응답, 피드 오류 본문)은 contracts/api.md에 이유를 적었다.

## 스키마 변경

**없음.** 002 data-model의 새 테이블 3개, 001 테이블 추가 컬럼 4개, FULLTEXT 인덱스 3개와 보조 인덱스(`idx_post_likes_post_created`, `idx_blog_subscriptions_blog`, `idx_notifications_user_created`, `idx_notifications_user_read`), 외래 키(`fk_post_likes_post` `ON DELETE CASCADE` 포함)가 모두 `db/schema-mysql.sql`(Crowfoot 문서 "blog 1.0", migrations/0001-baseline.sql)에 있다. 002 쿼리를 하나씩 대조했다.

| 쿼리 | 쓰는 인덱스·제약 |
|---|---|
| 좋아요·구독 멱등 쓰기 | PK `(user_id, post_id)`, `(user_id, blog_id)` |
| 구독 피드 | `idx_blog_subscriptions_blog`·PK, `idx_posts_blog_status_visibility_published` |
| 알림 목록·안 읽은 수·NEW_SUBSCRIBER 중복 확인 | `idx_notifications_user_created`, `idx_notifications_user_read` |
| 검색 | `ft_posts_title_content`, `ft_posts_title`, `ft_tags_name`, `idx_post_tags_tag` |
| 피드 | `idx_posts_blog_status_visibility_published`, `idx_posts_category` |
| 사이트맵 | PK 순 조회 |
| 관련 글 | `idx_post_tags_tag`, PK `(post_id, tag_id)`, `idx_posts_blog_status_visibility_published` |
| 글 영구 삭제(001 TrashPurgeJob) | `post_likes`는 FK CASCADE로 함께 삭제. `notifications.target_id`는 FK 없음(알림은 남음) |
| 블로그 정리(30일) | `blog_subscriptions`는 FK CASCADE가 없으므로 정리 작업이 먼저 지움(tasks.md) |

엔티티는 기존 스키마에 맞춰 만들고(`ddl-auto=validate`, `EntitySchemaValidationTest`), 구현 중 스키마 변경이 필요해지면 새 작업을 만들어 [db/README.md](../../db/README.md) 절차(data-model·erd.md → Crowfoot 문서 → `plan_migration` → **marco 승인(Crowfoot)** → `apply_migration` → `migrations/NNNN-*.sql` → `schema-mysql.sql`·backend 테스트 스냅숏 → 엔티티)를 따른다. 운영 DB의 `ngram_token_size`는 MySQL 기본값 2이며, 다른 값으로 설정된 서버라면 FULLTEXT 인덱스를 다시 만들어야 한다(quickstart 준비 절차의 확인 명령).

## Project Structure

### Documentation (this feature)

```text
specs/002-discovery-feeds/
├── spec.md              # 기능 스펙
├── plan.md              # 이 문서
├── research.md          # Phase 0: 기술 결정과 근거 (D1~D11)
├── data-model.md        # Phase 1: 테이블·알림 종류 (스펙 단계에서 작성, 변경 없음)
├── quickstart.md        # Phase 1: 실행·수동 검증 시나리오
├── contracts/
│   ├── api.md           # 002 REST API·피드·사이트맵 계약, 001 응답 확장
│   └── routes.md        # 002 화면과 001 화면 변경
├── checklists/requirements.md
└── tasks.md             # Phase 2: 작업 목록과 구현 전 결정 사항
```

### Source Code

001 구조(001 plan.md)에 아래를 더한다. 패키지 안 구성은 001과 같이 `controller`, `service`, `repository`, `domain`, `dto`, `job`, `event`.

```text
blog-backend/src/main/java/net/java21/blog/backend/
├── like/              # 좋아요: PostLike 엔티티, INSERT IGNORE 저장소, PostLikeService, PostLikeController(/me/likes)
├── subscription/      # 구독: BlogSubscription 엔티티, SubscriptionService, 구독 피드 쿼리, BlogSubscribedEvent, SubscriptionController(/me/subscriptions, /me/feed)
├── notification/      # 알림: Notification 엔티티, NotificationType, 이벤트 리스너, 목록·읽음, NotificationPurgeJob
├── search/            # 검색: SearchQueryParser, PostSearchRepository(QueryDSL + MATCH 함수), SearchController
├── syndication/       # RSS·Atom: FeedService(글 선택·ETag), RssFeedWriter·AtomFeedWriter(ROME), FeedContentUrlRewriter, FeedController(/{handle}/rss 등)
├── seo/               # 사이트맵·robots: SitemapService(StAX), SitemapController, RobotsController
├── common/persistence/MySqlFullTextFunctions.java   # Hibernate FunctionContributor(MATCH ... AGAINST)
├── post/              # (001) + 관련 글 RelatedPostQueryRepository·RelatedPostService, PostDetail의 likeCount·likedByMe
├── blog/              # (001) + Blog의 subscriberCount·feed 설정, BlogResponse 확장, PATCH 피드 설정
├── comment/           # (001) + CommentCreatedEvent 발행
└── user/              # (001) + /me unreadNotificationCount, 탈퇴 시 구독 정리, 파기 시 알림 삭제
blog-backend/src/main/resources/META-INF/services/org.hibernate.boot.model.FunctionContributor

blog-front/app/
├── routes/search.tsx, feed.tsx, notifications.tsx, manage/feed.tsx
├── components/post/LikeButton.tsx, RelatedPosts.tsx, ShareButtons.tsx
├── components/blog/SubscribeButton.tsx
├── components/notification/NotificationItem.tsx
├── components/layout/Header.tsx         # (001) + 검색창·구독 피드·알림 배지
├── share/kakao.client.ts                # Kakao SDK 지연 로딩
├── seo/feedLinks.ts                     # 자동 발견 link 메타
├── server/securityHeaders.ts            # (001) + 카카오 출처(키가 있을 때만)
└── locales/{ko,en,ja,zh-CN}/discovery.json, notification.json   # + manage.json·errors.json에 키 추가
```

**Structure Decision**: 001의 도메인별 패키지 구조를 따른다. "피드"가 구독 피드와 RSS 피드 두 뜻이라 RSS·Atom은 `syndication`, 구독 피드는 `subscription`에 둔다. 사이트맵·robots는 검색 엔진용이라 `seo`에 둔다.

## 구현 순서 (사용자 스토리 기준)

| 단계 | 스토리 | 핵심 산출물 | FR |
|---|---|---|---|
| 0 | 기반 | ROME 의존성, 새 컬럼 엔티티 매핑(읽기 전용 카운터·피드 설정), MATCH 함수 등록, 공개 경로(보안), 새 오류 코드, front 번역 namespace·모델 타입 | - |
| 1 | US1 좋아요·구독·구독 피드 (P1) | like, subscription, `/me/feed`, PostDetail·BlogResponse 확장, 블로그 홈·글 상세 버튼, `/feed`, 탈퇴 시 구독 정리, 블로그 정리 시 구독 삭제 | FR-030~032 |
| 1a | US1 알림 (P1) | notification(이벤트 리스너, 목록·읽음, 정리 작업), `/me` 안 읽은 수, `/notifications`, 상단 배지 | FR-033 |
| 2 | US2 검색·검색 엔진 노출 (P2) | search(MATCH + PostExposure), `/search`, 상단 검색창, 사이트맵·robots, SSR 확인 | FR-035, FR-037 |
| 2a | 글 상세 보강 (US2에 포함) | 관련 글 API·영역, 공유 버튼(카카오 SDK·CSP), 공유 메타 확인 | FR-068, FR-069 |
| 3 | US3 RSS·Atom (P3) | syndication(ROME, 절대 주소, ETag·304), 피드 설정 API·화면, 자동 발견 링크 | FR-044~048 |

각 단계는 끝날 때 해당 스토리의 Independent Test를 E2E로 통과해야 한다. 단계 1a·2·2a·3은 단계 0 이후 서로 독립이지만, 같은 파일(`ErrorCode`, `SecurityConfig`, `post-detail.tsx`, `blog-home.tsx`, `Header.tsx`, `errors.json`)을 고치는 작업은 순서대로 머지한다.

**범위 밖(다른 스펙)**: 포털 검색창·인기 점수(최근 7일 좋아요 수)·포털의 "구독 피드 보기" 링크(003), 보호 글·예약 발행(PROTECTED·SCHEDULED, 004 — 002는 노출 조각만 따르므로 004가 값을 더하면 검색·피드가 그대로 따른다), 블로그 내 검색(`/:handle/search`, 004 FR-061), 차단 시 구독 해제(004 FR-146), 백업 준비 알림(004 FR-145), 숨김(HIDDEN)·신고 처리 알림(005), 시스템 관리자 콘솔(006), 외부 블로그 알림(007). 이 스펙의 알림 목록·API·화면은 위 종류를 행과 문구만 더해 받을 수 있게 만든다.

## Complexity Tracking

| 도입 | 이유 | 더 단순한 대안을 쓰지 않은 이유 |
|---|---|---|
| ROME `com.rometools:rome` 2.1.0 (backend) | FR-044·048, SC-008: RSS 2.0·Atom 1.0을 검증기 오류 없이 생성(날짜 형식, 네임스페이스, 이스케이프). 007이 외부 피드를 읽을 때도 같은 라이브러리를 쓴다 | StAX로 직접 쓰면 두 형식의 규칙(RFC 822/3339 날짜, `atom:link`, `dc:creator`, guid)을 직접 유지해야 하고 007에서 파서를 따로 만들어야 함 (research D6) |
| Kakao JavaScript SDK 2.x (front, CDN 지연 로딩) | FR-069 카카오톡 공유는 공유 URL 방식이 없어 SDK 없이는 불가(spec Assumptions, 001 R21). 공유 버튼을 누를 때만 SRI와 함께 불러오고, 키가 없으면 버튼을 숨김 | 카카오톡 공유를 빼면 FR-069 미충족. Web Share API는 데스크톱 지원이 고르지 않음 (research D9) |
| Hibernate `FunctionContributor`(MATCH 함수 등록) | 검색 쿼리가 001 `PostExposure`의 노출 조각을 그대로 써야 함(원칙 IV "한 곳") | 네이티브 SQL이면 노출 조건을 SQL로 한 번 더 써야 해 규칙이 두 곳이 됨 (research D4) |
