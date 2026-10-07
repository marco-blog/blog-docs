# Implementation Plan: 블로그 꾸미기와 글 옵션 (방명록·공지·보관함·보호 글·예약·백업·차단)

**Branch**: `004-blog-features` (계획 문서는 `docs/004-plan`) | **Date**: 2026-10-07 | **Spec**: [spec.md](./spec.md)

**Status**: Phase 1 완료 (research, contracts, quickstart, tasks 작성). 다음 단계는 `/speckit-analyze` 후 `/speckit-implement`.

**Input**: Feature specification from `/specs/004-blog-features/spec.md`

## Summary

블로그를 "개인 공간"답게 만드는 기능과 글·댓글 옵션을 더한다. 방문자는 블로그 방명록에 글(비밀글·비회원 포함)을 남기고 주인은 답글·삭제·켜고 끄기를 한다(US1, FR-056~058·066). 주인은 공지를 지정하고 사이드바 항목(프로필·카테고리·최근 글·최근 댓글·인기 글·태그·월별 보관함·방문자 수·검색·피드)을 고르며, 방문자는 공지 목록·월별 보관함·블로그 내 검색·태그 목록을 쓰고 블로그마다 오늘·어제·전체 방문자 수를 센다(US2, FR-059~061·067). 글쓴이는 보호 글(비밀번호, 5회 실패 10분 차단)과 예약 발행(1분 이내 자동 발행)을 쓰고, 댓글은 비밀 댓글과 허용된 블로그의 비회원 댓글을 지원한다(US3, FR-062~066, SC-010). spec에 스토리가 없는 블로그 백업(FR-145)과 회원 차단(FR-146)은 FR에서 Independent Test를 만들어 US4·US5로 계획했다(결정 표 1번).

기술 접근: 보호 글·예약 글의 노출은 001 `PostExposure`의 자리(`LISTABLE_VISIBILITIES`, `status = PUBLISHED`)에 값만 넣어 해결하고, 002가 미리 둔 보호 글 분기를 그대로 쓴다. 보호 글 열람은 001 `JwtProvider`로 서명한 30분 쿠키, 비밀번호 실패 제한은 Caffeine 카운터(공용 `PasswordAttemptGuard`), 예약 발행은 30초 주기 작업의 조건부 UPDATE, 방문자 수는 Caffeine 중복 제거 + `blog_daily_visits` upsert, 백업은 정기 작업이 PENDING을 하나씩 꺼내 zip을 만드는 방식이다. 새 라이브러리와 스키마 변경은 없다(아래 "스키마 변경"). 세부 근거는 [research.md](./research.md).

## Technical Context

**Language/Version**: backend Java 21 / front TypeScript 5.9, Node.js 22 LTS (001~003과 같음)

**Primary Dependencies**:
- backend(001~003 그대로): Spring Boot 4.1.1(Web MVC, Security, Data JPA, Validation), QueryDSL OpenFeign 7.x, Hibernate 7, Caffeine, commonmark-java + OWASP HTML Sanitizer, springdoc-openapi. **새 의존성 없음**(zip은 `java.util.zip`, 서명 쿠키는 001 JWT 코드)
- front(001~003 그대로): React 19, React Router 8.4 framework 모드, Vite 8, Express 5, i18next + react-i18next, Milkdown Crepe(글쓰기 화면, 변경 없음). **새 의존성 없음**(예약 시각 입력은 `<input type="datetime-local">` + 회원 시간대 변환)

**Storage**: MySQL 8(InnoDB, utf8mb4, ngram_token_size=2). 004의 테이블(`guestbook_entries`, `blog_sidebar_items`, `blog_daily_visits`, `blog_exports`, `blog_blocks`)과 001 테이블 추가 컬럼(`blogs.guestbook_enabled`·`guest_write_enabled`·`total_visitors`, `posts.password_hash`·`scheduled_at`·`notice`, `comments.guest_name`·`guest_password_hash`·`guest_ip_enc`·`secret`, `comments.user_id` NULL 허용), CHECK 3개, 인덱스·외래 키가 Crowfoot 문서 "blog 1.0"(`db/schema-mysql.sql`)에 이미 있다. 백업 파일은 DB 밖 `blog.export.dir`

**Testing**: 001~003과 같음. JUnit 5, `@WebMvcTest` + `WebMvcTestSupport`, Mockito, `@JpaRepositoryTest`(H2) + `QueryCounter`, MySQL 전용(블로그 내 검색 FULLTEXT, 방문 동시 upsert)만 `@MySqlRepositoryTest`, `@SpringBootTest`는 노출 매트릭스·예약 발행 통합 확인만, Testcontainers 없음, JaCoCo 라인 80%. front Vitest(80%) + Playwright E2E(실제 backend, `requireBackend()`; 비회원 시나리오는 `requireGuestTestSettings()`)

**Target Platform**: Linux 서버 1대(backend 1대 전제, 001 R26 — 비밀번호 시도·방문 중복 제거 캐시와 예약·백업 작업이 이 전제에 기댄다), 최신 데스크톱/모바일 브라우저(폭 360px부터)

**Project Type**: 웹 서비스(REST API + SSR 웹 앱), 저장소 3개

**Performance Goals**: 예약 글은 예약 시각부터 1분 이내 발행(SC-010, 작업 주기 30초). 공개 블로그 화면의 사이드바는 loader 호출 1회·backend 쿼리 최대 7회. 방문 기록은 요청당 쿼리 0회(중복) 또는 2회(첫 방문)

**Constraints**: 보호 글 본문·예약 전 글·비밀 댓글·비밀 방명록 내용의 권한 밖 노출 0건(001 SC-004, 001 글 노출 매트릭스 PROTECTED·SCHEDULED 행), 보호 글·비회원 비밀번호 원문 저장 0건(FR-062, FR-066), 비회원 IP 평문 0건(001 FR-134), 커버리지 80%, 번역 누락 0건, N+1 금지

**Scale/Scope**: 새 공개 API 13개(방명록 5, 사이드바 1, 보관함 1, 공지 1, 방문 1, 보호 글 열기 1, 비밀 댓글 열기 1, 001·002 API 조건 추가 2), 새 주인 API 10개(사이드바 2, 통계 1, 예약 취소 1, 백업 3, 차단 3)와 001 API 확장 5곳(블로그 설정, 발행 설정, 대시보드, 일괄 작업, 관리 글 목록 필터), 새 화면 10개(공지·보관함·블로그 검색·태그 목록·방명록, 관리 방명록·꾸미기·통계·백업·차단) + 공개 블로그 레이아웃, 001~003 화면 변경 7곳(블로그 홈, 글 상세, 댓글, 발행 설정, 관리 글 목록, 블로그 설정, 대시보드)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| 원칙 | 확인 | 결과 |
|---|---|---|
| I. 스펙이 먼저다 | spec.md 확정(NEEDS CLARIFICATION 0개, checklist 통과). 이 plan은 FR-056~067, FR-145, FR-146, SC-010과 006 spec의 004 관리 메뉴(방명록·꾸미기·통계·백업·차단, 대시보드 방문자·방명록)만 다룬다. spec에 스토리가 없는 FR-145·146은 FR 문장에서 Independent Test를 만들었고, 모호한 점은 tasks.md "구현 전 결정 사항"에 기본값으로 기록(marco "묻지 말고 진행") | 통과 |
| II. 세 저장소, 두 실행 파트 | 캐시·작업은 backend 프로세스 안(Caffeine, `@Scheduled`). 백업 파일은 backend 디스크. Redis·큐·별도 작업 서버 없음. front는 REST API만 호출 | 통과 |
| III. 테스트 우선·커버리지 | 각 스토리의 테스트 작업이 구현보다 앞섬, 인수 시나리오마다 테스트(tasks.md), H2 + 쿼리 수 확인(엔티티 `@Check`로 H2에도 CHECK), MySQL 전용만 `@MySqlRepositoryTest`, Testcontainers 없음, 80% 게이트 유지 | 통과 |
| IV. 보안과 공개 범위 | 노출은 001 `PostExposure` 한 곳(PROTECTED·SCHEDULED 값만 추가). 보호 글 본문은 주인 또는 서명 쿠키가 있을 때만, 비밀 댓글·방명록 내용은 `canRead` 한 곳에서 거름. 모든 쓰기 API는 주인·작성자(회원 ID 또는 비회원 비밀번호) 검증. 비밀번호는 BCrypt, 비회원 IP는 AES-256-GCM, 응답에 해시·암호문·파일 경로 없음. 비밀번호 시도 5회 10분 차단, 비회원 쓰기 속도 제한. 차단은 일반 거부(403) | 통과 |
| V. SSR | 방명록, 공지 목록, 보관함, 블로그 검색, 태그 목록, 사이드바, 보호 글 잠금 화면은 SSR(JS 없이 목록·메타 포함). 보호 글 열기·비밀번호 입력·비회원 댓글은 `action` 폼이라 JS 없이 동작 | 통과 |
| VI. 단순함 | 새 라이브러리 없음. 새 정기 작업 3개(예약 발행, 백업 생성, 백업 정리)와 Caffeine 캐시 3개(비밀번호 시도, 방문 중복, 비회원 속도)만 추가(Complexity Tracking) | 통과 |
| VII. 다국어 우선 | 새 문구는 `blog`·`guestbook` namespace와 `manage`·`post`·`comment`·`notification`·`common`·`errors`에 4개 언어로. 사용자가 쓴 방명록·댓글·이름은 번역하지 않음. 새 오류 코드 13개 번역. 예약 시각은 회원 시간대로 입력·표시하고 UTC로 저장. 백업 파일 안의 front matter 키는 영어 고정(데이터 형식) | 통과 |
| 기술 제약 | Java 21, Spring Boot 4.1.1, JPA + QueryDSL(OpenFeign), N+1 금지, Crowfoot 스키마(DDL 변경 없음), 공통 응답 틀(실제 HTTP 상태, 문자열 `resultCode`, 페이지는 `totalCount`), 첨부 파일·백업 경로는 `blog.*` 프로퍼티, 에디터는 Milkdown Crepe 그대로 | 통과 |

**Phase 1 이후 재확인**: research, contracts(api.md, routes.md), quickstart, tasks 작성 후 원칙 I~VII을 다시 점검했고 위반 없음. 설계 규칙과 다르게 만든 곳(차단 PUT의 멱등 생성, 백업 파일 내려받기의 zip 응답, 비회원 DELETE 본문의 비밀번호)은 contracts/api.md에 이유를 적었다.

## 스키마 변경

**DDL은 필요 없다.** 004 data-model의 테이블·컬럼·CHECK·인덱스·외래 키가 모두 `db/schema-mysql.sql`(Crowfoot 문서 "blog 1.0", migrations/0001-baseline.sql)에 있다. 004 쿼리를 하나씩 대조했다.

| 쿼리·쓰기 | 쓰는 테이블·컬럼·인덱스·제약 | 비고 |
|---|---|---|
| 보호 글 저장·해제 | `posts.visibility`(VARCHAR(10), `PROTECTED` 9자), `posts.password_hash`, `ck_posts_protected_password` | 엔티티 `@Check`로 H2에도 |
| 예약 저장·취소 | `posts.status`(`SCHEDULED` 9자), `posts.scheduled_at` | |
| 예약 발행 대상 | `idx_posts_status_scheduled` (status, scheduled_at) | 30초마다 |
| 공지 목록 | `idx_posts_blog_notice_published` (blog_id, notice, published_at DESC) | |
| 블로그 홈 목록(공지 제외) | `idx_posts_blog_status_visibility_published` + `notice = false` 필터 | 001 쿼리에 조건 추가 |
| 월별 보관함·그 달의 글 | `idx_posts_blog_status_visibility_published`(발행 시각 범위) | 묶음은 자바 |
| 블로그 내 검색 | `ft_posts_title_content`, `ft_posts_title` + `blog_id` 조건 | MySQL 전용 |
| 사이드바 최근·인기 글 | `idx_posts_blog_status_visibility_published` | 블로그 안 정렬 |
| 사이드바 최근 댓글 | `idx_posts_blog_status_visibility_published` → `idx_comments_post_created` | 블로그 글 조인 |
| 사이드바 설정 | PK (blog_id, item_type), `fk_blog_sidebar_items_blog` | 전체 교체 |
| 방문 기록·조회 | PK (blog_id, visit_date), `blogs.total_visitors` | upsert |
| 방명록 목록·답글 | `idx_guestbook_entries_blog_status_created`, `idx_guestbook_entries_parent`, `ck_guestbook_entries_author` | |
| 비회원 댓글 | `comments.user_id`(NULL 허용), `guest_name`·`guest_password_hash`·`guest_ip_enc`·`secret`, `ck_comments_author` | |
| 비회원 IP 90일 파기 | `idx_comments_user`, `idx_guestbook_entries_user`(`user_id IS NULL` 행) | 001 개인정보 파기 작업 |
| 차단 확인·목록 | PK (blog_id, blocked_user_id), `idx_blog_blocks_blocked_user` | |
| 백업 하루 제한·목록 | `idx_blog_exports_blog_created` | |
| 백업 대기열·만료 정리 | `idx_blog_exports_status_expires` (status, expires_at) | |
| 백업 알림 | `notifications.type`(VARCHAR(30) `BACKUP_READY`), `target_type`(`BLOG_EXPORT`) | 002 테이블 그대로 |
| 블로그 영구 정리 | 각 004 테이블의 `blog_id` 외래 키(CASCADE 없음) | 001 정리 작업에서 먼저 삭제 |

엔티티는 기존 스키마에 맞춰 매핑하며(`ddl-auto=validate`, `EntitySchemaValidationTest`), 지금까지 "004~005 컬럼은 매핑하지 않는다"고 적힌 `Post`·`Blog`·`Comment` 주석을 고친다. 005 컬럼(`posts.status_before_hidden`, `blogs.trackback_enabled`)과 HIDDEN 값은 004에서 매핑하지 않는다(NULL 허용·DB 기본값).

**DDL 제안 없음.** 다만 아래 경우에는 marco 승인이 필요한 DDL을 따로 제안한다(지금 구현하지 않음): 방문 통계의 보관 기간을 두기로 바꾸면(결정 표 15번) `CREATE INDEX idx_blog_daily_visits_visit_date ON blog_daily_visits (visit_date ASC);`가 필요하다. 그때는 [db/README.md](../../db/README.md) 절차(data-model·erd.md → Crowfoot 문서 → `plan_migration` → **marco 승인(Crowfoot)** → `apply_migration` → `migrations/NNNN-*.sql` → `schema-mysql.sql`·backend 테스트 스냅숏)를 따른다.

**데이터 보정 없음.** 새 컬럼은 모두 DB 기본값(`guestbook_enabled` true, `guest_write_enabled` false, `total_visitors` 0, `notice` false, `secret` false)으로 기존 행에 맞는 값이 이미 들어 있다.

## Project Structure

### Documentation (this feature)

```text
specs/004-blog-features/
├── spec.md              # 기능 스펙
├── plan.md              # 이 문서
├── research.md          # Phase 0: 기술 결정과 근거 (B1~B17)
├── data-model.md        # Phase 1: 테이블 (스펙 단계에서 작성, 방문 통계 보관 기간만 확정)
├── quickstart.md        # Phase 1: 실행·수동 검증 시나리오
├── contracts/
│   ├── api.md           # 004 REST API 계약, 001~003 응답 확장
│   └── routes.md        # 004 화면과 001~003 화면 변경
├── checklists/requirements.md
└── tasks.md             # Phase 2: 작업 목록과 구현 전 결정 사항
```

### Source Code

001~003 구조에 아래를 더한다. 패키지 안 구성은 001과 같이 `controller`, `service`, `repository`, `domain`, `dto`, `job`, `event`.

```text
blog-backend/src/main/java/net/java21/blog/backend/
├── guestbook/         # 방명록: GuestbookEntry 엔티티, GuestbookQueryRepository, GuestbookService, GuestbookController
│                      #   (/blogs/{handle}/guestbook, /guestbook-entries/{id})
├── guest/             # 비회원 쓰기 공통: GuestAuthorService(이름·비밀번호·IP), GuestWriteGuard·RateLimitGuestWriteGuard(005가 바꿈),
│                      #   GuestProperties(blog.guest.*), dto/GuestCredentials
├── sidebar/           # 사이드바: BlogSidebarItem 엔티티, SidebarItemType, SidebarQueryRepository, SidebarService, SidebarController
├── stats/             # 방문자: BlogDailyVisit 엔티티, BlogVisitRepository(upsert), VisitService(중복 제거·봇), VisitorStatsService,
│                      #   StatsProperties(blog.stats.*), VisitController(/blogs/{handle}/visits), StatsController(/manage/stats)
├── export/            # 백업: BlogExport 엔티티, BlogExportRepository, BlogExportService, BlogExportWriter(zip), BlogExportJob,
│                      #   BlogExportCleanupJob, ExportStorage, ExportProperties(blog.export.*), BlogExportController
├── block/             # 차단: BlogBlock 엔티티, BlogBlockRepository·BlockQueryRepository, BlogBlockPolicy, BlogBlockService, BlogBlockController
├── common/security/   # (새) PasswordAttemptGuard — 보호 글·비회원 비밀번호 공용 시도 제한
├── common/web/        # (001) + VisitorKeyResolver(조회수·끝까지 읽음·방문 공용 방문자 키)
├── post/              # (001) + PostVisibility.PROTECTED·PostStatus.SCHEDULED, Post 매핑(password_hash·scheduled_at·notice, @Check),
│                      #   PostUnlockService·PostUnlockCookies, ScheduledPublishJob·ScheduledPublishRepository, 발행 설정의 password·scheduledAt·notice,
│                      #   공지 목록·보관함 쿼리(PostQueryRepository), PostSummaryResponse.forReader
├── comment/           # (001) + 비회원·비밀 댓글(Comment 매핑, CommentVisibility, 비회원 수정·삭제·열기), CommentCreatedEvent.authorId nullable
├── blog/              # (001) + Blog.guestbookEnabled·guestWriteEnabled·totalVisitors, BlogResponse·UpdateBlogRequest 확장
├── manage/            # (001) + 대시보드 방문자·방명록, 일괄 작업 NOTICE·UNNOTICE, 글 목록 SCHEDULED·PROTECTED 필터
├── search/            # (002) + 블로그 내 검색(blog 조건)
├── subscription/      # (002) + 구독 때 차단 확인
├── notification/      # (002) + NotificationType.BACKUP_READY, NotificationTargetType.BLOG_EXPORT
├── post/job/TrashPurgeJob (001) + 004 테이블 정리, user/job/PrivacyPurgeJob (001) + 비회원 IP 파기
blog-backend/src/main/resources/application.yml   # blog.stats.*, blog.guest.*, blog.export.*, blog.posts.* 추가 값, blog.jobs.* 추가 값

blog-front/app/
├── routes/blog/layout.tsx                    # 공개 블로그 화면의 경로 없는 레이아웃(사이드바, 블로그 메뉴, 방문 기록)
├── routes/blog-notice.tsx, blog-archive.tsx, blog-search.tsx, blog-tags.tsx, blog-guestbook.tsx
├── routes/manage/guestbook.tsx, design.tsx, stats.tsx, backup.tsx, blocks.tsx
├── components/blog/Sidebar.tsx, SidebarItems/*.tsx, BlogNav.tsx, NoticeList.tsx, ArchiveList.tsx, TagCloud.tsx
├── components/guestbook/GuestbookList.tsx, GuestbookForm.tsx, GuestbookEntryItem.tsx
├── components/comment/GuestFields.tsx, SecretToggle.tsx, GuestPasswordPrompt.tsx   # 댓글·방명록 공용
├── components/post/LockedPost.tsx, ProtectedPasswordField.tsx, ScheduleField.tsx
├── components/manage/VisitorChart.tsx(표·막대, 라이브러리 없음), SidebarEditor.tsx, BlockButton.tsx
├── blog/tagWeight.ts, archive.ts, sidebar.ts, guestAuthor.ts
├── i18n/zonedDateTime.ts                     # datetime-local ↔ UTC(회원 시간대)
└── locales/{ko,en,ja,zh-CN}/blog.json, guestbook.json   # + manage·post·comment·notification·common·errors에 키 추가
```

**Structure Decision**: 001의 도메인별 패키지 구조를 따른다. 방명록·사이드바·방문 통계·백업·차단은 각자 테이블을 가진 기능이라 패키지를 나눈다. 비회원 쓰기 규칙은 댓글과 방명록이 함께 쓰므로 `guest`에, 비밀번호 시도 제한은 보호 글과 비회원이 함께 쓰므로 `common/security`에 둔다. 보호 글·예약 발행·공지는 글의 속성이라 `post`에 둔다.

## 구현 순서 (사용자 스토리 기준)

| 단계 | 스토리 | 핵심 산출물 | FR |
|---|---|---|---|
| 0 | 기반 | 004 엔티티 매핑(새 테이블 5개, 001 추가 컬럼, `@Check`), `PasswordAttemptGuard`, `GuestAuthorService`·`GuestWriteGuard`, `BlogBlockPolicy`, `VisitorKeyResolver`, 블로그 설정(`guestbookEnabled`·`guestWriteEnabled`), 오류 코드, 공개 경로(보안), 블로그 영구 정리·비회원 IP 파기, front 번역 namespace·모델 타입·E2E 도구 | FR-058, FR-066 |
| 1 | US1 방명록 (P1) | 방명록 API(목록·쓰기·답글·수정·삭제·열기), 비밀글, 비회원 방명록, 방명록 끄기, 대시보드 방명록, `/:handle/guestbook`, 관리 방명록 화면 | FR-056~058, FR-066 |
| 2 | US2 꾸미기·탐색 (P2) | 공지(발행 설정·일괄 작업·목록·홈 위), 사이드바(설정·데이터), 월별 보관함, 블로그 내 검색, 태그 목록, 방문 기록·통계·대시보드, 공개 블로그 레이아웃, 꾸미기·통계 화면 | FR-059~061, FR-067 |
| 3 | US3 글 공개 옵션 (P3) | PROTECTED·SCHEDULED 값과 목록 가림, 보호 글 비밀번호·열기·잠금 화면, 예약 저장·취소·정기 발행, 비밀 댓글, 비회원 댓글(쓰기·수정·삭제·열기·알림), 발행 설정·글 상세·댓글·관리 글 목록 화면 | FR-062~066, SC-010 |
| 4 | US4 블로그 백업 (P4) | 백업 요청·목록·내려받기 API, zip 생성 작업, 만료 정리, `BACKUP_READY` 알림, 블로그 정리 시 파일 삭제, 백업 화면 | FR-145 |
| 5 | US5 회원 차단 (P5) | 차단 목록·차단·해제 API, 구독 해제, 댓글·방명록·구독 거부, 차단 목록 화면, 관리 댓글·방명록의 "차단" | FR-146 |

각 단계는 끝날 때 해당 스토리의 Independent Test를 E2E로 통과해야 한다. 단계 1~5는 단계 0 이후 서로 독립이지만, US1의 비회원 방명록과 US3의 비회원 댓글이 단계 0의 `GuestAuthorService`를, US5의 차단 확인이 단계 0의 `BlogBlockPolicy`를 쓴다. 같은 파일(`ErrorCode`, `SecurityConfig`, `BlogResponse`·`UpdateBlogRequest`·`BlogService`, `PostPublishService`·`PublishSettingsRequest`, `PostQueryRepository`, `CommentService`, `ManageDashboardService`, `routes.ts`, `post-detail.tsx`, `CommentSection.tsx`, `PublishSettingsDialog.tsx`, `manage/layout.tsx`, `errors.json`)을 고치는 작업은 순서대로 머지한다.

**003 진행 중 작업과의 관계**: 003 Phase 5~8(글 주제 지정, 관리자 콘솔, 릴리스 노트, Polish)이 `feat/003-rest`에서 구현되어 main 머지를 기다린다. 004가 같은 파일을 고치는 곳은 tasks.md "Dependencies"의 "003 의존" 표에 적었다(`PostPublishService`·`PublishSettingsRequest`·`PublishSettingsDialog`(003 T078·T080), `BlogResponse`·`UpdateBlogRequest`·`BlogService`·`manage/settings.tsx`(003 T079·T081), `SecurityConfig`·`ErrorCode`, `post-detail.tsx`, 사이트맵, Polish 공용 테스트(003 T126~T129)). 004는 `feat/003-rest`가 main에 머지된 뒤 시작한다.

**범위 밖(다른 스펙)**:
- 005: 방명록·댓글의 HIDDEN(관리자 숨김)과 신고, 회원 쓰기 속도 제한·운영자 설정값(`ratelimit.*`)·CAPTCHA(FR-141·142) — 004는 비회원 IP 속도 제한만 두고 `GuestWriteGuard` 자리를 남긴다, 금칙어(FR-143), 트랙백 받기 설정(`trackback_enabled`)과 예약 글 발행 때 트랙백 보내기(001 R17의 "트랙백 전송 이벤트"는 005가 `ScheduledPublishJob`의 발행 지점에 붙인다).
- 006: 시스템 관리자 콘솔의 004 관련 메뉴(없음). 블로그 관리 메뉴 중 004 몫(방명록·꾸미기·통계·백업·차단, 대시보드 방문자·방명록)은 004가 만든다(006 spec 머리말 "각 스펙과 함께 채운다").
- 스펙 범위 밖: 스킨·HTML/CSS 편집, 상세 유입 경로 통계, 외부 블로그 글 가져오기, 백업 파일로 복원(가져오기)(spec Assumptions).

## Complexity Tracking

| 도입 | 이유 | 더 단순한 대안을 쓰지 않은 이유 |
|---|---|---|
| 정기 작업 3개(`ScheduledPublishJob` 30초, `BlogExportJob` 30초, `BlogExportCleanupJob` 매시) | SC-010(1분 이내 발행), FR-145(오래 걸리는 zip 생성, 7일 뒤 만료) | 조회 시점 판단은 노출 조각 전체에 시각 조건이 퍼짐(research B5). 요청 스레드에서 zip 생성은 긴 요청·재시도 문제, `@Async`는 재기동 때 대기 작업이 사라짐(research B14) |
| 비밀번호 시도 제한 캐시(`PasswordAttemptGuard`) | FR-063: 5회 연속 실패 10분 차단 | DB 기록 테이블은 스키마 변경. 001 로그인 잠금은 회원 행 컬럼이라 비회원·보호 글에 쓸 수 없음 (research B3) |
| 방문 중복 제거 캐시와 비회원 속도 제한 캐시 | FR-067(하루 한 번), 001 R20(비회원 IP 속도) | 방문자 키를 DB에 저장하면 개인정보와 스키마가 늘어남. 속도 제한은 005가 일반화하기 전의 최소 장치 (research B6·B9) |
| 서명 열람 쿠키(`post_unlock_{id}`) | FR-062: 비밀번호를 맞힌 방문자에게만 본문, SSR 첫 요청 포함 | 서버 세션·DB 기록은 상태 저장이 늘고, 비밀번호를 요청마다 보내면 기록에 남음. 001 JWT 서명기를 재사용해 새 키 없음 (research B4) |
