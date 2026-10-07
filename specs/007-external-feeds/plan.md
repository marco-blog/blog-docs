# Implementation Plan: 외부 블로그 RSS 수집과 주제 자동 분류

**Branch**: `007-external-feeds` (계획 문서는 `docs/007-plan`) | **Date**: 2026-10-07 | **Spec**: [spec.md](./spec.md)

**Status**: Phase 1 완료 (research, contracts, quickstart, tasks 작성). 다음 단계는 `/speckit-analyze` 후 `/speckit-implement`.

**Input**: Feature specification from `/specs/007-external-feeds/spec.md`

## Summary

우리 서비스 밖 블로그의 RSS·Atom을 등록해 두면 backend가 주기적으로 가져와 **제목·요약(200자)·대표 이미지 썸네일·블로그 이름·원문 링크만** 저장하고, 포털(003) 최신 글과 주제 페이지에 "외부" 표시가 붙은 카드로 내부 글과 섞어 보여준다. 카드를 누르면 backend를 거쳐(클릭 수 집계) 원문으로 새 탭에서 이동한다. 등록 경로는 둘이다: 회원이 블로그 주소·피드 주소로 신청(미리보기 → 선택적 소유 인증 → 기본 주제 → 운영자 승인)하거나, 운영자가 콘솔에서 등록 근거와 함께 바로 등록한다(US1). 수집된 글의 주제는 주인 지정 → 매핑 규칙 → 자동 분류(신뢰도 0.7 이상) → 블로그 기본 주제 순으로 정하고(US2), 신뢰도가 낮은 글은 운영자 검수 목록으로 간다(US3). 주인은 언제든 등록을 해제하면서 수집된 글을 남길지(포털에 계속 노출, 새 글 수집 없음) 지울지 고르고, 운영자는 일시 중지·차단하며, 신고(005)로 들어온 삭제 요청을 처리한다(US4).

현재 코드(blog-backend·blog-front main, 001~003과 004 Phase 1~4 머지, 004 Phase 5~8은 `feat/004-rest`에서 구현 중, 005·006은 계획만)를 대조한 결과는 [research.md](./research.md) "현재 코드에서 확인한 것"에 있다. 요약하면 007 스키마 전체(테이블 6개, `portal_exclusions.external_post_id`, 인덱스·외래 키)가 이미 Crowfoot 문서 "blog 1.0"에 있고, 001이 수집 전용 스레드 풀(`feedFetchExecutor`, `ExternalFeedProperties`)과 스케줄러 풀 크기를 미리 만들어 두었으며, 002가 ROME 의존성을, 001이 썸네일 도구(Thumbnailator·TwelveMonkeys)를, 005 계획이 내부망 차단 도구(`OutboundUrlGuard`)와 신고 처리기 자리(`ReportTargetHandler`)를, 006 계획이 콘솔·블로그 관리의 메뉴 자리(숨김)와 관리자 API 행렬 테스트를 둔다.

기술 접근:
- **안전한 가져오기**: JDK `HttpClient` 하나를 감싼 `SafeHttpFetcher`가 모든 외부 요청(피드, 블로그 HTML, 이미지, 원문 링크 점검)을 맡는다. 자동 리다이렉트를 끄고 최대 3번까지 직접 따라가며 매번 005 `OutboundUrlGuard`(사설·루프백·링크로컬·CGNAT·멀티캐스트 주소, 허용 포트, `user@`, http/https만)와 "우리 서비스 주소 금지"를 검사한다. 연결 5초·전체 10초·응답 크기(피드 2MB, HTML 1MB, 이미지 5MB)는 스트림을 읽으며 끊는다. XML은 ROME(`allowDoctypes=false`, XXE 차단)로, HTML은 OWASP HTML Sanitizer의 이벤트 파서(001 `MarkdownRenderer`가 이미 쓰는 방식)로 읽어 **새 라이브러리 없이** 피드 찾기·인증 코드 찾기·요약 텍스트 추출을 한다.
- **본문을 저장하지 않는다**: 피드 본문은 메모리에서 태그를 지운 텍스트 200자 요약과 첫 이미지 주소 계산에만 쓰고 버린다(SC-021). 요약·제목은 일반 텍스트로만 저장하고 front는 이스케이프 출력만 한다(HTML 렌더링 없음).
- **썸네일**: 핫링크하지 않는다(001 R27 CSP `img-src 'self'`, 방문자 IP 노출, 혼합 콘텐츠). **소유 인증된 블로그의 글만** backend가 이미지를 받아(5MB, 픽셀 상한) 600x400 한 크기로 줄여 `thumbnail-dir/external/`에 저장하고 `/media/external/{key}`로 제공한다. 인증 없는 블로그는 이미지 주소만 보관하고 받지 않는다(FR-128).
- **수집**: research E1 그대로(`@Scheduled` 1분마다 차례인 피드 선택 → `feedFetchExecutor` 4스레드, 조건부 요청, 실패 시 30분→12시간 지연, 7일 연속 실패면 STOPPED + 알림). 같은 글은 `guid_hash` → `link_hash` 순으로 찾아 갱신한다.
- **분류**: `TopicClassifier` 인터페이스(교체 가능, FR-119) + 1.0 구현 `KeywordTopicClassifier`(주제 slug별 키워드 사전 파일, 버전 `keyword-v1`). 외부 AI API와 직접 학습 모델은 쓰지 않는다(spec Assumptions (A)안).
- **포털**: 003의 내부 글 쿼리는 그대로 두고, 외부 글 쿼리를 따로 만들어 서비스 계층에서 (발행 시각, 출처, id) 순으로 합친다. 블로그당 2편 제한(003 `PerBlogCap`)은 키를 `P:{blogId}`·`E:{externalBlogId}`로 나눠 함께 적용하고, 인기 점수는 외부 글 최근 7일 클릭 × `external.score-weight` × 003의 시간 감쇠로 같은 스냅숏에 넣는다. 카드에 `source` 필드를 더하고 `?source=all|internal|external` 필터를 둔다(FR-124).
- **새 테이블·컬럼 없음, 필수 DDL 없음**(아래 "스키마 변경"에 marco 승인이 필요한 선택 인덱스 제안 1개). **새 라이브러리 없음.**

세부 근거는 [research.md](./research.md).

## Technical Context

**Language/Version**: backend Java 21 / front TypeScript 5.9, Node.js 22 LTS (001~006과 같음)

**Primary Dependencies**:
- backend(001~006 그대로): Spring Boot 4.1.1(Web MVC, Security, Data JPA, Validation, Mail), QueryDSL OpenFeign 7.x, Hibernate 7, Caffeine, commonmark-java + OWASP HTML Sanitizer, **ROME**(002가 이미 넣음, 피드 읽기에도 씀), **Thumbnailator + TwelveMonkeys imageio-webp**(001), springdoc-openapi. **새 의존성 없음**: 외부 요청은 JDK `java.net.http.HttpClient`, HTML 읽기는 OWASP `HtmlSanitizer.sanitize(html, Policy)` 이벤트 수신기, Media RSS(`media:thumbnail`)는 `rome-modules` 없이 ROME `getForeignMarkup()`, 정규화는 `java.text.Normalizer`
- front(001~006 그대로): React 19, React Router 8.4 framework 모드, Vite 8, Express 5, i18next + react-i18next. **새 npm 의존성 없음**. E2E 피드 스텁 서버는 Node 내장 `node:http`

**Storage**: MySQL 8(InnoDB, utf8mb4). 007 테이블(`external_blogs`, `external_blog_verifications`, `external_posts`, `external_post_daily_clicks`, `topic_mapping_rules`, `classification_reviews`)과 003 `portal_exclusions.external_post_id`(+ `ck_portal_exclusions_target`), 생성 컬럼 `external_blogs.active_feed_hash` + UNIQUE, 인덱스 13개, 외래 키 15개, 002 `notifications`의 `EXTERNAL_*` 값, 005 `reports.target_type`의 `EXTERNAL_POST`·`EXTERNAL_BLOG`, 003 `system_settings`(키만 추가)가 Crowfoot 문서 "blog 1.0"(`db/schema-mysql.sql`)에 이미 있다. 썸네일 파일은 001 `blog.media.thumbnail-dir` 아래 `external/`(다시 만들 수 있어 백업 제외)

**Testing**: 001~006과 같음. JUnit 5, `@WebMvcTest` + `WebMvcTestSupport`, Mockito, `@JpaRepositoryTest`(H2) + `QueryCounter`, 시각 고정 `MutableClock`, Caffeine `Ticker`. 외부 HTTP는 JDK `com.sun.net.httpserver.HttpServer` 테스트 서버(005 `StubHttpServer`, 없으면 007이 만듦)와 주입한 `HostResolver` 가짜(내부망 판정), **실제 인터넷 요청 0건**. `@SpringBootTest`(H2)는 등록→승인→수집→포털 노출 왕복 1개와 006 관리자 API 행렬(SC-015·SC-017)만. 생성 컬럼 UNIQUE(`active_feed_hash`, FR-112)는 MySQL 전용 동작이라 **MySQL 전용 테스트 1개**(`@MySqlRepositoryTest`, 환경 변수가 있을 때만, 002 방식), H2에서는 엔티티 `@Formula`가 아닌 서비스 사전 검사로 같은 규칙을 시험한다. **Testcontainers 없음**. JaCoCo 라인 80%. front Vitest(80%) + Playwright E2E(실제 backend + **로컬 피드 스텁 서버**, `requireBackend()`·`requireAdmin()`·`requireExternalTestSettings()`) — CI `e2e-backend` 잡과 nightly에 환경 변수를 더해 **실제로 돈다**(결정 표 33번)

**Target Platform**: Linux 서버 1대(backend 1대 전제, 001 R26 — 수집 스케줄러의 "고른 피드 임대", 클릭 중복 제거, 미리보기·인증 확인 속도 제한이 이 전제에 기댄다), 최신 데스크톱/모바일 브라우저(폭 360px부터)

**Project Type**: 웹 서비스(REST API + SSR 웹 앱), 저장소 3개

**Performance Goals**: 피드 하나 수집은 DB 쿼리 4회 이하 + 새 글당 쓰기 1~2회(기존 글은 guid·link 해시 IN 조회 1회로 한꺼번에 찾음). 포털 메인 계산은 003 대비 쿼리 +3회 이하(외부 최신·외부 인기 후보·외부 일별 클릭), 외부 카드 수와 무관. 주제 페이지 최신순은 두 출처 가벼운 행(id·발행 시각) 조회 2회 + 카드 조회 2회. 클릭 이동은 쿼리 2회(글 확인, 집계 upsert). 수집 주기 30분 기준 새 글이 1시간 안에 포털에 나옴(SC-018)

**Constraints**: 외부 글 본문 저장·노출 0건(SC-021), 내부망·서비스 자신 주소로의 서버 요청 0건(FR-116, Edge Cases), 피드 요약·제목의 HTML 실행 0건, 인증 없는 블로그 글의 썸네일 노출 0건(FR-128), 해제(글 삭제 선택)·차단·삭제 요청 처리·탈퇴 후 5분 안 포털에서 사라짐(SC-020, 실제로는 커밋 직후 포털 캐시 무효화), 글을 남기고 해제한 블로그의 해제 뒤 새 글 포털 노출 0건, 외부 글이 검색·RSS·사이트맵에 0건(FR-125), 관리자 API 비관리자 404(006 FR-097), 관리자 변경 작업 기록 누락 0건(006 SC-017), 커버리지 80%, 번역 누락 0건, N+1 금지, E2E에서 인터넷 요청 0건

**Scale/Scope**: 새 회원 API 11개(미리보기, 인증 코드 발급·확인, 내 외부 블로그 목록·신청·조회·기본 주제 변경·넘겨받기·해제, 수집된 글 목록·글 주제 변경), 공개 API 1개(클릭 이동), 새 관리자 API 21개(외부 블로그 목록·직접 등록·조회·기본 주제 변경·승인·거절·일시 중지·재개·차단, 수집된 글 목록, 외부 글 내림, 외부 글 포털 제외·해제, 검수 목록·확정·일괄 확정, 분류 현황, 매핑 규칙 목록·추가·수정·삭제), 운영 설정 키 3개, 003 API 확장 3곳(`PortalCard.source`·`visitUrl`·`externalBlog`, `/portal/latest`·`/topics/{slug}/posts`의 `source` 필터), 005 신고 대상 2종 처리기, 002 알림 종류 3개. 새 화면 10개(블로그 관리 외부 블로그 목록·신청·상세, 콘솔 외부 블로그 목록·직접 등록·상세·검수·분류 현황·매핑 규칙·설정), 001~006 화면 변경 6곳(포털 카드·최신 글·주제 페이지 필터, 알림 문구, 신고 레이어·권리 침해 양식의 외부 대상, 콘솔·블로그 관리 메뉴 켜기, `/manage/external-blogs` 진입)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| 원칙 | 확인 | 결과 |
|---|---|---|
| I. 스펙이 먼저다 | spec.md 확정(NEEDS CLARIFICATION 0개, checklist 통과). 이 plan은 FR-109~129, FR-157, SC-018~021을 다룬다. 스펙이 계획 단계로 미룬 것(썸네일 저장 방식, 자동 분류 방식)과 모호한 점(해제 시 "글 유지"의 포털 노출, 미인증 신청자의 권한, 검수 대상 범위)은 tasks.md "구현 전 결정 사항"에 기본값으로 기록(marco "묻지 말고 진행"). 해제 시 "글 유지"는 marco가 2026-10-07에 "남기면 포털에 계속 노출"로 정했고(결정 표 24번) spec US4 AS1·FR-126·SC-020을 그에 맞게 고쳤다 | 통과 |
| II. 세 저장소, 두 실행 파트 | 수집·분류·썸네일은 backend 프로세스 안(`@Scheduled` + 전용 스레드 풀), 큐·워커·외부 AI 서비스 없음. front는 REST API만 호출. E2E 피드 스텁은 시험 도구일 뿐 실행 파트가 아님 | 통과 |
| III. 테스트 우선·커버리지 | 각 스토리의 테스트 작업이 구현보다 앞섬, 인수 시나리오마다 테스트(tasks.md). 외부 HTTP는 로컬 테스트 서버, 내부망 판정은 주입한 이름 해석기. H2 + 쿼리 수 확인, MySQL 전용은 생성 컬럼 UNIQUE 1개, Testcontainers 없음, 80% 게이트 유지. E2E는 CI에서 실제 backend와 로컬 피드 스텁으로 돈다 | 통과 |
| IV. 보안과 공개 범위 | SSRF: 모든 외부 요청이 `SafeHttpFetcher` 한 곳(매 리다이렉트마다 주소 검사, 크기·시간·횟수 제한), 미리보기·인증 확인은 로그인 회원만 + 속도 제한. XXE: ROME `allowDoctypes=false`. XSS: 외부 제목·요약은 태그를 지운 일반 텍스트로만 저장·출력, 링크는 http/https만 저장. 클릭 이동은 저장된 원문 주소로만(열린 리다이렉트 없음). 관리 권한: 회원 API는 `member_id` 본인만(아니면 404), 글 주제·기본 주제 변경은 소유 인증된 주인만(403). 외부 글은 001 노출 매트릭스 대상이 아니며 포털에만(FR-125) | 통과 |
| V. SSR | 신청·인증·관리 화면 모두 SSR + `action` 폼(JS 없이 동작). 포털 카드의 원문 이동은 일반 링크(`/api/v1/external-posts/{id}/visit`, 새 탭). 외부 글은 포털 HTML에 제목·요약으로 렌더링 | 통과 |
| VI. 단순함 | 새 라이브러리 없음. 새 정기 작업 3개(수집 선택, 원문 링크 점검, 만료 인증 코드·고아 썸네일 정리)와 인터페이스 1개(`TopicClassifier`, FR-119 "교체 가능")만 추가(Complexity Tracking). 분산 잠금·큐 없음 | 통과 |
| VII. 다국어 우선 | 새 문구는 새 namespace `external`(회원·콘솔 화면)과 `portal`·`notification`·`errors`·`admin`·`manage`에 4개 언어로. 외부 글 제목·요약·블로그 이름은 번역하지 않음. 분류 키워드 사전은 4개 언어 낱말을 함께 둠. 새 오류 코드 15개 번역 | 통과 |
| 기술 제약 | Java 21, Spring Boot 4.1.1, JPA + QueryDSL(OpenFeign), N+1 금지, Crowfoot 스키마(필수 DDL 없음, 선택 제안은 승인 절차), 공통 응답 틀(실제 HTTP 상태, 문자열 `resultCode`, 페이지는 `totalCount`), 운영 설정은 `blog.*` 프로퍼티 + `system_settings` `external.*` | 통과 |

**Phase 1 이후 재확인**: research, contracts(api.md, routes.md), quickstart, tasks 작성 후 원칙 I~VII을 다시 점검했고 위반 없음. 설계 규칙과 다르게 만든 곳(부수 효과가 있는 `GET /external-posts/{id}/visit`, 상태 전이 동작을 `POST …/approve` 같은 하위 자원으로 둔 것, 003 `PortalCard`의 `author`를 외부 글에서 null로)은 contracts/api.md에 이유를 적었다.

## 스키마 변경

**필수 DDL은 없다.** 007 data-model의 테이블·컬럼·생성 컬럼·인덱스·외래 키와 003 `portal_exclusions` 변경이 모두 `db/schema-mysql.sql`(Crowfoot 문서 "blog 1.0", `migrations/0001-baseline.sql`)에 있다. 007 쿼리·쓰기를 하나씩 대조했다.

| 쿼리·쓰기 | 쓰는 테이블·컬럼·인덱스·제약 | 비고 |
|---|---|---|
| 수집할 차례인 피드 고르기 | `idx_external_blogs_status_next_fetch` (status, next_fetch_at) | `status='ACTIVE' AND next_fetch_at <= now LIMIT 50`, 고른 행은 `next_fetch_at`을 임대 시각으로 미룸(research E1·E5) |
| 같은 피드 중복 등록 막기 | `uk_external_blogs_active_feed_hash`(생성 컬럼 UNIQUE), 사전 조회는 `idx_external_blogs_feed_url_hash` | 거절·해제된 등록은 생성 컬럼이 NULL이라 다시 신청 가능 |
| 해제할 때 글 남기기·삭제 선택(결정 표 24번) | `external_blogs.status`(RELEASED), `external_posts` 행 존재·`status` | 선택을 저장하는 컬럼이 필요 없다. 남기면 RELEASED 등록에 `ACTIVE` 글 행이 남고, 삭제하면 행이 없다. 탈퇴로 해제된 등록의 글은 `REMOVED`(`MEMBER_WITHDRAWN`)라 노출 조건에 블로그 상태 RELEASED만 더하면 된다 |
| 다시 등록 때 남긴 글 이어받기 | `idx_external_blogs_feed_url_hash`로 같은 피드의 RELEASED 등록 찾기 → `idx_external_posts_blog_published` 앞 컬럼 `external_blog_id`로 `UPDATE external_posts SET external_blog_id = ?` | 새 등록은 첫 수집 전이라 `uk_external_posts_blog_guid_hash`·`uk_external_posts_blog_link_hash`와 충돌 없음 |
| 해제 등록의 내린 글 정리(30일) | `external_posts.updated_at` + `idx_external_posts_blog_published`(RELEASED 등록 id 목록으로) | 정리 작업 하루 1회, 인덱스 추가 없음 |
| 회원별 3개 한도 | `users` PK `FOR UPDATE` + `idx_external_blogs_member_status` (member_id, status) | 001 R28 방식 |
| 회원의 외부 블로그 목록 | `idx_external_blogs_member_status` | |
| 관리자 목록(상태별, 신청 대기 먼저) | `idx_external_blogs_status_next_fetch` 앞 컬럼 `status` + `created_at` 정렬 | 상태별 행 수가 작아 정렬 비용 작음. 검색어는 제목·피드 주소 `LIKE`(관리자 화면, 1.0 규모) |
| 인증 코드 발급·찾기 | `uk_external_blog_verifications_code`, `idx_external_blog_verifications_user_feed_created` | |
| 만료 인증 코드 정리 | `external_blog_verifications.expires_at` | 인덱스 없음. 표가 작아(회원당 하루 몇 건) 매일 1회 전체 훑기 허용 |
| 수집한 글 같은 글 찾기 | `uk_external_posts_blog_guid_hash`, `uk_external_posts_blog_link_hash` | 피드 한 번에 `IN` 2회 |
| 포털 최신(외부) | `idx_external_posts_status_published` (status, published_at DESC) + `external_blogs` PK JOIN(상태) + `uk_portal_exclusions_external_post` LEFT JOIN | |
| 주제 페이지 최신(외부) | `idx_external_posts_topic_status_published` (topic_id, status, published_at DESC) | |
| 주제 자동 숨김 글 수에 외부 글 합산 | `idx_external_posts_status_published` + `topic_id` GROUP BY | 003 FR-147 |
| 외부 인기 점수 | `external_post_daily_clicks` PK (external_post_id, click_date) 범위 + `external_posts` PK | 최근 7일 |
| 클릭 집계 | `external_posts.click_count + 1`, `external_post_daily_clicks` upsert(`INSERT … ON DUPLICATE KEY UPDATE`) | H2는 MySQL 모드 `MERGE`(시험은 리포지토리 계층 하나로) |
| 회원의 수집된 글 목록 | `idx_external_posts_blog_published` (external_blog_id, published_at DESC) | |
| 원문 링크 점검(주 1회) | `idx_external_posts_status_link_checked` (status, link_checked_at) | `link_checked_at IS NULL` 먼저 |
| 매핑 규칙 일치 | `uk_topic_mapping_rules_keyword` | 규칙 전체를 피드 한 번에 1회 읽음(수백 행 이하) |
| 검수 목록 | `idx_classification_reviews_status_created` (status, created_at) | |
| 분류 정확도(최근 30일 사람이 확인) | `external_posts.topic_decided_at`, `classifier_topic_id` | **인덱스 없음 → 아래 선택 제안 1**(없으면 화면을 열 때마다 `external_posts` 전체 훑기, 5분 캐시) |
| 주제별 분포·검수 대기 수 | `idx_external_posts_topic_status_published`, `idx_classification_reviews_status_created` | |
| 외부 글 포털 제외 | `portal_exclusions.external_post_id` UNIQUE, `ck_portal_exclusions_target` | 003 엔티티의 `post_id` 매핑을 NULL 허용으로, `externalPost` 매핑 추가 |
| 신고 대상·조치 | `reports.target_type` `EXTERNAL_POST`·`EXTERNAL_BLOG`, `action` `REMOVE_FROM_PORTAL`·`BLOCK_EXTERNAL_BLOG` | 005 테이블, 값만 사용 |
| 알림 | `notifications.type` `EXTERNAL_BLOG_APPROVED`·`EXTERNAL_BLOG_REJECTED`·`EXTERNAL_FEED_STOPPED`, `target_type` `EXTERNAL_BLOG` | 002 테이블, 값만 사용 |
| 작업 기록 | `admin_audit_logs` | 006 data-model의 `EXTERNAL_*`·`TOPIC_MAPPING_RULE_*`·`CLASSIFICATION_CONFIRM` 값 + 007이 더하는 `EXTERNAL_BLOG_UPDATE`(VARCHAR(50), 스키마 변경 아님) |
| 운영 설정 | `system_settings` 키 `external.fetch-interval`·`external.auto-classify-min-confidence`·`external.score-weight` | 행만 추가(값이 없으면 프로퍼티 기본값) |
| 썸네일 키 | `external_posts.thumbnail_key` CHAR(22) | 001 `MediaKeyGenerator`와 같은 base62 22자 |

엔티티는 새로 만든다(`ExternalBlog`, `ExternalBlogVerification`, `ExternalPost`, `ExternalPostDailyClick`, `TopicMappingRule`, `ClassificationReview`). 생성 컬럼 `active_feed_hash`는 `@Column(insertable = false, updatable = false)`로 읽기만 한다(H2 스키마는 엔티티로 만들므로 H2에서는 일반 컬럼 + 서비스 사전 검사, MySQL UNIQUE는 `@MySqlRepositoryTest`로 확인). 003 `PortalExclusion`의 `post` 매핑은 `nullable = true`로 바꾸고 `externalPost`를 더하며, CHECK는 엔티티 `@Check`로 H2에도 둔다. `EntitySchemaValidationTest`가 실제 스키마와 엔티티 매핑이 맞는지 확인한다.

`external_posts.removed_reason`(LINK_BROKEN / BLOG_BLOCKED / MEMBER_WITHDRAWN / REPORT / ADMIN)과 `external_blogs.last_fetch_result`의 값은 data-model 그대로 쓴다. 리다이렉트 초과는 `HTTP_ERROR`, 이미지 실패는 수집 결과에 영향 없음(research E3)으로 정해 새 값을 만들지 않았다.

### marco 승인이 필요한 선택 DDL 제안 (지금 구현은 이것 없이 동작)

아래 인덱스는 1.0 규모(외부 블로그 수백, 외부 글 수만)에서는 없어도 된다. 분류 현황 화면(FR-122)은 관리자만 열고 결과를 5분 캐시하므로 5분에 한 번 `external_posts`를 훑는다. 외부 글이 수십만 건이 되면 필요하다. 넣기로 하면 [db/README.md](../../db/README.md) 절차(data-model·erd.md → Crowfoot 문서 → **Crowfoot `plan_migration` → marco 승인** → `apply_migration` → `migrations/NNNN-*.sql` → `schema-mysql.sql`·backend 테스트 스냅숏)를 따른다. 이 계획 단계에서는 Crowfoot 문서와 DB를 바꾸지 않았다(결정 표 35번).

```sql
-- 제안 1: 분류 현황의 "최근 30일 사람이 확인한 글 기준 자동 분류 정확도" (007 FR-122, SC-019)
--   쿼리: SELECT COUNT(*), SUM(classifier_topic_id = topic_id) FROM external_posts
--         WHERE topic_decided_at >= :since AND classifier_topic_id IS NOT NULL
CREATE INDEX idx_external_posts_topic_decided ON external_posts (topic_decided_at ASC);
```

승인되지 않아도 기능은 같다(5분 캐시 안에서 전체 훑기). 승인되면 코드 변경 없이 인덱스만 쓰인다.

**데이터 보정 없음.** 운영 설정 키 3개는 행이 없으면 프로퍼티 기본값이고, 분류 키워드 사전은 코드 리소스 파일이다(테이블 없음, 003 `TopicSeeder`가 넣은 주제 slug를 참조).

## Project Structure

### Documentation (this feature)

```text
specs/007-external-feeds/
├── spec.md              # 기능 스펙
├── plan.md              # 이 문서
├── research.md          # Phase 0: 현재 코드 대조와 기술 결정 (E1~E18)
├── data-model.md        # Phase 1: 테이블 (스펙 단계에서 작성, plan에서 확정한 값만 보탬)
├── quickstart.md        # Phase 1: 실행·수동 검증 시나리오
├── contracts/
│   ├── api.md           # 007 REST API 계약(회원·공개·관리자 API, 003 API 확장, 오류 코드, 프로퍼티)
│   └── routes.md        # 007 화면과 001~006 화면 변경
├── checklists/requirements.md
└── tasks.md             # Phase 2: 작업 목록과 구현 전 결정 사항
```

### Source Code

001~006 구조에 아래를 더한다. 패키지 안 구성은 001과 같이 `controller`, `service`, `repository`, `domain`, `dto`, `job`. 외부 블로그는 등록·수집·분류·포털 연결이 한 기능이라 `external` 한 패키지 아래 하위 패키지로 나누고, 관리자 API는 003의 `admin/*` 아래 `admin/external`에 둔다.

```text
blog-backend/src/main/java/net/java21/blog/backend/
├── common/net/                 # (005) OutboundUrlGuard·HostResolver·OutboundProperties — 005가 먼저 머지되지 않았으면 007이 만듦
│   ├── SafeHttpFetcher.java    #   (새) JDK HttpClient 감싸기: 수동 리다이렉트(3회, 매번 검사), 연결 5초·전체 10초, 크기 제한, 조건부 요청
│   └── FetchResult.java        #   (새) 상태·본문 바이트·ETag·Last-Modified·최종 주소·실패 종류(FetchFailure)
├── config/ExternalFeedProperties.java   # (001) + pollInterval·fetchInterval·fetchJitter·leaseTime·maxFeedSize·maxPageSize·
│                                        #   maxImageSize·initialWindow·maxItemsPerFetch·stopAfter·maxBackoff·linkCheckCron·
│                                        #   cleanupCron·previewPerHour·verifyChecksPerHour·forbiddenHosts·userAgent
├── external/
│   ├── domain/                 # ExternalBlog(상태 전이 메서드)·ExternalBlogStatus·RegistrationType·FetchResultCode·
│   │                           #   ExternalBlogVerification·ExternalPost·ExternalPostStatus·RemovedReason·TopicSource·
│   │                           #   ExternalPostDailyClick(+Id)·TopicMappingRule·ClassificationReview·ReviewStatus
│   ├── feed/                   # FeedUrlNormalizer(정규화·SHA-256), FeedDiscovery(HTML <link rel=alternate>, /rss·/feed 추가 시도),
│   │                           #   FeedParser(ROME, XXE 끔) → ParsedFeed/FeedItem, HtmlScanner(OWASP 이벤트 파서: 링크·이미지·텍스트),
│   │                           #   SummaryExtractor(태그 제거 200자), ItemImagePicker(enclosure → media:* → 첫 <img>)
│   ├── fetch/                  # FeedFetchScheduler(@Scheduled 선택·임대·제출), FeedCollector(가져오기→파싱→저장 한 피드),
│   │                           #   ExternalPostUpserter(같은 글 판별·갱신), FetchBackoff(지연 계산), FeedStopNotifier
│   ├── classify/               # TopicClassifier(인터페이스)·ClassificationResult·KeywordTopicClassifier·KeywordDictionary
│   │                           #   (resources/external/topic-keywords.yml), MappingRuleMatcher, TopicDecider(FR-118 순서)
│   ├── thumbnail/              # ExternalThumbnailService(받기·검사·600x400 생성·삭제), ExternalThumbnailController(/media/external/{key})
│   ├── verify/                 # VerificationService(코드 발급·확인), VerificationCodeGenerator
│   ├── portal/                 # ExternalPortalQueryRepository(최신·주제·후보·글 수), ExternalPopularity(클릭 × 가중치 × 감쇠),
│   │                           #   PortalMerge(두 출처 합치기·커서), ExternalVisitController·ExternalClickService(중복 제거, upsert)
│   ├── report/                 # ExternalPostReportHandler·ExternalBlogReportHandler (005 ReportTargetHandler 구현)
│   ├── member/                 # MemberExternalBlogController·Service(신청·조회·기본 주제·해제·넘겨받기·글 주제), PreviewService
│   ├── job/                    # LinkCheckJob(주 1회 원문 점검), ExternalCleanupJob(만료 인증 코드·고아 썸네일·해제 등록에서 내린 지 30일 지난 글)
│   ├── event/                  # MemberWithdrawnListener(FR-157), ExternalPortalChanged(커밋 후 포털 캐시 무효화)
│   ├── repository/             # 엔티티별 Spring Data + QueryDSL 조회 리포지토리
│   └── dto/
├── admin/external/             # (새) AdminExternalBlogController·Service(목록·직접 등록·승인·거절·중지·재개·차단·기본 주제),
│                               #   AdminExternalPostController(내림·포털 제외), AdminClassificationController(검수·현황),
│                               #   AdminMappingRuleController·Service, dto
├── admin/audit/AuditActions.java          # (003·006) + EXTERNAL_* 8개, TOPIC_MAPPING_RULE_* 3개, CLASSIFICATION_CONFIRM, 대상 4종
├── portal/service/PortalService.java       # (003) 최신·인기 합치기, PerBlogCap 키 확장, source 필터
├── portal/service/TopicPostService.java    # (003) 주제 페이지 두 출처 합치기, source 필터
├── portal/service/PopularityCalculator.java # (003) 외부 점수를 같은 스냅숏에(Entry.source)
├── portal/repository/TopicPostCountQueryRepository.java  # (003) 외부 글 수 합산(FR-147)
├── portal/domain/PortalExclusion.java      # (003) post NULL 허용 + externalPost, @Check
├── portal/dto/PortalCardResponse.java      # (003) + source·visitUrl·externalBlog, author NULL 허용
├── setting/SettingKey.java                 # (003) + EXTERNAL_FETCH_INTERVAL·EXTERNAL_AUTO_CLASSIFY_MIN_CONFIDENCE·EXTERNAL_SCORE_WEIGHT
├── notification/domain/NotificationType.java, NotificationTargetType.java  # (002) + EXTERNAL_* 3개, EXTERNAL_BLOG
├── user/service/AccountService.java        # (001) 탈퇴 시 MemberWithdrawnEvent 발행
└── common/error/ErrorCode.java             # (001) + 007 오류 코드 15개
blog-backend/src/main/resources/application.yml           # blog.external.* 기본값
blog-backend/src/main/resources/external/topic-keywords.yml  # 주제 slug별 키워드(4개 언어 + 기술 용어)
blog-backend/src/main/resources/messages_*.properties      # (메일 없음 — 알림만, 변경 없음)

blog-front/app/
├── api/models.ts                          # 007 타입, PortalCard 확장
├── external/                              # (새) status.ts(상태 이름·배지), sourceFilter.ts(?source= 읽기·쓰기), visit.ts(카드 링크)
├── components/portal/PortalCard.tsx       # (003) 외부 카드: "외부" 배지, 블로그 이름·사이트 호스트, 새 탭 링크, "삭제 요청"
├── components/portal/SourceFilter.tsx     # (새) 전체·내부 글만·외부 글만
├── components/external/                   # (새) FeedPreview, VerificationPanel, ExternalBlogStatusBadge, ExternalPostTable,
│                                          #   TopicSelect(003 주제 트리 재사용), ReleaseForm, ReviewTable, ClassificationStats, RuleForm
├── routes/manage/external-blogs.tsx, external-blog-new.tsx, external-blog.tsx   # 블로그 관리 "외부 블로그"
├── routes/manage-external-entry.ts        # /manage/external-blogs(/:id) → 최근 블로그의 같은 화면(알림 링크)
├── routes/admin/external-blogs.tsx, external-blog-new.tsx, external-blog.tsx,
│   external-reviews.tsx, external-stats.tsx, external-rules.tsx, external-settings.tsx
├── routes/home.tsx, topic.tsx             # (003) source 필터, 외부 카드
├── admin/links.ts, manage/links.ts        # (006) "외부 블로그 관리"·"외부 블로그" available: true
└── locales/{ko,en,ja,zh-CN}/external.json # (새) + portal·notification·errors·admin·manage 키
blog-front/tests/e2e/support/feed-stub-server.mjs  # (새) 로컬 피드 스텁(node:http): 피드·이미지·글 페이지, 시험이 내용을 바꾸는 /__stub API
blog-front/tests/e2e/support/feedStub.ts          # (새) 스텁 조작 도구
blog-front/playwright.config.ts                   # webServer에 스텁 서버, `external` 프로젝트
blog-front/.github/workflows/ci.yml, e2e.yml       # backend 환경 변수(BLOG_OUTBOUND_*, BLOG_EXTERNAL_*), E2E_EXTERNAL_TEST_SETTINGS
```

**Structure Decision**: 001의 도메인별 패키지 구조를 따른다. 외부 블로그는 등록·수집·분류·썸네일·포털 연결이 서로 강하게 묶여 있어 `external` 한 도메인 아래 역할별 하위 패키지로 나눈다(005가 `report`·`spam`·`trackback`을 나눈 것과 달리 007은 테이블 6개가 한 흐름이다). 포털 합치기는 003 `portal` 서비스가 `external/portal`의 쿼리를 부르는 방향으로 두어, `external`을 지워도 `portal`은 "외부 글 없음"으로 동작하도록 `ExternalPortalSource` 인터페이스 하나로 잇는다(빈이 없으면 빈 목록, 003 `BlogPenaltyPolicy` 방식). 외부 요청 도구는 005 트랙백과 함께 쓰므로 `common/net`에 둔다.

## 구현 순서 (사용자 스토리 기준)

spec의 스토리 번호와 우선순위를 그대로 쓴다(결정 표 1번).

| 단계 | 스토리 | 핵심 산출물 | FR |
|---|---|---|---|
| 0 | 기반 | 프로퍼티·설정 키·오류 코드·작업 종류·알림 종류, 엔티티 6개와 `PortalExclusion` 매핑 변경, `SafeHttpFetcher`(+005 `OutboundUrlGuard`), 피드 주소 정규화·피드 읽기·HTML 읽기·요약 추출, front 번역·모델 타입·E2E 피드 스텁·CI 환경 | FR-114, FR-115(정규화), FR-116(SSRF), SC-021 |
| 1 | US1 등록과 인증 (P1) 🎯 MVP | 미리보기, 인증 코드 발급·확인, 회원 신청(3개 한도·중복 거부), 운영자 승인·거절·직접 등록, 넘겨받기, 수집 스케줄러·수집기(기본 주제로 저장), 블로그 관리·콘솔 화면 | FR-109~113, FR-116, FR-128(썸네일 받기 조건), FR-129(넘겨받기) |
| 2 | US2 포털 노출 (P2) | 포털 최신·주제 페이지·인기에 외부 글 합치기, 카드 "외부" 표시·새 탭 이동·클릭 집계, `source` 필터, 주제 자동 숨김 합산, 매핑 규칙·자동 분류·기본 주제 순 결정, 썸네일 제공, 원문 링크 점검, 검색·RSS·사이트맵 제외 확인 | FR-114, FR-117(링크 점검), FR-118, FR-119, FR-123~125, FR-128, SC-018, SC-021 |
| 3 | US3 분류 개선과 검수 (P3) | 주인의 글 주제 변경, 검수 목록·확정·일괄 확정, 분류 현황(정확도·분포·대기 수), 매핑 규칙 관리 | FR-119~122, SC-019 |
| 4 | US4 해제와 운영 (P4) | 해제(글 남기기·삭제 선택, 남긴 글 나중 삭제), 일시 중지·재개·차단, 외부 글 내림·포털 제외, 신고 처리기 2종(005), 7일 연속 실패 자동 중지·알림, 탈퇴 연동 | FR-117, FR-126, FR-127, FR-129(삭제 요청), FR-157, SC-020 |

각 단계는 끝날 때 해당 스토리의 Independent Test를 E2E로 통과해야 한다. US1의 Independent Test 마지막 문장("포털에 글이 나오는지 확인")은 US2가 끝나야 확인되므로, US1 체크포인트는 "수집된 글이 회원·관리자 화면의 수집된 글 목록에 나옴"까지, 포털 확인은 US2 체크포인트에서 한다(결정 표 1번). 같은 파일(`ErrorCode`, `AuditActions`, `SettingKey`, `NotificationType`, `PortalService`, `TopicPostService`, `PopularityCalculator`, `PortalCardResponse`, `models.ts`, `PortalCard.tsx`, `routes.ts`, `admin/links.ts`, `manage/links.ts`, `errors.json`, `playwright.config.ts`, `tests/e2e/support/backend.ts`, 두 workflow)을 고치는 작업은 순서대로 머지한다.

**004·005·006 진행 중 작업과의 관계**:
- 004 Phase 5~8은 `feat/004-rest`에서 구현 중이다. 007은 004 화면을 고치지 않지만 블로그 관리 메뉴(006이 `manage/links.ts`로 옮김)와 E2E 프로젝트 순서를 공유하므로 **004가 main에 머지된 뒤 시작한다**(005·006과 같은 조건).
- 005·006은 계획만 있다. 007은 둘과 **병렬로 진행할 수 있다**. 기대는 것과 처리:
  - 005 `OutboundUrlGuard`·`HostResolver`·`OutboundProperties`·`StubHttpServer`(SSRF 차단, 시험 서버): **먼저 머지하는 쪽이 만들고 다른 쪽은 재사용**(결정 표 4번, 중복 정의 금지).
  - 005 `ReportTargetHandler`·조치 `REMOVE_FROM_PORTAL`·`BLOCK_EXTERNAL_BLOG`, 신고 레이어, `/rights-request`: 007의 신고 처리기·카드 "삭제 요청"은 **"(005 머지 후)"**. 그 전에는 카드의 "삭제 요청"이 `mailto`가 아니라 숨김이고, 운영자는 콘솔 "내림"으로 처리한다.
  - 006 `admin/links.ts`·`manage/links.ts`의 메뉴 정의와 행렬 테스트(SC-015 `AdminEndpointAccessMatrixTest`, SC-017 `AdminAuditCoverageIntegrationTest`, AS5 `ManageEndpointAccessMatrixTest`): 메뉴 켜기와 행렬 표 행 추가는 **"(006 머지 후)"**. 006 전에는 003 `admin/links.ts`의 `ADMIN_MENU`에 항목을 더하고 001 `routes/manage/layout.tsx`의 `MANAGE_MENU`에 항목을 더한다(006이 옮길 때 함께 옮김).
- 자세한 대응은 tasks.md "004·005·006·003 의존" 표.

**범위 밖(spec과 다른 스펙)**:
- spec Assumptions: 핑백·WebSub(실시간 구독), 직접 학습한 분류 모델(사람이 확정한 데이터가 쌓이기 전), 외부 글 댓글·좋아요.
- 이 계획에서 1.0에 넣지 않는 것(결정 표): 외부 AI API 분류, JSON Feed·RDF 이외 형식, 외부 블로그 공개 소개 화면, 포털 추천(큐레이션)에 외부 글 넣기, 인기 태그에 피드 태그 섞기, 넘겨받을 때 이전 회원 알림, 서버 2대 이상의 분산 잠금(research E1 "나중에").
- 005: 신고 접수·처리 화면 자체, 권리 침해 양식. 007은 대상 종류 처리기와 카드 링크만.
- 006: 콘솔·블로그 관리 레이아웃과 메뉴 정의. 007은 자기 메뉴 항목을 켜기만.

## Complexity Tracking

| 도입 | 이유 | 더 단순한 대안을 쓰지 않은 이유 |
|---|---|---|
| `SafeHttpFetcher`(수동 리다이렉트·크기·시간 제한) | FR-116 내부망 차단, Edge Cases "서버 자신·내부망 거부", 사용자 지시 "크기·시간·리다이렉트 제한". 피드·HTML·이미지·링크 점검 4곳이 같은 규칙을 써야 함 | 곳마다 `HttpClient`를 직접 쓰면 리다이렉트 검사·크기 제한이 한 곳이라도 빠질 수 있다. 프록시 서버 경유는 실행 파트 추가(원칙 II) (research E2) |
| `TopicClassifier` 인터페이스 | FR-119 "분류 방식은 교체할 수 있어야 한다", `classifier_version` 컬럼 | 구현 하나뿐이지만 spec이 교체를 요구한다. 빈 하나 교체로 (B)·(C)안을 붙일 수 있게 한다 (research E9) |
| 정기 작업 3개(수집 선택 1분, 원문 링크 점검 주 1회, 정리 매일) | FR-113, FR-117, 인증 코드 24시간·고아 썸네일 | 수집은 research E1 결정 그대로. 링크 점검은 HEAD만, 정리는 001 정리 작업들과 같은 모양 (research E1·E12·E15) |
| 포털 두 출처 합치기(`PortalMerge`, 커서 확장) | FR-123 "내부 글과 섞여 나온다", 블로그당 2편 제한 공유 | UNION 쿼리는 JPA·QueryDSL로 쓸 수 없고 네이티브 SQL은 003 노출 조각(`PortalExposure`) 재사용을 깬다. 외부 글을 `posts`에 넣는 것은 001 노출 매트릭스·검색·RSS를 모두 오염시킨다(FR-125) (research E13) |
| 키워드 사전 리소스 파일 | FR-119 자동 분류의 1.0 구현 | 테이블은 스키마 변경이 필요하고, 운영자가 바꾸는 규칙은 이미 매핑 규칙(FR-121)이 있다 (research E9) |
