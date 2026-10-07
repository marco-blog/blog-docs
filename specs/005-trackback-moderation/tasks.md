---
description: "005 트랙백과 운영 작업 목록"
---

# Tasks: 트랙백과 운영 (신고·관리자·트랙백·스팸 방어)

**Input**: `/specs/005-trackback-moderation/`의 설계 문서 (spec.md, plan.md, research.md, data-model.md, contracts/api.md, contracts/routes.md, quickstart.md)

**Prerequisites**: 001-blog-core·002-discovery-feeds·003-portal 구현 완료(blog-backend·blog-front main), **004-blog-features가 main에 머지된 뒤 시작**(004는 `feat/004-core`에서 구현 중, 아래 "004·003 의존"), plan.md, spec.md, research.md, data-model.md, contracts/, 헌법 v2.5.0, [api-guidelines.md](../../api-guidelines.md), [db/README.md](../../db/README.md)

**Tests**: 헌법 원칙 III(NON-NEGOTIABLE)에 따라 모든 스토리에 테스트 작업이 있고, 각 스토리 안에서 테스트 작업이 구현 작업보다 앞선다. 테스트를 먼저 쓰고 **실패하는 것을 확인한 뒤** 구현한다. backend·front 모두 라인 커버리지 80% 미만이면 빌드가 실패한다. Testcontainers는 쓰지 않고, 005는 MySQL 전용 테스트가 없다(H2 `@JpaRepositoryTest` + `QueryCounter`, 외부 HTTP는 JDK `HttpServer`).

**Organization**: 사용자 스토리별로 묶었다. 소유자 지시("트랙백은 가장 낮은 우선순위")에 따라 plan의 스토리 번호는 구현 순서다: **US1 = spec US1 신고와 운영(P1)**, **US2 = spec에 스토리가 없는 FR-141~144 스팸·어뷰징 방어(P2, plan이 Independent Test를 만듦)**, **US3 = spec US2 트랙백 주고받기(P3, 가장 낮음)**(결정 표 1번). 일정이 부족하면 US3을 통째로 뺄 수 있다(spec Assumptions). 여러 스토리가 쓰는 장치(속도 제한기, CAPTCHA, 내부망 차단, 엔티티 매핑)는 Phase 2에 둔다.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: 병렬 가능(다른 파일, 끝나지 않은 작업에 의존하지 않음)
- **[Story]**: 해당 사용자 스토리(US1~US3)
- 경로는 저장소 이름(`blog-backend/`, `blog-front/`)으로 시작한다(blog-docs CLAUDE.md 규칙)
- 작업 번호는 이 스펙 안에서 T001부터 센다(001~004 tasks.md와 별개)

## Path Conventions

- backend 소스: `blog-backend/src/main/java/net/java21/blog/backend/{domain}/{controller|service|repository|domain|dto|event|job}/` — 이 스펙의 새 도메인은 `report`, `moderation`, `spam`(하위 `captcha`), `trackback`, 공용 `common/net`, 관리자 `admin/report`·`admin/content`·`admin/spam`(003 `admin/user` 확장)
- backend 테스트: `blog-backend/src/test/java/net/java21/blog/backend/{domain}/...` (Controller `*ControllerTest` = `@WebMvcTest` + `@Import(WebMvcTestSupport.class)` + `@MockitoBean`, Service `*ServiceTest` = Mockito 단위, Repository `*RepositoryTest` = H2 `@JpaRepositoryTest` + `QueryCounter.assertQueryCount`, 시각 고정은 `support/MutableClock`, Caffeine 시각은 `Ticker`, 픽스처는 `support/JpaFixtures`·`support/TestEntities`, 쿠키는 `support/AuthCookies`, 외부 HTTP는 `support/StubHttpServer`(JDK `com.sun.net.httpserver.HttpServer`, T008에서 만듦))
- backend 리소스: `blog-backend/src/main/resources/`
- front: `blog-front/app/` (routes, components, locales, api, admin, manage, moderation), 단위 테스트 `blog-front/tests/unit/`, E2E `blog-front/tests/e2e/`(backend 필요 시나리오는 `tests/e2e/support/backend.ts`의 `requireBackend()`, 관리자 시나리오는 `requireAdmin()`, 운영 시험 설정이 필요한 시나리오는 `requireModerationTestSettings()`)
- 화면 문구는 모두 `blog-front/app/locales/{ko,en,ja,zh-CN}/{namespace}.json` 키로 쓰고 4개 언어를 같은 작업에서 넣는다(원칙 VII). 이 스펙의 새 namespace는 `report`, `trackback`, `moderation`. 새 오류 코드는 `blog-front/app/api/errorCodes.ts`와 4개 언어 `errors.json`에 함께 넣는다(`tests/unit/i18n/errorCodes.test.ts`).
- backend 오류 코드는 `blog-backend/src/main/java/net/java21/blog/backend/common/error/ErrorCode.java`에 contracts/api.md 표의 이름·HTTP 상태 그대로 더한다.
- 응답 타입은 `blog-front/app/api/models.ts`에 contracts/api.md를 옮겨 적는다.

## 스키마 변경

**필수 DDL 없음.** 005의 테이블(`reports`, `trackbacks`, `trackback_ping_logs`, `banned_words`), 001·004 테이블의 005 몫(`blogs.trackback_enabled`, `posts.status_before_hidden`, 네 테이블 `status`의 HIDDEN 값), CHECK(`ck_reports_reporter`)·UNIQUE(`uk_reports_reporter_target`, `uk_trackbacks_post_source_url_hash`, `uk_banned_words_word`)·인덱스·외래 키가 Crowfoot 문서 "blog 1.0"(`db/schema-mysql.sql`)에 모두 있다(plan.md "스키마 변경"의 쿼리별 대조표). 엔티티는 기존 스키마에 맞춰 만들고(`ddl-auto=validate`, `EntitySchemaValidationTest`), CHECK는 Hibernate `@Check`로 H2에도 건다(004 B2와 같음).

**marco 승인이 필요한 것**: 선택 인덱스 2개(plan.md "스키마 변경"에 정확한 DDL) — `idx_users_nickname`(관리자 닉네임 검색), `idx_trackback_ping_logs_status_created`(재기동 후 송신 복구). 구현은 둘 없이 동작한다. 넣기로 하면 Crowfoot `plan_migration` → **marco 승인** → `apply_migration` 절차로 따로 요청한다. 이 계획 작업에서는 Crowfoot 문서와 DB를 바꾸지 않았다.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: front 번역·타입 틀, E2E 도구와 CI 환경, backend 프로퍼티

- [x] T001 [P] 새 번역 namespace 파일 `blog-front/app/locales/{ko,en,ja,zh-CN}/report.json`, `blog-front/app/locales/{ko,en,ja,zh-CN}/trackback.json`, `blog-front/app/locales/{ko,en,ja,zh-CN}/moderation.json`을 같은 키 집합의 뼈대로 추가하고 `blog-front/app/i18n/config.ts`의 namespace 목록에 등록(이후 작업이 키를 채움, `tests/unit/i18n/translations.test.ts`가 4개 언어 키 일치 확인)
- [x] T002 [P] contracts/api.md 005 타입을 `blog-front/app/api/models.ts`에 추가: `ReportTargetType`, `ReportReason`, `ReportAction`, `ReportGroup`, `ReportTargetPreview`, `ReportDetail`, `AdminUserSummary`, `AdminUserDetail`, `BannedWord`, `CaptchaConfig`, `Trackback`, `ManagedTrackback`, `TrackbackPing`, `Blog.trackbackEnabled`, `PostDetail`의 `hidden`·`trackbackUrl`·`trackbackCount`, `Comment`·`GuestbookEntry`의 `hidden`, `PublishSettings.trackbackUrls`, `PostStatus`에 `HIDDEN`, 알림 종류 `REPORT_RESOLVED`
- [x] T003 [P] E2E 도구 `blog-front/tests/e2e/support/backend.ts`에 추가: `requireModerationTestSettings()`(`E2E_MODERATION_TEST_SETTINGS=1`이 아니면 건너뜀), `adminRequest(playwright)`(관리자 계정으로 로그인한 `APIRequestContext`), `report(request, targetType, targetId, reason)`, `sendTrackbackPing(request, handle, postId, form, charset?)`(form-urlencoded 원시 바이트, 응답 XML의 `error` 값 반환), `uniqueText(seed)`(반복 스팸 기준에 걸리지 않게 실행마다 다른 문구); `blog-front/playwright.config.ts`에 `moderation` 프로젝트(`testMatch: /moderation-.*\.spec\.ts$/`, `dependencies: ["e2e"]`, `workers: 1` — 전역 설정·금칙어를 바꿈)
- [x] T004 [P] CI가 005 E2E를 **실제로 돌리게** workflow 환경을 바꾼다: `blog-front/.github/workflows/ci.yml`의 `e2e-backend` 잡과 `blog-front/.github/workflows/e2e.yml`(nightly)의 "Start backend" `env`에 `BLOG_CAPTCHA_PROVIDER: test`, `BLOG_RATELIMIT_SIGNUP_PER_IP_PER_HOUR: "100000"`, `BLOG_RATELIMIT_COMMENT_PER_MINUTE: "1000"`, `BLOG_RATELIMIT_GUESTBOOK_PER_MINUTE: "1000"`, `BLOG_RATELIMIT_POST_PUBLISH_PER_HOUR: "100000"`, `BLOG_RATELIMIT_MEDIA_UPLOAD_PER_MINUTE: "1000"`, `BLOG_TRACKBACK_RECEIVE_LIMIT: "100000"`, `BLOG_REPORTS_MEMBER_PER_HOUR: "100000"`, `BLOG_REPORTS_RIGHTS_REQUEST_PER_IP_PER_HOUR: "100000"`를 더하고 004의 `BLOG_GUEST_COMMENT_PER_MINUTE`·`BLOG_GUEST_GUESTBOOK_PER_MINUTE`를 지운다; 두 workflow의 Playwright 단계 `env`에 `E2E_MODERATION_TEST_SETTINGS: "1"`. 주석에 "가입 IP 한도가 없으면 001~004 E2E가 가입 단계에서 막힘"(research M18). backend 저장소 `blog-backend/.github/workflows/*`에 E2E가 없음을 확인만 한다
- [x] T005 [P] backend 프로퍼티(contracts/api.md "프로퍼티" 표): `blog-backend/src/main/java/net/java21/blog/backend/spam/RateLimitProperties.java`(`blog.ratelimit.*` 5개), `spam/SpamProperties.java`(`blog.spam.duplicate-comment.*`), `spam/captcha/CaptchaProperties.java`(`provider`, `site-key`, `secret-key`, `test-token`, `verify-timeout`, `login-failures-before-captcha` — prod 프로필에서 `test`·`none`이거나 키가 비면 기동 실패), `report/ReportsProperties.java`(`member-per-hour`, `rights-request-per-ip-per-hour`, `penalty-window`), `trackback/TrackbackProperties.java`(`receive-limit`, `receive-window`, `connect-timeout`, `read-timeout`, `max-targets`, `executor-threads`, `executor-queue`, `recover-pending-after`), `common/net/OutboundProperties.java`(`allowed-ports`, `allow-private` — prod에서 true면 기동 실패), `blog-backend/src/main/java/net/java21/blog/backend/user/PrivacyProperties.java`에 `rightsRequestRetention`·`trackbackIpRetention`(기존 생성자 유지); `blog-backend/src/main/resources/application.yml` 기본값, `application-local.yml`에 `blog.captcha.provider: none`, `application-prod.yml`에 `turnstile`과 `${BLOG_CAPTCHA_SITE_KEY}`·`${BLOG_CAPTCHA_SECRET_KEY}`(필수); 004 `GuestProperties`의 `comment-per-minute`·`guestbook-per-minute` 제거(`ip-retention`은 유지). 잘못된 값이면 기동 실패하는 `*PropertiesTest`
- [x] T006 [P] 기존 E2E 점검: `blog-front/tests/e2e/*.spec.ts`에서 같은 문구 댓글·방명록을 한 계정(또는 비회원)으로 10분 안에 3번 넘게 쓰는 시나리오를 찾아 `uniqueText()`로 바꾸고, 문구가 10자 미만이면 그대로 둔다(반복 스팸 기준, research M12·M18). 바꾼 파일 목록을 PR 설명에 적음

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: 모든 스토리가 쓰는 엔티티 매핑, 공용 속도 제한기, CAPTCHA, 내부망 차단, 운영 설정 키, 작업 기록·알림 값, 오류 코드, 보안 경로, 개인정보 파기

**⚠️ CRITICAL**: 이 Phase가 끝나기 전에는 어떤 스토리도 시작하지 않는다

### Tests for Foundation ⚠️

> 먼저 쓰고 실패를 확인한다

- [x] T007 [P] `blog-backend/src/test/java/net/java21/blog/backend/report/repository/ModerationColumnsMappingTest.java`(`@JpaRepositoryTest`): `Report`(MEMBER·RIGHTS_REQUEST, `contactEmail` 암호문 저장·복호화 읽기, 대상 NULL 허용), `Trackback`(`senderIp` 암호문, `sourcePost` nullable, 상태), `TrackbackPingLog`, `BannedWord`, `Post.statusBeforeHidden`과 `PostStatus.HIDDEN`, `Blog.trackbackEnabled`(새 블로그 true), `CommentStatus.HIDDEN`·`GuestbookStatus.HIDDEN`을 저장 후 다시 읽기. H2에서도 예외: `@Check` 위반(MEMBER인데 `reporter` 없음, RIGHTS_REQUEST인데 있음), UNIQUE 위반(같은 회원·같은 대상 신고 두 번, 같은 글·같은 `source_url_hash` 트랙백 두 번, 같은 금칙어), RIGHTS_REQUEST 두 건(`reporter` NULL)은 허용
- [x] T008 [P] `blog-backend/src/test/java/net/java21/blog/backend/spam/RateLimiterTest.java`: 같은 (종류, 주체) 한도까지 통과·넘으면 429 `TOO_MANY_REQUESTS`와 남은 초(`Retry-After` 값), 창이 지나면(Caffeine `Ticker`) 다시 통과, 주체·종류가 다르면 따로 셈, 한도 변경이 다음 호출부터 반영, 동시 호출 100개에서 정확히 한도만 통과(스레드 풀); 테스트 도구 `blog-backend/src/test/java/net/java21/blog/backend/support/StubHttpServer.java`(JDK `HttpServer`, 경로별 응답·지연·상태 지정, 받은 요청 기록)와 그 자체 시험
- [x] T009 [P] `blog-backend/src/test/java/net/java21/blog/backend/spam/captcha/CaptchaVerifierTest.java`: `TurnstileCaptchaVerifier`(`StubHttpServer`가 siteverify 흉내 — `success: true` 통과, `false` 거부, 500·시간 초과(3초)·잘못된 JSON 거부, 보낸 값 `secret`·`response`·`remoteip` 확인, 토큰 없음·빈 문자열은 호출 없이 400 `CAPTCHA_FAILED`), `TestCaptchaVerifier`(설정 토큰만 통과), `NoopCaptchaVerifier`; `CaptchaPropertiesTest`(prod에서 test·none·빈 키 기동 실패); `spam/captcha/CaptchaControllerTest.java`(`GET /api/v1/captcha/config` 비로그인 200, `siteKey`는 turnstile일 때만, `Cache-Control: public, max-age=3600`, secret이 응답에 없음)
- [x] T010 [P] `blog-backend/src/test/java/net/java21/blog/backend/common/net/OutboundUrlGuardTest.java`: http/https만, 허용 포트만, `user@host` 거부, 루프백(127.0.0.1, ::1, `localhost`)·사설(10/8, 172.16/12, 192.168/16, fc00::/7)·링크로컬(169.254.169.254, fe80::)·CGNAT·멀티캐스트·0.0.0.0·IPv4 매핑 IPv6(`::ffff:127.0.0.1`)·10진수 표기(`http://2130706433/`) 거부, 여러 주소로 해석되면 하나라도 내부면 거부(이름 해석은 주입한 `HostResolver` 가짜), 공인 주소 통과, `allow-private=true`면 내부 통과 (research M16)
- [x] T011 [P] `blog-backend/src/test/java/net/java21/blog/backend/setting/SettingKeyTest.java`·`admin/setting/AdminSettingServiceTest.java`에 추가: `ratelimit.*` 5개(정수 범위, 0·음수·문자열 400 `INVALID` `params.min/max`), `spam.duplicate-comment`(객체 두 필드 범위·누락 `REQUIRED`), 기본값이 프로퍼티 값, `GET /admin/settings?prefix=ratelimit.`이 5개, 저장·되돌리기가 `SETTING_CHANGE` 작업 기록과 `RateLimitPolicy` 캐시 무효화
- [x] T012 [P] `blog-backend/src/test/java/net/java21/blog/backend/security/ModerationPathsWebMvcTest.java`(테스트 컨트롤러 + `WebMvcTestSupport`, 003 `PortalPathsWebMvcTest` 방식): 비로그인 허용 POST `/api/v1/rights-requests`(Origin 검사 받음, 403 `ORIGIN_NOT_ALLOWED`), 비로그인 허용 GET `/api/v1/captcha/config`·`/api/v1/posts/{id}/trackbacks`, 비로그인 허용 POST `/{handle}/{postId}/trackback`(Origin 없어도 통과, 숫자 아닌 postId는 매칭 안 됨), 로그인 필요 POST `/api/v1/reports`(401)·DELETE `/api/v1/trackbacks/{id}`·GET `/api/v1/posts/{id}/trackback-pings`·`/api/v1/blogs/{h}/manage/trackbacks`(401), 새 관리자 경로 `/api/v1/admin/reports/**`·`/admin/contents/**`·`/admin/users/**`·`/admin/banned-words/**`가 일반 회원·비로그인에 404 `NOT_FOUND`(003 `AdminAccessFilter`)
- [x] T013 [P] `blog-backend/src/test/java/net/java21/blog/backend/user/repository/PrivacyPurgeRepositoryTest.java`·`user/job/PrivacyPurgeJobTest.java`에 추가: 처리(`handled_at`) 후 `rights-request-retention`(1년) 지난 RIGHTS_REQUEST의 `contact_email_enc`만 NULL(대기 중·기간 안·MEMBER는 그대로, 나머지 내용 유지), `trackback-ip-retention`(90일) 지난 트랙백의 `sender_ip_enc`만 NULL, 건수 단위 처리와 로그(주소 원문은 로그에 없음) (data-model reports·trackbacks, 001 FR-134)
- [x] T014 [P] `blog-front/tests/unit/components/Captcha.test.tsx`·`tests/unit/components/captchaServer.test.ts`: `turnstile`이면 위젯 자리와 nonce 붙은 스크립트 태그, 숨은 입력 `captchaToken`, `<noscript>` 안내; `test`면 "시험 모드" 표시와 숨은 입력 값 `e2e-pass`(환경 변수 `BLOG_CAPTCHA_TEST_TOKEN`이 있으면 그 값); `none`이면 아무것도 없음; 설정은 `GET /captcha/config`를 요청당 한 번(메모); `blog-front/tests/unit/server/securityHeaders.test.ts`에 provider가 turnstile일 때만 `https://challenges.cloudflare.com`이 `script-src`·`frame-src`·`connect-src`에

### Implementation for Foundation

- [x] T015 `ErrorCode.java`에 contracts/api.md 표의 21개 코드(`REPORT_TARGET_NOT_FOUND`(404) … `TRACKBACK_NOT_ALLOWED`(422)), `FieldErrorCode`에 `BANNED_WORD`: `blog-backend/src/main/java/net/java21/blog/backend/common/error/ErrorCode.java`, `common/error/FieldErrorCode.java`
- [x] T016 [P] 글 숨김 매핑: `blog-backend/src/main/java/net/java21/blog/backend/post/domain/PostStatus.java`에 `HIDDEN`, `post/domain/Post.java`에 `status_before_hidden`과 `hide()`(DELETED면 예외, 이미 HIDDEN이면 그대로)·`unhide()`·`isHidden()`, "005 컬럼은 매핑하지 않는다" 주석 정리. 노출 조각(`PostExposure`)은 바꾸지 않는다(PUBLISHED만 목록이라 자동 제외, research M1)
- [x] T017 [P] `blog-backend/src/main/java/net/java21/blog/backend/blog/domain/Blog.java`에 `trackback_enabled`(`changeTrackbackEnabled`), `comment/domain/CommentStatus.java`·`guestbook/domain/GuestbookStatus.java`(004)에 `HIDDEN`, `Comment`·`GuestbookEntry`에 `hide()`·`unhide()`(ACTIVE ↔ HIDDEN만)
- [x] T018 [P] 신고 도메인: `blog-backend/src/main/java/net/java21/blog/backend/report/domain/Report.java`(`@Check(constraints = "(channel = 'MEMBER') = (reporter_id IS NOT NULL)")`, `@Table(uniqueConstraints = …reporter_id, target_type, target_id)`, reporter·targetUser·targetBlog·handledBy LAZY, `contactEmail` `@Convert(EncryptedStringConverter)`, `assignTarget`·`resolve`), `report/domain/ReportChannel.java`·`ReportReason.java`·`ReportStatus.java`·`ReportAction.java`·`ReportTargetType.java`(6개 값), `report/repository/ReportRepository.java`
- [x] T019 [P] 트랙백 도메인: `blog-backend/src/main/java/net/java21/blog/backend/trackback/domain/Trackback.java`(post·sourcePost LAZY, `senderIp` 암호문, `TrackbackStatus` ACTIVE·DELETED·HIDDEN, `@UniqueConstraint(post_id, source_url_hash)`, `markDeleted`·`hide`·`unhide`), `trackback/domain/TrackbackPingLog.java`(`PingStatus`, `PingErrorCode` 5개 값, `succeed`·`fail(code, message, at)`), `trackback/repository/TrackbackRepository.java`·`TrackbackPingLogRepository.java`
- [x] T020 [P] `blog-backend/src/main/java/net/java21/blog/backend/spam/domain/BannedWord.java`(`BannedWordScope`, `BannedWordAction`, createdBy LAZY, `BaseTimeEntity`), `spam/repository/BannedWordRepository.java`
- [x] T021 공용 속도 제한: `blog-backend/src/main/java/net/java21/blog/backend/spam/RateLimiter.java`(Caffeine 고정 창, `check(kind, subject, limit, window)`, 테스트용 `Ticker` 생성자), `spam/RateLimitKind.java`(POST_PUBLISH·COMMENT·GUESTBOOK·MEDIA_UPLOAD·SIGNUP·REPORT·RIGHTS_REQUEST·TRACKBACK_RECEIVE·LOGIN_FAILURE·DUPLICATE_CONTENT), `spam/RateLimitPolicy.java`(설정 키 → 한도, 003 `SystemSettingsService` 값), 004 `guest/service/RateLimitGuestWriteGuard.java`를 `RateLimiter`를 쓰도록 바꿈(한도는 `ratelimit.comment-per-minute`·`guestbook-per-minute`, US2 T075에서 `WriteGuard`로 대체), 429의 `Retry-After`는 004 `BusinessException` 헤더 자리 그대로
- [x] T022 CAPTCHA: `blog-backend/src/main/java/net/java21/blog/backend/spam/captcha/CaptchaVerifier.java`(인터페이스 `verify(token, ip)`), `TurnstileCaptchaVerifier.java`(JDK `HttpClient`, 시간 제한), `TestCaptchaVerifier.java`, `NoopCaptchaVerifier.java`, `CaptchaConfig.java`(provider에 따라 빈 하나), `CaptchaController.java`(`GET /api/v1/captcha/config`, 캐시 헤더)
- [x] T023 `blog-backend/src/main/java/net/java21/blog/backend/common/net/OutboundUrlGuard.java`(`check(URI)` → 통과 또는 `OutboundBlockedException(reason)`), `common/net/HostResolver.java`(기본 `InetAddress.getAllByName`, 시험용 주입)
- [x] T024 값 추가: `blog-backend/src/main/java/net/java21/blog/backend/setting/SettingKey.java`에 `ratelimit.*` 5개·`spam.duplicate-comment`(검증·기본값, `PortalProperties` 대신 쓸 프로퍼티를 받도록 `defaultValue` 시그니처를 설정 프로퍼티 묶음으로 넓힘), `admin/audit/AuditActions.java`에 `TARGET_USER`·`TARGET_REPORT`·`TARGET_COMMENT`·`TARGET_GUESTBOOK`·`TARGET_TRACKBACK`·`TARGET_BANNED_WORD`와 `USER_SUSPEND`·`USER_UNSUSPEND`·`REPORT_ACTION`·`REPORT_DISMISS`·`CONTENT_HIDE`·`CONTENT_UNHIDE`·`BANNED_WORD_CREATE`·`BANNED_WORD_UPDATE`·`BANNED_WORD_DELETE`, `notification/domain/NotificationType.java`에 `REPORT_RESOLVED`, `NotificationTargetType.java`에 `REPORT`
- [x] T025 `blog-backend/src/main/java/net/java21/blog/backend/config/SecurityConfig.java`: `PUBLIC_POST`에 `/api/v1/rights-requests`, `PUBLIC_GET`에 `/api/v1/captcha/config`·`/api/v1/posts/*/trackbacks`, 트랙백 받기 `POST /*/*/trackback`(숫자 조각은 컨트롤러 매핑이 확인) permitAll. 관리자 경로는 003 `AdminAccessFilter`가 이미 덮음
- [x] T026 개인정보 파기: `blog-backend/src/main/java/net/java21/blog/backend/user/repository/PrivacyPurgeRepository.java`에 `findExpiredRightsContactIds(cutoff, limit)`·`clearRightsContact(ids)`·`findExpiredTrackbackIpIds(cutoff, limit)`·`clearTrackbackIp(ids)`, `user/job/PrivacyPurgeJob.java`에 두 단계(건수 로그)
- [x] T027 [P] 새 오류 코드 문구: `blog-front/app/api/errorCodes.ts`에 T015의 21개 코드, `blog-front/app/locales/{ko,en,ja,zh-CN}/errors.json`에 4개 언어 문구, 필드 오류 `BANNED_WORD`("사용할 수 없는 단어가 있습니다")를 `app/api/formErrors.ts` 필드 문구 표에
- [x] T028 [P] `blog-front/app/components/captcha/Captcha.tsx`, `blog-front/app/components/captcha/captcha.server.ts`(설정 읽기·요청 메모), `blog-front/app/server/securityHeaders.ts`(provider가 turnstile일 때 CSP 출처 추가), 문구 `moderation` namespace(4개 언어)

**Checkpoint**: 기반 완료. `./mvnw verify`, `npm test -- --coverage` 통과, `EntitySchemaValidationTest`가 새 매핑으로 통과, CI `e2e-backend`가 새 환경 변수로 001~004 E2E를 모두 통과(CAPTCHA `test`·가입 한도 확인)

---

## Phase 3: User Story 1 - 신고와 운영 (Priority: P1) 🎯 MVP

**Goal**: 회원은 글·댓글·방명록 글·트랙백을 신고하고, 비회원 권리자는 권리 침해 양식으로 요청한다. 관리자는 대상별로 묶인 신고를 숨김·기각으로 처리하고, 회원을 찾아 정지·해제한다. 정지된 회원은 로그인할 수 없고 그 블로그는 "이용이 제한된 블로그"로 안내되며, 관리 기능은 관리자 외에 404다.

**Independent Test**: 회원이 글 신고 → 관리자가 신고 목록에서 해당 글 숨김 → 방문자에게 그 글이 보이지 않는지 확인(quickstart #1~#20).

FR: FR-040, FR-041, FR-042, FR-043 (006 FR-104 회원 관리, FR-106 작업 기록의 005 몫)

### Tests for User Story 1 (backend) ⚠️

- [x] T029 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/report/service/ReportTargetHandlerTest.java`(Mockito)와 `report/repository/ReportTargetPreviewRepositoryTest.java`(`@JpaRepositoryTest`): 처리기 4개의 `resolveForReporter` — 글은 `PostExposure.isDetailVisibleTo(reporter)`(남의 비공개·임시·삭제·숨김·정지 회원 글 404 `REPORT_TARGET_NOT_FOUND`, 자기 글 422), 댓글·방명록은 004 `canRead`(볼 수 없는 비밀 글 404, 숨김·삭제 404, 비회원 글은 작성 회원 NULL), 트랙백은 ACTIVE + 받은 글을 볼 수 있을 때(받은 글 주인이면 422, 서비스 안 출처면 출처 글 작성자·블로그를 `target_user`·`target_blog`로, 밖이면 둘 다 NULL); `previews(ids)`가 종류별 IN 쿼리 1회(`QueryCounter`), PRIVATE·PROTECTED 글은 `text` null, 비밀 댓글은 내용 포함(결정 표 6번), 삭제된 대상은 `state: DELETED`, 없는 대상 `MISSING`
- [x] T030 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/report/service/ReportServiceTest.java`: 회원 신고 정상(PENDING, `target_user_id`·`target_blog_id` 채움), 사유·설명 검증(OTHER면 `detail` 필수, 1000자), 처리기 없는 `EXTERNAL_POST`·`EXTERNAL_BLOG` 400 field `targetType` `INVALID`, 중복은 저장 전 조회와 UNIQUE 위반 모두 409 `REPORT_ALREADY_EXISTS`, 1시간 30건 넘으면 429 (AS1, FR-040)
- [x] T031 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/report/service/RightsRequestServiceTest.java`·`report/service/ReportUrlResolverTest.java`: CAPTCHA 실패 400 `CAPTCHA_FAILED`(저장 없음), 사유 4개만, `rightsBasis` 필수·2000자, 이메일 형식, `reporter_id` NULL(로그인 상태로 보내도), `contact_email_enc` 암호화, IP당 1시간 5건; 주소 해석 — `{base-url}/{handle}/{postId}` → POST, `#comment-{id}`·`#guestbook-{id}`·`#trackback-{id}` → 그 대상(그 글에 속한 것만), 쿼리·끝 `/` 무시, 다른 호스트·해석 실패·없는 글은 대상 NULL (AS5)
- [x] T032 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/admin/report/ReportQueryRepositoryTest.java`(`@JpaRepositoryTest`): 상태별 대상 묶음(같은 대상 신고 여러 건이 한 줄, 사유별 수, 첫·마지막 접수, `channel` MIXED), 대상 미정 권리 침해는 한 줄씩, 첫 접수 오래된 순, `targetType`·`channel` 거르기, `totalCount`, 대상 수와 무관한 쿼리 수(묶음 1 + 개수 1); 대기 수 1회; 상세의 같은 대상 신고 목록(최신 100, 신고자 닉네임 LEFT JOIN) 1회; 회원이 받은 신고 수 1회
- [x] T033 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/admin/report/AdminReportServiceTest.java`: `resolve(ACTION, HIDE_CONTENT)` — 대상 숨김 호출, 같은 대상의 PENDING 신고 모두 ACTIONED·`handled_by`·`handled_at`·`resolution_note`(다른 대상·이미 처리된 신고는 그대로), 응답 `resolvedCount`; `resolve(ACTION, SUSPEND_USER)` — 정지 호출(`suspendReason` 필수), 작성 회원 없는 대상 422 `REPORT_ACTION_NOT_ALLOWED`; `DISMISS`; 대상 미정 권리 침해의 ACTION 422 `REPORT_TARGET_REQUIRED`·DISMISS는 가능; 이미 처리된 신고 409 `REPORT_ALREADY_RESOLVED`; 대상 지정(이미 있으면 409 `REPORT_ALREADY_TARGETED`, 없는 대상 404 `CONTENT_NOT_FOUND`); 커밋 후 이벤트 — 회원 신고자마다 `REPORT_RESOLVED` 알림 1건(같은 회원 중복 없음, 파라미터에 대상 내용 없음), 권리 침해 신고자마다 `RightsRequestResolvedMail`; 작업 기록 `REPORT_ACTION`·`REPORT_DISMISS`(닫은 id 목록) (FR-041, 006 FR-106)
- [x] T034 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/moderation/ContentHideServiceTest.java`와 `post/service/PostPublishServiceTest.java`·`manage/service/ManagePostBulkServiceTest.java`·`post/service/PostServiceTest.java`에 추가: 글 숨김 → `status_before_hidden`·HIDDEN, 해제 → 원래 상태(SCHEDULED 포함), DELETED 글 404 `CONTENT_NOT_FOUND`, 두 번 숨김 멱등; 댓글 숨김은 글 `comment_count` 원자적 감소·해제는 증가; 방명록·트랙백 숨김; 작업 기록 `CONTENT_HIDE`·`CONTENT_UNHIDE`(before/after 상태, 사유); 숨긴 글의 발행·발행 설정 409 `POST_HIDDEN`, 일괄 공개 범위·공지는 건너뜀(건너뛴 수), 휴지통 이동 허용(`status_before_delete = HIDDEN`)·복구하면 HIDDEN; 숨긴 글 상세는 주인에게 `hidden: true`, 다른 사람 404 (AS2, FR-041, research M1)
- [x] T035 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/comment/service/CommentVisibilityTest.java`·`guestbook/service/GuestbookVisibilityTest.java`(004)와 `comment/repository/CommentQueryRepositoryTest.java`·`guestbook/repository/GuestbookQueryRepositoryTest.java`에 추가: HIDDEN 댓글·방명록 글은 작성 회원에게 내용 + `hidden: true`, 글·블로그 주인과 다른 사람에게는 보이는 답글이 있으면 `{ hidden, content: null, author: null }`, 없으면 목록에서 빠짐, 비회원 작성 숨김 글은 누구에게도 내용 없음; 사이드바 최근 댓글·대시보드 최근 방명록·관리 댓글/방명록 목록에서 HIDDEN 제외; 쿼리 수 변화 없음 (FR-041, data-model 숨김)
- [x] T036 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/admin/user/SuspensionServiceTest.java`와 `security/SuspendedUserRegistryTest.java`·`security/AuthenticationWebMvcTest.java`에 추가: 정지 → `SUSPENDED`, `revokeAllByUserId` 호출, 커밋 후 정지 목록 등록, 작업 기록 `USER_SUSPEND`(사유); 이미 정지 멱등, 탈퇴 409 `USER_NOT_ACTIVE`, 자기 자신 422 `CANNOT_SUSPEND_SELF`, ADMIN이 관리자 정지 403 `FORBIDDEN`, 마지막 SUPER_ADMIN 409 `LAST_SUPER_ADMIN`; 해제 → ACTIVE, 목록에서 제거, `USER_UNSUSPEND`; 등록된 회원의 유효한 접근 토큰 요청은 인증 없음(로그인 필요 API 401, 공개 API는 비로그인 응답), 목록 항목은 접근 토큰 수명 뒤 만료(`Ticker`); 정지 회원 로그인은 001대로 401 `INVALID_CREDENTIALS` (AS3, FR-042, research M5)
- [x] T037 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/admin/user/AdminUserQueryRepositoryTest.java`(`@JpaRepositoryTest`)·`admin/user/AdminUserServiceTest.java`: 이메일 정확 일치(정규화 후 해시, 대소문자·앞뒤 공백 무시, 부분 일치 없음), 닉네임 앞부분 일치(20건, 닉네임순), 블로그 주소 정확 일치(삭제된 블로그 포함), `q` 2자 미만 400, 블로그 수 포함 쿼리 수 고정(목록 1 + 개수 1); 상세의 글 수(휴지통 제외, 모든 블로그)·받은 신고 수·최근 로그인·블로그 목록·한도를 쿼리 5회 이하로, 응답에 이메일·비밀번호 해시 없음 (006 FR-104)
- [x] T038 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/blog/service/BlogAccessTest.java`·`blog/controller/BlogControllerTest.java`에 추가: 블로그 ACTIVE + 주인 SUSPENDED → `GET /api/v1/blogs/{h}` 404 `BLOG_RESTRICTED`; 주인 WITHDRAWN·블로그 DELETED·없는 handle은 `BLOG_NOT_FOUND`; 블로그 하위 API(글 목록·상세·방명록)는 지금처럼 `BLOG_NOT_FOUND`·`POST_NOT_FOUND` (AS3)
- [x] T039 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/report/repository/ReportPenaltyPolicyTest.java`(`@JpaRepositoryTest`): 후보 블로그 중 `penalty-window`(90일) 안 ACTIONED 신고가 있는 블로그만 `1 - reportPenalty`, DISMISSED·PENDING·기간 밖·`target_blog_id` NULL은 감점 없음, 블로그 수와 무관한 쿼리 1회; `portal/service/PopularityCalculatorTest.java`가 새 정책 빈으로 통과(003 `NoBlogPenaltyPolicy` 제거) (003 FR-086, research M6)
- [x] T040 [P] [US1] 컨트롤러: `blog-backend/src/test/java/net/java21/blog/backend/report/controller/ReportControllerTest.java`(`POST /api/v1/reports` 201 + `Location`, 비로그인 401, 검증 400 field, 409·404·422·429 형식), `report/controller/RightsRequestControllerTest.java`(202 `result: null`, Origin 검사, 400 `CAPTCHA_FAILED`), `admin/report/AdminReportControllerTest.java`(목록·요약·상세·대상 지정·처리, `no-store`, 상세의 `contactEmail`), `admin/content/AdminContentControllerTest.java`(PUT·DELETE `/admin/contents/{posts|comments|guestbook-entries|trackbacks}/{id}/hidden`, 다른 조각 404, 숨긴 글 목록), `admin/user/AdminUserControllerTest.java`(검색·상세·정지·해제, 기존 블로그 한도 그대로)
- [x] T041 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/mail/MailServiceTest.java`에 추가: 권리 침해 결과 메일 — 받는 주소는 복호화한 연락 이메일, 제목·본문에 ko와 en 문구가 함께, 결정(조치·미조치)과 대상 주소 포함, 관리자 메모 없음, 실패해도 예외 없이 로그(주소는 로그에 없음); `messages_{ko,en,ja,zh_CN}.properties` 키 일치 시험 (AS5, research M10)
- [x] T042 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/notification/service/NotificationServiceTest.java`·`notification/repository/NotificationQueryRepositoryTest.java`에 추가: `REPORT_RESOLVED` 알림 저장·목록 응답(`targetType: REPORT`, `params.decision`, actor null, 링크 없음) (FR-041)

### Tests for User Story 1 (front) ⚠️

- [x] T043 [P] [US1] `blog-front/tests/unit/components/ReportDialog.test.tsx`·`tests/unit/components/ReportButton.test.tsx`: 로그인 회원·남의 콘텐츠에만 버튼, 사유 8개 라디오(문구 `report` namespace), 기타면 설명 필수, 제출 → `POST /reports` 본문, 성공·`REPORT_ALREADY_EXISTS`·`REPORT_TARGET_NOT_FOUND`·429 문구, JS 없는 `?report=comment-{id}` 폼 화면, "권리 침해 신고" 링크(`/rights-request?url=` 현재 주소 + 앵커)
- [x] T044 [P] [US1] `blog-front/tests/unit/routes/rightsRequest.test.tsx`: loader가 CAPTCHA 설정, `?url=`로 주소 미리 채움, action 본문(`targetUrl`·`reason`·`rightsBasis`·`contactEmail`·`captchaToken`), 202 → `?submitted=1` 안내, 필드 오류·`CAPTCHA_FAILED`·429 문구, 개인정보 안내(보관 1년), meta `noindex`
- [x] T045 [P] [US1] `blog-front/tests/unit/routes/adminReports.test.tsx`·`tests/unit/routes/adminReport.test.tsx`: 상태 탭·대상 종류 거르기·페이지, 묶음 표(미리보기·신고 수·사유별 수), 상세의 신고 목록·권리 침해 정보·연락 이메일, 대상 미정이면 "대상 지정" 폼(주소 또는 종류+id), 처리 action(`intent=resolve` 숨김·정지(사유 필수)·기각, `intent=target`, `intent=unhide`), 처리된 신고의 결과 표시, 관리자가 아니면 404(003 `admin/access.server.ts`), 메뉴 배지(`GET /admin/reports/summary`)
- [x] T046 [P] [US1] `blog-front/tests/unit/routes/adminUsers.test.tsx`·`tests/unit/routes/adminUser.test.tsx`·`tests/unit/routes/adminHiddenPosts.test.tsx`: 검색 방식 선택·결과 표, 상세의 글 수·받은 신고 수·블로그 목록·한도 폼(003 API), 정지(사유 필수, 확인)·해제 action과 오류 문구(`CANNOT_SUSPEND_SELF`·`LAST_SUPER_ADMIN`·`USER_NOT_ACTIVE`), 숨긴 글 목록·해제
- [x] T047 [P] [US1] `blog-front/tests/unit/routes/blogLayout.test.tsx`(004)·`tests/unit/routes/postDetail.test.tsx`·`tests/unit/components/CommentSection.test.tsx`·`tests/unit/components/GuestbookEntryItem.test.tsx`·`tests/unit/routes/managePosts.test.tsx`·`tests/unit/routes/notifications.test.tsx`에 추가: `BLOG_RESTRICTED`면 "이용이 제한된 블로그"(404, noindex, 사이드바·방문 기록 없음), `BLOG_NOT_FOUND`는 기존 404; 주인의 숨긴 글 안내; 숨긴 댓글·방명록(작성자 안내, 다른 사람 자리), 항목 앵커 `#comment-{id}`·`#guestbook-{id}`; 관리 글 목록 "숨김" 필터·표시·버튼 비활성; `REPORT_RESOLVED` 문구 두 가지
- [x] T048 [P] [US1] E2E `blog-front/tests/e2e/moderation-us1-report.spec.ts`(`requireBackend`·`requireAdmin`·`requireModerationTestSettings`): Independent Test(B가 A 글 신고 → 관리자 콘솔에서 숨김 → 비로그인·B에게 글 404·블로그 목록·검색에 없음, A에게는 숨김 안내), 댓글 신고 숨김 후 작성자만 보임, 기각 후 신고자 알림, 일반 회원·비로그인의 `/admin/reports` 404·`/api/v1/admin/reports` 404(AS4), 권리 침해 양식 제출(`test` CAPTCHA 자동) → 관리자 상세에 연락 이메일 → 처리, `MAILPIT_URL`이 있으면(nightly) 결과 메일 확인 (quickstart #1~#11, #16, #18~#19)
- [x] T049 [P] [US1] E2E `blog-front/tests/e2e/moderation-us1-suspend.spec.ts`(`requireBackend`·`requireAdmin`·`requireModerationTestSettings`): 관리자가 닉네임으로 C 검색 → 정지 → 로그인해 있던 C의 다음 화면이 로그아웃 상태 → C 로그인 실패 → 비로그인으로 `/{C handle}`·글 주소가 "이용이 제한된 블로그"(상태 404) → 해제 → 다시 보임 (AS3, quickstart #12~#15)

### Implementation for User Story 1 (backend)

- [x] T050 [US1] 대상 처리기: `blog-backend/src/main/java/net/java21/blog/backend/report/service/ReportTargetHandler.java`(인터페이스), `report/service/PostTargetHandler.java`·`CommentTargetHandler.java`·`GuestbookTargetHandler.java`·`TrackbackTargetHandler.java`, `report/service/ReportTargetHandlers.java`(종류 → 처리기, 없으면 `INVALID`), `report/repository/ReportTargetPreviewRepository.java`(종류별 IN projection), `report/service/ReportUrlResolver.java`
- [x] T051 [US1] 신고 접수: `blog-backend/src/main/java/net/java21/blog/backend/report/service/ReportService.java`, `report/service/RightsRequestService.java`(CAPTCHA·`RateLimiter`), `report/controller/ReportController.java`, `report/controller/RightsRequestController.java`, DTO `report/dto/`(`CreateReportRequest`, `RightsRequestRequest`, `ReportCreatedResponse`)
- [x] T052 [US1] 관리자 신고: `blog-backend/src/main/java/net/java21/blog/backend/admin/report/ReportQueryRepository.java`·`ReportGroupRow.java`, `admin/report/AdminReportService.java`(목록·요약·상세·대상 지정·처리, 조건부 일괄 UPDATE, `ReportResolvedEvent`), `admin/report/AdminReportController.java`, DTO `admin/report/dto/`; 알림은 `notification/service/NotificationEventListener.java`에 `ReportResolvedEvent` 처리, 메일은 `mail/MailService.java`에 `onRightsRequestResolved`(ko·en, 커밋 후 비동기)와 `blog-backend/src/main/resources/messages_{ko,en,ja,zh_CN}.properties`의 `mail.rightsRequest.*` 키
- [x] T053 [US1] 숨김: `blog-backend/src/main/java/net/java21/blog/backend/moderation/ContentHideService.java`(처리기의 `hide`·`unhide` + 작업 기록), `admin/content/AdminContentController.java`·`admin/content/HiddenPostQueryRepository.java`; 글 쪽 규칙은 `post/service/PostPublishService.java`(숨김이면 409 `POST_HIDDEN`), `manage/service/ManagePostBulkService.java`(건너뜀), `post/dto/PostDetailResponse.java`(`hidden`), `post/service/PostService.java`(주인 상세), 관리 글 목록 `status=HIDDEN`(`manage/repository/ManagePostQueryRepository.java`)
- [x] T054 [US1] 댓글·방명록 HIDDEN: `blog-backend/src/main/java/net/java21/blog/backend/comment/service/CommentVisibility.java`·`guestbook/service/GuestbookVisibility.java`(004)에 HIDDEN 규칙, `comment/repository/CommentQueryRepository.java`·`guestbook/repository/GuestbookQueryRepository.java`(자리·제외), `comment/dto/CommentResponse.java`·`guestbook/dto/GuestbookEntryResponse.java`에 `hidden`, `post/repository/PostRepository.java`에 `decrementCommentCount`·`incrementCommentCount`(원자적), 사이드바·대시보드 쿼리(004 `SidebarQueryRepository`, `ManageDashboardService`)에서 HIDDEN 제외
- [x] T055 [US1] 정지와 회원 관리: `blog-backend/src/main/java/net/java21/blog/backend/admin/user/SuspensionService.java`, `security/SuspendedUserRegistry.java`(Caffeine, 커밋 후 등록·해제), `security/JwtAuthenticationFilter.java`(등록된 회원 토큰은 인증하지 않음), `admin/user/AdminUserQueryRepository.java`·`AdminUserService.java`(검색·상세)·`AdminUserController.java`(검색·상세·정지·해제), DTO `admin/user/dto/`
- [x] T056 [US1] `blog-backend/src/main/java/net/java21/blog/backend/blog/service/BlogAccess.java`에 `requireVisibleBlogForPage(handle)`(주인 SUSPENDED면 404 `BLOG_RESTRICTED`)를 두고 `blog/controller/BlogController.java`의 `GET /blogs/{handle}`만 사용
- [x] T057 [US1] `blog-backend/src/main/java/net/java21/blog/backend/report/repository/ReportPenaltyPolicy.java`(003 `BlogPenaltyPolicy` 구현), `portal/service/NoBlogPenaltyPolicy.java` 삭제와 빈 구성 정리

### Implementation for User Story 1 (front)

- [x] T058 [US1] 신고 UI: `blog-front/app/components/report/ReportButton.tsx`·`ReportDialog.tsx`·`ReasonSelect.tsx`, `blog-front/app/moderation/reasons.ts`·`reportTarget.ts`, 공용 action `blog-front/app/components/report/actions.server.ts`(`intent=report`), 연결: `blog-front/app/routes/post-detail.tsx`(글), `app/components/comment/CommentSection.tsx`(댓글, 앵커), `app/components/guestbook/GuestbookEntryItem.tsx`(004, 앵커), 문구 `report` namespace(4개 언어)
- [x] T059 [US1] `blog-front/app/routes/rights-request.tsx`(loader·action·meta), `blog-front/app/routes.ts`에 `rights-request`(고정 경로, `:handle` 앞), 문구 `report` namespace
- [x] T060 [US1] 콘솔 신고: `blog-front/app/routes/admin/reports.tsx`, `blog-front/app/routes/admin/report.tsx`, `blog-front/app/components/admin/ReportGroupTable.tsx`·`ReportTargetPreview.tsx`, `blog-front/app/admin/links.ts`·`routes/admin/layout.tsx`에 "신고 관리"(배지)·"숨긴 글", `routes.ts`의 admin 자식에 `reports`·`reports/:id`·`contents/hidden-posts`, 문구 `admin` namespace
- [x] T061 [US1] 콘솔 회원: `blog-front/app/routes/admin/users.tsx`, `blog-front/app/routes/admin/user.tsx`(정지·해제·블로그 한도), `blog-front/app/routes/admin/hidden-posts.tsx`, `blog-front/app/components/admin/UserSearch.tsx`, 메뉴 "회원 관리", `routes.ts`에 `users`·`users/:id`, 문구 `admin` namespace
- [x] T062 [US1] 공개 화면 변경: `blog-front/app/routes/blog/layout.tsx`(004)에 `BLOG_RESTRICTED` 분기와 `blog-front/app/components/blog/RestrictedBlog.tsx`, `routes/post-detail.tsx`의 숨김 안내, 댓글·방명록 숨김 표시, `routes/manage/posts.tsx`의 "숨김" 필터·비활성 버튼, `routes/notifications.tsx`·`app/components/notification/*`의 `REPORT_RESOLVED`, 문구 `moderation`·`manage`·`notification` namespace(4개 언어)

**Checkpoint**: US1 Independent Test E2E 통과(CI `e2e-backend`에서 실제로 실행), quickstart #1~#20

---

## Phase 4: User Story 2 - 스팸·어뷰징 방어 (Priority: P2)

**Goal**: 가입·비회원 쓰기·반복 로그인 실패·권리 침해 신고에 CAPTCHA를 걸고, 글 발행·댓글·방명록·이미지 업로드·가입의 속도를 운영자가 바꿀 수 있는 한도로 제한하며, 금칙어가 들어간 이름은 거부하고 댓글·방명록은 거부하거나 가리며, 같은 내용 댓글을 짧은 시간 반복하면 막는다.

**Independent Test**(plan이 FR에서 만듦): 관리자가 금칙어(본문류·가림)와 댓글 한도를 정함 → 회원이 금칙어 댓글을 쓰면 가려져 저장되고, 한도를 넘거나 같은 내용을 반복하면 거부되며, CAPTCHA 없이 가입 API를 부르면 거부되는지 확인(quickstart #21~#28).

FR: FR-141, FR-142, FR-143, FR-144 (006 "스팸 방어 설정" 메뉴)

### Tests for User Story 2 (backend) ⚠️

- [x] T063 [P] [US2] `blog-backend/src/test/java/net/java21/blog/backend/spam/BannedWordMatcherTest.java`: 정규화(NFKC·trim·소문자, 전각 "ＢＡＤ" → "bad"), 이름류는 공백·구두점을 지운 문자열에도 일치("나쁜 말"), 본문류 REJECT가 하나라도 있으면 거부, MASK만 있으면 같은 길이 `*`로(여러 번·겹침), 범위(NAME·CONTENT·ALL) 구분, 빈 목록, 목록 다시 읽기 후 반영 (research M11)
- [x] T064 [P] [US2] `blog-backend/src/test/java/net/java21/blog/backend/spam/BannedWordServiceTest.java`·`admin/spam/AdminBannedWordControllerTest.java`·`spam/repository/BannedWordRepositoryTest.java`(`@JpaRepositoryTest`): 추가(정규화 저장, 1~50자, 중복 409 `BANNED_WORD_EXISTS`, NAME + MASK 400 `INVALID`), 수정·삭제(없음 404 `BANNED_WORD_NOT_FOUND`), 커밋 후 캐시 다시 읽기, 작업 기록 `BANNED_WORD_*`, 목록 검색·페이지(쿼리 2회), 관리자 외 404
- [x] T065 [P] [US2] `blog-backend/src/test/java/net/java21/blog/backend/spam/DuplicateContentDetectorTest.java`: 같은 주체·같은 정규화 내용이 창(10분) 안 3회까지 통과·4번째 422 `DUPLICATE_CONTENT_SPAM`, 공백·대소문자 차이는 같은 내용, 10자 미만은 세지 않음, 주체가 다르면 따로, 창이 지나면 초기화(`Ticker`), 설정 값 반영 (FR-144)
- [x] T066 [P] [US2] `blog-backend/src/test/java/net/java21/blog/backend/spam/WriteGuardTest.java`와 `comment/service/CommentServiceTest.java`·`guestbook/service/GuestbookServiceTest.java`에 추가: 댓글·방명록 쓰기 순서 — 비회원 CAPTCHA(없거나 틀림 400 `CAPTCHA_FAILED`, 회원은 검사 안 함) → 속도(회원 ID 또는 비회원 IP, 한도 넘으면 429) → 금칙어(내용 REJECT 400 field `content` `BANNED_WORD`, MASK는 가린 값 저장, 비회원 이름 이름류 400 field `guestName`) → 반복 스팸 422; 수정은 금칙어만; 관리자는 속도·반복 제외; 004 `GuestWriteGuard` 구현이 `WriteGuard`로 바뀌어도 004 시험 통과 (FR-141~144)
- [x] T067 [P] [US2] `blog-backend/src/test/java/net/java21/blog/backend/auth/service/SignupServiceTest.java`·`blog/service/BlogServiceTest.java`·`user/service/AccountServiceTest.java`에 추가: 가입 CAPTCHA(400 `CAPTCHA_FAILED`, 저장 없음), 같은 IP 1시간 5회 넘으면 429, 닉네임·블로그 주소 금칙어 400 field `BANNED_WORD`; 블로그 만들기의 주소·제목, 블로그 수정의 제목, 프로필 닉네임 수정 금칙어 (FR-141~143)
- [x] T068 [P] [US2] `blog-backend/src/test/java/net/java21/blog/backend/spam/captcha/LoginCaptchaPolicyTest.java`·`auth/service/LoginServiceTest.java`에 추가: 같은 이메일 해시 또는 같은 IP 연속 3회 실패 뒤 토큰 없이 로그인 400 `CAPTCHA_REQUIRED`(비밀번호 확인 전, 잠금 수를 늘리지 않음), 틀린 토큰 400 `CAPTCHA_FAILED`, 맞는 토큰이면 평소 흐름, 성공하면 두 카운터 초기화, 없는 이메일도 카운트(존재 여부를 드러내지 않음), 001의 5회 잠금은 그대로 (FR-141)
- [x] T069 [P] [US2] `blog-backend/src/test/java/net/java21/blog/backend/post/service/PostPublishServiceTest.java`·`media/service/MediaServiceTest.java`에 추가: 처음 발행(DRAFT → PUBLISHED·SCHEDULED)만 회원 1시간 10편(여러 블로그 합계)으로 셈, 수정 재발행·예약 작업의 발행은 세지 않음, 11번째 429; 이미지 업로드 1분 30개 429 (FR-142)
- [x] T070 [P] [US2] 컨트롤러: `blog-backend/src/test/java/net/java21/blog/backend/auth/controller/AuthControllerTest.java`(가입·로그인 `captchaToken` 바인딩, 400·429 형식과 `Retry-After`), `comment/controller/CommentControllerTest.java`·`guestbook/controller/GuestbookControllerTest.java`(429·422·필드 `BANNED_WORD`), `media/controller/MediaControllerTest.java`(429)

### Tests for User Story 2 (front) ⚠️

- [x] T071 [P] [US2] `blog-front/tests/unit/routes/signup.test.tsx`·`tests/unit/routes/login.test.tsx`에 추가: 가입 폼의 CAPTCHA와 `captchaToken` 전송, 닉네임·주소 `BANNED_WORD` 필드 문구, 429 문구; 로그인 `CAPTCHA_REQUIRED`면 같은 화면에 CAPTCHA를 보이고 입력 값 유지, `CAPTCHA_FAILED` 문구
- [x] T072 [P] [US2] `blog-front/tests/unit/routes/adminSpam.test.tsx`: 한도 5개와 반복 기준의 현재 값·기본값·바꾼 관리자, 저장(`PUT /admin/settings/{key}`)·"기본값으로"(`DELETE`), 범위 오류 문구; 금칙어 목록·검색·추가(범위·처리 방식, 이름류면 "가림" 비활성)·변경·삭제(확인)와 오류 문구
- [x] T073 [P] [US2] `blog-front/tests/unit/components/CommentSection.test.tsx`·`tests/unit/routes/blogGuestbook.test.tsx`(004)·`tests/unit/routes/settingsProfile.test.tsx`·`tests/unit/routes/manageSettings.test.tsx`에 추가: 비회원 쓰기 폼의 CAPTCHA, `BANNED_WORD`·`DUPLICATE_CONTENT_SPAM`·429 문구, 프로필 닉네임·블로그 제목 금칙어 문구
- [x] T074 [P] [US2] E2E `blog-front/tests/e2e/moderation-us2-spam.spec.ts`(`requireBackend`·`requireAdmin`·`requireModerationTestSettings`, `moderation` 프로젝트): 관리자가 실행마다 고유한 금칙어 두 개(이름류 거부, 본문류 가림) 추가 → 그 단어가 든 닉네임으로 가입 거부 → 회원 댓글이 가려져 저장 → 단어 삭제(정리); 새 회원이 같은 고유 문구 댓글 3개 뒤 4번째 거부(FR-144); `captchaToken` 없이 `POST /api/v1/auth/signup` 400 `CAPTCHA_FAILED`; 관리자가 `/admin/spam`에서 댓글 한도를 바꾸고 "기본값으로" 되돌리는 화면 흐름(값 표시 확인, 한도 넘김 자체는 단위 테스트가 확인) (quickstart #23~#26)

### Implementation for User Story 2 (backend)

- [x] T075 [US2] `blog-backend/src/main/java/net/java21/blog/backend/spam/BannedWordMatcher.java`(메모리 캐시, 커밋 후 다시 읽기), `spam/BannedWordService.java`, `admin/spam/AdminBannedWordController.java`, DTO `admin/spam/dto/`
- [x] T076 [US2] `blog-backend/src/main/java/net/java21/blog/backend/spam/DuplicateContentDetector.java`, `spam/WriteGuard.java`(CAPTCHA·속도·금칙어·반복을 한 곳에서, 004 `GuestWriteGuard` 인터페이스 구현으로 등록하고 `RateLimitGuestWriteGuard` 삭제), `comment/service/CommentService.java`·`guestbook/service/GuestbookService.java`(004)에서 회원 쓰기도 `WriteGuard` 통과, `comment/dto/CreateCommentRequest.java`·`guestbook/dto/GuestbookWriteRequest.java`에 `captchaToken`
- [x] T077 [US2] 이름류 금칙어와 가입 보호: `blog-backend/src/main/java/net/java21/blog/backend/auth/service/SignupService.java`(CAPTCHA, IP 한도, 닉네임·주소), `auth/dto/SignupRequest.java`에 `captchaToken`, `blog/service/BlogService.java`(만들기 주소·제목, 수정 제목), `user/service/AccountService.java`(닉네임)
- [x] T078 [US2] 로그인 CAPTCHA: `blog-backend/src/main/java/net/java21/blog/backend/spam/captcha/LoginCaptchaPolicy.java`, `auth/service/LoginService.java`, `auth/dto/LoginRequest.java`에 `captchaToken`
- [x] T079 [US2] 발행·업로드 속도: `blog-backend/src/main/java/net/java21/blog/backend/post/service/PostPublishService.java`(처음 발행 판정 지점), `media/service/MediaService.java`(업로드)

### Implementation for User Story 2 (front)

- [x] T080 [US2] `blog-front/app/routes/signup.tsx`·`blog-front/app/routes/login.tsx`에 `Captcha`와 오류 처리, 문구 `auth` namespace(4개 언어)
- [x] T081 [US2] 004 비회원 쓰기 폼 `blog-front/app/components/comment/GuestFields.tsx`에 `Captcha`, `app/components/comment/actions.server.ts`·`app/routes/blog-guestbook.tsx`의 `captchaToken` 전달과 오류 문구, `app/routes/settings.profile.tsx`·`app/routes/manage/settings.tsx`·`app/routes/settings.blogs.tsx`의 `BANNED_WORD` 문구, 이미지 업로드 429 문구(`app/components/Editor`), 문구 `comment`·`guestbook`·`settings`·`media` namespace
- [x] T082 [US2] `blog-front/app/routes/admin/spam.tsx`, `blog-front/app/components/admin/RateLimitForm.tsx`·`BannedWordTable.tsx`, 콘솔 메뉴 "스팸 방어 설정", `routes.ts`에 `spam`, 문구 `admin` namespace

**Checkpoint**: US2 Independent Test E2E 통과, quickstart #21~#28

---

## Phase 5: User Story 3 - 트랙백 주고받기 (Priority: P3, 가장 낮음)

**Goal**: 공개 글마다 트랙백 주소가 있고 외부 블로그가 TrackBack 1.2 핑을 보내면 글 아래 목록에 쌓이며, 회원은 글을 발행·수정할 때 트랙백을 보내 결과를 본다. 블로그 주인은 트랙백 받기를 끄고 받은 트랙백을 지울 수 있고, 반복 핑과 중복은 거부된다.

**Independent Test**: 블로그 A의 글 주소에 표준 트랙백 핑을 보냄 → A의 글 아래 트랙백(보낸 글 제목·요약·블로그 이름·링크)이 보이는지 확인. 반대로 블로그 B에서 글을 발행하며 A의 글 트랙백 주소를 입력 → A의 글에 트랙백이 생기는지 확인(quickstart #29~#41).

FR: FR-049~055, SC-009 (006 블로그 관리 "받은 트랙백", 블로그 설정 "트랙백 허용")

### Tests for User Story 3 (backend) ⚠️

- [x] T083 [P] [US3] `blog-backend/src/test/java/net/java21/blog/backend/trackback/TrackbackUrlsTest.java`: 정규화(스킴·호스트 소문자, 기본 포트·조각 제거, 경로·쿼리 유지)와 SHA-256, 같은 주소의 다른 표기가 같은 해시, 서비스 안 주소 판별(`{base-url}/{handle}/{postId}`와 `/trackback`, 다른 호스트·포트·숫자 아닌 글번호는 밖), 1000자 초과·http/https 외 거부
- [x] T084 [P] [US3] `blog-backend/src/test/java/net/java21/blog/backend/trackback/service/TrackbackReceiveServiceTest.java`: 확인 순서(IP 한도 → 글·handle 일치·본문 노출 가능 → `trackback_enabled` → url → 중복 → 저장), 비공개·보호·임시·예약·삭제·숨김·정지 회원 글과 꺼진 블로그 모두 "허용 안 함"(저장 없음, FR-055, AS3), 같은 주소 재전송·DELETED·HIDDEN 행과 겹침은 중복(FR-054), 동시 저장의 UNIQUE 위반도 중복, 제목·요약·블로그 이름 태그 제거·제어 문자 제거·255자, 제목 없으면 url, 송신 IP 암호화, 내부 수신은 IP 한도 없이 `source_post_id` 채움, 11번째 핑 거부(AS5, Edge Cases)
- [x] T085 [P] [US3] `blog-backend/src/test/java/net/java21/blog/backend/trackback/controller/TrackbackXmlControllerTest.java`: `POST /{handle}/{postId}/trackback` 성공 XML(`<error>0</error>`), 실패 XML 메시지 5종(XML 이스케이프), 항상 200·`text/xml; charset=utf-8`, Origin 없이 통과, `charset=EUC-KR` 본문 바이트를 올바르게 디코딩, charset 없으면 UTF-8, 숫자 아닌 postId 404, GET 405, 공통 응답 틀이 아님
- [x] T086 [P] [US3] `blog-backend/src/test/java/net/java21/blog/backend/trackback/TrackbackInteropTest.java`(`@WebMvcTest` + 실제 `TrackbackReceiveService`와 가짜 저장소, 또는 `@JpaRepositoryTest` 조합): research M17의 고정 요청 20가지(Movable Type·WordPress·티스토리 형식·EUC-KR 설치형·선택 필드 없음·큰 excerpt·HTML 엔터티 등)가 모두 저장되고 저장 값이 기대와 같음 — SC-009 수신 기준(95% 이상, 현재 목록은 100%)
- [x] T087 [P] [US3] `blog-backend/src/test/java/net/java21/blog/backend/trackback/repository/TrackbackQueryRepositoryTest.java`(`@JpaRepositoryTest`): 글 상세 목록(ACTIVE만, 최신순, `totalCount`), 서비스 안 출처 글이 본문 노출 가능이 아니면(비공개·삭제·숨김·작성자 정지) 빠짐, 밖 출처는 그대로, 쿼리 2회(목록 + 개수, 출처 글·블로그·작성자 LEFT JOIN 별칭); 블로그 관리 목록(그 블로그 글들의 ACTIVE·HIDDEN, 받은 글 제목, 쿼리 2회); 보낸 기록 최신 50(1회); `PostExposure.bodyVisible(QPost, QBlog, QUser)` 별칭 오버로드가 기본 조각과 같은 결과 (FR-051, research M14)
- [x] T088 [P] [US3] `blog-backend/src/test/java/net/java21/blog/backend/trackback/service/TrackbackServiceTest.java`와 `post/service/PostServiceTest.java`·`blog/service/BlogServiceTest.java`에 추가: 주인 삭제(ACTIVE → DELETED, 남의 글 403, HIDDEN·DELETED·없음 404 `TRACKBACK_NOT_FOUND`), 목록은 글 상세를 볼 수 있을 때만(아니면 404 `POST_NOT_FOUND`); `PostDetail.trackbackUrl`(본문 노출 가능 + 블로그 허용일 때만, 주소 형식)·`trackbackCount`; `PATCH /blogs/{h}`의 `trackbackEnabled`(주인만, null 400 `REQUIRED`), 응답 필드 (FR-049, FR-053, AS4·AS6)
- [x] T089 [P] [US3] `blog-backend/src/test/java/net/java21/blog/backend/trackback/service/TrackbackSendServiceTest.java`와 `post/service/PostPublishServiceTest.java`에 추가: `trackbackUrls` 검증(최대 10·형식·중복 하나로, 400 field), PUBLIC이 아니면 422 `TRACKBACK_NOT_ALLOWED`, 주소마다 PENDING 기록, 즉시 발행·발행된 글 수정이면 커밋 후 `TrackbackSendRequested`, 예약(004)이면 기록만; 예약 취소·휴지통 이동이 그 글의 PENDING 기록 삭제; 004 `ScheduledPublishJob`이 발행한 글마다 PENDING을 찾아 이벤트(004 `ScheduledPublishJobTest`에 추가) (FR-052, AS2)
- [x] T090 [P] [US3] `blog-backend/src/test/java/net/java21/blog/backend/trackback/service/TrackbackPingerTest.java`(`StubHttpServer`, `blog.outbound.allow-private=true`): 보낸 요청이 form-urlencoded UTF-8의 `url`·`title`·`excerpt`(255자)·`blog_name`과 `User-Agent`, `<error>0</error>` → SUCCESS, `<error>1</error><message>…` → REMOTE_ERROR(메시지 태그 제거 255자), 500 → HTTP_ERROR, XML 아님 → REMOTE_ERROR, 6초 지연 → TIMEOUT(5초), 302 리다이렉트를 따르지 않음 → HTTP_ERROR, 64KB 넘는 본문은 잘라 읽음, DOCTYPE·외부 엔터티가 있는 응답이 파일·네트워크를 읽지 않음(XXE), 내부 주소(allow-private=false) → BLOCKED_ADDRESS·요청 없음, `attempted_at` 기록 (FR-052, Edge Cases, research M15·M16)
- [x] T091 [P] [US3] `blog-backend/src/test/java/net/java21/blog/backend/trackback/service/TrackbackDispatchListenerTest.java`·`trackback/service/PendingPingRecoveryTest.java`: 서비스 안 주소는 HTTP 없이 내부 수신(`source_post_id`, 대상 글이 볼 수 없으면 REMOTE_ERROR와 메시지), 보내기 직전 글이 더는 본문 노출 가능이 아니면 PENDING 삭제·전송 없음, 대상별 결과 갱신, 한 대상 실패가 다른 대상에 영향 없음; 기동 복구는 5분 넘은 PENDING 중 글이 발행된 것만 다시 보내고 예약 글의 PENDING은 그대로
- [x] T092 [P] [US3] `blog-backend/src/test/java/net/java21/blog/backend/trackback/controller/TrackbackControllerTest.java`: `GET /api/v1/posts/{id}/trackbacks` 비로그인 200 Page, `DELETE /api/v1/trackbacks/{id}` 200·401·403·404, `GET /api/v1/blogs/{h}/manage/trackbacks` 주인 200·`no-store`, `GET /api/v1/posts/{id}/trackback-pings` 주인만; `post/controller/PostControllerTest.java`에 `trackbackUrl`·`trackbackCount`, 발행 설정의 `trackbackUrls` 검증 오류 형식

### Tests for User Story 3 (front) ⚠️

- [x] T093 [P] [US3] `blog-front/tests/unit/components/TrackbackList.test.tsx`·`TrackbackUrlBox.test.tsx`·`TrackbackRdf.test.tsx`와 `tests/unit/routes/postDetail.test.tsx`에 추가: 트랙백 영역(주소·복사 버튼, JS 없을 때 선택 가능한 입력란, `trackbackUrl` null이면 "트랙백을 받지 않는 글"), 목록(제목 링크 `rel="nofollow ugc noopener"`, `http(s):`가 아니면 텍스트, `<script>` 제목이 텍스트로), `?tbPage=` 더 보기, 각 트랙백 "신고"·앵커 `#trackback-{id}`, SSR HTML 주석 안 RDF(`dc:identifier`·`trackback:ping`, 제목 XML 이스케이프, `--` 문자열이 주석을 깨지 않음)
- [x] T094 [P] [US3] `blog-front/tests/unit/components/PublishSettingsDialog.test.tsx`(004)와 `tests/unit/routes/managePosts.test.tsx`에 추가: "트랙백 보내기" 입력(줄마다 주소, 최대 10, 공개가 아니면 비활성과 안내), `trackbackUrls` 전송, 필드 오류·`TRACKBACK_NOT_ALLOWED` 문구, 보낸 기록(성공·실패 이유·보내는 중) 목록, 관리 글 목록 "트랙백 결과" 펼침
- [x] T095 [P] [US3] `blog-front/tests/unit/routes/manageTrackbacks.test.tsx`·`tests/unit/routes/manageSettings.test.tsx`: 받은 트랙백 목록(받은 글 제목, 숨김 표시·삭제 비활성), 삭제 action(확인), 빈 목록 문구, 트랙백 받기 상태; 설정의 "트랙백 받기" 체크와 PATCH `{ trackbackEnabled }`
- [x] T096 [P] [US3] `blog-front/tests/unit/server/backendProxy.test.ts`에 추가: `POST /:handle/:postId/trackback`의 본문 바이트(EUC-KR)와 `Content-Type` charset을 바꾸지 않고 넘기고 응답 XML을 그대로 돌려줌, `X-Forwarded-For` 전달
- [x] T097 [P] [US3] E2E `blog-front/tests/e2e/moderation-us3-trackback.spec.ts`(`requireBackend`·`requireModerationTestSettings`): Independent Test 받기(`sendTrackbackPing`으로 A 글에 핑 → `error 0` → 글 상세 트랙백 목록에 제목·요약·블로그 이름·링크, 같은 핑 `Duplicate trackback`), 보내기(B가 발행 설정에 A 글 주소 입력·발행 → A 글에 B 글 트랙백, B의 결과 "성공"), 비공개 글·트랙백 끈 블로그 거부(AS3), A가 관리 화면에서 삭제 후 재핑 중복(AS4), 글 상세 트랙백 주소·RDF(AS6), `requireAdmin`일 때 트랙백 신고 → 숨김 → 목록에서 사라짐 (quickstart #29~#33, #36, #38~#39, #41)

### Implementation for User Story 3 (backend)

- [x] T098 [US3] 받기: `blog-backend/src/main/java/net/java21/blog/backend/trackback/TrackbackUrls.java`, `trackback/service/TrackbackReceiveService.java`(`receive(handle, postId, form, ip)`·`receiveInternal(sourcePost, targetPostId)`), `trackback/controller/TrackbackXmlController.java`(원시 본문을 charset으로 디코딩, XML 응답, springdoc 제외), `trackback/TrackbackXml.java`(이스케이프한 응답 문자열)
- [x] T099 [US3] 목록·삭제·주소: `blog-backend/src/main/java/net/java21/blog/backend/post/repository/PostExposure.java`에 별칭을 받는 `bodyVisible(QPost, QBlog, QUser)`, `trackback/repository/TrackbackQueryRepository.java`·`TrackbackRow.java`, `trackback/service/TrackbackService.java`·`TrackbackVisibility.java`, `trackback/controller/TrackbackController.java`, DTO `trackback/dto/`, `post/dto/PostDetailResponse.java`에 `trackbackUrl`·`trackbackCount`(`post/service/PostService.java`), `blog/dto/UpdateBlogRequest.java`·`BlogResponse.java`·`blog/service/BlogService.java`에 `trackbackEnabled`
- [x] T100 [US3] 보내기 요청: `blog-backend/src/main/java/net/java21/blog/backend/trackback/service/TrackbackSendService.java`(검증·PENDING 기록·이벤트), `post/dto/PublishSettingsRequest.java`에 `trackbackUrls`, `post/service/PostPublishService.java` 연결, 004 `post/job/ScheduledPublishJob.java`의 발행 지점에서 `TrackbackSendRequested`, 예약 취소(004 `unschedule`)·휴지통 이동(001 `moveToTrash`)에서 PENDING 삭제
- [x] T101 [US3] 보내기 실행: `blog-backend/src/main/java/net/java21/blog/backend/trackback/service/TrackbackPinger.java`(JDK `HttpClient`, `Redirect.NEVER`, 시간 제한, 64KB, XXE 끈 `DocumentBuilderFactory`), `trackback/service/TrackbackDispatchListener.java`(`@Async("trackbackExecutor")` + `@TransactionalEventListener(AFTER_COMMIT)`), `trackback/TrackbackExecutorConfig.java`(스레드 2·대기열 100, 넘치면 FAILED `REMOTE_ERROR` "Queue full"), `trackback/service/PendingPingRecovery.java`(`ApplicationReadyEvent`)

### Implementation for User Story 3 (front)

- [x] T102 [US3] 글 상세 트랙백: `blog-front/app/components/trackback/TrackbackList.tsx`·`TrackbackUrlBox.tsx`·`TrackbackRdf.tsx`, `blog-front/app/routes/post-detail.tsx`(loader에 `GET /posts/{id}/trackbacks?page=` 병렬, `tbPage`), 트랙백 신고 버튼(US1 `ReportButton`), 문구 `trackback` namespace(4개 언어)
- [x] T103 [US3] 보내기 UI: `blog-front/app/components/trackback/TrackbackTargetsField.tsx`·`PingResultList.tsx`를 `app/components/post/PublishSettingsDialog.tsx`와 `app/routes/write.tsx`에, `app/routes/manage/posts.tsx`에 "트랙백 결과", 문구 `trackback`·`post`·`manage` namespace
- [x] T104 [US3] `blog-front/app/routes/manage/trackbacks.tsx`, `blog-front/app/manage/links.ts`·`routes/manage/layout.tsx`에 "받은 트랙백"(댓글 다음 — 구현은 006 FR-099 순서대로 통계 다음), `routes.ts`의 manage 자식에 `trackbacks`, `app/routes/manage/settings.tsx`에 "트랙백 받기", 문구 `manage`·`trackback` namespace

**Checkpoint**: US3 Independent Test E2E 통과, quickstart #29~#41

---

## Phase 6: Polish & Cross-Cutting Concerns

- [x] T105 [P] `blog-backend/src/test/java/net/java21/blog/backend/integration/ModerationExposureIntegrationTest.java`(`@SpringBootTest`, H2, `blog.portal.cache-ttl=0s`): 노출 매트릭스 HIDDEN·SUSPENDED 행을 블로그 홈·카테고리·태그·공지·보관함·사이드바·검색(H2 대체 경로)·구독 피드·RSS·Atom·사이트맵·포털·주제·관련 글·트랙백 목록(출처 글)에서 한 번에(주인 외 0건), 숨긴 댓글·방명록·트랙백이 권한 밖 응답에 0건, 정지 회원 블로그 `BLOG_RESTRICTED`, 권리 침해 연락 이메일·트랙백 송신 IP·신고자 신원이 관리자 외 어떤 응답에도 없음 (001 SC-004)
- [x] T106 [P] `blog-backend/src/test/java/net/java21/blog/backend/integration/TrackbackRoundTripIntegrationTest.java`(`@SpringBootTest(webEnvironment = RANDOM_PORT)`, `blog.outbound.allow-private=true`, `blog.base-url`은 다른 호스트로 두어 HTTP 경로를 탐): B 글 발행 시 A 글의 트랙백 주소(실제 HTTP)로 보내 SUCCESS와 A 글 트랙백 1건, 같은 요청 재발행은 REMOTE_ERROR(`Duplicate trackback`) (SC-009 송신)
- [x] T107 [P] `blog-backend/src/test/java/net/java21/blog/backend/openapi/OpenApiContractTest.java`에 contracts/api.md의 005 엔드포인트(공개 4, 주인 3, 관리자 16)와 확장 필드, 트랙백 XML 경로는 문서에 없음을 확인
- [x] T108 [P] `blog-backend/src/test/java/net/java21/blog/backend/security/CacheHeadersWebMvcTest.java`에 005 관리자·주인 API `no-store`, `GET /captcha/config` `public, max-age=3600`, 트랙백 XML 응답 `no-store`
- [x] T109 [P] 운영 문서 `blog-backend/docs/operations.md`에 005 프로퍼티(`blog.ratelimit.*`, `blog.spam.*`, `blog.captcha.*`, `blog.reports.*`, `blog.trackback.*`, `blog.outbound.*`, `blog.privacy.*` 추가 값), Turnstile 키 발급·환경 변수(`BLOG_CAPTCHA_SITE_KEY`·`BLOG_CAPTCHA_SECRET_KEY`), 트랙백 송신 스레드 풀과 재기동 복구, 내부망 차단의 남은 위험(DNS 재바인딩)과 nginx·방화벽에서의 외부 요청 제한 권고, 운영 설정 키 표, 정지·숨김 절차와 작업 기록 확인, 004 `blog.guest.*-per-minute` 제거 안내. front 4개 언어 README(`blog-front/README.md`·`README.en.md`·`README.ja.md`·`README.zh-CN.md`)에 E2E 환경 변수 `E2E_MODERATION_TEST_SETTINGS`와 E2E용 backend 설정(결정 표 29번)
- [x] T110 [P] E2E `blog-front/tests/e2e/moderation-mobile.spec.ts`(`requireBackend`, 뷰포트 360×740): 글 상세 트랙백 영역, 신고 레이어, `/rights-request`, `/admin/reports`(`requireAdmin`)에서 가로 스크롤 없음 (quickstart #42)
- [ ] T111 SC-009 확인: T086(수신 20가지)·T106(송신 왕복) 결과와, 수동으로 실제 외부 블로그 1곳 이상(트랙백을 받는 설치형 블로그 시험 서버)에 보내고 받은 결과를 backend PR 설명에 기록(도구는 저장소에 추가하지 않음, 95% 미만이면 원인과 대응을 이 표에 결정으로 추가) — (수동, 배포 후: 실제 외부 블로그 송수신은 아직 안 함. T086·T106 자동 테스트는 통과)
- [x] T112 커버리지 확인: `blog-backend`의 `./mvnw verify`, `blog-front`의 `npm test -- --coverage` 모두 라인 80% 이상
- [x] T113 CI 확인: blog-front PR의 `e2e-backend` 잡 로그에서 `moderation-us1-*`·`moderation-us2-*`·`moderation-us3-*`가 **건너뜀(skipped) 없이 통과**했는지 확인하고 PR 설명에 실행 수를 적음(건너뛰었다면 T004 환경 변수부터 고침)
- [ ] T114 `blog-docs/specs/005-trackback-moderation/quickstart.md` 수동 검증 시나리오 #1~#44 전체 실행(backend·front 함께 기동), 끝난 작업을 이 tasks.md에 [x]로 표시 — (수동, 배포 후)

---

## 구현 전 결정 사항 (2026-10-07 확정)

marco가 "묻지 말고 진행"하라고 해서 Claude가 기본값으로 정했다. 바꾸려면 이 표와 관련 문서를 함께 고친다.

| # | 문제 | 결정 | 반영 문서 |
|---|---|---|---|
| 1 | 스토리 순서와 번호 | 소유자 지시대로 트랙백을 가장 낮게: plan US1 = spec US1 신고와 운영(P1), plan US2 = spec에 스토리가 없는 FR-141~144 스팸 방어(P2, FR에서 Independent Test를 만듦), plan US3 = spec US2 트랙백(P3). spec의 "US2 (Priority: P2)" 표기는 고치지 않고 이 표로 대응을 기록. 일정이 부족하면 US3을 뺀다 | plan.md, 이 문서 |
| 2 | 004와의 순서 | 004가 main에 머지된 뒤 시작(공개 블로그 레이아웃, 비회원 쓰기 자리, `canRead`, 예약 발행 작업, 방명록에 기댐). 아래 "004·003 의존" 표 | plan.md |
| 3 | 숨김 방식 | 글은 `status_before_hidden` + HIDDEN, 해제 시 되돌림. 댓글·방명록·트랙백은 ACTIVE ↔ HIDDEN. 노출 조각은 바꾸지 않음(PUBLISHED만 목록) | research M1, data-model |
| 4 | 숨긴 글을 주인이 다루는 범위 | 주인은 상세에서 "관리자가 숨긴 글" 안내와 함께 봄. 발행·발행 설정·일괄 공개 범위 변경은 409 `POST_HIDDEN`(일괄은 건너뜀), 편집 사본 저장·휴지통 이동은 허용(복구하면 HIDDEN) | research M1, contracts/api.md |
| 5 | 외부 글·외부 블로그 신고(007) | `ReportTargetType`에 값과 처리기 자리만. 처리기가 없으면 신고 접수 400 `targetType` `INVALID`. 007이 처리기와 `REMOVE_FROM_PORTAL`·`BLOCK_EXTERNAL_BLOG` 조치를 더함 | research M4, plan.md 범위 밖 |
| 6 | 관리자 미리보기의 내용 범위 | 글은 PUBLIC만 요약, PRIVATE·PROTECTED는 제목만(006 FR-104). 댓글·방명록은 비밀 글이어도 내용 표시(신고 판단에 필요, 신고자가 볼 수 있었던 것만 신고 가능) | research M4 |
| 7 | 신고 처리 단위 | 대상 단위: 처리하면 같은 대상의 PENDING 신고 전체를 같은 결과로 닫음. 대상 없는 권리 침해 신고는 관리자가 대상을 지정한 뒤 조치(기각은 바로 가능). 같은 회원은 같은 대상을 다시 신고할 수 없음(처리 후에도, UNIQUE) | research M2·M3 |
| 8 | 포털 감점 | 최근 90일(`blog.reports.penalty-window`) 안 ACTIONED 신고가 있는 블로그에 `1 - reportPenalty`. 관리자 직접 숨김은 감점에 넣지 않음. 트랙백 신고는 받은 블로그를 감점하지 않음(서비스 안 출처면 출처 블로그) | research M2·M6 |
| 9 | 비회원 처리 결과 메일 언어 | 접수 언어를 저장할 컬럼이 없어(스키마 변경 회피) ko·en 두 언어를 한 메일에. 4개 언어 키는 messages 파일에 모두 둠. 접수 확인 메일은 보내지 않음(제3자 주소로 메일 보내는 수단 방지) | research M10 |
| 10 | 권리 침해 신고 응답과 로그인 사용자 | 202 결과 없음(조회 수단 없음). 로그인 상태로 보내도 `reporter_id` NULL(채널 정의). IP당 1시간 5건 | research M2, contracts/api.md |
| 11 | 연락 이메일·트랙백 IP 파기 | 001 개인정보 파기 작업에 두 단계: 처리 후 1년 지난 `contact_email_enc`, 90일 지난 `sender_ip_enc`를 NULL. 행이 적어 인덱스 없이 매일 1회 훑기 | research M10·M13, plan.md |
| 12 | 정지 권한 규칙 | ADMIN은 USER만 정지, 관리자 정지는 SUPER_ADMIN만, 마지막 SUPER_ADMIN과 자기 자신은 정지 불가, 탈퇴 회원 409. 정지 사유 필수(작업 기록) | research M5 |
| 13 | 정지 즉시 적용 | 갱신 토큰 전부 폐기 + 메모리 정지 목록(접근 토큰 수명 30분 동안 유지)으로 이미 받은 접근 토큰도 즉시 무효. 재기동 때 목록이 비는 위험은 "최대 30분 읽기 화면이 로그인 모양"이며 쓰기는 기존 `isActive` 검사로 막힘 | research M5, Complexity Tracking |
| 14 | 이용 제한 블로그 응답 | `GET /blogs/{handle}`만 404 `BLOG_RESTRICTED`(노출 매트릭스대로 404 유지, 코드로 안내 구분). 하위 API·피드·사이트맵은 기존 404. front는 004 공개 블로그 레이아웃에서 안내 화면 | research M5, contracts/routes.md |
| 15 | 속도 한도 설정 키 모양 | 003 data-model의 `ratelimit.*` 객체 하나 대신 005 data-model대로 키 5개 + `spam.duplicate-comment` 객체. 기본값은 `blog.ratelimit.*`·`blog.spam.*` 프로퍼티 | research M8, contracts/api.md |
| 16 | 004 비회원 속도 제한의 처리 | 004 `RateLimitGuestWriteGuard`와 `blog.guest.comment-per-minute`·`guestbook-per-minute`를 지우고 같은 숫자의 `ratelimit.*` 키로(회원·비회원 같은 한도, 비회원은 IP). E2E 환경 변수도 `BLOG_RATELIMIT_*`로 | research M8, T004·T005·T021 |
| 17 | 발행 한도에서 세는 것 | 처음 발행(DRAFT → PUBLISHED, DRAFT → SCHEDULED)만. 수정 재발행·예약 작업의 실제 발행·휴지통 복구는 세지 않음. 관리자는 모든 속도 제한 제외 | research M8 |
| 18 | 반복 댓글 기준 | 회원 ID 또는 비회원 IP별 같은 정규화 내용이 10분 안 3회면 4번째부터 422(같은 글·다른 글 구분 없음). 정규화 후 10자 미만은 세지 않음(인사말 보호). 방명록도 같은 카운터 | research M12 |
| 19 | CAPTCHA 제공자 | 운영 Cloudflare Turnstile(무료·쿠키 없음), 개발 `none`, E2E·로컬 시험 `test`(고정 토큰 `e2e-pass`, prod에서 기동 실패). 위젯 스크립트는 CAPTCHA 화면에서만 CSP nonce와 함께 | research M9 |
| 20 | 로그인 CAPTCHA 기준 | 같은 이메일 또는 같은 IP 연속 3회 실패 뒤(30분 창). 없는 이메일도 셈. 001의 5회 잠금은 그대로 | research M9 |
| 21 | 금칙어 적용 범위 | 이름류(닉네임·블로그 주소·블로그 제목·비회원 이름)는 항상 거부, 공백·구두점을 지운 문자열에도 검사. 본문류(댓글·방명록)는 단어별 REJECT·MASK. 글 제목·본문·트랙백·카테고리·태그는 적용하지 않음. 기존 데이터는 다시 검사하지 않음. 어느 단어인지는 응답에 넣지 않음 | research M11 |
| 22 | 트랙백 받기를 끈 블로그 | 새 핑만 거부, 이미 받은 트랙백은 계속 표시(주인이 하나씩 삭제). 글 상세 트랙백 주소는 숨김 | research M14 |
| 23 | 트랙백 받기 응답 | 항상 HTTP 200 + TrackBack 1.2 XML, 영어 고정 메시지 5개. 볼 수 없는 글은 "허용 안 함"과 같은 메시지(존재 숨김). 삭제·숨김된 같은 주소도 중복으로 거부 | research M13, contracts/api.md |
| 24 | 트랙백 보내기 조건 | PUBLIC 글만(아니면 422), 최대 10개, 자동 재시도 없음. 서비스 안 주소는 HTTP 없이 같은 규칙. 예약 글은 실제 발행 때 보냄. 상대 글의 트랙백 주소 자동 발견(보내기 쪽)은 하지 않음(받는 쪽 RDF는 제공) | research M14·M15 |
| 25 | 보내지 않은 PENDING의 처리 | 예약 취소·휴지통 이동·보내기 직전 비공개 전환이면 PENDING 기록을 지움(data-model 실패 이유에 "보내지 않음" 값이 없어 값을 늘리지 않음). 송신 대기열이 넘치면 FAILED `REMOTE_ERROR` "Queue full" | research M15 |
| 26 | 내부망 차단의 한계 | `OutboundUrlGuard`가 해석한 모든 주소를 검사하고 리다이렉트를 따르지 않음. JDK `HttpClient`로 해석 주소를 고정할 수 없는 DNS 재바인딩 위험은 운영 문서에 적고 서버 방화벽 권고. 007 피드 수집이 같은 도구를 씀 | research M16, T109 |
| 27 | 관리자 콘솔의 005 범위 | 회원 검색·상세·정지·해제, 신고 목록·상세·처리, 숨긴 글 목록·해제, 스팸 방어 설정. 콘솔 대시보드(처리 대기 신고 수 카드), 숨긴 댓글·방명록 전체 목록, 글·댓글 전체 검색, 권한 부여는 006. 메뉴에 처리 대기 배지만 | plan.md 범위 밖, research M7 |
| 28 | 회원 닉네임 검색 | 앞부분 일치 20건. 인덱스가 없어 지금은 전체 훑기 + `LIMIT`. 인덱스는 선택 DDL 제안 1로 marco 승인 대기 | plan.md "스키마 변경", research M5 |
| 29 | E2E가 CI에서 실제로 도는 조건 | `ci.yml` `e2e-backend`와 `e2e.yml`에 `BLOG_CAPTCHA_PROVIDER=test`, `BLOG_RATELIMIT_*`·`BLOG_TRACKBACK_RECEIVE_LIMIT`·`BLOG_REPORTS_*` 넉넉한 값, Playwright에 `E2E_MODERATION_TEST_SETTINGS=1`. 관리자 계정은 003 것 재사용. 전역 상태를 바꾸는 시나리오는 `moderation` 프로젝트(workers 1). 메일 확인은 Mailpit이 있는 nightly에서만. T113에서 건너뜀 없이 돌았는지 확인 | research M18, T003·T004·T113 |
| 30 | 새 번역 namespace | `report`(신고 버튼·레이어·권리 침해 양식), `trackback`(트랙백 영역·보내기·관리), `moderation`(CAPTCHA·이용 제한 블로그·숨김 안내). 콘솔은 `admin`, 블로그 관리는 `manage`, 알림은 `notification` | contracts/routes.md |
| 31 | 스키마 변경 | 필수 DDL 없음. 선택 인덱스 2개(`idx_users_nickname`, `idx_trackback_ping_logs_status_created`)는 plan.md에 정확한 DDL만 두고 Crowfoot `plan_migration` → marco 승인 전에는 만들지 않음. 이 작업에서 Crowfoot 문서와 DB는 건드리지 않음 | plan.md "스키마 변경" |
| 32 | 다른 스펙의 일 | 외부 글·외부 블로그 신고 처리(007), 콘솔 대시보드·관리자 권한·작업 기록 조회 화면·콘텐츠 전체 검색(006), 핑백·이의 제기(범위 밖) | plan.md "범위 밖" |

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: 001~004가 main에 있어야 함(004 머지 후)
- **Foundational (Phase 2)**: Setup의 프로퍼티(T005)·모델 타입(T002)·CI 환경(T004) 이후. 모든 스토리를 막는다
- **US1 신고와 운영 (Phase 3)**: Phase 2 이후. MVP. 트랙백 처리기(T050의 `TrackbackTargetHandler`)는 Phase 2 트랙백 엔티티(T019)만 있으면 되고, 트랙백 신고 E2E는 US3(T097)에서 확인
- **US2 스팸 방어 (Phase 4)**: Phase 2(`RateLimiter` T021, CAPTCHA T022) 이후. 댓글·방명록 서비스를 US1(T054)과 함께 고치므로 T054 다음에 T076을 머지
- **US3 트랙백 (Phase 5)**: Phase 2(엔티티 T019, `OutboundUrlGuard` T023) 이후. 신고 버튼(T102의 트랙백 신고)은 US1 `ReportButton`(T058) 이후. 가장 낮은 우선순위라 마지막
- **Polish (Phase 6)**: 원하는 스토리가 모두 끝난 뒤

### 004·003 의존 (005가 기대는 앞 스펙 작업)

| 005 작업 | 기대는 작업 | 내용 |
|---|---|---|
| T021, T066, T076 (`WriteGuard`, `RateLimitGuestWriteGuard` 교체) | 004 T024 (`GuestWriteGuard`·`RateLimitGuestWriteGuard`·`GuestAuthorService`) | 004의 비회원 쓰기 자리를 005 장치로 바꿈 |
| T035, T054 (댓글·방명록 HIDDEN) | 004 T043·T094 (`GuestbookVisibility`·`CommentVisibility.canRead`), 004 T042 (`GuestbookQueryRepository`) | 읽기 판단 한 곳에 HIDDEN 규칙 추가 |
| T054 (사이드바·대시보드 HIDDEN 제외) | 004 T045·T067·T068 (`ManageDashboardService`, `SidebarQueryRepository`) | 최근 댓글·방명록 쿼리 |
| T089, T100 (예약 발행 때 트랙백) | 004 T093 (`ScheduledPublishJob`), 004 T091 (`unschedule`) | 발행 지점에 이벤트, 예약 취소에 PENDING 삭제 |
| T047, T062 (이용 제한 블로그 화면) | 004 T046 (`routes/blog/layout.tsx`) | 공개 블로그 레이아웃 loader 분기 |
| T058, T081 (방명록 신고·CAPTCHA) | 004 T047 (`GuestbookEntryItem`, `GuestFields`) | 004 컴포넌트에 버튼·위젯 |
| T094, T103 (발행 설정 트랙백 입력) | 004 T072·T095 (`PublishSettingsDialog`의 공지·보호·예약) | 같은 레이어에 필드 추가 |
| T034, T053 (숨긴 글 발행 거부·일괄 건너뜀) | 004 T064·T075·T091 (`PostPublishService`·일괄 작업의 004 분기) | 같은 서비스 |
| T017 (`GuestbookStatus.HIDDEN`) | 004 T020 (`GuestbookEntry`) | 엔티티 값 |
| T004 (workflow 환경 변수) | 004의 workflow 변경(`BLOG_GUEST_*`, `E2E_GUEST_TEST_SETTINGS`) | 004 변수를 지우고 바꿈 |
| T024, T055, T060 (작업 기록·관리자 화면) | 003 `AdminAuditService`·`AuditActions`·`AdminAccessFilter`·`admin/layout.tsx`·`admin/access.server.ts` | 003 콘솔 뼈대 |
| T011, T024, T082 (설정 키·화면) | 003 `SettingKey`·`AdminSettingService`·`routes/admin/settings.tsx` | 003 설정 체계 |
| T039, T057 (감점 정책) | 003 `BlogPenaltyPolicy`·`NoBlogPenaltyPolicy`·`PopularityCalculator` | 003 자리 교체 |
| T061 (회원 상세의 블로그 한도) | 003 `PATCH /admin/users/{id}/blog-limit`(`AdminUserController`) | 003 API에 화면을 붙임 |

### User Story Dependencies

- **US1 (P1)**: Phase 2 이후. 다른 스토리에 의존하지 않음
- **US2 (P2)**: Phase 2 이후. 독립 테스트 가능(같은 서비스 파일 머지 순서만 US1 다음)
- **US3 (P3)**: Phase 2 이후. 독립 테스트 가능(트랙백 신고 버튼만 US1 컴포넌트 재사용)

### Within Each User Story

- 테스트를 먼저 쓰고 실패를 확인한 뒤 구현한다(원칙 III)
- 엔티티 → 리포지토리(QueryDSL) → 서비스 → 컨트롤러 → front 라우트 → E2E
- 엔티티를 더할 때마다 `EntitySchemaValidationTest`(실제 스키마 대상 `ddl-auto=validate`)가 통과해야 한다
- 새 화면 문구·오류 코드는 같은 작업에서 4개 언어 번역을 넣는다(원칙 VII)
- 스토리의 E2E(Independent Test)가 CI에서 통과해야 다음 우선순위로 넘어간다

### Parallel Opportunities

- Setup의 [P] 작업(T001~T006)은 모두 병렬
- Phase 2 테스트(T007~T014)는 모두 [P], 구현은 엔티티(T016~T020)·front(T027·T028)가 병렬
- 각 스토리의 테스트 작업(backend·front)은 모두 [P]
- Phase 2 이후 US1 backend(T050~T057)와 US3 받기 backend(T098~T099)는 병렬 가능. 같은 파일(`ErrorCode`, `SecurityConfig`, `AuditActions`, `SettingKey`, `PostPublishService`(T053·T079·T100), `PostDetailResponse`(T053·T099), `CommentService`·`GuestbookService`(T054·T076), `BlogService`(T077·T099), `AdminUserController`(T055), `post-detail.tsx`(T058·T062·T102), `PublishSettingsDialog.tsx`(T103), `admin/layout.tsx`·`admin/links.ts`(T060·T061·T082), `manage/layout.tsx`(T104), `routes.ts`, `errors.json`, 두 workflow)을 고치는 작업은 머지 순서를 맞춘다

---

## Parallel Example: User Story 1

```bash
# backend 테스트를 함께 시작:
Task: "ReportServiceTest in blog-backend/src/test/java/net/java21/blog/backend/report/service/ReportServiceTest.java"
Task: "ReportQueryRepositoryTest in blog-backend/src/test/java/net/java21/blog/backend/admin/report/ReportQueryRepositoryTest.java"
Task: "SuspensionServiceTest in blog-backend/src/test/java/net/java21/blog/backend/admin/user/SuspensionServiceTest.java"
Task: "ContentHideServiceTest in blog-backend/src/test/java/net/java21/blog/backend/moderation/ContentHideServiceTest.java"

# front 테스트를 함께 시작:
Task: "ReportDialog.test.tsx in blog-front/tests/unit/components/ReportDialog.test.tsx"
Task: "adminReports.test.tsx in blog-front/tests/unit/routes/adminReports.test.tsx"
Task: "rightsRequest.test.tsx in blog-front/tests/unit/routes/rightsRequest.test.tsx"
```

## Parallel Example: User Story 3

```bash
Task: "TrackbackReceiveServiceTest in blog-backend/src/test/java/net/java21/blog/backend/trackback/service/TrackbackReceiveServiceTest.java"
Task: "TrackbackPingerTest in blog-backend/src/test/java/net/java21/blog/backend/trackback/service/TrackbackPingerTest.java"
Task: "TrackbackQueryRepositoryTest in blog-backend/src/test/java/net/java21/blog/backend/trackback/repository/TrackbackQueryRepositoryTest.java"
Task: "TrackbackList.test.tsx in blog-front/tests/unit/components/TrackbackList.test.tsx"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1 Setup, Phase 2 Foundational(CI에서 001~004 E2E가 새 환경으로 통과하는지 먼저 확인)
2. Phase 3 (US1 신고와 운영)
3. **멈추고 확인**: US1 Independent Test E2E(CI), quickstart #1~#20
4. 시연·배포 가능(신고 버튼, 권리 침해 양식, 콘솔 신고·회원 관리)

### Incremental Delivery

1. Setup + Foundational → 기반 완료(엔티티, 속도 제한기, CAPTCHA, 내부망 차단)
2. US1(Phase 3) → MVP
3. US2(Phase 4) → US3(Phase 5, 일정이 부족하면 생략), 각 스토리의 E2E 통과 후 다음
4. Polish → 노출 매트릭스 통합 확인, SC-009 측정, CI E2E 실행 확인, quickstart 전체 검증

### Parallel Team Strategy

1. 함께 Setup + Foundational
2. Foundational이 끝나면:
   - 개발자 A: Phase 3(US1) backend → front
   - 개발자 B: Phase 4(US2)(댓글·방명록 서비스 머지는 A의 T054 다음)
   - 개발자 C: Phase 5(US3) 받기·목록 backend(T098·T099) → 보내기
3. 같은 파일을 고치는 연결 작업은 머지 순서를 맞춘다(Phase Dependencies, 004·003 의존)

---

## Notes

- [P] = 다른 파일, 끝나지 않은 작업에 의존하지 않음
- [Story] = plan 스토리 번호(US1 = spec US1, US2 = FR-141~144, US3 = spec US2 트랙백)
- 각 PR 설명에 스펙 경로 `blog-docs/specs/005-trackback-moderation`을 적는다(헌법 개발 흐름 6)
- 엔티티는 API 응답으로 직렬화하지 않고 DTO record를 쓴다. 연관관계는 모두 LAZY, 목록은 fetch join 또는 DTO projection, 목록 테스트에는 `QueryCounter`
- 속도 제한·반복 스팸·로그인 실패 카운터, 정지 목록, 금칙어 캐시, 트랙백 송신 스레드 풀은 backend 1대 전제(001 R26)다. 서버를 늘리면 공유 저장소(카운터·정지 목록)와 송신 작업 잠금을 따로 계획한다
- 테스트가 실패하는 것을 먼저 확인하고, 작업 단위로 커밋한다
