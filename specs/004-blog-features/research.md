# Research: 004 블로그 꾸미기와 글 옵션

> 001 research의 R17(예약 발행), R18(보호 글), R19(방문자 수), R20(비회원·비밀 댓글)을 이 문서의 B5·B4·B9·B6으로 옮겨 확정했다(001 research 머리말). 001 문서의 해당 절은 그대로 두며, 내용이 다르면 이 문서가 우선한다.
>
> 001의 결정(R1~R28: 인증, 프록시, SSR 구성, 노출 조각 `PostExposure`, 테스트 방식, 정기 작업, 보안 헤더, 다국어), 002의 결정(D1~D11), 003의 결정(P1~P14)은 그대로 따른다. 모든 API 경로는 `/api/v1` 접두어를 쓴다([contracts/api.md](./contracts/api.md)).

확인일: 2026-10-07 (blog-backend·blog-front main 기준. 003 Phase 5~8은 `feat/003-rest`에서 구현되어 아직 main에 머지되지 않았으며, 그 브랜치의 코드를 함께 읽었다)

## B1. 노출 조각에 PROTECTED·SCHEDULED 넣기 (FR-062, FR-064, SC-004)
- **Decision**:
  - `PostVisibility`에 `PROTECTED`, `PostStatus`에 `SCHEDULED`를 더한다(DB 컬럼은 이미 `VARCHAR(10)`이고 주석에 값이 있다).
  - `PostExposure.LISTABLE_VISIBILITIES`에 `PROTECTED`를 더한다. `listable()`은 `status = PUBLISHED`만 보므로 `SCHEDULED`는 아무것도 바꾸지 않아도 모든 목록·피드·검색·사이트맵·포털에서 빠진다. `bodyVisible()`은 `visibility = PUBLIC`을 이미 요구하므로 보호 글은 사이트맵·포털·관련 글에서 자동으로 빠진다.
  - 002가 미리 둔 보호 글 분기(`PostExposure.isBodyVisibleListed`, `hasListableWithoutBody`)가 검색(`SearchPostRow`, 제목만 검색하는 세 번째 조건)·구독 피드(`FeedPostResponse`)·RSS/Atom(`FeedItemRow`)에서 그대로 동작한다.
  - 아직 분기가 없는 곳: 블로그 글 목록(`PostQueryRepository` → `PostSummaryResponse`)과 서비스·블로그 태그 글 목록(`TagQueryRepository`)은 `summary`·`thumbnailUrl`을 그대로 준다. `PostSummaryResponse.forReader(row)`를 두어 `isBodyVisibleListed(visibility)`가 false면 두 필드를 null로 바꾼다(001 contracts `PostSummary` 규칙). 관리 목록(`ManagePostQueryRepository`)은 주인 화면이므로 가리지 않는다.
  - 관련 글(002 `RelatedPostQueryRepository`)은 `bodyVisible()`을 쓰므로 보호 글이 빠진다. 001 노출 매트릭스의 "블로그 목록" 열(관련 글 포함, 제목만)보다 엄격하지만 관련 글은 본문을 권하는 영역이라 그대로 둔다(결정 표 3번).
  - 노출 매트릭스 행 전체(PROTECTED·SCHEDULED 포함)는 Polish의 통합 테스트 한 곳에서 모든 공개 표면(블로그 홈·카테고리·태그·보관함·공지·사이드바·검색·구독 피드·RSS·Atom·사이트맵·포털·관련 글)에 대해 확인한다.
- **Rationale**: 001이 "PROTECTED를 더하는 스펙이 `LISTABLE_VISIBILITIES`에 값을 넣는다"는 자리를 이미 만들었고 002가 분기를 미리 넣었다. 004는 값을 넣고 빠진 두 곳만 메운다.
- **Alternatives**: 목록마다 `visibility` 분기를 따로 쓰기(규칙이 흩어짐, 원칙 IV 위반).

## B2. CHECK 제약과 H2 (FR-062, FR-066)
- **Decision**: MySQL 스키마의 `ck_posts_protected_password`, `ck_comments_author`, `ck_guestbook_entries_author`를 엔티티에 Hibernate `@Check`(같은 식)로도 적는다. H2 스키마는 엔티티로 만들어지므로 `@DataJpaTest`에서도 같은 제약이 걸린다. MySQL에서는 `ddl-auto=validate`가 CHECK를 보지 않으므로 영향이 없다.
- **Rationale**: 서비스가 지키는 규칙(보호 글이면 비밀번호 해시, 비회원이면 이름·비밀번호)을 H2 테스트에서도 DB가 한 번 더 막는다. MySQL 전용 테스트를 늘리지 않는다(헌법 III).
- **Alternatives**: `@MySqlRepositoryTest`로만 확인(테스트 DB가 없을 때 빠짐).

## B3. 공통 비밀번호 시도 제한 (FR-063, FR-066)
- **Decision**:
  - `PasswordAttemptGuard`(Caffeine, `expireAfterWrite = blog.posts.password-lock-duration` 10분)가 대상(`POST:{id}`, `COMMENT:{id}`, `GUESTBOOK:{id}`)과 두 키(방문자 키 `u:{userId}`·`v:{visitorId}`, 접속 IP)마다 연속 실패 수를 센다. 어느 키든 `blog.posts.password-max-failures`(5)에 닿으면 10분 동안 그 대상의 비밀번호 확인을 429 `PASSWORD_ATTEMPTS_EXCEEDED`(`Retry-After` 초)로 거부한다. 맞으면 두 키의 실패 수를 지운다.
  - 보호 글 열기(B4)와 비회원 댓글·방명록의 수정·삭제·내용 보기(B6·B7)가 같은 도구를 쓴다. 저장하지 않으므로 테이블이 없다(data-model "보호 글").
- **Rationale**: 방문자 쿠키만 세면 쿠키를 지워 우회하고, IP만 세면 같은 사무실이 함께 막힌다. 둘 중 하나라도 넘으면 막는 방식이 단순하고 001 로그인 잠금(`login-max-failures`, `login-lock-duration`)과 같은 숫자를 쓴다.
- **Alternatives**: DB 실패 기록 테이블(스키마 변경, backend 1대 전제라 불필요), CAPTCHA(005 FR-141).

## B4. 보호 글 (FR-062, FR-063) — 001 R18을 옮겨 확정
- **Decision**:
  - 발행 설정(`PublishSettings`)에 `password`(4~64자)를 더한다. `visibility = PROTECTED`이고 지금 보호 글이 아니면 필수(없으면 400 `VALIDATION_FAILED` field `password` `REQUIRED`), 이미 보호 글이면 생략 시 기존 해시를 유지한다. 다른 공개 범위로 바꾸면 `password_hash`를 NULL로 지운다. BCrypt(001 `PasswordEncoder` 빈)로 저장하고 어떤 응답에도 넣지 않는다.
  - 열기: `POST /posts/{id}/unlock` `{ password }`(비로그인 허용, Origin 검사). 목록 노출 가능한 보호 글이 아니면 404 `POST_NOT_FOUND`, 틀리면 400 `POST_PASSWORD_MISMATCH`(B3로 실패 수 셈). 맞으면 200 `PostDetail`(본문 포함)과 함께 열람 쿠키를 준다.
  - 열람 쿠키: 이름 `post_unlock_{postId}`, 값은 001 `JwtProvider`의 키로 서명한 짧은 JWT(`typ = post-unlock`, `pid`, `exp = 30분`, `blog.posts.unlock-ttl`), `HttpOnly; Secure; SameSite=Lax; Path=/; Max-Age=1800`. 새 비밀 키를 두지 않는다. 글의 비밀번호를 바꾸면 이전 쿠키도 막도록 클레임에 해시의 앞 8자 지문(`pwf`)을 넣고 비교한다.
  - 글 상세(`GET /posts/{id}`): 주인이거나 유효한 열람 쿠키가 있으면 본문을 준다. 아니면 `locked: true`와 제목·작성자·블로그·발행 시각·공개 범위만 주고 `contentHtml`·`summary`·`thumbnailUrl`·`tags`·`category`는 null·빈 값이다(001 노출 매트릭스 "제목 + 비밀번호 입력란"). front는 이미 브라우저 쿠키를 그대로 backend로 넘기고 Set-Cookie를 되돌려주므로(`app/api/backendCookies.server.ts`) SSR 첫 요청에서도 본문이 그려진다.
  - 잠긴 보호 글의 댓글 목록·쓰기, 조회수, 끝까지 읽음은 403 `POST_LOCKED`(댓글) 또는 세지 않음(조회수·끝까지 읽음, 200 그대로)이다. 열면 모두 일반 글처럼 동작한다.
  - SSR meta: 보호 글은 제목만, `description`·`og:image` 없음, `noindex`(사이트맵 제외와 맞춤).
- **Rationale**: 001 R18이 서명 쿠키 30분과 Caffeine 실패 카운트를 이미 정했다. JWT 서명기를 다시 쓰면 키 관리가 늘지 않는다.
- **Alternatives**: 세션 테이블에 열람 기록(스키마 변경), 비밀번호를 쿼리 문자열로 보내기(로그·기록에 남음), 쿠키에 HMAC만(서명 코드를 새로 만들어야 함).

## B5. 예약 발행 (FR-064, SC-010) — 001 R17을 옮겨 확정
- **Decision**:
  - 발행 설정에 `scheduledAt`(ISO-8601 UTC, 선택)을 더한다.
    - 값이 `now`보다 미래이면 예약: 글이 DRAFT 또는 SCHEDULED일 때만(PUBLISHED면 422 `SCHEDULE_NOT_ALLOWED`, data-model "이미 발행된 글은 예약 상태로 되돌리지 않는다"), `now + blog.posts.schedule-max-ahead`(365일) 이내(아니면 400 field `scheduledAt` `INVALID` `params.max`). 발행과 같은 변환·검증·태그·주제·이미지 참조 처리를 하되 `Post.schedule(..., scheduledAt)`이 `status = SCHEDULED`, `scheduled_at`을 정하고 `published_at`은 건드리지 않는다. 작성 중 사본은 지운다.
    - 값이 없거나 `now` 이하면 즉시 발행(Edge Cases "과거 시각은 즉시 발행"). SCHEDULED 글을 즉시 발행하면 `scheduled_at`을 지운다.
  - 예약 취소: `POST /posts/{id}/unschedule`(주인) → `status = DRAFT`, `scheduled_at = NULL`(SCHEDULED가 아니면 409 `POST_NOT_SCHEDULED`). 내용은 `posts`에 남고, 001 규칙대로 사본이 없으면 작성 화면이 발행본 내용을 불러온다.
  - 정기 작업 `ScheduledPublishJob`: `@Scheduled(fixedDelayString = "${blog.jobs.scheduled-publish-delay:30s}")`가 `status = SCHEDULED AND scheduled_at <= now`인 글 id를 `scheduled_at` 순으로 `purge-batch-size`(500)개씩 읽고(`idx_posts_status_scheduled`), 글마다 조건부 UPDATE `SET status = PUBLISHED, published_at = COALESCE(published_at, :now), scheduled_at = NULL WHERE id = ? AND status = 'SCHEDULED' AND scheduled_at <= :now` 1회. 1행이 바뀌었을 때만 `blogs.first_published_at`을 NULL일 때 채운다(003 `markFirstPublished`와 같은 규칙을 조건부 UPDATE로). 주기가 30초라 예약 시각부터 최대 약 30초 + 처리 시간 안에 발행된다(SC-010의 1분).
  - `published_at`은 실제 발행 시각(`now`)이다(data-model). 예약 시각을 지난 뒤 서버가 꺼져 있었다면 다시 뜬 뒤 첫 주기에 발행된다.
  - 휴지통: SCHEDULED → DELETED는 001 `moveToTrash`가 `status_before_delete = SCHEDULED`로 남기고, 복구하면 SCHEDULED로 돌아온다(시각이 지났으면 다음 주기에 발행). 관리 글 목록 필터에 `status=SCHEDULED`, 응답 `PostSummary`에 `scheduledAt`.
  - 동시성: 주인의 수정 발행·예약 취소와 작업이 겹쳐도 작업은 조건부 UPDATE라 SCHEDULED가 아닌 글을 바꾸지 않는다. 주인 쪽은 001처럼 엔티티 변경이며, 작업이 먼저 발행했다면 주인의 "예약 취소"는 409를 받는다. 서버 1대 전제(001 R26)라 분산 락은 없다.
- **Rationale**: 001 R17의 30초 주기. 조건부 UPDATE는 잠금 없이 이중 발행을 막는다.
- **Alternatives**: 글마다 `TaskScheduler.schedule`(재기동 때 다시 등록해야 함), 조회 시점에 `scheduled_at <= now`면 발행으로 보기(모든 노출 조각에 시각 조건이 퍼지고 피드 ETag·포털 캐시와 어긋남).

## B6. 비회원 글과 비밀 댓글 (FR-065, FR-066) — 001 R20을 옮겨 확정
- **Decision**:
  - **비회원 쓰기 공통**(`GuestAuthorService`): 로그인하지 않은 요청이 댓글·방명록을 쓰면 블로그의 `guest_write_enabled`가 true일 때만 받는다(아니면 401 `UNAUTHENTICATED`, front는 로그인 안내 — US3 AS6). `guestName` 1~30자(앞뒤 공백 제거, 제어 문자 제거), `guestPassword` 4~64자(BCrypt), 접속 IP(001 `ClientInfo`)를 `guest_ip_enc`에 001 `EncryptedStringConverter`(AES-256-GCM)로 저장한다. 응답의 작성자는 `{ userId: null, nickname: guestName, profileImageUrl: null, guest: true }`.
  - **비회원 쓰기 속도**: IP당 댓글 1분 5개, 방명록 1분 3개(`blog.guest.comment-per-minute`, `blog.guest.guestbook-per-minute`, 005 data-model의 `ratelimit.*` 기본값과 같은 숫자). Caffeine 고정 창, 넘으면 429 `TOO_MANY_REQUESTS` + `Retry-After`. 회원 속도 제한·운영자 설정값·CAPTCHA(005 FR-141·142)는 005가 이 자리(`GuestWriteGuard` 인터페이스)를 바꾼다(결정 표 9번).
  - **비회원 수정·삭제**: `PATCH /comments/{id}`·`DELETE /comments/{id}`(방명록도 같은 모양)의 본문에 `guestPassword`. 비회원 글에 비밀번호가 틀리면 403 `GUEST_PASSWORD_MISMATCH`(B3로 실패 수 셈). 블로그·글 주인은 비밀번호 없이 지울 수 있다(001 FR-028). 회원 글에 비로그인 요청은 401.
  - **비밀 댓글**: `CreateCommentRequest.secret`(기본 false). 내용을 볼 수 있는 사람은 글 주인, 작성 회원, 그리고 답글이면 부모 댓글의 작성 회원이다. 비밀 댓글의 답글과 비밀 부모 아래 답글은 모두 비밀로 다룬다(data-model "비밀글에 단 주인 답글도 같은 사람에게만"을 댓글에도 적용). 볼 수 없는 사람에게는 `content = null`, `secret: true`를 준다. 판단은 `CommentVisibility.canRead(comment, parent, viewerId, postOwnerId)` 한 곳(001 R20 "서비스 계층 한 곳").
  - **비회원 비밀 댓글 보기**: 비회원 작성자는 로그인 신원이 없으므로 `POST /comments/{id}/unlock` `{ guestPassword }`로 그 댓글 하나의 내용을 받는다(쿠키 없음, 수정 화면용, B3 적용). 방명록도 `POST /guestbook-entries/{id}/unlock`.
  - **알림**: 비회원 댓글도 002 `NEW_COMMENT`를 만든다(`actor_user_id` NULL, `params_json`에 `guestName`, 002 research D3). `CommentCreatedEvent.authorId`를 nullable로 바꾼다.
  - **목록 쿼리**: 댓글·방명록 목록은 작성자를 LEFT JOIN으로 읽는다(비회원 행 포함, 쿼리 수 그대로).
  - **IP 파기**: 001 `PrivacyPurgeJob`에 단계를 더해 `created_at < now - blog.guest.ip-retention(90일)`이고 `guest_ip_enc`가 있는 댓글·방명록의 IP를 NULL로 지운다. 후보는 `user_id IS NULL` 행만 보므로 기존 `idx_comments_user`·`idx_guestbook_entries_user`를 쓴다(새 인덱스 불필요).
- **Rationale**: 댓글과 방명록이 같은 규칙(이름·비밀번호·IP·속도)을 쓰므로 한 서비스에 모은다. 비밀 판단을 한 메서드로 두어 목록·관리·사이드바가 같은 결과를 낸다.
- **Alternatives**: 비회원 비밀 댓글은 아무도(작성자 포함) 못 보게(스펙 "작성자만"과 다름), 비회원 열람 쿠키(대상이 많아 쿠키가 늘어남).

## B7. 방명록 (FR-056~058, FR-066)
- **Decision**:
  - API: `GET /blogs/{handle}/guestbook?page=&size=`(최상위 글 최신순 페이지, 각 글의 `replies`), `POST /blogs/{handle}/guestbook`(회원 또는 비회원, `parentId`가 있으면 블로그 주인의 답글만 — 아니면 403 `FORBIDDEN`), `PATCH`·`DELETE /guestbook-entries/{id}`, `POST /guestbook-entries/{id}/unlock`. 내용 1~1000자 일반 텍스트(001 댓글과 같은 정규화, 출력 시 이스케이프).
  - 목록은 쿼리 2회: 최상위 글 페이지(작성자 LEFT JOIN, `idx_guestbook_entries_blog_status_created`)와 그 글들의 답글(`parent_id IN (...)`, `idx_guestbook_entries_parent`). `totalCount`는 표시되는 최상위 글 수.
  - 비밀글: 블로그 주인과 작성 회원만 내용. 비밀글의 답글도 같은 사람에게만(B6과 같은 `canRead`).
  - 삭제: 작성자(회원 또는 비밀번호) 또는 블로그 주인. 답글이 있는 글은 `status = DELETED`로 자리만 남기고("삭제된 글입니다"), 없으면 행 삭제. 마지막 답글이 지워지면 자리만 남은 부모도 지운다(001 댓글과 같음).
  - 방명록 끄기(`guestbook_enabled = false`): 주인이 아닌 사람의 목록·쓰기는 404 `GUESTBOOK_DISABLED`, front는 메뉴를 숨긴다(AS4). 주인은 관리 화면에서 계속 보고 답글·삭제할 수 있다. 행은 지우지 않는다.
  - 차단된 회원(B13)은 쓸 수 없다(403 `FORBIDDEN`, 차단 사실을 드러내지 않는 일반 거부).
  - 새 방명록 글 알림은 만들지 않는다(002 FR-033 알림 종류에 없음). 대신 블로그 관리 대시보드에 최근 7일 새 방명록 수와 최근 5건(006 FR-100).
  - 블로그 관리 "방명록"(`/:handle/manage/guestbook`)은 같은 목록 API를 쓴다(주인은 모든 내용을 봄). 별도 관리 API를 두지 않는다.
- **Rationale**: 001 댓글과 같은 모양이라 front 컴포넌트와 backend 규칙을 재사용한다.
- **Alternatives**: 답글을 `POST /guestbook-entries/{id}/replies`로(경로가 늘고 댓글과 달라짐), 관리 전용 목록 API(지금 필요한 필터가 없음).

## B8. 공지 (FR-059)
- **Decision**:
  - 발행 설정에 `notice`(null이면 지금 값 유지, 새 글은 false). 블로그 관리 글 목록 일괄 작업에 `NOTICE`·`UNNOTICE`를 더한다(001 `BulkAction`). "꾸미기" 화면이 지금 공지 목록과 "공지 해제"를 보여준다.
  - 읽기: `GET /blogs/{handle}/notices?page=&size=`(`listable()` + `notice = true`, 발행 최신순, `idx_posts_blog_notice_published`). 블로그 홈은 `size=5`로 목록 위에 따로 보이고, 공지 목록 화면 `/:handle/notice`가 전체를 보여준다.
  - 일반 목록에서 빼기: 블로그 홈 목록(`GET /blogs/{handle}/posts`에 카테고리·태그·보관함 조건이 없을 때)만 `notice = false`를 더한다. 카테고리·태그·보관함·검색·피드·사이트맵·포털에는 공지도 일반 글로 나온다(spec AS1의 "일반 목록"을 블로그 홈 목록으로 읽음, 결정 표 6번).
  - 공지 여부와 관계없이 노출 매트릭스를 따른다(비공개 공지는 주인 관리 화면에만, 보호 공지는 제목만).
- **Rationale**: 공지는 글의 속성 하나라 발행 설정에 둔다. 컬럼과 인덱스가 이미 있다.
- **Alternatives**: 공지를 별도 테이블로(스키마 변경), 모든 목록에서 공지 빼기(카테고리에서 글을 찾을 수 없게 됨).

## B9. 방문자 수 (FR-067) — 001 R19를 옮겨 확정
- **Decision**:
  - `POST /blogs/{handle}/visits`(비로그인 허용, Origin 검사). front의 공개 블로그 레이아웃 loader(B11)가 SSR 때 부른다. 방문자 키는 001 조회수와 같은 코드(회원 `u:{id}`, 아니면 방문자 쿠키 `v:{uuid}`, 없으면 발급)를 공용 `VisitorKeyResolver`로 옮겨 쓴다.
  - 세지 않는 경우: 블로그 주인 본인, User-Agent가 비었거나 `blog.stats.bot-user-agent-pattern`(기본 `(?i)(bot|crawler|spider|slurp|facebookexternalhit|preview)`)에 맞는 요청. Playwright의 `HeadlessChrome`은 맞지 않는다.
  - 중복 제거: Caffeine 키 `(blogId, 방문자 키, 날짜)`, `expireAfterWrite = 25h`, 최대 `blog.stats.visit-dedup-max-size`(200,000). 날짜는 `blog.stats.time-zone`(기본 `Asia/Seoul`, data-model)의 오늘.
  - 기록: 처음 오는 방문만 한 트랜잭션에서 네이티브 `INSERT INTO blog_daily_visits (blog_id, visit_date, visitors) VALUES (?, ?, 1) ON DUPLICATE KEY UPDATE visitors = visitors + 1`과 `UPDATE blogs SET total_visitors = total_visitors + 1 WHERE id = ?`(003 `post_daily_stats` upsert와 같은 방식, H2 MySQL 모드 지원). 동시 upsert는 `@MySqlRepositoryTest`로 확인.
  - 읽기: 사이드바 VISITORS(B10)와 대시보드는 `{ today, yesterday, total }`(행 2개 + `blogs.total_visitors`), 통계 화면은 `GET /blogs/{handle}/manage/stats?days=30`이 최근 30일(오늘 포함, 행이 없는 날은 0으로 채움)과 조회수 상위 글 10편(006 spec 통계 메뉴)을 준다.
  - 보관: `blog_daily_visits`는 지우지 않는다(블로그 × 방문이 있던 날만 행이 생기고 행이 작다). 통계 화면은 30일만 쓴다. 정리가 필요해지면 `visit_date` 인덱스 제안과 함께 다시 정한다(결정 표 15번, data-model "보관 기간은 004 plan에서 정한다").
- **Rationale**: 001 R19. 블로그 주소가 같은 날짜 기준이 블로그마다 달라지지 않도록 서비스 시간대 하나를 쓴다.
- **Alternatives**: front가 브라우저에서 비콘으로 기록(JS 없는 방문을 놓침), 방문자 키를 DB에 저장(개인정보 증가, 스키마 변경), 90일 정리 작업(PK가 `(blog_id, visit_date)`라 날짜 조건 삭제가 전체 스캔이 되고 인덱스가 필요).

## B10. 사이드바 (FR-060, FR-061)
- **Decision**:
  - 설정: `GET /blogs/{handle}/manage/sidebar`(주인, 10개 항목 모두 `{ type, enabled }` 순서대로), `PUT /blogs/{handle}/sidebar` `{ items: [{ type, enabled }] }`(주인, 10개를 빠짐·중복 없이 모두 — 아니면 400 field `items` `INVALID`, 배열 순서가 `sort_order`). 저장은 블로그의 행을 모두 지우고 다시 넣는다(data-model "전체 교체"). 행이 없으면 기본 구성(PROFILE, CATEGORIES, RECENT_POSTS, TAGS, ARCHIVE, SEARCH, FEED_LINKS 켜짐 → RECENT_COMMENTS, POPULAR_POSTS, VISITORS 꺼짐).
  - 읽기: `GET /blogs/{handle}/sidebar`(모두)가 켜진 항목의 순서와 데이터 항목의 내용을 한 번에 준다. 켜진 항목만 계산한다.
    - RECENT_POSTS: `listable()` 최신 5편(제목·id·발행 시각, 보호 글도 제목만이라 그대로).
    - POPULAR_POSTS: `listable()` 중 `view_count` 내림차순(같으면 최신) 5편.
    - RECENT_COMMENTS: 이 블로그의 `bodyVisible()` 글에 달린 ACTIVE 댓글 중 비밀이 아닌 것 최신 5개(내용 앞 50자, 작성자 이름, 글 id). 보호 글·비밀 댓글은 넣지 않는다.
    - TAGS: 001 블로그 태그 목록(`TagQueryRepository`, 목록 노출 가능 글 수) 상위 30개.
    - ARCHIVE: B12의 월별 글 수.
    - VISITORS: B9의 `{ today, yesterday, total }`.
    - PROFILE·CATEGORIES·SEARCH·FEED_LINKS: 데이터가 없고 front가 이미 받은 `GET /blogs/{handle}`(주인 프로필, 카테고리 트리, 피드 주소)로 그린다.
  - 쿼리 수: 설정 1 + 켜진 데이터 항목마다 1(최대 7). 서버 캐시는 두지 않는다(비공개 전환이 다음 요청에 바로 반영되어야 SC-004를 지킴, 002 research D5와 같은 판단).
- **Rationale**: 공개 블로그 화면마다 사이드바를 그리므로 loader 호출 한 번으로 끝낸다.
- **Alternatives**: 항목별 API(loader 호출 증가), 사이드바 결과 캐시(비공개 전환 지연).

## B11. 공개 블로그 레이아웃과 새 화면 (원칙 V·VII)
- **Decision**:
  - front `routes.ts`에서 공개 블로그 화면(`:handle`, `:handle/category/:categoryId`, `:handle/tags`, `:handle/tags/:name`, `:handle/notice`, `:handle/archive/:year/:month`, `:handle/search`, `:handle/guestbook`, `:handle/:postId`)을 경로 없는 레이아웃 `layout("routes/blog/layout.tsx", [...])`로 감싼다. 레이아웃 loader는 `GET /blogs/{handle}/sidebar`와 `POST /blogs/{handle}/visits`(실패 무시)를 병렬로 부르고, 사이드바와 블로그 메뉴(홈·공지·방명록(켜졌을 때)·태그)를 그린다. 자식 화면은 지금처럼 자기 loader에서 `GET /blogs/{handle}`을 부른다(레이아웃 데이터를 바꾸지 않아 기존 테스트가 그대로 산다). `shouldRevalidate`는 `handle`이 바뀔 때만 다시 부른다.
  - `:handle/write/**`, `:handle/manage/**`는 레이아웃 밖이다(방문 기록 없음).
  - 새 화면: 공지 목록, 월별 보관함, 블로그 내 검색, 블로그 태그 목록(글 수가 많을수록 큰 글자, 5단계 로그 눈금 `app/blog/tagWeight.ts`), 방명록. 관리: 방명록, 꾸미기(사이드바 순서·켜기, 공지 목록), 통계, 백업, 차단 목록. 001 contracts/routes.md가 이 경로들을 이미 예약했다.
  - 번역 namespace: `blog`(사이드바·보관함·공지·블로그 검색·태그 목록), `guestbook`(방명록). 관리 화면은 `manage`, 발행 설정의 보호·예약·공지는 `post`, 비밀·비회원 댓글은 `comment`, 백업 알림 문구는 `notification`, 오류는 `errors`.
- **Rationale**: 사이드바를 화면마다 따로 부르면 9개 loader를 고쳐야 한다. 경로 없는 레이아웃은 주소를 바꾸지 않는다.
- **Alternatives**: `:handle` 경로 레이아웃(글쓰기·관리 화면까지 묶여 방문 기록·사이드바가 붙음), 클라이언트에서 사이드바 읽기(SSR 원칙 V 위반).

## B12. 월별 보관함과 블로그 내 검색 (FR-061)
- **Decision**:
  - 보관함 목록: `GET /blogs/{handle}/archive` → `[{ year, month, postCount }]`(최근 달부터). 이 블로그의 `listable()` 글의 `published_at`만 한 번 읽어 자바에서 `blog.stats.time-zone`의 연·월로 묶는다(인덱스 `idx_posts_blog_status_visibility_published`로 범위 읽기). 블로그 글이 수천 편이어도 시각 하나씩이라 가볍다.
  - 그 달의 글: 기존 `GET /blogs/{handle}/posts`에 `year`·`month`(둘 다 있어야 함, 아니면 400)를 더한다. 자바가 그 달의 시작·끝을 UTC 시각으로 바꿔 `published_at >= start AND < end`로 거른다. 화면 `/:handle/archive/:year/:month`.
  - 블로그 내 검색: 002 `GET /search/posts`에 `blog={handle}` 조건을 더한다(블로그가 볼 수 없으면 404 `BLOG_NOT_FOUND`). 002 검색어 규칙·보호 글 제목만 규칙을 그대로 쓰고 MySQL FULLTEXT라 테스트는 `@MySqlRepositoryTest`.
  - 태그 목록: 001 `GET /blogs/{handle}/tags`를 그대로 쓴다(이름순, `postCount`). 강조 정도는 front가 계산한다.
- **Rationale**: 날짜 함수·시간대 변환 SQL은 MySQL과 H2가 달라(`CONVERT_TZ`는 시간대 테이블 필요) 자바에서 묶는 편이 테스트와 운영이 같다.
- **Alternatives**: `DATE_FORMAT(CONVERT_TZ(...))` GROUP BY(MySQL 전용·시간대 테이블 의존), 월별 집계 테이블(스키마 변경).

## B13. 블로그 차단 (FR-146)
- **Decision**:
  - API(주인): `GET /blogs/{handle}/blocks?page=`(차단 최신순, 회원 닉네임·프로필 이미지), `PUT /blogs/{handle}/blocks/{userId}`(멱등 생성, 200), `DELETE /blogs/{handle}/blocks/{userId}`(없으면 404 `BLOCK_NOT_FOUND`). 자기 자신은 422 `CANNOT_BLOCK_SELF`, 없는 회원은 404 `USER_NOT_FOUND`.
  - 차단을 만들 때 같은 트랜잭션에서 002 `blog_subscriptions` 행을 지우고 `blogs.subscriber_count`를 줄인다(002 data-model). 이미 쓴 댓글·방명록은 그대로 둔다(주인이 따로 지울 수 있음).
  - 확인 지점(`BlogBlockPolicy.isBlocked(blogId, userId)`, PK 조회 1회): 댓글 쓰기(그 글의 블로그), 방명록 쓰기, 구독(`PUT /me/subscriptions/{handle}`). 모두 403 `FORBIDDEN`(차단을 알리지 않는 일반 거부). 좋아요·읽기는 막지 않는다(스펙 범위 밖).
  - 회원을 고르는 곳: 블로그 관리의 댓글·방명록 목록에서 회원 작성자 옆 "차단"(응답의 `author.userId`). 비회원은 차단 대상이 아니다(data-model).
  - `PUT`으로 만드는 것은 003 포털 제외와 같은 설계 규칙 예외(블로그 × 회원이 곧 식별자, 멱등)이며 contracts/api.md에 이유를 적는다.
- **Rationale**: 차단 행의 PK가 `(blog_id, blocked_user_id)`라 경로가 곧 자원이다.

## B14. 블로그 백업 (FR-145)
- **Decision**:
  - API(주인): `POST /blogs/{handle}/exports` → 202 `BlogExport`(PENDING). 같은 블로그에 최근 24시간(`blog.export.min-interval`) 안에 만든 FAILED가 아닌 행이 있으면 409 `EXPORT_LIMIT_EXCEEDED`(`idx_blog_exports_blog_created`). `GET /blogs/{handle}/exports`(최근 10건), `GET /blogs/{handle}/exports/{id}/file`(READY이고 만료 전이면 `application/zip` 스트림, 아니면 404 `EXPORT_NOT_FOUND`).
  - 처리: `BlogExportJob`이 `fixedDelayString = ${blog.jobs.export-poll-delay:30s}`마다 가장 오래된 PENDING 하나를 조건부 UPDATE로 RUNNING으로 바꾸고 만든다(한 번에 하나, 별도 스레드 풀 없음). 기동 때 `blog.export.stale-running`(1시간)보다 오래된 RUNNING은 FAILED(`INTERRUPTED`)로 바꾼다. 실패하면 FAILED + `error_code`(`IO_ERROR` 등)이며 하루 제한에 세지 않는다.
  - zip 구성(`BlogExportWriter`, `java.util.zip.ZipOutputStream`, 새 의존성 없음):
    - `blog.json`: 블로그 제목·소개·주소, 카테고리 트리, 만든 시각, 형식 버전 1.
    - `posts/{id}.md`: 휴지통(DELETED)을 뺀 모든 글(DRAFT·SCHEDULED·PUBLISHED, 모든 공개 범위). 맨 위 YAML front matter(`title`, `category`(경로 "상위/하위"), `tags`, `visibility`, `status`, `publishedAt`, `scheduledAt`, `notice`, `topic`(slug)) + Markdown 원문(`posts.content_md`, 발행 전 글은 작성 중 사본). 발행된 글에 작성 중 사본이 있으면 `posts/{id}.draft.md`도 넣는다. 보호 글의 비밀번호는 넣지 않는다.
    - `images/{mediaKey}.{ext}`: 그 글들의 `post_media`가 가리키는 원본 이미지(썸네일 제외). 본문의 `/media/{key}` 주소는 원문 그대로 두고 `media.json`(`/media/{key}` → `images/...`)을 넣는다.
    - 글은 id 순 100편씩(`posts` + 태그 IN + 사본 IN, 묶음마다 쿼리 3회) 읽어 메모리를 일정하게 둔다.
  - 파일: `blog.export.dir`(prod 필수, local 기본 `./data/exports`) 아래 `{yyyy}/{MM}/{무작위 UUID}.zip`. `file_path`는 응답에 넣지 않는다. 내려받을 때 이름은 `{handle}-backup-{yyyyMMdd}.zip`, `Cache-Control: no-store`.
  - 완료: READY, `completed_at = now`, `expires_at = now + blog.export.retention(7일)`, 002 알림 `BACKUP_READY`(target `BLOG_EXPORT`, params `{ blogTitle, expiresAt, handle }`)를 요청한 주인에게.
  - 정리: `BlogExportCleanupJob`(`blog.jobs.export-cleanup-cron` 기본 매시 10분)이 `status = READY AND expires_at < now`(`idx_blog_exports_status_expires`)의 파일을 지우고 EXPIRED로 바꾼다. 블로그 영구 정리(001 `TrashPurgeRepository.purgeBlogs`)는 그 블로그의 백업 파일과 행을 지운다(data-model).
- **Rationale**: 백업은 드물고 오래 걸릴 수 있어 요청 스레드에서 만들지 않는다. 정기 작업 폴링은 재기동에도 끊긴 작업이 남지 않아 `@Async` + 이벤트보다 단순하다.
- **Alternatives**: `@Async` 실행(재기동 때 PENDING이 남음), 요청 중 동기 생성(긴 요청·타임아웃), 미디어 주소를 상대 경로로 바꾸기(스펙의 "Markdown 원문"과 다름).

## B15. 블로그 설정 확장 (FR-058, FR-066)
- **Decision**: `PATCH /blogs/{handle}`에 `guestbookEnabled`, `guestWriteEnabled`(둘 다 null 불가, 400 `REQUIRED`), `GET /blogs/{handle}`에 두 값을 더한다. 블로그 관리 "블로그 설정" 화면에 "방명록 사용", "비회원 댓글·방명록 허용"(006 spec 블로그 설정 메뉴).
- **Rationale**: 001 Merge Patch 클래스(`UpdateBlogRequest`)에 002·003이 필드를 더한 방식과 같다.

## B16. 블로그 영구 정리와 대시보드 (001 FR-159, 006 FR-100)
- **Decision**:
  - 001 `TrashPurgeRepository.purgeBlogs`에 004 행 정리를 더한다: 방명록(답글 → 글), 사이드바, 일별 방문, 차단, 백업(파일 삭제 후 행). 모두 `blog_id IN (...)` 일괄 삭제로 블로그 수와 무관한 쿼리 수.
  - 001 대시보드(`GET /blogs/{handle}/manage/dashboard`)에 `visitors: { today, yesterday, total }`, `newGuestbook7d`, `recentGuestbook`(최근 5건)을 더한다. front는 001 T-대시보드가 숨겨 둔 방문자 영역을 보인다.
- **Rationale**: 001 data-model이 "002~005가 더하는 블로그별 데이터도 지운다"를 정했다. 외래 키에 CASCADE가 없어 지우지 않으면 행이 남는다.

## B17. 테스트 전략 (원칙 III)
- **Decision**:
  - Repository: `@JpaRepositoryTest`(H2)로 엔티티 매핑과 `@Check`, 노출 조각의 PROTECTED·SCHEDULED, 방명록 목록(쿼리 2회), 사이드바 항목별 쿼리, 보관함 시각 읽기, 공지 목록·홈 목록의 공지 제외, 예약 대상 조회·조건부 UPDATE, 방문 upsert, 차단, 백업 조회, 블로그 정리. 쿼리 수는 001 `QueryCounter.assertQueryCount`.
  - MySQL 전용(`@MySqlRepositoryTest`): 블로그 내 검색(FULLTEXT), 방문 동시 upsert(20회 동시 → 1행·20).
  - Service: Mockito 단위(비밀번호 시도 제한, 열람 쿠키 서명·만료·지문, 예약 시각 경계, 비밀 판단, 비회원 검증·속도, 사이드바 기본 구성·검증, 월 경계(시간대), 봇 판정, 백업 하루 제한·zip 구성, 차단 시 구독 해제). 시각은 `support/MutableClock`, Caffeine은 테스트 `Ticker`.
  - Controller: `@WebMvcTest` + `WebMvcTestSupport`로 상태 코드·공통 틀·401/403/404/409/422/429·`Retry-After`·`Set-Cookie`·zip 응답 헤더.
  - 통합(`@SpringBootTest`, H2): 노출 매트릭스 PROTECTED·SCHEDULED 행을 공개 표면 전체에서(SC-004), 예약 작업 실행 후 목록·피드 등장.
  - front: Vitest + Testing Library(새 라우트 loader·action·meta, 사이드바 항목 렌더링, 태그 강조 단계, 예약 시각의 시간대 변환, 잠긴 글 화면, 비밀·비회원 댓글), Playwright E2E는 스토리마다 Independent Test를 실제 backend로(`requireBackend()`). 비회원 속도 제한이 E2E 끼리 겹치지 않도록 E2E용 backend는 `BLOG_GUEST_COMMENT_PER_MINUTE=1000`, `BLOG_GUEST_GUESTBOOK_PER_MINUTE=1000`으로 띄우고 해당 시나리오는 `E2E_GUEST_TEST_SETTINGS=1`일 때만 돈다(`requireGuestTestSettings()`). 예약·백업은 기본 주기(30초)에서 최대 90초 기다린다.
- **Rationale**: 001~003과 같은 구성. Testcontainers는 쓰지 않는다.
