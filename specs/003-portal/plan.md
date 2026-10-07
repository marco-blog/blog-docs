# Implementation Plan: 포털 (주제별 글 모아보기와 메인)

**Branch**: `003-portal` (계획 문서는 `docs/003-plan`) | **Date**: 2026-10-06 | **Spec**: [spec.md](./spec.md)

**Status**: Phase 1 완료 (research, contracts, quickstart, tasks 작성). 다음 단계는 `/speckit-analyze` 후 `/speckit-implement`.

**Input**: Feature specification from `/specs/003-portal/spec.md`

## Summary

서비스 메인(`/`)을 001의 임시 화면에서 여러 블로그의 글을 모은 포털로 바꾼다. 메인은 운영자 추천, 주제 탭(대분류), 인기 글 12편, 최신 글(20편씩 "더 보기"), 인기 태그 20개, 새로 시작한 블로그 6개를 보여주며 같은 블로그 글은 영역마다 2편까지만 둔다(US1, FR-034·080·085~087·090·094·095). 방문자는 `/topics/{대분류}`·`/topics/{대분류}/{소분류}`에서 주제별 글을 최신순·인기순으로 보고(US2, FR-078·147), 글쓴이는 글마다 서비스 주제(소분류)를 고르며 블로그 기본 주제와 "포털에 내 글 노출"을 설정한다(US3, FR-076·077·089). 운영자는 시스템 관리자 콘솔의 뼈대 위 주제 관리·포털 관리 메뉴에서 주제·추천·포털 제외·포털 설정값을 다룬다(US4, FR-075·079·091~093, 006 FR-102의 003 메뉴). 회원과 방문자는 포털 카드·상단 배너·`/updates` 위키에서 릴리스 노트를 읽는다(US5, FR-161~166).

기술 접근: 포털 노출 조건(FR-088)은 001 `PostExposure.bodyVisible()`에 조건을 더한 QueryDSL 조각 `PortalExposure` 한 곳에만 둔다. 인기 점수(FR-086)는 최근 7일 `post_daily_stats`(조회·끝까지 읽음)·`post_likes`·`comments`를 가중합하고 반감기로 낮춘 값을 메모리 스냅숏으로 만들며, 포털 목록·점수·주제 자동 숨김 계산은 Caffeine 5분 캐시로 FR-090(5분 안에 반영)을 지킨다. 관리자 쓰기는 캐시를 바로 비운다. 스키마는 이미 Crowfoot 문서에 있어 DDL 변경 없이 시작하고, 성능 측정 결과에 따라 인덱스 3개를 제안한다(아래 "스키마 변경"). 세부 근거는 [research.md](./research.md).

## Technical Context

**Language/Version**: backend Java 21 / front TypeScript 5.9, Node.js 22 LTS (001·002와 같음)

**Primary Dependencies**:
- backend(001·002 그대로): Spring Boot 4.1.1(Web MVC, Security, Data JPA, Validation), QueryDSL OpenFeign 7.x, Hibernate 7, Caffeine, commonmark-java + OWASP HTML Sanitizer, springdoc-openapi. **새 의존성 없음**
- front(001·002 그대로): React 19, React Router 8.4 framework 모드, Vite 8, Express 5, i18next + react-i18next. **새 의존성 없음**(상대 시각은 `Intl.RelativeTimeFormat`, 끝까지 읽음 감지는 `IntersectionObserver`)

**Storage**: MySQL 8(InnoDB, utf8mb4, ngram_token_size=2). 003의 테이블(`topics`, `portal_curations`, `portal_exclusions`, `post_daily_stats`, `system_settings`)과 001 테이블 추가 컬럼(`users.last_seen_release_version`, `blogs.portal_enabled`·`default_topic_id`·`first_published_at`, `posts.topic_id`, `post_drafts.topic_id`), 006이 정의한 릴리스 노트 테이블 3개와 FULLTEXT `ft_release_note_contents`가 Crowfoot 문서 "blog 1.0"(`db/schema-mysql.sql`)에 이미 있다. 아래 "스키마 변경" 참고

**Testing**: 001·002와 같음. JUnit 5, `@WebMvcTest` + `WebMvcTestSupport`, Mockito, `@JpaRepositoryTest`(H2) + `QueryCounter`, MySQL 전용(릴리스 노트 FULLTEXT 검색, `post_daily_stats` upsert 동시성)만 `@MySqlRepositoryTest`, `@SpringBootTest`는 포털 노출 통합 확인만, Testcontainers 없음, JaCoCo 라인 80%. front Vitest(80%) + Playwright E2E(실제 backend, `requireBackend()`; 관리자 시나리오는 `requireAdmin()`)

**Target Platform**: Linux 서버 1대(backend 1대 전제, 001 R26 — 메모리 캐시·스냅숏이 이 전제에 기댄다), 최신 데스크톱/모바일 브라우저

**Project Type**: 웹 서비스(REST API + SSR 웹 앱), 저장소 3개

**Performance Goals**: 포털 메인·주제 페이지 p95 1초(SC-012, 회원 1만·글 10만 규모). 상태 변화 반영 5분 이내(FR-090, SC-013). 메인 loader는 backend 호출 3회(병렬: `/portal`, `/topics`, `/release-notes`)

**Constraints**: 비공개·삭제·숨김·포털 제외 글 포털 노출 0건(SC-004·013, 001 글 노출 매트릭스 "포털" 열), 영역별 같은 블로그 2편 초과 0건(SC-014), 자동 숨김 기준 미만 주제의 탭 노출 0건(SC-023), 커버리지 80%, 번역 누락 0건, N+1 금지

**Scale/Scope**: 새 공개 API 5개 + 001 contracts에 정의된 릴리스 노트 독자 API 6개, 관리자 API 24개(주제 4, 포털 8, 설정 3, 001 contracts에 정의된 릴리스 노트 관리 9), 새 화면 11개(포털 메인 교체, 주제 2, `/updates` 4, `/admin` 콘솔 4 + 레이아웃), 001·002 화면 변경 4곳(글쓰기 발행 설정, 블로그 설정, 글 상세, 공통 상단)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| 원칙 | 확인 | 결과 |
|---|---|---|
| I. 스펙이 먼저다 | spec.md 확정(NEEDS CLARIFICATION 0개, checklist 통과). 이 plan은 FR-034, 075~080, 085~095, 147, 161~166과 006 FR-102의 003 메뉴(주제 관리·포털 관리), 006 FR-167·168의 backend API(001 contracts에 이미 정의, 결정 표 4번)만 다룬다. 모호한 점은 tasks.md "구현 전 결정 사항"에 기본값으로 기록(marco "묻지 말고 진행") | 통과 |
| II. 세 저장소, 두 실행 파트 | 캐시·인기 점수는 backend 프로세스 안 Caffeine과 메모리 스냅숏. Redis·검색 엔진·큐 추가 없음. front는 REST API만 호출 | 통과 |
| III. 테스트 우선·커버리지 | 각 스토리의 테스트 작업이 구현보다 앞섬, 인수 시나리오마다 테스트(tasks.md), H2 + 쿼리 수 확인, MySQL 전용만 `@MySqlRepositoryTest`, Testcontainers 없음, 80% 게이트 유지 | 통과 |
| IV. 보안과 공개 범위 | 모든 포털 쿼리가 `PortalExposure.portalVisible()`(= `PostExposure.bodyVisible()` + FR-088) 한 조각만 사용. 캐시에 든 카드도 5분 안에 다시 계산(FR-090)하고 관리자 제외·주제 숨김은 캐시를 바로 비움. 관리자 API는 001 `AdminAccessFilter`(DB role 재확인, 아니면 404). 쓰기 API는 블로그 주인 검증. 릴리스 노트 HTML은 001 변환·살균을 거치고 제목 `id`만 추가로 허용 | 통과 |
| V. SSR | 포털 메인, 주제 페이지, `/updates`·버전 페이지는 SSR(JS 없이 목록·본문·메타 포함, FR-094·164). "더 보기"는 JS 없이 `/?cursor=` 링크로도 동작 | 통과 |
| VI. 단순함 | 새 라이브러리 없음. 메모리 인기 점수 스냅숏 하나와 Caffeine 캐시만 추가(Complexity Tracking). 점수 저장 테이블·배치 서버 없음 | 통과 |
| VII. 다국어 우선 | 새 문구는 `portal`·`updates`·`admin` namespace와 `post`·`manage`·`common`·`errors`에 4개 언어로. 주제 이름은 DB의 4개 언어 값(FR-079), 릴리스 노트는 언어판 대체(FR-161). 새 오류 코드 9개 + 001에 정의된 릴리스 노트 코드 5개 번역 | 통과 |
| 기술 제약 | Java 21, Spring Boot 4, JPA + QueryDSL(OpenFeign), N+1 금지, Crowfoot 스키마(DDL 변경은 아래 제안만, marco 승인 전 구현하지 않음), 공통 응답 틀(커서 목록은 `nextCursor`, 설계 규칙 4절), `blog.*` 프로퍼티 | 통과 |

**Phase 1 이후 재확인**: research, contracts(api.md, routes.md), quickstart, tasks 작성 후 원칙 I~VII을 다시 점검했고 위반 없음. 설계 규칙과 다르게 만든 곳(포털 제외 PUT의 멱등 생성)은 contracts/api.md에 이유를 적었다.

## 스키마 변경

**DDL은 지금 필요 없다.** 003 data-model의 테이블·컬럼·인덱스·외래 키와 006의 릴리스 노트 테이블이 모두 `db/schema-mysql.sql`(Crowfoot 문서 "blog 1.0", migrations/0001-baseline.sql)에 있다. 003 쿼리를 하나씩 대조했다.

| 쿼리 | 쓰는 인덱스·제약 | 비고 |
|---|---|---|
| 주제 트리·자식 순서 | `idx_topics_parent_sort`, `uk_topics_slug` | |
| 주제 페이지(최신순) | `idx_posts_topic_status_visibility_published` | 대분류는 `topic_id IN (소분류들)` |
| 메인 최신 글(커서) | (없음) `posts` 전체에서 `status`·`visibility` 조건 + `published_at DESC` | 5분 캐시. 아래 제안 1 |
| 인기 점수: 조회·끝까지 읽음 | `idx_post_daily_stats_stat_date` | |
| 인기 점수: 최근 7일 좋아요 | (없음) `post_likes.created_at` 범위 | PK·`idx_post_likes_post_created`는 글별 조회용. 아래 제안 2 |
| 인기 점수: 최근 7일 댓글 | (없음) `comments.created_at` 범위 | `idx_comments_post_created`는 글별 조회용. 아래 제안 3 |
| 인기 태그(최근 7일 발행) | `idx_post_tags_tag`, PK `(post_id, tag_id)` + 제안 1 | |
| 새로 시작한 블로그 | `idx_blogs_first_published_at` | |
| 주제 자동 숨김(최근 30일 글 수) | 제안 1 | 5분 캐시 |
| 추천(지금 기간) | `idx_portal_curations_period` | |
| 포털 제외 확인 | `uk_portal_exclusions_post` | NOT EXISTS |
| 설정값 | PK `setting_key` | 메모리 캐시 |
| 릴리스 노트 목록·이전/다음 | `idx_release_notes_status_version` | |
| 릴리스 노트 검색 | `ft_release_note_contents` | MySQL 전용 |
| 마지막 확인 버전 | `users` PK | 비교 후 갱신(CAS) |

포털 목록은 5분 캐시를 거쳐 한 번 계산한 결과를 여러 요청이 나눠 쓰므로(FR-090이 허용하는 지연), 위 "(없음)" 쿼리도 회원 1만·글 10만 규모에서 캐시 갱신 1회당 수백 ms 안에 끝날 것으로 본다. 따라서 **인덱스 없이 구현하고 Polish의 성능 측정(tasks.md T126)에서 SC-012를 넘거나 `EXPLAIN`이 10만 행 이상 전체 스캔을 보일 때만** 아래 DDL을 marco에게 요청한다. 승인 전에는 구현하지 않으며, 승인되면 [db/README.md](../../db/README.md) 절차(data-model·erd.md → Crowfoot 문서 → `plan_migration` → **marco 승인(Crowfoot)** → `apply_migration` → `migrations/NNNN-*.sql` → `schema-mysql.sql`·backend 테스트 스냅숏)를 따른다.

**반영 (2026-10-07, marco 승인)**: 제안 1은 `(…, id DESC)`로 늘려 [migrations/0002](../../db/migrations/0002-add-query-indexes.sql)로 반영했고, 주제 페이지용 `idx_posts_topic_status_visibility_published_id (topic_id, status, visibility, published_at DESC, id DESC)`도 함께 더했다. 제안 2·3은 T126 측정에서 필요하지 않아 넣지 않았다. 아래 백필은 [migrations/0003](../../db/migrations/0003-backfill-first-published-at.sql)에 있고 marco가 직접 실행한다.

**제안 DDL (needs owner approval via Crowfoot)**

```sql
-- 제안 1: 서비스 전체 최신 글(포털 메인 최신 글·인기 태그·주제 자동 숨김의 최근 30일 집계)
CREATE INDEX idx_posts_status_visibility_published ON posts (status ASC, visibility ASC, published_at DESC);
-- 제안 2: 인기 점수의 최근 7일 좋아요 수
CREATE INDEX idx_post_likes_created ON post_likes (created_at ASC);
-- 제안 3: 인기 점수의 최근 7일 댓글 수
CREATE INDEX idx_comments_created ON comments (created_at ASC);
```

**데이터 보정 (needs owner approval, DDL 아님)**: `blogs.first_published_at`은 003 배포 뒤 처음 발행하는 글부터 채워진다. 이미 글이 있는 블로그가 "새로 시작한 블로그"(FR-087)에서 빠지지 않게, 배포 때 한 번 아래 SQL을 `migrations/NNNN-backfill-first-published-at.sql`로 남기고 marco 승인 후 실행한다(db/README "초기 데이터": 데이터를 바꾸는 일회성 작업도 같은 승인 절차).

```sql
UPDATE blogs b
   SET b.first_published_at = (SELECT MIN(p.published_at) FROM posts p
                                WHERE p.blog_id = b.id AND p.published_at IS NOT NULL)
 WHERE b.first_published_at IS NULL;
```

엔티티는 기존 스키마에 맞춰 매핑하며(`ddl-auto=validate`, `EntitySchemaValidationTest`), 지금까지 "003 컬럼은 매핑하지 않는다"고 적힌 `Post`·`Blog`·`User`·`PostDraft` 주석을 고친다. 007 컬럼(`portal_exclusions.external_post_id` 등)은 003에서 매핑하지 않는다(NULL 허용, CHECK는 `post_id`만 채우면 만족).

## Project Structure

### Documentation (this feature)

```text
specs/003-portal/
├── spec.md              # 기능 스펙
├── plan.md              # 이 문서
├── research.md          # Phase 0: 기술 결정과 근거 (P1~P14)
├── data-model.md        # Phase 1: 테이블·노출 계산 (스펙 단계에서 작성, 변경 없음)
├── quickstart.md        # Phase 1: 실행·수동 검증 시나리오
├── contracts/
│   ├── api.md           # 003 REST API 계약(공개·관리자), 001 응답 확장
│   └── routes.md        # 003 화면과 001·002 화면 변경
├── checklists/requirements.md
└── tasks.md             # Phase 2: 작업 목록과 구현 전 결정 사항
```

### Source Code

001·002 구조에 아래를 더한다. 패키지 안 구성은 001과 같이 `controller`, `service`, `repository`, `domain`, `dto`, `job`, `event`. 관리자 API는 001 `admin/user`처럼 `admin/{기능}` 아래 두고, 엔티티는 기능 패키지에 둔다.

```text
blog-backend/src/main/java/net/java21/blog/backend/
├── topic/             # 주제: Topic 엔티티, TopicRepository·TopicQueryRepository, TopicService(트리·선택 가능 검사), TopicSeeder(초기 목록, 멱등), TopicController(/topics)
├── portal/            # 포털: PortalProperties, PortalExposure(노출 조각), PortalQueryRepository(카드·최신·주제·인기 태그·새 블로그·주제별 글 수),
│                      #       PopularityCalculator·PopularitySnapshot, PortalCache(Caffeine), PortalService, PortalController(/portal, /topics/{slug}/posts),
│                      #       domain/PortalCuration·PortalExclusion, BlogPenaltyPolicy(005가 구현을 바꿈)
├── setting/           # 운영 설정: SystemSetting 엔티티, SettingKey(키별 형식·기본 프로퍼티), SystemSettingsService(메모리 캐시)
├── releasenote/       # 릴리스 노트: ReleaseNote·ReleaseNoteContent·ReleaseNoteRevision 엔티티, ReleaseNoteRenderer(제목 앵커·목차),
│                      #       ReleaseNoteQueryService(언어판 대체·이전/다음·수정 이력·검색), ReleaseNoteSeenService, ReleaseNoteController(/release-notes, /me/release-notes/seen)
├── admin/topic/       # AdminTopicController·AdminTopicService (/admin/topics)
├── admin/portal/      # AdminCurationController·AdminExclusionController·AdminPortalPostController·서비스 (/admin/portal/**)
├── admin/setting/     # AdminSettingController (/admin/settings)
├── admin/releasenote/ # AdminReleaseNoteController·AdminReleaseNoteService (/admin/release-notes, 001 contracts)
├── post/              # (001) + Post.topic 매핑, PostDailyStat 엔티티·PostDailyStatsRepository(upsert), ReadCompleteService, PostStatsPurgeJob, 발행 시 주제 검증·first_published_at
├── blog/              # (001) + Blog.portalEnabled·defaultTopic·firstPublishedAt, BlogResponse·UpdateBlogRequest 확장
├── user/              # (001) + User.lastSeenReleaseVersion, MeQueryService.unseenReleaseNote
├── content/           # (001) + HtmlSanitizerPolicy의 릴리스 노트용 변형(제목 id 허용)
└── seo/               # (002, 진행 중) + 사이트맵 pages.xml에 주제 페이지·릴리스 노트 버전, robots에 /admin
blog-backend/src/main/resources/portal/topics-seed.json   # FR-075 초기 주제 목록(4개 언어 이름·slug·색)

blog-front/app/
├── routes/home.tsx                          # (001 임시 메인) → 포털 메인으로 교체
├── routes/topic.tsx                         # /topics/:major, /topics/:major/:minor (한 모듈)
├── routes/updates/layout.tsx, index.tsx, version.tsx, history.tsx, revision.tsx, seen.ts
├── routes/admin/layout.tsx, index.ts, topics.tsx, curations.tsx, exclusions.tsx, settings.tsx
├── components/portal/PortalCard.tsx, CurationSection.tsx, TopicTabs.tsx, PopularPosts.tsx, LatestPosts.tsx,
│                    PopularTags.tsx, NewBlogs.tsx, ReleaseNoteCard.tsx, EmptyPortal.tsx
├── components/updates/VersionTree.tsx, Toc.tsx, ReleaseNoteSearch.tsx
├── components/layout/ReleaseNoteBanner.tsx  # 공통 상단 아래 한 줄 배너
├── components/post/TopicSelect.tsx, ReadCompleteTracker.tsx
├── portal/topics.ts, cursor.ts              # 주제 이름·색·slug 찾기, 커서 링크
├── updates/versionTree.ts                   # major.minor 묶음
├── admin/access.server.ts                   # 관리자 화면 접근(아니면 404)
└── locales/{ko,en,ja,zh-CN}/portal.json, updates.json, admin.json   # + post·manage·common·errors에 키 추가
```

**Structure Decision**: 001의 도메인별 패키지 구조를 따른다. 주제(`topic`)는 글쓰기·블로그 설정·포털·007이 함께 쓰므로 포털과 따로 둔다. 운영 설정(`setting`)은 005·007이 키를 더하므로 공용 패키지로 둔다. 릴리스 노트는 독자(003)와 관리(006) 양쪽이 쓰는 한 도메인이라 `releasenote` 하나에 두고, 관리자 컨트롤러만 `admin/releasenote`에 둔다.

## 구현 순서 (사용자 스토리 기준)

| 단계 | 스토리 | 핵심 산출물 | FR |
|---|---|---|---|
| 0 | 기반 | 003 엔티티 매핑(Topic, 포털 테이블, 설정, 릴리스 노트, 001 추가 컬럼), `PortalExposure`, `SystemSettingsService`, `TopicSeeder`, 공개 주제 API(`GET /topics`), 오류 코드, 공개 경로(보안), front 번역 namespace·모델 타입, E2E 도구(`requireAdmin`) | FR-075, FR-088 |
| 1 | US1 포털 메인 (P1) | 조회 일별 집계 upsert, 끝까지 읽음 API, 인기 점수 스냅숏, 포털 캐시, `GET /portal`(추천·인기·최신·인기 태그·새 블로그·주제 탭), 최신 글 커서, `first_published_at`, 포털 메인 SSR, 글 상세의 끝까지 읽음 감지, 상단 링크 | FR-034, 080, 085~088, 090, 094, 095, 147 |
| 2 | US2 주제 페이지 (P2) | `GET /topics/{slug}/posts`(최신·인기, 페이지), `/topics/:major(/:minor)` SSR, 숨김 주제 404, 사이트맵에 주제 페이지 | FR-078, 094, 147 |
| 3 | US3 글에 주제 지정 (P3) | 작성 중 사본·발행 설정의 `topicId`(검증), 블로그 `portalEnabled`·`defaultTopicId`, 발행 설정의 주제 선택, 블로그 설정 화면 | FR-076, 077, 089 |
| 4 | US4 운영자 큐레이션·주제 관리 (P4) | 관리자 주제·추천·포털 제외·설정값 API(작업 기록), 시스템 관리자 콘솔 뼈대(`/admin` 레이아웃·메뉴)와 주제·포털 관리 화면 | FR-079, 091~093, 147, 006 FR-102(003 메뉴) |
| 5 | US5 릴리스 노트 읽기 (P5) | 릴리스 노트 관리 API(backend, 001 contracts), 독자 API·검색·수정 이력·마지막 확인 버전, `GET /me`의 `unseenReleaseNote`, 포털 카드, 상단 배너, `/updates` 위키, 사이트맵에 버전 페이지 | FR-161~166 |

각 단계는 끝날 때 해당 스토리의 Independent Test를 E2E로 통과해야 한다. 단계 2~5는 단계 0 이후 서로 독립이지만 US1의 카드 DTO·포털 캐시(단계 1)를 US2가, 관리자 쓰기의 캐시 무효화(단계 4)를 US1·US2 캐시가 쓰므로 1 → 2 순서를 권한다. 같은 파일(`ErrorCode`, `SecurityConfig`, `BlogResponse`·`UpdateBlogRequest`·`BlogService`, `PostPublishService`, `MeQueryService`, `root.tsx`, `Header.tsx`, `post-detail.tsx`, `routes.ts`, `errors.json`)을 고치는 작업은 순서대로 머지한다.

**002 진행 중 작업과의 관계**: 002 Phase 5~8(검색·사이트맵·robots, 관련 글·공유, RSS·Atom, Polish)이 `feat/002-rest`에서 구현 중이다. 003이 그 결과에 기대는 곳은 tasks.md "Dependencies"의 "002 의존" 표에 적었다(사이트맵 `SitemapService`·`RobotsController`(002 T071), 상단 검색창(002 T072, FR-095), `post-detail.tsx` 변경(002 T081·T096), `UpdateBlogRequest`·`BlogResponse`·`manage/settings.tsx` 인접 변경(002 T095), Polish 공용 테스트(002 T098~T101)). 003은 002가 main에 머지된 뒤 시작한다.

**범위 밖(다른 스펙)**:
- 004: 보호 글(PROTECTED)·예약 발행(SCHEDULED). 포털은 `bodyVisible()`만 쓰므로 보호 글은 자동으로 빠지고, 예약 발행 글이 실제로 발행될 때 004가 `Blog.markFirstPublished`를 같은 방식으로 부른다. 블로그 내 검색·방문자 통계 화면.
- 005: 숨김(HIDDEN, 노출 조각이 PUBLISHED만 보므로 자동으로 빠짐), 신고, 인기 점수의 "신고가 인정되었거나 숨김 처리된 이력이 있는 블로그" 감점 데이터(003은 `BlogPenaltyPolicy` 자리와 `reportPenalty` 가중치만 둔다, 결정 표 9번), `ratelimit.*` 설정 키.
- 006: 콘솔 대시보드(FR-103), 회원·신고·외부 블로그·예약어·관리자·작업 기록 메뉴, **릴리스 노트 관리 화면**(`/admin/release-notes/**`), 서비스 설정 메뉴의 003 외 키. 003은 콘솔 뼈대와 주제·포털 관리 메뉴만 만든다(006 spec 머리말 "시스템 관리자 콘솔의 뼈대와 주제·큐레이션 메뉴는 003과 함께").
- 007: 외부 블로그 글의 포털 노출·점수(FR-123·124)·외부 글 포털 제외(`portal_exclusions.external_post_id`)·주제 자동 숨김 글 수의 외부 글 합산. 003의 카드·목록 쿼리는 내부 글만 다루고 007이 합친다.
- 스펙 범위 밖: 개인화 추천, 광고·배너 관리, 실시간 인기 검색어(spec Assumptions).

## Complexity Tracking

| 도입 | 이유 | 더 단순한 대안을 쓰지 않은 이유 |
|---|---|---|
| 메모리 인기 점수 스냅숏(`PopularitySnapshot`, 5분마다 다시 계산) | FR-086: 최근 7일 네 가지 신호의 가중합 + 시간 감쇠 + 운영자 가중치. 메인 인기 글과 주제 페이지 인기순이 같은 점수를 써야 한다 | 요청마다 SQL로 계산하면 세 테이블 집계 + 감쇠식을 매번 실행(SC-012 위험). 점수 테이블에 저장하면 스키마 변경과 배치 작업이 늘어남. backend 1대 전제(001 R26)라 메모리로 충분 (research P4) |
| 포털 Caffeine 캐시(`PortalCache`) | FR-090이 5분 지연을 허용하고 SC-012(p95 1초)를 지켜야 함. Caffeine은 001부터 쓰는 의존성 | 캐시 없이 요청마다 6개 영역 쿼리를 실행하면 메인 1회에 쿼리 10여 개. HTTP 캐시는 로그인 회원의 상단(배너·알림)과 섞여 쓸 수 없음 (research P5) |
| 릴리스 노트용 살균 정책 변형(제목 `id` 허용) | FR-164: 절 단위 앵커 주소(`/updates/v1.2.0#새-기능`) | 001 정책에 `id`를 열면 회원 글 본문에도 허용되어 DOM clobbering 여지가 생김. 노트는 관리자만 쓰므로 변형 정책을 노트에만 쓴다 (research P11) |
