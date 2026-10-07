---
description: "004 블로그 꾸미기와 글 옵션 작업 목록"
---

# Tasks: 블로그 꾸미기와 글 옵션 (방명록·공지·보관함·보호 글·예약·백업·차단)

**Input**: `/specs/004-blog-features/`의 설계 문서 (spec.md, plan.md, research.md, data-model.md, contracts/api.md, contracts/routes.md, quickstart.md)

**Prerequisites**: 001-blog-core·002-discovery-feeds·003-portal 구현 완료(blog-backend·blog-front main. 003 Phase 5~8은 `feat/003-rest`에서 구현되어 main 머지 대기 중이며, 004는 그 머지 후 시작, 아래 "003 의존"), plan.md, spec.md, research.md, data-model.md, contracts/, 헌법 v2.5.0, [api-guidelines.md](../../api-guidelines.md), [db/README.md](../../db/README.md)

**Tests**: 헌법 원칙 III(NON-NEGOTIABLE)에 따라 모든 스토리에 테스트 작업이 있고, 각 스토리 안에서 테스트 작업이 구현 작업보다 앞선다. 테스트를 먼저 쓰고 **실패하는 것을 확인한 뒤** 구현한다. backend·front 모두 라인 커버리지 80% 미만이면 빌드가 실패한다.

**Organization**: 사용자 스토리별로 묶었다. spec의 US1(방명록)·US2(꾸미기·탐색)·US3(글 공개 옵션)에 더해, spec에 사용자 스토리가 없는 FR-145(백업)와 FR-146(차단)을 plan이 US4·US5로 만들었다(결정 표 1번). 비회원 쓰기 규칙·차단 확인·비밀번호 시도 제한처럼 여러 스토리가 쓰는 것은 Phase 2에 둔다.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: 병렬 가능(다른 파일, 끝나지 않은 작업에 의존하지 않음)
- **[Story]**: 해당 사용자 스토리(US1~US5)
- 경로는 저장소 이름(`blog-backend/`, `blog-front/`)으로 시작한다(blog-docs CLAUDE.md 규칙)
- 작업 번호는 이 스펙 안에서 T001부터 센다(001~003 tasks.md와 별개)

## Path Conventions

- backend 소스: `blog-backend/src/main/java/net/java21/blog/backend/{domain}/{controller|service|repository|domain|dto|event|job}/` — 이 스펙의 새 도메인은 `guestbook`, `guest`, `sidebar`, `stats`, `export`, `block`, 공용 `common/security`
- backend 테스트: `blog-backend/src/test/java/net/java21/blog/backend/{domain}/...` (Controller `*ControllerTest` = `@WebMvcTest` + `@Import(WebMvcTestSupport.class)` + `@MockitoBean`, Service `*ServiceTest` = Mockito 단위, Repository `*RepositoryTest` = H2 `@JpaRepositoryTest` + `QueryCounter.assertQueryCount`, MySQL 전용(FULLTEXT·동시 upsert)만 `@MySqlRepositoryTest`, 시각 고정은 `support/MutableClock`, 픽스처는 `support/JpaFixtures`·`support/TestEntities`, 쿠키는 `support/AuthCookies`)
- backend 리소스: `blog-backend/src/main/resources/`
- front: `blog-front/app/` (routes, components, locales, api, blog, manage, i18n), 단위 테스트 `blog-front/tests/unit/`, E2E `blog-front/tests/e2e/`(backend 필요 시나리오는 `tests/e2e/support/backend.ts`의 `requireBackend()`, 비회원 쓰기 시나리오는 `requireGuestTestSettings()`)
- 화면 문구는 모두 `blog-front/app/locales/{ko,en,ja,zh-CN}/{namespace}.json` 키로 쓰고 4개 언어를 같은 작업에서 넣는다(원칙 VII). 이 스펙의 새 namespace는 `blog`, `guestbook`. 새 오류 코드는 `blog-front/app/api/errorCodes.ts`와 4개 언어 `errors.json`에 함께 넣는다(`tests/unit/i18n/errorCodes.test.ts`).
- backend 오류 코드는 `blog-backend/src/main/java/net/java21/blog/backend/common/error/ErrorCode.java`에 contracts/api.md 표의 이름·HTTP 상태 그대로 더한다.
- 응답 타입은 `blog-front/app/api/models.ts`에 contracts/api.md를 옮겨 적는다(OpenAPI 생성 스크립트는 001 후속 메모대로 아직 없음).

## 스키마 변경

**DDL 없음.** 004의 테이블(`guestbook_entries`, `blog_sidebar_items`, `blog_daily_visits`, `blog_exports`, `blog_blocks`), 001 테이블 추가 컬럼(`blogs.guestbook_enabled`·`guest_write_enabled`·`total_visitors`, `posts.password_hash`·`scheduled_at`·`notice`, `comments.guest_name`·`guest_password_hash`·`guest_ip_enc`·`secret`, `comments.user_id` NULL 허용), CHECK 3개와 인덱스·외래 키가 Crowfoot 문서 "blog 1.0"(`db/schema-mysql.sql`)에 모두 있다(plan.md "스키마 변경"의 쿼리별 대조표). 엔티티는 기존 스키마에 맞춰 만들고(`ddl-auto=validate`, `EntitySchemaValidationTest`), CHECK는 Hibernate `@Check`로 H2에도 건다(research B2).

**marco 승인이 필요한 것**: 없음. 방문 통계 보관 기간을 두기로 바꾸면(결정 표 15번) plan.md "스키마 변경"의 인덱스 제안을 Crowfoot `plan_migration` → **marco 승인** → `apply_migration` 절차로 따로 요청한다.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: front 번역·타입 틀, E2E 도구, backend 프로퍼티

- [x] T001 [P] 새 번역 namespace 파일 `blog-front/app/locales/{ko,en,ja,zh-CN}/blog.json`, `blog-front/app/locales/{ko,en,ja,zh-CN}/guestbook.json`을 같은 키 집합의 뼈대로 추가하고 `blog-front/app/i18n/config.ts`의 namespace 목록에 등록(이후 작업이 키를 채움, `tests/unit/i18n/translations.test.ts`가 4개 언어 키 일치 확인)
- [x] T002 [P] contracts/api.md 004 타입을 `blog-front/app/api/models.ts`에 추가: `GuestbookEntry`, `GuestbookWrite`, `CommentAuthor.guest`, `Comment.secret`, `SidebarItemType`, `SidebarView`, `SidebarConfig`, `ArchiveMonth`, `VisitorCounts`, `VisitStats`, `BlogExport`, `ExportStatus`, `BlockedUser`, `Blog`의 `guestbookEnabled`·`guestWriteEnabled`, `PostDetail`의 `locked`·`notice`·`scheduledAt`, `PostSummary`의 `notice`·`scheduledAt`, `PublishSettings`의 `password`·`scheduledAt`·`notice`, `Visibility`에 `PROTECTED`, `PostStatus`에 `SCHEDULED`, `Dashboard`의 `visitors`·`newGuestbook7d`·`recentGuestbook`, 알림 종류 `BACKUP_READY`
- [x] T003 [P] E2E 도구 `blog-front/tests/e2e/support/backend.ts`에 추가: `requireGuestTestSettings()`(`E2E_GUEST_TEST_SETTINGS=1`이 아니면 건너뜀), `setBlogSettings(request, handle, patch)`(PATCH /blogs/{handle}), `publishPost`에 `visibility: "PROTECTED"`·`password`·`scheduledAt`·`notice` 선택 인자, `waitForPublic(request, path, timeoutMs)`(예약·백업 작업을 기다리는 폴링, 기본 90초), `newGuestContext(browser)`(로그아웃 상태 새 컨텍스트)
- [x] T004 [P] backend 프로퍼티(contracts/api.md "프로퍼티" 표): `blog-backend/src/main/java/net/java21/blog/backend/stats/StatsProperties.java`(`time-zone`, `visit-dedup-max-size`, `bot-user-agent-pattern`), `blog-backend/src/main/java/net/java21/blog/backend/guest/GuestProperties.java`(`comment-per-minute`, `guestbook-per-minute`, `ip-retention`), `blog-backend/src/main/java/net/java21/blog/backend/export/ExportProperties.java`(`dir`, `retention`, `min-interval`, `stale-running`), `blog-backend/src/main/java/net/java21/blog/backend/post/PostsProperties.java`에 `unlockTtl`·`passwordMaxFailures`·`passwordLockDuration`·`scheduleMaxAhead`(기존 생성자 유지), `blog-backend/src/main/java/net/java21/blog/backend/common/job/JobsProperties.java`에 `exportCleanupCron`, `blog-backend/src/main/resources/application.yml`에 기본값(`blog.jobs.scheduled-publish-delay`·`export-poll-delay`는 `@Scheduled` 자리표시자 기본값으로도 둠), `application-local.yml`에 `blog.export.dir: ./data/exports`, `application-prod.yml`에 `${BLOG_EXPORT_DIR}`(필수). 잘못된 값(음수 기간, 0 이하 한도, 잘못된 시간대·정규식)이면 기동 실패하는 `*PropertiesTest`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: 모든 스토리가 쓰는 엔티티 매핑, 비밀번호 시도 제한, 비회원 쓰기 규칙, 차단 확인, 방문자 키, 블로그 설정, 오류 코드, 공개 경로, 블로그 영구 정리

**⚠️ CRITICAL**: 이 Phase가 끝나기 전에는 어떤 스토리도 시작하지 않는다

### Tests for Foundation ⚠️

> 먼저 쓰고 실패를 확인한다

- [x] T005 [P] `blog-backend/src/test/java/net/java21/blog/backend/blog/repository/BlogFeatureColumnsMappingTest.java`(`@JpaRepositoryTest`): `Post`의 `passwordHash`·`scheduledAt`·`notice`(기본 false), 새 블로그의 `guestbookEnabled` true·`guestWriteEnabled` false·`totalVisitors` 0, `Comment`의 `user` null·`guestName`·`guestPasswordHash`·`guestIp`(암호문으로 저장·복호화로 읽힘)·`secret`, `GuestbookEntry`(부모·비밀·상태), `BlogSidebarItem`·`BlogDailyVisit`·`BlogBlock`(복합 키), `BlogExport`(상태·만료)를 저장 후 다시 읽기. `@Check` 위반이 H2에서도 예외: 비밀번호 해시가 있는데 공개 범위가 PUBLIC인 글, 이름 없는 비회원 댓글·방명록, 회원 ID와 이름이 함께 있는 댓글 (research B2)
- [x] T006 [P] `blog-backend/src/test/java/net/java21/blog/backend/common/security/PasswordAttemptGuardTest.java`: 같은 대상에 방문자 키 또는 IP 하나라도 5회 연속 실패하면 `PASSWORD_ATTEMPTS_EXCEEDED`(429)와 남은 초, 10분 뒤(Caffeine `Ticker`) 풀림, 성공하면 두 키의 실패 수 초기화, 다른 대상은 영향 없음, 대상 종류(`POST`·`COMMENT`·`GUESTBOOK`)별 분리 (research B3, FR-063)
- [x] T007 [P] `blog-backend/src/test/java/net/java21/blog/backend/guest/service/GuestAuthorServiceTest.java`: 블로그 `guestWriteEnabled` false면 401 `UNAUTHENTICATED`; 이름 1~30자(앞뒤 공백·제어 문자 제거 후 빈 값 `REQUIRED`, 31자 `TOO_LONG`), 비밀번호 4~64자(`TOO_SHORT`·`TOO_LONG`); BCrypt 해시와 IP(`ClientInfo.ip`) 반환; 비밀번호 확인이 틀리면 403 `GUEST_PASSWORD_MISMATCH`이고 `PasswordAttemptGuard` 실패 기록, 맞으면 성공 기록; `GuestWriteGuard` 호출 (research B6, FR-066)
- [x] T008 [P] `blog-backend/src/test/java/net/java21/blog/backend/guest/service/RateLimitGuestWriteGuardTest.java`: 같은 IP 댓글 1분 5개까지 통과·6번째 429 `TOO_MANY_REQUESTS`와 `Retry-After`, 방명록은 3개, 1분 뒤 다시 통과(`Ticker`), IP가 다르면 따로 셈, 한도 프로퍼티 반영
- [x] T009 [P] `blog-backend/src/test/java/net/java21/blog/backend/block/repository/BlogBlockRepositoryTest.java`(`@JpaRepositoryTest`): `BlogBlockPolicy.isBlocked(blogId, userId)`가 차단 행이 있을 때만 true, 쿼리 1회(PK), userId null(비회원)은 쿼리 없이 false
- [x] T010 [P] `blog-backend/src/test/java/net/java21/blog/backend/common/web/VisitorKeyResolverTest.java`: 회원이면 `u:{id}`, 아니면 방문자 쿠키 `v:{uuid}`, 쿠키가 없거나 형식이 틀리면 새 UUID와 `Set-Cookie`(001 조회수 API와 같은 속성 `HttpOnly; Secure; SameSite=Lax; Max-Age=1년`); 기존 `PostControllerTest`의 조회수·끝까지 읽음 쿠키 시험이 그대로 통과
- [x] T011 [P] `blog-backend/src/test/java/net/java21/blog/backend/blog/service/BlogServiceTest.java`·`blog/controller/BlogControllerTest.java`에 추가: `PATCH /blogs/{handle}`의 `guestbookEnabled`·`guestWriteEnabled` 변경(주인만), null이면 400 `REQUIRED`, 보내지 않은 필드는 그대로; `GET /blogs/{handle}` 응답에 두 값 (FR-058, FR-066, research B15)
- [x] T012 [P] `blog-backend/src/test/java/net/java21/blog/backend/security/BlogFeaturePathsWebMvcTest.java`(테스트 컨트롤러 + `WebMvcTestSupport`, 003 `PortalPathsWebMvcTest` 방식): 비로그인 허용 GET `/api/v1/blogs/{h}/guestbook`·`/sidebar`·`/archive`·`/notices`; 비로그인 허용 POST `/api/v1/blogs/{h}/visits`·`/api/v1/blogs/{h}/guestbook`·`/api/v1/posts/{id}/unlock`·`/api/v1/posts/{id}/comments`·`/api/v1/comments/{id}/unlock`·`/api/v1/guestbook-entries/{id}/unlock`(모두 Origin 검사는 받음, 403 `ORIGIN_NOT_ALLOWED`); 비로그인 허용 PATCH·DELETE `/api/v1/comments/{id}`·`/api/v1/guestbook-entries/{id}`; 로그인 필요 GET `/api/v1/blogs/{h}/exports`·`/exports/{id}/file`·`/blocks`, `/api/v1/blogs/{h}/manage/sidebar`·`/manage/stats`(401)
- [x] T013 [P] `blog-backend/src/test/java/net/java21/blog/backend/post/repository/TrashPurgeRepositoryTest.java`에 추가: `purgeBlogs`가 그 블로그의 방명록(답글 먼저)·사이드바·일별 방문·차단 행을 지우고 다른 블로그 행은 남김, 쿼리 수가 블로그 수와 무관 (001 FR-159, research B16)
- [x] T014 [P] `blog-backend/src/test/java/net/java21/blog/backend/user/repository/PrivacyPurgeRepositoryTest.java`·`user/job/PrivacyPurgeJobTest.java`에 추가: `blog.guest.ip-retention`(90일) 지난 비회원 댓글·방명록의 `guest_ip_enc`만 NULL, 내용·이름·비밀번호 해시와 회원 글은 그대로, 건수 단위 처리와 로그 (001 FR-134, research B6)
- [x] T015 [P] `blog-front/tests/unit/routes/manage.test.tsx`에 블로그 설정 추가: "방명록 사용"·"비회원 댓글·방명록 허용" 체크가 현재 값으로 채워지고 저장하면 PATCH `{ guestbookEnabled, guestWriteEnabled }`, 비회원 허용 안내 문구(`manage` namespace)

### Implementation for Foundation

- [x] T016 `ErrorCode.java`에 `POST_PASSWORD_MISMATCH`(400), `POST_LOCKED`(403), `PASSWORD_ATTEMPTS_EXCEEDED`(429), `SCHEDULE_NOT_ALLOWED`(422), `POST_NOT_SCHEDULED`(409), `GUEST_PASSWORD_MISMATCH`(403), `GUESTBOOK_DISABLED`(404), `GUESTBOOK_ENTRY_NOT_FOUND`(404), `EXPORT_LIMIT_EXCEEDED`(409), `EXPORT_NOT_FOUND`(404), `CANNOT_BLOCK_SELF`(422), `USER_NOT_FOUND`(404), `BLOCK_NOT_FOUND`(404) 추가, 429 응답에 `Retry-After`를 싣는 `BusinessException`의 헤더 자리(001 `TOO_MANY_REQUESTS` 처리와 같은 방식): `blog-backend/src/main/java/net/java21/blog/backend/common/error/ErrorCode.java`, `common/error/GlobalExceptionHandler.java`
- [x] T017 [P] 글 매핑: `blog-backend/src/main/java/net/java21/blog/backend/post/domain/Post.java`에 `password_hash`·`scheduled_at`·`notice`(접근자, `changeNotice`), 클래스에 `@Check(constraints = "(visibility = 'PROTECTED') = (password_hash IS NOT NULL)")`. "004~005 컬럼은 매핑하지 않는다" 주석을 005 컬럼만 남기게 고침. 공개 범위·상태 값(PROTECTED·SCHEDULED)은 US3에서 더함
- [x] T018 [P] 블로그 매핑: `blog-backend/src/main/java/net/java21/blog/backend/blog/domain/Blog.java`에 `guestbook_enabled`·`guest_write_enabled`·`total_visitors`(읽기 전용, UPDATE는 원자적 쿼리로만), `changeGuestSettings(boolean guestbookEnabled, boolean guestWriteEnabled)`
- [x] T019 [P] 댓글 매핑: `blog-backend/src/main/java/net/java21/blog/backend/comment/domain/Comment.java`의 `user` nullable, `guest_name`·`guest_password_hash`·`guest_ip_enc`(`@Convert(EncryptedStringConverter)`)·`secret`, `@Check`(스키마 `ck_comments_author`와 같은 식), 정적 생성 `Comment.byGuest(post, parent, name, passwordHash, ip, content, secret)`, `isGuest()`
- [x] T020 [P] 방명록 엔티티 `blog-backend/src/main/java/net/java21/blog/backend/guestbook/domain/GuestbookEntry.java`(blog·user·parent LAZY, 비회원 필드는 댓글과 같음, `secret`, `GuestbookStatus.java` ACTIVE·DELETED, `@Check`, `BaseTimeEntity`, `edit`·`markDeleted`·`isOwnedBy`), `blog-backend/src/main/java/net/java21/blog/backend/guestbook/repository/GuestbookEntryRepository.java`
- [x] T021 [P] `blog-backend/src/main/java/net/java21/blog/backend/sidebar/domain/BlogSidebarItem.java`(`BlogSidebarItemId` blog_id·item_type), `sidebar/domain/SidebarItemType.java`(10개 값과 기본 구성·순서 `defaults()`), `sidebar/repository/BlogSidebarItemRepository.java`(`findByBlogIdOrderBySortOrder`, `deleteByBlogId`); `blog-backend/src/main/java/net/java21/blog/backend/stats/domain/BlogDailyVisit.java`(`BlogDailyVisitId` blog_id·visit_date), `stats/repository/BlogVisitRepository.java`(`@Modifying` 네이티브 `upsertVisit(blogId, date)`·`incrementTotal(blogId)`, `findRange(blogId, from, to)`)
- [x] T022 [P] `blog-backend/src/main/java/net/java21/blog/backend/export/domain/BlogExport.java`(`ExportStatus.java` 5개 값, blog·requestedBy LAZY, `markReady(path, size, now, retention)`·`markFailed(code)`·`markExpired()`), `export/repository/BlogExportRepository.java`; `blog-backend/src/main/java/net/java21/blog/backend/block/domain/BlogBlock.java`(`BlogBlockId` blog_id·blocked_user_id, 생성 시각), `block/repository/BlogBlockRepository.java`
- [x] T023 `blog-backend/src/main/java/net/java21/blog/backend/common/security/PasswordAttemptGuard.java`(`check(target, visitorKey, ip)`·`recordFailure`·`recordSuccess`, Caffeine `expireAfterWrite = blog.posts.password-lock-duration`, 테스트용 `Ticker` 생성자), `common/security/AttemptTarget.java`(종류 + id)
- [x] T024 비회원 쓰기 공통: `blog-backend/src/main/java/net/java21/blog/backend/guest/service/GuestAuthorService.java`(`requireGuestAllowed(blog)`, `newGuest(name, password, client, kind)` → `GuestCredentials`, `verify(hash, password, target, visitorKey, ip)`), `guest/dto/GuestCredentials.java`, `guest/service/GuestWriteGuard.java`(인터페이스, 005가 CAPTCHA·회원 속도로 바꿈), `guest/service/RateLimitGuestWriteGuard.java`(Caffeine 고정 창), `guest/dto/GuestWriteKind.java`(COMMENT·GUESTBOOK)
- [x] T025 `blog-backend/src/main/java/net/java21/blog/backend/block/service/BlogBlockPolicy.java`(`isBlocked(blogId, userId)`, `requireNotBlocked(blogId, userId)` → 403 `FORBIDDEN`, 메시지에 차단을 드러내지 않음 "Write not allowed")
- [x] T026 `blog-backend/src/main/java/net/java21/blog/backend/common/web/VisitorKeyResolver.java`로 `PostController`의 방문자 키·쿠키 코드를 옮기고 `blog-backend/src/main/java/net/java21/blog/backend/post/controller/PostController.java`가 사용
- [x] T027 블로그 설정: `blog-backend/src/main/java/net/java21/blog/backend/blog/dto/UpdateBlogRequest.java`에 `guestbookEnabled`·`guestWriteEnabled`(Merge Patch 표시, 003 T079 뒤), `blog/dto/BlogResponse.java`에 두 값, `blog/service/BlogService.java`의 `update`(null이면 400 `REQUIRED`)
- [x] T028 `blog-backend/src/main/java/net/java21/blog/backend/config/SecurityConfig.java`: `AUTHENTICATED_GET`에 `/api/v1/blogs/*/exports/**`, `/api/v1/blogs/*/blocks`; `PUBLIC_POST`에 `/api/v1/blogs/*/visits`, `/api/v1/blogs/*/guestbook`, `/api/v1/posts/*/unlock`, `/api/v1/posts/*/comments`, `/api/v1/comments/*/unlock`, `/api/v1/guestbook-entries/*/unlock`; 새 `PUBLIC_PATCH`·`PUBLIC_DELETE`에 `/api/v1/comments/*`, `/api/v1/guestbook-entries/*`(회원·비회원 판단은 서비스가 함). 공개 GET은 기존 `/api/v1/blogs/**`가 덮음
- [x] T029 `blog-backend/src/main/java/net/java21/blog/backend/post/repository/TrashPurgeRepository.java`의 `purgeBlogs`에 방명록(답글 → 글)·사이드바·일별 방문·차단 행 삭제(백업은 US4 T110에서), `post/job/TrashPurgeJob.java` 주석
- [x] T030 비회원 IP 파기: `blog-backend/src/main/java/net/java21/blog/backend/user/repository/PrivacyPurgeRepository.java`에 `findGuestIpCommentIds(cutoff, limit)`·`findGuestIpGuestbookIds(cutoff, limit)`(`user_id IS NULL AND guest_ip_enc IS NOT NULL AND created_at < cutoff`)·`clearGuestIp(ids)`, `user/job/PrivacyPurgeJob.java`에 단계 추가(건수 로그)
- [x] T031 [P] 새 오류 코드 문구: `blog-front/app/api/errorCodes.ts`에 T016의 13개 코드, `blog-front/app/locales/{ko,en,ja,zh-CN}/errors.json`에 4개 언어 문구(`PASSWORD_ATTEMPTS_EXCEEDED`는 남은 분을 넣는 보간 `{{minutes}}`)
- [x] T032 [P] `blog-front/app/routes/manage/settings.tsx`에 "방명록 사용"·"비회원 댓글·방명록 허용"(003 T081 뒤), 문구 `manage` namespace(4개 언어)

**Checkpoint**: 기반 완료. `./mvnw verify`(MySQL 테스트는 환경 변수가 있을 때), `npm test -- --coverage` 통과, `EntitySchemaValidationTest`가 새 매핑으로 통과

---

## Phase 3: User Story 1 - 방명록 (Priority: P1) 🎯 MVP

**Goal**: 방문자가 블로그 방명록에 글(비밀글, 허용된 블로그에서는 비회원)을 남기고, 블로그 주인이 답글·삭제하며, 방명록을 끄면 메뉴와 화면이 사라진다.

**Independent Test**: 회원 B가 회원 A의 블로그 방명록에 글을 남김 → A가 답글 → 방명록 화면에 두 글이 계층으로 보이는지 확인(quickstart #1~7).

FR: FR-056, FR-057, FR-058, FR-066(방명록) (006 FR-100 방명록 부분)

### Tests for User Story 1 (backend) ⚠️

- [x] T033 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/guestbook/repository/GuestbookQueryRepositoryTest.java`(`@JpaRepositoryTest`): 최상위 글 페이지(ACTIVE와 답글이 남은 DELETED 자리, 최신순, `totalCount`), 작성자 LEFT JOIN(비회원 행 포함, 프로필 이미지 주소), 페이지 글들의 답글을 한 번에(작성순), 글 수와 무관하게 쿼리 2회(+ count 1회); 대시보드용 최근 7일 최상위 글 수와 최근 5건(답글 제외) 각 1회
- [x] T034 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/guestbook/service/GuestbookServiceTest.java`: 목록 — 방명록이 꺼졌으면 주인 외 404 `GUESTBOOK_DISABLED`·주인은 정상, 비밀글 내용은 주인·작성 회원만(그 외 `content` null), 비밀글의 답글도 같음, 삭제 자리는 `deleted: true`·작성자 null(AS2); 쓰기 — 회원 정상, 꺼진 방명록 404, 내용 정규화·1000자, 볼 수 없는 블로그 404 `BLOG_NOT_FOUND`, 비로그인은 `GuestAuthorService`로(허용 안 함 401, 이름·비밀번호·IP 저장, 속도 제한 호출)(AS1, FR-066); 답글 — 주인만(아니면 403), 부모가 답글이면 422 `REPLY_DEPTH_EXCEEDED`, 없는 부모 404 `GUESTBOOK_ENTRY_NOT_FOUND`, 답글 `secret`은 부모를 따름(AS3); 수정 — 작성 회원만, 비회원은 비밀번호(틀리면 403 `GUEST_PASSWORD_MISMATCH`); 삭제 — 작성자 또는 주인, 답글이 있으면 자리만, 마지막 답글을 지우면 자리만 남은 부모도 삭제(AS3); 열기 — 비회원 비밀번호로 내용 반환 (research B7)
- [x] T035 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/guestbook/controller/GuestbookControllerTest.java`: `GET /api/v1/blogs/{h}/guestbook` 비로그인 200 Page(`totalCount`), `POST` 회원 201 + `Location`, 비로그인 비회원 201, 비회원 허용 안 함 401, 429 `Retry-After`, `PATCH`·`DELETE /api/v1/guestbook-entries/{id}`(DELETE 본문 `guestPassword`), `POST .../unlock`, 입력 검증 400 field 오류
- [x] T036 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/manage/service/ManageDashboardServiceTest.java`·`manage/controller/ManageControllerTest.java`에 추가: 대시보드 `newGuestbook7d`·`recentGuestbook`(최근 5건, 비밀글도 주인이므로 내용 포함) (006 FR-100)

### Tests for User Story 1 (front) ⚠️

- [x] T037 [P] [US1] `blog-front/tests/unit/routes/blogGuestbook.test.tsx`: loader가 `/blogs/{h}`·`/blogs/{h}/guestbook?page=`, 꺼진 방명록(404 `GUESTBOOK_DISABLED`)은 404 화면; action `intent=create|reply|update|delete|unlock`이 올바른 API·본문(비회원 `guestName`·`guestPassword`, 삭제 본문), 성공 후 같은 쪽으로 리다이렉트, 필드 오류·`GUEST_PASSWORD_MISMATCH`·`PASSWORD_ATTEMPTS_EXCEEDED`·`TOO_MANY_REQUESTS` 문구; 비로그인 + 비회원 허용이면 이름·비밀번호 칸, 허용 안 하면 로그인 안내 링크(`/login?next=`); meta(`{방명록} - {블로그 제목}`, 2쪽 이상 `noindex`)
- [x] T038 [P] [US1] `blog-front/tests/unit/components/GuestbookEntryItem.test.tsx`와 `blog-front/tests/unit/components/GuestFields.test.tsx`: 비밀글 "비밀글입니다"·자물쇠 표시, 비회원 "비회원" 표시, 삭제 자리 "삭제된 글입니다", 주인에게만 답글 폼, 작성자·주인에게만 삭제, 비회원 글 수정·삭제는 비밀번호 입력, 내용 이스케이프(`<script>` 문자열이 텍스트로), 문구 `guestbook` namespace
- [x] T039 [P] [US1] `blog-front/tests/unit/routes/manageGuestbook.test.tsx`: 주인 목록(비밀글 내용 표시), 답글·삭제 action, 방명록이 꺼져 있으면 안내와 설정 링크; `blog-front/tests/unit/routes/manageDashboard.test.tsx`에 새 방명록 수·최근 5건 추가
- [x] T040 [P] [US1] `blog-front/tests/unit/routes/blogLayout.test.tsx`: 공개 블로그 레이아웃이 블로그 메뉴(홈·공지·태그, `guestbookEnabled`일 때만 방명록)를 그리고 자식 화면을 `Outlet`으로, `:handle/write`·`:handle/manage`는 레이아웃 밖(`routes.ts` 구조 확인), 고정 이름 경로가 `:handle/:postId`보다 앞 (AS4)
- [x] T041 [P] [US1] E2E `blog-front/tests/e2e/blog-us1-guestbook.spec.ts`(`requireBackend`): Independent Test(B 작성 → A 답글 → 계층 표시), 비밀글은 C·비로그인에 "비밀글입니다"·A·B에 내용(AS2), A의 삭제(AS3), 방명록 끄기 후 메뉴 없음·404(AS4); `requireGuestTestSettings`일 때 비회원 작성·같은 비밀번호로 수정·틀린 비밀번호 거부 (quickstart #1~6)

### Implementation for User Story 1 (backend)

- [x] T042 [US1] `blog-backend/src/main/java/net/java21/blog/backend/guestbook/repository/GuestbookQueryRepository.java`·`GuestbookRow.java`(QueryDSL projection, 작성자 LEFT JOIN + 프로필 media LEFT JOIN): `findPage(blogId, pageable)`, `findReplies(parentIds)`, `countRecent(blogId, since)`, `findRecent(blogId, limit)`
- [x] T043 [US1] `blog-backend/src/main/java/net/java21/blog/backend/guestbook/service/GuestbookService.java`(목록·쓰기·답글·수정·삭제·열기, `BlogAccess`·`GuestAuthorService`·`PasswordAttemptGuard` 사용; 차단 확인 자리는 US5 T119), `guestbook/service/GuestbookVisibility.java`(`canRead(entry, parent, viewerId, blogOwnerId)` 한 곳), 내용 정규화는 001 `CommentService`의 규칙을 공용 `common/text/PlainTextNormalizer.java`로 옮겨 함께 씀
- [x] T044 [US1] `blog-backend/src/main/java/net/java21/blog/backend/guestbook/controller/GuestbookController.java`와 DTO `guestbook/dto/`(`GuestbookEntryResponse`, `GuestbookWriteRequest`, `GuestbookUpdateRequest`, `GuestPasswordRequest`), 작성자 DTO는 댓글과 같은 `CommentAuthor`(+ `guest`)를 `common/dto/AuthorResponse.java`로 옮겨 공용
- [x] T045 [US1] `blog-backend/src/main/java/net/java21/blog/backend/manage/service/ManageDashboardService.java`·`manage/dto/DashboardResponse.java`에 `newGuestbook7d`·`recentGuestbook`

### Implementation for User Story 1 (front)

- [x] T046 [US1] 공개 블로그 레이아웃: `blog-front/app/routes/blog/layout.tsx`(loader `GET /blogs/{handle}`, 블로그 메뉴 `blog-front/app/components/blog/BlogNav.tsx`, `Outlet`), `blog-front/app/routes.ts`에서 공개 블로그 화면을 `layout()`으로 감싸고 `:handle/guestbook`을 `:handle/:postId` 앞에 추가(사이드바·방문 기록은 US2 T070), 문구 `blog` namespace
- [x] T047 [US1] 방명록 화면: `blog-front/app/routes/blog-guestbook.tsx`(loader·action·meta), `blog-front/app/components/guestbook/GuestbookList.tsx`·`GuestbookForm.tsx`·`GuestbookEntryItem.tsx`, 댓글과 함께 쓸 `blog-front/app/components/comment/GuestFields.tsx`·`SecretToggle.tsx`·`GuestPasswordPrompt.tsx`, `blog-front/app/blog/guestAuthor.ts`(비회원 폼 표시 판단), 문구 `guestbook` namespace(4개 언어)
- [x] T048 [US1] `blog-front/app/routes/manage/guestbook.tsx`, `blog-front/app/manage/links.ts`·`routes/manage/layout.tsx`에 "방명록" 메뉴, `blog-front/app/routes/manage/dashboard.tsx`에 새 방명록 영역, 문구 `manage` namespace

**Checkpoint**: US1 Independent Test E2E 통과, quickstart #1~7

---

## Phase 4: User Story 2 - 블로그 꾸미기와 탐색 도구 (Priority: P2)

**Goal**: 주인이 공지를 지정하고 사이드바 항목을 켜고 끄고 순서를 바꾸며, 방문자는 공지·월별 보관함·블로그 내 검색·태그 목록으로 글을 찾고, 블로그마다 오늘·어제·전체 방문자 수가 집계된다.

**Independent Test**: 공지 1편 등록, 사이드바에 방문자 수·월별 보관함·태그 목록 켜기 → 방문자 화면에 공지가 목록 위에 고정되고, 선택한 사이드바 항목만 보이며, 보관함에서 특정 달을 누르면 그 달의 글만 나오는지 확인(quickstart #8~16).

FR: FR-059, FR-060, FR-061, FR-067 (006 FR-100 방문자 부분, 006 spec 꾸미기·통계 메뉴)

### Tests for User Story 2 (backend) ⚠️

- [x] T049 [P] [US2] `blog-backend/src/test/java/net/java21/blog/backend/post/repository/PostQueryRepositoryTest.java`에 추가: 공지 목록(목록 노출 가능 + `notice`, 발행 최신순, 페이지), 블로그 홈 목록(조건 없음)은 공지 제외·카테고리·태그 목록은 공지 포함, `year`·`month` 범위 목록(경계: 그 달 시작 포함·다음 달 시작 제외), 각 쿼리 수 그대로 (AS1, AS3, research B8·B12)
- [x] T050 [P] [US2] `blog-backend/src/test/java/net/java21/blog/backend/post/service/PostPublishServiceTest.java`에 `notice` true·false·null(유지)·새 글 기본 false 추가, `blog-backend/src/test/java/net/java21/blog/backend/manage/service/ManagePostServiceTest.java`에 일괄 `NOTICE`·`UNNOTICE`(휴지통 글은 건너뜀) 추가, `post/controller/PostControllerTest.java`에 `GET /api/v1/blogs/{h}/notices`·`/posts?year=&month=`(하나만 있으면 400, 범위 밖 400, `category`와 함께 400) 추가
- [x] T051 [P] [US2] `blog-backend/src/test/java/net/java21/blog/backend/post/service/ArchiveServiceTest.java`와 `post/repository/ArchiveQueryRepositoryTest.java`(`@JpaRepositoryTest`): 블로그의 목록 노출 가능 글 발행 시각만 쿼리 1회, `Asia/Seoul` 연·월로 묶어 최근 달부터, UTC 9월 30일 15:00 글은 10월, 비공개·임시저장 제외, 글이 없으면 `[]`; `ArchiveControllerTest`(비로그인 200, 없는 블로그 404) (research B12)
- [x] T052 [P] [US2] `blog-backend/src/test/java/net/java21/blog/backend/sidebar/repository/SidebarQueryRepositoryTest.java`(`@JpaRepositoryTest`): 최근 글 5(목록 노출 가능), 인기 글 5(`view_count` 내림차순·같으면 최신), 최근 댓글 5(본문 노출 가능 글의 ACTIVE·비밀 아닌 댓글, 내용 50자, 회원 닉네임·비회원 이름), 설정 읽기, 각 쿼리 1회 (FR-060)
- [x] T053 [P] [US2] `blog-backend/src/test/java/net/java21/blog/backend/sidebar/service/SidebarServiceTest.java`: 행이 없으면 기본 구성, 저장은 10개 모두·중복 없음·모르는 값 거부(400 field `items` `INVALID`), 배열 순서가 `sort_order`, 전체 교체(이전 행 삭제); 보기는 켜진 항목만 순서대로 `items`에, 꺼진 데이터 항목은 null이고 저장소를 부르지 않음, TAGS 상위 30·ARCHIVE·VISITORS 연결; `SidebarControllerTest`(공개 GET, 주인 GET·PUT, 남의 블로그 403) (AS2, research B10)
- [x] T054 [P] [US2] `blog-backend/src/test/java/net/java21/blog/backend/stats/service/VisitServiceTest.java`: 같은 블로그·방문자 키·날짜는 한 번만(`Ticker`로 25시간 뒤 다시), 날짜는 `blog.stats.time-zone`(UTC 15:00 = 다음 날), 첫 방문만 `upsertVisit`·`incrementTotal`, 블로그 주인·빈 User-Agent·`Googlebot`·`bingbot`·`facebookexternalhit`는 세지 않음, Playwright `HeadlessChrome`은 셈, 볼 수 없는 블로그 404 (AS4, Edge Cases, research B9)
- [x] T055 [P] [US2] `blog-backend/src/test/java/net/java21/blog/backend/stats/repository/BlogVisitRepositoryTest.java`(`@JpaRepositoryTest`): `upsertVisit` 첫 호출 행 생성(1)·다음 호출 증가, `incrementTotal`, 기간 조회, 각 쿼리 1회
- [x] T056 [P] [US2] `blog-backend/src/test/java/net/java21/blog/backend/stats/BlogVisitConcurrencyTest.java`(`@MySqlRepositoryTest`): 같은 블로그·같은 날 `upsertVisit`+`incrementTotal` 20회 동시 → 행 1, visitors 20, total 20
- [x] T057 [P] [US2] `blog-backend/src/test/java/net/java21/blog/backend/stats/service/VisitorStatsServiceTest.java`와 `stats/controller/StatsControllerTest.java`·`VisitControllerTest.java`: 오늘·어제·전체, 최근 `days`일(기본 30, 1~30 밖은 400) 오름차순·빈 날 0, 조회수 상위 10편(DELETED 제외), 주인만(403); `POST /api/v1/blogs/{h}/visits` 비로그인 200 `null`·방문자 쿠키 발급; 대시보드 `visitors` 추가(`ManageDashboardServiceTest`) (FR-067, 006 FR-100)
- [x] T058 [P] [US2] `blog-backend/src/test/java/net/java21/blog/backend/search/repository/PostSearchRepositoryTest.java`(`@MySqlRepositoryTest`)에 `blog` 조건 추가(그 블로그 글만, 노출 조건 그대로), `search/service/PostSearchServiceTest.java`·`search/controller/SearchControllerTest.java`에 `blog` 매개변수(볼 수 없는 블로그 404 `BLOG_NOT_FOUND`) (FR-061)

### Tests for User Story 2 (front) ⚠️

- [x] T059 [P] [US2] `blog-front/tests/unit/routes/blogLayout.test.tsx`에 추가: loader가 `/blogs/{h}/sidebar`와 `POST /blogs/{h}/visits`를 병렬로(방문 실패는 무시), 켜진 항목만 순서대로(`components/blog/Sidebar`), `shouldRevalidate`가 `handle`이 바뀔 때·action 뒤에만 true; 같은 요청의 `GET /blogs/{h}` 중복 호출이 한 번만 나감(`BackendSession.memo`)
- [x] T060 [P] [US2] `blog-front/tests/unit/components/Sidebar.test.tsx`(항목 10개 각각: 프로필·카테고리 트리·최근 글·최근 댓글(비회원 표시)·인기 글·태그·보관함("2026년 10월" 4개 언어 형식)·방문자(오늘·어제·전체)·검색 폼(`/:handle/search`, JS 없이 GET)·피드 링크(RSS·Atom)), `blog-front/tests/unit/blog/tagWeight.test.ts`(글 수 → 1~5단계 로그 눈금, 모두 같으면 3), `blog-front/tests/unit/blog/archive.test.ts`(경로 `/:handle/archive/2026/10`, 연·월 검증)
- [x] T061 [P] [US2] `blog-front/tests/unit/routes/blogNotice.test.tsx`, `blogArchive.test.tsx`(숫자가 아니거나 범위 밖이면 404, 제목 형식), `blogSearch.test.tsx`(`/search/posts?blog=&q=`, 2자 미만·100자 초과 문구, 보호 글 제목만, `noindex`), `blogTags.test.tsx`(이름순·단계별 크기 클래스·링크), `blogHome.test.tsx`에 공지 영역(최대 5, "공지 더 보기", 없으면 숨김) 추가 (AS1, AS3, FR-061)
- [x] T062 [P] [US2] `blog-front/tests/unit/routes/manageDesign.test.tsx`(사이드바 켜기·끄기·위로·아래로가 JS 없이 폼으로, 저장 PUT 본문 10개 순서, 공지 목록과 "공지 해제" bulk), `manageStats.test.tsx`(오늘·어제·전체, 30일 표·막대, 시간대 안내, 조회수 상위), `manageDashboard.test.tsx`에 방문자, `PublishSettingsDialog.test.tsx`에 "공지로 등록", `managePosts.test.tsx`에 일괄 "공지로"·"공지 해제"
- [x] T063 [P] [US2] E2E `blog-front/tests/e2e/blog-us2-design.spec.ts`(`requireBackend`): Independent Test(공지 1편 → 홈 위에만, 사이드바 VISITORS·ARCHIVE·TAGS 켜고 CATEGORIES 끔 → 홈·글 상세 사이드바 반영, 보관함 달 클릭 → 그 달 글만), 방문자: 서로 다른 두 컨텍스트로 블로그 3번씩 → 주인 통계 오늘 2(AS4), 블로그 검색·태그 목록 화면 (quickstart #8~16)

### Implementation for User Story 2 (backend)

- [x] T064 [US2] 공지: `blog-backend/src/main/java/net/java21/blog/backend/post/dto/PublishSettingsRequest.java`에 `notice`, `post/service/PostPublishService.java`(null이면 유지), `post/dto/PostSummaryResponse.java`·`PostDetailResponse.java`에 `notice`, `blog-backend/src/main/java/net/java21/blog/backend/manage/dto/BulkAction.java`에 `NOTICE`·`UNNOTICE`와 `manage/service/ManagePostService.java` 처리
- [x] T065 [US2] 목록 조건: `blog-backend/src/main/java/net/java21/blog/backend/post/dto/PostListFilter.java`에 `year`·`month`(검증), `post/repository/PostQueryRepository.java`에 공지 목록·홈 목록 공지 제외·발행 시각 범위, `post/controller/PostController.java`에 `GET /api/v1/blogs/{handle}/notices`와 `year`·`month` 매개변수, 월 경계 계산 `blog-backend/src/main/java/net/java21/blog/backend/stats/BlogCalendar.java`(`StatsProperties.timeZone`, 월 → UTC 범위, 시각 → 연·월·날짜)
- [x] T066 [US2] 보관함: `blog-backend/src/main/java/net/java21/blog/backend/post/repository/ArchiveQueryRepository.java`(발행 시각만), `post/service/ArchiveService.java`(`BlogCalendar`로 묶음), `post/controller/ArchiveController.java`(`GET /api/v1/blogs/{handle}/archive`), DTO `post/dto/ArchiveMonthResponse.java`
- [x] T067 [US2] 사이드바: `blog-backend/src/main/java/net/java21/blog/backend/sidebar/repository/SidebarQueryRepository.java`·행 DTO, `sidebar/service/SidebarService.java`(설정 읽기·전체 교체·보기 조립, `TagQueryRepository`·`ArchiveService`·`VisitorStatsService` 사용), `sidebar/controller/SidebarController.java`(`GET /blogs/{h}/sidebar`, `GET /blogs/{h}/manage/sidebar`, `PUT /blogs/{h}/sidebar`), DTO `sidebar/dto/`
- [x] T068 [US2] 방문자: `blog-backend/src/main/java/net/java21/blog/backend/stats/service/VisitService.java`(Caffeine 중복 제거·봇 판정·주인 제외, `@Transactional` upsert + total), `stats/controller/VisitController.java`(`POST /api/v1/blogs/{handle}/visits`, `VisitorKeyResolver`), `stats/service/VisitorStatsService.java`(오늘·어제·전체, 기간, 조회수 상위), `stats/controller/StatsController.java`(`GET /api/v1/blogs/{handle}/manage/stats`), 대시보드 `visitors`(`ManageDashboardService`·`DashboardResponse`)
- [x] T069 [US2] 블로그 내 검색: `blog-backend/src/main/java/net/java21/blog/backend/search/controller/SearchController.java`에 `blog`, `search/service/PostSearchService.java`(`BlogAccess.requireVisibleBlog`), `search/repository/PostSearchRepository.java`에 `blog_id` 조건(세 검색 조건 모두)

### Implementation for User Story 2 (front)

- [x] T070 [US2] `blog-front/app/routes/blog/layout.tsx`에 사이드바·방문 기록(`POST /blogs/{h}/visits`, 실패 무시)·`shouldRevalidate`, `blog-front/app/components/blog/Sidebar.tsx`와 `components/blog/sidebar/*.tsx`(항목별), 모바일에서 본문 아래 배치(CSS), `blog-front/app/api/client.server.ts`의 메모 대상에 `/blogs/{handle}`, 문구 `blog` namespace(4개 언어)
- [x] T071 [US2] 새 화면: `blog-front/app/routes/blog-notice.tsx`, `blog-archive.tsx`, `blog-search.tsx`, `blog-tags.tsx`와 `blog-front/app/routes.ts`(레이아웃 안, `:handle/:postId` 앞), `blog-front/app/blog/tagWeight.ts`·`archive.ts`, `blog-front/app/components/blog/NoticeList.tsx`·`TagCloud.tsx`·`ArchiveList.tsx`, `blog-front/app/routes/blog-home.tsx`에 공지 영역(loader에 `/blogs/{h}/notices?size=5`)
- [x] T072 [US2] `blog-front/app/routes/manage/design.tsx`(`components/manage/SidebarEditor.tsx`, 공지 목록·해제), `blog-front/app/routes/manage/stats.tsx`(`components/manage/VisitorChart.tsx` 표 + CSS 막대, 라이브러리 없음), 관리 메뉴 "꾸미기"·"통계", 대시보드 방문자 영역(001이 숨긴 자리), `blog-front/app/components/post/PublishSettingsDialog.tsx`에 "공지로 등록"(003 T080 뒤), `blog-front/app/routes/manage/posts.tsx`에 일괄 "공지로"·"공지 해제", 문구 `manage`·`post` namespace

**Checkpoint**: US2 Independent Test E2E 통과, quickstart #8~16

---

## Phase 5: User Story 3 - 글 공개 옵션 확장 (Priority: P3)

**Goal**: 글쓴이가 보호 글(비밀번호)과 예약 발행을 쓰고, 댓글 작성자는 비밀 댓글을, 허용된 블로그에서는 비회원도 이름·비밀번호로 댓글을 단다. 보호 글 본문·예약 전 글·비밀 댓글 내용은 권한 밖에 나오지 않는다.

**Independent Test**: 보호 글 작성 → 다른 계정에서 비밀번호 없이 본문이 안 보이고 비밀번호 입력 후 보이는지 확인. 10분 뒤로 예약한 글이 그 전엔 안 보이고 그 후엔 목록에 나오는지 확인(quickstart #17~30. E2E는 예약을 20초 뒤로 줄여 확인).

FR: FR-062, FR-063, FR-064, FR-065, FR-066(댓글) (SC-010, 001 SC-004)

### Tests for User Story 3 (backend) ⚠️

- [x] T073 [P] [US3] `blog-backend/src/test/java/net/java21/blog/backend/post/repository/PostExposureRepositoryTest.java`에 추가: PUBLISHED·PROTECTED는 `listable()`이지만 `bodyVisible()`이 아님, SCHEDULED(모든 공개 범위)는 둘 다 아님, `isDetailVisibleTo`는 보호 글을 주인 외에도 true(잠금 화면), SCHEDULED는 주인만, 쿼리와 자바 판단이 같은 결과 (001 노출 매트릭스 PROTECTED·SCHEDULED 행)
- [x] T074 [P] [US3] `blog-backend/src/test/java/net/java21/blog/backend/post/dto/PostSummaryResponseTest.java`와 `PostQueryRepositoryTest`·`tag/repository/TagQueryRepositoryTest.java`에 추가: 블로그 홈·카테고리·블로그 태그·서비스 태그·공지·보관함 목록에서 보호 글은 제목만(`summary`·`thumbnailUrl` null), 관리 목록은 가리지 않음 (AS2, research B1)
- [x] T075 [P] [US3] `PostPublishServiceTest`에 추가: PROTECTED는 새로 지정할 때 `password` 필수(400 `REQUIRED`), 4~64자, BCrypt 저장, 이미 보호 글이면 생략 시 해시 유지, 다른 공개 범위로 바꾸면 해시 NULL; `scheduledAt` 미래 → SCHEDULED·`scheduled_at` 설정·`published_at` 그대로·사본 삭제·이미지 참조 동기화·`markFirstPublished` 호출 안 함, 지금 이하 → 즉시 발행, PUBLISHED에 미래 시각 422 `SCHEDULE_NOT_ALLOWED`, 365일 초과 400, SCHEDULED 글을 즉시 발행하면 `scheduled_at` NULL; `ManagePostServiceTest`에 일괄 공개 범위 변경으로 PROTECTED 지정은 400(비밀번호 없음), PROTECTED에서 다른 값으로 바꾸면 해시 NULL (FR-062, FR-064, Edge Cases)
- [x] T076 [P] [US3] `blog-backend/src/test/java/net/java21/blog/backend/post/service/PostUnlockServiceTest.java`·`PostUnlockCookiesTest.java`: 맞는 비밀번호 → 쿠키 토큰(`typ=post-unlock`, `pid`, `pwf`, 30분)과 본문 포함 상세, 틀리면 400 `POST_PASSWORD_MISMATCH`와 실패 기록, 5회 뒤 429, 보호 글이 아니거나 목록 노출 가능이 아니면 404; 쿠키 검증은 만료·다른 글·비밀번호 변경(지문 다름)·변조 서명이면 무효 (FR-062, FR-063, research B4)
- [x] T077 [P] [US3] `blog-backend/src/test/java/net/java21/blog/backend/post/service/PostServiceTest.java`·`post/controller/PostControllerTest.java`에 추가: 보호 글 상세를 주인은 본문, 쿠키 있는 방문자는 본문, 없으면 `locked: true`와 본문·요약·이미지·카테고리·주제 null·태그 `[]`; `scheduledAt`은 주인에게만; `POST /api/v1/posts/{id}/unlock`의 `Set-Cookie` 속성(`HttpOnly`, `Secure`, `SameSite=Lax`, `Path=/`, `Max-Age=1800`)과 `Cache-Control: no-store`; 잠긴 글의 조회수·끝까지 읽음은 200이지만 세지 않음(`ViewCountServiceTest`·`ReadCompleteServiceTest`) (AS1)
- [x] T078 [P] [US3] `blog-backend/src/test/java/net/java21/blog/backend/post/repository/ScheduledPublishRepositoryTest.java`(`@JpaRepositoryTest`): 예약 시각이 지난 SCHEDULED id를 시각 순·`limit`개, 조건부 UPDATE가 1행(발행, `published_at` = now, `scheduled_at` NULL) 또는 0행(이미 발행·예약 취소·미래로 바뀜), `first_published_at`은 NULL일 때만 채움, 각 쿼리 1회 (research B5)
- [x] T079 [P] [US3] `blog-backend/src/test/java/net/java21/blog/backend/post/job/ScheduledPublishJobTest.java`: 묶음 단위 처리·처리 건수 로그, 0행이면 블로그를 건드리지 않음; `PostServiceTest`에 `unschedule`(SCHEDULED → DRAFT·`scheduled_at` NULL, 아니면 409 `POST_NOT_SCHEDULED`, 주인만), 휴지통 복구가 SCHEDULED로; `ManagePostServiceTest`·`ManagePostQueryRepositoryTest`에 `status=SCHEDULED`·`visibility=PROTECTED` 필터와 `scheduledAt` (AS3, Edge Cases)
- [x] T080 [P] [US3] `blog-backend/src/test/java/net/java21/blog/backend/post/ScheduledPublishIntegrationTest.java`(`@SpringBootTest`, H2, `MutableClock`): 예약 글이 상세(주인 외 404)·블로그 목록·RSS·사이트맵·포털·태그 목록에 없음 → 시각을 넘기고 작업 실행 → 모든 곳에 나오고 `publishedAt`이 작업 실행 시각 (AS3, SC-010)
- [x] T081 [P] [US3] `blog-backend/src/test/java/net/java21/blog/backend/comment/service/CommentServiceTest.java`에 추가: 비밀 댓글 내용은 글 주인·작성 회원·(답글이면) 부모 작성 회원만, 비밀 부모 아래 답글도 비밀, 비밀 댓글의 비회원 작성자는 목록에서 `content` null; 잠긴 보호 글의 목록·쓰기 403 `POST_LOCKED`; 비회원 쓰기(허용 안 함 401, 이름·비밀번호 검증, IP 암호화 저장, 속도 제한, `CommentCreatedEvent.authorId` null); 비회원 수정·삭제는 비밀번호(틀리면 403, 5회 뒤 429), 글 주인은 비밀번호 없이 삭제, 회원 댓글에 비로그인 요청은 401; 비회원 비밀 댓글 열기 (AS4, AS5, AS6, research B6)
- [x] T082 [P] [US3] `blog-backend/src/test/java/net/java21/blog/backend/comment/repository/CommentQueryRepositoryTest.java`·`manage/service/ManageCommentServiceTest.java`에 추가: 작성자 LEFT JOIN으로 비회원 댓글 포함, 쿼리 수 그대로(2회), 관리 목록은 비밀 내용·비회원 표시
- [x] T083 [P] [US3] `blog-backend/src/test/java/net/java21/blog/backend/comment/controller/CommentControllerTest.java`에 추가: 비로그인 `POST /api/v1/posts/{id}/comments` 201(비회원 허용 블로그)·401(허용 안 함), `PATCH`·`DELETE /api/v1/comments/{id}`의 `guestPassword` 본문, `POST /api/v1/comments/{id}/unlock`, `secret` 필드
- [x] T084 [P] [US3] `blog-backend/src/test/java/net/java21/blog/backend/notification/service/NotificationEventListenerTest.java`에 추가: 비회원 댓글 → 글 주인에게 `NEW_COMMENT`(`actor` null, `params.guestName`), 주인이 쓴 댓글은 알림 없음 그대로

### Tests for User Story 3 (front) ⚠️

- [x] T085 [P] [US3] `blog-front/tests/unit/components/PublishSettingsDialog.test.tsx`에 추가: 공개 범위 "보호"를 고르면 비밀번호 칸(새로 지정하면 필수, 이미 보호 글이면 "비워 두면 유지"), "예약 발행" 날짜·시각(발행된 글에는 숨김, 예약 글은 채워짐), 보낼 `scheduledAt`이 회원 시간대 → UTC; `blog-front/tests/unit/i18n/zonedDateTime.test.ts`(Asia/Seoul·America/New_York 일광 절약 경계, `datetime-local` 왕복); `blog-front/tests/unit/routes/write.test.tsx`에 "예약 취소" action
- [x] T086 [P] [US3] `blog-front/tests/unit/routes/postDetail.test.tsx`에 추가: `locked`면 제목·작성자·발행일과 비밀번호 폼만(본문·댓글·좋아요·조회수 호출 없음), `intent=unlock` 성공 시 같은 주소로 리다이렉트(쿠키는 backend Set-Cookie 전달), `POST_PASSWORD_MISMATCH`·`PASSWORD_ATTEMPTS_EXCEEDED`(남은 분) 문구, meta는 제목만·`noindex`·description·og:image 없음
- [x] T087 [P] [US3] `blog-front/tests/unit/components/CommentSection.test.tsx`·`CommentForm.test.tsx`에 추가: "비밀 댓글" 체크, 볼 수 없는 비밀 댓글은 "비밀 댓글입니다", "비회원" 표시, 비로그인 + 비회원 허용이면 이름·비밀번호 칸, 허용 안 하면 로그인 안내(`/login?next=`), 비회원 댓글 수정·삭제의 비밀번호 입력, 비밀 비회원 댓글 수정 전 `intent=unlockComment`; `blog-front/tests/unit/components/comment/actions.test.ts`에 새 intent
- [x] T088 [P] [US3] `blog-front/tests/unit/routes/managePosts.test.tsx`에 추가: 상태 필터 "예약"·공개 범위 필터 "보호", 예약 시각 표시(회원 시간대), "예약 취소"
- [x] T089 [P] [US3] E2E `blog-front/tests/e2e/blog-us3-post-options.spec.ts`(`requireBackend`): 보호 글 Independent Test(다른 계정 잠금 → 비밀번호 → 본문, 목록·RSS 제목만), 틀린 비밀번호 5번 뒤 잠김 안내, 예약 발행(20초 뒤로 예약 → 바로 404·목록 없음 → `waitForPublic` 90초 안에 목록·피드 등장), 비밀 댓글(AS4); `requireGuestTestSettings`일 때 비회원 댓글 작성·같은 비밀번호로 수정·삭제(AS5), 허용을 끄면 로그인 안내(AS6) (quickstart #17~27)

### Implementation for User Story 3 (backend)

- [x] T090 [US3] 값 추가와 목록 가림: `blog-backend/src/main/java/net/java21/blog/backend/post/domain/PostVisibility.java`에 `PROTECTED`, `post/domain/PostStatus.java`에 `SCHEDULED`, `post/repository/PostExposure.java`의 `LISTABLE_VISIBILITIES`에 `PROTECTED`(주석의 004 자리 정리), `post/dto/PostSummaryResponse.java`에 `forReader`(보호 글 `summary`·`thumbnailUrl` null)와 `scheduledAt`, `post/service/PostService.java`·`tag/service/TagService.java`의 독자 목록이 `forReader` 사용
- [x] T091 [US3] 발행 설정: `blog-backend/src/main/java/net/java21/blog/backend/post/dto/PublishSettingsRequest.java`에 `password`(4~64)·`scheduledAt`, `post/domain/Post.java`에 `protect(hash)`·`unprotect()`·`schedule(..., scheduledAt)`·`unschedule()`(공개 범위 변경 때 해시 정리), `post/service/PostPublishService.java`(검증을 글 변경 전에, 예약 분기, BCrypt `PasswordEncoder`), `manage/service/ManagePostService.java`의 일괄 공개 범위 규칙과 `manage/repository/ManagePostQueryRepository.java` 필터
- [x] T092 [US3] 보호 글 열기: `blog-backend/src/main/java/net/java21/blog/backend/post/service/PostUnlockCookies.java`(001 `JwtProvider`로 서명·검증, `pwf`), `post/service/PostUnlockService.java`(`PasswordAttemptGuard`), `post/controller/PostController.java`에 `POST /api/v1/posts/{id}/unlock`, `post/service/PostService.java`의 상세가 요청 쿠키로 잠금 판단, `post/dto/PostDetailResponse.java`에 `locked`·`scheduledAt`, `post/service/ViewCountService.java`·`ReadCompleteService.java`가 잠긴 글을 세지 않음, `comment/service/CommentService.java`의 잠긴 글 403 `POST_LOCKED`
- [x] T093 [US3] 예약 발행 작업: `blog-backend/src/main/java/net/java21/blog/backend/post/repository/ScheduledPublishRepository.java`(대상 id, 조건부 UPDATE, 블로그 첫 발행 조건부 UPDATE), `post/job/ScheduledPublishJob.java`(`@Scheduled(fixedDelayString = "${blog.jobs.scheduled-publish-delay:30s}")`, 묶음마다 트랜잭션, 처리 건수 로그, 005가 트랙백 보내기를 붙일 자리 주석), `post/service/PostService.java`에 `unschedule`, `post/controller/PostController.java`에 `POST /api/v1/posts/{id}/unschedule`
- [x] T094 [US3] 비밀·비회원 댓글: `blog-backend/src/main/java/net/java21/blog/backend/comment/service/CommentVisibility.java`(`canRead` 한 곳), `comment/service/CommentService.java`(비로그인 쓰기 → `GuestAuthorService`, 수정·삭제·열기의 비밀번호, 비밀 거르기), `comment/dto/CreateCommentRequest.java`·`UpdateCommentRequest.java`에 `secret`·`guestName`·`guestPassword`, `comment/dto/CommentResponse.java`에 `secret`·`author.guest`, `comment/controller/CommentController.java`(`@CurrentUser(required = false)`, DELETE 본문, `POST /comments/{id}/unlock`), `comment/repository/CommentQueryRepository.java`의 작성자 LEFT JOIN, `comment/event/CommentCreatedEvent.java`의 `authorId` nullable·`guestName`, `notification/service/NotificationEventListener.java`, `manage/service/ManageCommentService.java`·`manage/dto/ManageCommentResponse.java`

### Implementation for User Story 3 (front)

- [x] T095 [US3] `blog-front/app/components/post/PublishSettingsDialog.tsx`에 보호(`components/post/ProtectedPasswordField.tsx`)·예약(`components/post/ScheduleField.tsx`, `<input type="datetime-local">`), `blog-front/app/i18n/zonedDateTime.ts`, `blog-front/app/routes/write.tsx`의 예약 취소 action과 예약 시각 불러오기, 문구 `post` namespace(4개 언어)
- [x] T096 [US3] `blog-front/app/routes/post-detail.tsx`에 잠금 화면(`components/post/LockedPost.tsx`, `intent=unlock` action), 잠겼을 때 조회수·끝까지 읽음·댓글 호출 생략, `app/seo/meta.ts`의 보호 글 meta(003 T081 뒤)
- [x] T097 [US3] `blog-front/app/components/comment/CommentSection.tsx`·`CommentForm.tsx`·`actions.ts`·`actions.server.ts`에 비밀·비회원(US1의 `GuestFields`·`SecretToggle`·`GuestPasswordPrompt` 재사용), `intent=unlockComment`, 문구 `comment` namespace
- [x] T098 [US3] `blog-front/app/routes/manage/posts.tsx`에 예약·보호 필터, 예약 시각, "예약 취소"(`POST /posts/{id}/unschedule`), 문구 `manage` namespace

**Checkpoint**: US3 Independent Test E2E 통과, quickstart #17~30

---

## Phase 6: User Story 4 - 블로그 백업 (Priority: P4)

**Goal**: 블로그 주인이 블로그 전체(모든 글의 Markdown 원문과 정보, 원본 이미지, 카테고리 구조)를 zip으로 하루 1회 만들고, 준비되면 알림을 받아 7일 동안 내려받는다.

**Independent Test (plan이 FR-145에서 만듦)**: 임시저장·비공개·보호·예약 글과 이미지가 있는 블로그에서 백업을 요청 → 1분 안에 준비 알림 → 내려받은 zip에 글·front matter·이미지·카테고리가 들어 있고, 같은 날 다시 요청하면 거부되는지 확인(quickstart #31~35).

FR: FR-145 (002 FR-033 `BACKUP_READY`, 006 spec 백업 메뉴)

### Tests for User Story 4 (backend) ⚠️

- [x] T099 [P] [US4] `blog-backend/src/test/java/net/java21/blog/backend/export/repository/BlogExportRepositoryTest.java`(`@JpaRepositoryTest`): 최근 24시간 FAILED가 아닌 행 존재 여부, 최근 10건, 가장 오래된 PENDING, PENDING → RUNNING 조건부 UPDATE(1행·0행), 만료된 READY 목록, 오래된 RUNNING 목록, 각 쿼리 1회
- [x] T100 [P] [US4] `blog-backend/src/test/java/net/java21/blog/backend/export/service/BlogExportServiceTest.java`: 주인만(403), PENDING·RUNNING·READY·EXPIRED가 24시간 안에 있으면 409 `EXPORT_LIMIT_EXCEEDED`, FAILED만 있으면 허용, 목록 10건, 파일은 READY·만료 전·이 블로그의 백업일 때만(아니면 404 `EXPORT_NOT_FOUND`)
- [x] T101 [P] [US4] `blog-backend/src/test/java/net/java21/blog/backend/export/service/BlogExportWriterTest.java`(`@JpaRepositoryTest` + 임시 디렉터리): zip 항목 `blog.json`(카테고리 트리·형식 버전), 휴지통을 뺀 모든 글의 `posts/{id}.md`(front matter 필드, 제목의 `:`·따옴표·줄바꿈 YAML 이스케이프, 발행 전 글은 사본 내용, 보호 글 비밀번호 없음), 발행된 글의 사본 `posts/{id}.draft.md`, 원본 이미지 `images/{key}.{ext}`(썸네일 제외)와 `media.json`, 파일이 없는 이미지는 건너뛰고 경고 로그; 글 100편 묶음마다 쿼리 3회(글·태그·사본) (FR-145, research B14)
- [x] T102 [P] [US4] `blog-backend/src/test/java/net/java21/blog/backend/export/job/BlogExportJobTest.java`·`BlogExportCleanupJobTest.java`: PENDING 하나를 RUNNING으로 가져와 READY(`completed_at`, `expires_at` = +7일, 파일 크기)와 `BACKUP_READY` 알림 이벤트, 쓰기 실패면 FAILED·`error_code`·부분 파일 삭제, 기동 때 1시간 넘은 RUNNING → FAILED `INTERRUPTED`; 만료된 READY는 파일 삭제 후 EXPIRED, 파일이 이미 없어도 EXPIRED
- [x] T103 [P] [US4] `blog-backend/src/test/java/net/java21/blog/backend/export/controller/BlogExportControllerTest.java`: `POST` 202 + `Location`, 409, `GET` 목록, 파일 응답 `Content-Type: application/zip`·`Content-Disposition` 파일 이름 `{handle}-backup-{yyyyMMdd}.zip`·`Cache-Control: no-store`, 404는 공통 틀 JSON, 응답에 `filePath` 없음
- [x] T104 [P] [US4] `blog-backend/src/test/java/net/java21/blog/backend/notification/service/NotificationServiceTest.java`·`notification/controller/NotificationControllerTest.java`에 `BACKUP_READY`(target `BLOG_EXPORT`, params `blogTitle`·`handle`·`expiresAt`); `TrashPurgeRepositoryTest`에 블로그 정리 때 백업 행과 파일 삭제 추가

### Tests for User Story 4 (front) ⚠️

- [x] T105 [P] [US4] `blog-front/tests/unit/routes/manageBackup.test.tsx`: 목록 상태별 표시(대기·만드는 중·완료·실패·만료, 크기·만료 시각), READY만 내려받기 링크(`/api/v1/blogs/{h}/exports/{id}/file`), "백업 만들기" action과 409 문구("하루에 한 번"), PENDING·RUNNING이 있으면 다시 읽기 예약; `blog-front/tests/unit/components/NotificationItem.test.tsx`에 `BACKUP_READY` 문구·링크 `/{handle}/manage/backup`; `blog-front/tests/unit/server/backendProxy.test.ts`에 zip 응답을 버퍼링하지 않고 넘김 확인
- [x] T106 [P] [US4] E2E `blog-front/tests/e2e/blog-us4-backup.spec.ts`(`requireBackend`): 글·이미지가 있는 블로그에서 백업 요청 → `waitForPublic` 90초 안에 완료 → 알림 목록에 문구 → 내려받기(파일 크기 > 0, 앞 2바이트 `PK`) → 다시 요청하면 하루 한 번 안내 (quickstart #31~33)

### Implementation for User Story 4 (backend)

- [x] T107 [US4] `blog-backend/src/main/java/net/java21/blog/backend/export/storage/ExportStorage.java`(`blog.export.dir`, `{yyyy}/{MM}/{UUID}.zip`, 경로가 디렉터리 밖으로 나가지 않게 정규화 검사, 삭제), `export/service/BlogExportWriter.java`(`ZipOutputStream`, 001 `MediaStorage`로 원본 읽기, YAML front matter 직접 작성·이스케이프), `export/repository/ExportPostQueryRepository.java`(id 순 묶음, 태그·사본 IN)
- [x] T108 [US4] `blog-backend/src/main/java/net/java21/blog/backend/export/service/BlogExportService.java`(요청·목록·파일 열기), `export/controller/BlogExportController.java`(`StreamingResponseBody`), DTO `export/dto/BlogExportResponse.java`
- [x] T109 [US4] `blog-backend/src/main/java/net/java21/blog/backend/export/job/BlogExportJob.java`(`@Scheduled(fixedDelayString = "${blog.jobs.export-poll-delay:30s}")`, 하나씩), `export/job/BlogExportCleanupJob.java`(`blog.jobs.export-cleanup-cron`), `export/job/StaleExportRecovery.java`(`ApplicationRunner`), `export/event/BlogExportReadyEvent.java`; `blog-backend/src/main/java/net/java21/blog/backend/notification/domain/NotificationType.java`에 `BACKUP_READY`, `NotificationTargetType.java`에 `BLOG_EXPORT`, `notification/service/NotificationEventListener.java`에 처리
- [x] T110 [US4] `blog-backend/src/main/java/net/java21/blog/backend/post/repository/TrashPurgeRepository.java`·`post/job/TrashPurgeJob.java`에 블로그 정리 때 백업 파일 삭제(`ExportStorage`, 커밋 뒤) 후 행 삭제

### Implementation for User Story 4 (front)

- [x] T111 [US4] `blog-front/app/routes/manage/backup.tsx`(목록·요청·내려받기 링크·`useRevalidator` 30초), 관리 메뉴 "백업", `blog-front/app/components/notification/NotificationItem.tsx`·`components/notification/links.ts`에 `BACKUP_READY`, 문구 `manage`·`notification` namespace(4개 언어), `blog-front/server/middleware/backend-proxy.ts`가 바이너리를 스트림으로 넘기는지 확인(필요하면 수정)

**Checkpoint**: US4 Independent Test E2E 통과, quickstart #31~35

---

## Phase 7: User Story 5 - 회원 차단 (Priority: P5)

**Goal**: 블로그 주인이 특정 회원을 차단하면 그 회원은 그 블로그에 댓글·방명록을 쓰거나 구독할 수 없고(기존 구독 해제), 차단 사실은 알리지 않으며, 주인은 차단 목록에서 해제한다.

**Independent Test (plan이 FR-146에서 만듦)**: B가 A의 블로그를 구독한 뒤 A가 B를 차단 → B의 구독이 사라지고, B가 A의 블로그에 댓글·방명록·구독을 시도하면 일반 거부 문구가 나오며, A가 해제하면 다시 쓸 수 있는지 확인(quickstart #36~39).

FR: FR-146 (002 FR-031 구독, 006 spec 차단 목록 메뉴)

### Tests for User Story 5 (backend) ⚠️

- [x] T112 [P] [US5] `blog-backend/src/test/java/net/java21/blog/backend/block/service/BlogBlockServiceTest.java`: 차단은 주인만(403), 자기 자신 422 `CANNOT_BLOCK_SELF`, 없는 회원 404 `USER_NOT_FOUND`, 이미 차단이면 그대로(멱등), 같은 트랜잭션에서 구독 행 삭제와 `subscriber_count` 감소(구독이 없으면 그대로), 알림을 만들지 않음; 해제는 없으면 404 `BLOCK_NOT_FOUND`
- [x] T113 [P] [US5] `blog-backend/src/test/java/net/java21/blog/backend/block/repository/BlockQueryRepositoryTest.java`(`@JpaRepositoryTest`): 차단 목록 페이지(회원 닉네임·프로필 이미지 주소, 차단 최신순), 쿼리 1회 + count 1회
- [x] T114 [P] [US5] 확인 지점: `CommentServiceTest`(차단 회원의 그 블로그 글 댓글 403 `FORBIDDEN`, 다른 블로그는 허용), `GuestbookServiceTest`(차단 회원 방명록 403), `blog-backend/src/test/java/net/java21/blog/backend/subscription/service/SubscriptionServiceTest.java`(차단 회원 구독 403), 응답 메시지에 "block"이 드러나지 않음
- [x] T115 [P] [US5] `blog-backend/src/test/java/net/java21/blog/backend/block/controller/BlogBlockControllerTest.java`: `GET` Page, `PUT /api/v1/blogs/{h}/blocks/{userId}` 200, `DELETE` 200·404, 비로그인 401, 남의 블로그 403, `no-store`

### Tests for User Story 5 (front) ⚠️

- [x] T116 [P] [US5] `blog-front/tests/unit/routes/manageBlocks.test.tsx`(목록·해제 action·빈 목록 문구), `blog-front/tests/unit/components/BlockButton.test.tsx`(회원 작성자에만, 확인 후 `PUT`), `manageComments.test.tsx`·`manageGuestbook.test.tsx`에 "차단" 추가, 차단된 회원이 댓글·방명록·구독 때 받는 403의 일반 거부 문구
- [x] T117 [P] [US5] E2E `blog-front/tests/e2e/blog-us5-block.spec.ts`(`requireBackend`): B 구독 → A가 관리 댓글에서 B 차단 → 차단 목록에 B·구독자 수 감소 → B의 댓글·방명록·구독 거부 → A 해제 → B 댓글 성공 (quickstart #36~38)

### Implementation for User Story 5 (backend)

- [x] T118 [US5] `blog-backend/src/main/java/net/java21/blog/backend/block/service/BlogBlockService.java`, `block/repository/BlockQueryRepository.java`, `block/controller/BlogBlockController.java`, DTO `block/dto/BlockedUserResponse.java`; 구독 해제는 `blog-backend/src/main/java/net/java21/blog/backend/subscription/service/SubscriptionService.java`에 `removeForBlock(blogId, userId)`(행 삭제 + 카운터 원자적 감소, 002 해제와 같은 쿼리)
- [x] T119 [US5] `BlogBlockPolicy.requireNotBlocked`를 `comment/service/CommentService.java`(회원 쓰기), `guestbook/service/GuestbookService.java`(회원 쓰기), `subscription/service/SubscriptionService.java`(구독)에 연결

### Implementation for User Story 5 (front)

- [x] T120 [US5] `blog-front/app/routes/manage/blocks.tsx`, `blog-front/app/components/manage/BlockButton.tsx`를 `routes/manage/comments.tsx`·`routes/manage/guestbook.tsx`에, 관리 메뉴 "차단 목록", 문구 `manage` namespace(4개 언어)

**Checkpoint**: US5 Independent Test E2E 통과, quickstart #36~39

---

## Phase 8: Polish & Cross-Cutting Concerns

- [x] T121 [P] `blog-backend/src/test/java/net/java21/blog/backend/integration/BlogFeatureExposureIntegrationTest.java`(`@SpringBootTest`, H2, `blog.portal.cache-ttl=0s`): 노출 매트릭스 PROTECTED·SCHEDULED 행을 블로그 홈·카테고리·블로그 태그·서비스 태그·공지·보관함·사이드바(최근 글·인기 글·최근 댓글)·구독 피드·RSS·Atom·사이트맵·포털 메인·주제 페이지·관련 글에서 한 번에(보호 글은 제목만 또는 제외, 예약 글은 0건), 비밀 댓글·비밀 방명록 내용이 권한 밖 응답에 0건, 비회원 비밀번호 해시·IP가 어떤 응답에도 없음 (001 SC-004)
- [x] T122 [P] `blog-backend/src/test/java/net/java21/blog/backend/openapi/OpenApiContractTest.java`에 contracts/api.md의 004 엔드포인트(공개 11, 주인 10)와 확장 필드
- [x] T123 [P] `blog-backend/src/test/java/net/java21/blog/backend/security/CacheHeadersWebMvcTest.java`에 004 주인 API·`POST /posts/{id}/unlock`·백업 파일 `no-store`, 글 상세는 `private, no-cache` 그대로
- [x] T124 [P] 운영 문서 `blog-backend/docs/operations.md`에 004 프로퍼티(`blog.stats.*`, `blog.guest.*`, `blog.export.*`, `blog.posts.*` 추가 값, `blog.jobs.*` 추가 값), 정기 작업 목록(예약 발행 30초, 백업 생성 30초, 백업 정리 매시), 백업 디렉터리의 디스크 용량·권한과 "DB 백업에 포함되지 않음, 7일 뒤 지워지는 임시 파일이라 일일 백업 대상에서 빼도 됨"(헌법 1.0 운영 범위), 비회원 IP 90일 파기. front 4개 언어 README(`blog-front/README.md`·`README.en.md`·`README.ja.md`·`README.zh-CN.md`)에 E2E 환경 변수 `E2E_GUEST_TEST_SETTINGS`와 E2E용 backend 설정(quickstart "준비" 2)
- [x] T125 [P] E2E `blog-front/tests/e2e/blog-mobile.spec.ts`(`requireBackend`, 뷰포트 360×740): 블로그 홈(사이드바가 본문 아래), 방명록, 관리 꾸미기에서 가로 스크롤 없음 (spec Assumptions, quickstart #43)
- [x] T126 SC-010 확인: 기본 주기(30초)로 띄운 backend에서 예약 글 5편을 10초 간격으로 예약하고 실제 발행 지연(최대·평균)을 기록. 도구는 저장소에 추가하지 않고 절차와 결과를 backend PR 설명에 기록(1분 초과면 주기를 줄이는 결정을 이 표에 추가)
- [x] T127 커버리지 확인: `blog-backend`의 `./mvnw verify`, `blog-front`의 `npm test -- --coverage` 모두 라인 80% 이상
- [ ] T128 `blog-docs/specs/004-blog-features/quickstart.md` 수동 검증 시나리오 #1~43 전체 실행(backend·front 함께 기동), 끝난 작업을 이 tasks.md에 [x]로 표시 — (수동, 배포 후)

---

## 구현 전 결정 사항 (2026-10-07 확정)

marco가 "묻지 말고 진행"하라고 해서 Claude가 기본값으로 정했다. 바꾸려면 이 표와 관련 문서를 함께 고친다.

| # | 문제 | 결정 | 반영 문서 |
|---|---|---|---|
| 1 | spec에 백업(FR-145)·차단(FR-146)의 사용자 스토리가 없음 | plan이 US4(백업, P4)·US5(차단, P5)로 만들고 FR 문장에서 Independent Test를 정했다(스토리 5개 이하, 헌법 개발 흐름 2). spec.md는 고치지 않는다 | plan.md Summary, 이 문서 Phase 6·7 |
| 2 | 보호 글·예약 글의 노출 | `PostVisibility.PROTECTED`를 `LISTABLE_VISIBILITIES`에 넣고, 예약은 `status = SCHEDULED`라 `listable()`이 자동으로 뺀다. 아직 분기가 없던 블로그 글 목록·태그 글 목록은 `PostSummaryResponse.forReader`로 보호 글 요약·이미지를 가린다 | research B1 |
| 3 | 관련 글의 보호 글 | 관련 글(002)은 `bodyVisible()`이라 보호 글을 빼는 그대로 둔다(매트릭스의 "제목만"보다 엄격, 본문을 권하는 영역) | research B1 |
| 4 | 보호 글 열람 방식 | `POST /posts/{id}/unlock` 성공 시 001 `JwtProvider`로 서명한 30분 쿠키 `post_unlock_{id}`(비밀번호 지문 포함, 바꾸면 무효). 잠긴 상세는 `locked: true`와 제목·작성자·발행일만, 댓글은 403 `POST_LOCKED`, 조회수·끝까지 읽음은 세지 않음, `noindex` | research B4, contracts/api.md |
| 5 | 비밀번호 시도 제한 | 대상(보호 글·비회원 댓글·비회원 방명록)마다 방문자 키 또는 IP가 5회 연속 틀리면 10분 429 `PASSWORD_ATTEMPTS_EXCEEDED`(`Retry-After`). Caffeine, 테이블 없음 | research B3 |
| 6 | 공지를 "일반 목록"에서 빼는 범위 | 블로그 홈 목록(조건 없는 `GET /blogs/{h}/posts`)에서만 뺀다. 카테고리·태그·보관함·검색·피드·사이트맵·포털에는 일반 글처럼 나온다. 지정은 발행 설정 `notice`·관리 일괄 작업·꾸미기 화면 해제 | research B8 |
| 7 | 예약 발행 방식 | 발행 설정 `scheduledAt`(DRAFT·SCHEDULED 글만, 365일 이내, 지금 이하면 즉시 발행). 30초 주기 작업이 조건부 UPDATE로 발행하고 `published_at` = 실제 발행 시각, `scheduled_at`은 NULL로. 예약 취소는 `POST /posts/{id}/unschedule` → DRAFT | research B5 |
| 8 | 예약 글과 휴지통·트랙백 | 휴지통 복구는 SCHEDULED로 돌아가고 시각이 지났으면 다음 주기에 발행. 예약 발행 때 트랙백 보내기는 005가 작업의 발행 지점에 붙인다 | research B5, plan.md 범위 밖 |
| 9 | 비회원 쓰기 보호 | `guest_write_enabled`(기본 꺼짐)일 때만, 이름 1~30자·비밀번호 4~64자, IP당 댓글 1분 5개·방명록 1분 3개(Caffeine). CAPTCHA·회원 속도 제한·운영자 설정값(005 FR-141·142)은 005가 `GuestWriteGuard` 구현을 바꾼다 | research B6 |
| 10 | 비회원 비밀 글을 작성자가 보는 방법 | 로그인 신원이 없으므로 `POST /comments/{id}/unlock`·`/guestbook-entries/{id}/unlock`에 비밀번호를 보내 그 글 하나의 내용을 받는다(쿠키 없음, 수정 화면용). 목록에서는 비회원 작성자에게도 "비밀 댓글입니다" | research B6 |
| 11 | 비밀 댓글을 보는 사람 | 글 주인, 작성 회원, 답글이면 부모 댓글 작성 회원. 비밀 댓글의 답글과 비밀 부모 아래 답글도 비밀. 판단은 `CommentVisibility.canRead` 한 곳(방명록은 `GuestbookVisibility`, 같은 규칙에 "글 주인" 대신 "블로그 주인") | research B6·B7 |
| 12 | 방명록 답글과 알림 | 주인 답글은 같은 쓰기 API의 `parentId`(주인만), 한 글에 답글 여러 개 허용(댓글과 같은 `replies`). 새 방명록 알림은 만들지 않고(002 알림 종류에 없음) 대시보드에 최근 7일 수와 최근 5건 | research B7, B16 |
| 13 | 방명록을 껐을 때 | 주인이 아닌 사람의 목록·쓰기는 404 `GUESTBOOK_DISABLED`, 메뉴 숨김. 주인은 관리 화면에서 계속 보고 답글·삭제. 행은 지우지 않음 | research B7 |
| 14 | 방문자 수 세는 법 | front 공개 블로그 레이아웃 loader가 `POST /blogs/{h}/visits`(SSR). 같은 방문자(회원 ID 또는 방문자 쿠키)는 블로그마다 하루 한 번, 날짜는 `blog.stats.time-zone`(Asia/Seoul). 블로그 주인 본인과 봇(User-Agent 정규식, 빈 값 포함)은 세지 않음. Caffeine 25시간 | research B9 |
| 15 | 방문 통계 보관 기간 | `blog_daily_visits`는 지우지 않는다(방문이 있던 날만 행, 행이 작음). 통계 화면은 30일만 씀. 기간을 두게 되면 `visit_date` 인덱스를 Crowfoot로 **marco 승인** 후 추가(plan.md에 DDL) | research B9, data-model |
| 16 | 월별 보관함의 기준 | 서비스 시간대(`blog.stats.time-zone`)의 연·월. 블로그 글의 발행 시각만 읽어 자바에서 묶음. 그 달의 글은 `GET /blogs/{h}/posts?year=&month=`(카테고리·태그와 함께 쓰지 않음) | research B12 |
| 17 | 사이드바 계산 | `GET /blogs/{h}/sidebar` 한 번에 켜진 항목만 계산, 서버 캐시 없음. 최근 댓글은 본문 노출 가능 글의 비밀이 아닌 댓글만, 인기 글은 `view_count` 순, 태그는 상위 30. 저장은 10개 전체 교체, 행이 없으면 기본 구성 | research B10 |
| 18 | 사이드바를 그리는 곳 | front 경로 없는 레이아웃 `routes/blog/layout.tsx`가 공개 블로그 화면 9개를 감싼다. 글쓰기·관리 화면은 밖. 자식 loader는 그대로 두고 `GET /blogs/{h}` 중복은 요청 메모로 한 번 | research B11, contracts/routes.md |
| 19 | 블로그 내 검색 | 002 `GET /search/posts`에 `blog={handle}` 조건(새 API 없음). 002 검색어·보호 글 규칙 그대로 | research B12 |
| 20 | 태그 목록의 강조 | 001 `GET /blogs/{h}/tags`(이름순, 글 수) 재사용, front가 글 수로 1~5단계 로그 눈금 | research B12 |
| 21 | 백업 생성 방식과 내용 | 30초 주기 작업이 PENDING을 하나씩 처리(재기동에 안전, 1시간 넘은 RUNNING은 FAILED). zip에 휴지통을 뺀 모든 글(front matter + Markdown 원문, 발행 글의 작성 중 사본도), 원본 이미지, 카테고리 트리, `media.json`. 본문의 `/media/{key}`는 고치지 않음. 댓글·방명록·보호 글 비밀번호는 넣지 않음 | research B14 |
| 22 | 백업 제한·보관·알림 | 블로그당 24시간에 1회(FAILED는 세지 않음), 7일 보관 후 정리 작업이 파일 삭제·EXPIRED. 준비되면 `BACKUP_READY` 알림, 실패는 알림 없이 화면 상태로 | research B14 |
| 23 | 백업 파일 위치 | `blog.export.dir`(prod 필수 환경 변수, local `./data/exports`). 7일짜리 임시 파일이라 서버 일일 백업 대상에서 빼도 됨(운영 문서). 블로그 영구 정리 때 파일·행 삭제 | research B14·B16 |
| 24 | 차단 API와 거부 응답 | `PUT /blogs/{h}/blocks/{userId}` 멱등 생성(설계 규칙 예외, api.md), 해제 `DELETE`. 차단된 회원의 댓글·방명록·구독은 일반 403 `FORBIDDEN`(차단 사실을 드러내지 않음). 기존 글은 남기고, 읽기·좋아요는 막지 않음. 비회원은 차단 대상 아님. 차단은 관리 댓글·방명록 목록에서 | research B13 |
| 25 | 블로그 영구 정리와 개인정보 파기 | 001 `purgeBlogs`가 004 테이블(방명록·사이드바·방문·차단·백업 파일과 행)을 지운다. 001 개인정보 파기 작업이 비회원 IP를 90일 뒤 NULL로(`user_id IS NULL` 행, 기존 인덱스) | research B6·B16 |
| 26 | 일괄 공개 범위 변경과 보호 글 | 일괄 작업으로 PROTECTED를 지정할 수 없다(비밀번호가 없음, 400). PROTECTED 글을 일괄로 다른 공개 범위로 바꾸면 비밀번호를 지운다 | research B4, T075 |
| 27 | 스키마 변경 | DDL 없음. CHECK는 엔티티 `@Check`로 H2에도 걸어 테스트한다 | plan.md "스키마 변경", research B2 |
| 28 | E2E 설정 | 비회원 시나리오는 backend를 `BLOG_GUEST_COMMENT_PER_MINUTE=1000`, `BLOG_GUEST_GUESTBOOK_PER_MINUTE=1000`으로 띄우고 `E2E_GUEST_TEST_SETTINGS=1`일 때만. 예약·백업은 기본 주기(30초)에서 최대 90초 폴링. 예약 시험은 20초 뒤로 예약 | research B17, quickstart.md |
| 29 | 번역 namespace | 새로 `blog`(사이드바·보관함·공지·블로그 검색·태그 목록·블로그 메뉴), `guestbook`(방명록). 관리 화면은 `manage`, 발행 설정은 `post`, 댓글은 `comment`, 백업 알림은 `notification` | research B11 |
| 30 | 003 진행 중 작업과의 순서 | 004는 003 Phase 5~8(`feat/003-rest`)이 main에 머지된 뒤 시작. 발행 설정·블로그 설정·글 상세·보안 설정·오류 코드 파일을 함께 고치므로(아래 "003 의존") 그 뒤에 머지 | plan.md, 이 문서 |
| 31 | 다른 스펙의 일 | 방명록·댓글 HIDDEN과 신고, CAPTCHA·회원 속도 제한·금칙어, 트랙백 설정과 예약 발행 때 트랙백 보내기(005). 백업 복원(가져오기)·스킨 편집·상세 유입 통계(스펙 범위 밖) | plan.md "범위 밖" |

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: 001~003이 main에 있어야 함(003 Phase 5~8 머지 후)
- **Foundational (Phase 2)**: Setup의 프로퍼티(T004)·모델 타입(T002) 이후. 모든 스토리를 막는다
- **US1 방명록 (Phase 3)**: Phase 2 이후. MVP. 공개 블로그 레이아웃 뼈대(T046)를 만든다
- **US2 꾸미기·탐색 (Phase 4)**: Phase 2 이후. 사이드바는 US1의 레이아웃(T046)에 붙이므로 T046 이후 T070
- **US3 글 공개 옵션 (Phase 5)**: Phase 2(특히 `PasswordAttemptGuard` T023, `GuestAuthorService` T024) 이후. 비회원 댓글 front는 US1의 `GuestFields`(T047) 재사용. 보호 글 가림은 US2의 공지·보관함 목록(T065, T066)에도 적용되므로 둘 다 끝났으면 함께 확인
- **US4 백업 (Phase 6)**: Phase 2 이후. 백업 내용 시험은 US3의 보호·예약 글이 있으면 더 넓게 확인(없어도 독립 테스트 가능)
- **US5 차단 (Phase 7)**: Phase 2(`BlogBlockPolicy` T025) 이후. 확인 지점(T119)은 US1 `GuestbookService`(T043)·US3 `CommentService` 변경(T094) 이후
- **Polish (Phase 8)**: 원하는 스토리가 모두 끝난 뒤

### 003 의존 (feat/003-rest에서 구현된 003 작업)

| 004 작업 | 기대는 003 작업 | 내용 |
|---|---|---|
| T064, T091 (`PostPublishService`·`PublishSettingsRequest`) | 003 T077·T078 | 발행 설정의 `topicId`·주제 검증 뒤에 `notice`·`password`·`scheduledAt` |
| T072, T095 (`PublishSettingsDialog.tsx`, `write.tsx`) | 003 T080 | 발행 설정 레이어의 주제 선택 뒤 |
| T027, T032 (`UpdateBlogRequest`·`BlogResponse`·`BlogService`, `manage/settings.tsx`) | 003 T079·T081 | 포털 설정 필드 뒤 |
| T096 (`post-detail.tsx`, `seo/meta.ts`) | 003 T081 | 글 상세의 주제 링크·끝까지 읽음 추적기 뒤 |
| T016, T028, T031 (`ErrorCode`, `SecurityConfig`, `errors.json`) | 003 T082~T098·T104~T112 | 관리자·릴리스 노트 코드와 경로 뒤 |
| T121, T122, T123, T124 (Polish 공용 파일) | 003 T126~T129 | `integration/*ExposureIntegrationTest` 방식, `OpenApiContractTest`, `CacheHeadersWebMvcTest`, `docs/operations.md` |

### User Story Dependencies

- **US1 (P1)**: Phase 2 이후. 다른 스토리에 의존하지 않음. 001의 블로그·`BlogAccess`, 001 댓글 정규화 규칙 사용
- **US2 (P2)**: Phase 2 이후. US1의 레이아웃 뼈대를 쓰지만 backend는 독립 테스트 가능
- **US3 (P3)**: Phase 2 이후. 독립 테스트 가능(비회원 댓글 front는 US1 컴포넌트 재사용)
- **US4 (P4)**: Phase 2 이후. 002 알림, 001 이미지 저장소 사용
- **US5 (P5)**: Phase 2 이후. 확인 지점 연결은 US1·US3 이후

### Within Each User Story

- 테스트를 먼저 쓰고 실패를 확인한 뒤 구현한다(원칙 III)
- 엔티티 → 리포지토리(QueryDSL) → 서비스 → 컨트롤러 → front 라우트 → E2E
- 엔티티를 더할 때마다 `EntitySchemaValidationTest`(실제 스키마 대상 `ddl-auto=validate`)가 통과해야 한다
- 새 화면 문구·오류 코드는 같은 작업에서 4개 언어 번역을 넣는다(원칙 VII)
- 스토리의 E2E(Independent Test)가 통과해야 다음 우선순위로 넘어간다

### Parallel Opportunities

- Setup의 [P] 작업(T001~T004)은 모두 병렬
- Phase 2 테스트(T005~T015)는 모두 [P], 구현은 엔티티(T017~T022)·front 문구(T031·T032)가 병렬
- 각 스토리의 테스트 작업(backend·front)은 모두 [P]
- Phase 2 이후 US1(Phase 3), US3 backend(T090~T094), US4 backend(T107~T110)는 병렬 가능. 같은 파일(`ErrorCode`, `SecurityConfig`, `PostPublishService`(T064·T091), `PostQueryRepository`(T065·T090), `PostController`(T026·T065·T092·T093), `CommentService`(T094·T119), `GuestbookService`(T043·T119), `ManageDashboardService`(T045·T068), `TrashPurgeRepository`(T029·T110), `routes.ts`(T046·T071), `PublishSettingsDialog.tsx`(T072·T095), `manage/layout.tsx`·`manage/links.ts`(T048·T072·T111·T120), `errors.json`)을 고치는 작업은 머지 순서를 맞춘다

---

## Parallel Example: User Story 1

```bash
# backend 테스트를 함께 시작:
Task: "GuestbookQueryRepositoryTest in blog-backend/src/test/java/net/java21/blog/backend/guestbook/repository/GuestbookQueryRepositoryTest.java"
Task: "GuestbookServiceTest in blog-backend/src/test/java/net/java21/blog/backend/guestbook/service/GuestbookServiceTest.java"
Task: "GuestbookControllerTest in blog-backend/src/test/java/net/java21/blog/backend/guestbook/controller/GuestbookControllerTest.java"

# front 테스트를 함께 시작:
Task: "blogGuestbook.test.tsx in blog-front/tests/unit/routes/blogGuestbook.test.tsx"
Task: "GuestbookEntryItem.test.tsx in blog-front/tests/unit/components/GuestbookEntryItem.test.tsx"
Task: "blogLayout.test.tsx in blog-front/tests/unit/routes/blogLayout.test.tsx"
```

## Parallel Example: User Story 3

```bash
Task: "PostUnlockServiceTest in blog-backend/src/test/java/net/java21/blog/backend/post/service/PostUnlockServiceTest.java"
Task: "ScheduledPublishRepositoryTest in blog-backend/src/test/java/net/java21/blog/backend/post/repository/ScheduledPublishRepositoryTest.java"
Task: "CommentServiceTest in blog-backend/src/test/java/net/java21/blog/backend/comment/service/CommentServiceTest.java"
Task: "PublishSettingsDialog.test.tsx in blog-front/tests/unit/components/PublishSettingsDialog.test.tsx"
Task: "postDetail.test.tsx in blog-front/tests/unit/routes/postDetail.test.tsx"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1 Setup, Phase 2 Foundational
2. Phase 3 (US1 방명록)
3. **멈추고 확인**: US1 Independent Test E2E, quickstart #1~7
4. 시연·배포 가능(블로그 메뉴에 방명록, 비회원 허용 설정)

### Incremental Delivery

1. Setup + Foundational → 기반 완료(엔티티, 비회원 규칙, 블로그 설정)
2. US1(Phase 3) → MVP
3. US2(Phase 4) → US3(Phase 5) → US4(Phase 6) → US5(Phase 7), 각 스토리의 E2E 통과 후 다음
4. Polish → 노출 매트릭스 통합 확인, SC-010 측정, quickstart 전체 검증

### Parallel Team Strategy

1. 함께 Setup + Foundational
2. Foundational이 끝나면:
   - 개발자 A: Phase 3(US1) → Phase 4(US2)
   - 개발자 B: Phase 5(US3)
   - 개발자 C: Phase 6(US4) → Phase 7(US5)
3. 같은 파일을 고치는 연결 작업은 머지 순서를 맞춘다(Phase Dependencies, 003 의존)

---

## Notes

- [P] = 다른 파일, 끝나지 않은 작업에 의존하지 않음
- [Story] = spec.md 사용자 스토리 추적용(US4·US5는 plan이 FR-145·146에서 만든 단위)
- 각 PR 설명에 스펙 경로 `blog-docs/specs/004-blog-features`를 적는다(헌법 개발 흐름 6)
- 엔티티는 API 응답으로 직렬화하지 않고 DTO record를 쓴다. 연관관계는 모두 LAZY, 목록은 fetch join 또는 DTO projection, 목록 테스트에는 `QueryCounter`
- 005가 더한 컬럼·값(`posts.status_before_hidden`, `blogs.trackback_enabled`, HIDDEN)은 DB 기본값·NULL 허용이므로 004 엔티티에 매핑하지 않는다
- 비밀번호 시도·방문 중복·비회원 속도 캐시와 예약·백업 작업은 backend 1대 전제(001 R26)다. 서버를 늘리면 공유 저장소와 작업 잠금(ShedLock 등)을 따로 계획한다
- 테스트가 실패하는 것을 먼저 확인하고, 작업 단위로 커밋한다
