# Implementation Plan: 관리 화면 (시스템 관리자 콘솔과 블로그 관리)

**Branch**: `006-admin-consoles` (계획 문서는 `docs/006-plan`) | **Date**: 2026-10-07 | **Spec**: [spec.md](./spec.md)

**Status**: Phase 1 완료 (research, contracts, quickstart, tasks 작성). 다음 단계는 `/speckit-analyze` 후 `/speckit-implement`.

**Input**: Feature specification from `/specs/006-admin-consoles/spec.md`

## Summary

006은 두 관리 화면의 **구조와 공통 규칙**을 정하는 스펙이고, 메뉴 대부분은 다른 스펙이 이미 만들었거나 만들 예정이다(spec 머리말 "각 기능 스펙을 구현할 때 채운다"). 그래서 이 계획은 새로 만드는 것보다 **이미 있는 것을 확인하고 빈 곳만 채우는** 계획이다. 현재 코드(blog-backend·blog-front main, 001~003 완료, 004 Phase 1~4 머지, 004 Phase 5~8은 `feat/004-rest`에서 구현 중, 005는 계획만)를 하나씩 대조한 결과는 [research.md](./research.md) "현재 코드에서 확인한 것"에 있다.

| 영역 | 이미 있음(다른 스펙) | 006이 만드는 것 |
|---|---|---|
| 블로그 관리(US1) | 001: `/:handle/manage` 레이아웃·블로그 전환·`/manage` 진입점·대시보드·글 관리(필터·검색·일괄 작업·휴지통)·카테고리·댓글·설정·noindex. 002: 피드 설정. 004: 방명록·꾸미기·통계·대시보드 방문자·방명록(Phase 5~8: 백업·차단·보호/예약 필터) | FR-099 순서의 메뉴 정의 한 곳(`app/manage/links.ts`, 스펙별 공개 여부), 관리·콘솔 응답의 `X-Robots-Tag: noindex`(FR-098 보강), **모든 `/blogs/{h}/manage/**` API의 주인 외 거부 행렬 테스트**(AS5), Independent Test·SC-016 E2E |
| 콘솔 구조·운영(US2) | 003: `/admin` 레이아웃·`AdminAccessFilter`(DB의 현재 권한, 아니면 404)·주제·포털 추천·포털 제외·포털 설정·회원별 블로그 한도 API. 005(계획): 회원 검색·상세·정지, 신고, 콘텐츠 숨김 API·숨긴 글 목록, 스팸 방어. 007: 외부 블로그 관리 | 상단 메뉴 **"시스템 관리"** 링크(지금 없음), FR-102 순서의 콘솔 메뉴(스펙별 공개 여부), **콘솔 대시보드**(FR-103, `/admin` 첫 화면), **콘텐츠 관리 검색**(글·댓글·방명록 전체 검색과 숨김 상태 목록, 숨김·해제는 005 API), **예약어**(읽기 전용), **서비스 설정**(읽기 전용), **모든 `/api/v1/admin/**` API의 비관리자 404 행렬 테스트**(SC-015) |
| 작업 기록·권한(US3) | 003: `admin_audit_logs` 쓰기(`AdminAuditService`, 같은 트랜잭션), 첫 최고 관리자 지정(`SuperAdminBootstrap`) | **작업 기록 조회 API·화면**(FR-106), **1년 보관 정리 작업**, **관리자 권한 부여·회수**(FR-105, 최고 관리자만, 마지막 최고 관리자 보호), **모든 관리자 변경 API가 기록을 남기는지 강제하는 테스트**(SC-017) |
| 릴리스 노트(US4) | 003: 관리 API 9개(`/api/v1/admin/release-notes/**`)와 독자 화면 `/updates/**`(결정 4번 "화면은 006") | **릴리스 노트 관리 화면**(`/admin/release-notes/**`: 목록·만들기·수정(언어별 탭)·미리보기·게시·게시 중단·삭제·수정본) |

기술 접근: 새 테이블·컬럼 없이 001 `users.role`·`users.time_zone`, 003 `admin_audit_logs`·릴리스 노트 테이블, 001~005 콘텐츠 테이블을 읽는다. 대시보드는 쿼리 6회를 관리자 시간대별 Caffeine 캐시(5분, FR-103의 "최대 5분 지연")로 감싸고, 처리 대기 신고 수는 003 `BlogPenaltyPolicy`처럼 인터페이스 자리(`PendingReportCounter`)를 두어 005가 채운다. 권한 변경은 001 data-model의 규칙대로 `SELECT ... FOR UPDATE`로 최고 관리자 행을 잠근 뒤 남는 수를 확인하고, 반영은 003 `AdminAccessFilter`가 요청마다 DB를 읽으므로 따로 할 일이 없다. SC-015·SC-017은 "테스트를 하나씩 쓴다"가 아니라 **Spring MVC 매핑 목록을 훑는 행렬 테스트**로 강제해, 이후 스펙이 관리자 API를 더해도 빠지지 않게 한다. **새 라이브러리 없음, 필수 스키마 변경 없음**(아래 "스키마 변경"에 marco 승인이 필요한 선택 인덱스 제안 4개). 세부 근거는 [research.md](./research.md).

## Technical Context

**Language/Version**: backend Java 21 / front TypeScript 5.9, Node.js 22 LTS (001~005와 같음)

**Primary Dependencies**:
- backend(001~005 그대로): Spring Boot 4.1.1(Web MVC, Security, Data JPA, Validation), QueryDSL OpenFeign 7.x, Hibernate 7, Caffeine, commonmark-java + OWASP HTML Sanitizer(릴리스 노트 미리보기는 003 `ReleaseNoteRenderer` 재사용), springdoc-openapi. **새 의존성 없음**
- front(001~005 그대로): React 19, React Router 8.4 framework 모드, Vite 8, Express 5, i18next + react-i18next. **새 npm 의존성 없음**: 대시보드 추이 막대는 004 `components/manage/VisitorChart.tsx`(SVG)를 일반화해 쓴다

**Storage**: MySQL 8(InnoDB, utf8mb4). 006 테이블(`admin_audit_logs`, `release_notes`, `release_note_contents`, `release_note_revisions`)과 001 `users.role`(USER / ADMIN / SUPER_ADMIN)·`users.max_blogs`·`users.time_zone`, 인덱스 `idx_users_role_status`·`idx_admin_audit_logs_*` 4개·`idx_release_notes_status_version`이 Crowfoot 문서 "blog 1.0"(`db/schema-mysql.sql`)에 이미 있다. 대시보드·콘텐츠 검색은 001~005 테이블을 읽기만 한다

**Testing**: 001~005와 같음. JUnit 5, `@WebMvcTest` + `WebMvcTestSupport`, Mockito, `@JpaRepositoryTest`(H2) + `QueryCounter`, 시각 고정 `MutableClock`, Caffeine 시각 `Ticker`. `@SpringBootTest`(H2)는 관리자·관리 API 접근 행렬, 작업 기록 강제, 권한 변경 동시성 확인에만. **MySQL 전용 테스트는 콘텐츠 관리의 글 제목 FULLTEXT 검색 1개**(`@MySqlRepositoryTest`, 002 방식, 나머지 조건은 H2). **Testcontainers 없음**. JaCoCo 라인 80%. front Vitest(80%) + Playwright E2E(실제 backend, `requireBackend()`·`requireAdmin()`, 대시보드 수치 확인은 `requireAdminTestSettings()`) — CI `e2e-backend` 잡과 nightly에 환경 변수를 더해 **실제로 돈다**(결정 표 25번)

**Target Platform**: Linux 서버 1대(backend 1대 전제, 001 R26 — 대시보드 캐시가 이 전제에 기댄다), 최신 데스크톱/모바일 브라우저(블로그 관리는 폭 360px부터, 콘솔은 데스크톱 기준·모바일은 조회 위주, spec Assumptions)

**Project Type**: 웹 서비스(REST API + SSR 웹 앱), 저장소 3개

**Performance Goals**: 콘솔 대시보드는 캐시가 비었을 때 쿼리 6회 이하, 캐시 적중 시 0회(관리자 확인 1회 제외). 작업 기록 목록은 조건과 무관하게 쿼리 2회(목록 + 개수, 관리자 닉네임 JOIN). 콘텐츠 검색은 쿼리 2회(+ 글 목록의 블로그·작성자 JOIN). 권한 변경은 잠금 1회 + 변경 1회 + 기록 1회. SC-016(원하는 글을 찾아 수정 화면까지 30초)은 E2E에서 시간 측정

**Constraints**: 일반 회원·비로그인의 관리자 API 접근 성공 0건(SC-015, 모든 `/api/v1/admin/**` 매핑 행렬), 관리자 변경 작업의 작업 기록 누락 0건(SC-017, 모든 변경 매핑 행렬), 다른 회원의 블로그 관리 API 성공 0건(AS5), 관리자에게도 비밀번호·비공개 글 본문·이메일 원문 노출 0건(FR-104), 작업 기록 수정·삭제 API 0개, 관리 화면 검색 엔진 수집 0건(FR-098), 커버리지 80%, 번역 누락 0건, N+1 금지

**Scale/Scope**: 새 관리자 API 11개(대시보드 1, 콘텐츠 검색 3, 예약어 1, 서비스 설정 1, 작업 기록 3, 관리자 목록 1, 권한 변경 1)와 프로퍼티 4개, 001~005 API 변경 없음(응답 필드 추가도 없음). 새 화면 14개(`/admin` 대시보드, `/admin/contents/posts`·`comments`·`guestbook`, `/admin/reserved-handles`, `/admin/settings`, `/admin/admins`, `/admin/audit-log`·`/:id`, `/admin/release-notes`·`/new`·`/:id`·`/:id/revisions`·`/:id/revisions/:no`), 001~005 화면 변경 6곳(공통 상단 "시스템 관리", 콘솔 레이아웃 메뉴, 블로그 관리 레이아웃 메뉴, 005 회원 상세의 "관리자 권한", 005 숨긴 글 목록을 콘텐츠 관리로 흡수, 003 `/admin` 리다이렉트를 대시보드로)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| 원칙 | 확인 | 결과 |
|---|---|---|
| I. 스펙이 먼저다 | spec.md 확정(NEEDS CLARIFICATION 0개, checklist 통과). 이 plan은 FR-096~106, FR-160, FR-167·168, SC-015~017 중 다른 스펙이 맡지 않은 몫만 다룬다(위 Summary 표, research A1). 메뉴 표의 "출처"가 다른 스펙인 기능(회원 정지·신고·스팸은 005, 외부 블로그는 007, 방명록·백업·차단은 004)은 만들지 않고 메뉴 자리만 맞춘다. 모호한 점은 tasks.md "구현 전 결정 사항"에 기본값으로 기록(marco "묻지 말고 진행") | 통과 |
| II. 세 저장소, 두 실행 파트 | 두 관리 화면 모두 front 안의 화면(spec Assumptions), 별도 앱·도메인 없음. 대시보드 캐시·작업 기록 정리 작업은 backend 프로세스 안(Caffeine, `@Scheduled`). front는 REST API만 호출 | 통과 |
| III. 테스트 우선·커버리지 | 각 스토리의 테스트 작업이 구현보다 앞섬, 인수 시나리오마다 테스트(tasks.md). SC-015·SC-017은 매핑 행렬 테스트로 앞으로 더해질 API까지 강제. H2 + 쿼리 수 확인, MySQL 전용은 FULLTEXT 1개, Testcontainers 없음, 80% 게이트 유지. E2E는 CI에서 실제 backend로 돈다 | 통과 |
| IV. 보안과 공개 범위 | 콘솔은 003 `AdminAccessFilter`(요청마다 DB의 현재 권한·상태, 아니면 404) 한 곳. 최고 관리자 전용 동작(권한 변경, 작업 기록의 요청 IP)은 서비스에서 DB 권한을 다시 확인(403). 블로그 관리는 001 `BlogAccess.requireOwnedActiveBlog` 한 곳. 콘텐츠 검색 응답에 본문·비밀 글 내용·이메일 없음. 작업 기록은 INSERT·조회만(수정·삭제 API 없음), 요청 IP는 암호문 저장·최고 관리자에게만 복호화 표시. noindex는 meta + `X-Robots-Tag` + robots.txt | 통과 |
| V. SSR | 모든 관리 화면은 SSR + `action` 폼(JS 없이 동작). 릴리스 노트 미리보기만 JS가 있으면 `useFetcher`, 없으면 "미리보기" 제출 버튼이 같은 화면을 다시 그린다 | 통과 |
| VI. 단순함 | 새 라이브러리 없음. 새 캐시 1개(대시보드), 새 정기 작업 1개(작업 기록 정리)만 추가(Complexity Tracking). 메뉴 공개 여부는 런타임 기능 플래그가 아니라 코드 상수(스펙이 머지될 때 바꿈) | 통과 |
| VII. 다국어 우선 | 새 문구는 `admin`·`manage`·`common`·`errors`와 새 namespace `audit`(작업 종류 이름 약 60개)에 4개 언어로. 예약어·설정 키·작업 기록의 변경 전후 값(JSON)은 번역하지 않음. 새 오류 코드 3개(`LAST_SUPER_ADMIN`·`USER_NOT_ACTIVE`는 005와 공유, `CANNOT_CHANGE_OWN_ROLE`) 번역. 대시보드 날짜 경계는 관리자 시간대(001 FR-153) | 통과 |
| 기술 제약 | Java 21, Spring Boot 4.1.1, JPA + QueryDSL(OpenFeign), N+1 금지, Crowfoot 스키마(필수 DDL 없음, 선택 제안은 승인 절차), 공통 응답 틀(실제 HTTP 상태, 문자열 `resultCode`, 페이지는 `totalCount`), 개인정보 `blog.crypto.*`, 운영 설정은 `blog.*` 프로퍼티 | 통과 |

**Phase 1 이후 재확인**: research, contracts(api.md, routes.md), quickstart, tasks 작성 후 원칙 I~VII을 다시 점검했고 위반 없음. 설계 규칙과 다르게 만든 곳(권한 변경의 `PUT /admin/users/{id}/role` 멱등 교체, 콘텐츠 검색의 "범위 없는 키워드 거부")은 contracts/api.md에 이유를 적었다.

## 스키마 변경

**필수 DDL은 없다.** 006 data-model의 테이블·인덱스·외래 키가 모두 `db/schema-mysql.sql`(Crowfoot 문서 "blog 1.0", migrations/0001-baseline.sql)에 있다. 006 쿼리를 하나씩 대조했다.

| 쿼리·쓰기 | 쓰는 테이블·컬럼·인덱스·제약 | 비고 |
|---|---|---|
| 관리자 확인(요청마다) | `users` PK + `role`·`status` | 003 `DatabaseAdminRoleLookup` 그대로 |
| 관리자 목록 | `idx_users_role_status` (role, status) | `role IN ('ADMIN','SUPER_ADMIN')` |
| 권한 변경·마지막 최고 관리자 잠금 | `idx_users_role_status` + `SELECT id FROM users WHERE role = 'SUPER_ADMIN' AND status = 'ACTIVE' FOR UPDATE`, 대상 행 PK `FOR UPDATE` | 006 data-model "001 테이블 변경" 규칙 |
| 작업 기록 쓰기 | `admin_audit_logs`, `fk_admin_audit_logs_admin` | 003 `AdminAuditService`, 동작 값만 추가 |
| 작업 기록 목록(기간) | `idx_admin_audit_logs_created` (created_at) | 기본 최근 7일, 최대 366일 |
| 작업 기록 목록(관리자·기간) | `idx_admin_audit_logs_admin_created` (admin_id, created_at) | |
| 작업 기록 목록(작업 종류·기간) | `idx_admin_audit_logs_action_created` (action, created_at) | `action IN (...)` 묶음 필터 |
| 작업 기록 목록(대상) | `idx_admin_audit_logs_target` (target_type, target_id) | 회원 상세·릴리스 노트에서 "이 대상의 기록" |
| 작업 기록 1년 정리 | `idx_admin_audit_logs_created` | id를 모아 500건씩 삭제 |
| 대시보드 전체 회원·블로그·공개 글 수 | `users.status`, `blogs.status`, `posts`의 `idx_posts_status_scheduled` 앞 컬럼 `status = 'PUBLISHED'` + `visibility` | 5분 캐시 |
| 대시보드 오늘·7일 가입 | `users.created_at` | **인덱스 없음 → 아래 제안 1**(없으면 5분마다 `users` 전체 훑기) |
| 대시보드 오늘·7일 발행 | `posts.published_at`(최초 발행 시각) | **인덱스 없음 → 아래 제안 2**(있는 인덱스는 모두 `blog_id`·`topic_id`가 앞) |
| 대시보드 오늘 댓글 | `comments.created_at` | **인덱스 없음 → 아래 제안 3** |
| 대시보드 처리 대기 신고 | `idx_reports_status_created` (005) | 005가 `PendingReportCounter` 구현 |
| 콘텐츠 관리: 글 검색 | 제목 `ft_posts_title`(FULLTEXT ngram, 002), 블로그 `uk_blogs_handle` → `idx_posts_blog_status_visibility_published`, 작성자 `idx_blogs_user_status` → 같은 인덱스, 상태만 `idx_posts_status_scheduled` | 본문 컬럼은 읽지 않음 |
| 콘텐츠 관리: 댓글 검색 | 글 `idx_comments_post_created`, 작성자 `idx_comments_user`, 블로그는 글 IN → `idx_comments_post_created`, 범위 없는 최신 목록은 PK 역순 | 키워드는 범위 안에서만 `LIKE`(결정 표 9번) |
| 콘텐츠 관리: 숨긴 댓글 전체 | `comments.status = 'HIDDEN'` | **인덱스 없음 → 아래 제안 3**(같은 인덱스) |
| 콘텐츠 관리: 방명록 검색·숨긴 방명록 전체 | 블로그 `idx_guestbook_entries_blog_status_created`, 작성자 `idx_guestbook_entries_user`, 상태만은 인덱스 없음 | **아래 제안 4** |
| 회원 상세의 "이 회원 대상 기록" | `idx_admin_audit_logs_target` | 005 회원 상세 화면에 링크 |
| 릴리스 노트 관리 | 003이 쓰는 그대로(`uk_release_notes_version`, `idx_release_notes_status_version`, `uk_release_note_revisions_note_revision`) | backend 변경 없음 |

엔티티는 새로 만들지 않는다(`AdminAuditLog`·`ReleaseNote*`는 003, `User`는 001). `AdminAuditLog`는 `@Immutable`이라 정리 작업의 삭제는 별도 리포지토리의 벌크 DELETE로 한다(`EntitySchemaValidationTest` 변화 없음).

### marco 승인이 필요한 선택 DDL 제안 (지금 구현은 이것 없이 동작)

아래 네 인덱스는 1.0 규모(회원 수천, 글·댓글 수만)에서는 없어도 된다. 대시보드는 5분 캐시라 5분에 한 번 훑고, 숨김 목록은 숨긴 것이 적어 `LIMIT`으로 끝난다. 규모가 커지면 전체 훑기를 피하려고 필요하다. 넣기로 하면 [db/README.md](../../db/README.md) 절차(data-model·erd.md → Crowfoot 문서 → **Crowfoot `plan_migration` → marco 승인** → `apply_migration` → `migrations/NNNN-*.sql` → `schema-mysql.sql`·backend 테스트 스냅숏)를 따른다. 이 계획 단계에서는 Crowfoot 문서와 DB를 바꾸지 않았다(결정 표 27번).

```sql
-- 제안 1: 콘솔 대시보드의 오늘·최근 7일 가입자 수 (006 FR-103)
--   쿼리: SELECT COUNT(*) FROM users WHERE created_at >= :from AND created_at < :to
--         SELECT DATE(CONVERT_TZ(...)), COUNT(*) ... WHERE created_at >= :sevenDaysAgo GROUP BY 1 (날짜 묶기는 애플리케이션에서)
CREATE INDEX idx_users_created ON users (created_at ASC);

-- 제안 2: 콘솔 대시보드의 오늘·최근 7일 발행 글 수 (006 FR-103, posts.published_at = 최초 발행 시각)
--   쿼리: SELECT published_at FROM posts WHERE published_at >= :sevenDaysAgo
CREATE INDEX idx_posts_published_at ON posts (published_at ASC);

-- 제안 3: 콘솔 대시보드의 오늘 댓글 수와 콘텐츠 관리의 숨긴 댓글 전체 목록 (006 FR-102·103, 005 HIDDEN)
--   쿼리: SELECT COUNT(*) FROM comments WHERE status IN ('ACTIVE','HIDDEN','DELETED') AND created_at >= :from
--         SELECT ... FROM comments WHERE status = 'HIDDEN' ORDER BY created_at DESC LIMIT 20
CREATE INDEX idx_comments_status_created ON comments (status ASC, created_at ASC);

-- 제안 4: 콘텐츠 관리의 숨긴 방명록 전체 목록 (006 FR-102, 005 HIDDEN)
--   쿼리: SELECT ... FROM guestbook_entries WHERE status = 'HIDDEN' ORDER BY created_at DESC LIMIT 20
CREATE INDEX idx_guestbook_entries_status_created ON guestbook_entries (status ASC, created_at ASC);
```

승인되지 않아도 기능은 같다(5분마다 세 테이블 훑기, 숨김 목록은 `LIMIT`까지 훑기). 승인되면 코드 변경 없이 인덱스만 쓰인다. 005의 선택 제안 `idx_users_nickname`(관리자 회원 닉네임 검색)은 006 관리자 권한 화면의 회원 찾기도 같은 API를 쓰므로 함께 판단하면 된다.

**데이터 보정 없음.** 첫 최고 관리자는 003 `SuperAdminBootstrap`(프로퍼티 `blog.admin.bootstrap-super-admin-email`)이 이미 지정한다.

## Project Structure

### Documentation (this feature)

```text
specs/006-admin-consoles/
├── spec.md              # 기능 스펙
├── plan.md              # 이 문서
├── research.md          # Phase 0: 현재 코드 대조와 기술 결정 (A1~A14)
├── data-model.md        # Phase 1: 테이블 (스펙 단계에서 작성, plan에서 확정한 값만 보탬)
├── quickstart.md        # Phase 1: 실행·수동 검증 시나리오
├── contracts/
│   ├── api.md           # 006 REST API 계약(새 관리자 API, 오류 코드, 프로퍼티)
│   └── routes.md        # 006 화면과 001~005 화면 변경
├── checklists/requirements.md
└── tasks.md             # Phase 2: 작업 목록과 구현 전 결정 사항
```

### Source Code

001~005 구조에 아래를 더한다. 패키지 안 구성은 001과 같이 `controller`, `service`, `repository`, `domain`, `dto`, `job`. 관리자 API는 003이 만든 `admin/*` 아래 메뉴별 패키지에 둔다.

```text
blog-backend/src/main/java/net/java21/blog/backend/
├── admin/                    # (003) AdminAccessFilter·AdminRoleLookup·SuperAdminBootstrap·AdminProperties
│   ├── SuperAdminGuard.java  #   (새, 005와 공용) 최고 관리자 행 잠금·남는 수 확인, 요청자가 SUPER_ADMIN인지 DB로 확인
│   ├── dashboard/            # (새) AdminDashboardController·AdminDashboardService(Caffeine, 관리자 시간대별)·
│   │                         #   AdminDashboardQueryRepository·PendingReportCounter(인터페이스)·NoPendingReportCounter, dto
│   ├── content/              # (005 숨김 API) + (새) AdminContentSearchController·AdminContentSearchRepository
│   │                         #   (글·댓글·방명록 검색, 글 제목 FULLTEXT), dto
│   ├── info/                 # (새) AdminInfoController — 예약어 목록, 서비스 설정(읽기 전용)
│   ├── audit/                # (003 쓰기) + (새) AdminAuditLogController·AdminAuditLogService·AdminAuditLogQueryRepository,
│   │                         #   AdminAuditPurgeRepository·AdminAuditPurgeJob, AuditActions.ALL(전체 동작 목록), dto
│   └── user/                 # (003 블로그 한도, 005 검색·정지) + (새) AdminRoleService·AdminRoleController(권한 변경·관리자 목록), dto
├── common/job/JobsProperties.java  # (001) + auditPurgeCron
└── common/error/ErrorCode.java     # (001) + CANNOT_CHANGE_OWN_ROLE (+ 005와 공유: LAST_SUPER_ADMIN, USER_NOT_ACTIVE)
blog-backend/src/main/resources/application.yml   # blog.admin.dashboard-cache-ttl, blog.admin.audit-retention, blog.jobs.audit-purge-cron

blog-front/app/
├── admin/links.ts                         # (003) FR-102 순서의 메뉴 정의(스펙별 available), ADMIN_HOME = "/admin"
├── admin/roles.ts                         # (새) isAdmin·isSuperAdmin(세션 role)
├── admin/auditActions.ts                  # (새) 작업 종류 코드 목록·묶음(필터 선택지)
├── manage/links.ts                        # (001) + FR-099 순서의 MANAGE_MENU(레이아웃에서 옮김, 스펙별 available)
├── routes/admin/dashboard.tsx             # `/admin` index(003 index.ts 리다이렉트를 대체)
├── routes/admin/contents.tsx, contents.posts.tsx, contents.comments.tsx, contents.guestbook.tsx
├── routes/admin/reserved-handles.tsx, service-settings.tsx, admins.tsx, audit-log.tsx
├── routes/admin/release-notes.tsx, release-note-edit.tsx, release-note-revisions.tsx, release-note-revision.tsx
├── components/admin/DashboardCards.tsx, TrendChart.tsx, ContentSearchForm.tsx, AuditLogTable.tsx, JsonDiff.tsx,
│                     RoleForm.tsx, ReleaseNoteEditor.tsx, LanguageTabs.tsx, MarkdownPreview.tsx
├── components/charts/DailyBarChart.tsx    # 004 VisitorChart를 일반화(블로그 통계와 콘솔 추이가 함께 씀)
├── components/layout/Header.tsx           # (001) + 관리자에게 "시스템 관리"(/admin)
└── locales/{ko,en,ja,zh-CN}/audit.json    # (새) + admin·manage·common·errors에 키 추가
blog-front/server/middleware/robotsHeader.ts  # (새) /admin/**·/:handle/manage/**·/manage 응답에 X-Robots-Tag: noindex, nofollow
blog-front/.github/workflows/ci.yml, e2e.yml  # e2e-backend·nightly backend 환경 변수(BLOG_ADMIN_DASHBOARD_CACHE_TTL)와 E2E_ADMIN_TEST_SETTINGS
```

**Structure Decision**: 001의 도메인별 패키지 구조와 003의 `admin/{메뉴}` 구조를 따른다. 대시보드·예약어·서비스 설정은 다른 도메인에 속하지 않는 콘솔 전용 읽기라 `admin/dashboard`·`admin/info`에 둔다. 콘텐츠 검색은 005의 숨김 API(`admin/content/AdminContentController`)와 같은 메뉴지만 파일을 나눠(`AdminContentSearchController`) 005와 병렬로 만들 수 있게 한다. 권한 변경은 회원 단위 동작이라 `admin/user`에 둔다. 최고 관리자 잠금은 005 정지와 006 권한 변경이 함께 쓰므로 `admin/SuperAdminGuard`로 둔다.

## 구현 순서 (사용자 스토리 기준)

spec의 스토리 번호와 우선순위를 그대로 쓴다(결정 표 1번).

| 단계 | 스토리 | 핵심 산출물 | FR |
|---|---|---|---|
| 0 | 기반 | 프로퍼티, 오류 코드, 작업 종류 전체 목록(`AuditActions.ALL`), `SuperAdminGuard`, 메뉴 정의 두 곳(스펙별 공개 여부), 관리 화면 `X-Robots-Tag`, front 번역 namespace·모델 타입·E2E 도구·CI 환경 변수, **관리자 API 비관리자 404 행렬 테스트**(SC-015) | FR-096, FR-097, FR-098, SC-015 |
| 1 | US1 블로그 관리 (P1) 🎯 MVP | FR-099 순서 메뉴, 블로그 관리 API 주인 외 거부 행렬 테스트(AS5), 블로그 전환·대시보드·글 찾기 E2E(Independent Test, SC-016), 모바일 확인 | FR-096~101, SC-016 |
| 2 | US2 콘솔 운영 (P2) | 상단 "시스템 관리", 콘솔 메뉴, 대시보드 API·화면(`/admin` 첫 화면), 콘텐츠 관리 검색(+ 005 숨김 연결), 예약어·서비스 설정(읽기 전용) | FR-096, FR-097, FR-102, FR-103, FR-104(검색 범위), FR-160(서비스 설정 표시) |
| 3 | US3 작업 기록과 권한 (P3) | 작업 기록 조회 API·화면, 1년 정리 작업, 관리자 목록·권한 부여·회수(최고 관리자만, 마지막 보호), 005 회원 상세에 "관리자 권한", **관리자 변경 API 작업 기록 강제 행렬 테스트**(SC-017) | FR-105, FR-106, SC-017 |
| 4 | US4 릴리스 노트 관리 (P4) | `/admin/release-notes/**` 화면(003 API 사용), 미리보기·충돌 안내·게시·게시 중단·삭제·수정본 | FR-167, FR-168 |

각 단계는 끝날 때 해당 스토리의 Independent Test를 E2E로 통과해야 한다. 단계 1~4는 단계 0 이후 서로 독립이다(US4는 003 API만, US3의 화면 하나만 005 회원 상세에 기댐). 같은 파일(`ErrorCode`, `AuditActions`, `SecurityConfig`(변경 없을 예정, 확인만), `admin/links.ts`, `routes/admin/layout.tsx`, `manage/links.ts`, `routes/manage/layout.tsx`, `routes.ts`, `Header.tsx`, `errors.json`, `admin.json`, `playwright.config.ts`, `tests/e2e/support/backend.ts`, 두 workflow)을 고치는 작업은 순서대로 머지한다.

**004·005 진행 중 작업과의 관계**:
- 004 Phase 5~8(보호·예약 글, 백업, 차단)은 `feat/004-rest`에서 구현 중이다. 006은 블로그 관리 메뉴(`manage/layout.tsx`·`manage/links.ts`)와 관리 글 목록 필터를 함께 고치므로 **004가 main에 머지된 뒤 시작한다**(005와 같은 조건).
- 005는 계획만 있다. 006은 **005와 병렬로 진행할 수 있다**. 005에 기대는 작업(대시보드의 처리 대기 신고 수, 콘텐츠 관리의 숨김·해제 버튼과 숨긴 댓글·방명록, 회원 상세의 "관리자 권한" 영역)은 tasks.md에 "005 머지 후"로 표시했고, 그 전에는 자리(인터페이스·숨긴 메뉴)만 둔다. 공용 파일·코드(`SuperAdminGuard`, `LAST_SUPER_ADMIN`·`USER_NOT_ACTIVE`, `AuditActions.TARGET_USER`, E2E `adminRequest`)는 먼저 머지하는 쪽이 만들고 다른 쪽은 재사용한다(tasks.md "004·005·003 의존" 표).

**범위 밖(다른 스펙)**:
- 005: 회원 검색·상세·정지·해제(FR-104 화면 대부분), 신고 관리, 콘텐츠 숨김·해제 API, 스팸 방어 설정, 블로그 관리 "받은 트랙백". 006은 이 메뉴들의 자리와 순서만 맞춘다.
- 007: 콘솔 "외부 블로그 관리", 블로그 관리 "외부 블로그". 메뉴 자리만(숨김).
- 004: 블로그 관리 "백업"·"차단 목록"·보호/예약 필터(feat/004-rest).
- spec Assumptions 범위 밖: 관리자 2단계 인증(OTP), 관리자의 남의 블로그 관리 화면 대리 진입(Edge Cases "없다"), 회원당 기본 블로그 수의 콘솔 편집, 별도 관리 도메인, 릴리스 노트 본문 이미지 올리기.

## Complexity Tracking

| 도입 | 이유 | 더 단순한 대안을 쓰지 않은 이유 |
|---|---|---|
| 대시보드 Caffeine 캐시(관리자 시간대별, 5분) | FR-103 "최대 5분 지연 허용", 대시보드 열 때마다 큰 테이블 COUNT 6회 | 매번 계산은 인덱스가 없는 시각 조건(선택 제안 1~3)을 요청마다 훑음. 별도 집계 테이블은 스키마 변경과 집계 작업이 필요 (research A3) |
| 작업 기록 정리 정기 작업 | FR-106 "1년간 보관", 006 data-model `blog.admin.audit-retention` | 정리하지 않으면 보관 기간 규정을 어김. MySQL 파티션·이벤트는 Crowfoot 스키마 밖 운영 장치라 쓰지 않음 (research A7) |
| 매핑 행렬 테스트 2종(SC-015, SC-017) + 블로그 관리 1종(AS5) | SC-015 "모든 관리자 API 권한 테스트 기준", SC-017 "100%" | 엔드포인트마다 손으로 테스트를 쓰면 새 API가 빠져도 알 수 없음. 행렬 테스트는 매핑 목록을 읽어 빠진 것을 실패로 만든다 (research A8·A10) |
