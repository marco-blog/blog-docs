# API Contract: 006 관리 화면

006이 더하는 관리자 API만 적는다. 기준 경로·인증·Origin 검사·공통 응답 틀·오류 형식·페이지 규칙은 [001 contracts/api.md](../../001-blog-core/contracts/api.md)(관리자 API 공통 규칙과 릴리스 노트 관리 API 9개 포함), 003이 구현한 관리자 API(주제·포털·설정·블로그 한도·릴리스 노트)는 [003 contracts/api.md](../../003-portal/contracts/api.md), 005 관리자 API(회원·신고·콘텐츠 숨김·금칙어)는 [005 contracts/api.md](../../005-trackback-moderation/contracts/api.md), 설계 규칙은 [REST API 설계 규칙](../../../api-guidelines.md)을 따른다.

- 모든 API 경로는 `/api/v1`로 시작한다(아래 표의 경로는 이 접두어를 뺀 것).
- 표의 "응답"은 공통 틀 `{ header, result, totalCount? }`의 `result`에 들어가는 내용이다. "Page<X>"는 `result`가 X 배열, `totalCount`가 전체 개수이며 `page`는 0부터, `size`는 기본 20·최대 50이다.
- 권한: "관리자"는 ADMIN·SUPER_ADMIN(003 `AdminAccessFilter`: 요청마다 DB의 현재 권한·상태 확인, 아니면 비로그인 포함 404 `NOT_FOUND`, FR-097). "최고 관리자"는 그중 SUPER_ADMIN만이며, ADMIN이 부르면 서비스가 DB의 현재 권한을 다시 확인해 403 `FORBIDDEN`(관리자에게는 콘솔이 이미 드러나 있으므로 404가 아님, 005 정지 규칙과 같음).
- 모든 응답에 `Cache-Control: no-store`.
- 상태를 바꾸는 요청은 `Origin` 검사를 받는다(001 R27). 관리자의 모든 변경은 같은 트랜잭션에서 작업 기록(FR-106, 003 `AdminAuditService`)에 남는다(SC-017, 매핑 행렬 테스트가 강제 — research A8).
- 이 문서가 기준이며, 구현 후 springdoc OpenAPI와 일치해야 한다(`OpenApiContractTest`).
- **001~005 API의 요청·응답 변경은 없다.**

## 오류 코드 (006에서 추가)

001~005 표의 코드는 그대로 쓴다(`NOT_FOUND`, `FORBIDDEN`, `VALIDATION_FAILED`, `USER_NOT_FOUND`(004) 등).

| HTTP | resultCode | 상황 | 비고 |
|---|---|---|---|
| 409 | LAST_SUPER_ADMIN | 마지막(ACTIVE) 최고 관리자의 권한을 낮춤 (FR-105) | **005와 공유**(005는 마지막 최고 관리자 정지). 먼저 머지하는 스펙이 추가 |
| 409 | USER_NOT_ACTIVE | 정지·탈퇴 회원에게 관리자 권한 부여 | **005와 공유**(005는 탈퇴 회원 정지) |
| 422 | CANNOT_CHANGE_OWN_ROLE | 최고 관리자가 자기 권한을 바꿈(다른 최고 관리자가 바꿔야 함) | 006 |

필드 오류(`fieldErrors[].code`)는 001 값(`REQUIRED`, `INVALID`, `INVALID_FORMAT`, `TOO_LONG`)만 쓴다. 콘텐츠 검색에서 범위 없이 키워드만 주면 field `q` `INVALID` + `params: { reason: "SCOPE_REQUIRED" }`, 작업 기록 기간이 366일을 넘으면 field `to` `INVALID` + `params: { maxDays: 366 }`.

## 설계 규칙과 다르게 만든 것

| 항목 | 규칙 | 006 | 이유 |
|---|---|---|---|
| `PUT /admin/users/{id}/role` | 일부 수정은 PATCH | PUT(권한 값 하나를 통째로 교체, 멱등) | 자원 "회원의 권한"을 하나의 값으로 보고 교체한다. 같은 값이면 변화·기록 없이 200 |
| `GET /admin/contents/comments`, `/guestbook-entries`의 `q` | 검색 조건은 자유롭게 조합 | 범위(글·작성자·블로그) 없이 `q`만 주면 400 | 댓글·방명록 본문에는 전문 검색 인덱스가 없어 서비스 전체 `LIKE '%q%'`가 큰 테이블 전체 훑기가 된다(research A4) |

## 대시보드 (admin/dashboard) — FR-103

| 메서드 | 경로 | 권한 | 요청 | 응답 |
|---|---|---|---|---|
| GET | /admin/dashboard | 관리자 | - | 200 AdminDashboard |

```ts
type AdminDashboard = {
  today: { signups: number; publishedPosts: number; comments: number };   // 관리자 시간대의 오늘 0시~지금
  totals: { members: number; blogs: number; publicPosts: number };        // ACTIVE 회원, ACTIVE 블로그, PUBLISHED·PUBLIC 글
  pendingReports: number | null;     // 005 전에는 null(화면에서 카드 숨김). 캐시하지 않음
  trend: { date: string; signups: number; publishedPosts: number }[];     // 오늘 포함 7일, 오래된 날 먼저, 빈 날 0, date는 YYYY-MM-DD(관리자 시간대)
  timeZone: string;                  // 계산에 쓴 IANA 시간대(요청한 관리자의 users.time_zone)
  generatedAt: string;               // 캐시된 값을 계산한 시각(UTC). 최대 blog.admin.dashboard-cache-ttl(5분) 전
};
```

- 가입자 = `users.created_at`이 그 날(탈퇴 포함). 발행 글 = `posts.published_at`(최초 발행 시각)이 그 날(공개 범위·지금 상태 무관). 댓글 = `comments.created_at`이 그 날(비회원 포함, 지금 상태 무관).
- 캐시 키는 시간대. TTL 0이면 매번 계산(E2E).

## 콘텐츠 관리 검색 (admin/content) — FR-102, FR-104

숨김·해제는 005 `PUT·DELETE /admin/contents/{posts|comments|guestbook-entries|trackbacks}/{id}/hidden`을 쓴다(006은 검색만 더함).

| 메서드 | 경로 | 권한 | 요청(쿼리) | 응답 |
|---|---|---|---|---|
| GET | /admin/contents/posts | 관리자 | `q`(제목 전문 검색, 2~100자, 002 검색어 규칙), `handle`(블로그 정확 일치), `authorId`, `status`(DRAFT·PUBLISHED·SCHEDULED·DELETED·HIDDEN, 생략하면 전체), `visibility`, `page`, `size` | 200 Page<AdminPostRow>. 조건이 없으면 최신 생성순, `q`가 있으면 관련도 대신 최신 생성순(관리자는 시간 순서로 본다) |
| GET | /admin/contents/comments | 관리자 | `postId`, `authorId`, `handle`, `status`(ACTIVE·DELETED·HIDDEN), `q`(내용 부분 일치 2~100자, **`postId`·`authorId`·`handle` 중 하나 이상 필요**), `page`, `size` | 200 Page<AdminCommentRow>, 최신순 |
| GET | /admin/contents/guestbook-entries | 관리자 | `handle`, `authorId`, `status`, `q`(범위 규칙 같음), `page`, `size` | 200 Page<AdminGuestbookRow>, 최신순 |

```ts
type AdminRef = { userId: number; nickname: string; status: "ACTIVE" | "SUSPENDED" | "WITHDRAWN" };
type AdminPostRow = {
  id: number; title: string;
  blog: { handle: string; title: string; status: "ACTIVE" | "DELETED" };
  author: AdminRef;
  status: PostStatus; visibility: PostVisibility;
  publishedAt: string | null; createdAt: string; deletedAt: string | null; commentCount: number;
};  // 본문·요약·대표 이미지·비밀번호 해시 없음(FR-104)
type AdminCommentRow = {
  id: number; postId: number; postTitle: string; blogHandle: string; parentId: number | null;
  author: AdminRef | null; guestName: string | null;       // 비회원이면 author null, IP 없음
  secret: boolean; content: string | null;                 // 앞 200자. 비밀 댓글은 null
  status: "ACTIVE" | "DELETED" | "HIDDEN"; createdAt: string;
};
type AdminGuestbookRow = Omit<AdminCommentRow, "postId" | "postTitle">;   // + blogHandle
```

- 탈퇴 회원의 닉네임은 001 규칙대로 "탈퇴한 회원" 표시용 값이 그대로 온다.
- 쿼리 2회(목록 + 개수, 블로그·작성자·글 JOIN). 글 제목 검색만 MySQL FULLTEXT(`ft_posts_title`).

## 예약어·서비스 설정 (admin/info) — FR-102, FR-160

| 메서드 | 경로 | 권한 | 요청 | 응답 |
|---|---|---|---|---|
| GET | /admin/reserved-handles | 관리자 | - | 200 `string[]`(가나다·알파벳 정렬, backend `ReservedHandles.NAMES`) |
| GET | /admin/service-settings | 관리자 | - | 200 ServiceSettings |

```ts
type ServiceSettings = {
  termsVersion: string;                                   // blog.legal.terms-version
  blogs: { defaultMaxPerMember: number };                 // blog.blogs.default-max-per-member
  media: { maxFileSize: number; maxPixels: number; tempQuota: number;   // 바이트·픽셀 수
           tempTtl: string; allowedTypes: string[] };     // ISO-8601 기간, MIME
  admin: { auditRetention: string; dashboardCacheTtl: string };
};
```

- 읽기 전용. 비밀 값(암호화 키, JWT, 메일·CAPTCHA 비밀 키)은 넣지 않는다.

## 작업 기록 (admin/audit) — FR-106

| 메서드 | 경로 | 권한 | 요청(쿼리) | 응답 |
|---|---|---|---|---|
| GET | /admin/audit-logs | 관리자 | `from`, `to`(YYYY-MM-DD, 관리자 시간대, 생략하면 최근 7일, 최대 366일), `adminId`, `action`(쉼표로 여러 개), `targetType`, `targetId`, `targetKey`, `page`, `size` | 200 Page<AuditLogEntry>, 새 것 먼저 |
| GET | /admin/audit-logs/{id} | 관리자 | - | 200 AuditLogEntry + `requestIp: string \| null`(최고 관리자에게만 복호화 값, 일반 관리자는 null). 없으면 404 `NOT_FOUND` |
| GET | /admin/audit-logs/actions | 관리자 | - | 200 `{ actions: string[], targetTypes: string[] }`(backend `AuditActions.ALL`·`TARGETS`) |

```ts
type AuditLogEntry = {
  id: number; admin: { userId: number; nickname: string };
  action: string; targetType: string; targetId: number | null; targetKey: string | null;
  before: Record<string, unknown> | null; after: Record<string, unknown> | null;   // 바뀐 필드만, 개인정보 평문 없음
  reason: string | null; createdAt: string;
};
```

- 수정·삭제 API는 없다(FR-106). 1년(`blog.admin.audit-retention`)이 지난 행은 정리 작업만 지운다.

## 관리자 권한 (admin/user) — FR-105

| 메서드 | 경로 | 권한 | 요청 | 응답 |
|---|---|---|---|---|
| GET | /admin/admins | 관리자 | - | 200 `AdminMember[]`(ADMIN·SUPER_ADMIN 전원, 정지 포함, 권한 높은 순 → 닉네임순) |
| PUT | /admin/users/{id}/role | **최고 관리자** | `{ role: "USER" \| "ADMIN" \| "SUPER_ADMIN" }` | 200 AdminMember. 403 `FORBIDDEN`(요청자가 SUPER_ADMIN 아님), 404 `USER_NOT_FOUND`, 422 `CANNOT_CHANGE_OWN_ROLE`, 409 `USER_NOT_ACTIVE`(정지·탈퇴 회원에게 ADMIN 이상을 줌), 409 `LAST_SUPER_ADMIN`, 400 field `role` `REQUIRED`·`INVALID` |

```ts
type AdminMember = { userId: number; nickname: string; role: "USER" | "ADMIN" | "SUPER_ADMIN";
  status: "ACTIVE" | "SUSPENDED" | "WITHDRAWN"; createdAt: string };
```

- 반영: 다음 관리자 API 요청부터(003 `AdminAccessFilter`가 DB를 읽음). front 상단 "시스템 관리" 표시도 다음 화면 요청부터(`/me`).
- 작업 기록: 높아지면 `ROLE_GRANT`, 낮아지면 `ROLE_REVOKE`(target `USER`/id, before/after `{ role }`). 같은 값이면 기록 없음.
- 마지막 최고 관리자 확인: 트랜잭션 안에서 `SELECT id FROM users WHERE role = 'SUPER_ADMIN' AND status = 'ACTIVE' FOR UPDATE`(006 data-model).

## 작업 기록 `action` (006에서 코드로 만드는 것)

006 data-model 표가 기준이다. `AuditActions`에 지금 없는 값 중 006이 더하는 것: `USER_BLOG_LIMIT_CHANGE`(001 `AdminUserService`의 문자열 상수를 옮김), `ROLE_GRANT`, `ROLE_REVOKE`, 대상 종류 `USER`(005와 공유). 005·007 값은 그 스펙이 더한다.

## 프로퍼티 (006에서 추가, `application.yml` 기본값)

| 키 | 기본값 | 설명 |
|---|---|---|
| blog.admin.dashboard-cache-ttl | 5m | 콘솔 대시보드 캐시(FR-103 최대 지연). 0이면 끔(E2E `BLOG_ADMIN_DASHBOARD_CACHE_TTL=0s`) |
| blog.admin.audit-retention | 365d | 작업 기록 보관 기간(FR-106). 30일 미만이면 기동 실패 |
| blog.jobs.audit-purge-cron | `0 15 5 * * *` | 작업 기록 정리 주기(매일 05:15) |

`blog.admin.bootstrap-super-admin-email`(001·003)은 그대로. E2E용 값은 [quickstart.md](../quickstart.md) "준비"와 tasks.md 결정 표 25번.
