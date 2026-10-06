# API Contract: 003 포털

003이 더하는 엔드포인트와 001 응답의 확장만 적는다. 기준 경로·인증·Origin 검사·공통 응답 틀·오류 형식·페이지 규칙·관리자 API 공통 규칙은 [001 contracts/api.md](../../001-blog-core/contracts/api.md)와 [REST API 설계 규칙](../../../api-guidelines.md)을 따른다. 릴리스 노트의 독자 API와 관리 API는 001 contracts/api.md "릴리스 노트"·"릴리스 노트 관리" 절에 이미 정의되어 있으며, 003은 그 계약을 그대로 구현한다(아래 "릴리스 노트"에 구현 범위와 보충만 적었다).

- 모든 API 경로는 `/api/v1`로 시작한다(아래 표의 경로는 이 접두어를 뺀 것).
- 표의 "응답"은 공통 틀 `{ header, result, totalCount?, nextCursor? }`의 `result`에 들어가는 내용이다. "Page<X>"는 `result`가 X 배열, `totalCount`가 전체 개수이며 `page`는 0부터, `size`는 기본 20·최대 50이다. "Cursor<X>"는 `result`가 X 배열, `nextCursor`가 다음 묶음의 커서(없으면 응답에서 빠짐)다(설계 규칙 4절 "목록(커서)").
- "본문 없는 성공"은 200 + `result: null`이다(204를 쓰지 않음, 001 표의 "204"도 같은 뜻).
- "로그인" 권한 API는 로그인하지 않으면 401 `UNAUTHENTICATED`. 로그인이 필요한 응답에는 `Cache-Control: no-store`(설계 규칙 8절).
- "관리자"는 001 관리자 API 공통 규칙(ADMIN·SUPER_ADMIN, 요청마다 DB 확인, 아니면 비로그인 포함 404 `NOT_FOUND`). 관리자 쓰기는 모두 006 FR-106 작업 기록(`admin_audit_logs`)에 변경 전후 값을 남기고, 커밋 후 포털 캐시를 비운다(research P10).
- 이 문서가 기준이며, 구현 후 springdoc OpenAPI와 일치해야 한다.

## 오류 코드 (003에서 추가)

001 표의 코드는 그대로 쓴다(`POST_NOT_FOUND`, `BLOG_NOT_FOUND`, `VALIDATION_FAILED`, `NOT_FOUND` 등). 001 표에 이미 있는 릴리스 노트 코드 5개(`RELEASE_NOTE_NOT_FOUND`, `RELEASE_NOTE_VERSION_TAKEN`, `RELEASE_NOTE_REVISION_CONFLICT`, `RELEASE_NOTE_ONCE_PUBLISHED`, `RELEASE_NOTE_VERSION_LOCKED`)는 003 구현 때 backend `ErrorCode`와 front 번역에 넣는다(001 결정 8번).

| HTTP | resultCode | 상황 |
|---|---|---|
| 404 | TOPIC_NOT_FOUND | 없는 주제, 또는 운영자 숨김 주제(부모 숨김 포함)의 주제 페이지·글 목록 요청 (FR-079). 글·블로그 기본 주제로 없는 id를 보냄 |
| 422 | TOPIC_NOT_SELECTABLE | 글·블로그 기본 주제로 대분류 또는 운영자 숨김 주제를 새로 고름 (FR-076, FR-077, FR-079) |
| 409 | TOPIC_SLUG_TAKEN | 관리자 주제 추가 시 slug 중복 (FR-075) |
| 422 | TOPIC_DEPTH_EXCEEDED | 소분류 아래에 주제를 추가하려 함(2단계까지) (FR-075) |
| 404 | CURATION_NOT_FOUND | 없는 추천 |
| 409 | CURATION_LIMIT_EXCEEDED | 기간이 겹치는 추천이 이미 5개 (FR-091) |
| 422 | POST_NOT_PORTAL_ELIGIBLE | 포털 노출 조건(FR-088)을 만족하지 않는 글을 추천으로 지정 (FR-091) |
| 404 | PORTAL_EXCLUSION_NOT_FOUND | 포털에서 제외되지 않은 글의 제외 해제 (FR-093) |
| 404 | SETTING_NOT_FOUND | 모르는 운영 설정 키 (data-model system_settings) |

새 `fieldErrors[].code`는 없다. 형식 오류는 `INVALID`(`params`에 허용 값·범위), 필수 누락은 `REQUIRED`, 길이는 `TOO_LONG`·`TOO_SHORT`를 쓴다.

## 설계 규칙과 다르게 만든 것

| 항목 | 규칙 | 003 | 이유 |
|---|---|---|---|
| `PUT /admin/portal/exclusions/{postId}` | 생성은 POST + 201 | PUT 멱등 생성·사유 변경, 200 | 글 하나에 제외 행은 하나(`uk_portal_exclusions_post`)라 글 id가 곧 자원 식별자다. 두 관리자가 동시에 눌러도 결과가 하나로 수렴한다 |

## 001 응답 확장

필드 추가만 한다(설계 규칙 9절, v1 안에서 허용).

| API | 추가 필드 | 내용 |
|---|---|---|
| GET /me | `unseenReleaseNote` (001에 이미 있음, 003 전까지 null) | `{ version, title }` 또는 null. research P11의 배너 조건(FR-163) |
| GET /blogs/{handle} | `portalEnabled: boolean` | "포털에 내 글 노출"(FR-089, 기본 true) |
| | `defaultTopicId: number \| null` | 블로그 기본 주제(소분류, FR-077) |
| PATCH /blogs/{handle} (요청) | `portalEnabled?`, `defaultTopicId?` | 주인만. `portalEnabled`는 null로 지울 수 없음(400 `REQUIRED`). `defaultTopicId`는 null이면 지우고, 값이면 소분류·운영자 숨김 아님이어야 함(404 `TOPIC_NOT_FOUND` / 422 `TOPIC_NOT_SELECTABLE`, 지금 값과 같으면 검사하지 않음). 응답은 위 GET과 같음 |
| DraftWrite (POST /blogs/{handle}/posts/drafts, PUT /posts/{id}/draft 요청) | `topicId?: number \| null` | 작성 중 주제(소분류). 저장 때는 검증하지 않고 발행 때 검증(research P9) |
| GET /posts/{id}/draft | `topicId: number \| null` | 작성 중 사본의 주제, 사본이 없으면 발행본의 주제 |
| PublishSettings (POST /posts/{id}/publish 요청) | `topicId?: number \| null` | 값이 있으면 그 주제, null·생략이면 작성 중 사본의 값, 사본이 없으면 지금 발행본의 값(001 카테고리 규칙과 같음). 지금 발행본과 다른 값이면 404 `TOPIC_NOT_FOUND` / 422 `TOPIC_NOT_SELECTABLE` |
| GET /posts/{id} (PostDetail) | `topicId: number \| null` | 글의 주제(소분류). 주제 이름은 front가 `GET /topics` 트리로 찾는다 |

## 주제 (topic) — FR-075~079, FR-147

| 메서드 | 경로 | 권한 | 요청 | 응답 |
|---|---|---|---|---|
| GET | /topics | 모두 | - | 200 `[TopicNode]`(대분류 순서대로, 각 `children`은 소분류 순서대로). 운영자 숨김 주제와 숨긴 대분류의 소분류는 빠진다 |
| GET | /topics/{slug}/posts?sort=&page=&size= | 모두 | - | 200 Page<PortalCard>. `slug`는 대분류(소속 소분류 글 전체) 또는 소분류(그 글만). `sort`: `latest`(기본, 발행 최신순) / `popular`(최근 7일 인기 점수 순, 점수가 있는 글만). 운영자 숨김 주제는 404 `TOPIC_NOT_FOUND`. 자동 숨김은 영향 없음. `sort`가 다른 값이면 400 `VALIDATION_FAILED`(`INVALID`, `params.allowed`) (FR-078) |

`TopicNode`:
```json
{
  "id": 12, "slug": "it-internet", "parentId": 5,
  "names": { "ko": "IT 인터넷", "en": "IT & Internet", "ja": "IT・インターネット", "zh-CN": "IT 互联网" },
  "cardColor": null,
  "onTab": true,
  "children": []
}
```
- `cardColor`: `#RRGGBB` 또는 null(소분류가 null이면 front가 대분류 색을 쓴다).
- `onTab`: 주제 탭에 보이는지(FR-147 자동 숨김 계산 결과, research P2). 대분류는 메인 주제 탭, 소분류는 대분류 페이지의 소분류 목록에 쓴다. 최대 5분 지연(FR-090).
- 소분류의 `children`은 항상 `[]`.

## 포털 메인 (portal) — FR-034, FR-080, FR-085~088, FR-090

| 메서드 | 경로 | 권한 | 요청 | 응답 |
|---|---|---|---|---|
| GET | /portal | 모두 | - | 200 PortalHome |
| GET | /portal/latest?cursor= | 모두 | - | 200 Cursor<PortalCard>(20편). 커서 다음의 최신 글, 묶음 안에서 같은 블로그 2편까지. 커서 형식이 틀리면 400 `VALIDATION_FAILED`(field `cursor`, `INVALID`) |

`PortalHome`:
```json
{
  "curations": [PortalCard],
  "popular": [PortalCard],
  "latest": { "items": [PortalCard], "nextCursor": "eyJwIjoxNzU5NzI0MjU5MDAwLCJpIjoxMjN9" },
  "popularTags": [ { "name": "spring", "postCount": 14 } ],
  "newBlogs": [ { "handle": "marco", "title": "마르코의 블로그", "description": null, "coverImageUrl": null,
                  "owner": { "nickname": "마르코", "profileImageUrl": null }, "firstPublishedAt": "2026-10-01T02:00:00Z" } ],
  "generatedAt": "2026-10-06T04:24:19Z"
}
```
- `curations`: 지금 노출 기간 안이고 포털 노출 조건을 만족하는 추천 글, 운영자가 정한 순서(최대 5). 조건을 잃은 추천은 자동으로 빠진다(FR-092).
- `popular`: 최근 7일 인기 점수 상위 12편, 같은 블로그 2편까지(FR-080, FR-087).
- `latest`: 발행 최신순 20편, 같은 블로그 2편까지. `nextCursor`가 null이면 더 없음.
- `popularTags`: 최근 7일 발행된 포털 노출 글의 태그 사용 수 상위 20개(같으면 이름순).
- `newBlogs`: 최근 30일 안에 첫 글을 발행했고 포털 노출 글이 있는 블로그 6개, 첫 발행 최신순.
- `generatedAt`: 이 묶음을 계산한 시각(캐시, 최대 5분 전). front는 상대 시각 기준으로 요청 시각을 쓴다.
- 빈 영역은 `[]`(또는 `latest.items: []`)이며 front가 숨긴다.

`PortalCard`:
```json
{
  "id": 123, "title": "Spring Boot 4 시작하기", "summary": "요약 150자...",
  "thumbnailUrl": "/media/k3Jd9fQ2xLmA7pZ0bR5tYw", "topicId": 12,
  "blog": { "handle": "marco", "title": "마르코의 블로그" },
  "author": { "nickname": "마르코", "profileImageUrl": "/media/Ab3..." },
  "publishedAt": "2026-10-06T01:24:19Z", "likeCount": 3, "commentCount": 2
}
```
- 포털 카드는 포털 노출 조건(FR-088: 본문 노출 가능 + 블로그 포털 켜짐 + 제외 아님 + 가입 24시간 경과 + 본문 200자 이상)을 만족하는 글만 담는다. 보호 글은 본문 노출 가능이 아니므로 포털에 나오지 않는다(001 글 노출 매트릭스).
- `thumbnailUrl`이 null이면 front가 주제 카드 색으로 기본 이미지를 그린다(FR-085). `topicId`가 null이면 기본 회색.

포털 반영(FR-090): 위 응답과 주제 API는 최대 5분(`blog.portal.cache-ttl`) 캐시된다. 글의 발행·수정·비공개 전환·삭제·숨김, 회원 정지, 블로그의 포털 끄기는 5분 안에 반영되고, 관리자의 추천·제외·주제·설정 변경은 바로 반영된다.

## 끝까지 읽음 (read complete) — FR-086

| 메서드 | 경로 | 권한 | 요청 | 응답 |
|---|---|---|---|---|
| POST | /posts/{id}/read-complete | 모두 | - | 200 `null`. 상세를 볼 수 있는 글이 아니면 404 `POST_NOT_FOUND`. 같은 방문자(회원 ID 또는 방문자 쿠키)가 30분 안에 다시 보내면 세지 않고 같은 응답. 세면 그날(UTC)의 `post_daily_stats.read_completes` + 1 |

- front 글 상세가 본문 끝에 도달했을 때 브라우저에서 한 번 보낸다(Origin 검사 대상). 방문자 쿠키가 없으면 001 조회수 API처럼 발급한다.
- 001 `POST /posts/{id}/views`는 같은 트랜잭션에서 `post_daily_stats.views` + 1을 더 한다(응답 변경 없음).

## 릴리스 노트 (release note) — FR-161~166

001 contracts/api.md "릴리스 노트" 절의 독자 API 6개(`GET /release-notes`, `GET /release-notes/search`, `GET /release-notes/{version}`, `GET /release-notes/{version}/revisions`, `GET /release-notes/{version}/revisions/{revisionNo}`, `POST /me/release-notes/seen`)와 "릴리스 노트 관리" 절의 관리 API 9개를 그대로 구현한다(관리 화면은 006). 보충:

- `POST /me/release-notes/seen`의 성공은 200 + `result: null`(001 표의 "204").
- `DELETE /admin/release-notes/{id}`의 성공은 200 + `result: null`(001 표의 "204").
- `GET /release-notes`의 `portalCard`는 최신 게시 노트의 `firstPublishedAt`이 `blog.release-notes.portal-card-days`(14d) 이내일 때만 값이 있다. 게시된 노트가 없으면 `{ items: [], portalCard: null }`.
- `lang`은 `ko`·`en`·`ja`·`zh-CN`만(아니면 400 `VALIDATION_FAILED`, `INVALID`). 생략하면 `Accept-Language`·회원 설정 순의 화면 언어(001 FR-149).
- 검색 `q`는 2~100자, 공백으로 나눈 2자 이상 낱말 최대 5개를 모두 포함(002 검색 규칙과 같음). 결과는 버전 내림차순 Page.
- `contentHtml`은 h2~h4에 `id` 앵커를 가진 살균된 HTML이며 `toc`와 같은 앵커를 쓴다(001 contracts의 앵커 규칙).
- 초안(DRAFT)은 관리자에게도 독자 API로는 404 `RELEASE_NOTE_NOT_FOUND`(001 contracts).
- 관리 API의 `PUT`·`POST .../publish`·`unpublish`·`DELETE`는 커밋 후 포털 캐시를 비운다(카드·배너가 바로 바뀌도록).

## 관리자: 주제 (admin topic) — FR-075, FR-079, FR-147, 006 FR-102

| 메서드 | 경로 | 권한 | 요청 | 응답 |
|---|---|---|---|---|
| GET | /admin/topics | 관리자 | - | 200 `[AdminTopicNode]`(숨김 포함 전체 트리) |
| POST | /admin/topics | 관리자 | `{ parentId: number \| null, slug, names: { ko, en, ja, "zh-CN" }, cardColor?: string \| null }` | 201 AdminTopicNode + `Location: /api/v1/admin/topics/{id}`. 같은 부모의 마지막 순서로 추가. slug 형식 `^[a-z0-9]+(-[a-z0-9]+)*$` 2~40자(아니면 400 `INVALID_FORMAT`), 중복 409 `TOPIC_SLUG_TAKEN`, `parentId`가 소분류면 422 `TOPIC_DEPTH_EXCEEDED`, 없는 부모 404 `TOPIC_NOT_FOUND`, 이름 4개 언어 모두 1~50자(`REQUIRED`·`TOO_LONG`, field `names.ja` 등), `cardColor`는 `^#[0-9A-Fa-f]{6}$`. 작업 기록 `TOPIC_CREATE` |
| PATCH | /admin/topics/{id} | 관리자 | `{ names?, cardColor?, adminHidden?, pinnedOnTab? }` (JSON Merge Patch. `names`는 넣은 언어만 바꾸며 빈 값 불가, `cardColor: null`은 지움, `adminHidden`·`pinnedOnTab`은 null 불가) | 200 AdminTopicNode. slug와 부모는 바꿀 수 없다(요청에 없음). 작업 기록: 이름·색 `TOPIC_UPDATE`, 숨김 `TOPIC_HIDE`/`TOPIC_UNHIDE`, 고정 `TOPIC_PIN`/`TOPIC_UNPIN`(바뀐 항목마다 한 행) |
| PUT | /admin/topics/order | 관리자 | `{ parentId: number \| null, ids: [number] }` | 200 `[AdminTopicNode]`(전체 트리). `ids`는 그 부모(null이면 대분류)의 자식 전체를 새 순서로 나열해야 한다(빠지거나 다른 부모의 id가 있으면 400 `VALIDATION_FAILED`, field `ids`, `INVALID`). 작업 기록 `TOPIC_REORDER` |

`AdminTopicNode`: TopicNode + `{ adminHidden, effectiveHidden, pinnedOnTab, recentPostCount, createdAt, updatedAt }`
- `effectiveHidden`: 자신 또는 부모가 운영자 숨김. `recentPostCount`: 최근 30일 포털 노출 글 수(대분류는 소속 소분류 합, FR-147 판단에 쓰는 값, 최대 5분 지연).
- 삭제 API는 없다(주제는 숨긴다, FR-079). 대분류를 숨기면 소분류도 숨김으로 본다(저장값은 그대로).

## 관리자: 포털 (admin portal) — FR-086, FR-088, FR-091~093, FR-147

| 메서드 | 경로 | 권한 | 요청 | 응답 |
|---|---|---|---|---|
| GET | /admin/portal/posts/{id} | 관리자 | - | 200 `{ id, title, blog: { handle, title }, status, visibility, publishedAt, portalEligible, ineligibleReasons: [string], excluded: { reason, excludedBy: { userId, nickname }, createdAt } \| null }`. 콘솔에서 글 주소·번호로 글을 찾을 때. 없는 글 404 `POST_NOT_FOUND` |
| GET | /admin/portal/curations?status=&page= | 관리자 | - | 200 Page<Curation>. `status`: `ACTIVE`(지금 기간 안) / `UPCOMING` / `ENDED` / 생략 시 전체. `ACTIVE`·`UPCOMING`은 `startsAt`·`sortOrder` 순, `ENDED`·전체는 `endsAt` 내림차순 |
| POST | /admin/portal/curations | 관리자 | `{ postId, startsAt, endsAt, sortOrder? }` | 201 Curation + `Location`. 글이 없으면 404 `POST_NOT_FOUND`, 포털 노출 조건을 만족하지 않으면 422 `POST_NOT_PORTAL_ELIGIBLE`(`ineligibleReasons`는 `resultMessage`에만), `endsAt <= startsAt`이면 400(field `endsAt`, `INVALID`), 기간이 겹치는 추천이 이미 5개면 409 `CURATION_LIMIT_EXCEEDED`. `sortOrder` 생략 시 0. 작업 기록 `CURATION_CREATE` |
| PATCH | /admin/portal/curations/{id} | 관리자 | `{ startsAt?, endsAt?, sortOrder? }` | 200 Curation. 같은 검증(겹침 수에서 자기 자신 제외). 없으면 404 `CURATION_NOT_FOUND`. 작업 기록 `CURATION_UPDATE` |
| DELETE | /admin/portal/curations/{id} | 관리자 | - | 200 `null`. 없으면 404 `CURATION_NOT_FOUND`. 작업 기록 `CURATION_DELETE` |
| GET | /admin/portal/exclusions?page= | 관리자 | - | 200 Page<Exclusion>(제외 최신순) |
| PUT | /admin/portal/exclusions/{postId} | 관리자 | `{ reason }` (1~500자) | 200 Exclusion. 제외가 없으면 만들고, 있으면 사유를 바꾼다(멱등). 글 상태와 관계없이 된다. 없는 글 404 `POST_NOT_FOUND`. 작업 기록 `PORTAL_EXCLUDE`(사유 변경도 같은 코드, 전후 사유) |
| DELETE | /admin/portal/exclusions/{postId} | 관리자 | - | 200 `null`(행 삭제). 제외되지 않은 글이면 404 `PORTAL_EXCLUSION_NOT_FOUND`. 작업 기록 `PORTAL_UNEXCLUDE` |

`Curation`: `{ id, post: { id, title, blogHandle }, startsAt, endsAt, sortOrder, status: "ACTIVE" | "UPCOMING" | "ENDED", portalEligible, createdBy: { userId, nickname }, createdAt, updatedAt }` — `portalEligible`이 false인 ACTIVE 추천은 메인에 보이지 않는다(FR-092, 콘솔이 표시).

`Exclusion`: `{ post: { id, title, blogHandle }, reason, excludedBy: { userId, nickname }, createdAt, updatedAt }`

포털 제외는 포털(메인·주제 페이지·인기 태그·새 블로그·추천)에만 영향을 주고 블로그·검색·RSS·사이트맵에는 영향이 없다(FR-093, 001 글 노출 매트릭스).

## 관리자: 운영 설정 (admin setting) — FR-086, FR-088, FR-147, 006 FR-102

| 메서드 | 경로 | 권한 | 요청 | 응답 |
|---|---|---|---|---|
| GET | /admin/settings?prefix= | 관리자 | - | 200 `[Setting]`(알려진 키 전체 또는 `prefix`로 시작하는 키, 키 이름순) |
| PUT | /admin/settings/{key} | 관리자 | `{ value }` | 200 Setting. 모르는 키 404 `SETTING_NOT_FOUND`, 형식·범위가 틀리면 400 `VALIDATION_FAILED`(field `value` 또는 `value.like` 등, `INVALID` + `params`). 작업 기록 `SETTING_CHANGE`(`target_key`=키, 전후 값) |
| DELETE | /admin/settings/{key} | 관리자 | - | 200 Setting(기본값으로 되돌린 상태, `overridden: false`). 행이 없어도 200. 모르는 키 404 `SETTING_NOT_FOUND`. 작업 기록 `SETTING_CHANGE` |

`Setting`: `{ key, value, defaultValue, overridden, updatedBy: { userId, nickname } | null, updatedAt | null }` — `value`는 지금 쓰는 값(행이 없으면 기본 프로퍼티 값), `defaultValue`는 프로퍼티 값.

003의 키(005·007이 더한다, data-model system_settings):

| key | value 형식 | 기본값(프로퍼티) |
|---|---|---|
| portal.score-weights | `{ view, readComplete, like, comment }` 각 0~1000 숫자, `halfLifeHours` 1~720, `reportPenalty` 0~1. 모든 필드 필수 | `{ "view": 1, "readComplete": 5, "like": 10, "comment": 8, "halfLifeHours": 48, "reportPenalty": 0.5 }` (`blog.portal.score-weights.*`) |
| portal.new-member-delay | ISO-8601 기간 문자열 `PT0S`~`P30D` | `"PT24H"` (`blog.portal.new-member-delay`) |
| portal.min-content-length | 정수 0~10000 | `200` (`blog.portal.min-content-length`) |
| portal.topic-auto-hide-threshold | 정수 0~1000 | `20` (`blog.portal.topic-auto-hide-threshold`) |

## 프로퍼티 (backend `application.yml`, 003에서 추가)

| 키 | 기본값 | 설명 |
|---|---|---|
| blog.portal.cache-ttl | 5m | 포털 목록·인기 점수·주제별 글 수 캐시 수명(FR-090 반영 한도). `0s`면 캐시하지 않음(테스트·E2E) |
| blog.portal.cache-max-size | 2000 | 포털 캐시 최대 항목 수 |
| blog.portal.score-weights.view / read-complete / like / comment / half-life-hours / report-penalty | 1 / 5 / 10 / 8 / 48 / 0.5 | 인기 점수 가중치 기본값(`system_settings` 행이 없을 때) |
| blog.portal.new-member-delay | 24h | 가입 후 포털 노출까지 대기 기본값 |
| blog.portal.min-content-length | 200 | 포털 노출 최소 본문 길이 기본값 |
| blog.portal.topic-auto-hide-threshold | 20 | 주제 자동 숨김 기준 기본값(최근 30일 글 수) |
| blog.portal.popular-window | 7d | 인기 점수·인기 태그 집계 기간 |
| blog.portal.topic-count-window | 30d | 주제 자동 숨김 글 수·새로 시작한 블로그 기간 |
| blog.jobs.post-stats-purge-cron | `0 45 4 * * *` | 90일 지난 `post_daily_stats` 정리 |
| blog.posts.stats-retention | 90d | `post_daily_stats` 보관 기간 |

`blog.release-notes.portal-card-days`(14d)는 001 contracts에 이미 있다.
