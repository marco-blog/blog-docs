# API Contract: 005 트랙백과 운영

005가 더하는 엔드포인트와 001~004 응답·요청의 확장만 적는다. 기준 경로·인증·Origin 검사·공통 응답 틀·오류 형식·페이지 규칙은 [001 contracts/api.md](../../001-blog-core/contracts/api.md), 관리자 API 공통 규칙은 [003 contracts/api.md](../../003-portal/contracts/api.md), 004 확장은 [004 contracts/api.md](../../004-blog-features/contracts/api.md), 설계 규칙은 [REST API 설계 규칙](../../../api-guidelines.md)을 따른다.

- 모든 API 경로는 `/api/v1`로 시작한다(아래 표의 경로는 이 접두어를 뺀 것). **예외**: 트랙백 받기 `POST /{handle}/{postId}/trackback`(TrackBack 1.2, 아래 "트랙백 받기").
- 표의 "응답"은 공통 틀 `{ header, result, totalCount? }`의 `result`에 들어가는 내용이다. "Page<X>"는 `result`가 X 배열, `totalCount`가 전체 개수이며 `page`는 0부터, `size`는 기본 20·최대 50이다.
- "본문 없는 성공"은 200 + `result: null`이다(204를 쓰지 않음).
- 권한: "모두"는 비로그인 포함, "회원"은 로그인 회원, "주인"은 그 블로그(글이면 글이 속한 블로그)의 주인(001 `BlogAccess`), "관리자"는 ADMIN·SUPER_ADMIN(003 `AdminAccessFilter`: 요청마다 DB의 현재 권한·상태 확인, 아니면 비로그인 포함 404 `NOT_FOUND`, 006 FR-097). 로그인이 필요한 응답·주인·관리자 응답에는 `Cache-Control: no-store`.
- 상태를 바꾸는 요청은 비로그인이어도 `Origin` 검사를 받는다(001 R27). 트랙백 받기만 제외(001 R3, `OriginCheckFilter.EXEMPT_PATHS`에 이미 있음).
- 관리자의 모든 변경은 작업 기록(006 FR-106, 003 `AdminAuditService`)에 남는다. 요청 IP는 암호문으로.
- 이 문서가 기준이며, 구현 후 springdoc OpenAPI와 일치해야 한다(트랙백 XML 경로는 OpenAPI에서 제외하고 이 문서만 기준).

## 오류 코드 (005에서 추가)

001~004 표의 코드는 그대로 쓴다(`NOT_FOUND`, `POST_NOT_FOUND`, `BLOG_NOT_FOUND`, `COMMENT_NOT_FOUND`, `GUESTBOOK_ENTRY_NOT_FOUND`, `USER_NOT_FOUND`(004), `VALIDATION_FAILED`, `FORBIDDEN`, `TOO_MANY_REQUESTS`, `UNAUTHENTICATED`, `INVALID_CREDENTIALS` 등).

| HTTP | resultCode | 상황 |
|---|---|---|
| 404 | REPORT_TARGET_NOT_FOUND | 신고 대상이 없거나 신고자가 볼 수 없음(비공개·숨김·삭제·볼 수 없는 비밀 글) (FR-040) |
| 422 | CANNOT_REPORT_OWN_CONTENT | 자기 글·댓글·방명록 글, 자기 글이 받은 트랙백(→ 삭제 기능을 씀) 신고 |
| 409 | REPORT_ALREADY_EXISTS | 같은 대상을 이미 신고함(처리 여부와 무관) |
| 404 | REPORT_NOT_FOUND | 관리자: 없는 신고 |
| 409 | REPORT_ALREADY_RESOLVED | 관리자: 이미 처리·기각된 신고를 다시 처리 |
| 409 | REPORT_ALREADY_TARGETED | 관리자: 대상이 이미 정해진 신고의 대상 지정 |
| 422 | REPORT_TARGET_REQUIRED | 관리자: 대상이 없는 권리 침해 신고에 조치(ACTION) — 먼저 대상을 지정 |
| 422 | REPORT_ACTION_NOT_ALLOWED | 관리자: 대상에 맞지 않는 조치(작성 회원이 없는 대상의 `SUSPEND_USER`, 1.0에서 처리기가 없는 조치) |
| 404 | CONTENT_NOT_FOUND | 관리자: 숨김·해제할 대상이 없거나 삭제됨 |
| 409 | POST_HIDDEN | 주인: 관리자가 숨긴 글의 발행·발행 설정 변경 (FR-041) |
| 404 | BLOG_RESTRICTED | 주인이 정지된 블로그의 `GET /blogs/{handle}` — front는 "이용이 제한된 블로그" 안내 (FR-042) |
| 409 | USER_NOT_ACTIVE | 관리자: 탈퇴 회원 정지 |
| 422 | CANNOT_SUSPEND_SELF | 관리자: 자기 자신 정지 |
| 409 | LAST_SUPER_ADMIN | 관리자: 마지막 최고 관리자 정지 |
| 400 | CAPTCHA_FAILED | CAPTCHA 토큰이 없거나 검증 실패 (FR-141) |
| 400 | CAPTCHA_REQUIRED | 로그인 반복 실패 뒤 CAPTCHA 없이 로그인 (FR-141) |
| 422 | DUPLICATE_CONTENT_SPAM | 짧은 시간 같은 내용 댓글·방명록 반복 (FR-144) |
| 409 | BANNED_WORD_EXISTS | 관리자: 이미 있는 금칙어 |
| 404 | BANNED_WORD_NOT_FOUND | 관리자: 없는 금칙어 |
| 404 | TRACKBACK_NOT_FOUND | 없는 트랙백, 삭제·숨김된 트랙백 삭제 |
| 422 | TRACKBACK_NOT_ALLOWED | 공개(PUBLIC)가 아닌 글에서 트랙백 보내기 (FR-052) |

새 `fieldErrors[].code`: **`BANNED_WORD`** — 이름류(닉네임·블로그 주소·블로그 제목·비회원 이름)나 본문류(댓글·방명록 내용)에 거부 금칙어가 있음(FR-143). 어느 단어인지는 `params`에 넣지 않는다. 그 밖의 형식 오류는 `INVALID`, 필수 누락은 `REQUIRED`, 길이는 `TOO_LONG`·`TOO_SHORT`.

429 `TOO_MANY_REQUESTS`(001 코드)는 작성 속도 제한(FR-142), 트랙백 외 신고 남용 제한에도 쓰고 `Retry-After`(초)를 준다.

## 설계 규칙과 다르게 만든 것

| 항목 | 규칙 | 005 | 이유 |
|---|---|---|---|
| `POST /{handle}/{postId}/trackback` | `/api/v1`, JSON 공통 틀, 실제 HTTP 상태 | `/api/v1` 밖, `text/xml` TrackBack 1.2 응답, 성공·실패 모두 HTTP 200 | 외부 블로그 서비스가 보내는 표준 프로토콜이다(spec Assumptions). 규격은 HTTP 상태가 아니라 `<error>` 값으로 판단한다. 경로는 001 routes.md에서 정함 |
| `PUT /admin/contents/{targetType}/{id}/hidden` | 생성은 POST + 201 | PUT 멱등, 200 | "숨김 상태"를 자원으로 본다(003 포털 제외·004 차단과 같은 판단). 두 번 눌러도 결과가 같다 |
| `POST /admin/reports/{id}/resolve` | 자원 단위 변경은 PATCH | POST 동작 | 그 신고 하나가 아니라 같은 대상의 대기 신고 전체를 닫고 조치를 실행하는 동작이다(003 릴리스 노트 publish와 같은 판단) |
| `POST /rights-requests` | 생성은 201 + `Location` | 202, 결과 없음 | 비회원은 접수한 신고를 조회할 수단이 없다. 처리 결과는 메일로 안내(FR-040) |
| `POST /admin/users/{id}/suspend`, `/unsuspend` | 상태 변경은 PATCH | POST 동작 | 토큰 폐기·정지 목록 등록·작업 기록이 따르는 동작이다. 사유를 본문으로 받는다 |

## 001~004 요청·응답 확장

필드 추가만 한다(설계 규칙 9절, v1 안에서 허용).

| API | 추가 | 내용 |
|---|---|---|
| GET /blogs/{handle} | 오류 404 `BLOG_RESTRICTED` | 블로그는 ACTIVE인데 주인이 SUSPENDED. 탈퇴·삭제·없는 블로그는 그대로 `BLOG_NOT_FOUND`. 블로그 하위 API(글 목록·상세·방명록 등)는 바뀌지 않음 |
| GET /blogs/{handle} | `trackbackEnabled: boolean` | 트랙백 받기(FR-053, 기본 true) |
| PATCH /blogs/{handle} (요청) | `trackbackEnabled?` | 주인만, null 불가(400 `REQUIRED`). 블로그 제목(`title`)에 금칙어면 400 field `title` `BANNED_WORD` |
| POST /blogs (블로그 만들기), POST /auth/signup | 이름류 금칙어 검사, 가입은 `captchaToken` 필수와 IP 속도 | 가입 요청 `{ ..., captchaToken }`. 닉네임·블로그 주소 금칙어 400 field `BANNED_WORD`. 가입 IP 한도 초과 429 |
| PATCH /me (요청) | 닉네임 금칙어 검사 | 400 field `nickname` `BANNED_WORD` |
| POST /auth/login (요청) | `captchaToken?` | 같은 이메일 또는 같은 IP가 연속 3회 실패한 뒤에는 필수(없으면 400 `CAPTCHA_REQUIRED`, 틀리면 400 `CAPTCHA_FAILED`). 성공하면 초기화 |
| POST /posts/{id}/comments, POST /blogs/{handle}/guestbook (요청) | 비회원은 `captchaToken` 필수 | 004 비회원 쓰기에 CAPTCHA(FR-141). 회원·비회원 모두 속도 제한(429), 금칙어(400 `BANNED_WORD` 또는 가림 저장), 반복 내용(422 `DUPLICATE_CONTENT_SPAM`). 비회원 이름도 이름류 금칙어 |
| PATCH /comments/{id}, PATCH /guestbook-entries/{id} | 금칙어 | 내용 수정에도 같은 금칙어 규칙(속도·반복은 세지 않음) |
| POST /media (이미지 업로드) | 속도 제한 | 회원 1분 30개(`ratelimit.media-upload-per-minute`), 넘으면 429 |
| PublishSettings (POST /posts/{id}/publish 요청) | `trackbackUrls?: string[]` | 아래 "트랙백 보내기". 처음 발행(DRAFT·SCHEDULED → PUBLISHED, DRAFT → SCHEDULED)은 회원 1시간 10편 한도(`ratelimit.post-publish-per-hour`, 모든 블로그 합계, 429). 숨긴 글이면 409 `POST_HIDDEN` |
| GET /posts/{id} (PostDetail) | `hidden: boolean`, `trackbackUrl: string \| null`, `trackbackCount: number` | `hidden`은 주인에게만 true일 수 있음(다른 사람에게는 404). `trackbackUrl`은 본문 노출 가능 + 블로그 `trackbackEnabled`일 때만 |
| GET /blogs/{handle}/manage/posts (쿼리) | `status=HIDDEN` | 관리자가 숨긴 글. 응답 `PostSummary.status = "HIDDEN"` |
| POST /blogs/{handle}/manage/posts/bulk | 숨긴 글 | 공개 범위 변경·공지(004)는 숨긴 글을 건너뛰고 건너뛴 수에 셈. 휴지통 이동은 허용 |
| Comment, GuestbookEntry (목록·쓰기 응답) | `hidden: boolean` | 작성 회원에게는 내용과 `hidden: true`. 다른 사람에게는 보이는 답글이 있을 때만 `{ hidden: true, content: null, author: null }` 자리, 없으면 목록에서 빠짐 |
| Notification `type` | `REPORT_RESOLVED` | target `REPORT` / 신고 id, `params: { targetType, decision: "ACTIONED" \| "DISMISSED" }`(대상 제목·내용 없음), 링크 없음 |

## 신고 (report) — FR-040

| 메서드 | 경로 | 권한 | 요청 | 응답 |
|---|---|---|---|---|
| POST | /reports | 회원 | `{ targetType, targetId, reason, detail? }` | 201 `{ id, status: "PENDING" }` + `Location: /api/v1/reports/{id}`(조회 API는 없음, 식별용). 404 `REPORT_TARGET_NOT_FOUND`, 422 `CANNOT_REPORT_OWN_CONTENT`, 409 `REPORT_ALREADY_EXISTS`, 429 |
| POST | /rights-requests | 모두 | `{ targetUrl, reason, rightsBasis, contactEmail, captchaToken }` | 202, `result: null`. 400 `CAPTCHA_FAILED`, 429(IP당 1시간 5건) |

- `targetType`: `POST` / `COMMENT` / `GUESTBOOK` / `TRACKBACK`. `EXTERNAL_POST`·`EXTERNAL_BLOG`(007)은 처리기가 등록되기 전까지 400 `VALIDATION_FAILED` field `targetType` `INVALID`(`params.allowed`에 지금 받는 값).
- `reason`: `SPAM` / `ABUSE` / `ADULT` / `ILLEGAL` / `PRIVACY` / `COPYRIGHT` / `DEFAMATION` / `OTHER`. `detail` 1000자 이하, `OTHER`면 필수.
- 권리 침해: `reason`은 `COPYRIGHT` / `PRIVACY` / `DEFAMATION` / `OTHER`, `targetUrl` http/https 1000자 이하, `rightsBasis` 1~2000자, `contactEmail` 001 이메일 형식 254자 이하. 로그인 상태로 보내도 비회원 신고로 저장한다(`reporter_id` NULL).
- 신고자 신원은 대상 작성자·블로그 주인에게 어떤 응답에도 나오지 않는다.

## CAPTCHA — FR-141

| 메서드 | 경로 | 권한 | 요청 | 응답 |
|---|---|---|---|---|
| GET | /captcha/config | 모두 | - | 200 `{ provider: "turnstile" \| "test" \| "none", siteKey: string \| null }`, `Cache-Control: public, max-age=3600` |

- 토큰은 각 요청 본문의 `captchaToken`(form이면 같은 이름)으로 보낸다. backend가 검증하며 결과를 저장하지 않는다.

## 관리자: 신고 (admin/report) — FR-041

| 메서드 | 경로 | 권한 | 요청 | 응답 |
|---|---|---|---|---|
| GET | /admin/reports?status=&targetType=&channel=&page= | 관리자 | `status` 기본 `PENDING` | 200 Page<ReportGroup> |
| GET | /admin/reports/summary | 관리자 | - | 200 `{ pendingCount }` (콘솔 메뉴 배지) |
| GET | /admin/reports/{id} | 관리자 | - | 200 ReportDetail |
| PATCH | /admin/reports/{id}/target | 관리자 | `{ targetType, targetId }` | 200 ReportDetail. 409 `REPORT_ALREADY_TARGETED`, 404 `CONTENT_NOT_FOUND` |
| POST | /admin/reports/{id}/resolve | 관리자 | `{ decision: "ACTION" \| "DISMISS", action?: "HIDE_CONTENT" \| "SUSPEND_USER", note?, suspendReason? }` | 200 `{ resolvedCount, decision, action }`. 409 `REPORT_ALREADY_RESOLVED`, 422 `REPORT_TARGET_REQUIRED`·`REPORT_ACTION_NOT_ALLOWED` |

```ts
type ReportGroup = {
  representativeId: number;          // 묶음에서 가장 먼저 접수된 신고 id (상세 주소)
  targetType: ReportTargetType | null; // 대상 미정 권리 침해 신고는 null(한 줄에 한 건)
  targetId: number | null;
  channel: "MEMBER" | "RIGHTS_REQUEST" | "MIXED";
  reportCount: number;
  reasons: { reason: ReportReason; count: number }[];
  firstReportedAt: string; lastReportedAt: string;
  status: "PENDING" | "ACTIONED" | "DISMISSED";
  action: ReportAction | null;
  target: ReportTargetPreview | null;
};
type ReportTargetPreview = {
  type: ReportTargetType; id: number;
  state: "ACTIVE" | "HIDDEN" | "DELETED" | "MISSING";
  title: string | null;              // 글 제목, 트랙백 제목
  text: string | null;               // 글 요약(PUBLIC만), 댓글·방명록 내용(비밀 포함), 트랙백 요약
  url: string | null;                // 서비스 안 주소(글·댓글·방명록 앵커), 트랙백은 보낸 주소
  author: { userId: number | null; nickname: string | null; guest: boolean } | null;
  blog: { handle: string; title: string } | null;
};
type ReportDetail = {
  id: number; channel: "MEMBER" | "RIGHTS_REQUEST";
  status: "PENDING" | "ACTIONED" | "DISMISSED"; action: ReportAction | null;
  resolutionNote: string | null; handledBy: { id: number; nickname: string } | null; handledAt: string | null;
  targetUrl: string | null; rightsBasis: string | null;
  contactEmail: string | null;       // 권리 침해만, 파기 후 null
  target: ReportTargetPreview | null;
  reports: { id: number; channel: string; reporter: { id: number; nickname: string } | null;
             reason: ReportReason; detail: string | null; createdAt: string }[]; // 같은 대상의 모든 신고(최신순 100건)
  targetUserReportCount: number | null; // 대상 작성 회원이 받은 신고 수(006 FR-104)
};
```

- 처리는 대상의 모든 `PENDING` 신고를 같은 결과로 닫는다. `HIDE_CONTENT`는 대상 숨김(아래 "콘텐츠 숨김"과 같은 동작), `SUSPEND_USER`는 대상 작성 회원 정지(`suspendReason` 필수, "회원 정지"와 같은 규칙). 회원 신고자마다 `REPORT_RESOLVED` 알림, 권리 침해 신고자에게 메일(ko·en).
- 작업 기록: `REPORT_ACTION`·`REPORT_DISMISS`(target `REPORT` / 대표 id, after에 닫은 신고 id 목록·조치), 조치 자체의 `CONTENT_HIDE`·`USER_SUSPEND`.

## 관리자: 콘텐츠 숨김 (admin/content) — FR-041

| 메서드 | 경로 | 권한 | 요청 | 응답 |
|---|---|---|---|---|
| PUT | /admin/contents/{targetType}/{id}/hidden | 관리자 | `{ reason }`(1~500자) | 200 ReportTargetPreview(`state: "HIDDEN"`). 404 `CONTENT_NOT_FOUND`(없음·삭제) |
| DELETE | /admin/contents/{targetType}/{id}/hidden | 관리자 | `{ reason? }` | 200 ReportTargetPreview(되돌린 상태). 숨김이 아니면 그대로 200 |
| GET | /admin/contents/hidden-posts?page= | 관리자 | - | 200 Page<ReportTargetPreview>(숨긴 글, 숨긴 순서 최신) |

- `targetType`: `posts` / `comments` / `guestbook-entries` / `trackbacks`(경로 조각, 복수 명사).
- 글: `status_before_hidden`에 직전 상태를 두고 `HIDDEN`, 해제 시 되돌림. 댓글·방명록·트랙백: `ACTIVE ↔ HIDDEN`. 댓글 숨김은 글의 `comment_count`를 1 줄이고 해제는 1 늘린다.
- 작업 기록 `CONTENT_HIDE`·`CONTENT_UNHIDE`(target_type `POST`·`COMMENT`·`GUESTBOOK`·`TRACKBACK`, before·after `{ status }`, reason).

## 관리자: 회원 (admin/user) — FR-042, 006 FR-104

| 메서드 | 경로 | 권한 | 요청 | 응답 |
|---|---|---|---|---|
| GET | /admin/users?q=&by=&page= | 관리자 | `by`: `email`(정확 일치) / `nickname`(앞부분 일치, 기본) / `handle`(정확 일치) | 200 Page<AdminUserSummary>. `q` 2자 미만이면 400 `VALIDATION_FAILED` |
| GET | /admin/users/{id} | 관리자 | - | 200 AdminUserDetail. 404 `USER_NOT_FOUND` |
| POST | /admin/users/{id}/suspend | 관리자 | `{ reason }`(1~500자) | 200 AdminUserDetail. 422 `CANNOT_SUSPEND_SELF`, 409 `USER_NOT_ACTIVE`·`LAST_SUPER_ADMIN`, 403 `FORBIDDEN`(ADMIN이 관리자를 정지) |
| POST | /admin/users/{id}/unsuspend | 관리자 | `{ reason? }` | 200 AdminUserDetail. 정지가 아니면 그대로 200 |
| PATCH | /admin/users/{id}/blog-limit | 관리자 | (003 그대로) | (003 그대로) |

```ts
type AdminUserSummary = { id: number; nickname: string; status: "ACTIVE" | "SUSPENDED" | "WITHDRAWN";
  role: "USER" | "ADMIN" | "SUPER_ADMIN"; createdAt: string; blogCount: number };
type AdminUserDetail = AdminUserSummary & {
  postCount: number;                 // 휴지통 제외, 모든 블로그
  receivedReportCount: number;       // reports.target_user_id
  lastLoginAt: string | null;
  blogs: { handle: string; title: string; status: "ACTIVE" | "DELETED" }[];
  blogLimit: { current: number; limit: number; custom: boolean };   // 003 응답과 같은 값
};
```

- 이메일 원문·비밀번호·비공개 글 본문은 주지 않는다(006 FR-104).
- 정지: `status = SUSPENDED`, 모든 갱신 토큰 폐기, 정지 목록 등록(이미 발급된 접근 토큰도 다음 요청부터 401). 해제: `ACTIVE`, 목록에서 뺌. 작업 기록 `USER_SUSPEND`·`USER_UNSUSPEND`(reason).

## 관리자: 스팸 방어 (admin/spam) — FR-142~144

| 메서드 | 경로 | 권한 | 요청 | 응답 |
|---|---|---|---|---|
| GET | /admin/banned-words?q=&page= | 관리자 | - | 200 Page<BannedWord>(단어순) |
| POST | /admin/banned-words | 관리자 | `{ word, scope, action }` | 201 BannedWord + `Location`. 409 `BANNED_WORD_EXISTS`, 400(NAME + MASK) |
| PATCH | /admin/banned-words/{id} | 관리자 | `{ scope?, action? }` | 200 BannedWord. 404 `BANNED_WORD_NOT_FOUND` |
| DELETE | /admin/banned-words/{id} | 관리자 | - | 200 `result: null`. 404 |
| GET·PUT·DELETE | /admin/settings, /admin/settings/{key} | 관리자 | (003 그대로) | 아래 새 키 |

```ts
type BannedWord = { id: number; word: string; scope: "NAME" | "CONTENT" | "ALL"; action: "REJECT" | "MASK";
  createdBy: { id: number; nickname: string }; createdAt: string; updatedAt: string };
```

새 운영 설정 키(003 `SettingKey`, 행이 없으면 프로퍼티 기본값):

| key | 값 형식 | 기본값(프로퍼티) | 단위 |
|---|---|---|---|
| ratelimit.post-publish-per-hour | 정수 1~10000 | 10 (`blog.ratelimit.post-publish-per-hour`) | 회원, 모든 블로그 합계, 처음 발행·예약만 |
| ratelimit.comment-per-minute | 정수 1~10000 | 5 | 회원 ID 또는 비회원 IP |
| ratelimit.guestbook-per-minute | 정수 1~10000 | 3 | 회원 ID 또는 비회원 IP |
| ratelimit.media-upload-per-minute | 정수 1~10000 | 30 | 회원 |
| ratelimit.signup-per-ip-per-hour | 정수 1~100000 | 5 | IP |
| spam.duplicate-comment | `{ windowMinutes: 1~1440, maxCount: 2~100 }` | `{ 10, 3 }` (`blog.spam.duplicate-comment.*`) | 회원 ID 또는 비회원 IP별 같은 내용 |

작업 기록 `BANNED_WORD_CREATE`·`UPDATE`·`DELETE`(target `BANNED_WORD`), 설정은 003 `SETTING_CHANGE`.

## 트랙백 받기 — FR-050, FR-054, FR-055

`POST /{handle}/{postId}/trackback` (front가 프록시, `/api/v1` 밖, Origin 검사 제외, 비로그인)

요청 `Content-Type: application/x-www-form-urlencoded[; charset=...]`

| 필드 | 필수 | 규칙 |
|---|---|---|
| url | 예 | http/https, 1000자 이하. 정규화한 값의 SHA-256으로 같은 글 중복 확인 |
| title | 아니오 | 태그 제거 일반 텍스트 255자에서 자름. 없으면 `url` |
| excerpt | 아니오 | 태그 제거 일반 텍스트 255자에서 자름 |
| blog_name | 아니오 | 태그 제거 일반 텍스트 255자에서 자름 |

응답(항상 HTTP 200, `Content-Type: text/xml; charset=utf-8`):

```xml
<?xml version="1.0" encoding="utf-8"?>
<response><error>0</error></response>
```

```xml
<?xml version="1.0" encoding="utf-8"?>
<response><error>1</error><message>Trackback is not allowed</message></response>
```

| 상황 | message |
|---|---|
| 글이 없음·handle 불일치·본문 노출 가능이 아님(비공개·보호·임시·예약·삭제·숨김·정지 회원), 블로그 트랙백 꺼짐 | `Trackback is not allowed` |
| `url` 없음 | `Missing url` |
| `url` 형식·길이 오류 | `Invalid url` |
| 같은 글에 같은 주소가 이미 있음(삭제·숨김 포함) | `Duplicate trackback` |
| 같은 출처 IP 10분 10회 초과 | `Too many pings` |

GET 등 다른 메서드는 405(본문 없음). 실패는 저장하지 않는다.

## 트랙백 (trackback) — FR-049, FR-051~053

| 메서드 | 경로 | 권한 | 요청 | 응답 |
|---|---|---|---|---|
| GET | /posts/{id}/trackbacks?page= | 모두 | - | 200 Page<Trackback>(ACTIVE, 최신순). 글 상세를 볼 수 없으면 404 `POST_NOT_FOUND` |
| DELETE | /trackbacks/{id} | 주인(받은 글의 블로그) | - | 200 `result: null`. 404 `TRACKBACK_NOT_FOUND`(없음·삭제·숨김), 403 |
| GET | /blogs/{handle}/manage/trackbacks?page= | 주인 | - | 200 Page<ManagedTrackback>(ACTIVE·HIDDEN, 최신순) |
| GET | /posts/{id}/trackback-pings | 주인 | - | 200 `TrackbackPing[]`(최신 50개) |

```ts
type Trackback = { id: number; title: string; excerpt: string | null; blogName: string | null;
  url: string; receivedAt: string; internal: boolean };          // internal: 서비스 안 글이 보낸 것
type ManagedTrackback = Trackback & { hidden: boolean; post: { id: number; title: string } };
type TrackbackPing = { id: number; targetUrl: string; status: "PENDING" | "SUCCESS" | "FAILED";
  errorCode: "INVALID_URL" | "BLOCKED_ADDRESS" | "TIMEOUT" | "HTTP_ERROR" | "REMOTE_ERROR" | null;
  errorMessage: string | null; attemptedAt: string | null; createdAt: string };
```

- 서비스 안 글이 보낸 트랙백은 보낸 글이 본문 노출 가능일 때만 목록에 나온다(001 노출 매트릭스).
- 트랙백 받기를 꺼도 이미 받은 트랙백은 목록에 남는다(삭제는 주인이 하나씩).
- 화면은 모든 트랙백 값을 텍스트로만 출력한다.

## 트랙백 보내기 — FR-052

- `PublishSettings.trackbackUrls`: 최대 10개, 각 1000자 이하, http/https, 중복은 하나로. 형식 오류는 400 field `trackbackUrls[i]` `INVALID`, 11개 이상은 `trackbackUrls` `TOO_LONG`(`params.max: 10`). 공개 범위가 PUBLIC이 아니면 422 `TRACKBACK_NOT_ALLOWED`.
- 주소마다 PENDING 기록을 만들고, 즉시 발행·발행된 글 수정이면 커밋 직후, 예약 발행이면 실제 발행 때 보낸다. 예약 취소·휴지통 이동 때 보내지 않은 PENDING 기록은 지운다.
- 서비스 안 주소(`{base-url}/{handle}/{postId}`, `/trackback` 포함)는 HTTP 없이 같은 받기 규칙으로 처리한다. 밖 주소는 내부망·루프백·링크로컬로 해석되면 `BLOCKED_ADDRESS`, 리다이렉트는 따르지 않고 연결·응답 각 5초.
- 보내는 값: `url`(글 주소), `title`(글 제목), `excerpt`(글 요약 255자), `blog_name`(블로그 제목), `Content-Type: application/x-www-form-urlencoded; charset=utf-8`, `User-Agent: blog.java21.net-trackback/1.0`.

## 프로퍼티 (005에서 추가, `application.yml` 기본값)

| 키 | 기본값 | 설명 |
|---|---|---|
| blog.ratelimit.post-publish-per-hour | 10 | `ratelimit.post-publish-per-hour` 기본값 |
| blog.ratelimit.comment-per-minute | 5 | 같음(004 `blog.guest.comment-per-minute`를 대체) |
| blog.ratelimit.guestbook-per-minute | 3 | 같음(004 `blog.guest.guestbook-per-minute`를 대체) |
| blog.ratelimit.media-upload-per-minute | 30 | 같음 |
| blog.ratelimit.signup-per-ip-per-hour | 5 | 같음 |
| blog.spam.duplicate-comment.window-minutes | 10 | `spam.duplicate-comment` 기본값 |
| blog.spam.duplicate-comment.max-count | 3 | 같음 |
| blog.spam.duplicate-comment.min-length | 10 | 이보다 짧은 내용은 세지 않음 |
| blog.captcha.provider | `none`(local), `turnstile`(prod) | `turnstile` / `test` / `none`. prod에서 `test`·`none`이면 기동 실패 |
| blog.captcha.site-key, blog.captcha.secret-key | (prod 필수, 환경 변수 `BLOG_CAPTCHA_SITE_KEY`·`BLOG_CAPTCHA_SECRET_KEY`) | Turnstile 키. secret은 커밋 금지 |
| blog.captcha.test-token | `e2e-pass` | `test` provider가 통과시키는 토큰 |
| blog.captcha.verify-timeout | 3s | Turnstile 검증 시간 제한 |
| blog.captcha.login-failures-before-captcha | 3 | 로그인 CAPTCHA가 필요해지는 연속 실패 수 |
| blog.reports.member-per-hour | 30 | 회원 신고 한도 |
| blog.reports.rights-request-per-ip-per-hour | 5 | 권리 침해 신고 IP 한도 |
| blog.reports.penalty-window | 90d | 포털 감점에 넣는 처리 신고 기간 |
| blog.privacy.rights-request-retention | 365d | 처리 후 연락 이메일 보관 기간 |
| blog.privacy.trackback-ip-retention | 90d | 트랙백 송신 IP 보관 기간 |
| blog.trackback.receive-limit | 10 | 같은 출처 IP 수신 한도 |
| blog.trackback.receive-window | 10m | 수신 한도 창 |
| blog.trackback.connect-timeout, blog.trackback.read-timeout | 5s, 5s | 보내기 시간 제한 |
| blog.trackback.max-targets | 10 | 한 번에 보낼 주소 수 |
| blog.trackback.executor-threads, blog.trackback.executor-queue | 2, 100 | 보내기 스레드 풀 |
| blog.trackback.recover-pending-after | 5m | 기동 때 이보다 오래된 PENDING을 다시 보냄 |
| blog.outbound.allowed-ports | 80,443,8080,8443 | 서버가 나가는 요청을 허용하는 포트 |
| blog.outbound.allow-private | false | 시험용. prod에서 true면 기동 실패 |

E2E용 값은 [quickstart.md](../quickstart.md) "준비"와 tasks.md 결정 표 29번.
