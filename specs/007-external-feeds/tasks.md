---
description: "007 외부 블로그 RSS 수집과 주제 자동 분류 작업 목록"
---

# Tasks: 외부 블로그 RSS 수집과 주제 자동 분류

**Input**: `/specs/007-external-feeds/`의 설계 문서 (spec.md, plan.md, research.md, data-model.md, contracts/api.md, contracts/routes.md, quickstart.md)

**Prerequisites**: 001-blog-core·002-discovery-feeds·003-portal 구현 완료(blog-backend·blog-front main), **004-blog-features가 main에 머지된 뒤 시작**(004 Phase 5~8은 `feat/004-rest`에서 구현 중 — 블로그 관리 메뉴·E2E 프로젝트 순서를 공유), **005·006과는 병렬 가능**(005에 기대는 작업은 "(005 머지 후)", 006에 기대는 작업은 "(006 머지 후)"로 표시, 아래 "004·005·006·003 의존"), plan.md, spec.md, research.md, data-model.md, contracts/, 헌법 v2.5.0, [api-guidelines.md](../../api-guidelines.md), [db/README.md](../../db/README.md)

**Tests**: 헌법 원칙 III(NON-NEGOTIABLE)에 따라 모든 스토리에 테스트 작업이 있고, 각 스토리 안에서 테스트 작업이 구현 작업보다 앞선다. 테스트를 먼저 쓰고 **실패하는 것을 확인한 뒤** 구현한다. backend·front 모두 라인 커버리지 80% 미만이면 빌드가 실패한다. Testcontainers는 쓰지 않는다. 외부 HTTP는 JDK `com.sun.net.httpserver.HttpServer` 테스트 서버(`support/StubHttpServer`)와 주입한 `HostResolver` 가짜로만 시험하고 **실제 인터넷에 요청하지 않는다**. MySQL 전용 테스트는 생성 컬럼 UNIQUE 1개(`@MySqlRepositoryTest`)뿐이고 나머지는 H2 `@JpaRepositoryTest` + `QueryCounter`다. E2E는 로컬 피드 스텁 서버(`tests/e2e/support/feed-stub-server.mjs`)만 쓴다.

**Organization**: spec의 사용자 스토리 번호와 우선순위를 그대로 쓴다(US1 등록과 인증 P1, US2 포털 노출 P2, US3 분류 개선과 검수 P3, US4 해제와 운영 P4, 결정 표 1번). 외부 요청·피드 읽기·엔티티는 모든 스토리가 쓰므로 Phase 2에 둔다.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: 병렬 가능(다른 파일, 끝나지 않은 작업에 의존하지 않음)
- **[Story]**: 해당 사용자 스토리(US1~US4)
- 경로는 저장소 이름(`blog-backend/`, `blog-front/`)으로 시작한다(blog-docs CLAUDE.md 규칙)
- 작업 번호는 이 스펙 안에서 T001부터 센다(001~006 tasks.md와 별개)
- **(005 머지 후)** / **(006 머지 후)**: 그 스펙의 코드가 main에 있어야 하는 작업. 그 전에 007을 머지하면 이 작업만 남겨 두고 해당 PR이 끝난 뒤 따로 낸다

## Path Conventions

- backend 소스: `blog-backend/src/main/java/net/java21/blog/backend/{domain}/...` — 이 스펙은 `external/{domain,feed,fetch,classify,thumbnail,verify,portal,report,member,job,event,repository,dto}`, 관리자 API는 `admin/external`, 외부 요청 도구는 `common/net`
- backend 테스트: `blog-backend/src/test/java/net/java21/blog/backend/{domain}/...` (Controller `*ControllerTest` = `@WebMvcTest` + `@Import(WebMvcTestSupport.class)` + `@MockitoBean`, Service `*ServiceTest` = Mockito 단위, Repository `*RepositoryTest` = H2 `@JpaRepositoryTest` + `QueryCounter.assertQueryCount`, MySQL 전용은 `@MySqlRepositoryTest`, 시각 고정은 `support/MutableClock`, Caffeine 시각은 `Ticker`, 외부 HTTP는 `support/StubHttpServer`, 픽스처는 `support/JpaFixtures`·`support/TestEntities`, 피드 고정 데이터는 `src/test/resources/external/feeds/*.xml`)
- backend 리소스: `blog-backend/src/main/resources/`
- front: `blog-front/app/` (routes, components, locales, api, external, admin, manage), 단위 테스트 `blog-front/tests/unit/`, E2E `blog-front/tests/e2e/`(backend 필요 시나리오는 `requireBackend()`, 관리자는 `requireAdmin()`, 외부 수집은 `requireExternalTestSettings()`)
- 화면 문구는 모두 `blog-front/app/locales/{ko,en,ja,zh-CN}/{namespace}.json` 키로 쓰고 4개 언어를 같은 작업에서 넣는다(원칙 VII). 새 namespace는 `external`(파일만 두면 `app/i18n/resources.server.ts`가 모음). 새 오류 코드는 `blog-front/app/api/errorCodes.ts`와 4개 언어 `errors.json`에 함께 넣는다(`tests/unit/i18n/errorCodes.test.ts`).
- backend 오류 코드는 `blog-backend/src/main/java/net/java21/blog/backend/common/error/ErrorCode.java`에 contracts/api.md 표의 이름·HTTP 상태 그대로 더한다.
- 응답 타입은 `blog-front/app/api/models.ts`에 contracts/api.md를 옮겨 적는다.

## 스키마 변경

**필수 DDL 없음.** 007의 테이블 6개(`external_blogs`, `external_blog_verifications`, `external_posts`, `external_post_daily_clicks`, `topic_mapping_rules`, `classification_reviews`), 생성 컬럼 `active_feed_hash` + UNIQUE, 003 `portal_exclusions.external_post_id`·`ck_portal_exclusions_target`, 인덱스 13개, 외래 키 15개가 Crowfoot 문서 "blog 1.0"(`db/schema-mysql.sql`)에 모두 있다(plan.md "스키마 변경"의 쿼리별 대조표). 엔티티 6개는 새로 만들고, 003 `PortalExclusion` 매핑을 바꾼다(T019).

**marco 승인이 필요한 것**: 선택 인덱스 1개(plan.md "스키마 변경"에 정확한 DDL) — `idx_external_posts_topic_decided`(분류 현황의 최근 30일 사람이 확인한 글 기준 정확도). 구현은 이것 없이 동작한다(5분 캐시 안에서 전체 훑기). 넣기로 하면 Crowfoot `plan_migration` → **marco 승인** → `apply_migration` 절차로 따로 요청한다. 이 계획 작업에서는 Crowfoot 문서와 DB를 바꾸지 않았다.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: 프로퍼티, 키워드 사전, front 번역·타입 틀, E2E 피드 스텁과 CI 환경

- [ ] T001 [P] 새 번역 namespace `blog-front/app/locales/{ko,en,ja,zh-CN}/external.json`(상태 `status.*`, 등록 경로·소유 인증·주제 출처 `topicSource.*`, 수집 결과 `fetchResult.*`, 신청 단계·인증 안내·해제 확인·콘솔 화면 문구)과 `portal.json`(외부 배지, 출처 필터, "삭제 요청", 새 탭 안내)·`admin.json`(메뉴 "외부 블로그 관리"와 하위 탭)·`manage.json`(메뉴 "외부 블로그")·`notification.json`(`types.EXTERNAL_BLOG_APPROVED`·`EXTERNAL_BLOG_REJECTED`·`EXTERNAL_FEED_STOPPED`)에 007 키의 뼈대(같은 키 집합, 이후 작업이 채움, `tests/unit/i18n/translations.test.ts`가 4개 언어 키 일치 확인)
- [ ] T002 [P] contracts/api.md 007 타입을 `blog-front/app/api/models.ts`에 추가: `FeedPreview`, `ExternalBlogStatus`, `Verification`, `MyExternalBlog`, `FetchResultCode`, `MyExternalPost`, `AdminExternalBlog`, `AdminExternalPost`, `ExternalExclusion`, `ClassificationReview`, `ClassificationStats`, `TopicMappingRule`; 003 `PortalCard`에 `source`·`visitUrl`·`externalBlog`, `blog.handle`·`author` null 허용(기존 사용처 타입 오류는 이 작업에서 `source === "INTERNAL"` 분기로 정리), `PortalSource = "all" | "internal" | "external"`
- [ ] T003 [P] E2E 피드 스텁(research E18): `blog-front/tests/e2e/support/feed-stub-server.mjs`(Node `node:http`, `127.0.0.1:${E2E_FEED_STUB_PORT ?? 4610}`, 메모리 상태 — `/{name}/feed.xml`(RSS 2.0)·`/{name}/atom.xml`·`/{name}/`(HTML, `<link rel=alternate>`, 소개란에 `verifyCode`)·`/{name}/posts/{n}`(지운 글 404)·`/{name}/img/{n}.png`(8×8 PNG 바이트 상수)·ETag/304·`status` 강제(500 등), 조작 API `POST /__stub/{name}`·`DELETE /__stub/{name}/posts/{n}`·`GET /__stub/{name}/hits`(경로별 요청 수), `GET /__stub/health`), `blog-front/tests/e2e/support/feedStub.ts`(`stubFeed(name, spec)`, `stubUrl(name, path?)`, `addItem`, `removePost`, `setStatus`, `hits`, `uniqueStubName()`), `tests/e2e/support/backend.ts`에 `requireExternalTestSettings()`(`E2E_EXTERNAL_TEST_SETTINGS=1`이 아니면 건너뜀); `blog-front/playwright.config.ts`의 `webServer`를 배열로 바꿔 스텁(`command: "node tests/e2e/support/feed-stub-server.mjs"`, `url: …/__stub/health`, `reuseExistingServer: !CI`)을 더하고 `external` 프로젝트(`testMatch: /external-.*\.spec\.ts$/`, `dependencies: ["portal"]`(005·006 머지 후 `moderation`·`admin` 뒤), `workers: 1`), `e2e` 프로젝트 `testIgnore`에 `external-` 추가
- [ ] T004 [P] CI가 007 E2E를 **실제로 돌리게** workflow 환경을 바꾼다: `blog-front/.github/workflows/ci.yml`의 `e2e-backend` 잡과 `blog-front/.github/workflows/e2e.yml`(nightly)의 "Start backend" `env`에 `BLOG_OUTBOUND_ALLOW_PRIVATE: "true"`·`BLOG_OUTBOUND_ALLOWED_PORTS: "80,443,8080,8443,4610"`(주석 "E2E 피드 스텁이 127.0.0.1:4610, 시험 전용"), `BLOG_EXTERNAL_POLL_INTERVAL: 2s`, `BLOG_EXTERNAL_FETCH_INTERVAL: PT5S`, `BLOG_EXTERNAL_FETCH_JITTER: PT0S`, `BLOG_EXTERNAL_PREVIEW_PER_HOUR: "1000"`, `BLOG_EXTERNAL_VERIFY_CHECKS_PER_HOUR: "1000"`; 두 workflow의 Playwright 단계 `env`에 `E2E_EXTERNAL_TEST_SETTINGS: "1"`, `E2E_FEED_STUB_PORT: "4610"`. 005가 같은 줄(`BLOG_OUTBOUND_*`)을 먼저 넣었으면 포트 값만 합친다. backend 저장소 `blog-backend/.github/workflows/*`에는 E2E가 없음을 확인만 한다
- [ ] T005 [P] backend 프로퍼티(contracts/api.md "프로퍼티" 표): `blog-backend/src/main/java/net/java21/blog/backend/config/ExternalFeedProperties.java`에 `pollInterval`·`fetchInterval`·`fetchJitter`·`leaseTime`·`connectTimeout`·`requestTimeout`·`maxRedirects`·`maxFeedSize`·`maxPageSize`·`maxImageSize`·`initialWindow`·`maxItemsPerFetch`·`maxBackoff`·`stopAfter`·`autoClassifyMinConfidence`·`scoreWeight`·`memberLimit`·`previewPerHour`·`verifyChecksPerHour`·`verificationTtl`·`clickDedupeWindow`·`releaseRetention`·`linkCheckCron`·`linkCheckBatch`·`cleanupCron`·`forbiddenHosts`·`userAgent`(기존 `fetchThreads`·`batchSize`와 `SchedulingConfig` 호출부 유지), `blog-backend/src/main/resources/application.yml` 기본값; 005가 아직 없으면 `common/net/OutboundProperties.java`(`allowed-ports`, `allow-private` — prod 프로필에서 true면 기동 실패)
- [ ] T006 [P] 분류 키워드 사전 `blog-backend/src/main/resources/external/topic-keywords.yml`: 003 `TopicSeeder`의 소분류 slug마다 키워드(한국어·영어·일본어·중국어 낱말과 대표 기술 용어, 소분류당 10개 이상, 대분류 공통어는 넣지 않음), 머리 주석에 버전 `keyword-v1`과 정규화 규칙(NFKC·trim·소문자)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: 외부 요청 도구(SSRF), 피드·HTML 읽기, 요약 추출, 엔티티와 매핑, 설정 키·알림 종류·작업 종류·오류 코드

**⚠️ CRITICAL**: 이 Phase가 끝나기 전에는 어떤 스토리도 시작하지 않는다

### Tests for Foundation ⚠️

> 먼저 쓰고 실패를 확인한다

- [ ] T007 [P] `blog-backend/src/test/java/net/java21/blog/backend/common/net/SafeHttpFetcherTest.java`(`StubHttpServer`, `blog.outbound.allow-private=true`, 가짜 `HostResolver`): 200 본문·ETag·Last-Modified·최종 주소, 조건부 요청 머리글과 304, `Accept-Encoding` 없음·`User-Agent` 값, 301·302·307·308 따라감(최대 3번, 4번째 `HTTP_ERROR`), **리다이렉트 대상이 내부 주소면(가짜 해석기로 `10.0.0.5`) 그 요청을 보내지 않고 `BLOCKED_ADDRESS`**, `Location`이 `file:`·`ftp:`면 `BLOCKED_ADDRESS`, 우리 서비스 호스트(`blog.base-url`·`forbidden-hosts`, 하위 도메인 포함)로 가면 `SELF`로 거부, `Content-Length`가 상한보다 크면 읽지 않고 `TOO_LARGE`, 길이 없이 상한을 넘게 흘려보내면 읽다가 끊고 `TOO_LARGE`, 응답 지연 11초 → `TIMEOUT`(요청 10초), 이름 해석 실패 → `DNS_ERROR`, 404·500 → `HTTP_ERROR`(상태 코드). 005 `OutboundUrlGuardTest`(005 T010)가 아직 없으면 같은 작업에서 그 시험도 만든다 (FR-116, research E2)
- [ ] T008 [P] `blog-backend/src/test/java/net/java21/blog/backend/external/feed/FeedUrlNormalizerTest.java`: `HTTPS://Example.COM:443/feed/` = `http://example.com/feed` = `http://example.com/feed#x`(같은 해시), 쿼리는 유지(`?a=1&b=2` ≠ `?b=2&a=1`), IDN(`http://예시.kr/rss`)은 punycode, 루트 `/`는 빈 경로, 포트 8080은 유지, SHA-256 16진수 64자 (research E6)
- [ ] T009 [P] `blog-backend/src/test/java/net/java21/blog/backend/external/feed/FeedParserTest.java`(고정 데이터 `src/test/resources/external/feeds/`: `rss20.xml`, `rss091.xml`, `rdf10.xml`, `atom10.xml`, `euc-kr.xml`, `doctype-xxe.xml`, `media-rss.xml`, `no-dates.xml`, `big-content.xml`): 형식(RSS/ATOM), 채널 제목·링크, 항목 guid(Atom id)·링크(상대 주소 풀기, `javascript:` 항목 버림, 2000자 넘으면 버림)·제목(태그 제거, 300자, 비면 링크 마지막 조각)·발행 시각(없으면 수정 시각, 둘 다 없으면 null, 미래면 수집 시각)·카테고리(최대 20개·각 100자), 대표 이미지 순서(enclosure image/* → `media:thumbnail` → `media:content` → 본문 첫 `<img>`, `width`·`height` 50 미만 둘 다면 건너뜀, http/https만), **DOCTYPE이 있는 문서는 `PARSE_ERROR`이고 외부 엔터티 파일을 읽지 않음**, EUC-KR 문서 글자 정상, `big-content.xml`(본문 50KB)의 변환 결과 객체에 본문 문자열 필드가 없음(요약만) (FR-114, SC-021, research E3·E4)
- [ ] T010 [P] `blog-backend/src/test/java/net/java21/blog/backend/external/feed/HtmlScannerTest.java`·`SummaryExtractorTest.java`: `<link rel="alternate" type="application/rss+xml|atom+xml">`를 문서 순서대로(상대 주소 풀기, `rel` 대소문자·여러 값), 텍스트 추출에서 `<script>`·`<style>` 내용 버림·블록 경계 공백·엔터티(`&amp;`, `&#x1F600;`) 풀기·공백 정리, 요약 코드 포인트 200자(이모지·결합 문자 경계에서 자르지 않음, 넘으면 199자 + "…"), `<img onerror>`·`<script>alert(1)</script>`가 결과 문자열에 `<`로 남지 않음(태그 자체가 사라짐), `meta` 속성 값 모으기(인증 코드 찾기용) (FR-114, research E3·E4)
- [ ] T011 [P] `blog-backend/src/test/java/net/java21/blog/backend/external/repository/ExternalEntityMappingTest.java`(`@JpaRepositoryTest`): 엔티티 6개 저장·조회(JSON `feed_terms_json` 목록, `DECIMAL(4,3)` 신뢰도, 복합 키 `ExternalPostDailyClick`), `uk_external_posts_blog_guid_hash`·`uk_external_posts_blog_link_hash`·`uk_topic_mapping_rules_keyword`·`uk_classification_reviews_external_post`·`uk_external_blog_verifications_code` 위반, `PortalExclusion`이 내부 글 또는 외부 글 하나만(둘 다·둘 다 없음은 `@Check` 위반), 연관관계 모두 LAZY; `blog-backend/src/test/java/net/java21/blog/backend/persistence/EntitySchemaValidationTest.java`(실제 스키마 스냅숏)가 새 엔티티·바뀐 `PortalExclusion`으로 통과
- [ ] T012 [P] 코드 목록 시험: `blog-backend/src/test/java/net/java21/blog/backend/setting/SettingKeyTest.java`에 `external.fetch-interval`(`PT10M`~`PT24H`, 형식 오류·범위 밖 400 `params`), `external.auto-classify-min-confidence`(0~1), `external.score-weight`(0~10)와 프로퍼티 기본값; `notification/domain/NotificationTypeTest.java`에 `EXTERNAL_*` 3개·대상 `EXTERNAL_BLOG`(값 길이가 컬럼 30·20자 이내); `admin/audit/AuditActionsTest.java`(006 T006, 없으면 만듦)에 006 data-model 표의 007 행 전부 + `EXTERNAL_BLOG_UPDATE`, 대상 `EXTERNAL_BLOG`·`EXTERNAL_POST`·`TOPIC_MAPPING_RULE`·`CLASSIFICATION_REVIEW`
- [ ] T013 [P] `blog-backend/src/test/java/net/java21/blog/backend/external/repository/ExternalBlogActiveFeedMySqlTest.java`(`@MySqlRepositoryTest`, 환경 변수가 있을 때만): 같은 `feed_url_hash`의 PENDING·ACTIVE 두 행은 UNIQUE 위반, 하나가 REJECTED·RELEASED면 둘 다 저장, RELEASED를 ACTIVE로 바꾸려 하면 위반(생성 컬럼 재계산) (FR-112, research E6)
- [ ] T014 [P] `blog-backend/src/test/java/net/java21/blog/backend/config/ExternalFeedPropertiesTest.java`: 기본값(contracts/api.md 표), 0 이하 시간·크기·`fetch-threads` < 1·`member-limit` < 1·신뢰도 0~1 밖이면 기동 실패, `forbidden-hosts`에 `blog.base-url` 호스트가 항상 포함, 기존 `SchedulingConfigTest` 그대로 통과

### Implementation for Foundation

- [ ] T015 오류 코드: `blog-backend/src/main/java/net/java21/blog/backend/common/error/ErrorCode.java`에 contracts/api.md 007 표 15개(`EXTERNAL_FEED_URL_NOT_ALLOWED` 422, `EXTERNAL_FEED_NOT_FOUND` 422, `EXTERNAL_FEED_UNREADABLE` 422, `EXTERNAL_BLOG_ALREADY_REGISTERED` 409, `EXTERNAL_BLOG_LIMIT_EXCEEDED` 409, `EXTERNAL_BLOG_NOT_FOUND` 404, `EXTERNAL_BLOG_STATE_CONFLICT` 409, `EXTERNAL_BLOG_OWNERSHIP_REQUIRED` 403, `EXTERNAL_VERIFICATION_NOT_FOUND` 404, `EXTERNAL_VERIFICATION_EXPIRED` 422, `EXTERNAL_VERIFICATION_CODE_NOT_FOUND` 422, `EXTERNAL_POST_NOT_FOUND` 404, `CLASSIFICATION_REVIEW_NOT_FOUND` 404, `CLASSIFICATION_REVIEW_CLOSED` 409, `TOPIC_MAPPING_RULE_KEYWORD_TAKEN` 409); `blog-front/app/api/errorCodes.ts`와 `blog-front/app/locales/{ko,en,ja,zh-CN}/errors.json`에 같은 코드 문구(`params.reason`·`params.result`별 문구 포함)
- [ ] T016 외부 요청 도구: (005 T023이 아직 없으면) `blog-backend/src/main/java/net/java21/blog/backend/common/net/OutboundUrlGuard.java`·`HostResolver.java`·`OutboundBlockedException.java`를 005 contracts·tasks 그대로 만들고, `common/net/SafeHttpFetcher.java`(JDK `HttpClient` 빈 하나, `followRedirects(NEVER)`, 수동 리다이렉트·매번 `OutboundUrlGuard` + 우리 서비스 호스트 검사, 용도별 크기 상한 `Limit.FEED|PAGE|IMAGE|NONE`, 스트림 읽기 중단, 조건부 요청), `common/net/FetchResult.java`·`FetchFailure.java`; 시험 도구 `blog-backend/src/test/java/net/java21/blog/backend/support/StubHttpServer.java`(005가 먼저 만들었으면 재사용)
- [ ] T017 피드 읽기: `blog-backend/src/main/java/net/java21/blog/backend/external/feed/FeedUrlNormalizer.java`, `FeedParser.java`(ROME `SyndFeedInput`, `setAllowDoctypes(false)`, `XmlReader`) → `ParsedFeed`·`FeedItem` record(본문 필드 없음), `HtmlScanner.java`(OWASP `HtmlSanitizer.sanitize(html, Policy)` 이벤트 수신기: 링크·이미지·메타·텍스트), `SummaryExtractor.java`, `ItemImagePicker.java`(enclosure, `getForeignMarkup()`의 Media RSS 요소, 첫 `<img>`)
- [ ] T018 엔티티와 리포지토리: `blog-backend/src/main/java/net/java21/blog/backend/external/domain/`에 `ExternalBlog`(상태 전이 메서드 `approve`·`reject`·`pause`·`resume`·`block`·`release`·`stop`·`claim`, 잘못된 전이는 `EXTERNAL_BLOG_STATE_CONFLICT`, `active_feed_hash`는 `insertable=false, updatable=false`), `ExternalBlogStatus`, `RegistrationType`, `FetchResultCode`, `ExternalBlogVerification`, `ExternalPost`(`remove(reason)`, `changeTopic(topic, source, at)`), `ExternalPostStatus`, `RemovedReason`, `TopicSource`, `ExternalPostDailyClick`·`ExternalPostDailyClickId`, `TopicMappingRule`, `ClassificationReview`, `ReviewStatus`; `external/repository/`에 Spring Data 리포지토리 6개(조회 전용 QueryDSL 리포지토리는 각 스토리 작업에서)
- [ ] T019 `blog-backend/src/main/java/net/java21/blog/backend/portal/domain/PortalExclusion.java`: `post`를 `nullable = true`로, `externalPost`(`@ManyToOne(fetch = LAZY)`, `external_post_id`, unique) 추가, `@Check(constraints = "(post_id IS NULL) <> (external_post_id IS NULL)")`, 외부 글용 생성자; 003 `AdminExclusionService`·`PortalExclusionRepository`의 내부 글 경로가 그대로 동작하는지 기존 시험(`AdminExclusionServiceTest`·`PortalExclusionRepositoryTest`) 통과
- [ ] T020 운영 설정: `blog-backend/src/main/java/net/java21/blog/backend/setting/SettingKey.java`에 `EXTERNAL_FETCH_INTERVAL`·`EXTERNAL_AUTO_CLASSIFY_MIN_CONFIDENCE`·`EXTERNAL_SCORE_WEIGHT`(기본값은 `ExternalFeedProperties` — `defaultValue` 시그니처가 `PortalProperties`만 받으면 기본값 공급자 인터페이스로 넓힘), `setting/service/SystemSettingsService.java`에 `externalFetchInterval()`·`autoClassifyMinConfidence()`·`externalScoreWeight()`; `external.score-weight` 변경 시 포털 캐시 무효화(003 `PortalChangedEvent`)
- [ ] T021 알림 종류: `blog-backend/src/main/java/net/java21/blog/backend/notification/domain/NotificationType.java`에 `EXTERNAL_BLOG_APPROVED`·`EXTERNAL_BLOG_REJECTED`·`EXTERNAL_FEED_STOPPED`, `NotificationTargetType.java`에 `EXTERNAL_BLOG`, `notification/service/NotificationService.java`에 `notifyExternalBlog(userId, type, externalBlogId, params)`(같은 트랜잭션); front `blog-front/app/components/notification/*`의 종류별 문구·링크(`/manage/external-blogs/{id}`)와 `notification.json` 4개 언어
- [ ] T022 작업 종류: `blog-backend/src/main/java/net/java21/blog/backend/admin/audit/AuditActions.java`에 `EXTERNAL_BLOG_CREATE`·`APPROVE`·`REJECT`·`UPDATE`·`PAUSE`·`RESUME`·`BLOCK`, `EXTERNAL_POST_REMOVE`, `TOPIC_MAPPING_RULE_CREATE`·`UPDATE`·`DELETE`, `CLASSIFICATION_CONFIRM`, 대상 `TARGET_EXTERNAL_BLOG`·`TARGET_EXTERNAL_POST`·`TARGET_TOPIC_MAPPING_RULE`·`TARGET_CLASSIFICATION_REVIEW`(006 `ALL`·`TARGETS`가 있으면 거기에도); (006 머지 후) `blog-front/app/locales/{ko,en,ja,zh-CN}/audit.json`에 작업·대상 이름

**Checkpoint**: 기반 완료. `./mvnw verify`, `npm test -- --coverage` 통과, CI `e2e-backend`가 새 환경 변수와 스텁 서버로 001~004 E2E를 모두 통과(스텁은 아직 아무도 쓰지 않음)

---

## Phase 3: User Story 1 - 외부 블로그 등록: 회원 신청과 운영자 직접 등록 (Priority: P1) 🎯 MVP

**Goal**: 회원이 블로그·피드 주소로 미리보기 → (선택) 소유 인증 → 기본 주제를 골라 신청하고, 운영자가 승인·거절하거나 직접 등록하며, 승인된 피드가 주기적으로 수집된다. 이미 등록된 블로그의 실제 주인은 소유 인증으로 넘겨받는다.

**Independent Test**: (신청 경로) 회원이 RSS 주소로 신청 → 콘솔 신청 목록에 나타남 → 운영자 승인 → "수집 중"과 수집된 글. (직접 경로) 운영자가 피드 주소·기본 주제·등록 근거로 직접 등록 → 바로 "수집 중". 포털 노출 확인은 US2 체크포인트(결정 표 1번). (quickstart #1~#11)

FR: FR-109, FR-110, FR-111, FR-112, FR-113, FR-116, FR-128(썸네일 받기 조건), FR-129(넘겨받기)

### Tests for User Story 1 (backend) ⚠️

- [ ] T023 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/external/member/PreviewServiceTest.java`(`StubHttpServer`): 피드 주소 직접 → 미리보기(최근 3편 피드 순서), 블로그 HTML → `<link rel=alternate>`로 찾음, 링크 없으면 `/rss`·`/feed` 시도(요청 수 확인) 후 422 `EXTERNAL_FEED_NOT_FOUND`(`tried`), 리다이렉트 최종 주소가 `feedUrl`, 이미 등록된 피드면 `registered`(상태·`claimable`·`mine`), 같은 피드 10분 안 두 번째 미리보기는 외부 요청 없음(Caffeine `Ticker`), 회원당 시간당 20회 넘으면 429, 우리 서비스 주소 422 `EXTERNAL_FEED_URL_NOT_ALLOWED`(`SELF`) (US1 AS1, FR-109, research E3)
- [ ] T024 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/external/verify/VerificationServiceTest.java`(`StubHttpServer`, `MutableClock`): 코드 형식 `java21-verify-` + 12자, 같은 회원·피드에 유효한 코드가 있으면 재사용(200), 확인이 피드 채널 설명·항목 본문 텍스트·사이트 HTML 텍스트·`meta` 값 어디서든 찾음, 못 찾으면 422 `EXTERNAL_VERIFICATION_CODE_NOT_FOUND`(`checked`, 사이트 시간 초과면 `failures.SITE = TIMEOUT`), 24시간 지나면 422 `EXTERNAL_VERIFICATION_EXPIRED`, 다른 회원의 인증 404, 이미 인증됐으면 외부 요청 없이 200, 같은 피드의 다른 회원·미소유 활성 등록이 있으면 `claimableExternalBlogId`, 시간당 10회 넘으면 429 (US1 AS2·AS3, FR-110, research E8)
- [ ] T025 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/external/member/MemberExternalBlogServiceTest.java`(Mockito + 저장소 가짜)와 `MemberExternalBlogLimitIntegrationTest.java`(`@SpringBootTest` H2, 동시 요청 2개): 신청 정상(PENDING, `MEMBER_REQUEST`, `member_id`), 피드가 안 읽히면 422 `EXTERNAL_FEED_UNREADABLE`(`result`), 4번째 신청 409 `EXTERNAL_BLOG_LIMIT_EXCEEDED`(REJECTED·RELEASED는 세지 않고 BLOCKED는 셈), 같은 회원이 동시에 신청해도 3개를 넘지 않음(회원 행 `FOR UPDATE`), 중복 피드 409 `EXTERNAL_BLOG_ALREADY_REGISTERED`(`claimable`: BLOCKED면 false), 거절·해제된 피드는 다시 신청 가능, `verificationId`가 같은 회원·피드·성공·24시간 안이면 `ownership_verified = true`와 인증 행 연결(아니면 400 field `verificationId`), 기본 주제가 대분류·숨김이면 422 `TOPIC_NOT_SELECTABLE`; 넘겨받기 — 미소유 ADMIN_DIRECT·다른 회원의 미인증 신청을 넘겨받음(`member_id` 변경, 인증 true, 커밋 후 썸네일 소급 이벤트), BLOCKED 409, RELEASED 404, 한도 409, 남의 인증 400; 조회·목록은 본인 것만(남의 id 404) (US1 AS4·AS5·AS8, FR-111, FR-112, FR-129)
- [ ] T026 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/admin/external/AdminExternalBlogServiceTest.java`: 직접 등록(`registration_basis` 필수 1~500자, ACTIVE, `member_id` NULL, `reviewed_by/at`, `next_fetch_at = now`, 작업 기록 `EXTERNAL_BLOG_CREATE`), 승인(PENDING만, ACTIVE·`next_fetch_at = now`·알림 `EXTERNAL_BLOG_APPROVED`·작업 기록, 이미 ACTIVE면 409 `EXTERNAL_BLOG_STATE_CONFLICT`), 거절(사유 필수, REJECTED, 알림 `{ externalBlogTitle, reason }`, 제목이 없으면 피드 호스트), 기본 주제 변경(`EXTERNAL_BLOG_UPDATE` 전후 값) (US1 AS6·AS7, FR-111)
- [ ] T027 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/external/repository/ExternalBlogQueryRepositoryTest.java`(`@JpaRepositoryTest` + `QueryCounter`): 수집할 차례 선택(`ACTIVE`·`next_fetch_at <= now`·오래된 것 먼저·`LIMIT`), 임대 갱신 1회, 회원별 세는 수(상태 조건), 관리자 목록(전체면 PENDING 먼저 다음 최근 순, 상태별, `q` 제목·피드 주소, 회원 닉네임·검수 대기 수를 쿼리 2회 안에), 회원 목록(최근 20, 글 수 포함 쿼리 1회)
- [ ] T028 [P] [US1] 수집 시험: `blog-backend/src/test/java/net/java21/blog/backend/external/fetch/FeedFetchSchedulerTest.java`(고른 행의 `next_fetch_at`을 `now + lease`로 미룬 뒤 제출, `TaskRejectedException`이면 임대 유지·예외 삼킴, 고를 것이 없으면 쿼리 1회), `external/fetch/FeedCollectorTest.java`(`StubHttpServer`, `MutableClock`, H2 `@SpringBootTest` 아님 — 서비스 + `@JpaRepositoryTest` 조합): 최초 수집은 30일 안 글만·최대 100개, 이후 수집은 기간 제한 없음, 304면 글 쓰기 0·`NOT_MODIFIED`, guid로 같은 글 갱신(바뀐 필드만, 주제 유지), guid 없으면 링크로, guid가 바뀌고 링크 같으면 같은 행 갱신, REMOVED 글은 되살리지 않음, 새 글은 기본 주제·`topic_source = DEFAULT`(US2에서 `TopicDecider`로 바뀜), 성공 시 실패 수 0·ETag·`last_success_at`·`next_fetch_at = now + 주기(+0 지연)`, 실패 시 `30분 × 2^(n-1)` 최대 12시간, 첫 실패 7일 뒤 STOPPED·`next_fetch_at` NULL·관리 회원 알림 `EXTERNAL_FEED_STOPPED`(회원 없으면 알림 없음), ACTIVE가 아니게 된 블로그는 요청하지 않음, 새 글이 있으면 커밋 후 `PortalChangedEvent`, 피드 하나 수집의 DB 쿼리 4회 이하 + 새 글당 쓰기(`QueryCounter`) (FR-113, FR-115, FR-116, FR-117, research E1·E5)
- [ ] T029 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/external/thumbnail/ExternalThumbnailServiceTest.java`와 `ExternalThumbnailControllerTest.java`: 인증된 블로그 글만 받음(미인증이면 `StubHttpServer` 요청 0건), JPEG·PNG·GIF(첫 장면)·WebP(→PNG) 600x400 cover 생성, SVG·HTML·5MB 초과·픽셀 상한 초과는 썸네일 없음(수집 결과 영향 없음), 저장 경로 `external/{앞 2자}/{key}.{ext}`, 소급(최근 30일·이미지 있음·키 없음 최대 100개), 삭제; 컨트롤러 — 형식이 아닌 키·없는 파일·REMOVED 글·미인증 블로그 404 `MEDIA_NOT_FOUND`, 응답 `Cache-Control: public, max-age=86400`·`nosniff`·`inline` (FR-128, research E7)
- [ ] T030 [P] [US1] 컨트롤러: `blog-backend/src/test/java/net/java21/blog/backend/external/member/MemberExternalBlogControllerTest.java`(`POST /external-blog-previews`, `/me/external-blog-verifications`(201·재사용 200), `…/{id}/check`, `GET·POST /me/external-blogs`, `GET /me/external-blogs/{id}`, `POST /external-blogs/{id}/claim` — 비로그인 401, 요청 검증(주소 1~1000자, `defaultTopicId` 필수), 오류 코드·`params`, `Location`, `Cache-Control: no-store`), `admin/external/AdminExternalBlogControllerTest.java`(목록·직접 등록·조회·PATCH·승인·거절 — 검증, 응답 모양)

### Tests for User Story 1 (front) ⚠️

- [ ] T031 [P] [US1] `blog-front/tests/unit/routes/manageExternalBlogs.test.tsx`: 목록(상태 배지·거절 사유·3개면 신청 버튼 비활성), 신청 단계(`intent=preview` 결과 표시, 이미 등록됨 → 넘겨받기 안내, `issue-code` → 코드·복사·만료 시각, `check` 실패 이유 표시, 건너뛰기, 주제 선택 → `submit` 후 상세로 리다이렉트), 오류 코드별 문구(`EXTERNAL_FEED_URL_NOT_ALLOWED`의 `reason`별), JS 없이 단계 이동(`?step=`); `blog-front/tests/unit/routes/adminExternalBlogs.test.tsx`: 상태 탭(승인 대기 먼저·수), 직접 등록 폼(등록 근거 필수), 상세의 상태별 버튼(PENDING만 승인·거절), 거절 사유 필수; 메뉴 항목이 보임(`admin/links.ts`·`manage/links.ts` 또는 006 전의 레이아웃)

### Tests for User Story 1 (E2E) ⚠️

- [ ] T032 [P] [US1] E2E `blog-front/tests/e2e/external-us1-register.spec.ts`(`requireBackend`·`requireAdmin`·`requireExternalTestSettings`, `external` 프로젝트): Independent Test 두 경로 — 회원 A가 스텁 블로그 주소로 미리보기(최근 3편) → 코드 발급 → 코드 없이 확인 실패 → 스텁에 코드 넣고 확인 → 주제 → 신청 → 관리자 목록 "승인 대기"에 소유 인증 표시 → 승인 → `expect.poll`로 A의 상세 "수집 중"·수집된 글 1편(40일 전 글 제외) → A 알림 "승인"; 관리자 직접 등록(등록 근거) → 바로 수집 중; 회원 B가 같은 피드 신청 409 → 소유 인증 → 넘겨받기; 우리 서비스 주소(`http://localhost:5173/...`) 422; 3개 한도 (US1 AS1~AS8, quickstart #1~#11)

### Implementation for User Story 1 (backend)

- [ ] T033 [US1] 미리보기: `blog-backend/src/main/java/net/java21/blog/backend/external/feed/FeedDiscovery.java`(직접 피드 → `<link>` → `/rss`·`/feed`), `external/member/PreviewService.java`(Caffeine 10분 캐시, 회원별 시간당 한도 — 001 `common/security`의 고정 창 도구 또는 005 `RateLimiter`가 있으면 재사용), `external/dto/FeedPreviewResponse.java`
- [ ] T034 [US1] 소유 인증: `blog-backend/src/main/java/net/java21/blog/backend/external/verify/VerificationCodeGenerator.java`, `VerificationService.java`(발급·재사용·확인, 피드와 사이트 HTML 두 곳), `external/repository/ExternalBlogVerificationRepository`에 `findValid(userId, feedHash, now)`
- [ ] T035 [US1] 회원 API: `blog-backend/src/main/java/net/java21/blog/backend/external/member/MemberExternalBlogService.java`(신청: 피드 확인 → 회원 행 잠금 → 한도 → 중복 사전 검사 → 저장, `DataIntegrityViolationException` → 409; 넘겨받기; 조회·목록), `MemberExternalBlogController.java`(`/external-blog-previews`, `/me/external-blog-verifications/**`, `/me/external-blogs`, `/me/external-blogs/{id}`, `/external-blogs/{id}/claim`), `external/repository/ExternalBlogQueryRepository.java`(회원 목록·수), dto
- [ ] T036 [US1] 관리자 API: `blog-backend/src/main/java/net/java21/blog/backend/admin/external/AdminExternalBlogService.java`·`AdminExternalBlogController.java`(목록·직접 등록·조회·PATCH 기본 주제·승인·거절, 알림·작업 기록 같은 트랜잭션), `external/repository/ExternalBlogQueryRepository.java`에 관리자 목록, dto
- [ ] T037 [US1] 수집: `blog-backend/src/main/java/net/java21/blog/backend/external/fetch/FeedFetchScheduler.java`(`@Scheduled(fixedDelayString = "${blog.external.poll-interval}")`, 선택·임대·`feedFetchExecutor` 제출), `FeedCollector.java`(research E5 흐름, 외부 요청은 트랜잭션 밖), `ExternalPostUpserter.java`(guid·link 해시 `IN` 2회), `FetchBackoff.java`, `FeedStopNotifier.java`; 새 글 주제는 `TopicAssigner` 인터페이스(US1 구현은 기본 주제, US2 T055가 `TopicDecider`로 교체)
- [ ] T038 [US1] 썸네일: `blog-backend/src/main/java/net/java21/blog/backend/external/thumbnail/ExternalThumbnailService.java`(001 `ImageInspector`·Thumbnailator 재사용, 600x400 cover 한 크기), `ExternalThumbnailController.java`(`GET /media/external/{key}`), 인증·넘겨받기 커밋 후 소급 이벤트 리스너(`@TransactionalEventListener(AFTER_COMMIT)` → `feedFetchExecutor`)
- [ ] T039 [US1] 보안 경로: `blog-backend/src/main/java/net/java21/blog/backend/config/SecurityConfig.java`에 비로그인 허용 GET `/media/external/*`·`/api/v1/external-posts/*/visit`(US2가 씀), 나머지 007 회원 API는 인증 필요(기본); `security/ExternalPathsWebMvcTest.java`(003 `PortalPathsWebMvcTest` 방식)로 확인

### Implementation for User Story 1 (front)

- [ ] T040 [US1] 블로그 관리 화면: `blog-front/app/routes/manage/external-blogs.tsx`, `external-blog-new.tsx`, `external-blog.tsx`(상세는 이 단계에서 상태·인증·수집된 글 읽기 전용 표, 주제 변경·해제는 US3·US4), `blog-front/app/routes/manage-external-entry.ts`(`/manage/external-blogs(/:id)` → 최근 블로그), `blog-front/app/components/external/FeedPreview.tsx`·`VerificationPanel.tsx`·`ExternalBlogStatusBadge.tsx`·`TopicSelect.tsx`(003 주제 트리), `blog-front/app/external/status.ts`, `blog-front/app/routes.ts`에 경로, 메뉴 "외부 블로그" 켜기((006 머지 후) `app/manage/links.ts` `available: true`, 그 전에는 `routes/manage/layout.tsx`의 `MANAGE_MENU`), 문구 `external`·`manage`
- [ ] T041 [US1] 콘솔 화면: `blog-front/app/routes/admin/external-blogs.tsx`, `external-blog-new.tsx`, `external-blog.tsx`(승인·거절·기본 주제, 수집 상태, 수집된 글 읽기 전용 표), 하위 탭 컴포넌트 `components/external/AdminExternalTabs.tsx`, `routes.ts`, 메뉴 "외부 블로그 관리" 켜기((006 머지 후) `app/admin/links.ts`, 그 전에는 003 `ADMIN_MENU`), 문구 `external`·`admin`

**Checkpoint**: US1 Independent Test E2E 통과(CI `e2e-backend`에서 실제로 실행, 스텁 사용), quickstart #1~#11

---

## Phase 4: User Story 2 - 외부 글이 포털에 주제별로 나온다 (Priority: P2)

**Goal**: 수집된 외부 글이 주제가 정해져 포털 최신 글·인기 글·주제 페이지에 "외부" 표시와 함께 내부 글과 섞여 나오고, 카드를 누르면 새 탭에서 원문으로 간다. 클릭 수가 인기 점수가 되고, 원문이 없어진 글은 주 1회 점검에서 내려간다.

**Independent Test**: 승인된 외부 블로그(기본 주제 "IT 인터넷")에 새 글 발행 → 수집 주기 안에 포털 "IT 인터넷" 페이지에 카드가 나오고, 카드를 누르면 원래 블로그 글로 이동하는지 확인. (quickstart #12~#21)

FR: FR-114, FR-117(링크 점검), FR-118, FR-119, FR-123, FR-124, FR-125, FR-128, SC-018, SC-021

### Tests for User Story 2 (backend) ⚠️

- [ ] T042 [P] [US2] `blog-backend/src/test/java/net/java21/blog/backend/external/portal/ExternalPortalQueryRepositoryTest.java`(`@JpaRepositoryTest` + `QueryCounter`): 노출 조건 행렬(글 ACTIVE/REMOVED × 블로그 ACTIVE·PAUSED·STOPPED/PENDING·REJECTED·BLOCKED·RELEASED × 포털 제외 있음/없음 × 미래 발행 × 주제 운영자 숨김(소분류·대분류)), 최신(커서 다음, `LIMIT`), 주제 페이지 가벼운 행(id·발행 시각)과 개수, 카드 읽기(외부 블로그 JOIN, 인증 블로그만 `thumbnailUrl`) 쿼리 1회, 인기 후보, 주제별 최근 30일 수 쿼리 1회 (FR-123, research E13)
- [ ] T043 [P] [US2] `blog-backend/src/test/java/net/java21/blog/backend/portal/service/PortalMergeTest.java`와 `PortalServiceTest`·`TopicPostServiceTest`·`PortalCursorTest`(003) 추가: 두 출처를 (발행 시각 내림, 같으면 INTERNAL 먼저, id 내림)으로 합침, `PerBlogCap` 키 `P:`·`E:`로 블로그당 2편(내부·외부 블로그 id가 같아도 섞이지 않음), 커서에 `s` 포함·옛 커서(`s` 없음)는 내부로·잘못된 `s` 400, `source=internal|external|all`(잘못된 값 400 `params.allowed`), 캐시 키에 `source`, 주제 페이지 `latest`가 두 출처 합친 순서·`totalCount` 합·`page > 49` 빈 목록, `ExternalPortalSource` 빈이 없으면 003 결과와 같음(기존 003 시험 전부 통과) (FR-123, FR-124, research E13)
- [ ] T044 [P] [US2] `blog-backend/src/test/java/net/java21/blog/backend/portal/service/PopularityCalculatorTest.java`(003) 추가: 외부 점수 = 최근 7일 클릭 × `external.score-weight` × 같은 감쇠, 가중치 0이면 외부 글 없음, 내부·외부 한 목록 점수순, 외부는 신고 감점 대상 아님, `Entry.source`; `external/portal/ExternalPopularityRepositoryTest.java`(일별 클릭 합 쿼리 1회) (FR-124, research E13)
- [ ] T045 [P] [US2] `blog-backend/src/test/java/net/java21/blog/backend/portal/repository/TopicPostCountQueryRepositoryTest.java`(003) 추가: 주제별 수에 노출 조건을 만족하는 최근 30일 외부 글이 더해짐(REMOVED·차단 블로그 글 제외), 쿼리 2회 (FR-123 → 003 FR-147)
- [ ] T046 [P] [US2] 분류 시험: `blog-backend/src/test/java/net/java21/blog/backend/external/classify/KeywordTopicClassifierTest.java`(가중치 3·2·1, 같은 키워드 위치별 한 번, 신뢰도 `(top/sum) × min(1, top/4)` 경계값, 한국어·일본어·중국어 부분 문자열·영어 토큰, 일치 없음 → null·0, 버전 `keyword-v1`), `KeywordDictionaryTest.java`(사전의 모든 slug가 `TopicSeeder` 소분류에 있음, 소분류마다 10개 이상, 정규화 후 중복 없음, 없는 slug 항목은 경고 후 무시), `MappingRuleMatcherTest.java`(NFKC·trim·소문자 완전 일치, 우선순위 큰 것·같으면 id 작은 것, 숨김·대분류 대상 규칙 건너뜀), `TopicDeciderTest.java`(RULE → AUTO(기준 이상, 기준은 운영 설정) → DEFAULT, RULE이면 분류기 호출 없음·검수 없음, DEFAULT이고 신뢰도 미만(일치 없음 포함)이면 검수 PENDING, 분류 결과는 채택 여부와 관계없이 `classifier_*`에 기록) (FR-118, FR-119, research E9·E10)
- [ ] T047 [P] [US2] 클릭: `blog-backend/src/test/java/net/java21/blog/backend/external/portal/ExternalVisitControllerTest.java`(302 `Location` = 저장된 링크, `Cache-Control: no-store`, `Referrer-Policy: no-referrer`, 노출 조건을 만족하지 않으면 404 `EXTERNAL_POST_NOT_FOUND`, 숫자가 아닌 id 404), `ExternalClickServiceTest.java`(같은 방문자·같은 글 30분 1회 — Caffeine `Ticker`, 회원·쿠키·IP 해시 키), `external/repository/ExternalPostDailyClickRepositoryTest.java`(`@JpaRepositoryTest`: upsert 두 번이면 `clicks` 2, `click_count` 함께 증가, 쿼리 2회) (FR-124, research E14)
- [ ] T048 [P] [US2] `blog-backend/src/test/java/net/java21/blog/backend/external/job/LinkCheckJobTest.java`(`StubHttpServer`, `MutableClock`): HEAD 200 유지, 404·410 → REMOVED `LINK_BROKEN`, 405 → GET `Range: bytes=0-0`, 500·시간 초과·403·내부망 리다이렉트는 유지, 이름 해석 실패는 내림, 모든 경우 `link_checked_at` 갱신, 7일 안에 점검한 글 제외, 한 번에 `link-check-batch`개, 같은 호스트 1초 간격, 내린 글이 있으면 포털 캐시 무효화 (FR-117, research E12)
- [ ] T049 [P] [US2] 노출 범위 회귀: `blog-backend/src/test/java/net/java21/blog/backend/integration/ExternalPostExclusionIntegrationTest.java`(`@SpringBootTest` H2): 외부 글이 있는 상태에서 `GET /api/v1/search`, 블로그 RSS·Atom, `/sitemap.xml`, 블로그 홈·태그 목록 응답에 외부 글 제목이 없음(FR-125); 본문 50KB 피드를 수집한 뒤 `external_posts`의 모든 문자열 컬럼 길이 합이 제목+요약+주소 이하이고 본문 문장이 어느 컬럼에도 없음(SC-021)

### Tests for User Story 2 (front) ⚠️

- [ ] T050 [P] [US2] `blog-front/tests/unit/components/PortalCard.test.tsx`(003) 추가: 외부 카드 — 링크 `visitUrl`·`target="_blank"`·`rel="noopener nofollow"`, "외부" 배지, 블로그 이름·호스트(작성자 자리), 좋아요·댓글 숨김, 썸네일 없으면 주제 색, 요약 속 `<script>` 문자열이 텍스트로만(이스케이프), 내부 카드는 기존과 같음; `tests/unit/components/SourceFilter.test.tsx`(세 값, 현재 값 표시, 링크가 `?source=`이고 커서·페이지는 버림); `tests/unit/routes/home.test.tsx`·`topic.test.tsx`(003) 추가: `?source=`를 API에 넘기고 noindex, React 키 `${source}-${id}`로 같은 id 카드 둘이 함께 렌더링
- [ ] T051 [P] [US2] `blog-front/tests/unit/server/backendProxyVisit.test.ts`: `/api/v1/external-posts/{id}/visit`가 302면 그대로, 404이고 `Accept: text/html`이면 404 HTML 화면, JSON 요청이면 JSON 그대로

### Tests for User Story 2 (E2E) ⚠️

- [ ] T052 [P] [US2] E2E `blog-front/tests/e2e/external-us2-portal.spec.ts`(`requireBackend`·`requireAdmin`·`requireExternalTestSettings`): Independent Test — 관리자가 스텁 피드를 기본 주제 IT 인터넷으로 직접 등록 → 스텁에 새 글 → `expect.poll`로 `/topics/{IT 인터넷}`에 "외부" 카드 → 카드 클릭으로 새 탭이 스텁 원문 주소(`context.waitForEvent("page")`) → 콘솔 클릭 수 1; 메인 최신에 외부 카드와 블로그당 2편 제한(같은 피드 새 글 4편); "외부 글만"·"내부 글만" 필터; 매핑 규칙(고유 태그 → 다른 주제)로 들어온 글은 그 주제 페이지에; 소유 인증 없는 블로그 카드는 썸네일 없음·스텁 이미지 요청 0건, 인증된 블로그 카드는 `/media/external/…` 이미지(200); `/search?q=`에 외부 글 없음; 스텁에서 원문을 지운 뒤 링크 점검은 E2E에서 기다리지 않고 backend 시험(T048)으로 덮음 (US2 AS1~AS3·AS5, quickstart #12~#19)

### Implementation for User Story 2 (backend)

- [ ] T053 [US2] 포털 외부 출처: `blog-backend/src/main/java/net/java21/blog/backend/portal/service/ExternalPortalSource.java`(인터페이스: `latest(criteria, after, limit, …)`, `topicRows(...)`, `cards(ids)`, `popularityCandidates(...)`, `recentCountsByTopic(...)`; 빈이 없으면 `NoExternalPortalSource`), `external/portal/ExternalPortalExposure.java`(노출 조건 조각), `ExternalPortalQueryRepository.java`(QueryDSL, DTO projection), `ExternalPortalSourceImpl.java`
- [ ] T054 [US2] 포털 합치기: `blog-backend/src/main/java/net/java21/blog/backend/portal/dto/PortalCardResponse.java`(+ `source`·`visitUrl`·`externalBlog`, 외부용 `fromExternal`), `portal/service/PortalMerge.java`, `PortalCursor.java`(`s`), `PerBlogCap` 호출부 키 변경, `PortalService.java`(최신·인기 합치기, `latest(cursor, source)`), `TopicPostService.java`(`source`, 두 출처 합치기, 깊이 상한), `portal/controller/PortalController.java`·`TopicPostController.java`에 `source` 파라미터, `PopularityCalculator.java`·`PopularitySnapshot.java`(`Entry.source`, 외부 점수), `portal/repository/TopicPostCountQueryRepository.java`(외부 수 합산 — `ExternalPortalSource` 호출을 서비스 계층에서 합쳐도 됨)
- [ ] T055 [US2] 분류: `blog-backend/src/main/java/net/java21/blog/backend/external/classify/TopicClassifier.java`·`ClassifierInput.java`·`ClassificationResult.java`·`KeywordDictionary.java`(기동 때 yml 읽기, slug → topicId)·`KeywordTopicClassifier.java`·`MappingRuleMatcher.java`·`TopicDecider.java`(T037 `TopicAssigner` 구현 교체, 검수 행 생성), `external/repository/TopicMappingRuleRepository.findAllForMatching()`
- [ ] T056 [US2] 클릭: `blog-backend/src/main/java/net/java21/blog/backend/external/portal/ExternalVisitController.java`(`GET /api/v1/external-posts/{id}/visit`), `ExternalClickService.java`(001 `VisitorKeyResolver`, Caffeine 중복 제거), `external/repository/ExternalPostDailyClickRepository.java`의 upsert(MySQL `INSERT … ON DUPLICATE KEY UPDATE` 네이티브 1개 — H2 MySQL 모드에서도 동작 확인)
- [ ] T057 [US2] `blog-backend/src/main/java/net/java21/blog/backend/external/job/LinkCheckJob.java`(`@Scheduled(cron = "${blog.external.link-check-cron}")`, 대상 선택은 스케줄러 스레드, 요청은 `feedFetchExecutor`, 호스트별 간격)

### Implementation for User Story 2 (front)

- [ ] T058 [US2] 포털 화면: `blog-front/app/components/portal/PortalCard.tsx`(외부 분기), `components/portal/SourceFilter.tsx`, `blog-front/app/external/sourceFilter.ts`·`visit.ts`, `routes/home.tsx`(최신 영역 필터, `/portal/latest?source=`, JS 없으면 `/?source=`), `routes/topic.tsx`(`source`), 카드 목록 키 변경(`LatestPosts.tsx`·`PopularPosts.tsx`·`CurationSection.tsx`), 문구 `portal`
- [ ] T059 [US2] `blog-front/server/middleware/backend-proxy.ts`(001): `/api/v1/external-posts/*/visit`의 404를 `Accept: text/html` 요청이면 001 404 화면으로 바꿈(그 경로 한 곳만)

**Checkpoint**: US2 Independent Test E2E 통과(CI), US1 Independent Test의 포털 확인 부분도 통과, quickstart #12~#21

---

## Phase 5: User Story 3 - 주제 분류 개선과 검수 (Priority: P3)

**Goal**: 소유 인증된 주인이 수집된 자기 글의 주제를 고치고, 운영자는 신뢰도가 낮은 글을 검수 목록에서 확정하며, 매핑 규칙을 관리하고 분류 현황(정확도·분포·대기 수)을 본다.

**Independent Test**: 자동 분류 신뢰도가 기준 미만인 글이 검수 목록에 들어가는지 확인 → 운영자가 주제 지정 → 포털에 반영되고 분류 정확도 지표에 반영되는지 확인. (quickstart #22~#27)

FR: FR-119, FR-120, FR-121, FR-122, SC-019

### Tests for User Story 3 (backend) ⚠️

- [ ] T060 [P] [US3] `blog-backend/src/test/java/net/java21/blog/backend/external/member/ExternalPostTopicServiceTest.java`: 인증된 주인만 글 주제·기본 주제 변경(미인증 관리 회원 403 `EXTERNAL_BLOG_OWNERSHIP_REQUIRED`, 남의 블로그 404), 글 주제 변경 시 `OWNER`·`topic_decided_at`·PENDING 검수 `SKIPPED`·포털 캐시 무효화, CONFIRMED 뒤에도 주인이 바꿀 수 있음, REMOVED 글 404, 이후 같은 글이 피드에서 갱신되어도 주제 유지(T028 수집기와 함께), 기본 주제 변경은 이미 수집된 DEFAULT 글을 바꾸지 않음 (US3 AS1, FR-120)
- [ ] T061 [P] [US3] `blog-backend/src/test/java/net/java21/blog/backend/admin/external/ClassificationReviewServiceTest.java`와 `external/repository/ClassificationReviewQueryRepositoryTest.java`(`@JpaRepositoryTest` + `QueryCounter`): 목록은 ACTIVE 글의 PENDING만·오래된 것 먼저·블로그 필터, 글·블로그 정보 JOIN 쿼리 2회, 확정(PENDING만, `REVIEW`, `topic_decided_at`, `CONFIRMED`, 작업 기록 `CLASSIFICATION_CONFIRM`, 닫힌 것 409 `CLASSIFICATION_REVIEW_CLOSED`, 주제 규칙), 일괄 확정(1~50, 닫힌 것은 `skipped`, 확정한 행마다 작업 기록, 포털 캐시 무효화 1번) (US3 AS2·AS3, FR-121)
- [ ] T062 [P] [US3] `blog-backend/src/test/java/net/java21/blog/backend/admin/external/ClassificationStatsServiceTest.java`와 `external/repository/ClassificationStatsQueryRepositoryTest.java`(`MutableClock`): 최근 30일 사람이 확인한 글(OWNER·REVIEW, `classifier_topic_id` 있음)의 정확도·표본 수, 표본 0이면 null, 최종 주제 정확도(검수 CONFIRMED에서 확정 주제 = 블로그 기본 주제 비율, research E11), 주제·출처별 분포, 검수 대기 수, 5분 캐시(`Ticker`), 쿼리 4회 이하 (US3 AS4, FR-122, SC-019)
- [ ] T063 [P] [US3] `blog-backend/src/test/java/net/java21/blog/backend/admin/external/AdminMappingRuleServiceTest.java`: 키워드 정규화(NFKC·trim·소문자) 후 1~100자, 중복 409 `TOPIC_MAPPING_RULE_KEYWORD_TAKEN`(`ruleId`), 주제 규칙(소분류·숨김 아님), `priority` -1000~1000, 수정·삭제와 작업 기록(전후 값), 이미 RULE로 정해진 글은 바뀌지 않음, 다음 수집부터 적용(`TopicDecider`가 새 규칙을 읽음) (US3 AS5, FR-121)
- [ ] T064 [P] [US3] 컨트롤러: `blog-backend/src/test/java/net/java21/blog/backend/external/member/MemberExternalPostControllerTest.java`(`GET /me/external-blogs/{id}/posts`, `PATCH /me/external-blogs/{id}`, `PUT …/posts/{postId}/topic`), `admin/external/AdminClassificationControllerTest.java`(검수 목록·확정·일괄, 현황), `AdminMappingRuleControllerTest.java`(목록·추가·수정·삭제) — 검증·오류 코드·`Cache-Control: no-store`

### Tests for User Story 3 (front) ⚠️

- [ ] T065 [P] [US3] `blog-front/tests/unit/routes/manageExternalBlog.test.tsx`(상세: 인증된 주인에게만 글별 주제 바꾸기·기본 주제, 주제 출처 표시, 미인증이면 "소유 인증하면 주제를 고칠 수 있습니다"), `tests/unit/routes/adminExternalReviews.test.tsx`(행마다 기본 선택 = 예측 또는 지금 주제, 일괄 확정 체크 50개 상한, 닫힌 항목 안내), `adminExternalStats.test.tsx`(정확도·표본 수·정의 설명, 표본 0이면 "—"), `adminExternalRules.test.tsx`(추가·수정·삭제, "이후 수집되는 글에만" 안내), `adminExternalSettings.test.tsx`(세 키, 기본값으로)

### Tests for User Story 3 (E2E) ⚠️

- [ ] T066 [P] [US3] E2E `blog-front/tests/e2e/external-us3-classify.spec.ts`(`requireBackend`·`requireAdmin`·`requireExternalTestSettings`): Independent Test — 스텁에 사전 키워드가 없는 고유 제목 글 → 관리자 검수 목록에 "예측 없음" 대기 → 다른 주제로 확정 → 포털 그 주제 페이지에 나옴 → 분류 현황 표본 수 증가; 소유 인증한 회원이 수집된 글 주제 변경 → 포털 반영·출처 "주인", 같은 글을 스텁에서 수정해 다시 수집돼도 주제 유지; 매핑 규칙 추가 후 새 글만 적용 (US3 AS1~AS5, quickstart #22~#27)

### Implementation for User Story 3

- [ ] T067 [US3] 회원 글 주제: `blog-backend/src/main/java/net/java21/blog/backend/external/member/ExternalPostTopicService.java`, `MemberExternalBlogController.java`에 `GET …/posts`, `PATCH /me/external-blogs/{id}`, `PUT …/posts/{postId}/topic`, `external/repository/ExternalPostQueryRepository.java`(회원 글 목록, 썸네일 주소 계산)
- [ ] T068 [US3] 검수와 현황: `blog-backend/src/main/java/net/java21/blog/backend/admin/external/AdminClassificationController.java`·`ClassificationReviewService.java`·`ClassificationStatsService.java`(Caffeine 5분), `external/repository/ClassificationReviewQueryRepository.java`·`ClassificationStatsQueryRepository.java`, dto
- [ ] T069 [US3] 매핑 규칙: `blog-backend/src/main/java/net/java21/blog/backend/admin/external/AdminMappingRuleController.java`·`AdminMappingRuleService.java`, `external/classify/KeywordNormalizer.java`(분류 사전·규칙·피드 태그가 같은 정규화), dto
- [ ] T070 [US3] front 블로그 관리 상세: `blog-front/app/routes/manage/external-blog.tsx`에 기본 주제·글별 주제(`intent=default-topic|post-topic`), `components/external/ExternalPostTable.tsx`(주제 출처 배지), 문구 `external`
- [ ] T071 [US3] front 콘솔: `blog-front/app/routes/admin/external-reviews.tsx`, `external-stats.tsx`(분포 막대는 인라인 SVG — 라이브러리 없음), `external-rules.tsx`, `external-settings.tsx`(003 `/admin/settings?prefix=external.` 재사용), `components/external/ReviewTable.tsx`·`ClassificationStats.tsx`·`RuleForm.tsx`, `routes.ts`, 문구 `external`

**Checkpoint**: US3 Independent Test E2E 통과(CI), quickstart #22~#27

---

## Phase 6: User Story 4 - 등록 해제와 운영 (Priority: P4)

**Goal**: 관리 회원은 언제든 등록을 해제하고(수집된 글 즉시 삭제 선택), 운영자는 일시 중지·재개·차단하고 외부 글을 내리거나 포털에서 제외하며, 신고(005)로 들어온 삭제 요청을 처리한다. 7일 연속 실패는 자동 중지와 알림, 회원 탈퇴는 그 회원의 외부 블로그를 내린다.

**Independent Test**: 블로그 주인이 등록 해제 + "수집된 글 삭제" 선택 → 포털에서 해당 블로그 글이 모두 사라지는지 확인. (quickstart #28~#34)

FR: FR-117, FR-126, FR-127, FR-129(삭제 요청), FR-157, SC-020

### Tests for User Story 4 (backend) ⚠️

- [ ] T072 [P] [US4] `blog-backend/src/test/java/net/java21/blog/backend/external/member/ReleaseServiceTest.java`: PENDING·ACTIVE·PAUSED·STOPPED → RELEASED(그 밖 409), `next_fetch_at` NULL, `deletePosts=true`면 같은 트랜잭션에서 포털 제외 행 → 외부 글 삭제(검수·일별 클릭 CASCADE), 커밋 후 썸네일 파일 삭제, `false`면 글 행 유지하지만 포털 노출 조건에서 빠짐(T042 행렬과 같은 판단), 커밋 후 포털 캐시 무효화, 해제 뒤 같은 피드 재신청 가능 (US4 AS1, FR-126, research E16)
- [ ] T073 [P] [US4] `blog-backend/src/test/java/net/java21/blog/backend/admin/external/AdminExternalBlogServiceTest.java`(T026) 추가: 일시 중지(ACTIVE만, 글 유지), 재개(PAUSED·STOPPED만, 실패 수·첫 실패 초기화, `next_fetch_at = now`), 차단(사유 필수, 모든 글 `REMOVED`(`BLOG_BLOCKED`), BLOCKED에서 다시 차단 409), 외부 글 내림(`REMOVED`·`ADMIN`, 이미 내린 글 409), 외부 글 포털 제외 PUT(멱등·사유 변경)·DELETE(없으면 404 `PORTAL_EXCLUSION_NOT_FOUND`), 각 작업 기록(`EXTERNAL_BLOG_PAUSE`·`RESUME`·`BLOCK`·`EXTERNAL_POST_REMOVE`·`PORTAL_EXCLUDE`·`PORTAL_UNEXCLUDE` 대상 `EXTERNAL_POST`)과 포털 캐시 무효화; 컨트롤러 `AdminExternalPostControllerTest.java` (US4 AS2, FR-127)
- [ ] T074 [P] [US4] 탈퇴: `blog-backend/src/test/java/net/java21/blog/backend/user/service/AccountServiceTest.java`(001)에 `MemberWithdrawnEvent` 발행, `external/event/MemberWithdrawnListenerTest.java`(`@JpaRepositoryTest` 조합): 그 회원의 거절·해제가 아닌 등록 모두 RELEASED, 글 `REMOVED`(`MEMBER_WITHDRAWN`), 다른 회원의 등록은 그대로, 같은 트랜잭션(탈퇴가 롤백되면 함께 롤백), 이후 다른 회원이 같은 피드 신청 가능 (FR-157, SC-020)
- [ ] T075 [P] [US4] `blog-backend/src/test/java/net/java21/blog/backend/external/job/ExternalCleanupJobTest.java`(`MutableClock`, 임시 디렉터리): 만료 7일 지난 인증 코드 삭제, RELEASED 30일 지난 등록의 남은 글 삭제(포털 제외 행 먼저), 90일 지난 일별 클릭 삭제, 월요일 실행분만 `external/` 아래 DB에 없는 키 파일 삭제, 500건씩 (research E15)
- [ ] T076 [P] [US4] (005 머지 후) `blog-backend/src/test/java/net/java21/blog/backend/external/report/ExternalReportHandlersTest.java`와 `ExternalReportPreviewRepositoryTest.java`(`@JpaRepositoryTest`): `EXTERNAL_POST` — 포털 노출 중인 글만 신고 가능(아니면 404), `target_user_id` = 관리 회원 또는 NULL, 미리보기 IN 1회, 조치 `REMOVE_FROM_PORTAL` → `REMOVED`(`REPORT`)·되돌리기 미지원 표시, 원문 링크·visit 주소로 대상 해석(권리 침해 양식); `EXTERNAL_BLOG` — 거절·해제·차단이 아닌 등록만, 조치 `BLOCK_EXTERNAL_BLOG` → 차단(사유 = 신고 사유); 005 `ReportServiceTest`에서 두 대상 종류가 더 이상 400이 아님 (US4 AS3, FR-127, FR-129, research E17)

### Tests for User Story 4 (front) ⚠️

- [ ] T077 [P] [US4] `blog-front/tests/unit/routes/manageExternalBlog.test.tsx`(T065) 추가: 해제 폼("수집된 글도 지금 삭제" 체크, 확인 문구, 해제 후 상태), 자동 중지 안내; `tests/unit/routes/adminExternalBlogs.test.tsx`(T031) 추가: 상태별 버튼(일시 중지·재개·차단), 차단 확인 문구·사유 필수, 글 표의 "내림"(사유)·"포털 제외"·"제외 해제"; `tests/unit/components/notification/*.test.tsx`에 007 알림 3종 문구·링크; (005 머지 후) `PortalCard.test.tsx`에 "삭제 요청" — 로그인이면 신고 레이어(`EXTERNAL_POST`), 비로그인이면 `/rights-request?url=원문`

### Tests for User Story 4 (E2E) ⚠️

- [ ] T078 [P] [US4] E2E `blog-front/tests/e2e/external-us4-operations.spec.ts`(`requireBackend`·`requireAdmin`·`requireExternalTestSettings`): Independent Test — 회원이 등록·승인된 피드를 "수집된 글도 삭제"와 함께 해제 → 포털 최신·주제 페이지에서 그 블로그 글이 모두 사라짐(캐시 0s) → 같은 피드 재신청 가능; 다른 피드는 삭제 없이 해제해도 포털에서 사라짐; 관리자 일시 중지(새 글 수집 안 됨, 기존 글 유지) → 재개(수집됨) → 차단(모두 사라짐, 재신청 409 넘겨받기 불가); 외부 글 "포털 제외" → 사라짐 → 해제 → 다시 보임; 스텁을 500으로 바꾼 피드의 연속 실패 수 증가(자동 중지 7일은 backend 시험 T028로 덮음); 외부 블로그를 가진 회원 탈퇴 → 포털에서 사라짐 (US4 AS1·AS2·AS4, FR-157, SC-020, quickstart #28~#31·#33·#34)
- [ ] T079 [P] [US4] (005 머지 후) E2E `blog-front/tests/e2e/external-us4-report.spec.ts`: 로그인 회원이 외부 카드 "삭제 요청" → 신고 레이어 → 관리자 신고 처리 "포털에서 내림" → 포털에서 사라짐; 로그아웃 상태 "삭제 요청" → `/rights-request?url=`가 원문 주소로 채워짐 → 접수 → 관리자 신고 상세의 대상이 그 외부 글 (US4 AS3, quickstart #32)

### Implementation for User Story 4

- [ ] T080 [US4] 해제: `blog-backend/src/main/java/net/java21/blog/backend/external/member/ReleaseService.java`, `MemberExternalBlogController.java`에 `POST /me/external-blogs/{id}/release`, 썸네일 삭제 커밋 후 리스너
- [ ] T081 [US4] 운영자 동작: `blog-backend/src/main/java/net/java21/blog/backend/admin/external/AdminExternalBlogService.java`·`Controller`에 pause·resume·block, `AdminExternalPostController.java`(`GET /admin/external-blogs/{id}/posts`, `POST /admin/external-posts/{id}/remove`, `PUT·DELETE /admin/portal/external-exclusions/{externalPostId}`), `external/repository/ExternalPostQueryRepository.java`에 관리자 글 목록(포털 제외 정보 LEFT JOIN 쿼리 2회)
- [ ] T082 [US4] 탈퇴 연동: `blog-backend/src/main/java/net/java21/blog/backend/user/event/MemberWithdrawnEvent.java`, `user/service/AccountService.java`의 `withdraw`에서 발행, `external/event/MemberWithdrawnListener.java`(`@EventListener`, 같은 트랜잭션)
- [ ] T083 [US4] `blog-backend/src/main/java/net/java21/blog/backend/external/job/ExternalCleanupJob.java`(`@Scheduled(cron = "${blog.external.cleanup-cron}")`)
- [ ] T084 [US4] (005 머지 후) 신고 처리기: `blog-backend/src/main/java/net/java21/blog/backend/external/report/ExternalPostReportHandler.java`·`ExternalBlogReportHandler.java`(005 `ReportTargetHandler` 구현, 원문 링크·visit 주소 해석), 005 조치 enum의 `REMOVE_FROM_PORTAL`·`BLOCK_EXTERNAL_BLOG` 연결, `external/repository/ExternalReportPreviewRepository.java`
- [ ] T085 [US4] front 해제·운영: `blog-front/app/routes/manage/external-blog.tsx`에 `intent=release`(`components/external/ReleaseForm.tsx`), `blog-front/app/routes/admin/external-blog.tsx`에 `intent=pause|resume|block|remove|exclude|unexclude`, 문구 `external`·`admin`
- [ ] T086 [US4] (005 머지 후) front 신고 연결: `blog-front/app/components/portal/PortalCard.tsx`의 "삭제 요청"(005 `ReportButton`/`ReportDialog`에 `EXTERNAL_POST`, 비로그인 `/rights-request?url=`), 005 신고 레이어·콘솔 신고 화면의 대상 종류 문구(`report` namespace)와 외부 미리보기 표시

**Checkpoint**: US4 Independent Test E2E 통과(CI), quickstart #28~#34(#32는 005 머지 후)

---

## Phase 7: Polish & Cross-Cutting Concerns

- [ ] T087 [P] `blog-backend/src/test/java/net/java21/blog/backend/openapi/OpenApiContractTest.java`에 contracts/api.md의 007 엔드포인트(공개 2, 회원 11, 관리자 21)와 003 확장(`PortalCard` 필드, `source` 파라미터), 응답 스키마 필드
- [ ] T088 [P] `blog-backend/src/test/java/net/java21/blog/backend/security/CacheHeadersWebMvcTest.java`에 007 회원·관리자 API 전부 `Cache-Control: no-store`, visit `no-store`, 썸네일 `public, max-age=86400`
- [ ] T089 (006 머지 후) 행렬 시험에 007 반영: `blog-backend/src/test/java/net/java21/blog/backend/integration/AdminEndpointAccessMatrixTest.java`(006 T008)가 007 관리자 매핑 21개를 자동으로 덮는지 확인(경로 변수 채움 규칙에 `{externalPostId}` 추가), `AdminAuditCoverageIntegrationTest.java`(006 T046) 표에 007 변경 매핑 행(직접 등록·PATCH·승인·거절·중지·재개·차단·내림·포털 제외 2·검수 확정 2·규칙 3 → 작업 종류), 회원 API는 `/me/**`라 006 `ManageEndpointAccessMatrixTest` 대상이 아님을 표 주석으로
- [ ] T090 [P] `blog-backend/src/test/java/net/java21/blog/backend/integration/ExternalFeedFlowIntegrationTest.java`(`@SpringBootTest` H2, `StubHttpServer`, `blog.outbound.allow-private=true`, 수집 주기 1초): 회원 신청 → 관리자 승인 → 스케줄러가 수집 → `GET /api/v1/portal`에 외부 카드 → visit 302·클릭 1 → 해제 → 포털에서 사라짐 (핵심 흐름 1개)
- [ ] T091 [P] 운영 문서 `blog-backend/docs/operations.md`에 007 프로퍼티(`blog.external.*`), 수집 주기·자동 중지·재개 절차, 외부 요청 보안(내부망 차단 규칙, DNS 재바인딩 한계와 **나가는 연결의 사설 대역 방화벽 권고**, `blog.outbound.allow-private`는 시험 전용), 썸네일 디렉터리 `thumbnail-dir/external/`(백업 제외, 다시 받을 수 있음), 키워드 사전 고치는 방법(PR, 버전 올리기), 선택 인덱스가 없을 때 분류 현황 비용. front 4개 언어 README(`blog-front/README.md`·`README.en.md`·`README.ja.md`·`README.zh-CN.md`)에 E2E 피드 스텁과 환경 변수(`E2E_EXTERNAL_TEST_SETTINGS`, `E2E_FEED_STUB_PORT`, backend `BLOG_OUTBOUND_*`·`BLOG_EXTERNAL_*`, 결정 표 33번)
- [ ] T092 [P] E2E `blog-front/tests/e2e/external-mobile.spec.ts`(`requireBackend`, 뷰포트 360×740): 신청 단계·상세·포털 외부 카드·출처 필터 가로 스크롤 없음, `requireAdmin`일 때 콘솔 외부 블로그 목록·검수 표는 가로 스크롤 상자 안 (quickstart #40); `blog-front/tests/e2e/us5-i18n.spec.ts`(001)에 외부 블로그 화면·상태·오류·알림 문구가 en·ja·zh-CN이고 외부 제목은 원문 그대로 (quickstart #39)
- [ ] T093 커버리지 확인: `blog-backend`의 `./mvnw verify`, `blog-front`의 `npm test -- --coverage` 모두 라인 80% 이상
- [ ] T094 CI 확인: blog-front PR의 `e2e-backend` 잡 로그에서 `external-us1-*`·`external-us2-*`·`external-us3-*`·`external-us4-operations`·`external-mobile`이 **건너뜀(skipped) 없이 통과**했는지, 스텁 서버가 떴는지(`/__stub/health`), backend 로그에 인터넷 주소 요청이 없는지 확인하고 PR 설명에 실행 수를 적음(건너뛰었다면 T004 환경 변수부터 고침, `external-us4-report`는 005 머지 후)
- [ ] T095 `blog-docs/specs/007-external-feeds/quickstart.md` 수동 검증 시나리오 #1~#40 전체 실행(backend·front·피드 스텁 함께 기동, #32는 005 머지 후), 끝난 작업을 이 tasks.md에 [x]로 표시

---

## 구현 전 결정 사항 (2026-10-07 확정)

marco가 "묻지 말고 진행"하라고 해서 Claude가 기본값으로 정했다. 바꾸려면 이 표와 관련 문서를 함께 고친다. **24번은 spec 문장 두 개(US4 AS1과 SC-020)를 한쪽으로 읽은 것이라 marco 확인이 필요하다.**

| # | 문제 | 결정 | 반영 문서 |
|---|---|---|---|
| 1 | 스토리 순서와 US1 체크포인트 | spec 그대로: US1 등록과 인증(P1), US2 포털 노출(P2), US3 분류 개선과 검수(P3), US4 해제와 운영(P4). US1 Independent Test의 "포털에 글이 나오는지 확인"은 US2가 끝나야 되므로 US1 체크포인트는 "수집된 글이 회원·관리자 화면에 나옴"까지, 포털 확인은 US2 체크포인트. 일정이 부족하면 US3를 뒤로(분류는 기본 주제·규칙만으로도 동작) | plan.md, 이 문서 |
| 2 | 시작 조건 | 004가 main에 머지된 뒤 시작. 005·006과는 병렬, 기대는 작업은 "(005 머지 후)" 5개(T076·T079·T084·T086, T077 일부)·"(006 머지 후)" 2개(T022 번역 일부, T089)와 메뉴 켜기(T040·T041은 006 전이면 001·003 메뉴 파일에) | plan.md, 아래 의존 표 |
| 3 | 패키지 구조 | 등록·수집·분류·썸네일·포털 연결을 `external` 한 도메인 아래 하위 패키지로, 관리자 API는 `admin/external`. 포털은 `ExternalPortalSource` 인터페이스 하나로 연결(빈이 없으면 003 그대로) | plan.md "Structure Decision" |
| 4 | 005·006과 공유하는 코드 | `OutboundUrlGuard`·`HostResolver`·`OutboundProperties`·`StubHttpServer`(005), `AuditActions` 목록·`audit` 번역(006), E2E `backend.ts`·workflow 환경 변수·Playwright 프로젝트는 먼저 머지하는 스펙이 만들고 다른 쪽은 재사용(중복 정의 금지) | 아래 의존 표 |
| 5 | 외부 요청 제한값 | 연결 5초, 요청 전체 10초, 리다이렉트 최대 3번(매번 검사), 크기 피드 2MB·HTML 1MB·이미지 5MB(읽으면서 끊음), `Accept-Encoding` 보내지 않음(identity), User-Agent `java21-blog-feed/1.0 (+{base-url}/updates)` | research E2, contracts/api.md 프로퍼티 |
| 6 | SSRF 규칙과 한계 | 모든 외부 요청은 `SafeHttpFetcher` 한 곳. 005 `OutboundUrlGuard`(http/https, 허용 포트, `user@` 금지, 해석한 모든 주소가 공인) + 우리 서비스 호스트(`blog.base-url`·`forbidden-hosts`, 하위 도메인) 거부. 미리보기·인증 확인은 로그인 회원만. DNS 재바인딩은 완전히 막지 못함 → 운영 문서에 방화벽 권고 | research E2, T091 |
| 7 | 피드 형식과 파서 | ROME(이미 의존성), RSS 0.9x/1.0/2.0·Atom, `allowDoctypes=false`(XXE·엔터티 폭탄 차단). JSON Feed는 1.0 범위 밖 | research E3 |
| 8 | 피드 찾기 | 직접 피드 → HTML `<link rel=alternate>` 첫 번째 → `/rss`·`/feed` 두 번 시도. 그 이상 추측하지 않음 | research E3 |
| 9 | 피드 주소 중복 판단 | 정규화에서 스킴을 지워 http·https를 같은 피드로(data-model 규칙에 더함). 저장하는 `feed_url`은 최종 주소 | research E6, data-model |
| 10 | 요약·제목 정제 | HTML을 살균해 저장하지 않고 **태그를 지운 일반 텍스트**로만(요약 코드 포인트 200자, 넘으면 199자 + "…", 제목 300자). front는 이스케이프 출력만. 본문 문자열은 계산 후 버림 | research E4 |
| 11 | 대표 이미지 선택 | enclosure(image/*) → Media RSS(`rome-modules` 없이 foreign markup) → 본문 첫 `<img>`(1×1 추적 픽셀 제외). 원문 페이지 `og:image`는 가져오지 않음 | research E4 |
| 12 | 썸네일 방식 (spec "계획 단계에서 결정") | **소유 인증된 블로그 글만 backend가 받아 600x400 한 크기로 줄여 캐시**(`thumbnail-dir/external/`, `/media/external/{key}`, 원본 저장 안 함, 하루 캐시). 인증 없는 블로그는 이미지를 받지 않음. 핫링크(링크만)는 쓰지 않음 — front CSP `img-src 'self'`(001 R27에 이미 이 방식으로 적힘), 방문자 IP 노출, 혼합 콘텐츠. 인증이 나중에 되면 최근 30일 글 최대 100개 소급. 001 `media` 행은 쓰지 않음(`owner_id NOT NULL`) | research E7 |
| 13 | 최초 수집 범위 | 첫 성공 수집만 최근 30일·최대 100개. 이후는 피드에 있는 것 전부(한 번에 100개). 날짜 없는 글은 처음 수집한 시각, 미래 시각은 수집 시각 | research E4·E5 |
| 14 | 같은 글 갱신 범위 | 제목·요약·이미지 주소·발행 시각·카테고리만 바뀌었을 때 갱신. 주제는 다시 정하지 않음(사람이 정한 값 보호, 규칙은 이후 수집분부터). REMOVED는 되살리지 않음 | research E5 |
| 15 | 수집 주기·임대·지연·중지 | 선택 1분(`poll-interval`), 주기 30분(운영 설정, 관리자 범위 10분~24시간), 무작위 0~5분, 고른 행 10분 임대, 실패 지연 30분×2^(n-1) 최대 12시간, 첫 실패부터 7일이면 STOPPED + 관리 회원 알림. 큐가 차면 그 차례 건너뜀 | research E1·E5 |
| 16 | 인증 코드와 확인 | `java21-verify-` + base62 12자, 24시간, 같은 회원·피드면 유효한 코드 재사용. 피드(채널·항목 20개 텍스트)와 사이트 HTML(텍스트·meta 값) 두 곳에서 찾음. 회원당 확인 시간당 10회 | research E8 |
| 17 | 넘겨받기 규칙 | 같은 피드의 성공한 인증이면 PENDING·ACTIVE·PAUSED·STOPPED 등록을 넘겨받음(다른 회원의 미인증 신청, 운영자 등록 포함). BLOCKED 불가(409), 거절·해제는 새로 신청. 회원 3개 한도에 셈. 이전 회원 알림 없음(1.0). 이미 인증된 주인이 있어도 새 인증으로 넘어감(마지막 증명 우선) | research E8 |
| 18 | 관리 권한 | `member_id` 회원(관리 회원)은 조회·해제. 글별 주제·기본 주제 변경은 **소유 인증된 주인만**(미인증 신청자는 "추천한 사람"이지 블로그 주인이 아님, FR-120·AS8). STOPPED·PAUSED 재개는 운영자만 | research E8·E10, contracts/api.md |
| 19 | 신청·직접 등록 때 피드 확인 | 신청·직접 등록 순간 피드를 다시 받아 읽히지 않으면 422 `EXTERNAL_FEED_UNREADABLE`(승인 후 첫 수집에서야 실패를 아는 일 방지) | research E8 |
| 20 | 회원 한도에서 세는 상태 | REJECTED·RELEASED를 뺀 전부(BLOCKED 포함 — 차단된 블로그로 한도를 비우지 못하게). 운영자 직접 등록은 회원이 없어 세지 않음 | research E8, data-model |
| 21 | 자동 분류 방식 (spec "계획 단계에서 정한다") | **(A) 키워드 사전 기반** `KeywordTopicClassifier`(`keyword-v1`, 리소스 파일, 4개 언어 + 기술 용어), 신뢰도 `(top/sum) × min(1, top/4)`, 기준 0.7(운영 설정). `TopicClassifier` 인터페이스로 교체 가능(FR-119). (B) 외부 AI API는 비용·비밀 값·외부 전송 때문에, (C) 학습 모델은 spec이 데이터가 쌓이기 전 금지라 쓰지 않음 | research E9 |
| 22 | 검수 대상과 일괄 확정 | DEFAULT로 정해지고 자동 분류 신뢰도가 기준 미만(일치 없음 포함)인 새 글만 PENDING. 매핑 규칙(RULE)으로 정해진 글은 분류기를 돌리지 않고 검수도 없음. 목록은 ACTIVE 글만. 일괄 확정 50개, 행마다 작업 기록 | research E10 |
| 23 | 포털 카드와 합치기 | 003 `PortalCard`에 `source`·`visitUrl`·`externalBlog`, 외부는 `author` null·좋아요/댓글 0. 최신은 (시각, 출처, id) 합치기 + 블로그당 2편 키 `P:`/`E:` + 커서에 출처. 인기는 같은 스냅숏. 추천·인기 태그·새 블로그는 내부만. 주제 자동 숨김 수에 외부 합산. 필터 `?source=all|internal|external`(메인은 최신 영역만) | research E13, contracts/api.md |
| 24 | 해제할 때 "수집된 글 유지"의 의미 **[marco 확인 필요]** | spec US4 AS1("글도 삭제를 고르면 포털에서 사라진다")과 SC-020("등록 해제 후 5분 안에 포털에서 사라진다")이 다르게 읽힌다. **SC-020을 따름**: 해제하면 선택과 관계없이 포털에서 바로 사라지고, "수집된 글도 삭제"는 데이터를 지금 지울지(체크) 30일 보관 후 지울지(신고·권리 침해 처리 근거)의 선택. 다르게 원하면(유지 시 포털 계속 노출) 노출 조건의 블로그 상태에 RELEASED를 더하고 SC-020을 고쳐야 함 | research E16, data-model |
| 25 | 클릭 집계 | `GET /api/v1/external-posts/{id}/visit` → 302(부수 효과 있는 GET, contracts "설계 규칙과 다르게"), 같은 방문자 30분 1회, `click_count` + 일별 행, `Referrer-Policy: no-referrer`, robots `Disallow: /api/`(이미 있음) + `nofollow`. 카드는 새 탭 일반 링크(JS 없이) | research E14 |
| 26 | 외부 인기 점수 | 최근 7일 클릭 × `external.score-weight`(기본 1.0, 범위 0~10) × 003 감쇠. 신고 감점 대상 아님. 가중치 0이면 인기 목록에서 빠짐 | research E13 |
| 27 | 주제 페이지 합치기 비용 | 두 출처에서 (id, 시각)만 `(page+1) × size`행 읽어 합침. `page`가 49를 넘으면 빈 목록(1,000편 너머, 003 화면에서 닿지 않음) | research E13, contracts/api.md |
| 28 | 원문 링크 점검 | 주 1회(월 04:30) ACTIVE 글 중 7일 안 점검 안 한 것 500개, HEAD(405·501이면 GET 0바이트). 404·410·도메인 없음만 `LINK_BROKEN`, 그 밖 실패는 다음 주에 다시. 같은 호스트 1초 간격 | research E12 |
| 29 | 내림·포털 제외·차단의 되돌리기 | 외부 글 "내림"(`REMOVED`, 운영자·신고·링크 점검)은 되돌리지 않음. 되돌릴 수 있게 숨기려면 "포털 제외"(003 `portal_exclusions.external_post_id`, PUT/DELETE). 외부 블로그 차단 해제 API는 1.0에 없음(필요하면 marco 결정 후 추가) | research E16·E17, contracts/api.md |
| 30 | 회원 탈퇴·정지 | 탈퇴(FR-157)는 `AccountService.withdraw`가 같은 트랜잭션에서 `MemberWithdrawnEvent` → 그 회원 등록 RELEASED + 글 `MEMBER_WITHDRAWN`. 005 회원 정지는 외부 블로그에 영향 없음(외부 글은 그 회원이 쓴 콘텐츠가 아님, 필요하면 운영자가 차단) | research E16 |
| 31 | 신고 연동 | 005 처리기 두 개(`EXTERNAL_POST` → `REMOVE_FROM_PORTAL`, `EXTERNAL_BLOG` → `BLOCK_EXTERNAL_BLOG`), 권리 침해 주소가 visit 주소·원문 링크면 대상 자동 지정. 카드 "삭제 요청"은 회원 신고 레이어 / 비회원 `/rights-request?url=`. 005 머지 전에는 링크를 숨기고 운영자가 콘솔 "내림"으로 처리 | research E17 |
| 32 | 운영 설정 키 범위 | `external.fetch-interval` PT10M~PT24H(프로퍼티는 시험용 1초까지), `external.auto-classify-min-confidence` 0~1, `external.score-weight` 0~10. 콘솔 "외부 블로그 설정" 탭에서(003 설정 API 재사용) | contracts/api.md |
| 33 | E2E가 CI에서 실제로 도는 조건 | 로컬 피드 스텁(`feed-stub-server.mjs`, Playwright `webServer` 배열로 두 workflow 모두에서 기동, 인터넷 요청 0건). backend에 `BLOG_OUTBOUND_ALLOW_PRIVATE=true`·`BLOG_OUTBOUND_ALLOWED_PORTS`에 4610·`BLOG_EXTERNAL_POLL_INTERVAL=2s`·`FETCH_INTERVAL=PT5S`·`FETCH_JITTER=PT0S`·미리보기/인증 확인 한도 1000, Playwright에 `E2E_EXTERNAL_TEST_SETTINGS=1`·`E2E_FEED_STUB_PORT=4610`. 관리자 계정은 003 것. `external` 프로젝트(workers 1, 포털 뒤). 내부망 차단은 backend 시험으로 덮음(E2E는 allow-private). T094에서 건너뜀 없이 돌았는지 확인 | research E18, T003·T004·T094 |
| 34 | 번역 namespace와 오류 코드 | 새 namespace `external`. 포털 카드·필터는 `portal`, 메뉴는 `admin`·`manage`, 알림 `notification`, 작업 기록 `audit`(006). 새 오류 코드 15개(contracts/api.md), 없는 매핑 규칙은 001 `NOT_FOUND` | contracts/api.md, contracts/routes.md |
| 35 | 스키마 변경 | 필수 DDL 없음. 선택 인덱스 1개(`idx_external_posts_topic_decided`)는 plan.md에 정확한 DDL만 두고 Crowfoot `plan_migration` → marco 승인 전에는 만들지 않음. 이 작업에서 Crowfoot 문서와 DB는 건드리지 않음. 새 값(`EXTERNAL_BLOG_UPDATE` 작업 종류)은 VARCHAR 값이라 DDL 아님 | plan.md "스키마 변경" |
| 36 | 미리보기·인증 확인의 남용 방지 | 로그인 회원만, 미리보기 회원당 시간당 20회·같은 피드 10분 캐시, 인증 확인 시간당 10회(429). 비로그인에게 서버발 외부 요청을 열지 않음 | research E3·E8 |
| 37 | 알림 받는 사람과 링크 | 승인·거절은 신청 회원, 자동 중지는 관리 회원(없으면 알림 없음). 링크 `/manage/external-blogs/{id}` → 최근 블로그의 관리 화면으로 리다이렉트 | contracts/api.md, contracts/routes.md |
| 38 | 관리자의 기본 주제 변경 | 콘솔 상세에서 바꿀 수 있게 `PATCH /admin/external-blogs/{id}`와 작업 종류 `EXTERNAL_BLOG_UPDATE`를 더함(006 data-model 표에 추가함). 이미 수집된 글은 바꾸지 않음 | contracts/api.md, 006 data-model |
| 39 | SC-019(최종 주제 정확도 85%) 측정 | 주제 변경 이력 컬럼이 없어(스키마 변경 회피) "검수 확정 표본에서 확정 주제가 노출 중이던 기본 주제와 같은 비율"로 근사하고, FR-122의 자동 분류 정확도와 함께 정의를 화면에 보임. 정확한 측정이 필요하면 이력 테이블을 marco 승인 후 추가 | research E11 |
| 40 | 다른 스펙의 일과 범위 밖 | 신고 접수·처리 화면과 권리 침해 양식(005), 콘솔·블로그 관리 레이아웃과 메뉴 정의·행렬 시험(006). spec 범위 밖: 핑백·WebSub, 학습 모델, 외부 글 댓글·좋아요. 이 계획에서 뺀 것: JSON Feed, 외부 AI 분류, 외부 블로그 공개 소개 화면, 큐레이션·인기 태그에 외부 글, 차단 해제, 넘겨받기 알림, 서버 2대 분산 잠금 | plan.md "범위 밖" |

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: 001~004가 main에 있어야 함(004 머지 후)
- **Foundational (Phase 2)**: Setup의 프로퍼티(T005)·모델 타입(T002)·스텁과 CI 환경(T003·T004) 이후. 모든 스토리를 막는다
- **US1 등록과 인증 (Phase 3)**: Phase 2(외부 요청 T016, 피드 읽기 T017, 엔티티 T018, 알림 T021, 작업 종류 T022) 이후. MVP
- **US2 포털 노출 (Phase 4)**: US1의 수집(T037)·썸네일(T038) 이후(수집된 글이 있어야 포털에 나옴). `PortalExclusion` 매핑(T019) 필요
- **US3 분류 개선과 검수 (Phase 5)**: US2의 `TopicDecider`(T055) 이후(검수 행이 생겨야 함)
- **US4 해제와 운영 (Phase 6)**: US1 이후(등록·수집이 있어야 함). 포털에서 사라지는 확인은 US2 이후. 005에 기대는 T076·T079·T084·T086은 005 머지 후
- **Polish (Phase 7)**: 원하는 스토리가 모두 끝난 뒤. T089는 006 머지 후

### 004·005·006·003 의존 (007이 기대는 앞 스펙 작업)

| 007 작업 | 기대는 작업 | 내용 |
|---|---|---|
| T016 (`OutboundUrlGuard`·`HostResolver`·`StubHttpServer`), T007 | 005 T023·T010(내부망 차단), 005 T009·T090이 쓰는 `support/StubHttpServer` | 먼저 머지하는 쪽이 만듦(결정 표 4번). 007이 먼저면 005 계획의 규칙·시험 그대로 만들고 005 PR이 재사용 |
| T005 (`OutboundProperties`) | 005 T005(`common/net/OutboundProperties`) | 같은 클래스. 먼저 머지하는 쪽이 만듦 |
| T003·T004 (E2E 도구·workflow·Playwright 프로젝트) | 005 T003·T004(`requireModerationTestSettings`, `moderation` 프로젝트, `BLOG_OUTBOUND_*`), 006 T003·T004(`admin` 프로젝트) | 같은 파일. `external` 프로젝트의 `dependencies`를 머지 상태에 맞춤, 포트 값 합치기 |
| T076·T084 (신고 처리기) | 005 T050(`ReportTargetHandler`), T051(신고 접수), T052(관리자 신고 처리, 조치 enum) | 005 머지 후. 그 전에는 신고 대상 400(005 결정 표 5번) |
| T079·T086 (카드 "삭제 요청") | 005 T058(`ReportButton`·`ReportDialog`), T059(`/rights-request`), T060(콘솔 신고 화면) | 005 머지 후 |
| T022 (`AuditActions`, `audit` 번역), T089 (행렬 시험) | 006 T006·T011(`AuditActions.ALL`·`TARGETS`), T001(`audit` namespace), T008(관리자 API 404 행렬), T046(작업 기록 강제 표) | 006 머지 후 번역·표 행 추가. 그 전에는 상수만 |
| T040·T041 (메뉴 켜기) | 006 T013(`admin/links.ts`·`manage/links.ts` 메뉴 정의) | 006 머지 후면 `available: true`, 그 전이면 003 `ADMIN_MENU`·001 `MANAGE_MENU`에 항목 추가(006이 옮길 때 함께) |
| T040 (블로그 관리 메뉴·레이아웃) | 004 T111·T120(`feat/004-rest`의 메뉴 "백업"·"차단 목록") | 같은 메뉴 파일, 004 머지 후 |
| T053~T056 (포털 합치기·점수·자동 숨김) | 003 `PortalService`·`TopicPostService`·`PopularityCalculator`·`PortalCursor`·`PerBlogCap`·`TopicPostCountQueryRepository`·`PortalCardResponse`(main) | 003 시험이 그대로 통과해야 함 |
| T019 (`PortalExclusion`) | 003 `AdminExclusionService`·`PortalExclusionRepository`(main) | 매핑만 넓힘 |
| T020 (`SettingKey`) | 003 `SettingKey`·`SystemSettingsService`(main), 005 T005·T0xx(`ratelimit.*`·`spam.*` 키) | 같은 enum, 머지 순서 |
| T021 (`NotificationType`) | 002 `NotificationType`(main), 004 `BACKUP_READY`(004-rest), 005 `REPORT_RESOLVED` | 같은 enum, 머지 순서 |
| T029·T038 (썸네일) | 001 `ImageInspector`·`ThumbnailService`·`MediaKeyGenerator`·`MediaProperties`(main) | 재사용 |
| T037 (수집 풀) | 001 `SchedulingConfig.feedFetchExecutor`·`ExternalFeedProperties`(main) | 그대로 사용 |
| T082 (탈퇴) | 001 `AccountService.withdraw`(main) | 이벤트 발행만 추가 |
| T015 (`ErrorCode`), T001 (`errors.json` 등) | 004-rest·005·006의 같은 파일 변경 | 머지 순서 |

### User Story Dependencies

- **US1 (P1)**: Phase 2 이후. 다른 스토리에 의존하지 않음
- **US2 (P2)**: US1의 수집 이후. 수집된 글만 있으면 독립 시험 가능(관리자 직접 등록으로 준비)
- **US3 (P3)**: US2의 주제 결정 이후. 독립 시험 가능
- **US4 (P4)**: US1 이후. 포털 확인은 US2 이후. 005 몫만 005 머지 후

### Within Each User Story

- 테스트를 먼저 쓰고 실패를 확인한 뒤 구현한다(원칙 III)
- 엔티티(Phase 2) → 리포지토리(QueryDSL) → 서비스 → 컨트롤러 → front 라우트 → E2E
- 외부 HTTP는 `StubHttpServer`, 내부망 판정은 가짜 `HostResolver`. 리포지토리 시험은 H2 `@JpaRepositoryTest` + `QueryCounter`, 생성 컬럼 UNIQUE만 `@MySqlRepositoryTest`
- 새 화면 문구·오류 코드는 같은 작업에서 4개 언어 번역을 넣는다(원칙 VII)
- 스토리의 E2E(Independent Test)가 CI에서 통과해야 다음 우선순위로 넘어간다

### Parallel Opportunities

- Setup의 [P] 작업(T001~T006)은 모두 병렬
- Phase 2 테스트(T007~T014)는 모두 [P], 구현은 외부 요청·피드(T016·T017)와 엔티티·코드 목록(T018~T022)이 병렬
- 각 스토리의 테스트 작업(backend·front·E2E)은 모두 [P]
- US1 backend(T033~T039)와 front(T040·T041)는 API 계약이 정해져 있어 병렬
- 같은 파일(`ErrorCode`, `AuditActions`, `SettingKey`, `NotificationType`, `SecurityConfig`, `PortalService`·`TopicPostService`·`PopularityCalculator`(T054), `MemberExternalBlogController`(T035·T067·T080), `AdminExternalBlogService`(T036·T081), `models.ts`, `PortalCard.tsx`(T058·T086), `routes.ts`, `routes/manage/external-blog.tsx`(T040·T070·T085), `routes/admin/external-blog.tsx`(T041·T085), `errors.json`, `external.json`, `playwright.config.ts`, `tests/e2e/support/backend.ts`, 두 workflow)을 고치는 작업은 순서대로 머지한다

---

## Parallel Example: User Story 1

```bash
# backend 테스트를 함께 시작:
Task: "PreviewServiceTest in blog-backend/src/test/java/net/java21/blog/backend/external/member/PreviewServiceTest.java"
Task: "VerificationServiceTest in blog-backend/src/test/java/net/java21/blog/backend/external/verify/VerificationServiceTest.java"
Task: "FeedCollectorTest in blog-backend/src/test/java/net/java21/blog/backend/external/fetch/FeedCollectorTest.java"
Task: "ExternalThumbnailServiceTest in blog-backend/src/test/java/net/java21/blog/backend/external/thumbnail/ExternalThumbnailServiceTest.java"

# front 테스트와 E2E를 함께 시작:
Task: "manageExternalBlogs.test.tsx in blog-front/tests/unit/routes/manageExternalBlogs.test.tsx"
Task: "external-us1-register.spec.ts in blog-front/tests/e2e/external-us1-register.spec.ts"
```

## Parallel Example: User Story 2

```bash
Task: "ExternalPortalQueryRepositoryTest in blog-backend/src/test/java/net/java21/blog/backend/external/portal/ExternalPortalQueryRepositoryTest.java"
Task: "KeywordTopicClassifierTest in blog-backend/src/test/java/net/java21/blog/backend/external/classify/KeywordTopicClassifierTest.java"
Task: "LinkCheckJobTest in blog-backend/src/test/java/net/java21/blog/backend/external/job/LinkCheckJobTest.java"
Task: "PortalCard.test.tsx in blog-front/tests/unit/components/PortalCard.test.tsx"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1 Setup, Phase 2 Foundational(CI에서 스텁 서버가 뜨고 001~004 E2E가 새 환경으로 통과하는지 먼저 확인)
2. Phase 3 (US1 등록과 인증)
3. **멈추고 확인**: US1 Independent Test E2E(CI), quickstart #1~#11
4. 시연 가능(등록·인증·승인·수집까지. 포털 노출은 US2)

### Incremental Delivery

1. Setup + Foundational → 기반 완료(안전한 외부 요청, 피드 읽기, 엔티티)
2. US1(Phase 3) → MVP
3. US2(Phase 4) → 사용자 가치(포털 노출) 완성 → 배포 권장 시점
4. US3(Phase 5) → US4(Phase 6), 각 스토리의 E2E 통과 후 다음
5. 005가 머지되면 "(005 머지 후)" 작업(T076·T079·T084·T086)을 한 PR로, 006이 머지되면 T089와 번역·메뉴 정리를 한 PR로
6. Polish → OpenAPI·캐시 헤더·통합 흐름·모바일·다국어 확인, CI E2E 실행 확인, quickstart 전체 검증

### Parallel Team Strategy

1. 함께 Setup + Foundational
2. Foundational이 끝나면:
   - 개발자 A: Phase 3(US1) backend(등록·수집) → Phase 4(US2) backend(포털 합치기)
   - 개발자 B: Phase 3(US1) front → Phase 4(US2) front → Phase 5(US3) front
   - 개발자 C: 분류(T046·T055, 사전 T006) → Phase 5(US3) backend → Phase 6(US4) backend
3. 같은 파일을 고치는 연결 작업은 머지 순서를 맞춘다(Phase Dependencies, 004·005·006·003 의존)

---

## Notes

- [P] = 다른 파일, 끝나지 않은 작업에 의존하지 않음
- [Story] = spec 스토리 번호(US1~US4)
- 각 PR 설명에 스펙 경로 `blog-docs/specs/007-external-feeds`를 적는다(헌법 개발 흐름 6). backend·front 브랜치는 같은 이름을 쓴다(예: `feat/007-core`, `feat/007-portal`) — front CI가 같은 이름의 backend 브랜치를 받아 E2E를 돌린다
- 엔티티는 API 응답으로 직렬화하지 않고 DTO record를 쓴다. 연관관계는 모두 LAZY, 목록은 fetch join 또는 DTO projection, 목록 테스트에는 `QueryCounter`
- 외부 요청은 `SafeHttpFetcher` 밖에서 만들지 않는다(리뷰 기준). 시험·E2E에서 인터넷 주소를 쓰지 않는다
- 수집 스케줄러·클릭 중복 제거·미리보기 한도는 backend 1대 전제(001 R26)다. 서버를 늘리면 research E1 "나중에"(ShedLock 또는 `SKIP LOCKED`)를 먼저 한다
- 관리자 변경 API를 더하면 006 작업 기록 강제 표(T089)와 006 data-model `action` 표, `AuditActions`, front `audit` namespace에 행을 더한다
- 테스트가 실패하는 것을 먼저 확인하고, 작업 단위로 커밋한다
