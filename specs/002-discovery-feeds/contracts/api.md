# API Contract: 002 구독과 탐색

002가 더하는 엔드포인트와 001 응답의 확장만 적는다. 기준 경로·인증·Origin 검사·공통 응답 틀·오류 형식·페이지 규칙은 [001 contracts/api.md](../../001-blog-core/contracts/api.md)와 [REST API 설계 규칙](../../../api-guidelines.md)을 따른다.

- 모든 API 경로는 `/api/v1`로 시작한다(아래 표의 경로는 이 접두어를 뺀 것). 예외는 블로그 피드(`/{handle}/rss` 등)와 사이트맵·robots이며, 이들은 성공 시 표준 형식(XML·텍스트)을 그대로 쓴다(설계 규칙 4절 예외 경로).
- 표의 "응답"은 공통 틀 `{ header, result, totalCount? }`의 `result`에 들어가는 내용이다. "Page<X>"는 `result`가 X 배열, `totalCount`가 전체 개수이며 `page`는 0부터, `size`는 기본 20·최대 50이다.
- "로그인" 권한 API는 로그인하지 않으면 401 `UNAUTHENTICATED`. 로그인이 필요한 응답에는 `Cache-Control: no-store`(설계 규칙 8절).
- 이 문서가 기준이며, 구현 후 springdoc OpenAPI와 일치해야 한다.

## 오류 코드 (002에서 추가)

001 표의 코드는 그대로 쓴다(`POST_NOT_FOUND`, `BLOG_NOT_FOUND`, `CATEGORY_NOT_FOUND`, `VALIDATION_FAILED`, `UNAUTHENTICATED` 등).

| HTTP | resultCode | 상황 |
|---|---|---|
| 404 | NOTIFICATION_NOT_FOUND | 없는 알림, 또는 다른 회원의 알림 (FR-033) |
| 422 | CANNOT_SUBSCRIBE_OWN_BLOG | 내가 가진 블로그(어느 블로그든)를 구독하려 함 (FR-031, AS3) |

새 `fieldErrors[].code`는 없다. 검색어 길이는 `TOO_SHORT`·`TOO_LONG`(`params: { min: 2 }`·`{ max: 100 }`), 피드 글 수가 허용 값이 아니면 `INVALID`(`params: { allowed: [10, 20, 30, 50] }`)를 쓴다.

## 설계 규칙과 다르게 만든 것

| 항목 | 규칙 | 002 | 이유 |
|---|---|---|---|
| `DELETE /me/likes/{postId}`, `DELETE /me/subscriptions/{handle}` | DELETE는 `result: null`, 이미 없으면 404 | 200 + 현재 상태(`liked: false` 등)·수. 이미 없어도 200 | 좋아요·구독은 두 탭·두 번 누름에서 PUT·DELETE가 엇갈리기 쉽다. 결과 상태로 수렴하는 멱등 동작이 화면을 단순하게 하고, 바뀐 수를 다시 조회하지 않게 한다 (research D1) |
| 피드·사이트맵 오류 | - | 성공은 XML·텍스트, 오류(404 등)는 공통 틀 JSON | 리더·크롤러는 상태 코드만 본다. 오류 처리를 001 `GlobalExceptionHandler` 하나로 유지한다 |

## 001 응답 확장

필드 추가만 한다(설계 규칙 9절, v1 안에서 허용).

| API | 추가 필드 | 내용 |
|---|---|---|
| GET /me | `unreadNotificationCount: number` | 안 읽은 알림 수(FR-033). 상단 알림 배지에 쓴다 |
| GET /blogs/{handle} | `subscriberCount: number` | 구독자 수(`blogs.subscriber_count`, FR-031) |
| | `subscribedByMe: boolean \| null` | 로그인 회원이 구독 중이면 true, 아니면 false, 비로그인이면 null |
| | `feedItemCount: 10 \| 20 \| 30 \| 50` | 피드에 담을 글 수(FR-046, 기본 20) |
| | `feedContentMode: "FULL" \| "SUMMARY"` | 피드 공개 형태(FR-046, 기본 FULL) |
| PATCH /blogs/{handle} (요청) | `feedItemCount?`, `feedContentMode?` | 주인만. 둘 다 `null`로 지울 수 없다(400 `VALIDATION_FAILED`, `REQUIRED`). `feedItemCount`가 10·20·30·50이 아니면 `INVALID`. 응답은 위 GET과 같음 |
| GET /posts/{id} (PostDetail) | `likeCount: number` | 좋아요 수(`posts.like_count`, FR-030) |
| | `likedByMe: boolean \| null` | 로그인 회원이 누른 글이면 true, 아니면 false, 비로그인이면 null |

`subscribedByMe`·`likedByMe` 때문에 두 GET은 요청한 사람에 따라 응답이 다르다. 공개 GET이지만 `Cache-Control: private, no-cache`로 준다.

## 좋아요 (like) — FR-030

| 메서드 | 경로 | 권한 | 요청 | 응답 |
|---|---|---|---|---|
| PUT | /me/likes/{postId} | 로그인 | - | 200 `{ postId, liked: true, likeCount }`. 이미 누른 글이면 바뀌지 않고 같은 응답(멱등). 발행되지 않았거나 이 회원이 상세를 볼 수 없는 글은 404 `POST_NOT_FOUND` |
| DELETE | /me/likes/{postId} | 로그인 | - | 200 `{ postId, liked: false, likeCount }`. 누르지 않은 글이어도 200(멱등). 글 상태와 관계없이 취소된다. 글이 아예 없으면 404 `POST_NOT_FOUND` |

규칙: 좋아요 행 추가·삭제와 `posts.like_count` ±1은 한 트랜잭션이며, 행이 실제로 생기거나 지워질 때만 수를 바꾼다(research D1). 자기 글에도 누를 수 있다.

## 구독 (subscription) — FR-031, FR-032

| 메서드 | 경로 | 권한 | 요청 | 응답 |
|---|---|---|---|---|
| PUT | /me/subscriptions/{handle} | 로그인 | - | 200 `{ handle, subscribed: true, subscriberCount }`. 이미 구독 중이면 같은 응답(멱등). 블로그가 없거나 삭제·주인 정지·탈퇴면 404 `BLOG_NOT_FOUND`, 내 블로그면 422 `CANNOT_SUBSCRIBE_OWN_BLOG`. 새로 구독했으면 블로그 주인에게 NEW_SUBSCRIBER 알림(아래) |
| DELETE | /me/subscriptions/{handle} | 로그인 | - | 200 `{ handle, subscribed: false, subscriberCount }`. 구독하지 않았어도 200. handle이 있는 블로그면 상태와 관계없이 취소된다. handle이 아예 없으면 404 `BLOG_NOT_FOUND` |
| GET | /me/feed?page=&size= | 로그인 | - | 200 Page<FeedPost> (구독한 블로그들의 "목록 노출 가능" 글, 발행 최신순. 정지·탈퇴 회원·삭제된 블로그의 글은 빠짐) |

`FeedPost`: PostSummary(001) + `{ blog: { handle, title }, author: { nickname, profileImageUrl } }`. PostSummary의 `hasDraft`는 항상 false, 본문 노출 가능이 아닌 글(004 보호 글)은 `summary`·`thumbnailUrl`이 null.

규칙: 구독 행 추가·삭제와 `blogs.subscriber_count` ±1은 한 트랜잭션. 회원이 탈퇴하면 그 회원의 구독 행을 지우고 수를 줄인다(research D1).

## 알림 (notification) — FR-033

| 메서드 | 경로 | 권한 | 요청 | 응답 |
|---|---|---|---|---|
| GET | /me/notifications?page=&size= | 로그인 | - | 200 Page<Notification> (내 알림, 최신순. 내 여러 블로그의 알림이 함께 나온다) |
| POST | /me/notifications/{id}/read | 로그인 | - | 200 Notification(`read: true`). 이미 읽었으면 그대로. 다른 회원의 알림·없는 알림은 404 `NOTIFICATION_NOT_FOUND` |
| POST | /me/notifications/bulk | 로그인 | `{ action: "MARK_READ", ids?: [id] }` | 200 `{ updated: n }`. `ids`를 생략하면 지금까지의 안 읽은 알림 전부, 있으면 그중 내 알림만(최대 100개, 넘으면 400 `VALIDATION_FAILED`) |

`Notification`:
```json
{
  "id": 501,
  "type": "NEW_COMMENT",
  "actor": { "userId": 7, "nickname": "독자", "profileImageUrl": null, "withdrawn": false },
  "blog": { "handle": "marco", "title": "마르코의 블로그" },
  "targetType": "COMMENT",
  "targetId": 3001,
  "params": { "postId": 123, "postTitle": "첫 글" },
  "read": false,
  "createdAt": "2026-10-06T04:24:19Z"
}
```
- `type`: 002가 만드는 값은 `NEW_COMMENT`, `NEW_SUBSCRIBER`. 이후 스펙이 `BACKUP_READY`(004), `EXTERNAL_BLOG_APPROVED`·`EXTERNAL_BLOG_REJECTED`·`EXTERNAL_FEED_STOPPED`(007), `REPORT_RESOLVED`(005)를 더한다(data-model 표). front는 모르는 값을 공통 문구로 보여준다.
- `actor`: 알림을 일으킨 회원. 비회원·시스템이면 null. 탈퇴 회원이면 `{ userId, nickname: null, profileImageUrl: null, withdrawn: true }`.
- `blog`: 관련된 내 블로그. 삭제된 블로그도 handle은 준다(화면은 링크 없이 제목만).
- `params`: 만들 때 저장한 값(번역하지 않음). NEW_COMMENT `{ postId, postTitle }`, NEW_SUBSCRIBER `{ blogTitle }`.
- 화면 링크는 front가 만든다: NEW_COMMENT → `/{blog.handle}/{params.postId}#comment-{targetId}`, NEW_SUBSCRIBER → `/{blog.handle}`. 대상이 지워졌으면 그 화면의 404를 따른다(data-model).

알림 생성 규칙(research D3):
- NEW_COMMENT: 글에 댓글·답글이 저장(커밋)된 뒤, 글이 속한 블로그의 주인에게. 작성자가 주인이면 만들지 않는다.
- NEW_SUBSCRIBER: 구독 행이 새로 생긴(커밋) 뒤, 블로그 주인에게. 같은 구독자·같은 블로그의 NEW_SUBSCRIBER가 `blog.notifications.subscriber-dedup-window`(24h) 안에 있으면 만들지 않는다.
- 알림 생성이 실패해도 댓글·구독은 성공으로 끝난다(로그만 남김).

## 검색 (search) — FR-035, SC-007

| 메서드 | 경로 | 권한 | 요청 | 응답 |
|---|---|---|---|---|
| GET | /search/posts?q=&page=&size= | 모두 | - | 200 Page<SearchPost>. 서비스 전체 "목록 노출 가능" 글 중 제목·본문·태그에 검색어가 있는 글(보호 글은 제목만), 발행 최신순 |

- `q`: 앞뒤 공백을 뺀 뒤 2~100자(아니면 400 `VALIDATION_FAILED`, field `q`, `TOO_SHORT`/`TOO_LONG`). 공백으로 나눈 낱말 중 2자 이상만 최대 5개를 쓰며 모든 낱말을 포함한 글만 나온다. 2자 이상 낱말이 없으면 400(`TOO_SHORT`). 낱말은 제목+본문, 태그 이름, (보호 글) 제목 중 한 곳에 모두 있어야 한다(research D4).
- `SearchPost`: PostSummary(001) + `{ blog: { handle, title } }`. 보호 글은 `summary`·`thumbnailUrl`이 null.
- 비공개·임시저장·예약·삭제·숨김 글과 정지·탈퇴 회원·삭제된 블로그의 글은 나오지 않는다(AS2, 001 글 노출 매트릭스).

## 관련 글 (related) — FR-068

| 메서드 | 경로 | 권한 | 요청 | 응답 |
|---|---|---|---|---|
| GET | /posts/{id}/related | 글을 볼 수 있는 사람 | - | 200 `[PostSummary]`(최대 5편). 같은 블로그의 "본문 노출 가능" 글 중 이 글과 태그가 겹치거나 카테고리가 같은 글. 점수(겹치는 태그 수 + 같은 카테고리 1) 내림차순, 같으면 발행 최신순. 없으면 `[]`. 이 글을 볼 수 없으면 404 `POST_NOT_FOUND` |

## 블로그 피드 (RSS·Atom) — FR-044~048, SC-008

접두어 `/api/v1` 없음. front 서버가 같은 경로를 backend로 프록시한다(001 contracts/routes.md 프록시 표).

| 메서드 | 경로 | 권한 | 응답 |
|---|---|---|---|
| GET | /{handle}/rss | 모두 | 200 RSS 2.0, `Content-Type: application/rss+xml; charset=UTF-8` |
| GET | /{handle}/atom | 모두 | 200 Atom 1.0(RFC 4287), `Content-Type: application/atom+xml; charset=UTF-8` |
| GET | /{handle}/category/{categoryId}/rss | 모두 | 200 RSS 2.0. 그 카테고리(상위면 하위 포함)의 글만 |

- 담는 글: "목록 노출 가능" 글을 발행 최신순으로 `feedItemCount`개. 본문 노출 가능 글은 `feedContentMode`가 FULL이면 본문 HTML, SUMMARY면 요약. 본문 노출 가능이 아닌 글(004 보호 글)은 제목·링크·시각만(FR-047).
- 본문 HTML의 상대 주소(`/media/...` 등)는 `blog.base-url` 기준 절대 주소로 바꾼다. 작성자는 닉네임(RSS `dc:creator`, Atom `author/name`), 이메일은 넣지 않는다.
- RSS 채널: `title`(카테고리 피드는 `{카테고리 이름} - {블로그 제목}`), `link`(블로그 홈 또는 카테고리 화면 절대 주소), `description`(블로그 소개, 없으면 제목), `atom:link rel="self"`, `lastBuildDate`. 항목: `title`, `link`, `guid isPermaLink="true"`(글 주소), `pubDate`(RFC 822), `description`(FULL·SUMMARY일 때), `category`(카테고리·태그), `dc:creator`.
- Atom: `id`·`link rel="self"`·`link rel="alternate"`, `title`, `updated`(RFC 3339), `author/name`; 항목 `id`(글 주소), `title`, `link rel="alternate"`, `published`, `updated`, `content type="html"`(FULL) 또는 `summary`(SUMMARY), `category term`.
- 조건부 요청: 응답에 약한 `ETag`와 `Last-Modified`, `Cache-Control: no-cache`. `If-None-Match`/`If-Modified-Since`가 맞으면 304(본문 없음). ETag는 담을 글의 (id, 수정 시각)과 블로그 제목·소개·피드 설정·수정 시각으로 만든다(research D6).
- 없는 블로그·카테고리, 삭제된 블로그, 주인이 정지·탈퇴한 블로그는 404 `BLOG_NOT_FOUND`/`CATEGORY_NOT_FOUND`(공통 틀 JSON).

## 사이트맵·robots — FR-037

접두어 `/api/v1` 없음. front 서버가 프록시한다.

| 메서드 | 경로 | 권한 | 응답 |
|---|---|---|---|
| GET | /sitemap.xml | 모두 | 200 사이트맵 색인(`sitemapindex`): `/sitemap/pages.xml`과 `/sitemap/posts-1.xml` … `/sitemap/posts-{N}.xml` (N = ceil(본문 노출 가능 글 수 / `urls-per-file`), 0이면 posts 파일 없음) |
| GET | /sitemap/pages.xml | 모두 | 200 `urlset`: `/`, `/terms`, `/privacy`, 본문 노출 가능 글이 1편 이상인 블로그의 홈(`lastmod`=그 블로그 글의 가장 최근 발행 시각) |
| GET | /sitemap/posts-{n}.xml | 모두 | 200 `urlset`: 본문 노출 가능 글 주소(`/{handle}/{id}`, `lastmod`=글 수정 시각), id 오름차순으로 n번째 묶음. 범위 밖 n은 404 `NOT_FOUND` |
| GET | /robots.txt | 모두 | 200 `text/plain; charset=UTF-8` (research D5의 규칙과 `Sitemap: {base-url}/sitemap.xml`) |

- 사이트맵 응답은 `Content-Type: application/xml; charset=UTF-8`, `Cache-Control: no-cache`, `Last-Modified`. 주소는 모두 `blog.base-url` 기준 절대 주소.
- 보호 글(004)은 본문 노출 가능이 아니므로 사이트맵에 넣지 않는다(001 글 노출 매트릭스).

## 프로퍼티 (backend `application.yml`, 002에서 추가)

| 키 | 기본값 | 설명 |
|---|---|---|
| blog.search.max-terms | 5 | 검색어에서 쓰는 최대 낱말 수 (research D4) |
| blog.search.min-term-length | 2 | 쓰는 낱말의 최소 길이(MySQL `ngram_token_size`와 같게) |
| blog.notifications.retention | 90d | 알림 보관 기간 (data-model notifications) |
| blog.notifications.subscriber-dedup-window | 24h | 같은 구독자·블로그의 NEW_SUBSCRIBER를 다시 만들지 않는 기간 |
| blog.jobs.notification-purge-cron | `0 15 4 * * *` | 오래된 알림 정리 (research D3) |
| blog.sitemap.urls-per-file | 50000 | 사이트맵 posts 파일 하나의 주소 수(표준 상한) |

front 환경 변수(002에서 추가): `BLOG_KAKAO_JS_KEY`(Kakao JavaScript 키, 없으면 카카오톡 공유 버튼을 숨김, research D9).
