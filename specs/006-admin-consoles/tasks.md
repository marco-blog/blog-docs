---
description: "006 관리 화면 작업 목록"
---

# Tasks: 관리 화면 (시스템 관리자 콘솔과 블로그 관리)

**Input**: `/specs/006-admin-consoles/`의 설계 문서 (spec.md, plan.md, research.md, data-model.md, contracts/api.md, contracts/routes.md, quickstart.md)

**Prerequisites**: 001-blog-core·002-discovery-feeds·003-portal 구현 완료(blog-backend·blog-front main), **004-blog-features가 main에 머지된 뒤 시작**(004 Phase 5~8은 `feat/004-rest`에서 구현 중 — 블로그 관리 메뉴·글 필터를 함께 고침), **005와는 병렬 가능**(005에 기대는 작업은 "(005 머지 후)"로 표시, 아래 "004·005·003 의존"), plan.md, spec.md, research.md, data-model.md, contracts/, 헌법 v2.5.0, [api-guidelines.md](../../api-guidelines.md), [db/README.md](../../db/README.md)

**Tests**: 헌법 원칙 III(NON-NEGOTIABLE)에 따라 모든 스토리에 테스트 작업이 있고, 각 스토리 안에서 테스트 작업이 구현 작업보다 앞선다. 테스트를 먼저 쓰고 **실패하는 것을 확인한 뒤** 구현한다. backend·front 모두 라인 커버리지 80% 미만이면 빌드가 실패한다. Testcontainers는 쓰지 않는다. MySQL 전용 테스트는 글 제목 FULLTEXT 검색 1개(`@MySqlRepositoryTest`, 002 방식)뿐이고 나머지는 H2 `@JpaRepositoryTest` + `QueryCounter`다.

**Organization**: spec의 사용자 스토리 번호와 우선순위를 그대로 쓴다(US1 블로그 관리 P1, US2 콘솔 운영 P2, US3 작업 기록과 권한 P3, US4 릴리스 노트 P4, 결정 표 1번). 006은 두 관리 화면의 구조 스펙이라 다른 스펙이 이미 만든 메뉴는 만들지 않고 자리·순서·접근 규칙만 맞춘다(research A1). 모든 관리자 API와 블로그 관리 API에 걸리는 규칙(SC-015, SC-017, AS5)은 Spring MVC 매핑 목록을 훑는 행렬 테스트로 강제한다.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: 병렬 가능(다른 파일, 끝나지 않은 작업에 의존하지 않음)
- **[Story]**: 해당 사용자 스토리(US1~US4)
- 경로는 저장소 이름(`blog-backend/`, `blog-front/`)으로 시작한다(blog-docs CLAUDE.md 규칙)
- 작업 번호는 이 스펙 안에서 T001부터 센다(001~005 tasks.md와 별개)
- **(005 머지 후)**: 005의 코드(회원 상세 화면, 숨김 API, 신고 저장소)가 main에 있어야 하는 작업. 그 전에 006을 머지하면 이 작업만 남겨 두고 005 PR이 끝난 뒤 따로 낸다

## Path Conventions

- backend 소스: `blog-backend/src/main/java/net/java21/blog/backend/{domain}/{controller|service|repository|domain|dto|job}/` — 이 스펙의 관리자 API는 003의 `admin/*` 아래 `admin/dashboard`, `admin/content`(검색), `admin/info`, `admin/audit`(조회·정리), `admin/user`(권한), 공용 `admin/SuperAdminGuard`
- backend 테스트: `blog-backend/src/test/java/net/java21/blog/backend/{domain}/...` (Controller `*ControllerTest` = `@WebMvcTest` + `@Import(WebMvcTestSupport.class)` + `@MockitoBean`, Service `*ServiceTest` = Mockito 단위, Repository `*RepositoryTest` = H2 `@JpaRepositoryTest` + `QueryCounter.assertQueryCount`, MySQL 전용은 `@MySqlRepositoryTest`, 시각 고정은 `support/MutableClock`, Caffeine 시각은 `Ticker`, 픽스처는 `support/JpaFixtures`·`support/TestEntities`, 쿠키는 `support/AuthCookies`, 행렬 테스트는 `integration/` 아래 `@SpringBootTest`(H2))
- backend 리소스: `blog-backend/src/main/resources/`
- front: `blog-front/app/` (routes, components, locales, api, admin, manage), 서버 미들웨어 `blog-front/server/middleware/`, 단위 테스트 `blog-front/tests/unit/`, E2E `blog-front/tests/e2e/`(backend 필요 시나리오는 `tests/e2e/support/backend.ts`의 `requireBackend()`, 관리자 시나리오는 `requireAdmin()`, 대시보드 수치 확인은 `requireAdminTestSettings()`)
- 화면 문구는 모두 `blog-front/app/locales/{ko,en,ja,zh-CN}/{namespace}.json` 키로 쓰고 4개 언어를 같은 작업에서 넣는다(원칙 VII). 이 스펙의 새 namespace는 `audit`(파일만 두면 `app/i18n/resources.server.ts`가 모음). 새 오류 코드는 `blog-front/app/api/errorCodes.ts`와 4개 언어 `errors.json`에 함께 넣는다(`tests/unit/i18n/errorCodes.test.ts`).
- backend 오류 코드는 `blog-backend/src/main/java/net/java21/blog/backend/common/error/ErrorCode.java`에 contracts/api.md 표의 이름·HTTP 상태 그대로 더한다.
- 응답 타입은 `blog-front/app/api/models.ts`에 contracts/api.md를 옮겨 적는다.

## 스키마 변경

**필수 DDL 없음.** 006의 테이블(`admin_audit_logs`, `release_notes`, `release_note_contents`, `release_note_revisions`)과 001 `users.role`·`users.time_zone`·`users.max_blogs`, 인덱스(`idx_users_role_status`, `idx_admin_audit_logs_*` 4개, `idx_release_notes_status_version`, 002 `ft_posts_title`)가 Crowfoot 문서 "blog 1.0"(`db/schema-mysql.sql`)에 모두 있다(plan.md "스키마 변경"의 쿼리별 대조표). 새 엔티티 없음(`AdminAuditLog`·`ReleaseNote*`는 003, `User`는 001).

**marco 승인이 필요한 것**: 선택 인덱스 4개(plan.md "스키마 변경"에 정확한 DDL) — `idx_users_created`·`idx_posts_published_at`·`idx_comments_status_created`(대시보드 5분 캐시 계산, 숨긴 댓글 목록), `idx_guestbook_entries_status_created`(숨긴 방명록 목록). 구현은 넷 없이 동작한다. 넣기로 하면 Crowfoot `plan_migration` → **marco 승인** → `apply_migration` 절차로 따로 요청한다. 이 계획 작업에서는 Crowfoot 문서와 DB를 바꾸지 않았다.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: front 번역·타입 틀, E2E 도구와 CI 환경, backend 프로퍼티

- [x] T001 [P] 새 번역 namespace `blog-front/app/locales/{ko,en,ja,zh-CN}/audit.json`(작업 종류 이름 `actions.{CODE}` — 006 data-model `action` 표의 003·001·006 행, 대상 종류 `targets.{TYPE}`, 작업 기록 화면 문구)과 `admin.json`·`manage.json`·`common.json`에 006 키의 뼈대(같은 키 집합, 이후 작업이 채움, `tests/unit/i18n/translations.test.ts`가 4개 언어 키 일치 확인)
- [x] T002 [P] contracts/api.md 006 타입을 `blog-front/app/api/models.ts`에 추가: `AdminDashboard`, `AdminRef`, `AdminPostRow`, `AdminCommentRow`, `AdminGuestbookRow`, `ServiceSettings`, `AuditLogEntry`(+ `requestIp`), `AuditActionList`, `AdminMember`, `UserRole`; 003 릴리스 노트 관리 타입 `AdminReleaseNote`·`AdminReleaseNoteSummary`·`ReleaseNoteWrite`·`AdminRevision`(001 contracts/api.md, 지금 front에 없음)
- [x] T003 [P] E2E 도구 `blog-front/tests/e2e/support/backend.ts`에 추가: `requireAdminTestSettings()`(`E2E_ADMIN_TEST_SETTINGS=1`이 아니면 건너뜀), `adminRequest(playwright)`(관리자 계정으로 로그인한 `APIRequestContext` — 005 T003과 같은 함수, 이미 있으면 재사용), `setRole(request, userId, role)`, `myUserId(request)`(`GET /me`), `uniqueVersion()`(`900.{분}.{난수}` 릴리스 노트 버전); `blog-front/playwright.config.ts`에 `admin` 프로젝트(`testMatch: /admin-.*\.spec\.ts$/`, `dependencies: ["portal"]`(005 머지 후 `"moderation"`도), `workers: 1` — 권한·릴리스 노트 게시 등 전역 상태를 바꿈)와 `e2e` 프로젝트 `testIgnore`에 `admin-` 추가
- [x] T004 [P] CI가 006 E2E를 **실제로 돌리게** workflow 환경을 바꾼다: `blog-front/.github/workflows/ci.yml`의 `e2e-backend` 잡과 `blog-front/.github/workflows/e2e.yml`(nightly)의 "Start backend" `env`에 `BLOG_ADMIN_DASHBOARD_CACHE_TTL: 0s`(주석 "대시보드 수치를 바로 확인, E2E_ADMIN_TEST_SETTINGS=1과 짝"), 두 workflow의 Playwright 단계 `env`에 `E2E_ADMIN_TEST_SETTINGS: "1"`. 관리자 계정(`E2E_ADMIN_EMAIL`·`scripts/e2e-provision-admin.sh`, SUPER_ADMIN)은 003 것 그대로. backend 저장소 `blog-backend/.github/workflows/*`에 E2E가 없음을 확인만 한다
- [x] T005 [P] backend 프로퍼티(contracts/api.md "프로퍼티"): `blog-backend/src/main/java/net/java21/blog/backend/admin/AdminProperties.java`에 `dashboardCacheTtl`(기본 5m, 음수 기동 실패)·`auditRetention`(기본 365d, 30일 미만 기동 실패)(기존 `bootstrapSuperAdminEmail`과 `hasBootstrapEmail()` 유지, 기존 생성자 호출부 정리), `common/job/JobsProperties.java`에 `auditPurgeCron`(기본 `0 15 5 * * *`, 기존 보조 생성자 유지), `blog-backend/src/main/resources/application.yml` 기본값; `AdminPropertiesTest`·`JobsPropertiesTest`에 기본값·잘못된 값 기동 실패

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: 모든 스토리가 쓰는 오류 코드, 작업 종류 목록, 최고 관리자 잠금, 메뉴 정의, 검색 엔진 제외 보강, 관리자 API 접근 행렬(SC-015)

**⚠️ CRITICAL**: 이 Phase가 끝나기 전에는 어떤 스토리도 시작하지 않는다

### Tests for Foundation ⚠️

> 먼저 쓰고 실패를 확인한다

- [x] T006 [P] `blog-backend/src/test/java/net/java21/blog/backend/admin/audit/AuditActionsTest.java`: `AuditActions.ALL`이 클래스의 action 상수(public static String, `TARGET_` 제외) 전부와 같고 중복 없음, `TARGETS`가 `TARGET_*` 상수 전부와 같음, 006 data-model `action` 표의 003·001·006 행(`TOPIC_*` 7개, `CURATION_*` 3개, `PORTAL_EXCLUDE`·`PORTAL_UNEXCLUDE`, `SETTING_CHANGE`, `RELEASE_NOTE_*` 5개, `USER_BLOG_LIMIT_CHANGE`, `ROLE_GRANT`, `ROLE_REVOKE`)이 모두 있음, 모든 값이 `admin_audit_logs.action` 50자·`target_type` 30자 이내 (research A6)
- [x] T007 [P] `blog-backend/src/test/java/net/java21/blog/backend/admin/SuperAdminGuardTest.java`(`@JpaRepositoryTest`): `lockActiveSuperAdminIds()`가 ACTIVE SUPER_ADMIN id만(정지·탈퇴·ADMIN 제외) 돌려주고 쿼리 1회(`FOR UPDATE`는 H2에서도 실행됨), `requireSuperAdmin(userId)`가 DB의 현재 role로 판단(USER·ADMIN·정지된 SUPER_ADMIN이면 403 `FORBIDDEN`, 세션·토큰 값은 보지 않음), `ensureAnotherActiveSuperAdmin(targetId)`가 대상 외 ACTIVE SUPER_ADMIN이 없으면 409 `LAST_SUPER_ADMIN` (006 data-model "001 테이블 변경", research A9)
- [x] T008 [P] `blog-backend/src/test/java/net/java21/blog/backend/integration/AdminEndpointAccessMatrixTest.java`(`@SpringBootTest`, H2, MockMvc, research A10): `RequestMappingHandlerMapping`에서 `/api/v1/admin/**` 매핑 전체(메서드 × 경로, 경로 변수는 숫자 `1`·고정 문자열로 채움, 본문은 `{}`)를 읽어 비로그인·일반 회원·정지된 관리자·권한이 회수된 관리자(유효한 토큰)로 호출하면 모두 404 `NOT_FOUND`(공통 틀, 본문에 관리자 기능 흔적 없음), 관리자(SUPER_ADMIN)로 호출하면 `NOT_FOUND`가 아닌 응답(필터를 통과했음)인지 확인. 매핑이 0개면 실패(경로 오타 방지). 003·005·007이 더한 매핑도 자동으로 포함 (SC-015, US2 AS2, FR-097)
- [x] T009 [P] front 메뉴·헤더 시험: `blog-front/tests/unit/admin/links.test.ts`(ADMIN_MENU가 contracts/routes.md "콘솔 메뉴" 표 순서·묶음, `available`인 항목의 경로가 `app/routes.ts`에 있음, 숨긴 항목(회원·신고·스팸·외부 블로그)의 경로는 없음, `ADMIN_HOME === "/admin"`), `blog-front/tests/unit/manage/links.test.ts`(MANAGE_MENU가 FR-099 표 순서, available 경로가 `routes.ts`의 manage 자식에 있음, 받은 트랙백·외부 블로그 숨김), `blog-front/tests/unit/server/robotsHeader.test.ts`(`/admin`, `/admin/topics`, `/manage`, `/marco/manage`, `/marco/manage/posts.data`, 404·302 응답에도 `X-Robots-Tag: noindex, nofollow`, `/marco`·`/marco/12`·`/updates`·`/api/v1/...`에는 없음)

### Implementation for Foundation

- [x] T010 오류 코드: `blog-backend/src/main/java/net/java21/blog/backend/common/error/ErrorCode.java`에 `CANNOT_CHANGE_OWN_ROLE`(422), 그리고 005가 아직 더하지 않았으면 `LAST_SUPER_ADMIN`(409)·`USER_NOT_ACTIVE`(409); `blog-front/app/api/errorCodes.ts`와 `blog-front/app/locales/{ko,en,ja,zh-CN}/errors.json`에 같은 코드 문구
- [x] T011 작업 종류 목록: `blog-backend/src/main/java/net/java21/blog/backend/admin/audit/AuditActions.java`에 `TARGET_USER`(005와 공유), `USER_BLOG_LIMIT_CHANGE`, `ROLE_GRANT`, `ROLE_REVOKE`, `ALL`(상수 배열을 `List.of`로 — 리플렉션 없음)·`TARGETS`; `admin/user/AdminUserService.java`의 문자열 상수(`ACTION_BLOG_LIMIT`, `TARGET_USER`)를 `AuditActions`로 바꿈(`AdminUserServiceTest` 그대로 통과)
- [x] T012 `blog-backend/src/main/java/net/java21/blog/backend/admin/SuperAdminGuard.java`(`requireSuperAdmin`, `lockActiveSuperAdminIds`, `ensureAnotherActiveSuperAdmin`)와 `admin/user/AdminUserRepository.java`에 `@Lock(PESSIMISTIC_WRITE)` 조회 `findIdsByRoleAndStatus`·`findRoleAndStatusById`(projection) — 005 T055 정지가 먼저 머지되어 같은 일을 하는 코드가 있으면 이 클래스로 합친다
- [x] T013 [P] 메뉴 정의: `blog-front/app/admin/links.ts`(contracts/routes.md "콘솔 메뉴" 표 — `{ key, path, group, spec, available }`, `ADMIN_HOME = "/admin"`, `ADMIN_FEATURES = { contentHide: false }`(005가 true로)), `blog-front/app/manage/links.ts`에 `MANAGE_MENU`(FR-099 순서, `routes/manage/layout.tsx`에서 옮김), `blog-front/app/admin/roles.ts`(`isAdmin(role)`, `isSuperAdmin(role)`, 003 `access.server.ts`의 `ADMIN_ROLES`를 여기서 가져다 씀); `routes/admin/layout.tsx`는 묶음 제목(`admin:nav.groups.*`)과 `available` 항목만, `routes/manage/layout.tsx`는 `MANAGE_MENU` import로 바꿈; 문구 `admin`·`manage` namespace(4개 언어)
- [x] T014 [P] `blog-front/server/middleware/robotsHeader.ts`(경로의 첫 조각 `admin`·`manage` 또는 둘째 조각 `manage`면 `res.setHeader("X-Robots-Tag", "noindex, nofollow")`, 응답 종류와 무관)와 `blog-front/server.ts`·`server/app.ts`(있는 곳)에 React Router 처리기보다 앞에 등록 (FR-098, research A11)

**Checkpoint**: 기반 완료. `./mvnw verify`(행렬 테스트 T008이 003의 관리자 API 전부를 덮음), `npm test -- --coverage` 통과, CI `e2e-backend`가 새 환경 변수로 001~004 E2E를 모두 통과

---

## Phase 3: User Story 1 - 블로그 주인이 내 블로그를 관리한다 (Priority: P1) 🎯 MVP

**Goal**: 회원이 "내 블로그 관리"로 자기 블로그의 관리 대시보드에 들어가 FR-099 순서의 메뉴로 글·카테고리·댓글·설정을 관리하고, 블로그가 여럿이면 상단에서 바꾼다. 다른 회원은 화면·API 모두 거부된다. (대부분 001·004가 만들었고, 006은 메뉴 정의·접근 행렬·E2E로 확인한다 — research A1)

**Independent Test**: 회원으로 로그인 → "내 블로그 관리"(`/{블로그주소}/manage`) 진입 → 대시보드 수치 확인 → 글 관리에서 임시저장 글 찾기 → 카테고리 추가 → 설정에서 블로그 제목 변경 → 블로그 홈에 반영되는지 확인. 다른 회원의 블로그 관리 화면에는 들어갈 수 없는지 확인(quickstart #1~#9).

FR: FR-096, FR-097, FR-098, FR-099, FR-100, FR-101, SC-016

### Tests for User Story 1 ⚠️

- [x] T015 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/integration/ManageEndpointAccessMatrixTest.java`(`@SpringBootTest`, H2, research A10): `RequestMappingHandlerMapping`의 `/api/v1/blogs/{handle}/manage/**` 매핑 전체와 시험 안 표의 블로그 주인 전용 API(001 `PATCH /blogs/{handle}`·카테고리 변경·`DELETE /blogs/{handle}`, 002 피드 설정, 004 사이드바·공지·통계·백업·차단, 005 이후 받은 트랙백)를 비로그인 401 `UNAUTHENTICATED`, 다른 회원 403 `FORBIDDEN`, 삭제된 블로그의 주인 404, 주인 2xx로 확인. 표에 없는 `/manage/**` 매핑이 있으면 실패("새 블로그 관리 API는 이 표에 행을 더한다") (AS5, FR-097)
- [x] T016 [P] [US1] `blog-front/tests/unit/routes/manage.test.tsx`(001)에 추가: 좌측 메뉴가 `MANAGE_MENU` 순서·현재 메뉴 표시, 블로그 전환 링크가 같은 하위 경로(`/marco2/manage/posts`)이고 쿼리는 버림, 블로그 1개면 전환 없음, 관리자 회원에게도 블로그 관리 머리글에 "시스템 관리"가 섞이지 않음(Edge Cases "두 화면은 섞이지 않는다"); `tests/unit/routes/manageDashboard.test.tsx`에 임시저장 수 링크가 `?status=DRAFT`, 최근 글 링크가 발행 전이면 작성 화면(SC-016 경로)
- [x] T017 [P] [US1] E2E `blog-front/tests/e2e/admin-us1-manage.spec.ts`(`requireBackend`): Independent Test 전체(가입 → 블로그 2개 → 글·임시저장 글·댓글 준비 → `/manage` → 대시보드 수치(최근 글·임시저장 수·새 댓글) → 글 관리 상태 "임시저장" + 제목 검색 → 작성 화면, **대시보드 진입부터 작성 화면까지 30초 이하를 `Date.now()`로 측정해 단정**(SC-016) → 카테고리 추가 → 설정 제목 변경 → `/{handle}`에 반영), 일괄 공개 범위 변경·카테고리 이동·삭제·휴지통 복구(AS3), 블로그 전환으로 다른 블로그의 같은 메뉴(AS6), 다른 회원으로 `/{handle}/manage`·`/{handle}/manage/posts` 404 화면과 `GET /api/v1/blogs/{handle}/manage/dashboard` 403(AS5), 응답 헤더 `X-Robots-Tag`·meta noindex(FR-098) (quickstart #1~#9)

### Implementation for User Story 1

- [x] T018 [US1] 글 관리 필터 값 정리: `blog-front/app/routes/manage/posts.tsx`의 상태·공개 범위 선택지를 `blog-front/app/manage/postFilters.ts` 한 곳으로 옮기고 FR-099 "001 data-model의 status·visibility 값" 중 머지된 스펙 몫만(004의 SCHEDULED·PROTECTED는 004-rest가 넣은 값을 옮김, 005의 HIDDEN은 005가 이 파일에 더함); 문구 `manage` namespace
- [x] T019 [US1] 블로그 관리 모바일(폭 360px, spec Assumptions "블로그 관리는 모바일에서도"): `blog-front/app/routes/manage/layout.tsx`의 좌측 메뉴를 좁은 화면에서 접히는 `<details>`(JS 없이 동작)로, 글 관리 표의 일괄 작업 막대를 줄바꿈 가능하게(`blog-front/app/styles` 또는 해당 CSS 모듈) — T068에서 E2E로 확인

**Checkpoint**: US1 Independent Test E2E 통과(CI `e2e-backend`에서 실제로 실행), quickstart #1~#9

---

## Phase 4: User Story 2 - 시스템 관리자가 서비스를 운영한다 (Priority: P2)

**Goal**: 관리자는 상단 "시스템 관리"로 콘솔 대시보드에 들어가 서비스 현황을 보고, FR-102 순서의 메뉴로 주제·포털(003), 콘텐츠 관리, 예약어, 서비스 설정을 다룬다(회원·신고·스팸은 005, 외부 블로그는 007). 관리자가 아니면 화면·API 모두 404다.

**Independent Test**: 관리자 계정으로 `/admin` 진입 → 주제 소분류 추가 → 일반 회원 글쓰기 화면의 주제 선택에 새 소분류가 나오는지 확인. 일반 회원 계정으로 `/admin` 접근이 거부되는지 확인(quickstart #10~#20).

FR: FR-096, FR-097, FR-102, FR-103, FR-104(검색 범위), FR-160(서비스 설정 표시), SC-015

### Tests for User Story 2 (backend) ⚠️

- [x] T020 [P] [US2] `blog-backend/src/test/java/net/java21/blog/backend/admin/dashboard/AdminDashboardQueryRepositoryTest.java`(`@JpaRepositoryTest` + `MutableClock`): 시간대 `Asia/Seoul`·`UTC`에서 "오늘" 경계(현지 0시 직전·직후 가입·발행·댓글), 7일 추이(오래된 날 먼저, 빈 날 0, 현지 날짜로 묶음), 가입은 탈퇴 회원 포함, 발행은 `published_at` 기준(지금 PRIVATE·DELETED여도 셈, 발행 안 한 글 제외), 댓글은 비회원·삭제 포함, 전체 회원 ACTIVE만·블로그 ACTIVE만·공개 글 PUBLISHED+PUBLIC만, 쿼리 6회 이하(`QueryCounter`) (FR-103, research A3)
- [x] T021 [P] [US2] `blog-backend/src/test/java/net/java21/blog/backend/admin/dashboard/AdminDashboardServiceTest.java`와 `AdminDashboardControllerTest.java`: 같은 시간대 두 번째 요청은 저장소를 부르지 않음(캐시), 다른 시간대는 따로, TTL 지나면(Caffeine `Ticker`) 다시 계산, TTL 0이면 매번 계산, `generatedAt`은 계산 시각, `pendingReports`는 캐시하지 않고 매번 `PendingReportCounter`를 부름, 구현 빈이 없으면 `NoPendingReportCounter`로 null; 시간대는 요청한 관리자의 `users.time_zone`; 컨트롤러 응답 모양·`Cache-Control: no-store` (FR-103)
- [x] T022 [P] [US2] `blog-backend/src/test/java/net/java21/blog/backend/admin/content/AdminContentSearchRepositoryTest.java`(`@JpaRepositoryTest`): 글 — `handle`(삭제된 블로그 포함)·`authorId`(그 회원의 모든 블로그)·`status`(DELETED 포함)·`visibility` 조합, 조건 없으면 최신 생성순, select 절에 `content_md`·`content_html`·`content_text`·`summary`·`password_hash`가 없음(Hibernate SQL 로그 또는 projection 타입으로 확인), 쿼리 2회; 댓글 — `postId`·`authorId`·`handle` 범위와 `status`(HIDDEN 포함), 범위 안 `q` 부분 일치, 비밀 댓글 `content` null·`secret` true, 비회원은 `author` null·`guestName`, 내용 200자 자르기, 글 제목·handle JOIN으로 쿼리 2회; 방명록 같은 규칙 (FR-102, FR-104, research A4)
- [x] T023 [P] [US2] `blog-backend/src/test/java/net/java21/blog/backend/admin/content/AdminPostTitleSearchMySqlTest.java`(`@MySqlRepositoryTest`, 002 `MySqlFullTextFunctionsTest` 방식): `q`가 `ft_posts_title`로 제목만 찾고(본문에만 있는 단어는 안 찾음) 다른 조건과 함께 동작, 002 검색어 규칙(2~100자, 낱말 5개 AND)
- [x] T024 [P] [US2] 컨트롤러: `blog-backend/src/test/java/net/java21/blog/backend/admin/content/AdminContentSearchControllerTest.java`(쿼리 바인딩, 범위 없는 `q`는 400 field `q` `INVALID` + `params.reason=SCOPE_REQUIRED`, `q` 길이 400, 잘못된 enum 400, Page 응답), `admin/info/AdminInfoControllerTest.java`(`GET /admin/reserved-handles`가 `ReservedHandles.NAMES`를 정렬한 배열, `GET /admin/service-settings`가 `LegalProperties`·`BlogsProperties`·`MediaProperties`·`AdminProperties` 값 그대로, 응답 문자열에 `crypto`·`secret`·`jwt`·`password`가 없음)

### Tests for User Story 2 (front) ⚠️

- [x] T025 [P] [US2] `blog-front/tests/unit/components/Header.test.tsx`(001)에 추가: 세션 `role`이 ADMIN·SUPER_ADMIN이면 "내 블로그 관리" 다음에 "시스템 관리"(`/admin`), USER·비로그인에는 없음; `tests/unit/routes/admin.test.tsx`(003)를 바꿈: `/admin` index가 리다이렉트가 아니라 대시보드 loader(`GET /admin/dashboard`), 관리자 아님 404, backend 404 `NOT_FOUND`면 404, 메뉴는 묶음 제목과 `available` 항목만 (AS1, AS2, FR-096)
- [x] T026 [P] [US2] `blog-front/tests/unit/routes/adminDashboard.test.tsx`: 카드 6개 값과 `pendingReports`가 null이면 카드 없음·숫자면 `/admin/reports` 링크, 7일 막대(두 계열, 접근성 표 대체), "n분 전 기준"(`generatedAt`, 003 `formatRelativeTime`)과 시간대 표시; `tests/unit/components/DailyBarChart.test.tsx`(004 `VisitorChart` 시험을 옮겨 일반화, 계열 1·2개)
- [x] T027 [P] [US2] `blog-front/tests/unit/routes/adminContents.test.tsx`: `/admin/contents` → `/posts` 리다이렉트, 탭 3개, 검색 폼 값이 쿼리로(`q`·`handle`·`authorId`·`status`·`visibility`·`postId`), 표(글 → 글 주소, 댓글 → `#comment-{id}` 앵커, 비밀 댓글 "비밀 댓글", 비회원 이름), 400 `SCOPE_REQUIRED`면 "블로그·글·작성자 중 하나를 먼저 정하세요", `ADMIN_FEATURES.contentHide`가 false면 숨김 버튼 없음·true면 `intent=hide|unhide`가 005 API(`PUT·DELETE /admin/contents/{type}/{id}/hidden`)를 부르고 오류 문구(`CONTENT_NOT_FOUND`), 페이지 이동
- [x] T028 [P] [US2] `blog-front/tests/unit/routes/adminInfo.test.tsx`: `/admin/reserved-handles` 목록·안내, `/admin/settings` 값(바이트는 "10 MB", 기간은 "365일" 같은 사람이 읽는 형식)과 프로퍼티 이름, 입력·저장 버튼이 없음

### Tests for User Story 2 (E2E) ⚠️

- [x] T029 [P] [US2] E2E `blog-front/tests/e2e/admin-us2-console.spec.ts`(`requireBackend`·`requireAdmin`·`requireAdminTestSettings`): 관리자 상단 "시스템 관리" → `/admin` 대시보드(AS1), 대시보드 수치를 읽고 새 회원 가입·글 발행·댓글 후 다시 읽어 오늘 값이 각각 1 이상 늘었는지(다른 시나리오와 동시에 돌 수 있어 "늘었다"로 단정, AS3), Independent Test(주제 소분류 추가 → 일반 회원 글쓰기 발행 설정 주제 선택에 보임 → 정리로 숨김, AS4), 일반 회원·비로그인의 `/admin`·`/admin/contents/posts`·`/admin/release-notes` 404 화면과 `GET /api/v1/admin/dashboard` 404(AS2, SC-015), 콘텐츠 관리에서 handle·제목으로 방금 쓴 글 찾기, 예약어(`admin` 포함)·서비스 설정 화면 (quickstart #10~#17, #19); `blog-front/tests/e2e/portal-us4-admin.spec.ts`(003)의 "`/admin` → `/admin/topics`" 단정을 "`/admin`은 대시보드, 메뉴의 주제 관리 → `/admin/topics`"로 고침
- [x] T030 [P] [US2] **(005 머지 후)** E2E `blog-front/tests/e2e/admin-us2-members.spec.ts`(`requireBackend`·`requireAdmin`): 회원 관리에서 이메일 전체 주소로 찾기(부분 주소는 결과 없음) → 상세의 가입일·상태·글 수·신고 받은 수 → 블로그 한도 5 → "블로그 2 / 한도 5" → 기본값으로(AS5, AS6, FR-160), 콘텐츠 관리에서 글 숨김 → 비로그인 404 → 해제, 대시보드 처리 대기 신고 카드가 신고 1건 뒤 늘어남 (quickstart #18, #20)

### Implementation for User Story 2 (backend)

- [x] T031 [US2] `blog-backend/src/main/java/net/java21/blog/backend/admin/dashboard/AdminDashboardQueryRepository.java`(QueryDSL, 7일치 시각 목록 조회 2회 + 오늘 댓글 수 + 전체 수 3회), `admin/dashboard/PendingReportCounter.java`(인터페이스 `Long countPending()`), `admin/dashboard/NoPendingReportCounter.java`(`@ConditionalOnMissingBean`, null) — 005가 먼저 머지되었으면 005 `ReportQueryRepository`의 대기 수 메서드를 감싼 `ReportPendingCounter`를 바로 등록하고 `NoPendingReportCounter`는 만들지 않음
- [x] T032 [US2] `blog-backend/src/main/java/net/java21/blog/backend/admin/dashboard/AdminDashboardService.java`(Caffeine `Cache<ZoneId, Snapshot>`, `AdminProperties.dashboardCacheTtl`, 테스트용 `Ticker` 생성자, 관리자 시간대는 `UserRepository`의 `time_zone` projection), `admin/dashboard/AdminDashboardController.java`(`GET /api/v1/admin/dashboard`), DTO `admin/dashboard/dto/AdminDashboardResponse.java`
- [x] T033 [US2] `blog-backend/src/main/java/net/java21/blog/backend/admin/content/AdminContentSearchRepository.java`(글·댓글·방명록 DTO projection, 글 제목은 002 `MySqlFullTextFunctions.MATCH_TITLE`, 범위 없는 키워드 거부는 서비스), `admin/content/AdminContentSearchService.java`(검증·범위 규칙·002 `SearchQueryParser` 재사용), `admin/content/AdminContentSearchController.java`(`GET /api/v1/admin/contents/{posts|comments|guestbook-entries}` — 005 `AdminContentController`와 다른 파일), DTO `admin/content/dto/`(`AdminPostRow`, `AdminCommentRow`, `AdminGuestbookRow`, `AdminRef`)
- [x] T034 [US2] `blog-backend/src/main/java/net/java21/blog/backend/admin/info/AdminInfoController.java`(`GET /api/v1/admin/reserved-handles`, `GET /api/v1/admin/service-settings`), DTO `admin/info/dto/ServiceSettingsResponse.java`

### Implementation for User Story 2 (front)

- [x] T035 [US2] `blog-front/app/components/layout/Header.tsx`에 "시스템 관리"(`isAdmin(user.role)`, `/admin`), 문구 `common:nav.admin`(4개 언어)
- [x] T036 [US2] 대시보드: `blog-front/app/routes/admin/dashboard.tsx`(loader·meta), `blog-front/app/routes.ts`의 admin index를 `routes/admin/dashboard.tsx`로 바꾸고 `routes/admin/index.ts` 삭제, `blog-front/app/components/admin/DashboardCards.tsx`, `blog-front/app/components/charts/DailyBarChart.tsx`(004 `components/manage/VisitorChart.tsx`를 일반화하고 `routes/manage/stats.tsx`·dashboard가 새 컴포넌트를 쓰게 함), 문구 `admin` namespace(4개 언어)
- [x] T037 [US2] 콘텐츠 관리: `blog-front/app/routes/admin/contents.tsx`(리다이렉트), `routes/admin/contents.posts.tsx`·`contents.comments.tsx`·`contents.guestbook.tsx`(loader·action — 숨김은 `ADMIN_FEATURES.contentHide`일 때만), `blog-front/app/components/admin/ContentSearchForm.tsx`, `routes.ts`의 admin 자식에 `contents`·`contents/posts`·`contents/comments`·`contents/guestbook`, 문구 `admin` namespace
- [x] T038 [US2] `blog-front/app/routes/admin/reserved-handles.tsx`, `blog-front/app/routes/admin/service-settings.tsx`(경로 `settings`), `routes.ts`에 `reserved-handles`·`settings`, 크기·기간 표시 도우미 `blog-front/app/admin/format.ts`, 문구 `admin` namespace
- [x] T039 [US2] **(005 머지 후)** 005 연결: `blog-front/app/admin/links.ts`의 `ADMIN_FEATURES.contentHide` 플래그를 없애고 숨김·해제 버튼을 항상 보임(구현: true로 켜는 대신 플래그 제거), 005의 별도 "숨긴 글" 화면 파일·메뉴 항목을 없애고 `/admin/contents/hidden-posts`는 `/admin/contents/posts?status=HIDDEN`으로 리다이렉트, 005 회원 상세(`routes/admin/user.tsx`)에 "이 회원의 글·댓글"(`/admin/contents/posts?authorId=`·`/admin/contents/comments?authorId=`) 링크, backend는 T031의 `NoPendingReportCounter`를 005 `ReportPendingCounter`로 대체(빈 등록 시험 `AdminDashboardServiceTest`에 추가)

**Checkpoint**: US2 Independent Test E2E 통과, quickstart #10~#19(005 머지 후 #18·#20)

---

## Phase 5: User Story 3 - 관리자 작업 기록과 권한 부여 (Priority: P3)

**Goal**: 관리자의 모든 변경 작업이 작업 기록에 남고(누락 0건을 시험이 강제), 관리자는 기간·관리자·작업 종류로 걸러 본다. 최고 관리자는 다른 회원에게 관리자 권한을 주거나 회수하며, 마지막 최고 관리자는 보호된다. 기록은 1년 뒤 정리된다.

**Independent Test**: 관리자가 주제 숨김과 회원 블로그 한도 변경(005 머지 후에는 회원 정지)을 수행 → 작업 기록 메뉴에 누가·언제·무엇을·어떻게 바꿨는지 2건이 남는지 확인. 최고 관리자가 새 회원에게 ADMIN을 주면 그 회원이 콘솔을 열 수 있고, 회수하면 다음 요청부터 404인지 확인(quickstart #21~#29).

FR: FR-105, FR-106, SC-017

### Tests for User Story 3 (backend) ⚠️

- [x] T040 [P] [US3] `blog-backend/src/test/java/net/java21/blog/backend/admin/audit/AdminAuditLogQueryRepositoryTest.java`(`@JpaRepositoryTest`): 기간(관리자 시간대의 `from` 0시 ~ `to` 다음 날 0시 미만), `adminId`, `action` 여러 개, `targetType`+`targetId`, `targetKey` 각각과 조합, 새 것 먼저(같은 시각은 id 내림차순), 관리자 닉네임 JOIN, `before`·`after` JSON 그대로, 쿼리 2회(목록 + 개수, `QueryCounter`) (AS2, research A6)
- [x] T041 [P] [US3] `blog-backend/src/test/java/net/java21/blog/backend/admin/audit/AdminAuditLogServiceTest.java`·`AdminAuditLogControllerTest.java`: 기간 생략 시 최근 7일, `from > to` 400 field `from`, 366일 초과 400 field `to` `INVALID` `params.maxDays`, 상세의 `requestIp`는 요청자가 DB 기준 SUPER_ADMIN일 때만 복호화 값(ADMIN null), 없는 id 404 `NOT_FOUND`, `GET /admin/audit-logs/actions`가 `AuditActions.ALL`·`TARGETS`, `/admin/audit-logs/**`에 GET 외 매핑 없음(PUT·PATCH·DELETE 405 `METHOD_NOT_ALLOWED`), `no-store` (AS2, FR-106)
- [x] T042 [P] [US3] `blog-backend/src/test/java/net/java21/blog/backend/admin/audit/AdminAuditPurgeRepositoryTest.java`(`@JpaRepositoryTest`)·`AdminAuditPurgeJobTest.java`: 보관 기간(`MutableClock`)이 지난 행만 지우고 경계 직전 행은 남음, `purgeBatchSize`보다 많으면 여러 묶음으로 끝까지, 묶음마다 쿼리 2회(id 조회 + 삭제), 지운 건수 로그, `AdminAuditLogRepository`에는 여전히 삭제 메서드가 없음(리플렉션) (FR-106 "1년간 보관", research A7)
- [x] T043 [P] [US3] `blog-backend/src/test/java/net/java21/blog/backend/admin/user/AdminRoleServiceTest.java`(Mockito + `SuperAdminGuard` 가짜) 표 시험: USER→ADMIN·USER→SUPER_ADMIN·ADMIN→SUPER_ADMIN은 `ROLE_GRANT`, SUPER_ADMIN→ADMIN·ADMIN→USER·SUPER_ADMIN→USER는 `ROLE_REVOKE`(before/after `{ role }`, 요청 IP), 같은 값은 변화·기록 없이 200, 요청자 ADMIN이면 403 `FORBIDDEN`(저장 없음), 자기 자신 422 `CANNOT_CHANGE_OWN_ROLE`, 없는 회원 404 `USER_NOT_FOUND`, 정지·탈퇴 회원에게 ADMIN 이상 409 `USER_NOT_ACTIVE`(정지 회원의 회수는 허용), 마지막 ACTIVE SUPER_ADMIN을 낮추면 409 `LAST_SUPER_ADMIN`, `role` 없음·잘못된 값 400 (FR-105, Edge Cases, research A9)
- [x] T044 [P] [US3] `blog-backend/src/test/java/net/java21/blog/backend/admin/user/AdminRoleControllerTest.java`: `PUT /admin/users/{id}/role` 본문 바인딩·응답 `AdminMember`·오류 형식, `GET /admin/admins`(ADMIN·SUPER_ADMIN 전원·정지 포함, 권한 높은 순 → 닉네임순, 쿼리 1회는 `AdminUserRepositoryTest`에서), `no-store`
- [x] T045 [P] [US3] `blog-backend/src/test/java/net/java21/blog/backend/integration/AdminRoleIntegrationTest.java`(`@SpringBootTest`, H2): 최고 관리자가 회원 B에게 ADMIN → B의 같은 접근 토큰으로 관리자 API 200 → 회수 → B의 다음 관리자 API 요청 404 `NOT_FOUND`(토큰 재발급 없이, US3 AS3), 최고 관리자 두 명이 서로를 동시에 SUPER_ADMIN→USER로 낮추는 요청 두 개(스레드 2개, `CountDownLatch`)에서 하나만 성공하고 하나는 409 `LAST_SUPER_ADMIN`(잠금 확인, Edge Cases)
- [x] T046 [P] [US3] `blog-backend/src/test/java/net/java21/blog/backend/integration/AdminAuditCoverageIntegrationTest.java`(`@SpringBootTest`, H2, research A8): `RequestMappingHandlerMapping`의 `/api/v1/admin/**` 중 GET이 아닌 매핑 전체를 시험 안의 표(매핑 → 준비·요청 본문 → 기대 `action`)와 비교해 표에 없는 매핑이 있으면 실패("새 관리자 변경 API는 이 표에 행을 더한다"), 표의 각 행을 SUPER_ADMIN으로 보내 2xx 뒤 `admin_audit_logs`에 그 `action` 행이 늘었는지 확인. 상태를 바꾸지 않는 POST(`/admin/release-notes/preview`)는 "기록 없음" 목록에 이유와 함께. 003의 주제·추천·제외·설정·블로그 한도·릴리스 노트 5종, 006 권한 변경을 모두 덮음 (SC-017, US3 AS1, FR-106)

### Tests for User Story 3 (front) ⚠️

- [x] T047 [P] [US3] `blog-front/tests/unit/routes/adminAuditLog.test.tsx`: 필터 폼 값이 쿼리로(기간·관리자 선택지는 `GET /admin/admins`·작업 종류 선택지는 `GET /admin/audit-logs/actions`를 `app/admin/auditActions.ts` 묶음으로), 표(작업 이름은 `audit:actions.{CODE}`, 없는 코드는 코드 그대로), 대상 링크(USER → 005 회원 상세(005 전에는 텍스트), RELEASE_NOTE → 편집 화면, TOPIC → 주제 관리), `<details>` 펼침의 `JsonDiff`(키별 전·후, 같은 값은 흐리게), 400 기간 오류 문구, `/admin/audit-log/:id`의 요청 IP(SUPER_ADMIN만, ADMIN은 안내); `tests/unit/components/JsonDiff.test.tsx`; `tests/unit/i18n/auditActions.test.ts`(`auditActions.ts`의 모든 코드에 4개 언어 문구)
- [x] T048 [P] [US3] `blog-front/tests/unit/routes/adminAdmins.test.tsx`·`tests/unit/components/RoleForm.test.tsx`: 목록(권한·상태), 세션이 SUPER_ADMIN이면 행마다 권한 바꾸기(선택 + 확인 체크)와 "회원 번호로 관리자 지정" 폼, ADMIN이면 읽기 전용, action `intent=role` → `PUT /admin/users/{id}/role`, 오류 문구(`CANNOT_CHANGE_OWN_ROLE`·`LAST_SUPER_ADMIN`·`USER_NOT_ACTIVE`·`USER_NOT_FOUND`·403)

### Tests for User Story 3 (E2E) ⚠️

- [x] T049 [P] [US3] E2E `blog-front/tests/e2e/admin-us3-audit-roles.spec.ts`(`requireBackend`·`requireAdmin`, `admin` 프로젝트): Independent Test(관리자가 실행마다 고유한 소분류를 만들고 숨김, 새 회원의 블로그 한도 변경 → `/admin/audit-log`에서 기간 오늘·작업 종류로 걸러 2건과 펼친 변경 전후 값, AS1·AS2), 기록 수정 요청 405(AS2), 권한: 새 회원 B 가입 → 최고 관리자가 `/admin/admins`에서 B 번호로 ADMIN → B로 상단 "시스템 관리"와 `/admin` → B가 `PUT /admin/users/{C}/role` 403 → 회수 → B의 다음 `/admin` 404·상단 메뉴 없음 → 작업 기록에 `ROLE_GRANT`·`ROLE_REVOKE`(AS3), 최고 관리자가 자기 권한 변경 시도 422 문구. `GET /admin/audit-logs/actions`의 코드가 front `auditActions.ts`에 모두 있는지 비교. **CI 관리자 자신의 권한이 바뀌는 요청은 보내지 않는다**(결정 표 25번) (quickstart #21~#27)

### Implementation for User Story 3 (backend)

- [x] T050 [US3] `blog-backend/src/main/java/net/java21/blog/backend/admin/audit/AdminAuditLogQueryRepository.java`(QueryDSL, 조건별 인덱스에 맞춘 where, 관리자 닉네임 JOIN projection), `admin/audit/AdminAuditLogService.java`(기간 해석·검증, 상세 IP는 `SuperAdminGuard`로 확인한 최고 관리자만), `admin/audit/AdminAuditLogController.java`(`GET /api/v1/admin/audit-logs`, `/{id}`, `/actions`), DTO `admin/audit/dto/`(`AuditLogEntryResponse`, `AuditLogDetailResponse`, `AuditActionListResponse`)
- [x] T051 [US3] `blog-backend/src/main/java/net/java21/blog/backend/admin/audit/AdminAuditPurgeRepository.java`(`findIdsCreatedBefore(cutoff, limit)`, `deleteByIds(ids)` 벌크 DELETE), `admin/audit/AdminAuditPurgeJob.java`(`@Scheduled(cron = "${blog.jobs.audit-purge-cron:0 15 5 * * *}")`, 묶음마다 트랜잭션, 건수 로그)
- [x] T052 [US3] `blog-backend/src/main/java/net/java21/blog/backend/admin/user/AdminRoleService.java`(`SuperAdminGuard`로 요청자 확인·잠금·남는 수 확인, `AdminUserRepository.updateRole`, `AdminAuditService.record`), `admin/user/AdminRoleController.java`(`PUT /api/v1/admin/users/{id}/role`, `GET /api/v1/admin/admins`), DTO `admin/user/dto/RoleChangeRequest.java`·`AdminMemberResponse.java`, `AdminUserRepository`에 관리자 목록 projection(`idx_users_role_status`)

### Implementation for User Story 3 (front)

- [x] T053 [US3] 작업 기록: `blog-front/app/routes/admin/audit-log.tsx`, `blog-front/app/routes/admin/audit-log-entry.tsx`(`/admin/audit-log/:id`), `blog-front/app/components/admin/AuditLogTable.tsx`·`JsonDiff.tsx`, `blog-front/app/admin/auditActions.ts`(코드 목록·묶음: 주제·포털·회원·콘텐츠·설정·릴리스 노트·권한), `routes.ts`에 `audit-log`·`audit-log/:id`, 문구 `audit` namespace(작업 종류 이름 4개 언어)·`admin` namespace
- [x] T054 [US3] 관리자 권한: `blog-front/app/routes/admin/admins.tsx`(loader·action), `blog-front/app/components/admin/RoleForm.tsx`, `routes.ts`에 `admins`, 문구 `admin` namespace
- [x] T055 [US3] **(005 머지 후)** 005 회원 상세 `blog-front/app/routes/admin/user.tsx`에 "관리자 권한" 영역(`RoleForm`, 최고 관리자만 바꾸기)과 "이 회원 대상 작업 기록"(`/admin/audit-log?targetType=USER&targetId={id}`) 링크, `tests/unit/routes/adminUser.test.tsx`(005)에 같은 시험 추가; 005 정지·신고·금칙어 API 행을 T046 표에 더했는지 확인(005가 이미 더했으면 확인만)

**Checkpoint**: US3 Independent Test E2E 통과, quickstart #21~#29, 행렬 테스트 T046이 모든 관리자 변경 API를 덮음

---

## Phase 6: User Story 4 - 시스템 관리자가 릴리스 노트를 쓰고 게시한다 (Priority: P4)

**Goal**: 관리자는 콘솔 "릴리스 노트" 메뉴에서 버전별 노트를 언어별로 쓰고 미리 보고 초안으로 저장한 뒤 게시하며, 고칠 때마다 수정본이 남고 동시 수정은 충돌로 안내된다(003이 만든 API를 쓰는 화면).

**Independent Test**: 관리자가 v1.2.0을 한국어판만 넣어 초안으로 저장 → 비로그인으로 `/updates/v1.2.0`이 "찾을 수 없음"인지 확인 → 영어판을 더해 저장 → 게시 → `/updates/v1.2.0`에 보이는지 확인 → 본문을 고쳐 저장 → 수정본 목록에 3건(만들기, 영어판 추가, 게시 후 수정)이 남고 작업 기록에 만들기·수정·게시가 남는지 확인(quickstart #30~#38).

FR: FR-167, FR-168 (003 FR-161~166 독자 화면은 003)

### Tests for User Story 4 ⚠️

- [x] T056 [P] [US4] `blog-front/tests/unit/routes/adminReleaseNotes.test.tsx`: 상태 탭(전체·초안·게시) → `GET /admin/release-notes?status=&page=`, 표(버전·상태 배지·릴리스 날짜·언어판·수정본 번호·게시 시각), "새 노트" 링크, 빈 목록 문구, 관리자 아님 404
- [x] T057 [P] [US4] `blog-front/tests/unit/routes/adminReleaseNoteEdit.test.tsx`: 새 노트(`/new`) — 언어 탭 4개(ko 필수 표시, 나머지는 "이 언어판 넣기"), 저장 → `POST` 본문(`version`·`releaseDate`·`contents`에 체크한 언어판만) → 201이면 `/admin/release-notes/{id}`로; 수정 — `GET` 값 채움, 숨은 `baseRevisionNo`, `firstPublishedAt`이 있으면 버전 읽기 전용·삭제 버튼 없음, `intent=preview`가 `POST /preview` 결과를 그리고 입력을 유지(JS 없음 경로) — `useFetcher` 경로는 컴포넌트 시험, `intent=publish|unpublish|delete`(확인 체크), 409 `RELEASE_NOTE_REVISION_CONFLICT`면 입력 유지 + 안내 + "최신 내용 열기"(AS5), 필드 오류(`version` `INVALID_FORMAT`, `RELEASE_NOTE_VERSION_TAKEN`, `contents.ko` `REQUIRED`, `RELEASE_NOTE_VERSION_LOCKED`, `RELEASE_NOTE_ONCE_PUBLISHED`)를 필드 옆에(AS2), `?fromRevision=` 값 채우기, 게시 상태면 "독자에게 보기"
- [x] T058 [P] [US4] `blog-front/tests/unit/routes/adminReleaseNoteRevisions.test.tsx`(목록: 번호·수정한 관리자·시각·당시 상태, 보기: 언어판별 제목·원문 읽기 전용, "이 내용으로 편집기 채우기" 링크)와 `blog-front/tests/unit/components/MarkdownPreview.test.tsx`(backend HTML 그대로·목차); `tests/unit/lint/` 의 `dangerouslySetInnerHTML` 허용 목록 시험에 `components/admin/MarkdownPreview.tsx`
- [x] T059 [P] [US4] backend 계약 확인: `blog-backend/src/test/java/net/java21/blog/backend/admin/releasenote/AdminReleaseNoteControllerTest.java`(003)에 006 화면이 기대는 것 — 목록 `langs` 배열, 상세 `contents`에 모든 언어판, 수정본 상세의 `editedBy`·`status`, 모든 응답 `no-store` — 이 없으면 추가(003 구현이 이미 맞으면 시험만)
- [x] T060 [P] [US4] E2E `blog-front/tests/e2e/admin-us4-release-notes.spec.ts`(`requireBackend`·`requireAdmin`, `admin` 프로젝트): Independent Test 전체를 화면으로(버전은 `uniqueVersion()`), 잘못된 버전·한국어판 비움 문구(AS2), 게시 뒤 `/updates/v{version}`·포털 카드(AS3), 게시 뒤 버전 입력 읽기 전용·삭제 버튼 없음, 같은 노트를 두 페이지로 열어 차례로 저장 → 두 번째 충돌 안내(AS5), 게시 중단 → 독자 404, 작업 기록에 `RELEASE_NOTE_CREATE`·`UPDATE`·`PUBLISH`·`UNPUBLISH`(AS6), 한 번도 게시하지 않은 초안 만들기·삭제 (quickstart #30~#37)

### Implementation for User Story 4

- [x] T061 [US4] `blog-front/app/routes/admin/release-notes.tsx`(목록), `routes.ts`의 admin 자식에 `release-notes`·`release-notes/new`·`release-notes/:id`·`release-notes/:id/revisions`·`release-notes/:id/revisions/:revisionNo`, 문구 `admin` namespace(`releaseNotes.*`, 4개 언어)
- [x] T062 [US4] `blog-front/app/routes/admin/release-note-edit.tsx`(`/new`·`/:id` 공용 모듈 — 003 `topic.tsx`처럼 `id`로 구분, loader·action·meta), `blog-front/app/components/admin/ReleaseNoteEditor.tsx`·`LanguageTabs.tsx`(JS 없이 앵커·`<details>`로 탭, JS 있으면 탭 전환)·`MarkdownPreview.tsx`(003 `updates` 본문 클래스·`Toc` 재사용), ESLint 설정(`blog-front/eslint.config.js`)의 `dangerouslySetInnerHTML` 허용 목록에 `MarkdownPreview.tsx`, 오류 문구는 003 `AdminFormErrors`
- [x] T063 [US4] `blog-front/app/routes/admin/release-note-revisions.tsx`, `blog-front/app/routes/admin/release-note-revision.tsx`, 편집 화면의 "이 노트의 작업 기록"(`/admin/audit-log?targetType=RELEASE_NOTE&targetId={id}`) 링크

**Checkpoint**: US4 Independent Test E2E 통과, quickstart #30~#38

---

## Phase 7: Polish & Cross-Cutting Concerns

- [x] T064 [P] `blog-backend/src/test/java/net/java21/blog/backend/openapi/OpenApiContractTest.java`에 contracts/api.md의 006 엔드포인트 11개(대시보드 1, 콘텐츠 검색 3, 예약어 1, 서비스 설정 1, 작업 기록 3, 관리자 목록 1, 권한 변경 1)와 응답 스키마 필드
- [x] T065 [P] `blog-backend/src/test/java/net/java21/blog/backend/security/CacheHeadersWebMvcTest.java`에 006 관리자 API 전부 `Cache-Control: no-store`
- [x] T066 [P] `blog-backend/src/test/java/net/java21/blog/backend/seo/controller/RobotsControllerTest.java`에 `/admin`, `/manage`, `/*/manage/` 규칙이 있음을 단정(이미 있으면 확인만, FR-098)
- [x] T067 [P] 운영 문서 `blog-backend/docs/operations.md`에 006 프로퍼티(`blog.admin.dashboard-cache-ttl`, `blog.admin.audit-retention`, `blog.jobs.audit-purge-cron`), 첫 최고 관리자 지정(`BLOG_ADMIN_BOOTSTRAP_SUPER_ADMIN_EMAIL`)과 관리자 권한 부여·회수 절차(최고 관리자 2명 이상 권장, 자기 권한은 바꿀 수 없음), 작업 기록 보관·정리와 요청 IP 열람 권한, 선택 인덱스 4개가 없을 때 대시보드 계산 비용. front 4개 언어 README(`blog-front/README.md`·`README.en.md`·`README.ja.md`·`README.zh-CN.md`)에 E2E 환경 변수 `E2E_ADMIN_TEST_SETTINGS`와 backend `BLOG_ADMIN_DASHBOARD_CACHE_TTL=0s`(결정 표 25번)
- [x] T068 [P] E2E `blog-front/tests/e2e/admin-mobile.spec.ts`(`requireBackend`, 뷰포트 360×740): `/{handle}/manage`·`/{handle}/manage/posts`(일괄 작업 포함)·`/{handle}/manage/settings` 가로 스크롤 없이 동작, `requireAdmin`일 때 `/admin`·`/admin/audit-log` 조회 가능(표는 가로 스크롤 상자 안) (spec Assumptions, quickstart #39)
- [x] T069 [P] E2E `blog-front/tests/e2e/us5-i18n.spec.ts`(001)에 006 화면 추가: 화면 언어 en·ja·zh-CN에서 콘솔 메뉴·대시보드 카드·작업 기록의 작업 이름·릴리스 노트 편집기 문구가 그 언어 (quickstart #40)
- [x] T070 커버리지 확인: `blog-backend`의 `./mvnw verify`, `blog-front`의 `npm test -- --coverage` 모두 라인 80% 이상
- [x] T071 CI 확인: blog-front PR의 `e2e-backend` 잡 로그에서 `admin-us1-*`·`admin-us2-*`·`admin-us3-*`·`admin-us4-*`·`admin-mobile`이 **건너뜀(skipped) 없이 통과**했는지 확인하고 PR 설명에 실행 수를 적음(건너뛰었다면 T004 환경 변수부터 고침, `admin-us2-members`는 005 머지 후)
- [ ] T072 `blog-docs/specs/006-admin-consoles/quickstart.md` 수동 검증 시나리오 #1~#41 전체 실행(backend·front 함께 기동, 005 의존 #18·#20은 005 머지 후), 끝난 작업을 이 tasks.md에 [x]로 표시 — (수동, 배포 후)

---

## 구현 전 결정 사항 (2026-10-07 확정)

marco가 "묻지 말고 진행"하라고 해서 Claude가 기본값으로 정했다. 바꾸려면 이 표와 관련 문서를 함께 고친다.

| # | 문제 | 결정 | 반영 문서 |
|---|---|---|---|
| 1 | 스토리 순서와 번호 | spec 그대로: US1 블로그 관리(P1), US2 콘솔 운영(P2), US3 작업 기록과 권한(P3), US4 릴리스 노트(P4). 일정이 부족하면 US4를 뒤로(003 독자 화면은 API로 게시 가능) | plan.md, 이 문서 |
| 2 | 006의 범위 | 다른 스펙이 만든·만들 메뉴는 만들지 않는다. 회원 검색·상세·정지(FR-104 화면 대부분)·신고·숨김 API·스팸은 005, 외부 블로그는 007, 방명록·꾸미기·통계·백업·차단은 004, 주제·포털·릴리스 노트 API는 003. 006은 메뉴 자리·순서·접근 규칙과 FR-103·105·106·콘텐츠 검색·예약어·서비스 설정·릴리스 노트 화면 | research A1, plan.md 범위 밖 |
| 3 | 블로그 관리 메뉴 순서 | FR-099 표 순서(대시보드, 글, 카테고리, 댓글, 방명록, 블로그 설정, 꾸미기, 피드 설정, 통계, 받은 트랙백, 백업, 차단 목록, 외부 블로그). 005 routes.md의 "받은 트랙백은 댓글 다음"보다 spec 표를 따른다. 콘솔은 FR-102 표 순서에 표시용 묶음 제목 셋(운영·포털·서비스) | research A2, contracts/routes.md |
| 4 | "아직 구현되지 않은 스펙의 메뉴는 숨긴다" 방식 | 런타임 플래그가 아니라 `admin/links.ts`·`manage/links.ts`의 `available` 상수와 `ADMIN_FEATURES.contentHide`. 각 스펙의 PR이 자기 항목을 켠다. 숨긴 항목의 경로는 `routes.ts`에도 없다. `ADMIN_FEATURES.contentHide`는 005 머지 후 true로 켜는 대신 없앴다(숨김·해제 버튼 항상 보임, T039) | research A2 |
| 5 | 시작 조건 | 004가 main에 머지된 뒤 시작(004-rest가 관리 메뉴·글 필터를 함께 고침). 005와는 병렬, 005에 기대는 작업 5개(T030·T039·T055와 T031·T046의 005 연결)는 "(005 머지 후)" | plan.md, 아래 의존 표 |
| 6 | 대시보드 수치 정의 | 가입자 = `users.created_at`(탈퇴 포함), 발행 글 = `posts.published_at`(최초 발행, 지금 상태·공개 범위 무관), 댓글 = `comments.created_at`(비회원·삭제 포함), 전체 회원·블로그 = ACTIVE, 공개 글 = PUBLISHED + PUBLIC(정지 회원 글 포함 — 노출 매트릭스 전체를 적용하지 않음) | research A3, contracts/api.md |
| 7 | 대시보드 시간대와 캐시 | 요청한 관리자의 `users.time_zone`으로 날짜 경계. Caffeine 캐시(키 시간대, `blog.admin.dashboard-cache-ttl` 5분, 0이면 끔). 처리 대기 신고 수는 캐시하지 않음 | research A3 |
| 8 | 콘텐츠 검색의 비밀 댓글·방명록 | 목록에 내용을 보이지 않음(`content: null`, "비밀 댓글"). 내용 확인은 신고 처리 화면(005 결정 6번)에서만 | research A4 |
| 9 | 댓글·방명록 키워드 검색 | 글·작성자·블로그 범위가 하나 이상 있을 때만 `LIKE`. 범위 없으면 400 `SCOPE_REQUIRED`. 서비스 전체 본문 검색은 하지 않음(FULLTEXT 인덱스 없음, 스키마 변경 회피) | research A4, contracts/api.md |
| 10 | 005 "숨긴 글" 화면 | 006 콘텐츠 관리 `?status=HIDDEN`으로 흡수하고 옛 주소는 리다이렉트. 숨긴 댓글·방명록 전체 목록도 같은 화면의 `status` 필터 | research A4, T039 |
| 11 | 관리자 글 검색의 범위 | 제목만 전문 검색(본문 검색 안 함 — 비공개 본문 추측 방지, FR-104), 휴지통 글 포함, 응답에 본문·요약 없음 | research A4 |
| 12 | 예약어·서비스 설정 | 둘 다 읽기 전용 API·화면. 서비스 설정은 약관 버전·첨부 파일 한도·회원당 기본 블로그 수·작업 기록 보관·대시보드 갱신 주기와 프로퍼티 이름. 비밀 값은 넣지 않음 | research A5 |
| 13 | 작업 기록 조회 기본값 | 기간 생략 시 최근 7일, 최대 366일, 날짜는 관리자 시간대, 새 것 먼저, 작업 종류 여러 개 선택 | research A6 |
| 14 | 권한 변경 API 형태 | `PUT /admin/users/{id}/role { role }` 하나(세 단계 값을 바로 정함). 같은 값이면 기록 없이 200. 관리자 목록 `GET /admin/admins` | research A9, contracts/api.md |
| 15 | 권한 부여 화면 위치 | 005 회원 상세의 "관리자 권한" 영역(회원 찾기는 005 검색) + `/admin/admins`의 "회원 번호로 관리자 지정"(005 전에도 쓸 수 있게, 005 뒤에도 둠) | research A9 |
| 16 | 자기 권한 변경 | 금지(422 `CANNOT_CHANGE_OWN_ROLE`). 마지막 최고 관리자 보호와 별도로, 실수로 자기 권한을 잃는 것을 막음. 다른 최고 관리자가 바꿔야 함 | research A9 |
| 17 | 권한 회수 때 토큰 | 갱신 토큰을 폐기하지 않음(일반 회원으로는 계속 로그인). 관리자 API는 003 필터가 요청마다 DB를 읽어 다음 요청부터 404, 상단 메뉴도 다음 화면부터(`/me`) | research A9·A12 |
| 18 | 작업 기록의 요청 IP | 목록에는 없고 상세에서 최고 관리자에게만 복호화 값. 일반 관리자에게는 null | research A6 |
| 19 | 작업 기록 정리 | 매일 05:15(`blog.jobs.audit-purge-cron`), 보관 365일(`blog.admin.audit-retention`, 30일 미만 기동 실패), id 500건씩 삭제. 삭제는 정리 전용 리포지토리에만 | research A7 |
| 20 | SC-015 강제 방법 | `/api/v1/admin/**` 매핑 전체를 비관리자 4종으로 호출하는 행렬 테스트(T008). 005·007 API도 자동으로 덮음 | research A10 |
| 21 | SC-017 강제 방법 | GET이 아닌 관리자 매핑 전체를 표와 비교하고 각 행이 기록을 남기는지 실행하는 행렬 테스트(T046). 표에 없는 새 매핑이 생기면 실패. 005·007은 자기 API 행을 더함 | research A8 |
| 22 | 블로그 관리 AS5 강제 | `/blogs/{handle}/manage/**`와 주인 전용 API 표의 행렬 테스트(T015) | research A10 |
| 23 | 검색 엔진 제외 보강 | meta noindex·robots.txt에 더해 front 미들웨어가 관리 화면 모든 응답에 `X-Robots-Tag: noindex, nofollow` | research A11 |
| 24 | 릴리스 노트 화면의 되돌리기·JS 없는 편집 | 되돌리기 API를 만들지 않고 "이 내용으로 편집기 채우기" → 저장(새 수정본). 언어 탭은 JS 없이 한 폼(앵커·`<details>`), 미리보기는 `intent=preview` 제출(JS 있으면 `useFetcher`) | research A13 |
| 25 | E2E가 CI에서 실제로 도는 조건 | `ci.yml` `e2e-backend`와 `e2e.yml`에 `BLOG_ADMIN_DASHBOARD_CACHE_TTL=0s`, Playwright에 `E2E_ADMIN_TEST_SETTINGS=1`. 관리자 계정은 003 것 재사용. 전역 상태를 바꾸는 시나리오는 `admin` 프로젝트(workers 1, 마지막). CI 관리자 자신의 권한을 바꾸는 요청은 E2E에서 보내지 않음(마지막 최고 관리자는 단위·통합 시험). T071에서 건너뜀 없이 돌았는지 확인 | research A14, T003·T004·T071 |
| 26 | 새 번역 namespace | `audit`(작업 종류·대상 이름, 작업 기록 화면). 콘솔은 `admin`, 블로그 관리는 `manage`, 상단 링크는 `common` | contracts/routes.md |
| 27 | 스키마 변경 | 필수 DDL 없음. 선택 인덱스 4개(`idx_users_created`, `idx_posts_published_at`, `idx_comments_status_created`, `idx_guestbook_entries_status_created`)는 plan.md에 정확한 DDL만 두고 Crowfoot `plan_migration` → marco 승인 전에는 만들지 않음. 이 작업에서 Crowfoot 문서와 DB는 건드리지 않음 | plan.md "스키마 변경" |
| 28 | 005와 공유하는 코드 | `SuperAdminGuard`, 오류 코드 `LAST_SUPER_ADMIN`·`USER_NOT_ACTIVE`, `AuditActions.TARGET_USER`, E2E `adminRequest`는 먼저 머지하는 스펙이 만들고 다른 쪽은 재사용(중복 정의 금지) | 아래 의존 표 |
| 29 | 처리 대기 신고 수 자리 | `PendingReportCounter` 인터페이스 + `NoPendingReportCounter`(null, 카드 숨김). 005가 구현 빈을 등록(003 `BlogPenaltyPolicy` 방식). 005가 먼저 머지되면 자리 없이 바로 연결 | research A3, T031·T039 |
| 30 | 콘솔 첫 화면 | `/admin`은 대시보드(003의 `/admin/topics` 리다이렉트 제거). 003 E2E 단정을 같은 PR에서 고침 | contracts/routes.md, T029·T036 |
| 31 | 다른 스펙의 일 | 회원 관리·신고·스팸·받은 트랙백(005), 외부 블로그(007), 백업·차단·보호/예약 필터(004-rest). 관리자 OTP·대리 블로그 관리·기본 블로그 수 편집·별도 관리 도메인·릴리스 노트 이미지는 spec 범위 밖 | plan.md "범위 밖" |

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: 001~004가 main에 있어야 함(004 머지 후)
- **Foundational (Phase 2)**: Setup의 프로퍼티(T005)·모델 타입(T002)·CI 환경(T004) 이후. 모든 스토리를 막는다
- **US1 블로그 관리 (Phase 3)**: Phase 2(메뉴 정의 T013, `X-Robots-Tag` T014) 이후. MVP
- **US2 콘솔 운영 (Phase 4)**: Phase 2 이후. 005에 기대는 T030·T039는 005 머지 후
- **US3 작업 기록과 권한 (Phase 5)**: Phase 2(`AuditActions` T011, `SuperAdminGuard` T012) 이후. T055는 005 머지 후. 작업 기록 화면의 대상 링크는 US2·US4 화면이 있으면 더 쓸모 있지만 없어도 독립 시험 가능
- **US4 릴리스 노트 (Phase 6)**: Phase 2 이후. 003 API만 쓰므로 다른 스토리와 독립
- **Polish (Phase 7)**: 원하는 스토리가 모두 끝난 뒤

### 004·005·003 의존 (006이 기대는 앞 스펙 작업)

| 006 작업 | 기대는 작업 | 내용 |
|---|---|---|
| T013, T016, T018, T019 (블로그 관리 메뉴·글 필터) | 004 T111·T120 (`routes/manage/backup.tsx`·`blocks.tsx`, 메뉴 "백업"·"차단 목록"), 004 T098 (관리 글 목록의 예약·보호 필터 값) — `feat/004-rest` | 004-rest가 더한 메뉴·필터를 `manage/links.ts`·`postFilters.ts`로 옮기므로 004 머지 후 |
| T015 (블로그 관리 API 행렬) | 004 T028 (`SecurityConfig`의 백업·차단 경로), 004 Phase 6·7 컨트롤러 | 표에 004 주인 전용 API 행 |
| T036 (`DailyBarChart`) | 004 US2 통계 화면(`components/manage/VisitorChart.tsx`, `routes/manage/stats.tsx`, main에 있음) | 004 그래프를 일반화 |
| T017 (블로그 관리 E2E) | 004 T036·T045 (대시보드 방명록·방문자) | 대시보드 수치 확인 |
| T031, T039 (처리 대기 신고) | 005 T032·T052 (`ReportQueryRepository`의 대기 수) | `PendingReportCounter` 구현 |
| T027, T037, T039 (콘텐츠 숨김 버튼·숨긴 목록 흡수) | 005 T053·T060 (`AdminContentController` 숨김 API, `/admin/contents/hidden-posts`) | 005 API 호출, 005 화면을 리다이렉트로 |
| T030, T055 (회원 상세의 블로그 한도·권한 영역) | 005 T055·T061 (`AdminUserController` 검색·상세, `routes/admin/user.tsx`) | 005 화면에 영역 추가 |
| T010, T012 (`LAST_SUPER_ADMIN`·`USER_NOT_ACTIVE`·`SuperAdminGuard`) | 005 T015·T055 (같은 오류 코드, 마지막 최고 관리자 정지 거부) | 먼저 머지하는 쪽이 만듦(결정 표 28번) |
| T011 (`AuditActions.TARGET_USER`) | 005 T024 | 같은 상수 |
| T003 (`adminRequest`), T004 (workflow) | 005 T003·T004 (`adminRequest`, `moderation` 프로젝트, 환경 변수) | 같은 파일. `admin` 프로젝트 `dependencies`에 `moderation` 추가 |
| T046 (작업 기록 강제 표) | 005 관리자 변경 API 16개(신고 처리·숨김·정지·금칙어) | 005가 먼저 머지되면 006 PR이 005 행을 표에 넣고, 006이 먼저면 005 PR이 넣음 |
| T008 (관리자 API 404 행렬) | 001 T159 (`AdminAccessFilter`·`DatabaseAdminRoleLookup`) | 001 필터를 시험 |
| T013, T025, T029, T036 (콘솔 레이아웃·첫 화면) | 003 T100 (`routes/admin/layout.tsx`, `admin/links.ts`, `routes/admin/index.ts`), 003 `portal-us4-admin.spec.ts` | 003 뼈대를 바꿈 |
| T056~T063 (릴리스 노트 화면) | 003 T107·T119 (`AdminReleaseNoteController`·`Service`), 003 T120~T125 (독자 화면 `updates` 컴포넌트 `Toc`) | 003 API·컴포넌트 그대로 |
| T011 (`USER_BLOG_LIMIT_CHANGE`), T042·T050 (작업 기록) | 001 T160·T161 (`AdminAuditLog`·`AdminAuditService`, `AdminUserService` 블로그 한도), 003 T094 (`recordKey`) | 문자열 상수를 `AuditActions`로 |

### User Story Dependencies

- **US1 (P1)**: Phase 2 이후. 다른 스토리에 의존하지 않음
- **US2 (P2)**: Phase 2 이후. 독립 테스트 가능(005 몫만 005 머지 후)
- **US3 (P3)**: Phase 2 이후. 독립 테스트 가능(005 회원 상세 영역만 005 머지 후)
- **US4 (P4)**: Phase 2 이후. 독립 테스트 가능

### Within Each User Story

- 테스트를 먼저 쓰고 실패를 확인한 뒤 구현한다(원칙 III)
- 리포지토리(QueryDSL) → 서비스 → 컨트롤러 → front 라우트 → E2E
- 새 엔티티는 없다. 리포지토리 시험은 H2 `@JpaRepositoryTest` + `QueryCounter`, 글 제목 FULLTEXT만 `@MySqlRepositoryTest`
- 새 화면 문구·오류 코드는 같은 작업에서 4개 언어 번역을 넣는다(원칙 VII)
- 스토리의 E2E(Independent Test)가 CI에서 통과해야 다음 우선순위로 넘어간다

### Parallel Opportunities

- Setup의 [P] 작업(T001~T005)은 모두 병렬
- Phase 2 테스트(T006~T009)는 모두 [P], 구현은 backend(T010~T012)와 front(T013·T014)가 병렬
- 각 스토리의 테스트 작업(backend·front·E2E)은 모두 [P]
- Phase 2 이후 US1·US2·US3·US4는 서로 다른 파일이 대부분이라 병렬 가능. 같은 파일(`ErrorCode`, `AuditActions`, `AdminUserRepository`(T012·T052), `admin/links.ts`(T013·T039), `routes/admin/layout.tsx`, `routes.ts`(T036~T038·T053·T054·T061), `Header.tsx`, `admin.json`, `errors.json`, `playwright.config.ts`, `tests/e2e/support/backend.ts`, 두 workflow)을 고치는 작업은 머지 순서를 맞춘다

---

## Parallel Example: User Story 2

```bash
# backend 테스트를 함께 시작:
Task: "AdminDashboardQueryRepositoryTest in blog-backend/src/test/java/net/java21/blog/backend/admin/dashboard/AdminDashboardQueryRepositoryTest.java"
Task: "AdminContentSearchRepositoryTest in blog-backend/src/test/java/net/java21/blog/backend/admin/content/AdminContentSearchRepositoryTest.java"
Task: "AdminInfoControllerTest in blog-backend/src/test/java/net/java21/blog/backend/admin/info/AdminInfoControllerTest.java"

# front 테스트를 함께 시작:
Task: "adminDashboard.test.tsx in blog-front/tests/unit/routes/adminDashboard.test.tsx"
Task: "adminContents.test.tsx in blog-front/tests/unit/routes/adminContents.test.tsx"
Task: "Header.test.tsx in blog-front/tests/unit/components/Header.test.tsx"
```

## Parallel Example: User Story 3

```bash
Task: "AdminAuditLogQueryRepositoryTest in blog-backend/src/test/java/net/java21/blog/backend/admin/audit/AdminAuditLogQueryRepositoryTest.java"
Task: "AdminRoleServiceTest in blog-backend/src/test/java/net/java21/blog/backend/admin/user/AdminRoleServiceTest.java"
Task: "AdminAuditCoverageIntegrationTest in blog-backend/src/test/java/net/java21/blog/backend/integration/AdminAuditCoverageIntegrationTest.java"
Task: "adminAuditLog.test.tsx in blog-front/tests/unit/routes/adminAuditLog.test.tsx"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1 Setup, Phase 2 Foundational(CI에서 001~004 E2E가 새 환경으로 통과하는지, 행렬 테스트가 003 관리자 API 전부를 덮는지 먼저 확인)
2. Phase 3 (US1 블로그 관리)
3. **멈추고 확인**: US1 Independent Test E2E(CI), quickstart #1~#9
4. 시연·배포 가능(FR-099 메뉴, 접근 규칙 행렬, noindex 보강)

### Incremental Delivery

1. Setup + Foundational → 기반 완료(메뉴 정의, 작업 종류 목록, 최고 관리자 잠금, SC-015 행렬)
2. US1(Phase 3) → MVP
3. US2(Phase 4) → US3(Phase 5) → US4(Phase 6), 각 스토리의 E2E 통과 후 다음
4. 005가 머지되면 "(005 머지 후)" 작업(T030·T039·T055)을 한 PR로
5. Polish → OpenAPI·캐시 헤더·모바일·다국어 확인, CI E2E 실행 확인, quickstart 전체 검증

### Parallel Team Strategy

1. 함께 Setup + Foundational
2. Foundational이 끝나면:
   - 개발자 A: Phase 3(US1) → Phase 4(US2) backend
   - 개발자 B: Phase 5(US3) backend → front
   - 개발자 C: Phase 6(US4) front(003 API만 씀) → Phase 4(US2) front
3. 같은 파일을 고치는 연결 작업은 머지 순서를 맞춘다(Phase Dependencies, 004·005·003 의존)

---

## Notes

- [P] = 다른 파일, 끝나지 않은 작업에 의존하지 않음
- [Story] = spec 스토리 번호(US1~US4)
- 각 PR 설명에 스펙 경로 `blog-docs/specs/006-admin-consoles`를 적는다(헌법 개발 흐름 6). backend·front 브랜치는 같은 이름을 쓴다(예: `feat/006-core`)
- 엔티티는 API 응답으로 직렬화하지 않고 DTO record를 쓴다. 연관관계는 모두 LAZY, 목록은 fetch join 또는 DTO projection, 목록 테스트에는 `QueryCounter`
- 대시보드 캐시는 backend 1대 전제(001 R26)다. 서버를 늘려도 캐시는 서버마다 따로라 최대 지연(5분)만 같고 수치가 서버마다 잠깐 다를 수 있다(허용)
- 관리자 변경 API를 더하는 모든 후속 스펙은 T046 표와 006 data-model `action` 표, `AuditActions`, front `audit` namespace에 행을 더한다
- 테스트가 실패하는 것을 먼저 확인하고, 작업 단위로 커밋한다
