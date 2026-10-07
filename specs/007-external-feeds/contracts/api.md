# API Contract: 007 외부 블로그 RSS 수집과 주제 자동 분류

007이 더하는 API와 003 API 확장만 적는다. 기준 경로·인증·Origin 검사·공통 응답 틀·오류 형식·페이지 규칙은 [001 contracts/api.md](../../001-blog-core/contracts/api.md), 포털·주제·설정 API는 [003 contracts/api.md](../../003-portal/contracts/api.md), 신고는 [005 contracts/api.md](../../005-trackback-moderation/contracts/api.md), 관리자 API 공통 규칙은 [006 contracts/api.md](../../006-admin-consoles/contracts/api.md), 설계 규칙은 [REST API 설계 규칙](../../../api-guidelines.md)을 따른다.

- 모든 API 경로는 `/api/v1`로 시작한다(아래 표의 경로는 이 접두어를 뺀 것). 예외: 썸네일 `GET /media/external/{key}`(001 `/media/**`와 같이 접두어 없음).
- 표의 "응답"은 공통 틀 `{ header, result, totalCount? }`의 `result`에 들어가는 내용이다. "Page<X>"는 `result`가 X 배열, `totalCount`가 전체 개수이며 `page`는 0부터, `size`는 기본 20·최대 50이다.
- 권한: "회원"은 로그인 회원(아니면 401 `UNAUTHENTICATED`). "관리 회원"은 그 외부 블로그의 `member_id` 회원(아니면 존재를 숨겨 404 `EXTERNAL_BLOG_NOT_FOUND`). "인증된 주인"은 관리 회원이면서 `ownership_verified = true`(아니면 403 `EXTERNAL_BLOG_OWNERSHIP_REQUIRED`). "관리자"는 006 규칙(요청마다 DB의 현재 권한, 아니면 404 `NOT_FOUND`).
- 회원·관리자 API 응답은 `Cache-Control: no-store`. 상태를 바꾸는 요청은 `Origin` 검사(001 R27). 관리자의 모든 변경은 같은 트랜잭션에서 작업 기록(006 FR-106)에 남는다(006 SC-017 행렬 테스트 표에 007 행을 더함).
- 외부 블로그 이름·제목·요약은 외부에서 온 일반 텍스트다. front는 이스케이프 출력만 한다.
- 이 문서가 기준이며, 구현 후 springdoc OpenAPI와 일치해야 한다(`OpenApiContractTest`).

## 오류 코드 (007에서 추가)

001~006 표의 코드는 그대로 쓴다(`VALIDATION_FAILED`, `UNAUTHENTICATED`, `NOT_FOUND`, `TOO_MANY_REQUESTS`, `TOPIC_NOT_FOUND`, `TOPIC_NOT_SELECTABLE`, `MEDIA_NOT_FOUND` 등).

| HTTP | resultCode | 상황 | params |
|---|---|---|---|
| 422 | EXTERNAL_FEED_URL_NOT_ALLOWED | 주소 형식·스킴·포트·`user@`·내부망·우리 서비스 주소 (FR-116, Edge Cases) | `reason`: `INVALID_URL` / `SCHEME` / `PORT` / `CREDENTIALS` / `PRIVATE_ADDRESS` / `SELF` |
| 422 | EXTERNAL_FEED_NOT_FOUND | 블로그 주소에서 RSS·Atom을 찾지 못함 (FR-109) | `tried`: 시도한 주소 수 |
| 422 | EXTERNAL_FEED_UNREADABLE | 피드를 받거나 읽지 못함 | `result`: `HTTP_ERROR` / `TIMEOUT` / `TOO_LARGE` / `PARSE_ERROR` / `DNS_ERROR` / `BLOCKED_ADDRESS`, `httpStatus?` |
| 409 | EXTERNAL_BLOG_ALREADY_REGISTERED | 같은 피드의 거절·해제되지 않은 등록이 있음 (FR-112, US1 AS5) | `externalBlogId`, `status`, `claimable`(BLOCKED가 아니면 true) |
| 409 | EXTERNAL_BLOG_LIMIT_EXCEEDED | 회원당 3개 한도 (FR-112) | `max`: 3 |
| 404 | EXTERNAL_BLOG_NOT_FOUND | 없거나 관리 회원이 아님 | - |
| 409 | EXTERNAL_BLOG_STATE_CONFLICT | 지금 상태에서 할 수 없는 전이(승인·거절은 PENDING만, 재개는 PAUSED·STOPPED만, BLOCKED 넘겨받기 등) | `status`, `action` |
| 403 | EXTERNAL_BLOG_OWNERSHIP_REQUIRED | 소유 인증 없이 글 주제·기본 주제 변경 (FR-120, 결정 표 18번) | - |
| 404 | EXTERNAL_VERIFICATION_NOT_FOUND | 없는 인증이거나 다른 회원의 인증 | - |
| 422 | EXTERNAL_VERIFICATION_EXPIRED | 24시간 지난 인증 코드 (FR-110) | `expiredAt` |
| 422 | EXTERNAL_VERIFICATION_CODE_NOT_FOUND | 피드·블로그 페이지 어디에서도 코드를 찾지 못함 (US1 AS3) | `checked`: `["FEED","SITE"]`, `failures`: `{ FEED?: 결과, SITE?: 결과 }` |
| 404 | EXTERNAL_POST_NOT_FOUND | 없거나 볼 수 없는 외부 글 | - |
| 404 | CLASSIFICATION_REVIEW_NOT_FOUND | 없는 검수 | - |
| 409 | CLASSIFICATION_REVIEW_CLOSED | PENDING이 아닌 검수를 확정 | `status` |
| 409 | TOPIC_MAPPING_RULE_KEYWORD_TAKEN | 정규화한 키워드가 이미 있음 | `ruleId` |

없는 매핑 규칙은 별도 코드 없이 001 `NOT_FOUND`(404)로 둔다(관리자 화면 하나뿐, 코드 수를 줄임). 필드 오류(`fieldErrors[].code`)는 001 값(`REQUIRED`, `INVALID`, `INVALID_FORMAT`, `TOO_LONG`)만 쓴다.

## 설계 규칙과 다르게 만든 것

| 항목 | 규칙 | 007 | 이유 |
|---|---|---|---|
| `GET /external-posts/{id}/visit` | GET은 안전(부수 효과 없음) | 클릭 수를 세고 302 | 카드가 JS 없이 일반 링크로 동작해야 한다(원칙 V). 001 조회수와 같은 종류의 집계이고, robots.txt `Disallow: /api/`와 `nofollow`로 크롤러를 막는다(research E14) |
| 상태 전이 `POST /admin/external-blogs/{id}/approve` 등 | 상태 변경은 PATCH | 동작별 POST 하위 경로 | 전이마다 필요한 입력(거절 사유, 차단 사유)·알림·작업 기록이 달라 한 PATCH로 묶으면 검증이 복잡하다. 005 신고 처리(`POST …/resolve`)와 같은 방식 |
| 003 `PortalCard.author` | 기존 응답은 항상 값 | 외부 카드는 `null` | 외부 글에는 우리 회원 작성자가 없다. `source`로 구분 |
| `POST /external-blog-previews` | 조회는 GET | POST(결과를 저장하지 않음) | 서버가 외부로 요청을 보내는 동작이고 입력 주소를 로그·캐시 키에 남기지 않으려고 본문으로 받는다. 속도 제한 대상 |

## 공개 API

| 메서드 | 경로 | 권한 | 요청 | 응답 |
|---|---|---|---|---|
| GET | /external-posts/{id}/visit | 모두 | - | 302 `Location: {원문 링크}`, `Cache-Control: no-store`, `Referrer-Policy: no-referrer`. 포털 노출 조건(research E13)을 만족하지 않으면 404 `EXTERNAL_POST_NOT_FOUND`. 같은 방문자·같은 글 30분 1회만 셈 (FR-124, research E14) |
| GET | /media/external/{key} | 모두 | - | 200 이미지(600x400, `image/jpeg` 또는 `image/png`), `Cache-Control: public, max-age=86400`, `nosniff`, `Content-Disposition: inline`. 키 형식이 아니거나 파일이 없거나, 글이 ACTIVE가 아니거나 블로그가 소유 인증되지 않았으면 404 `MEDIA_NOT_FOUND` (FR-128, research E7) |

## 003 API 확장 (포털)

| API | 변경 | 비고 |
|---|---|---|
| GET /portal (PortalHome) | `popular`·`latest.items`에 외부 카드가 섞임. `curations`·`popularTags`·`newBlogs`는 그대로 내부만 | 최신은 블로그당 2편 제한을 외부 블로그에도 적용 (FR-123) |
| GET /portal/latest?cursor=&source= | `source`: `all`(기본) / `internal` / `external`. 다른 값이면 400 `VALIDATION_FAILED`(field `source`, `INVALID`, `params.allowed`). 커서에 출처가 들어감(옛 커서는 내부로 읽음). 커서와 `source`가 다르게 섞여도 오류 아님(커서 위치부터 그 필터로) | FR-124 |
| GET /topics/{slug}/posts?sort=&page=&size=&source= | `source` 같은 규칙. `latest`는 두 출처 합친 발행 최신순, `popular`는 같은 점수 스냅숏. `page`가 49를 넘으면 빈 목록(`totalCount`는 그대로) | research E13 |
| PortalCard | 필드 추가: `source: "INTERNAL" \| "EXTERNAL"`, `visitUrl: string \| null`, `externalBlog: { id, title, siteHost } \| null`. 외부 카드는 `blog: { handle: null, title }`, `author: null`, `likeCount`·`commentCount` 0, `topicId` 항상 값, `thumbnailUrl`은 인증된 블로그의 `/media/external/{key}` 또는 null | 내부 카드는 `source: "INTERNAL"`, `visitUrl`·`externalBlog` null로 기존과 같음 |

```ts
type PortalCard = {
  id: number;                      // 출처별 id(내부 posts.id, 외부 external_posts.id) — front 키는 `${source}-${id}`
  source: "INTERNAL" | "EXTERNAL";
  title: string;
  summary: string | null;          // 외부: 태그 제거 텍스트 최대 200자
  thumbnailUrl: string | null;
  topicId: number | null;
  blog: { handle: string | null; title: string };
  author: { nickname: string; profileImageUrl: string | null } | null;
  externalBlog: { id: number; title: string; siteHost: string } | null;
  visitUrl: string | null;         // "/api/v1/external-posts/{id}/visit"
  publishedAt: string;
  likeCount: number;
  commentCount: number;
};
```

- 주제 자동 숨김(003 FR-147)의 최근 30일 글 수에 외부 글이 더해진다(`GET /topics`의 `onTab` 판단). 응답 모양은 그대로.
- 검색(`GET /search`), 블로그 RSS·Atom, 사이트맵은 바뀌지 않는다(외부 글 0건, FR-125).

## 회원 API (외부 블로그 등록·관리)

| 메서드 | 경로 | 권한 | 요청 | 응답 |
|---|---|---|---|---|
| POST | /external-blog-previews | 회원 | `{ url }` (블로그 주소 또는 피드 주소, 1~1000자) | 200 FeedPreview. 주소 검사 실패 422 `EXTERNAL_FEED_URL_NOT_ALLOWED`, 피드 없음 422 `EXTERNAL_FEED_NOT_FOUND`, 읽기 실패 422 `EXTERNAL_FEED_UNREADABLE`. 회원당 시간당 20회(429). 같은 피드 10분 캐시 (FR-109, research E3) |
| POST | /me/external-blog-verifications | 회원 | `{ feedUrl }` | 201 Verification + `Location`. 같은 회원·같은 피드에 유효한 코드가 있으면 200으로 그것(재사용). 주소 검사는 미리보기와 같음 (FR-110) |
| POST | /me/external-blog-verifications/{id}/check | 회원(발급받은 본인) | - | 200 Verification(`verifiedAt` 채움, `claimableExternalBlogId`: 같은 피드의 다른 회원·미소유 활성 등록이 있으면 그 id). 이미 인증됐으면 그대로 200. 만료 422 `EXTERNAL_VERIFICATION_EXPIRED`, 못 찾음 422 `EXTERNAL_VERIFICATION_CODE_NOT_FOUND`, 남의 인증 404 `EXTERNAL_VERIFICATION_NOT_FOUND`. 회원당 시간당 10회(429) (US1 AS3) |
| GET | /me/external-blogs | 회원 | - | 200 `[MyExternalBlog]`(만든 순, 거절·해제 포함 최근 것 먼저, 최대 20) — 어느 블로그 관리에서 열어도 같은 목록(spec Assumptions) |
| POST | /me/external-blogs | 회원 | `{ feedUrl, defaultTopicId, verificationId?: number }` | 201 MyExternalBlog(`status: PENDING`) + `Location`. 피드 확인 실패 422 `EXTERNAL_FEED_UNREADABLE`, 중복 409 `EXTERNAL_BLOG_ALREADY_REGISTERED`, 한도 409 `EXTERNAL_BLOG_LIMIT_EXCEEDED`, 주제 404 `TOPIC_NOT_FOUND`/422 `TOPIC_NOT_SELECTABLE`, `verificationId`가 같은 회원·같은 피드의 성공한 인증이 아니면 400(field `verificationId`, `INVALID`) (FR-111, FR-112) |
| GET | /me/external-blogs/{id} | 관리 회원 | - | 200 MyExternalBlog |
| PATCH | /me/external-blogs/{id} | 인증된 주인 | `{ defaultTopicId }` | 200 MyExternalBlog. 이후 수집되는 글의 기본 주제(이미 수집된 DEFAULT 글은 그대로) |
| POST | /external-blogs/{id}/claim | 회원 | `{ verificationId }` | 200 MyExternalBlog(`ownershipVerified: true`). 인증이 그 회원의 성공한 인증이고 피드 해시가 같아야 함(아니면 400 field `verificationId` `INVALID`), BLOCKED면 409 `EXTERNAL_BLOG_STATE_CONFLICT`, 거절·해제·없는 등록 404 `EXTERNAL_BLOG_NOT_FOUND`, 한도 409 `EXTERNAL_BLOG_LIMIT_EXCEEDED` (FR-129, US1 AS8) |
| POST | /me/external-blogs/{id}/release | 관리 회원 | `{ deletePosts: boolean }` | 200 MyExternalBlog(`status: RELEASED`). PENDING·ACTIVE·PAUSED·STOPPED만(아니면 409 `EXTERNAL_BLOG_STATE_CONFLICT`). 포털에서 바로 사라짐, `deletePosts`면 수집된 글 즉시 삭제 (FR-126, research E16) |
| GET | /me/external-blogs/{id}/posts?page=&size= | 관리 회원 | - | 200 Page<MyExternalPost>(발행 최신순) |
| PUT | /me/external-blogs/{id}/posts/{postId}/topic | 인증된 주인 | `{ topicId }` | 200 MyExternalPost(`topicSource: OWNER`). 주제 규칙은 003(소분류, 숨김 아님). 그 글의 PENDING 검수는 SKIPPED. REMOVED 글 404 `EXTERNAL_POST_NOT_FOUND` (FR-120) |

```ts
type FeedPreview = {
  feedUrl: string;                 // 리다이렉트를 따라간 최종 피드 주소
  siteUrl: string | null;
  title: string | null;
  format: "RSS" | "ATOM";
  recentPosts: { title: string; link: string; publishedAt: string | null }[];   // 최대 3
  registered: { externalBlogId: number; status: ExternalBlogStatus; claimable: boolean; mine: boolean } | null;
};
type ExternalBlogStatus = "PENDING" | "REJECTED" | "ACTIVE" | "PAUSED" | "STOPPED" | "BLOCKED" | "RELEASED";
type Verification = {
  id: number;
  feedUrl: string;
  code: string;                    // "java21-verify-XXXXXXXXXXXX"
  expiresAt: string;
  verifiedAt: string | null;
  claimableExternalBlogId: number | null;
};
type MyExternalBlog = {
  id: number;
  title: string | null;
  siteUrl: string | null;
  feedUrl: string;
  feedFormat: "RSS" | "ATOM" | null;
  status: ExternalBlogStatus;
  registrationType: "MEMBER_REQUEST" | "ADMIN_DIRECT";
  ownershipVerified: boolean;
  defaultTopicId: number;
  rejectReason: string | null;
  lastFetchedAt: string | null;
  lastSuccessAt: string | null;
  lastFetchResult: FetchResultCode | null;
  postCount: number;               // ACTIVE 외부 글 수
  createdAt: string;
};
type FetchResultCode = "OK" | "NOT_MODIFIED" | "HTTP_ERROR" | "TIMEOUT" | "TOO_LARGE" | "PARSE_ERROR" | "BLOCKED_ADDRESS" | "DNS_ERROR";
type MyExternalPost = {
  id: number;
  title: string;
  summary: string | null;
  link: string;
  thumbnailUrl: string | null;     // 인증된 블로그만
  publishedAt: string | null;
  topicId: number;
  topicSource: "OWNER" | "REVIEW" | "RULE" | "AUTO" | "DEFAULT";
  status: "ACTIVE" | "REMOVED";
  removedReason: "LINK_BROKEN" | "BLOG_BLOCKED" | "MEMBER_WITHDRAWN" | "REPORT" | "ADMIN" | null;
  clickCount: number;
};
```

## 관리자 API (admin/external)

| 메서드 | 경로 | 권한 | 요청 | 응답 |
|---|---|---|---|---|
| GET | /admin/external-blogs?status=&q=&page=&size= | 관리자 | - | 200 Page<AdminExternalBlog>. `status` 생략 시 전체(PENDING 먼저, 그다음 최근 만든 순), 값이 있으면 그 상태의 최근 순. `q`는 제목·피드 주소 부분 일치(2~100자) |
| POST | /admin/external-blogs | 관리자 | `{ feedUrl, defaultTopicId, registrationBasis }` (`registrationBasis` 1~500자 필수) | 201 AdminExternalBlog(`status: ACTIVE`, `registrationType: ADMIN_DIRECT`) + `Location`. 피드 확인·중복·주제 오류는 회원 신청과 같음. 작업 기록 `EXTERNAL_BLOG_CREATE` (FR-111 (2)) |
| GET | /admin/external-blogs/{id} | 관리자 | - | 200 AdminExternalBlog. 없으면 404 `EXTERNAL_BLOG_NOT_FOUND` |
| PATCH | /admin/external-blogs/{id} | 관리자 | `{ defaultTopicId }` | 200 AdminExternalBlog. 작업 기록 `EXTERNAL_BLOG_UPDATE`(전후 주제) |
| POST | /admin/external-blogs/{id}/approve | 관리자 | - | 200 AdminExternalBlog(`ACTIVE`, `next_fetch_at = now`). PENDING만. 신청 회원에게 알림 `EXTERNAL_BLOG_APPROVED`. 작업 기록 `EXTERNAL_BLOG_APPROVE` (FR-111 (1)) |
| POST | /admin/external-blogs/{id}/reject | 관리자 | `{ reason }` (1~500자) | 200 AdminExternalBlog(`REJECTED`). PENDING만. 알림 `EXTERNAL_BLOG_REJECTED`(`{ externalBlogTitle, reason }`). 작업 기록 `EXTERNAL_BLOG_REJECT`(사유) |
| POST | /admin/external-blogs/{id}/pause | 관리자 | `{ reason? }` | 200. ACTIVE만. 수집 멈춤, 글은 그대로. 작업 기록 `EXTERNAL_BLOG_PAUSE` (FR-127) |
| POST | /admin/external-blogs/{id}/resume | 관리자 | - | 200. PAUSED·STOPPED만. 실패 수 초기화, `next_fetch_at = now`. 작업 기록 `EXTERNAL_BLOG_RESUME` |
| POST | /admin/external-blogs/{id}/block | 관리자 | `{ reason }` (1~500자) | 200. BLOCKED가 아니면 모두. 글 전부 `REMOVED`(`BLOG_BLOCKED`), 포털에서 바로 사라짐. 되돌리는 API 없음(1.0). 작업 기록 `EXTERNAL_BLOG_BLOCK` (FR-127) |
| GET | /admin/external-blogs/{id}/posts?status=&page=&size= | 관리자 | - | 200 Page<AdminExternalPost>(발행 최신순, `status` 생략 시 전체) |
| POST | /admin/external-posts/{id}/remove | 관리자 | `{ reason }` (1~500자) | 200 AdminExternalPost(`REMOVED`, `ADMIN`). 되돌리지 않음(되돌릴 수 있게 내리려면 아래 포털 제외). 작업 기록 `EXTERNAL_POST_REMOVE` (FR-127) |
| PUT | /admin/portal/external-exclusions/{externalPostId} | 관리자 | `{ reason }` (1~500자) | 200 ExternalExclusion. 003 `PUT /admin/portal/exclusions/{postId}`와 같은 규칙(멱등, 사유 변경). 작업 기록 `PORTAL_EXCLUDE`(대상 `EXTERNAL_POST`) (FR-123 → 003 FR-093) |
| DELETE | /admin/portal/external-exclusions/{externalPostId} | 관리자 | - | 200 `null`. 제외가 없으면 404 `PORTAL_EXCLUSION_NOT_FOUND`. 작업 기록 `PORTAL_UNEXCLUDE` |
| GET | /admin/classification-reviews?status=&externalBlogId=&page=&size= | 관리자 | - | 200 Page<ClassificationReview>. `status` 기본 `PENDING`(오래된 것 먼저), ACTIVE 글만 (FR-121) |
| POST | /admin/classification-reviews/{id}/confirm | 관리자 | `{ topicId }` | 200 ClassificationReview(`CONFIRMED`). 글 `topic_source = REVIEW`. PENDING이 아니면 409 `CLASSIFICATION_REVIEW_CLOSED`. 작업 기록 `CLASSIFICATION_CONFIRM` (US3 AS3) |
| POST | /admin/classification-reviews/confirm-batch | 관리자 | `{ items: [{ id, topicId }] }` (1~50개) | 200 `{ confirmed: number[], skipped: [{ id, status }] }`(이미 닫힌 것은 건너뜀). 확정한 행마다 작업 기록 |
| GET | /admin/classification-stats | 관리자 | - | 200 ClassificationStats (5분 캐시, `generatedAt`) (FR-122) |
| GET | /admin/topic-mapping-rules?q=&page=&size= | 관리자 | - | 200 Page<TopicMappingRule>(우선순위 큰 것 먼저, 같으면 id) |
| POST | /admin/topic-mapping-rules | 관리자 | `{ keyword, topicId, priority? }` (`keyword` 정규화 후 1~100자, `priority` -1000~1000 기본 0) | 201 TopicMappingRule + `Location`. 중복 409 `TOPIC_MAPPING_RULE_KEYWORD_TAKEN`, 주제 규칙은 003. 작업 기록 `TOPIC_MAPPING_RULE_CREATE` (FR-121) |
| PATCH | /admin/topic-mapping-rules/{id} | 관리자 | `{ keyword?, topicId?, priority? }` | 200. 없으면 404 `NOT_FOUND`. 작업 기록 `TOPIC_MAPPING_RULE_UPDATE`(전후) |
| DELETE | /admin/topic-mapping-rules/{id} | 관리자 | - | 200 `null`. 작업 기록 `TOPIC_MAPPING_RULE_DELETE`. 이미 RULE로 정해진 글은 그대로 |

```ts
type AdminExternalBlog = MyExternalBlog & {
  member: { userId: number; nickname: string; status: "ACTIVE" | "SUSPENDED" | "WITHDRAWN" } | null;
  registrationBasis: string | null;
  reviewedBy: { userId: number; nickname: string } | null;
  reviewedAt: string | null;
  ownershipVerifiedAt: string | null;
  nextFetchAt: string | null;
  lastHttpStatus: number | null;
  consecutiveFailures: number;
  firstFailedAt: string | null;
  pendingReviewCount: number;
};
type AdminExternalPost = MyExternalPost & {
  guid: string | null;
  imageUrl: string | null;          // 원본 주소(관리자 확인용, 화면은 링크로만 표시)
  feedTerms: string[];
  classifierTopicId: number | null;
  classifierConfidence: number | null;
  classifierVersion: string | null;
  excluded: { reason: string; excludedBy: { userId: number; nickname: string }; createdAt: string } | null;
  linkCheckedAt: string | null;
};
type ExternalExclusion = { externalPostId: number; reason: string; excludedBy: { userId: number; nickname: string }; createdAt: string };
type ClassificationReview = {
  id: number;
  status: "PENDING" | "CONFIRMED" | "SKIPPED";
  post: { id: number; title: string; summary: string | null; link: string; feedTerms: string[]; topicId: number; topicSource: string };
  externalBlog: { id: number; title: string | null; defaultTopicId: number };
  predictedTopicId: number | null;
  confidence: number | null;
  confirmedTopicId: number | null;
  reviewedBy: { userId: number; nickname: string } | null;
  reviewedAt: string | null;
  createdAt: string;
};
type ClassificationStats = {
  window: { from: string; to: string };            // 최근 30일
  classifierAccuracy: { sample: number; correct: number; rate: number | null };   // FR-122
  finalAccuracy: { sample: number; unchanged: number; rate: number | null };      // SC-019 근사(research E11)
  distribution: { topicId: number; total: number; bySource: Record<"OWNER"|"REVIEW"|"RULE"|"AUTO"|"DEFAULT", number> }[];
  pendingReviews: number;
  minConfidence: number;                            // 지금 기준값
  classifierVersion: string;
  generatedAt: string;
};
type TopicMappingRule = { id: number; keyword: string; topicId: number; priority: number; createdBy: { userId: number; nickname: string }; createdAt: string; updatedAt: string };
```

## 운영 설정 키 (003 `/admin/settings`에 추가)

| 키 | 값 형식·범위 | 기본값(프로퍼티) | 설명 |
|---|---|---|---|
| external.fetch-interval | ISO-8601 기간 문자열 `PT10M`~`PT24H` | `blog.external.fetch-interval`(`PT30M`) | 수집 주기 (FR-113). 바꾸면 다음 수집부터 |
| external.auto-classify-min-confidence | 숫자 0~1 | `blog.external.auto-classify-min-confidence`(0.7) | 자동 분류 채택 기준 (FR-118, FR-119) |
| external.score-weight | 숫자 0~10 | `blog.external.score-weight`(1.0) | 외부 글 인기 점수 가중치 (FR-124). 포털 캐시 무효화 |

프로퍼티 쪽 수집 주기는 시험을 위해 1초까지 허용하지만, 관리자 화면에서 바꿀 수 있는 범위는 위 표다.

## 신고 연동 (005)

- `POST /reports`의 `targetType`에 `EXTERNAL_POST`·`EXTERNAL_BLOG`가 받아진다(처리기 등록, 005 결정 표 5번). 대상은 포털 노출 중인 외부 글, 거절·해제·차단이 아닌 외부 블로그. 아니면 404 `EXTERNAL_POST_NOT_FOUND`/`EXTERNAL_BLOG_NOT_FOUND`.
- 관리자 신고 처리(`POST /admin/reports/{id}/resolve`)의 조치에 `REMOVE_FROM_PORTAL`(외부 글 `REMOVED`, `REPORT`)과 `BLOCK_EXTERNAL_BLOG`(외부 블로그 차단)가 선택지로 나온다. 미리보기는 제목·요약·블로그 이름·원문 링크·상태.
- 권리 침해 신고 `POST /rights-requests`의 `targetUrl`이 이 서비스의 `/api/v1/external-posts/{id}/visit`이거나 외부 글의 원문 링크(정규화 해시 일치)면 대상이 자동으로 채워진다.

## 알림 (002 `GET /notifications`에 나오는 종류)

| type | target | params | 받는 사람 |
|---|---|---|---|
| EXTERNAL_BLOG_APPROVED | EXTERNAL_BLOG / id | `{ externalBlogTitle }` | 신청 회원 |
| EXTERNAL_BLOG_REJECTED | EXTERNAL_BLOG / id | `{ externalBlogTitle, reason }` | 신청 회원 |
| EXTERNAL_FEED_STOPPED | EXTERNAL_BLOG / id | `{ externalBlogTitle, lastResult }` | 관리 회원(있을 때) |

`externalBlogTitle`이 없으면(피드에 이름이 없음) 피드 주소의 호스트.

## 프로퍼티 (`blog.external.*`, `application.yml`)

| 프로퍼티 | 기본값 | 설명 |
|---|---|---|
| blog.external.fetch-threads | 4 | (001) 수집 풀 크기 |
| blog.external.batch-size | 50 | (001) 한 번에 고르는 피드 수·수집 풀 큐 |
| blog.external.poll-interval | 1m | 수집할 차례인 피드를 고르는 주기(`@Scheduled(fixedDelayString)`) |
| blog.external.fetch-interval | PT30M | 수집 주기 기본값(운영 설정 `external.fetch-interval`이 우선) |
| blog.external.fetch-jitter | PT5M | 다음 수집 시각에 더하는 무작위 지연 상한 |
| blog.external.lease-time | PT10M | 고른 피드를 다시 고르지 않는 시간 |
| blog.external.connect-timeout | 5s | 외부 연결 시간 |
| blog.external.request-timeout | 10s | 요청 하나 전체 시간 |
| blog.external.max-redirects | 3 | 리다이렉트 상한 |
| blog.external.max-feed-size | 2MB | 피드 응답 상한 |
| blog.external.max-page-size | 1MB | 블로그 HTML 상한(피드 찾기·인증 확인) |
| blog.external.max-image-size | 5MB | 대표 이미지 상한 |
| blog.external.initial-window | P30D | 최초 수집 범위 (FR-113) |
| blog.external.max-items-per-fetch | 100 | 한 번에 처리하는 항목 수 |
| blog.external.max-backoff | PT12H | 실패 지연 상한 |
| blog.external.stop-after | P7D | 연속 실패 자동 중지 (FR-117) |
| blog.external.auto-classify-min-confidence | 0.7 | 설정 키 기본값 |
| blog.external.score-weight | 1.0 | 설정 키 기본값 |
| blog.external.member-limit | 3 | 회원당 외부 블로그 수 (FR-112) |
| blog.external.preview-per-hour | 20 | 회원당 미리보기 수 |
| blog.external.verify-checks-per-hour | 10 | 회원당 인증 확인 수 |
| blog.external.verification-ttl | PT24H | 인증 코드 유효 시간 (FR-110) |
| blog.external.click-dedupe-window | PT30M | 같은 방문자 클릭 중복 제거 |
| blog.external.release-retention | P30D | 해제 후 글 보관(삭제 선택 안 함) |
| blog.external.link-check-cron | `0 30 4 * * MON` | 원문 링크 점검 (FR-117) |
| blog.external.link-check-batch | 500 | 한 번에 점검하는 글 수 |
| blog.external.cleanup-cron | `0 30 5 * * *` | 정리 작업 |
| blog.external.forbidden-hosts | blog.java21.net | 외부 블로그로 등록할 수 없는 호스트(하위 도메인 포함). `blog.base-url`의 호스트는 항상 포함 |
| blog.external.user-agent | `java21-blog-feed/1.0 (+{blog.base-url}/updates)` | 외부 요청의 User-Agent |
| blog.outbound.allowed-ports, blog.outbound.allow-private | (005) | 외부 요청 허용 포트, 시험용 내부망 허용(prod에서 true면 기동 실패) |

잘못된 값(0 이하 시간·크기, `fetch-threads` < 1, `member-limit` < 1, `auto-classify-min-confidence`가 0~1 밖)은 기동 실패한다(`ExternalFeedPropertiesTest`).
