# Implementation Plan: 트랙백과 운영 (신고·관리자·트랙백·스팸 방어)

**Branch**: `005-trackback-moderation` (계획 문서는 `docs/005-plan`) | **Date**: 2026-10-07 | **Spec**: [spec.md](./spec.md)

**Status**: Phase 1 완료 (research, contracts, quickstart, tasks 작성). 다음 단계는 `/speckit-analyze` 후 `/speckit-implement`.

**Input**: Feature specification from `/specs/005-trackback-moderation/spec.md`

## Summary

여러 사람이 쓰는 서비스의 운영 장치를 더한다. 회원은 글·댓글·방명록 글·트랙백을 사유를 골라 신고하고, 회원이 아닌 권리자는 권리 침해 신고 양식(대상 주소·권리 근거·연락 이메일, CAPTCHA)으로 요청한다. 관리자는 시스템 관리자 콘솔에서 대상별로 묶인 신고를 보고 콘텐츠를 숨기거나(HIDDEN) 기각하며, 회원을 찾아 정지·해제한다. 정지된 회원은 로그인할 수 없고 그 회원의 모든 블로그는 "이용이 제한된 블로그"로 안내된다(US1, FR-040~043). spec에 스토리가 없는 공통 스팸 방어(FR-141~144: CAPTCHA, 작성 속도 제한, 금칙어, 반복 댓글 차단)는 FR에서 Independent Test를 만들어 US2로 계획했다. 블로그 사이의 트랙백 주고받기(FR-049~055, SC-009)는 소유자 지시대로 가장 낮은 우선순위인 US3으로 마지막에 둔다(spec의 US2, 결정 표 1번).

기술 접근: 숨김은 001 노출 조각(`PostExposure`)이 이미 `status = PUBLISHED`만 목록에 넣으므로 `PostStatus.HIDDEN` 값과 `status_before_hidden`만 더하면 모든 공개 표면에서 빠진다. 댓글·방명록·트랙백은 각자의 `canRead` 한 곳(004 `CommentVisibility`·`GuestbookVisibility`)에 HIDDEN 규칙을 더한다. 정지는 001 `users.status = SUSPENDED`와 기존 `isActive()` 판단을 그대로 쓰고, 30분짜리 접근 토큰이 남는 문제는 정지 즉시 갱신 토큰 폐기 + 메모리 정지 목록(`SuspendedUserRegistry`)으로 막는다. 신고 대상 해석·조치는 대상 종류별 `ReportTargetHandler`로 나눠 007이 외부 글·외부 블로그 구현만 더하게 한다. 속도 제한·반복 스팸은 003 `system_settings` 키(`ratelimit.*`, `spam.*`) + Caffeine 고정 창 카운터, CAPTCHA는 `CaptchaVerifier`(운영 Cloudflare Turnstile, 개발 `none`, E2E `test`), 금칙어는 DB + 메모리 캐시다. 트랙백 받기는 001이 이미 비워 둔 `POST /{handle}/{postId}/trackback`(Origin 검사 제외·front 프록시 완료)에 TrackBack 1.2 XML 응답, 보내기는 커밋 후 전용 스레드 풀에서 JDK `HttpClient`로 보내고 내부망 주소를 막는다(`OutboundUrlGuard`, 007 피드 수집이 재사용). **새 라이브러리 없음, 필수 스키마 변경 없음**(아래 "스키마 변경"에 marco 승인이 필요한 선택 인덱스 제안 2개). 세부 근거는 [research.md](./research.md).

## Technical Context

**Language/Version**: backend Java 21 / front TypeScript 5.9, Node.js 22 LTS (001~004와 같음)

**Primary Dependencies**:
- backend(001~004 그대로): Spring Boot 4.1.1(Web MVC, Security, Data JPA, Validation, Mail), QueryDSL OpenFeign 7.x, Hibernate 7, Caffeine, commonmark-java + OWASP HTML Sanitizer, springdoc-openapi. **새 의존성 없음**: 트랙백 송신과 CAPTCHA 검증은 JDK `java.net.http.HttpClient`, 트랙백 XML 응답은 문자열 이스케이프(`HtmlUtils`), 송신 응답 파싱은 JDK `DocumentBuilder`(XXE 끔), 정규화는 `java.text.Normalizer`
- front(001~004 그대로): React 19, React Router 8.4 framework 모드, Vite 8, Express 5(`/:handle/:postId/trackback` 프록시는 001에 이미 있음), i18next + react-i18next. **새 npm 의존성 없음**: Turnstile 위젯은 공식 스크립트(`https://challenges.cloudflare.com/turnstile/v0/api.js`)를 CAPTCHA가 필요한 화면에서만 CSP nonce와 함께 불러온다(Complexity Tracking)

**Storage**: MySQL 8(InnoDB, utf8mb4). 005의 테이블(`reports`, `trackbacks`, `trackback_ping_logs`, `banned_words`)과 001·004 테이블의 005 몫(`blogs.trackback_enabled`, `posts.status_before_hidden`, `posts`·`comments`·`guestbook_entries`·`trackbacks.status`의 HIDDEN 값, `ck_reports_reporter`, `uk_reports_reporter_target`, `uk_trackbacks_post_source_url_hash`, 인덱스·외래 키), 003 `system_settings`(키 추가), 006 `admin_audit_logs`, 002 `notifications`(`REPORT_RESOLVED`·`REPORT` 값)가 Crowfoot 문서 "blog 1.0"(`db/schema-mysql.sql`)에 이미 있다

**Testing**: 001~004와 같음. JUnit 5, `@WebMvcTest` + `WebMvcTestSupport`, Mockito, `@JpaRepositoryTest`(H2) + `QueryCounter`, CHECK·UNIQUE는 엔티티 `@Check`·`@UniqueConstraint`로 H2에도, `@SpringBootTest`는 노출 매트릭스 HIDDEN·SUSPENDED 행 통합 확인과 트랙백 송수신 왕복만, 외부 HTTP는 JDK `com.sun.net.httpserver.HttpServer`로 띄운 테스트 서버(새 의존성 없음), **Testcontainers 없음, MySQL 전용 테스트 없음**(005 쿼리에 MySQL 전용 기능이 없다. 기존 `EntitySchemaValidationTest`만 실제 스키마로), JaCoCo 라인 80%. front Vitest(80%) + Playwright E2E(실제 backend, `requireBackend()`·`requireAdmin()`, 운영 시나리오는 `requireModerationTestSettings()`) — CI `e2e-backend` 잡과 nightly에 필요한 환경 변수를 더해 **실제로 돈다**(결정 표 29번)

**Target Platform**: Linux 서버 1대(backend 1대 전제, 001 R26 — 속도 제한·반복 스팸·트랙백 수신 제한·로그인 CAPTCHA 카운터, 정지 목록, 금칙어 캐시가 이 전제에 기댄다), 최신 데스크톱/모바일 브라우저(폭 360px부터)

**Project Type**: 웹 서비스(REST API + SSR 웹 앱), 저장소 3개

**Performance Goals**: 신고 접수·트랙백 수신은 요청당 쿼리 4회 이하. 쓰기 경로의 스팸 검사(속도·반복·금칙어)는 쿼리 0회(메모리). 트랙백 보내기는 발행 요청 시간에 영향 없음(커밋 후 비동기, 대상별 연결·응답 5초). 관리자 신고 목록은 대상 수와 무관한 쿼리 3회

**Constraints**: 숨김 글·숨김 댓글·방명록·트랙백과 정지 회원 콘텐츠가 작성자(와 관리자) 외에 노출 0건(001 SC-004, 노출 매트릭스 HIDDEN·SUSPENDED 행), 권리 침해 연락 이메일·트랙백 송신 IP 평문 저장 0건(001 FR-134), 트랙백 제목·요약의 스크립트 실행 0건(Edge Cases), 내부망 주소로의 서버 요청 0건(spec Assumptions), 관리자 API는 비관리자에게 404(006 FR-097), 커버리지 80%, 번역 누락 0건, N+1 금지

**Scale/Scope**: 새 공개 API 5개(신고, 권리 침해 신고, CAPTCHA 설정, 트랙백 목록, 트랙백 받기 XML), 새 주인 API 4개(받은 트랙백 관리 목록·삭제, 보낸 트랙백 기록, 내 신고 없음), 새 관리자 API 14개(신고 4, 콘텐츠 숨김 3, 회원 4, 금칙어 3)와 운영 설정 키 6개, 001~004 API 확장 9곳(블로그 설정, 블로그 조회 오류 코드, 발행 설정, 글 상세, 관리 글 목록 필터, 댓글·방명록 응답, 로그인·가입 요청, 알림 종류). 새 화면 7개(`/rights-request`, `/:handle/manage/trackbacks`, `/admin/reports`, `/admin/reports/:id`, `/admin/users`, `/admin/users/:id`, `/admin/spam`) + "이용이 제한된 블로그" 화면, 001~004 화면 변경 9곳(신고 버튼: 글 상세·댓글·방명록·트랙백, 글 상세 트랙백 영역, 발행 설정, 관리 글 목록, 블로그 설정, 가입·로그인·비회원 쓰기 CAPTCHA)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| 원칙 | 확인 | 결과 |
|---|---|---|
| I. 스펙이 먼저다 | spec.md 확정(NEEDS CLARIFICATION 0개, checklist 통과). 이 plan은 FR-040~043, FR-049~055, FR-141~144, SC-009와 006 spec의 005 몫(콘솔 회원·신고·콘텐츠 숨김·스팸 방어 메뉴, 블로그 관리 "받은 트랙백", 블로그 설정의 트랙백 허용)만 다룬다. spec에 스토리가 없는 FR-141~144는 FR에서 Independent Test를 만들어 US2로 계획했고, 외부 글·외부 블로그 신고(FR-040·041의 007 대상)는 대상 해석기 자리만 두고 007이 채운다. 모호한 점은 tasks.md "구현 전 결정 사항"에 기본값으로 기록(marco "묻지 말고 진행") | 통과 |
| II. 세 저장소, 두 실행 파트 | 카운터·캐시·송신 스레드 풀은 backend 프로세스 안(Caffeine, `@Async` 전용 실행기). CAPTCHA는 외부 검증 API를 backend가 호출할 뿐 새 실행 파트가 아님. Redis·큐·별도 작업 서버 없음. front는 REST API만 호출하고, 트랙백 경로는 001 프록시 그대로 | 통과 |
| III. 테스트 우선·커버리지 | 각 스토리의 테스트 작업이 구현보다 앞섬, 인수 시나리오마다 테스트(tasks.md), H2 + 쿼리 수 확인(엔티티 `@Check`로 H2에도 CHECK), MySQL 전용 테스트 없음, 외부 HTTP는 JDK 테스트 서버, Testcontainers 없음, 80% 게이트 유지. E2E는 CI에서 실제 backend로 돈다 | 통과 |
| IV. 보안과 공개 범위 | 노출은 001 `PostExposure` 한 곳(HIDDEN은 PUBLISHED가 아니므로 자동 제외), 댓글·방명록·트랙백은 각자 `canRead` 한 곳. 관리자 API는 003 `AdminAccessFilter`(DB의 현재 권한, 아니면 404). 정지는 로그인 거부 + 갱신 토큰 폐기 + 접근 토큰 무효(정지 목록). 연락 이메일·송신 IP는 AES-256-GCM, 응답에 암호문 없음. 트랙백 입력은 태그 제거 일반 텍스트, 송신은 내부망·리다이렉트 차단. 신고자 신원은 대상 작성자에게 보이지 않음 | 통과 |
| V. SSR | 권리 침해 신고 양식, 이용 제한 블로그 안내, 글 상세의 트랙백 목록·트랙백 주소(RDF 자동 발견 포함)는 SSR. 신고 버튼은 `action` 폼(JS 없이 동작). CAPTCHA 위젯만 JS가 필요하며(외부 위젯의 본질), 콘텐츠 열람에는 영향 없음 | 통과 |
| VI. 단순함 | 새 라이브러리 없음. 새 비동기 실행기 1개(트랙백 송신), 새 Caffeine 카운터 1종(공용 `RateLimiter`, 키 접두어로 용도 구분)과 캐시 2개(금칙어, 정지 목록), 외부 호출 1곳(CAPTCHA)만 추가(Complexity Tracking). 004의 비회원 IP 속도 제한(`RateLimitGuestWriteGuard`)은 공용 `RateLimiter`로 흡수해 장치 수를 줄인다 | 통과 |
| VII. 다국어 우선 | 새 문구는 `report`·`trackback`·`moderation` namespace와 `admin`·`manage`·`post`·`comment`·`guestbook`·`auth`·`notification`·`common`·`errors`에 4개 언어로. 사용자가 쓴 트랙백 제목·요약·블로그 이름, 금칙어는 번역하지 않음. 새 오류 코드 21개·필드 오류 코드 1개 번역. 권리 침해 처리 메일은 backend `messages_*.properties`(4개 언어)이며, 비회원은 언어 설정이 없어 접수 화면 언어를 메일 언어로 쓴다(결정 표 9번). 트랙백 XML 응답 메시지는 영어 고정(기계가 읽는 프로토콜) | 통과 |
| 기술 제약 | Java 21, Spring Boot 4.1.1, JPA + QueryDSL(OpenFeign), N+1 금지, Crowfoot 스키마(필수 DDL 없음, 선택 제안은 승인 절차), 공통 응답 틀(실제 HTTP 상태, 문자열 `resultCode`, 페이지는 `totalCount`), 개인정보 `blog.crypto.*`, 운영 설정은 `blog.*` 프로퍼티 기본값 + `system_settings` | 통과 |

**Phase 1 이후 재확인**: research, contracts(api.md, routes.md), quickstart, tasks 작성 후 원칙 I~VII을 다시 점검했고 위반 없음. 설계 규칙과 다르게 만든 곳(트랙백 받기의 XML 응답·200 고정, 관리자 콘텐츠 숨김의 PUT 멱등 생성, 신고 처리의 대상 단위 처리, 권리 침해 신고의 202)은 contracts/api.md에 이유를 적었다.

## 스키마 변경

**필수 DDL은 없다.** 005 data-model의 테이블·컬럼·CHECK·UNIQUE·인덱스·외래 키가 모두 `db/schema-mysql.sql`(Crowfoot 문서 "blog 1.0", migrations/0001-baseline.sql)에 있다. 005 쿼리를 하나씩 대조했다.

| 쿼리·쓰기 | 쓰는 테이블·컬럼·인덱스·제약 | 비고 |
|---|---|---|
| 회원 신고 저장·중복 거부 | `reports`, `uk_reports_reporter_target` (reporter_id, target_type, target_id), `ck_reports_reporter` | 엔티티 `@Check`·`@UniqueConstraint`로 H2에도 |
| 권리 침해 신고 저장 | `reports.channel = RIGHTS_REQUEST`, `reporter_id` NULL, `target_url`, `rights_basis`, `contact_email_enc` | NULL은 UNIQUE에 걸리지 않음(MySQL·H2 같음) |
| 관리자 신고 목록(대상별 묶음) | `idx_reports_status_created` (status, created_at) → GROUP BY target_type, target_id | 대상 미정 권리 침해 신고는 행 단위 |
| 한 대상의 신고 전체·일괄 처리 | `idx_reports_target` (target_type, target_id) | 조건부 UPDATE `status = 'PENDING'` |
| 처리 대기 신고 수 | `idx_reports_status_created` | 콘솔 메뉴 표시 |
| 회원 상세의 받은 신고 수 | `idx_reports_target_user` | 006 FR-104 |
| 포털 점수 감점(003 `BlogPenaltyPolicy`) | `idx_reports_target_blog_status` (target_blog_id, status) + `handled_at` 필터 | 블로그 목록 IN 1회 |
| 연락 이메일 파기(1년) | `reports.channel`, `contact_email_enc IS NOT NULL`, `handled_at` | 행이 적어 매일 1회 전체 훑기(결정 표 11번) |
| 글 숨김·해제 | `posts.status`(`HIDDEN` 6자), `posts.status_before_hidden` | |
| 관리자 숨긴 글 목록 | `idx_posts_status_scheduled` (status, …)의 앞 컬럼 `status = 'HIDDEN'` | |
| 관리 글 목록 HIDDEN 필터 | `idx_posts_blog_status_visibility_published` | 001 쿼리에 값만 |
| 댓글·방명록 숨김 | `comments.status`, `guestbook_entries.status`(`HIDDEN`) | 개수 비정규화는 원자적 UPDATE |
| 정지·해제 | `users.status`(`SUSPENDED`), `refresh_tokens` 폐기(001 `revokeAllByUserId`) | 새 컬럼 없음 |
| 관리자 회원 검색 | 이메일 `uk_users_email_hash`, 블로그 주소 `uk_blogs_handle`, 닉네임 `users.nickname` 앞부분 일치 | 닉네임 인덱스 없음: 아래 제안 1 |
| 작업 기록 | `admin_audit_logs`(003 `AdminAuditService`) | action 값만 추가 |
| 처리 결과 알림 | `notifications.type = REPORT_RESOLVED`, `target_type = REPORT` | 002 테이블 그대로 |
| 금칙어 | `banned_words`, `uk_banned_words_word`, `fk_banned_words_created_by` | 전체를 메모리 캐시 |
| 속도 한도·반복 스팸 기준 | `system_settings` (`ratelimit.*`, `spam.duplicate-comment`) | 003 키 체계 |
| 트랙백 받기·중복 거부 | `trackbacks`, `uk_trackbacks_post_source_url_hash`, `blogs.trackback_enabled` | |
| 글 상세 트랙백 목록 | `idx_trackbacks_post_status_created` + 내부 출처 글 LEFT JOIN(`fk_trackbacks_source_post`, PK) | 출처 글 노출 조건 |
| 블로그의 받은 트랙백(관리) | `idx_posts_blog_status_visibility_published`(블로그 글) → `idx_trackbacks_post_status_created` | |
| 보낸 트랙백 기록·발행 시 전송 대상 | `idx_trackback_ping_logs_post_created` (post_id, created_at) | 예약 글은 발행 작업이 post_id로 찾음 |
| 재기동 후 남은 PENDING 송신 | `trackback_ping_logs.status = 'PENDING'` | 기동 때 1회 훑기. 아래 제안 2 |
| 송신 IP 90일 파기 | `trackbacks.sender_ip_enc IS NOT NULL AND created_at < cutoff` | 001 개인정보 파기 작업에 단계 추가, 매일 1회 훑기 |
| 글·블로그 영구 정리 | `trackbacks`·`trackback_ping_logs`(CASCADE)·`reports`(다형 참조라 외래 키 없음) | 001 `TrashPurgeRepository`가 이미 트랙백을 지움 |

엔티티는 기존 스키마에 맞춰 매핑하며(`ddl-auto=validate`, `EntitySchemaValidationTest`), 004가 남긴 "005 컬럼은 매핑하지 않는다" 주석(`Post.status_before_hidden`, `Blog.trackback_enabled`)을 고친다.

### marco 승인이 필요한 선택 DDL 제안 (지금 구현은 이것 없이 동작)

아래 두 인덱스는 1.0 규모(회원 수천, 송신 기록 수천 행)에서는 없어도 되지만, 규모가 커지면 전체 훑기를 피하려고 필요하다. 넣기로 하면 [db/README.md](../../db/README.md) 절차(data-model·erd.md → Crowfoot 문서 → **Crowfoot `plan_migration` → marco 승인** → `apply_migration` → `migrations/NNNN-*.sql` → `schema-mysql.sql`·backend 테스트 스냅숏)를 따른다. 이 계획 단계에서는 Crowfoot 문서와 DB를 바꾸지 않았다(결정 표 31번).

```sql
-- 제안 1: 관리자 회원 검색의 닉네임 앞부분 일치 (006 FR-104, 005 FR-042의 정지 대상 찾기)
--   쿼리: SELECT ... FROM users WHERE nickname LIKE :prefix% ORDER BY nickname LIMIT 20
CREATE INDEX idx_users_nickname ON users (nickname ASC);

-- 제안 2: 재기동 뒤 남은 트랙백 송신(PENDING) 다시 보내기 (005 FR-052)
--   쿼리: SELECT id FROM trackback_ping_logs WHERE status = 'PENDING' AND created_at < :cutoff ORDER BY created_at LIMIT 100
CREATE INDEX idx_trackback_ping_logs_status_created ON trackback_ping_logs (status ASC, created_at ASC);
```

승인되지 않아도 기능은 같다(제안 1: `LIKE` 전체 훑기 + `LIMIT 20`, 제안 2: 기동 시 1회 전체 훑기). 승인되면 코드 변경 없이 인덱스만 쓰인다.

**데이터 보정 없음.** `blogs.trackback_enabled`는 DB 기본값 true로 기존 행에 이미 채워져 있고, HIDDEN·SUSPENDED 행은 아직 없다. 운영 설정 키는 행이 없으면 프로퍼티 기본값을 쓴다(003 규칙).

## Project Structure

### Documentation (this feature)

```text
specs/005-trackback-moderation/
├── spec.md              # 기능 스펙
├── plan.md              # 이 문서
├── research.md          # Phase 0: 기술 결정과 근거 (M1~M18)
├── data-model.md        # Phase 1: 테이블 (스펙 단계에서 작성, plan에서 확정한 값만 보탬)
├── quickstart.md        # Phase 1: 실행·수동 검증 시나리오
├── contracts/
│   ├── api.md           # 005 REST API 계약, 트랙백 XML, 001~004 응답 확장
│   └── routes.md        # 005 화면과 001~004 화면 변경
├── checklists/requirements.md
└── tasks.md             # Phase 2: 작업 목록과 구현 전 결정 사항
```

### Source Code

001~004 구조에 아래를 더한다. 패키지 안 구성은 001과 같이 `controller`, `service`, `repository`, `domain`, `dto`, `job`, `event`.

```text
blog-backend/src/main/java/net/java21/blog/backend/
├── report/            # 신고: Report 엔티티(@Check), ReportChannel·ReportReason·ReportStatus·ReportAction·ReportTargetType,
│                      #   ReportRepository·ReportQueryRepository, ReportService(회원 신고), RightsRequestService(권리 침해),
│                      #   ReportTargetHandler(대상 종류별 해석·미리보기·조치)·*TargetHandler 4개, ReportUrlResolver(권리 침해 주소 → 대상),
│                      #   ReportPenaltyPolicy(003 BlogPenaltyPolicy 구현), RightsRequestMail(메일 이벤트), ReportController, RightsRequestController
├── moderation/        # 숨김 공통: ContentHideService(HIDDEN 전환·해제, 작업 기록), HiddenContentQueryRepository
├── spam/              # 스팸 방어: RateLimiter(Caffeine 고정 창, 공용), RateLimitPolicy(설정 키 → 한도), WriteGuard(속도·반복·금칙어·CAPTCHA 묶음),
│                      #   DuplicateContentDetector, BannedWord 엔티티·BannedWordRepository·BannedWordService·BannedWordMatcher(캐시),
│                      #   captcha/CaptchaVerifier·TurnstileCaptchaVerifier·TestCaptchaVerifier·NoopCaptchaVerifier·CaptchaProperties·CaptchaController,
│                      #   LoginCaptchaPolicy(연속 실패 카운터), SpamProperties(blog.spam.*)
├── trackback/         # 트랙백: Trackback·TrackbackPingLog 엔티티, TrackbackQueryRepository, TrackbackReceiveService, TrackbackXmlController
│                      #   (/{handle}/{postId}/trackback), TrackbackController(/api/v1/posts/{id}/trackbacks, /trackbacks/{id}),
│                      #   TrackbackSendService·TrackbackPinger(HttpClient)·TrackbackDispatchListener(@Async 커밋 후)·PendingPingRecovery,
│                      #   TrackbackUrls(내부 주소 판별·정규화·해시), TrackbackProperties(blog.trackback.*)
├── common/net/        # (새) OutboundUrlGuard — 내부망·루프백·링크로컬 주소 차단(007 피드 수집이 재사용)
├── common/text/       # (004 PlainTextNormalizer) + TextNormalizer.nfkcLower(금칙어·반복 비교용)
├── admin/report/      # 관리자 신고: AdminReportController·AdminReportService(목록·상세·처리·기각), dto
├── admin/content/     # 관리자 콘텐츠: AdminContentController(숨김·해제·숨긴 글 목록)
├── admin/user/        # (003 블로그 한도) + 검색·상세·정지·해제: AdminUserQueryRepository, AdminUserService 확장, SuspensionService
├── admin/spam/        # 금칙어 관리: AdminBannedWordController
├── admin/audit/       # (003) AuditActions에 005 값
├── security/          # (001) + SuspendedUserRegistry(JWT 필터가 확인), SecurityConfig 경로
├── setting/           # (003) SettingKey에 ratelimit.* 5개·spam.duplicate-comment
├── post/              # (001) + PostStatus.HIDDEN, Post.hide·unhide(status_before_hidden), 숨김 중 발행·공개 범위 변경 거부,
│                      #   PublishSettingsRequest.trackbackUrls, 발행·예약 발행 지점의 TrackbackSendRequested 이벤트, PostDetail.hidden·trackbackUrl
├── comment/ guestbook/ # (001·004) + HIDDEN 상태와 canRead 규칙, 개수 비정규화, WriteGuard 연결
├── blog/              # (001) + Blog.trackbackEnabled, BLOG_RESTRICTED 응답, 금칙어(주소·제목)
├── auth/ user/        # (001) + 가입 CAPTCHA·IP 속도·금칙어(닉네임·주소), 로그인 CAPTCHA, 프로필 닉네임 금칙어
├── notification/      # (002) + NotificationType.REPORT_RESOLVED, NotificationTargetType.REPORT
├── mail/              # (001) + 권리 침해 처리 결과 메일(MessageSource 4개 언어)
├── user/job/PrivacyPurgeJob (001) + 연락 이메일·트랙백 송신 IP 파기
blog-backend/src/main/resources/application.yml   # blog.ratelimit.*, blog.spam.*, blog.captcha.*, blog.trackback.*, blog.reports.*, blog.privacy.* 추가 값
blog-backend/src/main/resources/messages_{ko,en,ja,zh_CN}.properties   # 권리 침해 처리 결과 메일

blog-front/app/
├── routes/rights-request.tsx                 # 비회원 권리 침해 신고 양식(CAPTCHA)
├── routes/manage/trackbacks.tsx              # 받은 트랙백 관리
├── routes/admin/reports.tsx, report.tsx, users.tsx, user.tsx, spam.tsx
├── routes/blog/restricted.tsx(컴포넌트)       # "이용이 제한된 블로그" — 004 공개 블로그 레이아웃이 BLOG_RESTRICTED일 때 그림
├── components/report/ReportButton.tsx, ReportDialog.tsx, ReasonSelect.tsx
├── components/trackback/TrackbackList.tsx, TrackbackUrlBox.tsx, TrackbackRdf.tsx, TrackbackTargetsField.tsx, PingResultList.tsx
├── components/captcha/Captcha.tsx(Turnstile·test·none), captcha.server.ts(설정 읽기)
├── components/admin/ReportGroupTable.tsx, ReportTargetPreview.tsx, UserSearch.tsx, BannedWordTable.tsx, RateLimitForm.tsx
├── moderation/reasons.ts, reportTarget.ts
└── locales/{ko,en,ja,zh-CN}/report.json, trackback.json, moderation.json   # + admin·manage·post·comment·guestbook·auth·notification·common·errors에 키 추가
blog-front/.github/workflows/ci.yml, e2e.yml  # e2e-backend·nightly backend 환경 변수(CAPTCHA test, 속도 한도, 트랙백 수신 한도)와 E2E_MODERATION_TEST_SETTINGS
```

**Structure Decision**: 001의 도메인별 패키지 구조를 따른다. 신고(`report`)·스팸 방어(`spam`)·트랙백(`trackback`)은 각자 테이블과 규칙을 가진 기능이라 패키지를 나눈다. 숨김은 신고 처리와 관리자 직접 조치가 함께 쓰므로 `moderation`에 둔다. 관리자 API는 003이 만든 `admin/*` 아래에 메뉴별로 둔다. 외부로 나가는 요청의 주소 검사는 트랙백 송신과 007 피드 수집이 함께 쓰므로 `common/net`에 둔다.

## 구현 순서 (사용자 스토리 기준)

plan의 스토리 번호는 구현 순서다. spec US1 = plan US1, spec에 없는 FR-141~144 = plan US2, spec US2(트랙백) = plan US3(결정 표 1번).

| 단계 | 스토리 | 핵심 산출물 | FR |
|---|---|---|---|
| 0 | 기반 | 005 엔티티 매핑(새 테이블 4개, HIDDEN 값, `status_before_hidden`, `trackback_enabled`, `@Check`), 공용 `RateLimiter`, `CaptchaVerifier` 3종과 설정 API, `OutboundUrlGuard`, 운영 설정 키, 작업 기록 값, 알림 종류, 오류 코드, 보안 경로, 개인정보 파기 단계, front 번역 namespace·모델 타입·E2E 도구·CI 환경 변수 | FR-141(장치), FR-142(장치) |
| 1 | US1 신고와 운영 (P1) 🎯 MVP | 회원 신고 API·버튼(글·댓글·방명록·트랙백), 권리 침해 신고 양식(CAPTCHA·암호화·메일), 관리자 신고 목록·상세·처리·기각, 콘텐츠 숨김·해제(글·댓글·방명록·트랙백)와 노출, 관리 글 목록 HIDDEN, 회원 검색·상세·정지·해제, 정지 즉시 적용, 이용 제한 블로그 안내, 처리 결과 알림, 포털 감점 정책, 콘솔 메뉴 | FR-040~043 |
| 2 | US2 스팸·어뷰징 방어 (P2) | 가입·비회원 쓰기·로그인 반복 실패의 CAPTCHA, 작성 속도 제한(글 발행·댓글·방명록·이미지·가입), 금칙어(관리·이름류 거부·본문류 거부/가림), 반복 댓글 차단, 콘솔 "스팸 방어 설정" 화면 | FR-141~144 |
| 3 | US3 트랙백 주고받기 (P3, 가장 낮음) | 트랙백 받기(TrackBack 1.2 XML, 노출·허용 확인, 중복·IP 제한), 글 상세 트랙백 목록·주소·RDF, 트랙백 보내기(발행·수정·예약 발행, 내부 주소 직접 처리, 내부망 차단, 결과 기록), 받은 트랙백 관리·삭제, 블로그 설정의 트랙백 받기, 신고 대상에 트랙백 | FR-049~055, SC-009 |

각 단계는 끝날 때 해당 스토리의 Independent Test를 E2E로 통과해야 한다. 단계 1~3은 단계 0 이후 서로 독립이지만, US1의 "트랙백 신고·숨김"은 US3의 트랙백 행이 있어야 E2E로 확인할 수 있다(US1에서는 단위·리포지토리 테스트로 확인하고 E2E는 US3에서 보탬). US2의 쓰기 검사는 US1과 같은 댓글·방명록 서비스를 고치므로 머지 순서를 맞춘다. 같은 파일(`ErrorCode`, `SecurityConfig`, `AuditActions`, `SettingKey`, `NotificationType`, `PostPublishService`·`PublishSettingsRequest`, `PostDetailResponse`, `CommentService`·`GuestbookService`, `SignupService`·`LoginService`, `BlogService`·`UpdateBlogRequest`·`BlogResponse`, `routes.ts`, `post-detail.tsx`, `CommentSection.tsx`, `PublishSettingsDialog.tsx`, `routes/blog/layout.tsx`, `admin/layout.tsx`, `manage/layout.tsx`, `errors.json`, 두 workflow)을 고치는 작업은 순서대로 머지한다.

**004 진행 중 작업과의 관계**: 004는 `feat/004-core`에서 구현 중이며 아직 main에 없다(이 계획 시점에 원격 브랜치도 없음). 005는 004의 공개 블로그 레이아웃, `GuestWriteGuard`·`GuestAuthorService`, `CommentVisibility`·`GuestbookVisibility`, `PlainTextNormalizer`, `ScheduledPublishJob`, `PublishSettingsDialog`의 004 필드, 방명록 화면에 기대므로 **004가 main에 머지된 뒤 시작한다**. 기대는 004 작업과 파일은 tasks.md "Dependencies"의 "004·003 의존" 표에 적었다.

**범위 밖(다른 스펙)**:
- 007: 외부 글·외부 블로그 신고와 조치(포털에서 내림 `REMOVE_FROM_PORTAL`, 차단 `BLOCK_EXTERNAL_BLOG`). 005는 `ReportTargetType`에 두 값과 `ReportTargetHandler` 자리를 두고, 처리기가 등록되지 않은 대상 종류의 신고는 400 `VALIDATION_FAILED`(field `targetType` `INVALID`)로 받지 않는다(결정 표 5번).
- 006: 콘솔 대시보드(FR-103, 처리 대기 신고 수 카드 포함), 회원 상세의 최근 로그인·작업 기록 화면(FR-106 조회), 관리자 권한 부여·회수(FR-105), "콘텐츠 관리"의 글·댓글 전체 검색. 005는 콘솔 메뉴에 처리 대기 신고 수 배지만 단다.
- 스펙 범위 밖: 핑백(Pingback), 트랙백 자동 발견으로 상대 글에서 트랙백 주소 찾기(보내기 쪽), 신고자에게 처리 메모 공개, 이의 제기 절차.

## Complexity Tracking

| 도입 | 이유 | 더 단순한 대안을 쓰지 않은 이유 |
|---|---|---|
| 공용 `RateLimiter`(Caffeine 고정 창) | FR-142 다섯 한도, FR-054 트랙백 수신, 신고·권리 침해 신고 남용, 로그인 CAPTCHA 기준 | 용도별 카운터를 따로 두면 004 `RateLimitGuestWriteGuard`와 같은 코드가 다섯 벌. DB 카운터는 스키마 변경과 쓰기 경로 쿼리 증가 (research M8) |
| CAPTCHA 외부 검증(Cloudflare Turnstile) | FR-141 | 자체 문자 이미지 CAPTCHA는 이미지 생성·접근성·우회 대응을 직접 해야 함. reCAPTCHA는 추적 쿠키·개인정보 문제. Turnstile은 무료·쿠키 없음·공식 시험 키 제공 (research M9) |
| 트랙백 송신 전용 비동기 실행기 | FR-052, Edge Cases "응답하지 않으면 실패로 기록하고 발행은 완료" | 요청 스레드 동기 송신은 대상 10개 × 5초가 발행을 막음. 정기 작업 폴링은 상태 인덱스가 없음(선택 제안 2) (research M15) |
| `SuspendedUserRegistry`(메모리) | FR-042 "정지된 사용자는 로그인할 수 없고" — 이미 받은 30분짜리 접근 토큰도 즉시 막아야 함 | 모든 인증 요청마다 `users.status` 조회는 요청당 쿼리 +1(모든 `QueryCounter` 기준이 바뀜). 접근 토큰 수명 단축은 헌법 기술 제약(30분) 변경 (research M5) |
| 금칙어 메모리 캐시 | FR-143: 이름·댓글·방명록 쓰기마다 검사 | 쓰기마다 `banned_words` 전체 조회. 목록이 작고(수백 단어) 바뀔 때만 무효화 (research M11) |
