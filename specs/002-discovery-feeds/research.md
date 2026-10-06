# Research: 002 구독과 탐색

> 001 research.md에서 002용으로 미리 조사한 R9(검색), R15(RSS·Atom), R21(관련 글·공유)을 이 문서로 옮겨 D4·D6·D8·D9로 확정했다(001 research 머리말). 001 문서의 해당 절은 그대로 두며, 내용이 다르면 이 문서가 우선한다.
>
> 001의 결정(R1~R28: 인증, 프록시, SSR 구성, 노출 조각 `PostExposure`, 테스트 방식, 정기 작업, 보안 헤더, 다국어)은 그대로 따른다. 모든 API 경로는 `/api/v1` 접두어를 쓰며, 예외는 피드(`/{handle}/rss` 등)와 사이트맵·robots다([contracts/api.md](./contracts/api.md)).

버전 확인일: 2026-10-06 (Maven Central 기준)

## D1. 좋아요·구독 쓰기 (FR-030, FR-031)
- **Decision**:
  - API는 "내 좋아요"·"내 구독"을 회원 자원으로 보고 `PUT /me/likes/{postId}`·`DELETE /me/likes/{postId}`, `PUT /me/subscriptions/{handle}`·`DELETE /me/subscriptions/{handle}`로 둔다. 둘 다 멱등이며 200과 현재 상태(`liked`/`subscribed`)·수(`likeCount`/`subscriberCount`)를 돌려준다(api-guidelines와 다른 점은 contracts/api.md에 이유를 적었다).
  - 누르기: 한 트랜잭션에서 `INSERT IGNORE INTO post_likes (user_id, post_id, created_at)`를 실행하고 영향받은 행이 1일 때만 `UPDATE posts SET like_count = like_count + 1 WHERE id = ?`. 취소: `DELETE` 영향 행이 1일 때만 `like_count - 1`. 구독도 같은 방식(`blog_subscriptions`, `blogs.subscriber_count`). 엔티티를 읽어 값을 바꾸지 않고 원자적 UPDATE만 쓰므로 동시 요청에도 수가 어긋나지 않는다.
  - 카운터 컬럼(`posts.like_count`, `blogs.subscriber_count`)은 엔티티에 읽기 전용(`insertable=false, updatable=false`, H2용 `@ColumnDefault("0")`)으로 매핑한다.
  - 좋아요 대상: 발행(PUBLISHED)되었고 요청한 회원이 상세를 볼 수 있는 글(`PostExposure.isDetailVisibleTo`). 아니면 404 `POST_NOT_FOUND`. 자기 글 좋아요는 막지 않는다(스펙에 금지 규칙 없음). 취소는 글 상태와 관계없이 된다(비공개로 바뀐 글의 좋아요도 취소 가능).
  - 구독 대상: ACTIVE 블로그이고 주인이 ACTIVE(`BlogAccess.requireVisibleBlog`), 아니면 404 `BLOG_NOT_FOUND`. 블로그 주인이 요청한 회원이면 422 `CANNOT_SUBSCRIBE_OWN_BLOG`(FR-031, AS3. front는 버튼을 숨긴다). 취소는 handle이 있는 블로그면(삭제·정지 포함) 된다.
  - 탈퇴(001 FR-009, `DELETE /me`): 같은 트랜잭션에서 그 회원의 구독 행을 지우고 각 블로그의 `subscriber_count`를 줄인다(구독자 수가 실제 회원만 세도록). 좋아요 행은 남긴다(002 data-model).
- **Rationale**: PK 중복을 예외로 잡는 방식은 트랜잭션이 롤백 전용이 되어 같은 트랜잭션에서 카운터를 다룰 수 없다. `INSERT IGNORE`는 H2(MySQL 모드)에서도 동작하므로 H2 Repository 테스트로 확인하고, 동시성만 테스트 MySQL에서 확인한다.
- **Alternatives**: 토글 API 하나(`POST /posts/{id}/like`, 멱등이 아님·두 탭에서 엇갈림), 카운터를 `COUNT(*)`로 매번 계산(003 포털 목록에서 비쌈), 엔티티 필드 증감(동시 요청 시 갱신 손실).

## D2. 구독 피드 (FR-032)
- **Decision**: `GET /me/feed?page=&size=` 페이지 목록. QueryDSL 한 쿼리로 `post JOIN blog JOIN user JOIN blog_subscriptions(bs.blog = blog AND bs.user.id = :me)`를 `PostExposure.listable()`로 거르고 `published_at DESC, id DESC`로 정렬, DTO projection(PostSummary + 블로그 handle·title + 작성자 닉네임·프로필). 태그는 001처럼 `TagQueryRepository.findTagNames`로 한 번에. 쿼리 3회(목록, 전체 수, 태그) 고정.
  - 정지·탈퇴 회원과 삭제된 블로그의 글은 노출 조각으로 자동으로 빠진다(Edge Cases). 따로 저장하는 피드 테이블은 없다(data-model).
  - 페이지 방식(`page`, `totalCount`)을 쓴다. 001 블로그 목록과 같은 `Pagination` 컴포넌트를 재사용한다.
- **Rationale**: 회원당 구독 수가 수십~수백이면 `idx_posts_blog_status_visibility_published`와 `idx_blog_subscriptions_blog`로 충분하다. 커서 방식(api-guidelines 4절)은 무한 스크롤 화면용이며 지금 화면은 페이지 이동이다.
- **Alternatives**: 커서 방식(새 글이 생기면 페이지가 밀리는 문제는 없지만 화면·도구가 새로 필요, 003 포털 피드 때 검토), 팬아웃 저장(쓰기 증폭, 지금 규모에 불필요).

## D3. 알림 (FR-033)
- **Decision**:
  - 002가 만드는 종류는 `NEW_COMMENT`, `NEW_SUBSCRIBER` 둘이다. 나머지 다섯 종류(BACKUP_READY, EXTERNAL_*, REPORT_RESOLVED)는 004·005·007이 같은 테이블·API·화면에 행과 문구를 더한다. backend `NotificationType` enum에는 002의 두 값만 두고, front는 모르는 `type`을 공통 문구("새 알림")로 보여준다.
  - 생성: 댓글 작성(`CommentService.create`)과 구독(`SubscriptionService.subscribe`, 실제로 행이 생긴 경우)이 도메인 이벤트(`CommentCreatedEvent`, `BlogSubscribedEvent`)를 발행하고, `NotificationEventListener`가 `@TransactionalEventListener(phase = AFTER_COMMIT)` + `@Transactional(propagation = REQUIRES_NEW)`로 알림 행을 만든다. 같은 스레드에서 동기로 실행하며, 실패는 로그만 남기고 원래 요청(댓글·구독)은 성공으로 둔다. 커밋된 이벤트당 한 번만 실행되므로 중복 생성이 없다(data-model).
  - 받는 회원: NEW_COMMENT는 글이 속한 블로그의 주인(댓글·답글 모두, 작성자가 주인이면 만들지 않음). 답글의 대상 댓글 작성자에게는 보내지 않는다(스펙 종류에 없음). NEW_SUBSCRIBER는 블로그 주인.
  - 구독·취소를 반복해 알림이 쌓이지 않도록, 같은 구독자(`actor_user_id`)·같은 블로그의 NEW_SUBSCRIBER 알림이 최근 `blog.notifications.subscriber-dedup-window`(기본 24h) 안에 있으면 새로 만들지 않는다.
  - `params_json`: NEW_COMMENT `{ postId, postTitle }`(비회원 댓글은 004가 `guestName`을 더함), NEW_SUBSCRIBER `{ blogTitle }`. 만들 때의 값을 저장하며 번역하지 않는다.
  - 읽음: 알림 하나(`POST /me/notifications/{id}/read`)와 일괄(`POST /me/notifications/bulk`, `ids` 생략 시 지금까지의 안 읽은 알림 전부). 안 읽은 수는 `GET /me`의 `unreadNotificationCount`로 준다(001 root loader가 이미 매 화면 `/me`를 부르므로 호출이 늘지 않는다). 실시간 알림은 범위 밖(spec Assumptions).
  - 보관: `NotificationPurgeJob`(`blog.jobs.notification-purge-cron` 기본 `0 15 4 * * *`)이 `created_at < now - blog.notifications.retention(90d)` 행을 건수 단위(`blog.jobs.purge-batch-size`)로 지운다. 001 개인정보 파기 작업(`PrivacyPurgeJob`)이 파기하는 회원의 알림을 함께 지운다. 알림을 일으킨 회원이 탈퇴(WITHDRAWN)면 응답의 `actor.withdrawn = true`, 닉네임·프로필은 null(front는 "탈퇴한 회원").
- **Rationale**: 댓글·구독 서비스가 알림을 직접 부르면 의존 방향이 뒤집히고 롤백 시 알림만 남을 수 있다. 커밋 후 이벤트는 Spring 기본 기능이라 새 라이브러리가 없다. 비동기(`@Async`)는 테스트와 순서 보장이 어려워지고 지금 부하에서는 이득이 없다.
- **Alternatives**: 같은 트랜잭션 안에서 생성(알림 실패가 댓글을 롤백), 메시지 큐(실행 파트 추가, 원칙 II·VI 위반), 알림 문구를 backend에서 생성(원칙 VII 위반).

## D4. 검색 (FR-035, SC-007) — 001 R9를 옮겨 확정
- **Decision**:
  - MySQL FULLTEXT(ngram, token size 2)를 쓴다. 인덱스는 이미 스키마에 있다: `ft_posts_title_content (title, content_text)`, `ft_posts_title (title)`, `ft_tags_name (name)`.
  - 검색어 해석(`SearchQueryParser`): 앞뒤 공백 제거 후 2~100자(아니면 400 `VALIDATION_FAILED`, field `q`, `TOO_SHORT`/`TOO_LONG`). 공백으로 나눈 낱말 중 2자 이상만 최대 5개(`blog.search.max-terms`)를 쓰고, 남는 낱말이 없으면 400(`TOO_SHORT`). 각 낱말은 BOOLEAN MODE 연산자 문자(`+ - < > ( ) ~ * " @`)를 지운 뒤 `+"낱말"`로 묶는다(모든 낱말을 포함, 낱말 안은 ngram 구문 일치).
  - 일치 조건(한 글은 아래 중 하나면 결과에 든다):
    1. 본문 노출 가능(`PostExposure.bodyVisible()`) AND `MATCH(title, content_text) AGAINST(:q IN BOOLEAN MODE)`
    2. 본문 노출 가능 AND 글의 태그 중 `MATCH(tags.name) AGAINST(:q IN BOOLEAN MODE)`인 것이 있음(EXISTS 하위 쿼리)
    3. 목록 노출 가능(`listable()`) AND NOT 본문 노출 가능(= 004 이후의 보호 글) AND `MATCH(title) AGAINST(:q IN BOOLEAN MODE)` — 보호 글은 제목만 검색하고 결과도 제목만(`summary`·`thumbnailUrl` null) 준다(FR-035, 글 노출 매트릭스).
     002 시점에는 `listable()`이 PUBLIC만 포함하므로 3번은 결과가 없지만 쿼리에 미리 둔다. 004가 `PostExposure.LISTABLE_VISIBILITIES`에 PROTECTED를 더하면 그대로 동작한다.
  - 정렬은 발행 최신순(`published_at DESC, id DESC`)이다. ngram 관련도 점수는 짧은 낱말에서 순서가 들쭉날쭉하고, 페이지가 안정적인 최신순이 독자에게 예측 가능하다.
  - 낱말은 필드별로 따로 맞춘다. "spring"이 제목에, "jpa"가 태그에만 있는 글은 1·2번 어느 쪽에도 모든 낱말이 있지 않으므로 나오지 않는다(받아들인 한계, 결정 표).
  - 구현: Hibernate 7 `FunctionContributor`(`MySqlFullTextFunctions`, `META-INF/services` 등록)로 `match_title_content(title, contentText, q)`, `match_title(title, q)`, `match_tag(name, q)`를 `MATCH(...) AGAINST (? IN BOOLEAN MODE)`로 렌더링하는 함수를 등록하고, QueryDSL `Expressions.numberTemplate(Double.class, "match_title_content({0}, {1}, {2})", ...)`.gt(0)로 쓴다. 이렇게 하면 노출 조건이 `PostExposure` 한 곳에만 있다(원칙 IV). 결과는 001과 같은 DTO projection, 태그는 `findTagNames`로 일괄. 쿼리 3회(목록, 전체 수, 태그).
  - 테스트: FULLTEXT는 H2에 없으므로 검색 Repository는 `@MySqlRepositoryTest`(환경 변수 없으면 건너뜀)만 쓴다. 검색어 해석·서비스·컨트롤러는 단위·슬라이스 테스트.
  - 성능(SC-007): 글 10만 편에서 p95 2초. 폴리시 단계에서 측정해 PR에 기록(001 T246과 같은 방식).
- **Rationale**: 별도 검색 엔진 없이 MySQL 하나로(원칙 VI), 001에서 인덱스를 이미 만들어 두었다.
- **Alternatives**: Elasticsearch·OpenSearch(별도 인프라), `LIKE '%q%'`(10만 건에서 2초 목표 불확실, 인덱스 못 씀), 네이티브 SQL 문자열(노출 조건을 한 번 더 써야 함), NATURAL LANGUAGE MODE(ngram에서 낱말 일부만 겹쳐도 맞아 결과가 지나치게 많음).

## D5. 사이트맵과 robots (FR-037)
- **Decision**:
  - backend가 생성하고 front가 프록시한다(001 contracts/routes.md 프록시 표에 이미 있음). JDK StAX(`XMLStreamWriter`)로 쓰며 새 라이브러리는 없다.
  - `/sitemap.xml`: 사이트맵 색인(sitemapindex). `/sitemap/pages.xml`(서비스 고정 화면 `/`, `/terms`, `/privacy`와 본문 노출 가능 글이 1편 이상인 블로그 홈), `/sitemap/posts-{n}.xml`(본문 노출 가능 글, `id` 오름차순, 파일당 `blog.sitemap.urls-per-file` 기본 50,000개, 표준 상한)을 가리킨다.
  - 각 `<url>`은 `<loc>`(절대 주소, `blog.base-url`)와 `<lastmod>`(글은 `updated_at`, 블로그 홈은 그 블로그 글의 가장 최근 `published_at`)만 넣는다. `changefreq`·`priority`는 검색 엔진이 무시하므로 넣지 않는다.
  - 서버 캐시는 두지 않는다. 요청마다 노출 조각으로 다시 조회한다(비공개로 바뀐 글이 남지 않게, SC-004). 응답은 `Content-Type: application/xml; charset=UTF-8`, `Cache-Control: no-cache`, `Last-Modified`. 범위를 벗어난 `n`은 404.
  - `/robots.txt`(`text/plain`): 모든 크롤러 허용, 로그인·개인 화면 차단(`/api/`, `/login`, `/signup`, `/password-reset`, `/settings`, `/write`, `/manage`, `/*/write`, `/*/manage`, `/feed`, `/notifications`, `/search`), 마지막 줄 `Sitemap: {base-url}/sitemap.xml`.
- **Rationale**: 글 10만 편은 파일 2~3개이고 id 순 조회라 요청마다 만들어도 가볍다. 캐시를 두면 비공개 전환 뒤에도 주소가 남는다.
- **Alternatives**: 정기 작업으로 정적 파일 생성(파일 관리·배포 경로가 늘어남), front에서 생성(데이터 로직이 front로 새어 원칙 II 위반).

## D6. RSS·Atom 피드 (FR-044~048, SC-008) — 001 R15를 옮겨 확정
- **Decision**:
  - ROME `com.rometools:rome` 2.1.0(확인 시점 최신 정식)으로 `SyndFeed`를 만들고 `WireFeedOutput`으로 RSS 2.0(`rss_2.0`)·Atom 1.0(`atom_1.0`)을 쓴다. 007(외부 블로그 수집)도 같은 라이브러리로 피드를 읽는다(007 research E1).
  - 경로(`/api/v1` 밖, backend `syndication` 패키지의 `FeedController`): `GET /{handle}/rss`, `GET /{handle}/atom`, `GET /{handle}/category/{categoryId}/rss`. 카테고리 피드는 001 contracts/routes.md 목록대로 RSS만 둔다. 상위 카테고리 피드는 하위 카테고리 글을 포함한다(001 결정 4).
  - 담는 글: `PostExposure.listable()`인 글을 발행 최신순으로 `blogs.feed_item_count`(10·20·30·50, 기본 20)개. 각 글은
    - 본문 노출 가능 + FULL: 제목, 링크, 본문 HTML(`content_html`), 발행 시각, 수정 시각, 카테고리·태그(`<category>`), 작성자 닉네임
    - 본문 노출 가능 + SUMMARY: 본문 대신 `summary`
    - 본문 노출 가능이 아님(004 보호 글): 제목·링크·시각만(본문·요약 없음, FR-047)
  - 본문 HTML 안의 상대 주소(`/media/...`, `/{handle}/...`)는 `blog.base-url` 기준 절대 주소로 바꾼다(`FeedContentUrlRewriter`). 리더는 피드 주소의 출처를 모르기 때문이다. 살균은 001에서 저장할 때 이미 했다.
  - RSS: `<channel>`에 `<title>`(블로그 제목, 카테고리 피드는 `{카테고리} - {블로그 제목}`), `<link>`(블로그 홈 또는 카테고리 주소), `<description>`(블로그 소개, 없으면 제목), `<atom:link rel="self">`, `<lastBuildDate>`; `<item>`에 `<guid isPermaLink="true">`(글 주소), `<pubDate>`, `<dc:creator>`(이메일을 쓰는 `<author>` 대신). Atom: `<id>`(피드·글 주소), `<updated>`, `<author><name>`, `<link rel="self">`·`<link rel="alternate">`, `<content type="html">` 또는 `<summary>`.
  - 조건부 요청(Edge Cases "변경 없음"): 담을 글의 `(id, updated_at)` 목록과 블로그 설정(`title`, `description`, `feed_item_count`, `feed_content_mode`, `updated_at`)으로 만든 SHA-256 약한 ETag와 `Last-Modified`(그중 가장 늦은 시각)를 붙이고, `ServletWebRequest.checkNotModified(etag, lastModified)`로 304를 준다. 304 판단에는 가벼운 조회(id·updated_at만) 1회, 바뀌었을 때만 본문 조회 1회 + 태그 1회.
  - 서버 캐시는 두지 않는다(001 R15의 "5분 캐시"를 바꿈): 글을 비공개로 돌리거나 회원이 정지되면 다음 요청부터 피드에서 빠져야 한다(SC-004). 응답 헤더는 `Cache-Control: no-cache`(매번 ETag로 재검증).
  - `Content-Type`: `application/rss+xml; charset=UTF-8`, `application/atom+xml; charset=UTF-8`. 없는 블로그·카테고리, 삭제된 블로그, 정지·탈퇴 회원의 블로그는 404(본문은 공통 응답 틀 JSON. 리더는 상태 코드만 본다).
  - 피드 설정(FR-046)은 `PATCH /blogs/{handle}`에 `feedItemCount`·`feedContentMode`를 더한다(블로그 설정의 일부, 006 FR-099 "피드 설정" 메뉴가 이 API를 쓴다).
  - 검증(SC-008): 단위 테스트가 ROME `SyndFeedInput`으로 다시 읽어 필수 요소·날짜 형식(RFC 822 / RFC 3339)·절대 주소·guid 유일성을 확인하고, quickstart에서 W3C Feed Validation Service(직접 입력)로 오류 0건을 확인한다. CI는 외부 서비스에 의존하지 않는다.
- **Rationale**: 날짜 형식·이스케이프·네임스페이스를 손으로 맞추면 검증기 오류가 나기 쉽다. ROME은 RSS·Atom을 함께 다루는 사실상 표준 Java 라이브러리이며 007에서도 필요하다.
- **Alternatives**: StAX로 직접 작성(새 의존성은 없지만 두 형식의 규칙을 직접 유지해야 함), front에서 생성(원칙 II 위반), 5분 서버 캐시(SC-004와 충돌).

## D7. 피드 자동 발견 (FR-048)
- **Decision**: 블로그 홈(`/:handle`)과 글 상세(`/:handle/:postId`)는 라우트 `meta`에서 `{ tagName: "link", rel: "alternate", type: "application/rss+xml", title, href }`와 Atom 링크를 SSR로 출력한다. 카테고리 화면(`/:handle/category/:categoryId`)은 그 카테고리 RSS를 먼저, 블로그 피드를 다음에 넣는다. `href`는 `publicOrigin` 기준 절대 주소. 도우미는 `blog-front/app/seo/feedLinks.ts`.
- **Rationale**: React Router의 `links` 함수는 loader 데이터를 받지 못하므로, 001이 canonical을 `meta`의 `tagName: "link"`로 넣는 방식과 같게 한다.

## D8. 관련 글 (FR-068) — 001 R21을 옮겨 확정
- **Decision**: `GET /posts/{id}/related` → 최대 5편의 PostSummary. 기준 글을 볼 수 있어야 하며(아니면 404 `POST_NOT_FOUND`), 후보는 같은 블로그의 본문 노출 가능 글(자기 자신 제외). 점수 = 겹치는 태그 수 + (같은 카테고리면 1). 점수 0인 글은 넣지 않는다. 정렬은 점수 내림차순, 발행 최신순. QueryDSL 한 쿼리(`post_tags` LEFT JOIN 집계 + 카테고리 비교 `CASE`) + 태그 1회.
  - 서버 캐시는 두지 않는다(001 R21의 "10분 캐시"를 바꿈). 블로그 안에서만 계산하므로 가볍고, 캐시가 있으면 비공개로 바뀐 글이 남는다.
- **Alternatives**: 본문 유사도(FULLTEXT 관련도, 계산 비용·결과 품질 불확실), 서비스 전체 범위(스펙은 같은 블로그).

## D9. 공유 (FR-069) — 001 R21을 옮겨 확정
- **Decision**:
  - 주소 복사: Clipboard API(`navigator.clipboard.writeText`), 쓸 수 없으면 주소를 선택된 입력란으로 보여준다.
  - X: `https://twitter.com/intent/tweet?url={주소}&text={제목}`, 페이스북: `https://www.facebook.com/sharer/sharer.php?u={주소}`. 일반 링크(`target="_blank" rel="noopener noreferrer"`)라 JS 없이도 동작한다.
  - 카카오톡: 공유 URL 방식이 없어 Kakao JavaScript SDK 2.x(`Kakao.Share.sendDefault`, 피드 템플릿: 제목·요약·대표 이미지 1200x630·글 주소)를 쓴다. SDK는 공식 CDN(`https://t1.kakaocdn.net/kakao_js_sdk/{버전}/kakao.min.js`)에서 공유 버튼을 처음 누를 때만 SRI(`integrity`)와 함께 불러온다(`blog-front/app/share/kakao.client.ts`). 버전과 SRI 해시는 도입하는 PR에서 고정한다.
  - 앱 키: front 환경 변수 `BLOG_KAKAO_JS_KEY`(JavaScript 키, 공개 값이지만 도메인 등록이 필요). root loader가 브라우저로 넘기고, 값이 없으면 카카오톡 버튼을 숨긴다. Kakao Developers에 `blog.java21.net` 도메인을 등록하는 일은 운영 작업(marco)이다.
  - CSP(001 R27): 키가 있을 때만 `script-src`에 `https://t1.kakaocdn.net`, `connect-src`(새로 명시, 기본 `'self'`)에 `https://kapi.kakao.com`을 더한다. 공유 창(`sharer.kakao.com`)은 새 창 이동이라 CSP 대상이 아니다. 실제 필요한 출처는 E2E·수동 확인으로 확정하고 다르면 이 절을 고친다.
  - 공유 미리보기 정보: 001 글 상세 `meta`의 `og:title`·`og:description`(요약)·`og:image`(대표 이미지 1200x630 썸네일)·`og:url`·`twitter:card`를 그대로 쓰고, 대표 이미지가 없을 때 `twitter:card=summary`를 넣는다.
- **Rationale**: 카카오톡은 한국 독자의 주요 공유 경로이고 SDK 외 방법이 없다(spec Assumptions, 001 R21). 지연 로딩으로 공유하지 않는 방문자에게는 외부 스크립트가 실행되지 않는다.
- **Alternatives**: 카카오톡 빼기(FR-069 미충족), Web Share API만 사용(데스크톱 지원이 고르지 않음, 보조 수단으로만 쓰지 않음).

## D10. front 화면과 다국어 (원칙 V·VII)
- **Decision**:
  - 새 라우트: `/search`(SSR, noindex), `/feed`(로그인, noindex), `/notifications`(로그인, noindex), `/:handle/manage/feed`(블로그 관리 "피드 설정"). 모두 001 contracts/routes.md 기준 목록과 예약어에 이미 있다(예약어 변경 없음).
  - 좋아요·구독은 해당 화면 라우트의 `action`(`intent=like|unlike|subscribe|unsubscribe`)으로 폼 전송해 JS 없이도 동작한다. 비로그인은 버튼 대신 `/login?next=` 링크.
  - 공통 상단(001 `Header`): 검색창(`GET /search`), 로그인 회원에게 "구독 피드"와 알림 링크(안 읽은 수 배지, 99개 넘으면 "99+").
  - 번역 namespace 2개를 새로 둔다: `discovery`(좋아요·구독·구독 피드·검색·관련 글·공유·피드 자동 발견 제목), `notification`(알림 종류별 문구 `notification:types.{TYPE}`, 공통 "새 알림"). 피드 설정 화면 문구는 001의 `manage` namespace에 더한다. 새 오류 코드는 `errors.json`과 `blog-front/app/api/errorCodes.ts`에 4개 언어로 함께 넣는다.
  - 화면의 응답 타입은 001처럼 `blog-front/app/api/models.ts`에 계약 문서를 옮겨 적는다(OpenAPI 생성 스크립트는 001 후속 메모대로 아직 없음).

## D11. 테스트 전략 (원칙 III)
- **Decision**:
  - Repository: `@JpaRepositoryTest`(H2)로 좋아요·구독 쓰기(`INSERT IGNORE`·카운터), 구독 피드, 알림 목록·안 읽은 수·정리, 사이트맵·피드·관련 글 조회를 확인하고 모든 목록 쿼리에 `QueryCounter.assertQueryCount`를 둔다. `@MySqlRepositoryTest`는 검색(FULLTEXT)과 좋아요·구독 동시성(같은 회원 20회 동시 PUT → 행 1, 카운터 1)만.
  - Service: Mockito 단위(노출·권한·멱등·이벤트 발행·알림 받는 사람 규칙·검색어 해석).
  - Controller: `@WebMvcTest` + `WebMvcTestSupport`로 상태 코드·공통 틀·401/404/422, 피드·사이트맵은 XML 형식·`Content-Type`·304.
  - 통합(`@SpringBootTest`, H2): 노출 매트릭스를 구독 피드·RSS·Atom·사이트맵·관련 글에서 한 번에 확인(SC-004). 검색은 MySQL 전용이므로 `@MySqlRepositoryTest` 쪽 노출 테스트로 따로 확인.
  - front: Vitest + Testing Library(각 라우트의 loader·action·meta·화면), Playwright E2E는 스토리별 Independent Test를 실제 backend(`E2E_BACKEND_URL`, 001 `tests/e2e/support/backend.ts`)로 실행. JaCoCo·Vitest 라인 80% 게이트 유지.
