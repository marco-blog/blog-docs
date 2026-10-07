# Research: 006 관리 화면

> 001의 결정(R1~R28: 인증, 프록시, SSR 구성, 노출 조각, 테스트 방식, 정기 작업, 보안 헤더, 다국어), 002(D1~D11), 003(P1~P14), 004(B1~B17), 005(M1~M18)의 결정은 그대로 따른다. 모든 API 경로는 `/api/v1` 접두어를 쓴다.
>
> 006 spec은 두 관리 화면의 구조와 공통 규칙을 정하고, 메뉴 대부분은 각 기능 스펙이 만든다(spec 머리말). 그래서 이 문서는 먼저 **무엇이 이미 있는지**를 코드로 확인하고(A1), 남은 몫만 결정한다.

확인일: 2026-10-07 (blog-backend main `29c2308`, blog-front main `b3a0484` 기준. 001~003과 004 Phase 1~4는 main에 있다. 004 Phase 5~8은 `feat/004-rest`에서 구현 중이라 [004 tasks](../004-blog-features/tasks.md)를, 005는 계획만 있어 [005 plan](../005-trackback-moderation/plan.md)·[tasks](../005-trackback-moderation/tasks.md)를 기준으로 읽었다)

## 현재 코드에서 확인한 것

**backend**
- 관리자 접근: `admin/AdminAccessFilter`가 `/api/v1/admin/**`에서 `AdminRoleLookup`(`DatabaseAdminRoleLookup`, `existsByIdAndStatusAndRoleIn` 쿼리 1회)으로 DB의 현재 `role`·`status`를 확인하고 아니면 404 `NOT_FOUND`(001 T159). JWT의 role 클레임은 보지 않는다 → FR-097 "권한 회수는 다음 요청부터"가 이미 성립.
- 첫 최고 관리자: `admin/SuperAdminBootstrap`(기동 시 SUPER_ADMIN이 없으면 `blog.admin.bootstrap-super-admin-email` 회원을 지정), `AdminUserRepository.updateRole`·`existsByRole`(001 T154).
- 작업 기록 쓰기: `admin/audit/AdminAuditLog`(`@Immutable`, 요청 IP `EncryptedStringConverter`), `AdminAuditService.record`·`recordKey`(`Propagation.MANDATORY` — 변경과 같은 트랜잭션), `AdminAuditLogRepository`(save와 대상별 조회만, 삭제 없음), `AuditActions`(003 값만, "005~007이 더한다"). 회원별 블로그 한도는 `AdminUserService`가 `"USER_BLOG_LIMIT_CHANGE"`·`"USER"`를 문자열 상수로 따로 둔다(→ `AuditActions`로 옮김, A6).
- 003 관리자 API: 주제(`/admin/topics`), 포털 추천·제외·글 확인(`/admin/portal/**`), 설정(`/admin/settings`), 릴리스 노트 9개(`/admin/release-notes/**`: 목록·만들기·조회·수정(`baseRevisionNo`)·게시·게시 중단·삭제·미리보기·수정본 목록·수정본), 회원별 블로그 한도(`PATCH /admin/users/{id}/blog-limit`). 오류 코드 `RELEASE_NOTE_*` 5개는 front `errorCodes.ts`·`errors.json`에도 있다.
- 블로그 관리 API(`manage/controller/ManageController`): 대시보드(`DashboardResponse`: 임시저장 수, 최근 글 5, 7일 새 댓글 수·최근 5, 7일 새 방명록 수·최근 5(004), 방문자(004)), 글 목록(상태·공개 범위·카테고리·`q`), 일괄 작업(`BulkAction`: `CHANGE_VISIBILITY`·`MOVE_CATEGORY`·`DELETE`·`NOTICE`·`UNNOTICE`), 댓글 목록. 모두 `BlogAccess.requireOwnedActiveBlog`(주인 아니면 403 `FORBIDDEN`). → FR-100·101과 US1 AS2~AS4는 이미 구현됨.
- robots: `seo/controller/RobotsController`가 `/admin`·`/manage`·`/*/manage` 등을 `Disallow`(002·003).
- 예약어: `blog/ReservedHandles.NAMES`(코드 상수, `Set`이라 순서 없음).
- 서비스 설정 값: `legal/LegalProperties.termsVersion`, `media/MediaProperties`(`maxSize`·`tempQuota`·`tempTtl`·`maxPixels`·`allowedTypes`), `blog/BlogsProperties.defaultMaxPerMember`.
- 정기 작업: `@Scheduled(cron = "${blog.jobs.*}")` 방식(`TrashPurgeJob` 03:30, `PrivacyPurgeJob` 04:00, `NotificationPurgeJob` 04:15, `PostStatsPurgeJob` 04:45).
- 글 제목 전문 검색: `common/persistence/MySqlFullTextFunctions`의 `match_title`(→ `ft_posts_title`), 시험은 `support/MySqlRepositoryTest`(환경 변수가 있을 때만, Testcontainers 없음).

**front**
- 콘솔: `routes/admin/layout.tsx`(003, `requireAdmin` + `privatePageMeta` noindex), `admin/links.ts`의 `ADMIN_MENU` 4개(주제·포털 추천·포털 제외·포털 설정), `routes/admin/index.ts`가 `/admin` → `/admin/topics` 리다이렉트("대시보드는 006"), `admin/access.server.ts`(`requireAdmin`, backend 404 → 화면 404). **릴리스 노트 관리 화면이 없다**(003 결정 4번).
- 블로그 관리: `routes/manage/layout.tsx`(001, 주인만·404, 블로그 전환 — 같은 하위 경로 유지, `last_blog` 쿠키), `MANAGE_MENU`가 **레이아웃 파일 안에** 있고 9개 모두 `available: true`(대시보드·글·카테고리·댓글·방명록·꾸미기·통계·설정·피드), `routes/manage-entry.ts`(`/manage` → 최근 블로그 또는 `/settings/blogs`).
- 공통 상단 `components/layout/Header.tsx`: 로그인 회원에게 피드·알림·글쓰기·"내 블로그 관리"(`/manage`)·설정·로그아웃. **"시스템 관리" 링크가 없다**(FR-096 미충족).
- 세션: `auth/session.server.ts`의 `SessionUser.role`은 요청마다 한 번 부르는 `GET /me`(DB의 현재 값)에서 온다 → 상단 메뉴 표시도 다음 화면 요청부터 바뀐다(spec US3 AS3의 "다음 토큰 갱신 때"보다 빠름).
- 번역: `i18n/resources.server.ts`가 `locales/*/*.json`을 모두 모은다(파일만 두면 namespace 등록). 콘솔 문구 `admin`, 블로그 관리 `manage`.
- 004 통계 막대 그래프 `components/manage/VisitorChart.tsx`(SVG, 라이브러리 없음).
- E2E: `tests/e2e/support/backend.ts`의 `requireBackend()`·`requireAdmin()`(E2E_ADMIN_EMAIL·PASSWORD), `requirePortalTestSettings()`·`requireGuestTestSettings()`. CI `ci.yml` `e2e-backend`와 `e2e.yml`(nightly)이 일회용 MySQL·backend를 띄우고 `scripts/e2e-provision-admin.sh`로 SUPER_ADMIN 계정을 만든다. Playwright 프로젝트 `e2e`·`portal`(workers 1). `portal-us4-admin.spec.ts`가 콘솔을 쓴다.

## A1. 006의 범위: 이미 있는 것과 남은 것 (spec 머리말)
- **Decision**: 아래 대조표대로 006은 "남은 것"만 만든다. 다른 스펙의 메뉴는 기능을 만들지 않고 메뉴 정의의 자리·순서·공개 여부만 맞춘다.

  | spec 항목 | 상태 | 006의 일 |
  |---|---|---|
  | FR-096 별도 레이아웃·상단 진입 | 레이아웃 둘 다 있음, 상단 "시스템 관리" 없음 | 상단 링크(US2) |
  | FR-097 주인만·관리자만·404·요청마다 권한 | 둘 다 구현됨 | 행렬 테스트로 강제(US1 AS5, SC-015) |
  | FR-098 noindex | meta·robots 있음 | `X-Robots-Tag` 보강(기반) |
  | FR-099 블로그 관리 메뉴 | 001·002·004 메뉴 있음(004-rest가 백업·차단 추가 중) | 메뉴 정의를 `manage/links.ts` 한 곳으로, FR-099 순서, 미구현(트랙백 005, 외부 블로그 007) 숨김 |
  | FR-100 블로그 관리 대시보드 | 001+004로 완성 | E2E 확인만 |
  | FR-101 일괄 작업 | 001 구현 | E2E 확인만 |
  | FR-102 콘솔 메뉴 | 003 메뉴 4개 | FR-102 순서 메뉴 정의, 대시보드·콘텐츠 관리·예약어·서비스 설정·관리자 권한·작업 기록·릴리스 노트 화면. 회원·신고·스팸(005)·외부 블로그(007)는 자리만 |
  | FR-103 콘솔 대시보드 | 없음 | API·화면(US2) |
  | FR-104 회원 관리 | 005 계획(검색·상세·정지, 최근 로그인·블로그 수/한도 포함) | 없음(005). 006은 회원 상세에 "관리자 권한" 영역(US3) |
  | FR-105 권한 단계·부여·회수 | 값과 첫 지정만 있음 | 관리자 목록·부여·회수(US3) |
  | FR-106 작업 기록 | 쓰기만 있음 | 조회 API·화면, 1년 정리, 누락 강제 테스트(US3) |
  | FR-160 블로그 한도 | API 003, 화면 005 계획 | 서비스 설정 화면에 기본값 표시(US2) |
  | FR-167·168 릴리스 노트 | API 003 | 관리 화면(US4) |
- **Rationale**: spec 머리말이 "블로그 관리 뼈대와 001 메뉴는 001과, 콘솔 뼈대와 주제·큐레이션 메뉴는 003과, 나머지 메뉴는 각 기능 스펙과 함께"를 정했다. 같은 기능을 두 스펙이 만들면 충돌한다.
- **Alternatives**: 006이 회원 관리(FR-104) 화면까지 맡음(005 계획 T037·T046·T055·T061과 중복, 정지와 같은 화면이라 005가 맡는 것이 자연스러움).

## A2. 메뉴 정의와 "아직 구현되지 않은 스펙의 메뉴는 숨긴다" (FR-099, FR-102)
- **Decision**:
  - 콘솔: `app/admin/links.ts`의 `ADMIN_MENU`를 FR-102 표 순서의 항목 13개로 바꾸고 항목마다 `spec`(출처)과 `available`(boolean 상수)을 둔다. 레이아웃은 `available`만 그린다. 006 머지 시점의 값: 대시보드·주제·포털(추천·제외·설정 3개를 "포털 관리" 묶음 아래)·콘텐츠 관리·예약어·서비스 설정·관리자 권한·작업 기록·릴리스 노트는 true, 회원 관리·신고 관리·스팸 방어(005)·외부 블로그 관리(007)는 false. 005·007이 머지될 때 그 PR이 자기 항목을 true로 바꾼다(005 T060·T061·T082가 이미 이 파일을 고치게 되어 있음).
  - 블로그 관리: `MANAGE_MENU`를 `routes/manage/layout.tsx`에서 `app/manage/links.ts`로 옮기고 FR-099 표 순서(대시보드, 글, 카테고리, 댓글, 방명록, 블로그 설정, 꾸미기, 피드 설정, 통계, 받은 트랙백, 백업, 차단 목록, 외부 블로그)로 맞춘다. 받은 트랙백(005)·외부 블로그(007)는 false, 백업·차단(004-rest)은 004 머지 상태를 그대로 따른다.
  - 콘솔 메뉴 묶음: 화면 폭이 좁을 때를 위해 "운영"(대시보드·회원·콘텐츠·신고·스팸), "포털"(주제·추천·제외·포털 설정·외부 블로그), "서비스"(예약어·서비스 설정·관리자 권한·작업 기록·릴리스 노트) 세 묶음 제목을 둔다(항목 순서는 FR-102 그대로).
  - 숨긴 메뉴의 경로는 `routes.ts`에도 없으므로 주소로 들어가면 001 `*` 라우트의 404다(콘솔 레이아웃의 404와 같은 모양).
  - 블로그 관리 대시보드(FR-100 "아직 구현되지 않은 스펙의 항목은 숨긴다")는 004까지 모두 구현되어 숨길 항목이 없다. 확인만 한다.
- **Rationale**: 런타임 기능 플래그는 설정·캐시·시험 조합을 늘린다. 스펙은 PR 단위로 머지되므로 코드 상수가 가장 단순하고, 메뉴 정의가 한 파일이면 메뉴 순서 시험이 한 곳에서 끝난다.
- **Alternatives**: backend가 사용 가능한 메뉴 목록을 주는 API(front만의 관심사에 API 추가), 메뉴를 각 스펙이 자기 위치에 추가(지금처럼 순서가 스펙 머지 순서를 따름 — FR-099·102 표 순서와 어긋남).

## A3. 콘솔 대시보드 (FR-103)
- **Decision**:
  - API `GET /api/v1/admin/dashboard` → `{ today: { signups, publishedPosts, comments }, totals: { members, blogs, publicPosts }, pendingReports: number | null, trend: [{ date, signups, publishedPosts }] × 7, timeZone, generatedAt }`.
  - 정의: 오늘 = 요청한 관리자의 `users.time_zone`(001 FR-153) 기준 오늘 0시부터 지금까지. 가입자 = 그 기간 `users.created_at`(탈퇴 포함, 가입 사건 수). 발행 글 = `posts.published_at`(최초 발행 시각)이 그 기간인 글(공개 범위·지금 상태 무관, "발행 사건 수"). 댓글 = `comments.created_at`이 그 기간인 댓글(비회원 포함, 지금 상태 무관). 전체 회원 = `users.status = ACTIVE`, 전체 블로그 = `blogs.status = ACTIVE`, 공개 글 = `status = PUBLISHED AND visibility = PUBLIC`(001 노출 매트릭스의 "목록에 나오는 글"과 같은 기준이 아니라 단순 상태 기준 — 정지 회원 글도 셈, 결정 표 6번). 추이 = 오늘 포함 7일, 빈 날은 0.
  - 쿼리: 가입 7일치 `created_at` 1회, 발행 7일치 `published_at` 1회(날짜 묶기는 애플리케이션에서 관리자 시간대로), 오늘 댓글 수 1회, 전체 수 3회 → 6회. 처리 대기 신고는 `PendingReportCounter.count()`(005 구현, `idx_reports_status_created`), 005 전에는 `NoPendingReportCounter`가 `null`(화면에서 카드 숨김) — 003 `BlogPenaltyPolicy`·`NoBlogPenaltyPolicy`와 같은 방식(`@ConditionalOnMissingBean`).
  - 캐시: Caffeine, 키 = 시간대 ID, TTL `blog.admin.dashboard-cache-ttl`(기본 5분, 0이면 캐시 끔 — E2E용), 최대 50항목. 응답의 `generatedAt`으로 화면에 "n분 전 기준"을 보여준다. 처리 대기 신고 수만은 캐시하지 않고 매번 센다(인덱스가 있고, 005 콘솔 메뉴 배지와 숫자가 다르면 혼란).
  - 화면 `/admin`(index): 카드 7개(오늘 3, 전체 3, 처리 대기 신고 — 005 전에는 없음) + 7일 막대(가입·발행 두 계열, 004 `VisitorChart`를 `components/charts/DailyBarChart.tsx`로 일반화). 처리 대기 신고 카드는 `/admin/reports`로 링크(005).
- **Rationale**: spec이 5분 지연을 허용한 것은 캐시를 전제한 것이다. 시간대별 키는 관리자 수(수 명)만큼만 생긴다. 상태별로 다른 "공개 글" 정의(노출 매트릭스 전체)는 블로그·작성자 JOIN이 늘어 대시보드 목적(규모 감각)에 비해 무겁다.
- **Alternatives**: 일별 집계 테이블(스키마 변경), 서비스 시간대 하나(UTC)로 고정(운영자가 한국 시간 기준으로 보기 어려움), `@Cacheable`(시간대 키·TTL 0 처리를 위해 결국 직접 설정이 필요 — Caffeine 직접 사용이 003·005와 같음).

## A4. 콘텐츠 관리 검색 (FR-102 "글·댓글 검색, 숨김·복구", 005 결정 27·32번)
- **Decision**:
  - 화면 `/admin/contents/{posts|comments|guestbook}`(탭 3개). 숨김·해제 버튼은 005의 `PUT·DELETE /admin/contents/{type}/{id}/hidden`을 그대로 부른다(005 머지 후에만 보임). 005의 `/admin/contents/hidden-posts` 화면은 `/admin/contents/posts?status=HIDDEN`으로 흡수하고 옛 주소는 리다이렉트(005 T060과 머지 순서를 맞춤, 결정 표 10번).
  - 글 검색 `GET /admin/contents/posts?q=&handle=&authorId=&status=&visibility=&page=`: `q`는 제목 전문 검색(002 `match_title`, `ft_posts_title`, 002 검색어 규칙 2~100자), `handle`은 블로그 정확 일치, `authorId`는 회원 ID(005 회원 상세에서 링크), `status`·`visibility`는 001·004·005 값. 아무 조건이 없으면 최신 생성순(PK 역순). 응답: id, title, blog(handle·title), author(userId·nickname·status), status, visibility, publishedAt, createdAt, commentCount. **본문·요약·비밀번호 해시는 응답에 없다**(FR-104 "비공개 글 본문은 볼 수 없다" — 공개 글 본문은 글 주소로 보면 되므로 목록에도 넣지 않음). 휴지통(DELETED) 글도 찾을 수 있다(신고 대상 추적).
  - 댓글 검색 `GET /admin/contents/comments?postId=&authorId=&handle=&status=&q=&page=`, 방명록 `GET /admin/contents/guestbook-entries?handle=&authorId=&status=&q=&page=`: 범위(글·작성자·블로그) 없이는 최신순(PK 역순)과 `status` 거르기만, `q`(내용 부분 일치 `LIKE`)는 **범위가 하나 이상 있을 때만**(없으면 400 `VALIDATION_FAILED` field `q` `INVALID` + `params.reason: "SCOPE_REQUIRED"`, 결정 표 9번). 응답 내용은 앞 200자. **비밀 댓글·비밀 방명록은 `content: null`, `secret: true`**(관리자는 신고 화면에서만 내용을 본다 — 005 결정 6번은 "신고된 것"에 한정, 결정 표 8번). 비회원 작성은 `guestName`만(IP 없음).
  - 숨긴 댓글·방명록 전체(`status=HIDDEN`, 범위 없음)는 `comments.status`·`guestbook_entries.status` 인덱스가 없어 `LIMIT` 훑기(선택 제안 3·4).
  - 쿼리: 목록 1 + 개수 1(블로그·작성자는 같은 쿼리의 JOIN, 댓글은 글 제목·블로그 handle까지 JOIN). 제목 전문 검색만 MySQL 전용이라 그 조건은 `@MySqlRepositoryTest` 1개, 나머지 조건은 H2 `@JpaRepositoryTest` + `QueryCounter`.
- **Rationale**: 관리자는 신고·문의를 받으면 "이 블로그의 글", "이 회원의 댓글"로 좁혀 찾는다. 범위 없는 본문 `LIKE '%q%'`는 큰 테이블 전체 훑기라 막고, 댓글에는 FULLTEXT 인덱스가 없다(스키마 변경 회피). 비밀 글은 작성자가 주인에게만 보이려 한 것이라 신고 같은 이유 없이 관리자 목록에 펼치지 않는다.
- **Alternatives**: 댓글 FULLTEXT 인덱스 추가(필수 범위 밖이라 제안하지 않음 — 필요해지면 선택 DDL로), 글 본문 전문 검색(`ft_posts_title_content`, 관리자에게 비공개 본문 검색 결과로 내용을 추측하게 함 — FR-104 취지에 어긋남).

## A5. 예약어와 서비스 설정 (FR-102 "예약어", "서비스 설정", FR-160)
- **Decision**: `GET /api/v1/admin/reserved-handles` → 정렬한 문자열 배열(`ReservedHandles.NAMES`), `GET /api/v1/admin/service-settings` → `{ termsVersion, blogs: { defaultMaxPerMember }, media: { maxFileSize, maxPixels, tempQuota, tempTtl, allowedTypes }, admin: { auditRetentionDays, dashboardCacheTtl } }`(바이트는 숫자, 기간은 ISO-8601). 둘 다 읽기 전용이고 화면에 "운영 설정 프로퍼티로만 바꿉니다(`blog.blogs.default-max-per-member` 등)" 안내와 프로퍼티 이름을 함께 보여준다. 비밀 값(`blog.crypto.*`, JWT, 메일 비밀번호)은 넣지 않는다.
- **Rationale**: spec이 "코드 상수", "읽기 전용"을 정했다. 프로퍼티 이름을 보여주면 운영자가 어디를 바꿔야 하는지 안다.
- **Alternatives**: actuator `env` 노출(비밀 값 노출 위험, 관리자 API 공통 규칙 밖).

## A6. 작업 기록 조회 (FR-106, US3 AS1·AS2)
- **Decision**:
  - `GET /api/v1/admin/audit-logs?from=&to=&adminId=&action=&targetType=&targetId=&targetKey=&page=&size=` → Page<{ id, admin: { userId, nickname }, action, targetType, targetId, targetKey, before, after, reason, createdAt }>. `from`·`to`는 날짜(`YYYY-MM-DD`, 관리자 시간대로 해석), 생략하면 최근 7일, 범위는 최대 366일(넘으면 400 field `to` `INVALID`). `action`은 여러 개(쉼표). 새 것 먼저(created_at DESC, id DESC). 쿼리 2회(목록 + 개수, 관리자 닉네임 JOIN).
  - `GET /api/v1/admin/audit-logs/{id}` → 위 + `requestIp`(**SUPER_ADMIN에게만 복호화 값**, ADMIN에게는 `null`). `GET /api/v1/admin/audit-logs/actions` → 알려진 작업 종류 코드와 대상 종류(`AuditActions.ALL`·`TARGETS`, 필터 선택지).
  - 수정·삭제 API는 만들지 않는다(매핑 행렬 테스트가 `/admin/audit-logs/**`에 GET 외 매핑이 없음을 확인).
  - `AuditActions`를 006 data-model `action` 표 전체의 단일 목록으로 만든다: 003 값 + 001 `USER_BLOG_LIMIT_CHANGE`(지금 `AdminUserService`의 문자열을 옮김) + 006 `ROLE_GRANT`·`ROLE_REVOKE`. 005·007 값은 그 스펙이 더하고, `ALL`은 리플렉션 없이 상수 배열로 둔다(시험이 public static 상수와 `ALL`이 같은지 확인).
  - 화면 `/admin/audit-log`: 필터(기간, 관리자 — 관리자 목록에서 선택, 작업 종류 — 묶음별 선택, 대상 종류·ID), 표(시각·관리자·작업·대상·사유), 행을 펼치면 변경 전후 값을 키별로 나란히(`JsonDiff`, 값은 JSON 문자열 그대로, 번역 안 함). 작업 종류 이름은 `audit` namespace(코드 → 문구, 없으면 코드 그대로). 대상이 회원이면 회원 상세(005), 릴리스 노트면 편집 화면 링크.
  - 회원 상세(005)와 릴리스 노트 편집 화면에 "이 대상의 작업 기록" 링크(`?targetType=&targetId=`).
- **Rationale**: 인덱스 4개(006 data-model)가 기간·관리자·작업·대상 거르기에 맞춰져 있다. 요청 IP는 개인정보라 사고 조사 권한(최고 관리자)으로 좁힌다.
- **Alternatives**: IP를 아무에게도 보여주지 않음(저장 이유가 사라짐), 동작 목록을 front에만 둠(backend·front 목록이 어긋나도 알 수 없음 — `/actions` API와 E2E 비교로 맞춤).

## A7. 작업 기록 1년 보관 정리 (FR-106, 006 data-model)
- **Decision**: `admin/audit/AdminAuditPurgeJob`(`@Scheduled(cron = "${blog.jobs.audit-purge-cron:0 15 5 * * *}")`, 다른 정리 작업과 겹치지 않는 05:15)이 `created_at < now - blog.admin.audit-retention`(기본 365일)인 행의 id를 `purgeBatchSize`(001 `blog.jobs.purge-batch-size`, 500)씩 모아 `DELETE ... WHERE id IN (...)`을 트랜잭션마다 반복한다. 삭제는 `AdminAuditPurgeRepository`(QueryDSL `JPAQueryFactory.delete`, 엔티티 `@Immutable`과 무관한 벌크 DELETE)에만 두고 `AdminAuditLogRepository`에는 여전히 삭제가 없다. 건수만 로그. 보관 기간은 30일 미만이면 기동 실패(실수로 기록을 지우는 것을 막음).
- **Rationale**: 001 `TrashPurgeJob`·`PrivacyPurgeJob`과 같은 방식. id 묶음 삭제는 H2·MySQL에서 같게 동작한다(`DELETE ... LIMIT`의 방언 차이 회피).
- **Alternatives**: MySQL 파티션·이벤트 스케줄러(Crowfoot 스키마 밖, 시험 불가).

## A8. 작업 기록 누락 0건 강제 (SC-017)
- **Decision**: `integration/AdminAuditCoverageIntegrationTest`(`@SpringBootTest`, H2)가 `RequestMappingHandlerMapping`에서 `/api/v1/admin/**`의 **GET이 아닌 매핑 전체**를 읽어, 테스트 안의 표(매핑 → 요청 픽스처 → 기대 `action`)와 비교한다. 표에 없는 매핑이 있으면 실패("새 관리자 변경 API는 이 표에 행을 더한다"). 표의 각 행은 SUPER_ADMIN으로 실제 요청을 보내 성공한 뒤 `admin_audit_logs`에 그 `action` 행이 1개 이상 늘었는지 확인한다. "값이 같아 바뀐 것이 없는 요청"(예: 블로그 한도를 같은 값으로)은 기록하지 않는 현재 규칙을 유지하고, 표에는 값이 바뀌는 요청을 둔다. 미리보기(`POST /admin/release-notes/preview`)처럼 상태를 바꾸지 않는 POST는 표의 "기록 없음" 목록에 이유와 함께 둔다.
- **Rationale**: SC-017은 100%다. 스펙마다 관리자 API가 늘어나므로(005 16개, 007) 목록을 매핑에서 읽어야 빠짐을 잡는다. 005·007은 자기 API를 이 표에 더한다(tasks 의존 표).
- **Alternatives**: AOP로 모든 관리자 변경 요청을 자동 기록(변경 전후 값을 알 수 없어 FR-106의 "변경 전후 값"을 못 채움, 실패한 요청과 구분 어려움).

## A9. 관리자 권한 부여·회수 (FR-105, US3 AS3, Edge Cases)
- **Decision**:
  - `PUT /api/v1/admin/users/{id}/role` `{ role: "USER" | "ADMIN" | "SUPER_ADMIN" }` → 200 `{ userId, nickname, role, status }`. **최고 관리자만**: 서비스가 `SuperAdminGuard.requireSuperAdmin(requesterId)`로 DB의 현재 권한을 다시 확인하고 아니면 403 `FORBIDDEN`(관리자에게는 콘솔이 이미 드러나 있으므로 404가 아님 — 005 정지 규칙과 같음).
  - 규칙: 대상이 ACTIVE가 아니면 409 `USER_NOT_ACTIVE`(정지 회원에게 권한을 주지 않음; 회수는 상태와 무관하게 허용), 자기 자신은 422 `CANNOT_CHANGE_OWN_ROLE`(실수로 마지막 권한을 잃는 것 방지 — 다른 최고 관리자가 바꿔야 함), SUPER_ADMIN을 낮추는 변경은 트랜잭션 안에서 `SELECT id FROM users WHERE role = 'SUPER_ADMIN' AND status = 'ACTIVE' FOR UPDATE`로 잠근 뒤 대상을 빼고 1명 이상 남지 않으면 409 `LAST_SUPER_ADMIN`(006 data-model 규칙). 같은 값이면 변화·기록 없이 200.
  - 작업 기록: 권한이 올라가면 `ROLE_GRANT`, 내려가면 `ROLE_REVOKE`, `target_type = USER`, before/after `{ role }`.
  - 반영: 001 `AdminAccessFilter`가 요청마다 DB를 읽으므로 회수된 관리자는 다음 관리자 API 요청부터 404, front 콘솔도 다음 화면 요청부터 404(`/me` role). 갱신 토큰 폐기는 하지 않는다(일반 회원으로서의 로그인은 유지).
  - 관리자 목록 `GET /api/v1/admin/admins` → [{ userId, nickname, role, status, createdAt }](ADMIN·SUPER_ADMIN, 정지 포함, `idx_users_role_status`, 쿼리 1회). 화면 `/admin/admins`: 목록, 최고 관리자에게만 "권한 바꾸기"(선택 + 확인), 일반 관리자에게는 읽기 전용. 부여는 005 회원 상세(`/admin/users/:id`)의 "관리자 권한" 영역에서(회원 찾기는 005 검색) — 005 머지 전에는 `/admin/admins`에 "회원 번호로 부여" 입력을 둔다(005 머지 후 제거하지 않고 둠, 결정 표 15번).
  - `SuperAdminGuard`는 005 정지(마지막 최고 관리자 정지 거부)와 함께 쓴다. 먼저 머지하는 스펙이 만든다.
- **Rationale**: spec Edge Cases "최고 관리자는 최소 1명", AS3 "다음 요청부터". 잠금은 두 최고 관리자가 서로를 동시에 낮추는 경쟁을 막는다(`AdminRoleIntegrationTest`).
- **Alternatives**: 부여·회수를 POST 두 개로(`/grant`, `/revoke`) — 세 단계 값을 바로 정하는 PUT 하나가 단순(결정 표 14번, contracts "설계 규칙과 다르게 만든 것"은 아님: 자원의 한 필드를 통째로 바꾸는 PUT). 자기 강등 허용(마지막이 아니면) — 실수 방지가 더 중요.

## A10. 접근 규칙 강제: 관리자 API 404, 블로그 관리 API 주인만 (SC-015, US1 AS5, US2 AS2)
- **Decision**:
  - `integration/AdminEndpointAccessMatrixTest`(`@SpringBootTest`, H2, MockMvc): `/api/v1/admin/**`의 모든 매핑(메서드 × 경로, 경로 변수는 숫자 1 또는 고정 문자열로 채움)을 비로그인·일반 회원·정지된 관리자·권한이 회수된 관리자(토큰은 유효)로 호출해 모두 404 `NOT_FOUND`(공통 틀)인지 확인. 관리자로 호출하면 404 `NOT_FOUND`가 아닌 응답(200·400·404의 다른 코드 등)인지 확인해 "필터가 아니라 컨트롤러가 응답했다"를 보인다. 최고 관리자 전용 매핑(권한 변경)은 ADMIN에게 403.
  - `integration/ManageEndpointAccessMatrixTest`: `/api/v1/blogs/{handle}/manage/**`와 블로그 주인 전용 API(001 `PATCH /blogs/{handle}`, 카테고리 변경, 004 사이드바·백업·차단 등 — 표로 관리)의 모든 매핑을 비로그인 401, 다른 회원 403 `FORBIDDEN`, 삭제된 블로그 주인 404로 확인. 표에 없는 `/manage/**` 매핑이 있으면 실패.
  - front는 001·003 `requireOwnedBlog`·`requireAdmin`이 이미 404를 주므로 단위 시험은 그대로 두고 E2E에서 화면 404를 확인한다.
- **Rationale**: "모든 관리자 API 권한 테스트 기준"을 매핑 목록에서 자동으로 만든다. 005·007이 API를 더해도 같은 시험이 덮는다.
- **Alternatives**: 컨트롤러 시험마다 권한 사례 추가(새 API에서 빠지기 쉬움, `@WebMvcTest`는 실제 필터 구성과 다름).

## A11. 검색 엔진 제외 (FR-098)
- **Decision**: 지금의 `privatePageMeta`(noindex meta, 모든 관리 화면)와 robots.txt `Disallow`(002·003)에 더해, front 서버 미들웨어 `server/middleware/robotsHeader.ts`가 `/admin`, `/admin/**`, `/manage`, `/:handle/manage`, `/:handle/manage/**` 응답(오류·리다이렉트 포함)에 `X-Robots-Tag: noindex, nofollow`를 붙인다. 경로 판단은 첫 조각 `admin`·`manage` 또는 둘째 조각 `manage`(예약어라 블로그 handle과 겹치지 않음).
- **Rationale**: meta는 HTML 응답에만 있다. 404·리다이렉트·JSON(SSR 데이터 요청 `*.data`) 응답에도 붙이려면 헤더가 확실하다. 관리 API(`/api/**`)는 robots.txt `Disallow: /api/`와 `no-store`가 이미 있다.
- **Alternatives**: React Router `headers` export를 화면마다(빠뜨리기 쉬움).

## A12. 상단 "시스템 관리" 링크 (FR-096, US2 AS1)
- **Decision**: `Header.tsx`가 `user.role`이 ADMIN·SUPER_ADMIN이면 "내 블로그 관리" 다음에 "시스템 관리"(`/admin`)를 보인다(`app/admin/roles.ts`의 `isAdmin`). 문구 `common:nav.admin`(4개 언어). 관리자도 "내 블로그 관리"는 그대로(Edge Cases "두 메뉴 모두").
- **Rationale**: `role`은 요청마다 `/me`(DB)에서 오므로 부여·회수가 다음 화면부터 반영된다.

## A13. 릴리스 노트 관리 화면 (FR-167·168, US4)
- **Decision**:
  - 화면: 목록 `/admin/release-notes`(상태 탭 전체·초안·게시, 버전·상태·언어판·수정본 번호·게시 시각, "새 노트"), 만들기 `/admin/release-notes/new`, 수정 `/admin/release-notes/:id`, 수정본 목록 `/:id/revisions`, 수정본 보기 `/:id/revisions/:revisionNo`. 모두 003 관리 API를 그대로 쓴다(backend 변경 없음).
  - 편집기: 버전(처음 게시한 뒤에는 읽기 전용 — `firstPublishedAt`이 있으면 `disabled`, backend도 422 `RELEASE_NOTE_VERSION_LOCKED`), 릴리스 날짜(`type="date"`), 언어 탭 ko·en·ja·zh-CN(ko는 필수 표시, 나머지는 "이 언어판 넣기" 체크 — 빼면 그 언어판 삭제), 탭마다 제목·Markdown 본문(`<textarea>`, 100,000자 표시). JS가 없어도 모든 탭이 한 폼에 있고(탭은 `<details>`/앵커 링크로 열림), 숨은 입력 `baseRevisionNo`.
  - 미리보기: "미리보기" 버튼이 `intent=preview`로 같은 action에 보내 `POST /admin/release-notes/preview` 결과(`contentHtml`·`toc`)를 편집기 옆에 그린다(JS가 있으면 `useFetcher`로 화면 이동 없이, 없으면 입력 값을 유지한 채 다시 그림). backend가 살균한 HTML이므로 `dangerouslySetInnerHTML` 허용 목록(001 R27, ESLint 예외)에 `components/admin/MarkdownPreview.tsx`를 더한다. 독자 화면과 같은 스타일 클래스(003 `updates` 본문)를 쓴다.
  - 충돌(409 `RELEASE_NOTE_REVISION_CONFLICT`): 입력 값을 지우지 않고 "다른 관리자가 먼저 저장했습니다. 최신 내용을 다시 불러온 뒤 고쳐 주세요"와 "최신 내용 열기"(새 탭 링크) 안내(AS5). 그 밖의 오류(`RELEASE_NOTE_VERSION_TAKEN`, 형식 `INVALID_FORMAT`, `contents.ko` `REQUIRED`)는 필드 옆에(003 `AdminFormErrors`).
  - 게시·게시 중단·삭제: 편집 화면의 별도 폼(`intent=publish|unpublish|delete`, 확인 대화상자는 JS가 있을 때 `confirm`, 없으면 확인 체크박스). 삭제 버튼은 `firstPublishedAt`이 없을 때만 보임(backend도 409 `RELEASE_NOTE_ONCE_PUBLISHED`). 게시 상태면 "독자에게 보기"(`/updates/v{version}`) 링크.
  - 수정본: 번호·수정한 관리자·시각·당시 상태 목록, 수정본 보기는 언어판별 제목·Markdown 원문(읽기 전용)과 "이 내용으로 편집기 채우기"(편집 화면으로 값을 넘겨 다시 저장하면 새 수정본 — 되돌리기 API를 따로 만들지 않음, 결정 표 24번).
- **Rationale**: 003이 API·검증·충돌·수정본을 모두 만들었으므로 006은 화면만. 미리보기가 독자 화면과 같은 변환(같은 `ReleaseNoteRenderer`)이라 FR-167 "독자 화면과 같은 변환 결과"를 만족.
- **Alternatives**: 클라이언트 Markdown 변환(살균 규칙이 backend와 달라짐), 되돌리기 API 추가(spec에 없음).

## A14. E2E와 CI (헌법 III, 소유자 지시 "E2E는 CI에서 실제로 돈다")
- **Decision**:
  - 새 시험 도구(`tests/e2e/support/backend.ts`): `requireAdminTestSettings()`(`E2E_ADMIN_TEST_SETTINGS=1`이 아니면 건너뜀 — 대시보드 캐시를 끈 backend 표시), `adminRequest(playwright)`(005 T003과 같은 함수, 먼저 머지하는 쪽이 만듦), `setRole(request, userId, role)`, `myUserId(request)`.
  - Playwright 프로젝트 `admin`(`testMatch: /admin-.*\.spec\.ts$/`, `dependencies: ["portal"]`(005 머지 후에는 `["moderation"]`도), `workers: 1`): 권한을 바꾸고 릴리스 노트를 게시하는 등 전역 상태를 바꾸므로 다른 시나리오가 끝난 뒤 한 번에 하나씩. `e2e` 프로젝트의 `testIgnore`에 `admin-` 추가.
  - workflow: `blog-front/.github/workflows/ci.yml` `e2e-backend`와 `e2e.yml`의 "Start backend" `env`에 `BLOG_ADMIN_DASHBOARD_CACHE_TTL: 0s`, Playwright 단계 `env`에 `E2E_ADMIN_TEST_SETTINGS: "1"`. 관리자 계정은 003 것(`E2E_ADMIN_EMAIL`, SUPER_ADMIN) 재사용. 권한 시험의 두 번째 관리자는 시나리오 안에서 새 회원을 가입시키고 CI 관리자가 API로 ADMIN을 준다.
  - 위험 관리: "마지막 최고 관리자" 시험은 CI 관리자가 자기 자신을 낮추는 요청으로 하지 않고(422 `CANNOT_CHANGE_OWN_ROLE`로 먼저 막힘) 단위·통합 시험(`AdminRoleServiceTest` T043, `AdminRoleIntegrationTest` T045)에서만 확인한다. E2E가 실패해도 CI 관리자 권한이 바뀌지 않게 한다.
  - 릴리스 노트 E2E 버전은 실행마다 겹치지 않게 `900.{실행 시각 분}.{난수}`(게시하면 지울 수 없음 — CI DB는 일회용이지만 로컬 반복 실행 대비). 게시하면 회원 배너가 생기므로 `admin` 프로젝트(마지막)에서만.
  - `portal-us4-admin.spec.ts`의 "`/admin`이 `/admin/topics`로 간다" 단정을 "`/admin`이 대시보드"로 고친다.
- **Rationale**: 005 M18과 같은 방식. 시험 표시 변수가 없으면 건너뛰므로, CI 변수를 같은 PR에서 넣고 tasks.md T071(CI 확인)에서 skipped 0건을 확인한다.
