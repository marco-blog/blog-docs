# API Contract: 004 블로그 꾸미기와 글 옵션

004가 더하는 엔드포인트와 001~003 응답·요청의 확장만 적는다. 기준 경로·인증·Origin 검사·공통 응답 틀·오류 형식·페이지 규칙은 [001 contracts/api.md](../../001-blog-core/contracts/api.md)와 [REST API 설계 규칙](../../../api-guidelines.md)을 따른다.

- 모든 API 경로는 `/api/v1`로 시작한다(아래 표의 경로는 이 접두어를 뺀 것).
- 표의 "응답"은 공통 틀 `{ header, result, totalCount? }`의 `result`에 들어가는 내용이다. "Page<X>"는 `result`가 X 배열, `totalCount`가 전체 개수이며 `page`는 0부터, `size`는 기본 20·최대 50이다.
- "본문 없는 성공"은 200 + `result: null`이다(204를 쓰지 않음).
- 권한: "모두"는 비로그인 포함, "주인"은 그 블로그(글이면 글이 속한 블로그)의 주인(001 `BlogAccess`: 볼 수 없는 블로그면 404 `BLOG_NOT_FOUND`, 주인이 아니면 403 `FORBIDDEN`), "작성자"는 회원 글이면 그 회원, 비회원 글이면 맞는 `guestPassword`를 보낸 사람이다. 로그인이 필요한데 하지 않았으면 401 `UNAUTHENTICATED`. 로그인이 필요한 응답과 주인 응답에는 `Cache-Control: no-store`(설계 규칙 8절).
- 상태를 바꾸는 요청은 비로그인이어도 `Origin` 검사를 받는다(001 R27).
- 이 문서가 기준이며, 구현 후 springdoc OpenAPI와 일치해야 한다.

## 오류 코드 (004에서 추가)

001~003 표의 코드는 그대로 쓴다(`POST_NOT_FOUND`, `BLOG_NOT_FOUND`, `COMMENT_NOT_FOUND`, `COMMENTS_DISABLED`, `VALIDATION_FAILED`, `FORBIDDEN`, `TOO_MANY_REQUESTS` 등).

| HTTP | resultCode | 상황 |
|---|---|---|
| 400 | POST_PASSWORD_MISMATCH | 보호 글 비밀번호가 틀림 (FR-062) |
| 403 | POST_LOCKED | 열지 않은 보호 글의 댓글 목록·쓰기 (FR-062) |
| 429 | PASSWORD_ATTEMPTS_EXCEEDED | 같은 대상의 비밀번호를 5회 연속 틀려 10분 동안 막힘. `Retry-After` 헤더(초) (FR-063, FR-066) |
| 422 | SCHEDULE_NOT_ALLOWED | 이미 발행된 글에 예약 시각을 보냄 (FR-064, data-model 예약 발행) |
| 409 | POST_NOT_SCHEDULED | 예약 상태가 아닌 글의 예약 취소 |
| 403 | GUEST_PASSWORD_MISMATCH | 비회원 댓글·방명록의 수정·삭제·내용 보기에서 비밀번호가 틀림 (FR-066) |
| 404 | GUESTBOOK_DISABLED | 방명록을 끈 블로그의 방명록 목록·쓰기(주인 제외) (FR-058) |
| 404 | GUESTBOOK_ENTRY_NOT_FOUND | 없는 방명록 글, 또는 볼 수 없는 블로그의 방명록 글 |
| 409 | EXPORT_LIMIT_EXCEEDED | 최근 24시간 안에 만든(실패하지 않은) 백업이 있음 (FR-145) |
| 404 | EXPORT_NOT_FOUND | 없는 백업, 준비되지 않았거나 만료된 백업 파일 (FR-145) |
| 422 | CANNOT_BLOCK_SELF | 블로그 주인이 자기 자신을 차단 (FR-146) |
| 404 | USER_NOT_FOUND | 차단할 회원이 없음 |
| 404 | BLOCK_NOT_FOUND | 차단하지 않은 회원의 차단 해제 |

새 `fieldErrors[].code`는 없다. 형식 오류는 `INVALID`(`params`에 허용 값·범위), 필수 누락은 `REQUIRED`, 길이는 `TOO_LONG`·`TOO_SHORT`를 쓴다.

## 설계 규칙과 다르게 만든 것

| 항목 | 규칙 | 004 | 이유 |
|---|---|---|---|
| `PUT /blogs/{handle}/blocks/{userId}` | 생성은 POST + 201 | PUT 멱등 생성, 200 | 차단 행의 키가 (블로그, 회원)이라 경로가 곧 자원이다. 두 번 눌러도 결과가 같다(003 포털 제외와 같은 판단) |
| `GET /blogs/{handle}/exports/{id}/file` | JSON 공통 틀 | 성공은 `application/zip` 바이너리, 실패는 공통 틀 JSON | 파일 내려받기다(설계 규칙 4절의 이미지 예외와 같은 성격). `Content-Disposition: attachment` |
| 비회원 `DELETE /comments/{id}`, `DELETE /guestbook-entries/{id}` | DELETE에 본문 없음(권장) | 본문 `{ guestPassword }` | 001 `DELETE /me`·`DELETE /blogs/{handle}`이 비밀번호를 본문으로 받는 것과 같다. 비밀번호를 쿼리 문자열에 넣으면 접근 기록에 남는다 |
| 비회원 `POST /comments/{id}/unlock`, `POST /guestbook-entries/{id}/unlock` | 조회는 GET | POST | 비밀번호를 본문으로 보내야 한다(위와 같은 이유). 상태를 바꾸지 않는다 |

## 001~003 요청·응답 확장

필드 추가만 한다(설계 규칙 9절, v1 안에서 허용).

| API | 추가 필드 | 내용 |
|---|---|---|
| GET /blogs/{handle} | `guestbookEnabled: boolean`, `guestWriteEnabled: boolean` | 방명록 사용(FR-058, 기본 true), 비회원 댓글·방명록 허용(FR-066, 기본 false) |
| PATCH /blogs/{handle} (요청) | `guestbookEnabled?`, `guestWriteEnabled?` | 주인만. 둘 다 null로 지울 수 없음(400 `REQUIRED`) |
| GET /blogs/{handle}/posts (쿼리) | `year`, `month` | 둘 다 있을 때 그 달(`blog.stats.time-zone` 기준)에 발행된 글만. 하나만 있거나 범위 밖이면 400 `VALIDATION_FAILED`. `category`·`tag`와 함께 쓸 수 없음(400) |
| GET /blogs/{handle}/posts (동작) | - | 조건(`category`·`tag`·`year`·`month`)이 하나도 없으면(블로그 홈 목록) 공지(`notice = true`)를 뺀다 (FR-059) |
| PostSummary (블로그 글 목록·태그 글 목록 등 주인 외 목록) | `notice: boolean`, `scheduledAt: string \| null` | 보호 글은 주인 외에게 `summary`·`thumbnailUrl` null(001 contracts 규칙, 004가 구현). `scheduledAt`은 관리 목록에서만 값, 그 외 null |
| GET /blogs/{handle}/manage/posts (쿼리) | `status=SCHEDULED`, `visibility=PROTECTED` | 예약 글, 보호 글 거르기 |
| POST /blogs/{handle}/manage/posts/bulk (요청) | `action: "NOTICE" \| "UNNOTICE"` | 공지 지정·해제. 휴지통 글은 건너뛰고 응답의 건너뛴 수에 셈(001 일괄 작업 규칙) |
| GET /blogs/{handle}/manage/dashboard | `visitors: { today, yesterday, total }`, `newGuestbook7d: number`, `recentGuestbook: [GuestbookEntry]`(최근 5건, 답글 제외) | 006 FR-100 |
| PublishSettings (POST /posts/{id}/publish 요청) | `password?: string`, `scheduledAt?: string \| null`, `notice?: boolean \| null` | 아래 "보호 글", "예약 발행", "공지" |
| GET /posts/{id} (PostDetail) | `locked: boolean`, `notice: boolean`, `scheduledAt: string \| null` | `locked`가 true면(열지 않은 보호 글) `contentHtml`·`summary`·`thumbnailUrl`·`category`·`topicId`는 null, `tags`는 `[]`. `scheduledAt`은 주인에게만 값 |
| Comment (GET /posts/{id}/comments 등) | `secret: boolean`, `author.guest: boolean` | 볼 수 없는 비밀 댓글은 `content: null`. 비회원은 `author = { userId: null, nickname: 이름, profileImageUrl: null, guest: true }` |
| POST /posts/{id}/comments (요청) | `secret?: boolean`, `guestName?`, `guestPassword?` | 비로그인 요청은 비회원 댓글(아래 "비회원 글") |
| PATCH /comments/{id} (요청) | `secret?: boolean`, `guestPassword?` | 비회원 댓글은 `guestPassword` 필수 |
| DELETE /comments/{id} (요청) | 본문 `{ guestPassword }` | 비회원 댓글을 작성자가 지울 때만 |
| GET /search/posts (쿼리) | `blog` | 블로그 주소. 그 블로그 글만 검색(FR-061). 볼 수 없는 블로그면 404 `BLOG_NOT_FOUND` |
| Notification `type` | `BACKUP_READY` | target `BLOG_EXPORT` / 백업 id, `params: { blogTitle, handle, expiresAt }` (002 data-model 표) |
| NEW_COMMENT 알림 `params` | `guestName` | 비회원 댓글이면 이름(그때 `actor`는 null) |

## 보호 글 (post) — FR-062, FR-063

| 메서드 | 경로 | 권한 | 요청 | 응답 |
|---|---|---|---|---|
| POST | /posts/{id}/unlock | 모두 | `{ password }` | 200 PostDetail(`locked: false`, 본문 포함) + `Set-Cookie: post_unlock_{id}=...; HttpOnly; Secure; SameSite=Lax; Path=/; Max-Age=1800`. 목록 노출 가능한 보호 글이 아니면 404 `POST_NOT_FOUND`, 틀리면 400 `POST_PASSWORD_MISMATCH`, 막혔으면 429 `PASSWORD_ATTEMPTS_EXCEEDED` |

- `PublishSettings.visibility = "PROTECTED"`이면 `password`(4~64자)가 필요하다. 이미 보호 글이면 생략할 수 있고 기존 비밀번호를 유지한다. 다른 공개 범위로 바꾸면 비밀번호를 지운다. 비밀번호는 어떤 응답에도 나오지 않는다.
- 글 상세는 주인이거나 유효한 `post_unlock_{id}` 쿠키(30분, 비밀번호를 바꾸면 무효)가 있으면 본문을 준다. 아니면 `locked: true`(위 "확장" 표).
- 열지 않은 보호 글: 댓글 목록·쓰기는 403 `POST_LOCKED`, 조회수(`POST /posts/{id}/views`)·끝까지 읽음(`POST /posts/{id}/read-complete`)은 200이지만 세지 않는다.
- 비밀번호 시도 제한: 같은 글에 같은 방문자(회원 ID 또는 방문자 쿠키) 또는 같은 IP가 5회 연속 틀리면 10분 동안 429(research B3).

## 예약 발행 (post) — FR-064, SC-010

| 메서드 | 경로 | 권한 | 요청 | 응답 |
|---|---|---|---|---|
| POST | /posts/{id}/unschedule | 주인 | - | 200 PostSummary(`status: "DRAFT"`, `scheduledAt: null`). 예약 상태가 아니면 409 `POST_NOT_SCHEDULED` |

- `PublishSettings.scheduledAt`이 지금보다 미래이면 글은 `SCHEDULED`가 된다(글이 DRAFT·SCHEDULED일 때만, PUBLISHED면 422 `SCHEDULE_NOT_ALLOWED`). 지금부터 365일(`blog.posts.schedule-max-ahead`)을 넘으면 400 `VALIDATION_FAILED`(field `scheduledAt`, `INVALID`, `params.max`). 응답은 `status: "SCHEDULED"`인 PostDetail.
- `scheduledAt`이 null·생략이거나 지금 이하면 바로 발행한다(Edge Cases).
- 예약 글은 주인 외에게 404이며 어떤 목록에도 나오지 않는다(001 노출 매트릭스 SCHEDULED 행). 예약 시각이 지나면 30초 주기 작업이 발행하고 그때부터 목록·피드·검색에 나온다(1분 이내, SC-010). `publishedAt`은 실제 발행 시각이다.
- 휴지통으로 옮긴 예약 글을 복구하면 SCHEDULED로 돌아온다(시각이 지났으면 다음 주기에 발행).

## 공지 (notice) — FR-059

| 메서드 | 경로 | 권한 | 요청 | 응답 |
|---|---|---|---|---|
| GET | /blogs/{handle}/notices?page=&size= | 모두 | - | 200 Page<PostSummary>. 목록 노출 가능한 공지 글, 발행 최신순. 블로그 홈은 `size=5` |

- `PublishSettings.notice`: true면 공지로, false면 해제, null·생략이면 지금 값 유지(새 글은 false).

## 사이드바 (sidebar) — FR-060, FR-061

| 메서드 | 경로 | 권한 | 요청 | 응답 |
|---|---|---|---|---|
| GET | /blogs/{handle}/sidebar | 모두 | - | 200 SidebarView |
| GET | /blogs/{handle}/manage/sidebar | 주인 | - | 200 `{ items: [{ type, enabled }] }`(10개, 순서대로. 저장한 적이 없으면 기본 구성) |
| PUT | /blogs/{handle}/sidebar | 주인 | `{ items: [{ type, enabled }] }` | 200 `{ items }`. 10개 항목을 빠짐·중복 없이 모두 보내야 하며(아니면 400 field `items` `INVALID`), 배열 순서가 사이드바 순서 |

`type`: `PROFILE`, `CATEGORIES`, `RECENT_POSTS`, `RECENT_COMMENTS`, `POPULAR_POSTS`, `TAGS`, `ARCHIVE`, `VISITORS`, `SEARCH`, `FEED_LINKS`. 기본 구성(행이 없을 때): PROFILE, CATEGORIES, RECENT_POSTS, TAGS, ARCHIVE, SEARCH, FEED_LINKS 켜짐, RECENT_COMMENTS, POPULAR_POSTS, VISITORS 꺼짐(이 순서).

`SidebarView`:
```json
{
  "items": ["PROFILE", "CATEGORIES", "RECENT_POSTS", "VISITORS", "TAGS", "ARCHIVE", "SEARCH", "FEED_LINKS"],
  "recentPosts": [ { "id": 123, "title": "첫 글", "publishedAt": "2026-10-06T04:24:19Z" } ],
  "popularPosts": null,
  "recentComments": null,
  "tags": [ { "name": "spring", "postCount": 14 } ],
  "archive": [ { "year": 2026, "month": 10, "postCount": 3 } ],
  "visitors": { "today": 12, "yesterday": 30, "total": 1520 }
}
```
- `items`: 켜진 항목만, 사이드바 순서대로.
- 데이터 필드는 그 항목이 켜졌을 때만 값이고 꺼졌으면 null이다. `recentPosts`·`popularPosts`는 목록 노출 가능 글 5편(인기는 조회수 순), `recentComments`는 본문 노출 가능 글의 비밀이 아닌 댓글 최신 5개 `{ id, postId, postTitle, excerpt(50자), authorName, guest, createdAt }`, `tags`는 글 수 상위 30개, `archive`는 아래 보관함과 같다.
- PROFILE·CATEGORIES·SEARCH·FEED_LINKS는 front가 `GET /blogs/{handle}` 응답으로 그린다.

## 월별 보관함 (archive) — FR-061

| 메서드 | 경로 | 권한 | 요청 | 응답 |
|---|---|---|---|---|
| GET | /blogs/{handle}/archive | 모두 | - | 200 `[{ year, month, postCount }]`. 목록 노출 가능 글이 있는 달만, 최근 달부터. 연·월은 `blog.stats.time-zone`(기본 Asia/Seoul) 기준 |

그 달의 글은 `GET /blogs/{handle}/posts?year=&month=`(위 "확장" 표).

## 방문자 (visit) — FR-067

| 메서드 | 경로 | 권한 | 요청 | 응답 |
|---|---|---|---|---|
| POST | /blogs/{handle}/visits | 모두 | - | 200 `null`. 셌는지와 관계없이 같은 응답. 방문자 쿠키가 없으면 001 조회수 API처럼 발급. 볼 수 없는 블로그면 404 `BLOG_NOT_FOUND` |
| GET | /blogs/{handle}/manage/stats?days= | 주인 | - | 200 `{ visitors: { today, yesterday, total }, daily: [{ date, visitors }], topPosts: [{ id, title, viewCount }] }`. `days`는 1~30(기본 30), `daily`는 오늘 포함 날짜 오름차순이며 기록이 없는 날은 0. `topPosts`는 조회수 상위 10편(주인 화면이라 모든 공개 범위·상태 중 DELETED 제외) |

- 같은 방문자(회원 ID 또는 방문자 쿠키)는 블로그마다 하루(`blog.stats.time-zone` 날짜) 한 번만 센다. 블로그 주인 본인과 봇(User-Agent 규칙, research B9)은 세지 않는다.
- front 공개 블로그 레이아웃이 SSR 때 부른다(contracts/routes.md).

## 방명록 (guestbook) — FR-056~058, FR-066

| 메서드 | 경로 | 권한 | 요청 | 응답 |
|---|---|---|---|---|
| GET | /blogs/{handle}/guestbook?page=&size= | 모두 | - | 200 Page<GuestbookEntry>(최상위 글 최신순, 각 `replies`). 방명록이 꺼졌으면 주인 외 404 `GUESTBOOK_DISABLED` |
| POST | /blogs/{handle}/guestbook | 회원 또는 비회원 | GuestbookWrite | 201 GuestbookEntry + `Location: /api/v1/guestbook-entries/{id}`. 아래 규칙 |
| PATCH | /guestbook-entries/{id} | 작성자 | `{ content?, secret?, guestPassword? }` | 200 GuestbookEntry. 비회원 글은 `guestPassword` 필수(틀리면 403 `GUEST_PASSWORD_MISMATCH`) |
| DELETE | /guestbook-entries/{id} | 작성자 또는 블로그 주인 | 비회원 작성자는 `{ guestPassword }` | 200 `null`. 답글이 있으면 "삭제된 글" 자리만 남김 |
| POST | /guestbook-entries/{id}/unlock | 비회원 작성자 | `{ guestPassword }` | 200 GuestbookEntry(내용 포함). 비회원 비밀글을 수정하려고 내용을 볼 때 |

`GuestbookWrite`:
```json
{ "content": "놀러 왔어요", "secret": false, "parentId": null, "guestName": "지나가던 사람", "guestPassword": "1234" }
```
- `content` 1~1000자 일반 텍스트(출력 시 이스케이프). `parentId`가 있으면 블로그 주인의 답글이다: 주인이 아니면 403 `FORBIDDEN`, 부모가 답글이면 422 `REPLY_DEPTH_EXCEEDED`, 부모가 없으면 404 `GUESTBOOK_ENTRY_NOT_FOUND`. 답글의 `secret`은 부모를 따른다.
- 로그인 회원은 `guestName`·`guestPassword`를 보내지 않는다(보내면 무시). 비로그인 요청은 비회원 글이며 블로그가 비회원 쓰기를 허용해야 한다(아래 "비회원 글").
- 방명록이 꺼진 블로그에는 주인 외 쓰기 404 `GUESTBOOK_DISABLED`. 이 블로그에서 차단된 회원은 403 `FORBIDDEN`(FR-146).

`GuestbookEntry`:
```json
{
  "id": 7, "content": "놀러 왔어요", "secret": false, "deleted": false,
  "author": { "userId": 42, "nickname": "리더", "profileImageUrl": null, "guest": false },
  "createdAt": "2026-10-06T04:24:19Z", "updatedAt": "2026-10-06T04:24:19Z",
  "replies": [ { "id": 8, "content": "반가워요", "secret": false, "deleted": false, "author": { "userId": 1, "nickname": "마르코", "profileImageUrl": null, "guest": false }, "createdAt": "...", "updatedAt": "...", "replies": [] } ]
}
```
- 비밀글(`secret: true`)의 `content`는 블로그 주인과 작성 회원에게만 값이고 그 외에는 null이다. 비밀글의 답글도 같다.
- 삭제된 자리는 `deleted: true`, `content: null`, `author: null`.

## 비회원 글 (guest) — FR-066

댓글(`POST /posts/{id}/comments`)과 방명록(`POST /blogs/{handle}/guestbook`)에 같은 규칙을 쓴다.

- 로그인하지 않은 요청은 블로그의 `guestWriteEnabled`가 true일 때만 받는다. 아니면 401 `UNAUTHENTICATED`(front는 로그인 안내).
- `guestName` 1~30자, `guestPassword` 4~64자 필수(아니면 400 field별 `REQUIRED`·`TOO_LONG`·`TOO_SHORT`). 비밀번호는 BCrypt로, 작성 IP는 AES-256-GCM으로 저장하고 IP는 90일 뒤 지운다.
- 비회원 쓰기 속도: 같은 IP에서 댓글 1분 5개, 방명록 1분 3개(`blog.guest.*`). 넘으면 429 `TOO_MANY_REQUESTS` + `Retry-After`. CAPTCHA·회원 속도 제한은 005.
- 수정·삭제·내용 보기는 같은 비밀번호로만(틀리면 403 `GUEST_PASSWORD_MISMATCH`, 5회 연속 틀리면 10분 동안 429 `PASSWORD_ATTEMPTS_EXCEEDED`). 블로그·글 주인은 비밀번호 없이 지울 수 있다.
- 응답의 작성자는 `guest: true`이며 front가 "비회원" 표시를 붙인다.

## 비밀 댓글 (comment) — FR-065

| 메서드 | 경로 | 권한 | 요청 | 응답 |
|---|---|---|---|---|
| POST | /comments/{id}/unlock | 비회원 작성자 | `{ guestPassword }` | 200 Comment(내용 포함). 비회원 비밀 댓글을 수정하려고 내용을 볼 때 |

- `secret: true` 댓글의 `content`는 글 주인, 작성 회원, (답글이면) 부모 댓글의 작성 회원에게만 값이다. 비밀 댓글의 답글과 비밀 댓글 아래의 답글도 비밀로 다룬다. 그 외에는 `content: null`이고 front는 "비밀 댓글입니다"를 보여준다.

## 블로그 백업 (export) — FR-145

| 메서드 | 경로 | 권한 | 요청 | 응답 |
|---|---|---|---|---|
| POST | /blogs/{handle}/exports | 주인 | - | 202 BlogExport(`status: "PENDING"`) + `Location: /api/v1/blogs/{handle}/exports/{id}`. 최근 24시간 안에 만든 실패하지 않은 백업이 있으면 409 `EXPORT_LIMIT_EXCEEDED` |
| GET | /blogs/{handle}/exports | 주인 | - | 200 `[BlogExport]`(최근 10건, 새것부터) |
| GET | /blogs/{handle}/exports/{id}/file | 주인 | - | 200 `application/zip`, `Content-Disposition: attachment; filename="{handle}-backup-{yyyyMMdd}.zip"`, `Cache-Control: no-store`. READY이고 만료 전이 아니면 404 `EXPORT_NOT_FOUND`(JSON) |

`BlogExport`:
```json
{ "id": 3, "status": "READY", "fileSize": 1048576, "errorCode": null,
  "createdAt": "2026-10-06T04:24:19Z", "completedAt": "2026-10-06T04:25:02Z", "expiresAt": "2026-10-13T04:25:02Z" }
```
- `status`: `PENDING`(대기) / `RUNNING`(만드는 중) / `READY`(완료) / `FAILED`(실패, `errorCode`) / `EXPIRED`(만료, 파일 삭제됨).
- 준비되면 요청한 주인에게 `BACKUP_READY` 알림이 간다. 7일 동안 내려받을 수 있다.
- zip 구성: `blog.json`(블로그·카테고리 트리, 형식 버전), `posts/{id}.md`(휴지통을 뺀 모든 글, YAML front matter `title`·`category`·`tags`·`visibility`·`status`·`publishedAt`·`scheduledAt`·`notice`·`topic` + Markdown 원문), `posts/{id}.draft.md`(발행된 글의 작성 중 사본이 있을 때), `images/{mediaKey}.{ext}`(글에 쓰인 원본 이미지), `media.json`(`/media/{key}` → `images/...`). 보호 글 비밀번호, 댓글·방명록은 넣지 않는다(research B14).

## 회원 차단 (block) — FR-146

| 메서드 | 경로 | 권한 | 요청 | 응답 |
|---|---|---|---|---|
| GET | /blogs/{handle}/blocks?page=&size= | 주인 | - | 200 Page<`{ user: { userId, nickname, profileImageUrl }, blockedAt }`>, 차단 최신순 |
| PUT | /blogs/{handle}/blocks/{userId} | 주인 | - | 200 `{ user, blockedAt }`. 이미 차단했으면 그대로(멱등). 자기 자신이면 422 `CANNOT_BLOCK_SELF`, 없는 회원이면 404 `USER_NOT_FOUND` |
| DELETE | /blogs/{handle}/blocks/{userId} | 주인 | - | 200 `null`. 차단하지 않았으면 404 `BLOCK_NOT_FOUND` |

- 차단하면 같은 트랜잭션에서 그 회원의 이 블로그 구독을 지우고 구독자 수를 줄인다.
- 차단된 회원이 이 블로그에 댓글·방명록을 쓰거나 구독(`PUT /me/subscriptions/{handle}`)하면 403 `FORBIDDEN`(차단 사실을 알리지 않는 일반 거부). 차단 사실은 알림으로 보내지 않는다.

## 프로퍼티 (004에서 추가, `application.yml` 기본값)

| 키 | 기본값 | 설명 |
|---|---|---|
| blog.posts.unlock-ttl | 30m | 보호 글 열람 쿠키 수명 |
| blog.posts.password-max-failures | 5 | 비밀번호 연속 실패 허용 수(보호 글·비회원 글) |
| blog.posts.password-lock-duration | 10m | 넘었을 때 막는 시간 |
| blog.posts.schedule-max-ahead | 365d | 예약 시각의 최대 앞날 |
| blog.jobs.scheduled-publish-delay | 30s | 예약 발행 작업 주기(SC-010) |
| blog.stats.time-zone | Asia/Seoul | 방문 날짜·월별 보관함의 날짜 기준 |
| blog.stats.visit-dedup-max-size | 200000 | 방문 중복 제거 캐시 최대 항목 |
| blog.stats.bot-user-agent-pattern | `(?i)(bot\|crawler\|spider\|slurp\|facebookexternalhit\|preview)` | 세지 않는 User-Agent |
| blog.guest.comment-per-minute | 5 | 비회원 댓글 IP당 1분 한도 |
| blog.guest.guestbook-per-minute | 3 | 비회원 방명록 IP당 1분 한도 |
| blog.guest.ip-retention | 90d | 비회원 작성 IP 보관 기간 |
| blog.export.dir | (prod 필수, local `./data/exports`) | 백업 파일 디렉터리 |
| blog.export.retention | 7d | 내려받기 기간 |
| blog.export.min-interval | 24h | 블로그당 백업 간격 |
| blog.export.stale-running | 1h | 기동 때 이보다 오래된 RUNNING은 FAILED(`INTERRUPTED`) |
| blog.jobs.export-poll-delay | 30s | 백업 생성 작업 주기 |
| blog.jobs.export-cleanup-cron | `0 10 * * * *` | 만료 백업 정리(매시 10분) |
