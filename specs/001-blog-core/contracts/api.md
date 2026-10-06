# API Contract: 001 블로그 핵심

- 기준 경로: `/api/v1` (브라우저는 `https://blog.java21.net/api/v1/...`, front 서버가 backend로 프록시)
- 형식: JSON, UTF-8. 시간은 ISO-8601 UTC(`2026-10-06T04:24:19Z`).
- 인증: `access_token` 쿠키(JWT 30분). 없거나 만료면 401. 리프레시는 `refresh_token` 쿠키(`Path=/api/v1/auth`).
- 상태 변경 요청은 `Origin`이 허용 출처가 아니면 403 `ORIGIN_NOT_ALLOWED`.
- 이 문서가 기준이며, 구현 후 springdoc이 만든 OpenAPI와 일치해야 한다(front 타입은 OpenAPI에서 생성).

## 공통

**페이지 응답**
```json
{ "items": [ ... ], "page": 0, "size": 20, "totalElements": 135, "totalPages": 7 }
```
`page`는 0부터, `size` 기본 20·최대 50.

**에러 응답**
```json
{ "code": "POST_NOT_FOUND", "message": "글을 찾을 수 없습니다.", "fieldErrors": [ { "field": "title", "message": "필수입니다." } ] }
```

| HTTP | code | 상황 |
|---|---|---|
| 400 | VALIDATION_FAILED | 입력 검증 실패(fieldErrors 포함) |
| 401 | UNAUTHENTICATED | 로그인 필요, 접근 토큰 만료 |
| 401 | INVALID_CREDENTIALS | 이메일 또는 비밀번호 불일치(어느 쪽인지 밝히지 않음) |
| 401 | REFRESH_INVALID | 리프레시 토큰 없음·만료·폐기·재사용 |
| 403 | FORBIDDEN | 소유자 아님, 권한 없음 |
| 403 | ORIGIN_NOT_ALLOWED | CSRF 방어 |
| 404 | BLOG_NOT_FOUND / POST_NOT_FOUND / CATEGORY_NOT_FOUND / COMMENT_NOT_FOUND / MEDIA_NOT_FOUND | 없음, 또는 볼 권한이 없는 비공개 리소스 |
| 409 | EMAIL_TAKEN / HANDLE_TAKEN | 가입 중복 |
| 409 | CATEGORY_NAME_TAKEN | 같은 부모 아래 이름 중복 |
| 413 | MEDIA_TOO_LARGE | max-size 초과 |
| 415 | MEDIA_TYPE_NOT_ALLOWED | 허용 형식 아님(내용 기준) |
| 422 | HANDLE_RESERVED / HANDLE_INVALID | 블로그 주소 규칙 위반 |
| 422 | TAG_LIMIT_EXCEEDED / CATEGORY_DEPTH_EXCEEDED / REPLY_DEPTH_EXCEEDED | 규칙 위반 |
| 422 | COMMENTS_DISABLED | 블로그가 댓글을 막음 |
| 423 | ACCOUNT_LOCKED | 로그인 5회 실패 후 10분 잠금 |
| 429 | MEDIA_TEMP_QUOTA_EXCEEDED | 회원별 임시 한도 초과 |

## 인증 (auth) — FR-001~007

| 메서드 | 경로 | 권한 | 요청 | 성공 응답 |
|---|---|---|---|---|
| POST | /auth/signup | 비로그인 | `{ email, password, nickname, handle }` | 201 `{ userId, handle }` + 두 쿠키 설정(가입 즉시 로그인) |
| GET | /auth/handle-availability?handle= | 모두 | - | 200 `{ available: true }` 또는 `{ available: false, reason: "TAKEN" \| "RESERVED" \| "INVALID" }` |
| POST | /auth/login | 비로그인 | `{ email, password }` | 200 `{ userId, handle, nickname, role }` + 두 쿠키 설정 |
| POST | /auth/refresh | refresh 쿠키 | - | 204 + 새 access·refresh 쿠키 (회전) |
| POST | /auth/logout | 로그인 | - | 204 + 쿠키 삭제, family 폐기 |

규칙: 비밀번호 8~64자, 영문+숫자 포함. handle `^[a-z0-9](?:[a-z0-9-]{1,18})[a-z0-9]$`, 연속 하이픈 금지, 예약어 목록은 [routes.md](./routes.md#예약어).

## 회원 (user) — FR-008, FR-009

| 메서드 | 경로 | 권한 | 요청 | 응답 |
|---|---|---|---|---|
| GET | /me | 로그인 | - | 200 `{ userId, email, nickname, bio, profileImageUrl, role, blog: { handle, title } }` |
| PATCH | /me | 로그인 | `{ nickname?, bio?, profileImageMediaId? }` | 200 위와 같음 |
| DELETE | /me | 로그인 | `{ password }` | 204, 글 전부 비공개, 모든 토큰 폐기 |

## 블로그 (blog) — FR-010~012

| 메서드 | 경로 | 권한 | 요청 | 응답 |
|---|---|---|---|---|
| GET | /blogs/{handle} | 모두 | - | 200 `{ handle, title, description, coverImageUrl, commentEnabled, owner: { nickname, profileImageUrl, bio }, categories: [CategoryNode] }` |
| PATCH | /blogs/{handle} | 주인 | `{ title?, description?, coverImageMediaId?, commentEnabled? }` | 200 위와 같음 |
| GET | /blogs/{handle}/posts?category=&tag=&page= | 모두 | - | 200 Page<PostSummary> (공개 노출 가능 글만, 주인이 요청해도 같음) |
| GET | /blogs/{handle}/manage/posts?status=&page= | 주인 | - | 200 Page<PostSummary> (임시저장·비공개 포함) |

정지·탈퇴 회원의 블로그: GET /blogs/{handle}은 404 `BLOG_NOT_FOUND`(정지 안내 화면은 004에서 추가).

`CategoryNode`: `{ id, name, postCount, children: [CategoryNode] }`

`PostSummary`: `{ id, title, summary, thumbnailUrl, category: { id, name } | null, tags: [string], viewCount, commentCount, visibility, status, publishedAt, updatedAt }`

## 글 (post) — FR-013~022, FR-070

| 메서드 | 경로 | 권한 | 요청 | 응답 |
|---|---|---|---|---|
| POST | /posts | 로그인 | PostWrite | 201 PostDetail |
| GET | /posts/{id} | 모두(비공개·임시저장은 주인만) | - | 200 PostDetail, 권한 없으면 404 |
| PUT | /posts/{id} | 주인 | PostWrite | 200 PostDetail |
| DELETE | /posts/{id} | 주인 | - | 204 (status=DELETED) |
| POST | /posts/{id}/views | 모두 | - | 204 (중복 판단 후 조회수 증가, SSR loader가 호출) |

`PostWrite`:
```json
{
  "title": "제목(1~200자)",
  "contentMarkdown": "본문 Markdown(최대 200,000자)",
  "categoryId": 12,
  "tags": ["spring", "jpa"],
  "visibility": "PUBLIC",
  "publish": true
}
```
- `publish: false` → DRAFT로 저장(임시저장). 이미 PUBLISHED인 글은 false로 되돌릴 수 없음(422 `POST_ALREADY_PUBLISHED`).
- 저장 시 본문의 `/media/{id}` 참조를 등록(ATTACHED), 빠진 이미지는 ORPHANED.
- 태그는 소문자·공백 제거로 정규화, 최대 10개, 각 1~30자.

`PostDetail`:
```json
{
  "id": 123, "blogHandle": "marco",
  "title": "...", "contentHtml": "<p>...</p>", "contentMarkdown": "... (주인에게만, 그 외 null)",
  "summary": "...", "thumbnailUrl": "/media/88",
  "category": { "id": 12, "name": "Spring" }, "tags": ["spring"],
  "visibility": "PUBLIC", "status": "PUBLISHED",
  "viewCount": 10, "commentCount": 2,
  "author": { "nickname": "마르코", "profileImageUrl": null },
  "prev": { "id": 122, "title": "..." }, "next": null,
  "publishedAt": "...", "updatedAt": "..."
}
```

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

## 이미지 (media) — FR-038, FR-039, FR-071~074

| 메서드 | 경로 | 권한 | 요청 | 응답 |
|---|---|---|---|---|
| POST | /media | 로그인 | `multipart/form-data` file | 201 `{ id, url: "/media/{id}", mime, size }` (status=TEMP) |
| GET | /media/{id} *(접두어 /api/v1 없음)* | 모두 | - | 200 이미지 바이트, `Cache-Control: public, max-age=31536000, immutable` / 정리된 경우 404 |

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
