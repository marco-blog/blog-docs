# API Contract: 001 블로그 핵심

- 기준 경로: `/api/v1` (브라우저는 `https://blog.java21.net/api/v1/...`, front 서버가 backend로 프록시)
- 형식: JSON, UTF-8. 시간은 ISO-8601 UTC(`2026-10-06T04:24:19Z`).
- 인증: `access_token` 쿠키(JWT 30분). 없거나 만료면 401. 리프레시는 `refresh_token` 쿠키(`Path=/api/v1/auth`).
- 모든 API 경로는 `/api/v1`로 시작한다(아래 표의 경로는 이 접두어를 뺀 것). 예외는 이미지(`/media/**`)와 블로그 피드·트랙백(`/{handle}/rss` 등, 002·005)뿐이다.
- 상태 변경 요청은 `Origin`이 허용 출처가 아니면 403 `ORIGIN_NOT_ALLOWED`. 단, 외부 서버가 보내는 표준 트랙백 핑 `POST /{handle}/{postId}/trackback`(005)은 Origin 검사에서 제외한다(쿠키 인증을 쓰지 않으므로 CSRF 대상이 아니며, 자체 속도 제한·검증을 따른다).
- 관리자 API(`/api/v1/admin/**`, 006)는 요청마다 DB에서 회원의 현재 `role`을 다시 읽어 확인한다(JWT의 role 클레임을 믿지 않음). 권한이 회수되면 다음 요청부터 거부된다. 관리자가 아닌 요청에는 403이 아니라 404 `NOT_FOUND`로 응답해 관리 API의 존재를 드러내지 않는다.
- 이 문서가 기준이며, 구현 후 springdoc이 만든 OpenAPI와 일치해야 한다(front 타입은 OpenAPI에서 생성).

## 공통

**페이지 응답**
```json
{ "items": [ ... ], "page": 0, "size": 20, "totalElements": 135, "totalPages": 7 }
```
`page`는 0부터, `size` 기본 20·최대 50.

**에러 응답**
```json
{ "code": "POST_NOT_FOUND", "message": "Post not found: 123", "fieldErrors": [ { "field": "title", "code": "REQUIRED" } ] }
```
- `code`: 언어와 무관한 고정 오류 코드. 한번 정한 코드는 바꾸지 않는다(FR-154).
- `fieldErrors[].code`: 필드 검증 오류 코드(`REQUIRED`, `TOO_LONG`, `TOO_SHORT`, `INVALID_FORMAT`, `PASSWORD_WEAK` 등). 길이 제한 등 값이 필요하면 `params`(예: `{ "max": 200 }`)를 함께 준다.
- `message`: 영어로 된 디버그용 설명. 로그·개발 도구용이며 front는 화면에 보여주지 않는다.
- front는 `code`와 `fieldErrors[].code`를 메시지 키(`errors.{code}`, `fieldErrors.{code}`)로 바꿔 화면 언어로 보여준다(헌법 원칙 VII). 모르는 코드는 공통 오류 문구로 보여준다.

| HTTP | code | 상황 |
|---|---|---|
| 400 | VALIDATION_FAILED | 입력 검증 실패(fieldErrors 포함) |
| 401 | UNAUTHENTICATED | 로그인 필요, 접근 토큰 만료 |
| 401 | INVALID_CREDENTIALS | 이메일 또는 비밀번호 불일치(어느 쪽인지 밝히지 않음) |
| 401 | REFRESH_INVALID | 리프레시 토큰 없음·만료·폐기·재사용 |
| 403 | FORBIDDEN | 소유자 아님(관리자 API의 권한 없음은 403이 아니라 404 `NOT_FOUND`) |
| 403 | ORIGIN_NOT_ALLOWED | CSRF 방어 |
| 404 | BLOG_NOT_FOUND / POST_NOT_FOUND / DRAFT_NOT_FOUND / CATEGORY_NOT_FOUND / COMMENT_NOT_FOUND / MEDIA_NOT_FOUND | 없음, 또는 볼 권한이 없는 비공개 리소스(다른 사람의 TEMP 이미지 포함) |
| 404 | NOT_FOUND | 관리자 API에 관리자가 아닌 요청, 그 밖의 없는 경로 |
| 400 | THUMBNAIL_SIZE_NOT_ALLOWED | 허용 목록에 없는 썸네일 크기 (FR-131) |
| 400 | PASSWORD_RESET_TOKEN_INVALID | 재설정 링크 만료·사용됨·없음 (FR-133) |
| 400 | CURRENT_PASSWORD_MISMATCH | 비밀번호 변경 시 현재 비밀번호 불일치 (FR-082) |
| 409 | EMAIL_TAKEN / HANDLE_TAKEN | 가입·블로그 만들기 중복(삭제된 블로그의 주소 포함, FR-159) |
| 409 | CATEGORY_NAME_TAKEN | 같은 부모 아래 이름 중복 |
| 409 | BLOG_LIMIT_EXCEEDED | 가진 블로그(삭제 제외) 수가 회원의 블로그 한도 이상 (FR-158) |
| 409 | LAST_BLOG_CANNOT_BE_DELETED | 마지막 남은 블로그 삭제 시도 (FR-159) |
| 413 | MEDIA_TOO_LARGE | max-size 초과 |
| 415 | MEDIA_TYPE_NOT_ALLOWED | 허용 형식 아님(내용 기준) |
| 422 | HANDLE_RESERVED / HANDLE_INVALID | 블로그 주소 규칙 위반 |
| 422 | TAG_LIMIT_EXCEEDED / CATEGORY_DEPTH_EXCEEDED / REPLY_DEPTH_EXCEEDED | 규칙 위반 |
| 422 | COMMENTS_DISABLED | 블로그 설정(FR-029) 또는 글별 설정(FR-107)이 댓글을 막음 |
| 422 | POST_NOT_IN_TRASH | 휴지통에 없는 글을 복구하려 함 |
| 422 | TERMS_VERSION_OUTDATED | 가입 화면이 받은 약관 버전이 현재 버전과 다름(새로 고침 필요) |
| 409 | POST_NOT_PUBLISHED | 발행 전 글에 작성 중 사본 폐기 요청 |
| 423 | ACCOUNT_LOCKED | 로그인 5회 실패 후 10분 잠금 |
| 429 | MEDIA_TEMP_QUOTA_EXCEEDED | 회원별 임시 한도 초과 |

## 인증 (auth) — FR-001~007, FR-081, FR-133

| 메서드 | 경로 | 권한 | 요청 | 성공 응답 |
|---|---|---|---|---|
| POST | /auth/signup | 비로그인 | `{ email, password, nickname, handle, agreeTerms, agreePrivacy, over14, termsVersion, locale?, timeZone? }` | 201 `{ userId, handle }` + 두 쿠키 설정(가입 즉시 로그인). `termsVersion`이 현재 버전과 다르면 422 `TERMS_VERSION_OUTDATED`. `locale`·`timeZone`은 가입 화면의 현재 언어·브라우저 시간대 |
| GET | /auth/handle-availability?handle= | 모두 | - | 200 `{ available: true }` 또는 `{ available: false, reason: "TAKEN" \| "RESERVED" \| "INVALID" }` (가입과 새 블로그 만들기에 같이 씀. 삭제된 블로그의 주소는 TAKEN) |
| POST | /auth/login | 비로그인 | `{ email, password }` | 200 `{ userId, nickname, role, blogs: [{ handle, title }] }` + 두 쿠키 설정 (`blogs`는 삭제하지 않은 내 블로그, 만든 순) |
| POST | /auth/refresh | refresh 쿠키 | - | 204 + 새 access·refresh 쿠키 (회전) |
| POST | /auth/logout | 로그인 | - | 204 + 쿠키 삭제, family 폐기 |
| POST | /auth/password-reset/request | 비로그인 | `{ email }` | 202 (가입 여부와 관계없이 같은 응답). 메일은 회원의 `locale` 언어로 발송(FR-148) |
| POST | /auth/password-reset/confirm | 비로그인 | `{ token, newPassword }` | 204, 모든 family 폐기 |

규칙: 비밀번호 8~64자, 영문+숫자 포함. handle `^[a-z0-9](?:[a-z0-9-]{1,18})[a-z0-9]$`, 연속 하이픈 금지, 예약어 목록은 [routes.md](./routes.md#예약어).

## 회원·계정 설정 (user) — FR-008, FR-009, FR-082, FR-138, FR-139, FR-149, FR-153

| 메서드 | 경로 | 권한 | 요청 | 응답 |
|---|---|---|---|---|
| GET | /me | 로그인 | - | 200 `{ userId, email, nickname, bio, profileImageUrl, role, locale, timeZone, blogs: [{ handle, title }] }` (`blogs`는 삭제하지 않은 내 블로그, 만든 순) |
| PATCH | /me | 로그인 | `{ nickname?, bio?, profileImageMediaKey?, locale?, timeZone? }` | 200 위와 같음. 프로필 이미지는 `purpose=PROFILE`로 올린 본인 이미지만, 저장 시 ATTACHED. `locale`은 ko·en·ja·zh-CN, `timeZone`은 IANA ID |
| DELETE | /me | 로그인 | `{ password }` | 204, 되돌릴 수 없음. 모든 블로그의 글 전부 비공개, 모든 토큰 폐기, 30일 보존 기간 후 개인정보 파기(복구 기능 없음) |
| PUT | /me/password | 로그인 | `{ currentPassword, newPassword }` | 204, 현재 기기 외 모든 family 폐기 |
| GET | /me/login-history?page= | 로그인 | - | 200 Page<`{ at, success, ipMasked, device }`> (IP는 일부 가림, 예: 211.234.*.*) |

## 블로그 (blog) — FR-010~012, FR-158, FR-159

| 메서드 | 경로 | 권한 | 요청 | 응답 |
|---|---|---|---|---|
| GET | /me/blogs | 로그인 | - | 200 `{ items: [{ handle, title, coverImageUrl, postCount, createdAt }], count, limit }` (삭제하지 않은 내 블로그, 만든 순. `limit`은 회원별 한도 또는 기본값) |
| POST | /blogs | 로그인 | `{ handle, title }` | 201 `{ handle, title, ... }`(GET /blogs/{handle}과 같음). handle 규칙·예약어(422 `HANDLE_INVALID`/`HANDLE_RESERVED`), 중복(409 `HANDLE_TAKEN`), 한도(409 `BLOG_LIMIT_EXCEEDED`)를 검사. `title`은 1~100자, 생략하면 "{닉네임}의 블로그" |
| DELETE | /blogs/{handle} | 주인 | `{ password }` | 204, 되돌릴 수 없음. 마지막 남은 블로그면 409 `LAST_BLOG_CANNOT_BE_DELETED`, 비밀번호가 틀리면 400 `CURRENT_PASSWORD_MISMATCH`. 블로그 status=DELETED, 글은 휴지통 규칙대로 30일 뒤 영구 삭제(data-model blogs) |
| GET | /blogs/{handle} | 모두 | - | 200 `{ handle, title, description, coverImageUrl, commentEnabled, owner: { nickname, profileImageUrl, bio }, categories: [CategoryNode] }` |
| PATCH | /blogs/{handle} | 주인 | `{ title?, description?, coverImageMediaKey?, commentEnabled? }` | 200 위와 같음. 대표 이미지는 `purpose=BLOG_COVER`로 올린 본인 이미지만, 저장 시 ATTACHED |
| GET | /blogs/{handle}/posts?category=&tag=&page= | 모두 | - | 200 Page<PostSummary> ("목록 노출 가능" 글만, 주인이 요청해도 같음. 보호 글은 제목만, data-model 글 노출 매트릭스) |
| GET | /blogs/{handle}/manage/posts?status=&visibility=&category=&q=&page= | 주인 | - | 200 Page<PostSummary> (블로그 관리 글 목록). `status`: DRAFT / PUBLISHED / DELETED(휴지통, 30일 내 글과 `purgeAt` 포함), 004·005 이후 SCHEDULED / HIDDEN. `visibility`: PUBLIC / PRIVATE, 004 이후 PROTECTED. 생략하면 휴지통을 뺀 전체 |

정지·탈퇴 회원의 블로그와 삭제된 블로그: GET /blogs/{handle}은 404 `BLOG_NOT_FOUND`(정지 안내 화면은 005에서 추가). `/blogs/{handle}/...` 아래의 "주인" 권한 API는 그 블로그의 주인(`blogs.user_id`)만 쓸 수 있고, 삭제된 블로그는 주인에게도 404다.

블로그 만들기 규칙(FR-158): 한 트랜잭션에서 회원 행을 잠그고(`SELECT ... FOR UPDATE`) 삭제하지 않은 블로그 수를 센 뒤, `COALESCE(users.max_blogs, blog.blogs.default-max-per-member)` 이상이면 409 `BLOG_LIMIT_EXCEEDED`, 아니면 생성한다. 블로그 삭제의 "마지막 블로그" 확인도 같은 잠금 안에서 한다(research R28).

`CategoryNode`: `{ id, name, postCount, children: [CategoryNode] }`

`PostSummary`: `{ id, title, summary, thumbnailUrl, category: { id, name } | null, tags: [string], viewCount, commentCount, visibility, status, publishedAt, updatedAt, hasDraft, deletedAt?, purgeAt? }`. 본문 노출 가능이 아닌 글(보호 글)을 주인 외에게 줄 때는 `summary`·`thumbnailUrl`이 null.

## 글 (post) — FR-013~022, FR-070, FR-084, FR-107, FR-108

| 메서드 | 경로 | 권한 | 요청 | 응답 |
|---|---|---|---|---|
| POST | /blogs/{handle}/posts/drafts | 주인 | DraftWrite | 201 `{ id, savedAt }` (이 블로그의 새 임시저장 글. 내 블로그가 아니면 403 `FORBIDDEN`, 삭제된 블로그는 404) |
| PUT | /posts/{id}/draft | 주인 | DraftWrite | 200 `{ id, savedAt }` (자동저장·임시저장, 발행본에는 영향 없음) |
| GET | /blogs/{handle}/posts/drafts/latest | 주인 | - | 200 `{ id, title, savedAt }` 또는 204 (이 블로그의 이어 쓰기 확인용) |
| GET | /posts/{id}/draft | 주인 | - | 200 `DraftWrite + { savedAt }` (작성 화면 불러오기. 작성 중 사본이 없으면 발행본 내용을 그대로 돌려줌) |
| DELETE | /posts/{id}/draft | 주인 | - | 204 (작성 중 사본 폐기. 발행본은 그대로 두고, 사본에서만 참조하던 이미지는 정리 대상 판단. 발행 전 글(DRAFT)에는 이 API 대신 `DELETE /posts/{id}`를 쓰며, 호출하면 409 `POST_NOT_PUBLISHED`) |
| POST | /posts/{id}/publish | 주인 | PublishSettings | 200 PostDetail (발행 설정 화면의 발행 버튼, 수정 발행 포함) |
| GET | /posts/{id} | 모두(비공개·임시저장은 주인만) | - | 200 PostDetail, 권한 없으면 404 |
| DELETE | /posts/{id} | 주인 | - | 204 (휴지통으로 이동: status=DELETED, 직전 상태 보관) |
| POST | /posts/{id}/restore | 주인 | - | 200 PostSummary (휴지통에서 삭제 전 상태로 복구, FR-084) |
| POST | /posts/{id}/views | 모두 | - | 204 (중복 판단 후 조회수 증가, SSR loader가 호출) |

글쓰기는 작성(임시저장) → 완료 → 발행 설정 → 발행 순서다(FR-013, FR-107, FR-108). "완료"는 화면 전환일 뿐 API 호출이 없다. 글은 처음 만들 때 정한 블로그에 속하며 다른 블로그로 옮길 수 없다. `/posts/{id}/...`의 "주인"은 그 글이 속한 블로그의 주인이다. `categoryId`는 같은 블로그의 카테고리여야 한다(아니면 404 `CATEGORY_NOT_FOUND`).

`DraftWrite` (작성 화면의 내용):
```json
{
  "title": "제목(0~200자, 임시저장은 빈 제목 허용)",
  "contentMarkdown": "본문 Markdown(최대 200,000자)",
  "categoryId": 12,
  "tags": ["spring", "jpa"]
}
```
- 저장 시 본문의 `/media/{key}` 참조 중 본인이 올린 이미지를 등록(ATTACHED)하고 `post_media`(source=DRAFT)를 갱신한다.
- 이미지는 발행본·작성 중 사본·다른 글·프로필·블로그 대표 이미지 어디에서도 참조하지 않을 때만 ORPHANED가 된다. 판단은 발행과 작성 중 사본 폐기 때 다시 한다(data-model media). 작성 중 사본에서 이미지를 지워도 발행본의 이미지는 그대로 남는다.
- 발행된 글의 draft는 별도 사본으로 저장되며 `publish` 전까지 독자 화면에 반영되지 않는다.

`PublishSettings` (발행 설정 화면):
```json
{
  "visibility": "PUBLIC",
  "thumbnailMediaKey": "k3Jd9fQ2xLmA7pZ0bR5tYw",
  "commentEnabled": true,
  "categoryId": 12,
  "tags": ["spring", "jpa"]
}
```
- 발행 시 제목 1~200자 필수, 본문 비어 있으면 422 `POST_CONTENT_EMPTY`.
- `thumbnailMediaKey`는 본문 이미지 중 하나(생략하면 본문 첫 이미지). `commentEnabled`가 false면 이 글에 댓글을 달 수 없다(422 `COMMENTS_DISABLED`).
- 태그는 앞뒤 공백 제거(trim) + 소문자로 정규화(단어 사이 공백은 유지), 최대 10개, 각 1~30자.

`PostDetail`:
```json
{
  "id": 123, "blogHandle": "marco",
  "title": "...", "contentHtml": "<p>...</p>", "contentMarkdown": "... (주인에게만, 그 외 null)",
  "summary": "...", "thumbnailUrl": "/media/k3Jd9fQ2xLmA7pZ0bR5tYw",
  "category": { "id": 12, "name": "Spring" }, "tags": ["spring"],
  "visibility": "PUBLIC", "status": "PUBLISHED",
  "viewCount": 10, "commentCount": 2, "commentEnabled": true,
  "author": { "nickname": "마르코", "profileImageUrl": null },
  "prev": { "id": 122, "title": "..." }, "next": null,
  "publishedAt": "...", "updatedAt": "..."
}
```

## 블로그 관리 뼈대 (manage) — 006 FR-099~101 중 001 범위

| 메서드 | 경로 | 권한 | 요청 | 응답 |
|---|---|---|---|---|
| GET | /blogs/{handle}/manage/dashboard | 주인 | - | 200 `{ draftCount, recentPosts: [PostSummary], newComments7d, recentComments: [Comment + { postId, postTitle }] }` (최근 5건씩). 방문자 수(004 FR-067)·방명록(004)은 해당 스펙이 필드를 추가 |
| POST | /blogs/{handle}/manage/posts/bulk | 주인 | `{ postIds: [id], action: "CHANGE_VISIBILITY" \| "MOVE_CATEGORY" \| "DELETE", visibility?, categoryId? }` | 200 `{ updated: n }` (모두 `{handle}` 블로그의 글이어야 하며 하나라도 아니면 403, 최대 100개) |
| GET | /blogs/{handle}/manage/comments?page= | 주인 | - | 200 Page<Comment + { postId, postTitle }> (내 블로그 모든 글의 댓글, 최신순) |

## 카테고리 (category) — FR-023, FR-024

| 메서드 | 경로 | 권한 | 요청 | 응답 |
|---|---|---|---|---|
| GET | /blogs/{handle}/categories | 모두 | - | 200 [CategoryNode] |
| POST | /blogs/{handle}/categories | 주인 | `{ name, parentId? }` | 201 CategoryNode |
| PATCH | /blogs/{handle}/categories/{id} | 주인 | `{ name? }` | 200 CategoryNode |
| PUT | /blogs/{handle}/categories/order | 주인 | `[{ id, parentId, sortOrder }]` | 200 [CategoryNode] |
| DELETE | /blogs/{handle}/categories/{id} | 주인 | - | 204 (소속·하위 글 미분류로) |

## 태그 (tag) — FR-025, FR-026

| 메서드 | 경로 | 권한 | 응답 |
|---|---|---|---|
| GET | /tags/{name}/posts?page= | 모두 | 200 Page<PostSummary + blogHandle> (서비스 전체) |
| GET | /blogs/{handle}/tags | 모두 | 200 `[{ name, postCount }]` |

## 댓글 (comment) — FR-027~029

| 메서드 | 경로 | 권한 | 요청 | 응답 |
|---|---|---|---|---|
| GET | /posts/{postId}/comments | 글을 볼 수 있는 사람 | - | 200 `[Comment]` (작성순, 답글은 replies에 포함) |
| POST | /posts/{postId}/comments | 로그인 | `{ content, parentId? }` | 201 Comment |
| PATCH | /comments/{id} | 작성자 | `{ content }` | 200 Comment |
| DELETE | /comments/{id} | 작성자 또는 글 주인 | - | 204 |

`Comment`: `{ id, content, author: { userId, nickname, profileImageUrl }, deleted, createdAt, updatedAt, replies: [Comment] }`. 답글이 있는 댓글이 삭제되면 `deleted: true`, `content: null`.

content: 1~1000자, 일반 텍스트(출력 시 이스케이프).

## 이미지 (media) — FR-038, FR-039, FR-071~074, FR-130~132, FR-156

| 메서드 | 경로 | 권한 | 요청 | 응답 |
|---|---|---|---|---|
| POST | /media | 로그인 | `multipart/form-data` file, purpose(`POST` 기본 / `PROFILE` / `BLOG_COVER`) | 201 `{ key, url: "/media/{key}", mime, size, width, height }` (status=TEMP) |
| GET | /media/{key} *(접두어 /api/v1 없음)* | TEMP: 올린 회원만 / ATTACHED·ORPHANED: 모두 | - | 200 원본 이미지. ATTACHED는 `Cache-Control: public, max-age=31536000, immutable`, TEMP는 `Cache-Control: private, no-store`. 다른 사람의 TEMP·정리된 경우·없는 키는 404 |
| GET | /media/{key}/{w}x{h}?fit=cover\|contain | 위와 같음 | - | 200 썸네일(첫 요청 시 생성 후 저장), 허용 목록에 없는 크기면 400 `THUMBNAIL_SIZE_NOT_ALLOWED` |

`key`는 무작위 128비트를 base62로 표현한 22자(`^[0-9A-Za-z]{22}$`). 순번 ID를 주소에 쓰지 않으므로 다른 이미지 주소를 추측할 수 없다. 등록된 이미지는 비공개·임시저장·휴지통 글의 것이라도 주소를 아는 사람은 열 수 있으며, 이는 받아들인 절충이다(FR-156, data-model media).

썸네일 규칙 (FR-130~132):
- 허용 크기는 `blog.media.thumbnail.sizes` 프로퍼티. `fit` 기본값 `cover`.
- 저장 위치는 `blog.media.thumbnail-dir/{key}/{w}x{h}-{fit}.{ext}`. 원본 삭제 시 `{key}` 디렉터리 통째로 삭제.
- 원본보다 큰 요청은 원본 크기(media.width·height)를 넘지 않게 축소만 한다. 움직이는 GIF는 첫 프레임으로 만든다. 출력 형식은 원본과 같게(WebP 원본은 읽기만 지원되므로 PNG로 출력, research R11).
- 화면별 사용 크기: 글 카드 300x200·600x400, 프로필 50x50·100x100, 공유 미리보기 1200x630.

## 약관·개인정보처리방침 (legal) — FR-137, FR-155

| 메서드 | 경로 | 권한 | 응답 |
|---|---|---|---|
| GET | /legal/terms?lang= | 모두 | 200 `{ version, lang, authoritativeLang: "ko", effectiveAt, contentHtml }` |
| GET | /legal/privacy?lang= | 모두 | 200 위와 같음 |

- 버전은 4개 언어 공통 하나(`blog.legal.terms-version`)이며 한국어판이 기준이다. 본문은 backend 리소스 `legal/{terms|privacy}_{lang}.md`를 변환해 준다. 해당 언어 파일이 없으면 영어, 영어도 없으면 한국어.
- 가입 화면은 `version`을 받아 `/auth/signup`의 `termsVersion`으로 보낸다.

## 관리자 API 공통 규칙 (006)

- 경로는 `/api/v1/admin/**`. 001은 규칙과 001 데이터에 바로 붙는 아래 엔드포인트만 정하고, 나머지 관리자 API는 006 이후 스펙이 정한다.
- 매 요청마다 DB의 `users.role`(ADMIN 또는 SUPER_ADMIN)과 `users.status`(ACTIVE)를 확인한다. JWT의 role 클레임은 화면 메뉴 표시용 힌트일 뿐이다.
- 관리자가 아니면(비로그인 포함) 404 `NOT_FOUND`.

| 메서드 | 경로 | 권한 | 요청 | 응답 |
|---|---|---|---|---|
| PATCH | /admin/users/{id}/blog-limit | ADMIN, SUPER_ADMIN | `{ maxBlogs: number \| null }` (0 이상 정수, `null`은 기본값으로 되돌림) | 200 `{ userId, blogCount, maxBlogs, effectiveLimit }`. 지금 가진 블로그보다 작아도 허용(기존 블로그 유지, 새로 만들기만 막힘). 006 FR-106 작업 기록에 변경 전후 값 저장 (006 FR-160) |

## 프로퍼티 (backend `application.yml`)

| 키 | 기본값 | 설명 |
|---|---|---|
| blog.base-url | https://blog.java21.net | 허용 Origin, 절대 URL 생성 |
| blog.auth.access-ttl | 30m | 접근 토큰 수명 |
| blog.auth.refresh-idle-ttl | 4h | 리프레시 유휴 만료 |
| blog.auth.refresh-absolute-ttl | 7d | 리프레시 절대 만료 |
| blog.auth.refresh-reuse-grace | 10s | 동시 리프레시 유예 |
| blog.auth.jwt-secret | (환경 변수 필수) | HS256 키, 32바이트 이상 |
| blog.auth.login-max-failures | 5 | 로그인 잠금 기준 |
| blog.auth.login-lock-duration | 10m | 잠금 시간 |
| blog.media.upload-dir | (필수) | 정식 보관 디렉터리 |
| blog.media.temp-dir | (필수) | 임시 보관 디렉터리 |
| blog.media.temp-ttl | 24h | 임시 보관 기간 |
| blog.media.temp-quota | 200MB | 회원별 임시 합계 한도 |
| blog.media.max-size | 10MB | 파일당 최대 크기 |
| blog.media.cleanup-cron | `0 0 * * * *` | 정리 작업 주기 |
| blog.media.thumbnail-dir | (필수) | 썸네일 저장 디렉터리 |
| blog.crypto.keys | (필수, 환경 변수) | 개인정보 암호화 키 목록 `{버전: Base64 32바이트}` |
| blog.crypto.active-key-version | (필수) | 새로 암호화할 때 쓰는 키 버전 |
| blog.crypto.hash-key | (필수, 환경 변수) | 이메일 검색용 HMAC 키 |
| blog.mail.host / blog.mail.port | (필수) | SMTP 서버 (Spring Boot Mail `JavaMailSender`로 발송, research R23) |
| blog.mail.username / blog.mail.password | (필수, 환경 변수) | SMTP 인증 |
| blog.mail.from | (필수) | 보내는 사람 주소 |
| blog.mail.starttls | true | STARTTLS 사용 |
| blog.blogs.default-max-per-member | 3 | 회원별 한도(`users.max_blogs`)가 없을 때 회원 1명이 가질 수 있는 블로그 수 (FR-158). 1.0에서는 관리 화면에서 바꾸지 않음 |
| blog.legal.terms-version | (필수) | 현재 약관·개인정보처리방침 버전(4개 언어 공통) |
| blog.admin.bootstrap-super-admin-email | (선택) | 기동 시 SUPER_ADMIN이 한 명도 없으면 이 이메일의 회원을 SUPER_ADMIN으로 지정(006 FR-105). 첫 최고 관리자 지정의 유일한 경로 |
| blog.media.allowed-types | image/jpeg, image/png, image/gif, image/webp | 업로드 허용 형식(내용 기준 판별) |
| blog.jobs.trash-purge-cron | `0 30 3 * * *` | 휴지통 30일 경과 글 영구 삭제 (FR-084) |
| blog.jobs.privacy-purge-cron | `0 0 4 * * *` | 탈퇴 30일 경과 개인정보·90일 경과 로그인 기록 파기 (FR-138, FR-139) |
| blog.privacy.withdrawn-retention | 30d | 탈퇴 후 개인정보 파기까지 |
| blog.privacy.login-history-retention | 90d | 로그인 기록 보관 |
| blog.media.thumbnail.sizes | 50x50,100x100,160x160,300x200,600x400,1200x630 + 각 2배 | 허용 썸네일 크기 |
