# Research: 007 외부 블로그 피드

> 001의 결정(R1~R28: 인증, 프록시, SSR 구성, 노출 조각, 테스트 방식, 정기 작업, 보안 헤더, 다국어), 002(D1~D11), 003(P1~P14), 004(B1~B17), 005(M1~M18), 006(A1~A14)의 결정은 그대로 따른다. 모든 API 경로는 `/api/v1` 접두어를 쓴다.
>
> E1은 `/speckit-plan` 전에 먼저 정했고(001 구현 때 수집 전용 스레드 풀까지 만들어 둠), E2~E18은 계획 단계에서 더했다.

확인일: 2026-10-07 (blog-backend main `29c2308`, blog-front main `b3a0484` 기준. 001~003과 004 Phase 1~4는 main에 있다. 004 Phase 5~8은 `feat/004-rest`에서 구현 중이라 [004 tasks](../004-blog-features/tasks.md)를, 005·006은 계획만 있어 [005 plan](../005-trackback-moderation/plan.md)·[tasks](../005-trackback-moderation/tasks.md), [006 plan](../006-admin-consoles/plan.md)·[tasks](../006-admin-consoles/tasks.md)를 기준으로 읽었다)

## 현재 코드에서 확인한 것

**스키마**
- `db/schema-mysql.sql`에 007 테이블 6개(`external_blogs`, `external_blog_verifications`, `external_posts`, `external_post_daily_clicks`, `topic_mapping_rules`, `classification_reviews`), 생성 컬럼 `external_blogs.active_feed_hash` + `uk_external_blogs_active_feed_hash`, 인덱스 13개(`idx_external_*` 10개, `idx_classification_reviews_status_created` 등), 외래 키 15개(`external_post_daily_clicks`·`classification_reviews`는 `ON DELETE CASCADE`, `portal_exclusions.external_post_id`는 CASCADE 없음)가 모두 있다. 003 `portal_exclusions`는 이미 `post_id` NULL 허용 + `external_post_id` UNIQUE + `ck_portal_exclusions_target`. 002 `notifications.type`·005 `reports.target_type`·`action`의 007 값도 컬럼 설명에 있다(값은 VARCHAR라 코드 enum만 더하면 된다). → **필수 DDL 없음**(plan.md "스키마 변경" 대조표).

**backend**
- 수집 준비: `config/ExternalFeedProperties`(`blog.external.fetch-threads` 4, `batch-size` 50)와 `config/SchedulingConfig`의 `feedFetchExecutor`(core=max=4, 큐 50, 큐가 차면 `TaskRejectedException`, 종료 시 30초 대기)가 이미 있다(001이 E1을 미리 반영). `spring.task.scheduling.pool.size=3`, `spring.task.execution.mode=force`도 있다. `AsyncConfig.EXECUTOR`(메일)와 풀을 나눈다.
- 피드 라이브러리: ROME(`com.rometools:rome`)이 002 RSS·Atom 쓰기(`syndication/writer`)용으로 이미 의존성에 있다. `rome-modules`(Media RSS)는 없다.
- HTML 처리: OWASP HTML Sanitizer. `content/MarkdownRenderer`가 `HtmlSanitizer.sanitize(html, new HtmlSanitizer.Policy() { … })`로 태그 이벤트를 직접 받는다 → 같은 방식으로 HTML에서 `<link>`·`<img>`·텍스트를 읽을 수 있다(jsoup 없음).
- 썸네일: `media/thumbnail/ThumbnailService`(Thumbnailator, WebP 읽기 TwelveMonkeys, GIF 첫 장면, WebP→PNG 출력, `ThumbnailLocks`), `media/service/ImageInspector`(내용으로 형식 판별, 픽셀 상한 `maxPixels`), `MediaKeyGenerator`(base62 22자), `media/controller/MediaServeController`(`/media/{key}`, `/media/{key}/{size}`, `public, max-age=31536000, immutable`, `nosniff`). 썸네일 디렉터리는 `blog.media.thumbnail-dir`(`{key}/{w}x{h}-{fit}.{ext}`). `media` 행은 `owner_id NOT NULL`(회원 소유)이라 외부 이미지에는 쓰지 않는다.
- CSP: front가 `img-src 'self' data:`(001 R27)이고 R27에 "외부 블로그 썸네일(007)은 backend가 받아 `/media`로 제공"이라고 이미 적혀 있다.
- 포털: `portal/service/PortalService`(HOME·LATEST·POPULARITY 캐시, 최신은 `PortalCursor`(발행 시각+id)와 `PerBlogCap`(블로그당 2편, 키는 `blogId`)), `TopicPostService`(주제 페이지 `latest`·`popular`, offset 페이지), `PopularityCalculator`(조회·끝까지 읽음·좋아요·댓글 × 가중치 × `2^(-시간/반감기)` × 감점, `PopularitySnapshot.Entry(postId, blogId, topicId, publishedAt, score)`), `TopicPostCountQueryRepository`(주제 자동 숨김 글 수), `PortalCache`(Caffeine, 백그라운드 갱신), `PortalChangedEvent` → 커밋 후 `PortalCacheInvalidator`. `PortalCardResponse`는 내부 글 전제(`blog.handle`, `author` 필수). `PortalExclusion` 엔티티는 `post_id`를 `nullable=false`로 매핑하고 `external_post_id`를 매핑하지 않는다("007 컬럼은 매핑하지 않는다").
- 운영 설정: `setting/SettingKey` enum이 키마다 검증·기본값을 정한다("005·007이 키를 더한다"). 관리자 API `/admin/settings?prefix=`가 그대로 다룬다.
- 알림: `notification/domain/NotificationType`(`NEW_COMMENT`, `NEW_SUBSCRIBER`)·`NotificationTargetType`(`COMMENT`, `BLOG`). "007 EXTERNAL_*은 그 스펙이 더한다".
- 작업 기록: `admin/audit/AuditActions`(003 값만, "005~007이 더한다"), `AdminAuditService.record`(`Propagation.MANDATORY`).
- 탈퇴: `user/service/AccountService.withdraw`가 `user.withdraw(now)` + `withdrawalRepository.makeAllPostsPrivate(userId)`를 한 트랜잭션에서 한다. 이벤트는 발행하지 않는다.
- 서비스 주소: `config/SiteProperties.baseUrl`(`blog.base-url`, 기본 `https://blog.java21.net`, local 프로필은 `http://localhost:5173`).
- robots: `seo/controller/RobotsController`가 `Disallow: /api/`를 이미 낸다 → 클릭 이동 주소(`/api/v1/external-posts/{id}/visit`)를 크롤러가 따라가지 않는다.
- 검색(`search/PostSearchRepository`)·RSS(`syndication/FeedItemQueryRepository`)·사이트맵(`seo/SitemapQueryRepository`)은 모두 `posts`만 읽는다 → 외부 글은 구조적으로 빠진다(FR-125, 회귀 시험만).
- 방문자 식별: `common/web/VisitorKeyResolver`(회원 ID 또는 방문자 쿠키) — 조회수 중복 제거(001 R10)와 같은 도구로 클릭 중복을 막는다.

**005·006 계획에서 가져다 쓰는 것**(아직 코드 없음)
- 005 `common/net/OutboundUrlGuard`·`HostResolver`·`OutboundProperties`(`blog.outbound.allowed-ports` 80,443,8080,8443, `allow-private` 시험용·prod에서 true면 기동 실패), 시험 도구 `StubHttpServer`(JDK `HttpServer`) — research M16, 결정 표 26번 "007 피드 수집이 같은 도구를 씀".
- 005 `report/ReportTargetHandler`(대상 종류별 처리기 빈 목록, `EXTERNAL_POST`·`EXTERNAL_BLOG`은 처리기가 없으면 400) — research M4, 결정 표 5번.
- 006 콘솔 메뉴 "외부 블로그 관리"(`/admin/external-blogs`)와 블로그 관리 메뉴 "외부 블로그"(`/external-blogs`)는 숨김 자리(006 contracts/routes.md), 관리자 API 행렬 테스트(SC-015)·작업 기록 강제 표(SC-017)는 "007은 자기 API 행을 더한다".

**front**
- 포털 카드 `components/portal/PortalCard.tsx`: 카드 전체가 `/{handle}/{id}` 링크, 썸네일은 `media/thumbnail.ts`의 `thumbnailImage`(이 서비스 `/media/{key}`가 아니면 주소를 그대로 씀 → `/media/external/{key}`는 그대로 쓰임), 대표 이미지가 없으면 주제 카드 색.
- 포털 화면 `routes/home.tsx`(최신 글 "더 보기" `?cursor=`), `routes/topic.tsx`(`sort`, `page`).
- 콘솔 `routes/admin/*`(003, `admin/links.ts` 4항목), 블로그 관리 `routes/manage/*`(001·004, 메뉴는 레이아웃 파일 안). 006이 메뉴 정의를 `admin/links.ts`·`manage/links.ts`로 정리할 예정.
- E2E: `tests/e2e/support/backend.ts`(`requireBackend`·`requireAdmin`·`requirePortalTestSettings`·`requireGuestTestSettings`, `signUp`·`publishPost`·`callApi`), `playwright.config.ts` 프로젝트 `e2e`·`portal`(workers 1), `webServer`는 front 하나. CI `ci.yml` `e2e-backend`와 `e2e.yml`(nightly)이 일회용 MySQL·backend를 띄우고 `BLOG_PORTAL_*`·`BLOG_GUEST_*` 시험 설정을 넘긴다. 외부 HTTP를 흉내 내는 도구는 아직 없다.

## E1. 피드 수집 스케줄링 (FR-113, FR-116, FR-117)
- **Decision**: Spring `@Scheduled`로 단순하게 간다(1.0은 backend 1대, 001 R26과 같은 방식).
  - 스케줄러는 1분마다 "수집할 차례인 피드"만 골라낸다: `external_blogs.status = ACTIVE AND next_fetch_at <= now`(007 data-model), 한 번에 최대 `blog.external.batch-size`(기본 50)개.
  - 고른 피드는 크기가 정해진 별도 스레드 풀(`blog.external.fetch-threads`, 기본 4)에서 동시에 받는다. 피드 하나가 느려도 나머지가 밀리지 않게 하기 위해서다. 연결 5초, 읽기 10초, 응답 최대 2MB 제한.
  - 스레드 설정은 두 가지를 따로 둔다.
    - 스케줄러 풀: Spring 기본값은 스레드 1개라서 이미지 정리, 휴지통 비우기, 피드 선택 같은 `@Scheduled` 작업이 서로를 기다린다. `spring.task.scheduling.pool.size=3`으로 늘린다. 스케줄러 작업은 "고르고 넘기기"만 하고 오래 걸리는 일은 하지 않는다.
    - 피드 수집 전용 풀: `ThreadPoolTaskExecutor` 빈 `feedFetchExecutor`(core=max=`blog.external.fetch-threads`, 기본 4, 큐 `batch-size`, 큐가 차면 이번 차례는 건너뛰고 다음 분에 다시 고름). 메일 발송 등 다른 비동기 작업과 풀을 공유하지 않는다. 종료 시 진행 중 작업이 끝나기를 최대 30초 기다린다.
  - 받은 뒤 `next_fetch_at = now + 수집 주기(기본 30분, blog.external.fetch-interval)`로 미룬다. 피드마다 `next_fetch_at`에 무작위 지연(0~5분)을 더해 같은 시각에 몰리지 않게 한다.
  - 변경 확인: 저장해 둔 `ETag`, `Last-Modified`로 조건부 요청(`If-None-Match`, `If-Modified-Since`)을 보내고 304면 내려받지 않는다(FR-116).
  - 파싱은 ROME(RSS 0.9x/1.0/2.0, Atom 1.0)으로 한다. 같은 글 판별은 `guid`, 없으면 원문 링크의 정규화 값(FR-115).
  - 실패하면 다음 시도를 점점 늦춘다(30분 → 1시간 → 2시간 … 최대 12시간). 첫 실패 후 7일 동안 성공이 없으면 `status = STOPPED`로 바꾸고 알린다(FR-117).
  - 외부 주소 요청은 사설·루프백·링크 로컬 IP로 가지 못하게 막는다(SSRF 방지, FR-116). 리다이렉트도 최대 3번까지만 따라가고 매번 같은 검사를 한다.
  - 원문 링크 점검(FR-117 후반)은 주 1회 별도 `@Scheduled` 작업으로 HEAD 요청만 보낸다.
- **나중에 서버가 2대 이상이 되면**: 같은 피드를 두 대가 동시에 수집하지 않도록 ShedLock(DB 잠금)을 붙이거나, 피드를 고를 때 `SELECT … FOR UPDATE SKIP LOCKED`로 가져간다. 1.0에는 넣지 않는다.
- **Alternatives**: Quartz(테이블과 설정이 늘어남, 1대 운영엔 과함), Spring Batch(재시작·청크 처리가 필요할 만큼 무겁지 않음), 메시지 큐(실행 파트 추가, 원칙 위반).
- **계획 단계에서 더한 것**(E5): 고른 행은 제출 전에 `next_fetch_at = now + lease-time(10분)`으로 미뤄 수집이 끝나기 전 다음 분에 다시 고르지 않는다(임대). 수집이 끝나면 결과에 따라 다시 정한다. 큐가 차서 제출하지 못한 행은 임대를 풀지 않고 10분 뒤 다시 고른다(결정 표 15번).

## E2. 외부 요청 도구 `SafeHttpFetcher` (FR-116, Edge Cases, 사용자 지시 "SSRF 안전")
- **Decision**: 외부로 나가는 모든 요청(피드, 피드 찾기·인증 확인용 블로그 HTML, 대표 이미지, 원문 링크 점검)은 `common/net/SafeHttpFetcher` 하나만 쓴다.
  - JDK `HttpClient`(HTTP/1.1, `followRedirects(NEVER)`, 연결 시간 `blog.external.connect-timeout` 5초). 요청마다 전체 시간 `request-timeout` 10초(`HttpRequest.timeout`).
  - 리다이렉트는 직접 따라간다: 301·302·303·307·308이고 `Location`이 있으면 절대 주소로 바꿔 **매번 처음과 같은 검사**(아래) 후 다시 요청, 최대 3번(넘으면 `HTTP_ERROR`, 메시지 "too many redirects"). 다른 호스트로 가도 된다(블로그 이전·https 전환이 흔함). 최종 주소는 결과에 담아 피드 찾기에서 `feed_url`로 저장한다.
  - 주소 검사(요청 전, 리다이렉트마다): 005 `OutboundUrlGuard.check(uri)`(스킴 http/https, 허용 포트, `user@` 금지, 이름 해석한 **모든** 주소가 공인 주소 — 루프백·사설·링크로컬·CGNAT·멀티캐스트·와일드카드·IPv4 매핑 IPv6 거부) + 007의 "우리 서비스 주소 금지"(호스트가 `blog.base-url`의 호스트이거나 `blog.external.forbidden-hosts`(기본 `blog.java21.net`) 또는 그 하위 도메인이면 `SELF`).
  - 크기: 본문을 `InputStream`으로 읽으며 상한을 넘는 순간 끊고 `TOO_LARGE`(`Content-Length`가 이미 크면 읽지 않음). 상한은 용도별: 피드 `max-feed-size` 2MB, HTML `max-page-size` 1MB, 이미지 `max-image-size` 5MB, 링크 점검은 본문을 읽지 않음.
  - 압축: `Accept-Encoding`을 보내지 않는다(identity). gzip 해제 폭탄 걱정이 없고 크기 제한이 실제 바이트와 같다.
  - 머리글: `User-Agent: java21-blog-feed/1.0 (+{blog.base-url}/updates)`, 피드는 `Accept: application/rss+xml, application/atom+xml, application/xml;q=0.9, text/xml;q=0.8, */*;q=0.5`, 조건부 요청 `If-None-Match`·`If-Modified-Since`.
  - 결과 `FetchResult`: 성공(200·304, 본문, ETag, Last-Modified, 최종 주소, Content-Type) 또는 실패 종류 `FetchFailure`(`HTTP_ERROR`(상태 코드), `TIMEOUT`, `TOO_LARGE`, `BLOCKED_ADDRESS`, `DNS_ERROR`) — data-model `last_fetch_result` 값과 같다(파싱 실패 `PARSE_ERROR`는 호출하는 쪽).
- **한계**: JDK `HttpClient`는 검사한 IP로 연결을 고정할 수 없어 이름 해석과 연결 사이에 DNS 응답이 바뀌는 재바인딩 공격을 완전히 막지 못한다. 짧은 시간 제한, 리다이렉트마다 재검사로 줄이고 남는 위험은 운영 문서에 적어 서버 방화벽(나가는 연결에서 사설 대역 차단)을 권고한다(005 결정 표 26번과 같음).
- **Rationale**: 같은 규칙을 네 곳에서 써야 하고 하나라도 빠지면 SSRF다. 005 트랙백 송신은 리다이렉트를 따르지 않지만 피드는 http→https, 주소 이전 리다이렉트가 흔해서 따르되 매번 검사한다.
- **Alternatives**: 리다이렉트 금지(실제 피드 상당수가 실패), Spring `RestClient`(같은 JDK 클라이언트 위에 추상화만 늘어남), 자체 소켓으로 IP 고정(HTTPS SNI·인증서 처리를 직접 해야 함), 외부 프록시 경유(실행 파트 추가).

## E3. 피드 읽기와 피드 찾기 (FR-109, FR-114)
- **Decision**:
  - 파서: ROME `SyndFeedInput`(`setAllowDoctypes(false)` — DOCTYPE이 있으면 거부해 XXE·엔터티 폭탄 차단, `XmlReader`로 문서 선언·Content-Type의 문자 집합 판별). 지원 형식은 RSS 0.9x/1.0/2.0, Atom 0.3/1.0(ROME이 읽는 것). JSON Feed는 1.0 범위 밖(실패 `PARSE_ERROR`, 안내 문구 "RSS·Atom만").
  - `feed_format`: ROME `getFeedType()`이 `rss_*`면 RSS, `atom_*`면 ATOM.
  - 블로그 이름·주소: 채널 `title`(태그 제거, 200자), `link`(없으면 피드 주소의 호스트 루트).
  - 피드 찾기(회원이 블로그 주소를 넣은 경우): (1) 받은 응답이 XML로 읽히면 그 주소가 피드. (2) HTML이면 `HtmlScanner`(OWASP 이벤트 파서)로 `<link rel="alternate" type="application/rss+xml|application/atom+xml" href>`를 문서 순서대로 모아 첫 번째(상대 주소는 기준 주소로 풀기). (3) 없으면 `{사이트 루트}/rss`, `{사이트 루트}/feed`를 차례로 시도(최대 2번, 티스토리 `/rss`·워드프레스 `/feed`). 그래도 없으면 422 `EXTERNAL_FEED_NOT_FOUND`.
  - 미리보기(FR-109): 블로그 이름, 사이트 주소, 피드 주소(최종), 형식, 최근 글 3편(제목·원문 링크·발행 시각), 이미 등록되어 있으면 그 상태와 넘겨받기 가능 여부. 결과는 정규화한 피드 해시 키로 10분 Caffeine 캐시(같은 주소를 여러 번 눌러도 외부 요청 1번, FR-116 "수집 주기보다 자주 요청하지 않는다"의 취지).
- **Rationale**: ROME은 이미 의존성에 있고 RSS·Atom 변형을 모두 읽는다. HTML 파싱은 OWASP 라이브러리의 이벤트 수신기로 충분하다(태그 이름·속성만 필요).
- **Alternatives**: jsoup(새 의존성, 원칙 VI), 정규식으로 `<link>` 찾기(주석·속성 순서·따옴표 변형에 약함), 흔한 피드 주소를 더 많이 추측(요청 수 증가·오탐).

## E4. 저장할 값: 요약·제목·대표 이미지 (FR-114, SC-021, Edge Cases)
- **Decision**:
  - 요약: 항목의 `description`(RSS) 또는 `summary`(Atom), 없으면 `content:encoded`·`content`에서 `HtmlScanner`로 **텍스트만** 모은다(`<script>`·`<style>` 안 텍스트 버림, 블록 요소 경계에 공백, HTML 엔터티 풀기) → 공백 정리 → 코드 포인트 200자(넘으면 199자 + "…"). 결과가 일반 텍스트 문자열이고 front는 이스케이프 출력만 하므로 HTML이 실행될 길이 없다. 원문 본문 문자열은 이 계산 뒤 버린다(엔티티·로그·캐시 어디에도 남기지 않음, SC-021).
  - 제목: 같은 텍스트 추출 + 공백 정리, 300자. 비면 "(제목 없음)"이 아니라 링크의 경로 마지막 조각을 쓴다(번역 문구를 저장하지 않기 위해).
  - 원문 링크: 항목 `link`(Atom은 `rel=alternate`), 상대 주소면 피드 주소 기준으로 풀기, http/https가 아니면 그 항목을 버린다(`javascript:` 등). 2000자 넘으면 버린다.
  - 대표 이미지 주소(`image_url`): (1) RSS `<enclosure type="image/*">`, (2) Media RSS `media:thumbnail`·`media:content(medium=image 또는 type=image/*)` — `rome-modules` 없이 `SyndEntry.getForeignMarkup()`의 JDOM 요소에서 이름공간 `http://search.yahoo.com/mrss/`로 읽음, (3) 요약 계산 때 본 HTML의 첫 `<img src>`(1×1 추적 픽셀을 피하려고 `width`·`height` 속성이 둘 다 있고 50 미만이면 건너뜀). http/https만, 1000자 이하.
  - 피드 카테고리·태그(`feed_terms_json`): RSS `category`, Atom `category@term`(`label`이 있으면 함께가 아니라 `term` 하나), 원문 그대로 최대 20개·각 100자.
  - 발행 시각: `publishedDate`, 없으면 `updatedDate`, 둘 다 없으면 처음 수집한 시각. 미래 시각은 수집 시각으로 당긴다(포털 최신 맨 위를 차지하는 것 방지).
- **Rationale**: spec "요약은 HTML 태그를 제거한 텍스트", "본문 전체를 저장하지 않는다". HTML을 살균해 저장하는 대신 텍스트로만 바꾸면 살균 규칙 유지 부담과 렌더링 위험이 모두 없다.
- **Alternatives**: 요약을 살균한 HTML로 저장(포털 카드에 서식 필요 없음, 위험만 늘어남), `og:image`를 위해 원문 페이지 방문(글마다 외부 요청 1번 추가, 수집 비용·상대 서버 부담).

## E5. 수집 한 번의 흐름과 같은 글 판별 (FR-113, FR-115, FR-116, FR-117)
- **Decision**: `FeedCollector.collect(externalBlogId)`(수집 풀 스레드에서):
  1. 블로그 행 읽기(ACTIVE가 아니면 끝 — 그사이 중지·차단됨).
  2. `SafeHttpFetcher`로 조건부 요청. 304 → 성공 처리(`NOT_MODIFIED`)만.
  3. ROME 파싱 실패 → 실패 처리(`PARSE_ERROR`).
  4. 항목을 피드 순서대로 최대 `max-items-per-fetch`(100)개 변환(E4). **최초 수집**(`last_success_at`이 NULL)이면 발행 시각이 `now - initial-window(30일)`보다 오래된 항목은 버린다(FR-113). 이후 수집은 기간 제한 없이 피드에 있는 것(보통 최근 10~50개).
  5. 같은 글 찾기: 항목들의 `guid_hash`·`link_hash`로 `IN` 조회 2번(쿼리 수 고정). 찾는 순서는 guid가 있으면 guid, 없으면 링크(FR-115). guid가 다른데 링크가 같은 항목(피드가 guid를 바꾼 경우)은 링크로 찾은 행을 갱신하고 guid를 새 값으로.
  6. 기존 글: 제목·요약·이미지 주소·발행 시각·카테고리가 바뀌었을 때만 갱신. **주제는 다시 정하지 않는다**(사람이 정한 주제 보호, 규칙 변경은 이후 수집분부터 — data-model). REMOVED 글은 되살리지 않는다(내린 이유 유지).
  7. 새 글: 주제 결정(E10) → 저장 → 검수 행(필요하면) → 썸네일(E7, 인증된 블로그만, 트랜잭션 밖).
  8. 성공 처리: `consecutive_failures = 0`, `first_failed_at = NULL`, ETag·Last-Modified·`last_success_at`·`last_fetch_result`·`last_http_status`, 블로그 이름·사이트 주소가 비어 있으면 채움, `next_fetch_at = now + 수집 주기 + 무작위(0~fetch-jitter)`.
  9. 새 글이 하나라도 있으면 커밋 후 `PortalChangedEvent("external-fetch")` → 포털 캐시 무효화(SC-018 지연을 수집 주기로 한정).
  - 트랜잭션: 블로그 행 갱신과 글 저장을 피드 하나당 한 트랜잭션(외부 요청은 트랜잭션 밖에서 끝낸 뒤). 썸네일 받기는 커밋 뒤 같은 수집 스레드에서 글마다 짧은 트랜잭션으로 `thumbnail_key`만 갱신.
  - 실패 처리: `consecutive_failures + 1`, `first_failed_at`이 NULL이면 now, `next_fetch_at = now + min(30분 × 2^(실패 수 - 1), max-backoff 12시간)`. `now - first_failed_at >= stop-after(7일)`이면 `STOPPED`, `next_fetch_at = NULL`, 신청·소유 회원이 있으면 알림 `EXTERNAL_FEED_STOPPED`(`{ externalBlogTitle, lastResult }`).
  - 같은 피드를 두 스레드가 동시에 수집하지 않는 것은 E1 임대로 보장한다(1대 전제).
- **Rationale**: 피드 하나의 결과가 한 트랜잭션이면 실패·재시도가 단순하다. 외부 요청을 트랜잭션 밖에 두어 DB 연결을 10초씩 잡지 않는다.
- **Alternatives**: 항목마다 트랜잭션(쿼리 수 증가), 주제를 갱신 때마다 다시 계산(사람이 정한 값과 충돌, 규칙 변경 소급은 spec이 요구하지 않음).

## E6. 피드 주소 정규화와 중복 (FR-112, FR-115)
- **Decision**: `FeedUrlNormalizer.normalize(uri)`: 스킴을 지우고(`http`와 `https`를 같은 피드로 봄), 호스트 소문자·IDN은 ASCII(punycode), 기본 포트(80·443) 제거, 경로의 끝 `/` 제거(루트 `/`는 빈 문자열), 조각(`#…`) 제거, 쿼리는 그대로(순서도). `feed_url_hash = SHA-256(정규화 문자열)` 16진수 64자. 원문 링크 `link_hash`도 같은 함수. `feed_url` 자체는 실제로 받은 최종 주소(https 우선)를 저장한다.
- 중복 등록 막기: 신청·직접 등록·넘겨받기 트랜잭션에서 `feed_url_hash`로 거절·해제가 아닌 행을 먼저 찾아 있으면 409 `EXTERNAL_BLOG_ALREADY_REGISTERED`(`params: { externalBlogId, status, claimable }`). 동시에 두 요청이 사전 검사를 통과하면 MySQL `uk_external_blogs_active_feed_hash`가 막고 `DataIntegrityViolationException`을 같은 409로 바꾼다.
- **Rationale**: 같은 블로그를 http·https 두 주소로 두 번 등록하는 것이 가장 흔한 중복이다. data-model의 정규화 규칙에 스킴 무시를 더했다(data-model "plan에서 확정한 값").
- **Alternatives**: 스킴 포함(위 중복 허용), 사이트 주소 기준 중복(한 사이트에 피드가 여럿인 경우를 막음).

## E7. 썸네일 (FR-128, Edge Cases "외부 썸네일", 001 R27)
- **Decision**: **소유 인증된 블로그의 글만, backend가 받아 줄인 사본을 제공한다. 핫링크는 하지 않는다.**
  - 대상: `external_blogs.ownership_verified = true`인 블로그의 새 글 중 `image_url`이 있는 것. 인증 없는 블로그는 `image_url`만 저장하고 이미지를 받지 않는다(요청 0건, FR-128 "썸네일 없이").
  - 받기: `SafeHttpFetcher`(5MB) → 001 `ImageInspector`로 내용 판별(JPEG·PNG·GIF·WebP만, SVG·HTML 거부)·픽셀 상한(`blog.media.max-pixels`) → 001 Thumbnailator 경로로 **600x400 cover 한 크기**(포털 카드 300x200의 2배, 003 research) 생성 → `{blog.media.thumbnail-dir}/external/{key 앞 2자}/{key}.{jpg|png}`(WebP·GIF는 PNG, 001 규칙) 저장 → `thumbnail_key`(001 `MediaKeyGenerator` 22자) 기록. 원본은 저장하지 않는다.
  - 제공: `GET /media/external/{key}` (backend, 접두어 없음, front 프록시가 `/media/**`를 이미 넘김). 키 형식이 아니거나 파일이 없거나, 그 글이 ACTIVE가 아니거나 블로그가 인증되지 않았으면 404 `MEDIA_NOT_FOUND`. 응답은 001과 같은 `nosniff`·`inline`, 캐시는 `public, max-age=86400`(블로그가 해제·차단되면 내려야 하므로 001의 `immutable` 1년보다 짧게).
  - 포털 카드 `thumbnailUrl`: 블로그가 인증되었고 `thumbnail_key`가 있을 때만 `/media/external/{key}`, 아니면 null(→ 주제 카드 색 기본 이미지). front `thumbnailImage`는 이 주소를 그대로 쓴다(이 서비스 `/media/{key}` 형식이 아님).
  - 인증이 나중에 된 경우: 인증(넘겨받기 포함) 커밋 후 그 블로그의 최근 30일 ACTIVE 글 중 `image_url`이 있고 `thumbnail_key`가 없는 것 최대 100개를 수집 풀에 맡겨 받는다(FR-128 "인증이 완료되면 썸네일 노출이 켜진다").
  - 삭제: 글 행 삭제(해제 + 글 삭제)·REMOVED 전환 시 커밋 후 파일 삭제. 실패하거나 놓친 파일은 정리 작업(E15)이 `external/` 아래에서 DB에 없는 키를 지운다(주 1회).
  - 이미지 받기 실패는 그 글의 썸네일만 없을 뿐 수집 결과(`last_fetch_result`)에 영향이 없다.
- **Rationale**: front CSP가 `img-src 'self'`(001 R27, 이미 이 방식으로 결정됨)라 핫링크는 정책을 넓혀야 한다. 핫링크는 방문자 IP·Referer를 외부에 넘기고 http 이미지는 혼합 콘텐츠가 된다. 한 크기만 미리 만들면 요청 때 원본을 다시 받을 일이 없다.
- **Alternatives**: 링크만(핫링크, CSP·개인정보·혼합 콘텐츠), 001 `media` 행으로 저장(`owner_id NOT NULL` — 운영자 등록 블로그는 회원이 없음, 스키마 변경 필요), 요청 때 받아 만들기(포털 렌더링 경로에서 외부 요청 발생), 인증 없는 블로그도 받아 두고 숨김(FR-128 취지와 달리 남의 이미지를 우리 서버에 복제).

## E8. 등록·인증·넘겨받기 (FR-109~112, FR-128, FR-129)
- **Decision**:
  - 미리보기·인증 코드 발급·인증 확인·신청은 로그인 회원만(비로그인 401). 외부 요청을 일으키는 미리보기는 회원당 시간당 `preview-per-hour`(20), 인증 확인은 `verify-checks-per-hour`(10) — Caffeine 고정 창, 넘으면 429 `TOO_MANY_REQUESTS`(001 코드).
  - 인증 코드: `java21-verify-` + base62 12자(총 26자, `code` VARCHAR(32) UNIQUE), `expires_at = 발급 + 24시간`. 같은 회원·같은 피드에 유효한 코드가 있으면 새로 만들지 않고 그것을 돌려준다(코드가 바뀌어 회원이 헷갈리지 않게).
  - 확인: 피드(채널 `title`·`description`, 항목 최대 20개의 제목·요약·본문 텍스트)와 사이트 주소 HTML(`HtmlScanner` 텍스트 + `meta` 속성 값) 두 곳에서 코드 문자열을 찾는다. 찾으면 `verified_at`. 못 찾으면 422 `EXTERNAL_VERIFICATION_CODE_NOT_FOUND`(`params: { checked: ["FEED","SITE"], failures: { SITE: "TIMEOUT" } }`), 만료면 422 `EXTERNAL_VERIFICATION_EXPIRED`. 확인은 캐시를 쓰지 않는다(코드를 막 넣었을 수 있음). 단, 피드 서버가 캐시하는 경우를 위해 안내 문구에 "반영까지 몇 분 걸릴 수 있음"을 둔다.
  - 신청(`POST /me/external-blogs`): 피드를 다시 받아 읽히는지 확인(읽히지 않으면 422 `EXTERNAL_FEED_UNREADABLE`, `params.result`) → 회원 행 `FOR UPDATE` → 3개 한도(`member_id = ? AND status NOT IN ('REJECTED','RELEASED')`, BLOCKED 포함, 409 `EXTERNAL_BLOG_LIMIT_EXCEEDED`) → 중복 검사(E6) → `PENDING` 저장. `verificationId`를 주면 같은 회원·같은 피드 해시·24시간 안 성공한 인증이어야 하며 `ownership_verified = true`, 그 인증 행의 `external_blog_id`를 연결. 기본 주제는 003 규칙(소분류, 운영자 숨김 아님 — 404 `TOPIC_NOT_FOUND`/422 `TOPIC_NOT_SELECTABLE`).
  - 운영자 직접 등록: 같은 피드 확인·중복 검사, `registration_basis` 필수(1~500자), `member_id = NULL`, `ownership_verified = false`, 바로 `ACTIVE`, `next_fetch_at = now`. 작업 기록 `EXTERNAL_BLOG_CREATE`.
  - 넘겨받기(`POST /external-blogs/{id}/claim { verificationId }`): 인증이 성공했고 피드 해시가 그 등록과 같아야 함. 대상 상태가 PENDING·ACTIVE·PAUSED·STOPPED면 가능, BLOCKED면 409 `EXTERNAL_BLOG_STATE_CONFLICT`(`params.status`), REJECTED·RELEASED는 "활성 등록이 아님"으로 404(새로 신청하면 됨). 이미 같은 회원이 인증된 주인이면 200 그대로. 회원 3개 한도에 넘겨받는 등록도 센다(같은 회원 행 잠금). `member_id` 변경, `ownership_verified = true`, `ownership_verified_at`. 이전 회원에게 알림 없음(data-model, 1.0). 커밋 후 썸네일 소급(E7).
  - 이미 등록된 블로그를 신청하면 409 + `claimable: true`(인증 성공 시 넘겨받기 가능)로 front가 "소유 인증으로 넘겨받기" 흐름을 안내한다(spec US1 AS5).
- **Rationale**: 피드와 블로그 페이지 두 곳 중 한 곳에 코드를 넣으라는 spec 그대로. 신청 시 피드 확인은 승인 후 첫 수집에서야 실패를 아는 일을 막는다.
- **Alternatives**: 인증을 `<meta>` 태그로만(블로그 서비스 대부분이 head 편집 불가), DNS TXT(개인 블로그 서비스는 도메인이 없음), 이메일 인증(외부 블로그 주인의 메일을 알 방법이 없음).

## E9. 자동 분류 방식 (FR-118, FR-119, spec Assumptions 후보 A·B·C)
- **Decision**: **(A) 키워드 사전 기반**. `TopicClassifier` 인터페이스(`ClassificationResult classify(ClassifierInput)` → `{ topicId | null, confidence 0~1, version }`) + `KeywordTopicClassifier`(버전 `keyword-v1`).
  - 사전: `src/main/resources/external/topic-keywords.yml` — 003 `TopicSeeder`의 소분류 slug마다 키워드 목록(한국어·영어·일본어·중국어 낱말과 기술 용어, 예: `it-internet: [spring, java, kubernetes, 개발, 프로그래밍, プログラミング, 编程, …]`). 기동 때 읽어 DB의 주제 slug와 맞추고, 없는 slug 항목은 경고 로그 후 무시(운영자가 주제를 바꿔도 기동은 됨). 키워드는 매핑 규칙과 같은 정규화(NFKC·trim·소문자).
  - 입력: 제목, 요약, 피드 카테고리·태그. 낱말 나누기는 정규화한 텍스트를 공백·구두점으로 자른 토큰 + 한글·가나·한자 연속 구간은 키워드 포함 여부(부분 문자열)로 본다(형태소 분석기 없음).
  - 점수: 주제마다 일치한 키워드 가중치 합(카테고리·태그 일치 3, 제목 2, 요약 1, 같은 키워드는 위치별 한 번). `top` = 가장 높은 주제 점수, `sum` = 모든 주제 점수 합. 신뢰도 = `(top / sum) × min(1, top / 4)`(경쟁 주제가 없고 증거가 충분할수록 1). 일치가 하나도 없으면 `topicId = null`, 신뢰도 0.
  - 채택 기준은 운영 설정 `external.auto-classify-min-confidence`(기본 0.7). 결과는 채택 여부와 관계없이 `classifier_topic_id`·`classifier_confidence`·`classifier_version`에 남긴다(정확도 측정, FR-122).
  - 사전은 코드와 함께 바뀐다(PR). 운영자가 화면에서 바꾸는 규칙은 매핑 규칙(FR-121)이다.
- **Rationale**: spec이 "처음부터 자체 알고리즘을 만들지 않는다", "(C)는 데이터가 쌓이기 전에 만들지 않는다"고 정했다. (A)는 외부 비용·개인정보 이동이 없고 결과를 설명할 수 있으며, 사람이 확정한 결과(REVIEW·OWNER)가 쌓이면 같은 인터페이스로 (B)·(C)를 붙여 정확도(FR-122)를 비교할 수 있다.
- **Alternatives**: (B) 외부 AI API(호출 비용, API 키·비밀 값 추가, 외부 블로그 글을 제3자에 보냄, 실행 파트는 아니지만 외부 의존), (C) 내부 글(작성자가 주제를 고른 `posts.topic_id`)로 나이브 베이즈 학습(spec이 1.0에서 금지, 내부·외부 글 분포가 달라 검증 필요).

## E10. 주제 결정 순서와 검수 (FR-118~121)
- **Decision**: 새 글마다 `TopicDecider`:
  1. (주인 지정 OWNER는 새 글에는 없음 — 수집 후 주인이 바꿈.)
  2. 매핑 규칙: `feed_terms_json`을 정규화해 `topic_mapping_rules.keyword`와 완전 일치하는 규칙 중 `priority` 큰 것, 같으면 `id` 작은 것 → `topic_source = RULE`. 규칙 전체는 피드 한 번에 1번 읽는다. 규칙이 가리키는 주제가 운영자 숨김이거나 대분류면 건너뜀.
  3. 자동 분류: 신뢰도 ≥ 기준 → `AUTO`, `topic_id = classifier_topic_id`.
  4. 그 외 → `DEFAULT`(블로그 기본 주제). 이때 자동 분류 신뢰도가 기준 미만이면(일치 없음 포함) `classification_reviews`에 `PENDING`(`predicted_topic_id`, `confidence`)을 만든다(FR-119).
  - 매핑 규칙으로 정해진 글(RULE)은 자동 분류를 돌리지 않고 검수도 만들지 않는다(운영자가 정한 규칙이 이미 사람의 판단). 정확도 지표에도 들어가지 않는다(`classifier_topic_id` NULL).
  - 주인 변경(OWNER, FR-120): 소유 인증된 주인만. `topic_source = OWNER`, `topic_decided_at = now`, 같은 글의 `PENDING` 검수는 `SKIPPED`. CONFIRMED 뒤에도 주인이 바꿀 수 있다(FR-118 우선순위 1).
  - 운영자 확정(REVIEW): `PENDING`만(아니면 409 `CLASSIFICATION_REVIEW_CLOSED`), `topic_source = REVIEW`, `topic_decided_at = now`, 검수 `CONFIRMED`. 작업 기록 `CLASSIFICATION_CONFIRM`. 일괄 확정은 한 번에 50개(각 행마다 작업 기록).
  - 목록에는 ACTIVE 글의 PENDING만 보인다(REMOVED 글의 검수는 남겨 두되 숨김).
  - 기존 글의 주제는 규칙·사전이 바뀌어도 다시 계산하지 않는다(US3 AS5 "이후 수집되는 글에 적용").
- **Rationale**: spec 우선순위 그대로. RULE 글을 검수에서 빼야 검수 목록이 실제로 "기계가 자신 없는 글"만 남는다.
- **Alternatives**: 일치 없는 글(신뢰도 0)은 검수에서 빼기(spec FR-119 "기준 미만이면 … 검수 목록에 넣는다"와 다름), RULE 글도 자동 분류해 정확도에 넣기(규칙이 맞힌 것을 분류기 성과로 셈).

## E11. 분류 현황 (FR-122, SC-019)
- **Decision**: `GET /admin/classification-stats`(5분 Caffeine 캐시):
  - 정확도: `topic_decided_at >= now - 30일 AND classifier_topic_id IS NOT NULL`인 글(OWNER·REVIEW) 중 `classifier_topic_id = topic_id` 비율, 표본 수 함께. 표본이 0이면 null.
  - 최종 주제 정확도(SC-019 확인용): 같은 표본에서 "사람이 정하기 직전 노출 주제"를 알 수 없으므로(이력 컬럼 없음) SC-019는 "검수·주인 확인 표본에서 사람이 바꾸지 않은 비율"로 근사한다 — `classification_reviews.CONFIRMED`에서 `confirmed_topic_id = 그 당시 노출 주제(=블로그 기본 주제, DEFAULT였으므로 external_blogs.default_topic_id)` 비율. 화면에 두 값과 정의를 함께 보인다.
  - 주제별 분포: 최근 30일 발행 ACTIVE 외부 글을 `topic_id`·`topic_source`로 묶은 수.
  - 검수 대기 수: ACTIVE 글의 PENDING 검수 수.
- **Rationale**: 스키마를 바꾸지 않고(결정 이력 테이블 없음) spec 지표를 계산한다. SC-019 정의의 한계는 결정 표에 남긴다.
- **Alternatives**: 주제 변경 이력 테이블(스키마 변경), 캐시 없이 매번 계산(선택 인덱스 제안 1이 없으면 매번 전체 훑기).

## E12. 원문 링크 점검과 자동 중지 (FR-117)
- **Decision**:
  - `LinkCheckJob`(`blog.external.link-check-cron`, 기본 매주 월요일 04:30): `status = ACTIVE`이고 `link_checked_at`이 NULL이거나 7일 지난 글을 `link_checked_at` 오래된 순으로 최대 `link-check-batch`(500)개, 수집 풀에 하나씩 맡겨 `HEAD`(405·501이면 `GET` + `Range: bytes=0-0`, 본문 읽지 않음). 404·410, 또는 호스트 이름이 없음(`DNS_ERROR`)이면 `REMOVED`(`LINK_BROKEN`). 그 밖의 실패(시간 초과, 5xx, 403, 내부망으로 리다이렉트)는 내리지 않고 다음 주에 다시(일시 장애·봇 차단 오판 방지). 결과와 관계없이 `link_checked_at = now`. 같은 호스트에 1초에 1번 이하(호스트별 마지막 요청 시각 메모리).
  - 내린 글이 하나라도 있으면 커밋 후 포털 캐시 무효화.
  - 자동 중지는 E5 실패 처리 안에서(별도 작업 없음).
- **Rationale**: spec "원문 링크가 열리지 않는 글은 주 1회 점검해 포털에서 내린다". 확실히 없어진 경우(404·410·도메인 없음)만 내려 오탐을 줄인다.
- **Alternatives**: 모든 실패를 내림(일시 장애에 대량 삭제), 연속 2주 실패 후 내림(실패 횟수 컬럼이 없어 스키마 변경 필요).

## E13. 포털 합치기 (FR-123, FR-124, 003 FR-080·086·093·147)
- **Decision**: 003 쿼리는 그대로 두고 007이 `ExternalPortalSource`(인터페이스, 003 `BlogPenaltyPolicy`처럼 빈이 없으면 빈 결과)를 003 서비스에 붙인다.
  - 외부 글의 포털 노출 조건(`ExternalPortalExposure`): `external_posts.status = ACTIVE` AND `external_blogs.status IN (ACTIVE, PAUSED, STOPPED, RELEASED)`(일시 중지·자동 중지는 이미 수집된 글을 그대로 둠 — data-model. RELEASED는 "글 남기기"로 해제한 경우다: "삭제"를 골랐으면 글 행이 없고, 탈퇴로 해제된 등록의 글은 `REMOVED`라 따로 거를 필요가 없다 — E16, 결정 표 24번. BLOCKED·PENDING·REJECTED는 안 보임) AND 포털 제외(`portal_exclusions.external_post_id`) 없음 AND `published_at <= now` AND 주제(소분류와 그 대분류)가 운영자 숨김이 아님. 003 FR-088의 가입 24시간·본문 200자 조건과 블로그 포털 노출 설정(FR-089)은 적용하지 않음(FR-123).
  - 카드: 003 `PortalCard`에 `source: "INTERNAL" | "EXTERNAL"`(기존 응답은 `INTERNAL`), `visitUrl`(외부만 `/api/v1/external-posts/{id}/visit`), `externalBlog: { id, title, siteHost }`(외부만)를 더한다. 외부 카드는 `blog`가 `{ handle: null, title: 외부 블로그 이름 }`, `author: null`, `likeCount`·`commentCount` 0, `thumbnailUrl`은 E7 규칙. 카드 id는 출처마다 따로라 front 키는 `${source}-${id}`.
  - 메인 최신(`/portal`, `/portal/latest`): 내부 최신 `LATEST_WINDOW + 1`행 + 외부 최신 같은 수를 읽어 (발행 시각 내림, 같으면 출처 INTERNAL 먼저, 같으면 id 내림)으로 합친 뒤 `PerBlogCap`(키 `P:{blogId}`·`E:{externalBlogId}`, 블로그당 2편 — FR-123이 003 FR-080을 그대로 적용)으로 20편. 커서는 003 형식에 출처 `s`("P"/"E")를 더한다(`s`가 없는 옛 커서는 "P"로 읽음). 커서 다음 읽기는 각 출처에서 "(시각, 출처, id)가 커서보다 뒤"인 행.
  - 메인 인기: `PopularitySnapshot.Entry`에 `source`를 더하고, 외부 점수 = 최근 7일(`portal.popular-window`) 클릭 합 × `external.score-weight`(기본 1.0) × 003 감쇠 `2^(-발행 후 시간/halfLifeHours)`. 외부 블로그는 신고 감점(005) 대상이 아니다(차단·내림으로 처리). 내부·외부를 한 목록에서 점수순 정렬(FR-124 "같은 점수 체계"). 가중치 기본값 1.0은 "클릭 1번 = 내부 글 조회 1번 × (조회 가중치 / 1)"이 아니라 그대로 곱하므로, 내부 조회 가중치(003 기본 1)와 같은 크기다. 운영자가 0~10으로 조정한다.
  - 주제 페이지(`/topics/{slug}/posts`): `latest`는 두 출처에서 (id, 발행 시각)만 `(page+1) × size`행씩 읽어 합치고 그 페이지 몫만 카드로 읽는다(쿼리 4회). `totalCount`는 두 출처 개수의 합(COUNT 2회). 페이지 깊이 비용이 커지므로 `page`가 49를 넘으면(1,000편 너머) 빈 목록(003 화면은 페이지 번호 10개씩 표시라 실제로 닿지 않음). `popular`는 위 스냅숏을 주제로 거름.
  - 추천(큐레이션)·인기 태그·새 블로그는 내부 글만(spec이 요구하지 않음, 큐레이션 테이블은 `post_id`만).
  - 주제 자동 숨김(003 FR-147): `TopicPostCountQueryRepository` 결과에 외부 글 최근 30일 포털 노출 수를 주제별로 더한다(쿼리 1회 추가).
  - 필터(FR-124 "외부 글만 모아 보거나 숨기는 필터"): `/portal/latest?source=all|internal|external`, `/topics/{slug}/posts?source=…`(기본 `all`). 메인 첫 화면(`/portal`)은 항상 `all`이고, 최신 글 영역의 필터를 바꾸면 front가 `/portal/latest?source=`로 그 영역만 다시 읽는다(JS 없으면 `/?source=external` 링크로 SSR). 캐시 키에 `source`를 넣는다.
- **Rationale**: 외부 글을 `posts`에 넣으면 노출 매트릭스·검색·RSS·사이트맵(FR-125)을 모두 고쳐야 한다. 서비스 계층 합치기는 각 출처 쿼리를 단순하게 두고 커서·2편 제한만 넓히면 된다.
- **Alternatives**: DB 뷰 + UNION(Crowfoot 스키마에 뷰 추가, JPA 매핑 어려움), 외부 글을 별도 영역으로만 표시(FR-123 "섞여 나온다" 위반).

## E14. 클릭 집계와 원문 이동 (FR-123, FR-124)
- **Decision**: 카드 링크는 `GET /api/v1/external-posts/{id}/visit`(front 프록시 경유, `target="_blank" rel="noopener nofollow"`). backend는 포털 노출 조건(E13)을 만족하는 글이면 클릭을 세고 `302 Location: {link}`, `Cache-Control: no-store`, `Referrer-Policy: no-referrer`(우리 서비스 경로를 외부에 넘기지 않음). 아니면 404 `EXTERNAL_POST_NOT_FOUND`(front 프록시가 그대로 넘기므로 공통 404 화면 대신 JSON — 새 탭에 오류 JSON이 보이지 않게 front가 이 경로만 `Accept: text/html` 요청이면 404 화면으로 바꿈, contracts/routes.md).
  - 세기: 같은 방문자(001 `VisitorKeyResolver`: 회원 ID 또는 방문자 쿠키, 없으면 IP 해시) + 같은 글은 30분에 한 번(Caffeine, 001 R10 조회수와 같은 방식). 세면 `external_posts.click_count + 1`과 `external_post_daily_clicks`(UTC 날짜) upsert를 한 트랜잭션에서.
  - 크롤러: robots.txt가 이미 `Disallow: /api/`이고 링크에 `nofollow`.
  - 일별 클릭은 90일 지나면 정리 작업(E15)이 지운다.
- **Rationale**: data-model "카드 클릭은 backend를 거쳐 원문으로 이동". 링크가 그대로 동작해야 JS 없이도 원문으로 간다(원칙 V).
- **Alternatives**: `POST` 비콘 + 직접 링크(JS 필요, 원칙 V·SSR 정신에 어긋나고 차단기에 막힘), 원문 주소를 쿼리로 받는 일반 리다이렉트(열린 리다이렉트).

## E15. 정리 작업 (FR-110, FR-126)
- **Decision**: `ExternalCleanupJob`(`blog.external.cleanup-cron`, 기본 매일 05:30): (1) `expires_at`이 7일 지난 인증 코드 행 삭제(성공한 행 포함 — 결과는 `external_blogs.ownership_verified`에 있음), (2) RELEASED 등록에 남은 `REMOVED` 외부 글 중 내린 지(`external_posts.updated_at`) `release-retention`(30일)이 지난 것 삭제(탈퇴·신고 처리 근거 보관 기간, 결정 표 24번. 주인이 남긴 `ACTIVE` 글은 지우지 않음, 검수·일별 클릭은 CASCADE, 포털 제외 행은 먼저 지움), (3) 90일 지난 `external_post_daily_clicks` 삭제, (4) 주 1회(월요일 실행분) `thumbnail-dir/external/` 아래 DB에 없는 키의 파일 삭제. 한 번에 500건씩.
- **Rationale**: 001 R26의 정리 작업들과 같은 모양(`blog.jobs.*` 대신 `blog.external.*`에 모아 007 설정을 한 곳에).
- **Alternatives**: 작업마다 따로 cron(설정 4개 늘어남).

## E16. 해제·차단·탈퇴와 SC-020 (FR-126, FR-127, FR-157)
- **Decision** (결정 표 24번, marco 2026-10-07 확정):
  - 해제(관리 회원, ACTIVE·PAUSED·STOPPED·PENDING → RELEASED, `deletePosts` 필수): 수집 즉시 중지(`next_fetch_at = NULL`). 해제 뒤에는 새 글을 수집하지 않는다.
    - **글 남기기**(`deletePosts: false`): 글 행과 상태를 그대로 둔다. 노출 조건이 RELEASED를 포함하므로(E13) 이미 수집된 `ACTIVE` 글은 포털에 계속 나온다. 포털 캐시 무효화는 하지 않아도 되지만 상태 변경이라 `PortalChangedEvent`를 똑같이 낸다(카드 내용은 같음). 썸네일 노출은 지금처럼 `ownership_verified`로 판단. 남긴 글에는 보관 기한이 없다(주인이 지우거나 운영자가 내릴 때까지).
    - **글 삭제**(`deletePosts: true`): 같은 트랜잭션에서 글 행을 지우고(포털 제외 행 먼저, 검수·클릭은 CASCADE) 커밋 후 썸네일 파일을 지운다. **30일 보관 없이 즉시 삭제**(주인의 삭제 의사가 우선. 그 글에 걸린 처리 중 신고는 005 화면에 "대상 없음"으로 나와 운영자가 종결).
    - **남긴 글 나중에 삭제**: RELEASED 등록에 같은 API를 `deletePosts: true`로 다시 부르면 남은 글을 위와 같이 지운다(상태는 RELEASED 그대로, `false`면 409 `EXTERNAL_BLOG_STATE_CONFLICT`). 해제 뒤 관리 회원(`member_id` 유지)은 조회와 이 삭제만 할 수 있고, 기본 주제·글 주제 변경은 409 `EXTERNAL_BLOG_STATE_CONFLICT`.
  - 다시 등록(같은 `feed_url_hash`의 새 등록이 승인·직접 등록으로 ACTIVE가 될 때): 같은 트랜잭션에서 그 피드의 RELEASED 등록에 남은 글 중 `MEMBER_WITHDRAWN`이 아닌 것(`ACTIVE`와 신고·운영자·링크 점검으로 내린 `REMOVED`)의 `external_blog_id`를 새 등록으로 바꾼다. 새 등록은 첫 수집 전이라 글이 없어 UNIQUE(external_blog_id, guid_hash·link_hash)와 충돌하지 않고, 활성 시점마다 옮기므로 한 피드에서 옮길 글을 가진 RELEASED 등록은 많아야 하나다. 첫 수집이 같은 글을 새로 만들지 않고 갱신하며(E5), 주제·클릭 수·내림 결정이 이어진다. 남긴 글의 관리 권한은 새 등록의 관리 회원으로 넘어간다(이전 주인이 지우려면 소유 인증으로 넘겨받기). 탈퇴로 내린 글은 옮기지 않고 정리 작업이 지운다(E15).
  - 차단(관리자, BLOCKED가 아닌 모든 상태 → BLOCKED, 사유 필수): 그 등록의 모든 외부 글 `REMOVED`(`BLOG_BLOCKED`), `next_fetch_at = NULL`. **같은 피드의 RELEASED 등록에 남은 `ACTIVE` 글도 함께 `REMOVED`(`BLOG_BLOCKED`)**(차단은 피드 단위 판단). RELEASED 등록 자체도 차단할 수 있지만(남긴 글을 내리고 재신청을 막음), 같은 피드에 거절·해제가 아닌 다른 등록이 있으면 `active_feed_hash` UNIQUE와 겹치므로 409 `EXTERNAL_BLOG_STATE_CONFLICT`(`params: { status, action, activeExternalBlogId }`) — 그 등록을 차단하면 남긴 글도 함께 내려간다. 차단된 피드는 `active_feed_hash`가 남아 다시 신청할 수 없다(409 `EXTERNAL_BLOG_ALREADY_REGISTERED`, `claimable: false`).
  - 일시 중지·재개: ACTIVE ↔ PAUSED, STOPPED → ACTIVE(재개 시 `consecutive_failures = 0`, `first_failed_at = NULL`, `next_fetch_at = now`). 이미 수집된 글은 그대로 노출.
  - 탈퇴(FR-157): 001 `AccountService.withdraw`가 같은 트랜잭션에서 `MemberWithdrawnEvent(userId)`를 발행하고, 007 리스너(`@EventListener`, 동기)가 그 회원의 거절·해제가 아닌 등록을 모두 RELEASED로 바꾸고, **그 회원의 모든 등록(이미 글을 남기고 해제한 것 포함)**의 `ACTIVE` 외부 글을 `REMOVED`(`MEMBER_WITHDRAWN`)로 바꾼다. 실제 주인은 이후 새로 신청할 수 있다(`active_feed_hash` NULL).
  - 신고(E17): 남긴 글은 포털 노출 중이므로 `EXTERNAL_POST` 신고 대상이고, 남긴 `ACTIVE` 글이 있는 RELEASED 등록은 `EXTERNAL_BLOG` 신고 대상이다(조치 `BLOCK_EXTERNAL_BLOG`는 위 차단 규칙).
  - 포털에서 사라지는 경우(글 삭제 해제·남긴 글 삭제·차단·내림·탈퇴)는 모두 커밋 후 `PortalChangedEvent` → 포털 캐시 무효화 → 다음 요청부터 사라짐(SC-020 "5분"보다 빠름). 상태 전이가 맞지 않으면 409 `EXTERNAL_BLOG_STATE_CONFLICT`(`params: { status, action }`).
- **Rationale**: marco가 해제할 때 주인이 글을 남길지 고르게 하고, 남기면 포털에 계속 보이도록 정했다(spec US4 AS1, FR-126, SC-020 수정). 남긴 글 상태를 따로 저장하지 않아도 "글 행이 있는 RELEASED 등록 = 남긴 글"로 표현되므로 스키마 변경이 없다. 다시 등록할 때 옮기지 않으면 첫 수집이 최근 30일 글을 새 행으로 만들어 포털에 같은 글이 두 번 나온다.
- **Alternatives**: 해제하면 선택과 관계없이 포털에서 내림(이전 기본값, marco가 바꿈), 남긴 글을 다시 등록 때 숨김(30일보다 오래된 글이 사라짐), "글 유지" 여부 컬럼 추가(행 존재로 충분, DDL 필요), 삭제 선택에도 30일 보관(주인 의사와 어긋남).

## E17. 신고 연동 (FR-127, FR-129, 005 FR-040·041)
- **Decision**: 005 `ReportTargetHandler` 두 구현:
  - `EXTERNAL_POST`: 신고자 확인(포털 노출 중인 글이면 누구나, 작성자 개념 없음 → `target_user_id` = 블로그의 `member_id`(없으면 NULL), `target_blog_id` NULL), 관리자 미리보기(제목·요약·블로그 이름·원문 링크·상태), 조치 `REMOVE_FROM_PORTAL` → `REMOVED`(`REPORT`, 005 data-model). `REMOVED`는 되돌리지 않는다(`unhide`는 409 `EXTERNAL_BLOG_STATE_CONFLICT`가 아니라 처리기에서 지원 안 함으로 표시 — 005 처리 화면에서 버튼 숨김). 되돌릴 수 있게 내려야 하면 관리자가 신고를 기각하고 외부 글 포털 제외(003 FR-093 방식, `PORTAL_EXCLUDE`)를 쓴다.
  - `EXTERNAL_BLOG`: 조치 `BLOCK_EXTERNAL_BLOG` → E16 차단(사유 = 신고 사유), 되돌리기는 지원하지 않음(콘솔에서 재개 불가 상태 — 차단 해제는 1.0 범위 밖, 결정 표).
  - 권리 침해 양식(비회원): 대상 주소가 `{서비스}/api/v1/external-posts/{id}/visit`이거나 외부 글 원문 링크와 같으면 005의 "주소 해석"이 대상으로 채운다(`ExternalPostReportHandler.resolveUrl`). 아니면 관리자가 대상 지정.
  - 카드의 "삭제 요청" 링크: 로그인 회원은 005 신고 레이어(`targetType=EXTERNAL_POST`), 비로그인은 `/rights-request?url={원문 링크}`.
- **Rationale**: 005가 대상 종류를 처리기 목록으로 열어 두었다(005 research M4). 007은 새 클래스만 더한다.
- **Alternatives**: 007 전용 삭제 요청 양식(005와 중복).

## E18. E2E와 CI (헌법 III, 사용자 지시 "E2E는 CI에서 실제로 돈다, 피드는 로컬 스텁")
- **Decision**:
  - 피드 스텁 서버 `blog-front/tests/e2e/support/feed-stub-server.mjs`(Node `node:http`, 의존성 없음, 포트 `E2E_FEED_STUB_PORT` 기본 4610, `127.0.0.1`에만 바인딩). Playwright `webServer`를 배열로 바꿔 front와 함께 띄운다. 제공: `/{name}/feed.xml`(RSS)·`/{name}/atom.xml`·`/{name}/`(HTML, `<link rel=alternate>`)·`/{name}/posts/{n}`(원문 글, 지우면 404)·`/{name}/img/{n}.png`(작은 PNG)·ETag/304. 시험 조작 API `POST /__stub/{name}` `{ title, items[], verifyCode?, status? }`, `DELETE /__stub/{name}/posts/{n}`. 도구 `tests/e2e/support/feedStub.ts`(`stubFeed(name, …)`, `stubUrl(name)`, `addItem`, `removePost`, `requireExternalTestSettings()`).
  - backend 실행 환경 변수(두 workflow의 "Start backend"): `BLOG_OUTBOUND_ALLOW_PRIVATE: "true"`(스텁이 127.0.0.1, prod 금지 규칙은 005), `BLOG_OUTBOUND_ALLOWED_PORTS: "80,443,8080,8443,4610"`, `BLOG_EXTERNAL_POLL_INTERVAL: 2s`, `BLOG_EXTERNAL_FETCH_INTERVAL: PT5S`, `BLOG_EXTERNAL_FETCH_JITTER: PT0S`, `BLOG_EXTERNAL_PREVIEW_PER_HOUR: "1000"`, `BLOG_EXTERNAL_VERIFY_CHECKS_PER_HOUR: "1000"`. E2E는 `BLOG_PORTAL_CACHE_TTL=0s`(003)를 그대로 쓴다.
  - Playwright 환경 변수: `E2E_EXTERNAL_TEST_SETTINGS: "1"`(위 backend 설정으로 띄웠다는 표시), `E2E_FEED_STUB_PORT: "4610"`.
  - 프로젝트 `external`(`testMatch: /external-.*\.spec\.ts$/`, `workers: 1`, `dependencies: ["portal"]` — 외부 글이 포털 최신 목록을 바꾸므로 포털 시나리오 뒤. 005·006이 먼저 머지되면 `moderation`·`admin` 뒤로).
  - 시나리오는 이름이 겹치지 않게 스텁 이름에 난수를 붙인다. 수집을 기다릴 때는 `expect.poll`(최대 30초, 수집 주기 5초 + 선택 주기 2초).
  - 내부망 차단은 E2E에서 확인할 수 없다(`allow-private=true`). backend 단위 시험(가짜 `HostResolver`)과 "우리 서비스 주소 거부"(E2E에서 `http://localhost:5173/...` 신청 → 422) 두 가지로 덮는다.
- **Rationale**: 인터넷의 실제 피드는 CI에서 흔들리고 상대 서버에 부담이다. 스텁이 front와 같은 러너에 있어 두 workflow 모두에서 같은 방식으로 돈다.
- **Alternatives**: Playwright `page.route`로 가로채기(요청은 backend가 보내므로 브라우저에서 가로챌 수 없음), backend 시험용 가짜 수집기(E2E가 실제 수집 경로를 거치지 않음).
