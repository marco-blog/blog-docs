# Research: 005 트랙백과 운영

> 001 research의 R16(트랙백)과 R3의 트랙백 예외를 이 문서의 M12~M16으로 옮겨 확정했다(001 research 머리말). 001 문서의 해당 절은 그대로 두며, 내용이 다르면 이 문서가 우선한다.
>
> 001의 결정(R1~R28: 인증, 프록시, SSR 구성, 노출 조각 `PostExposure`, 테스트 방식, 정기 작업, 보안 헤더, 다국어), 002(D1~D11), 003(P1~P14), 004(B1~B17)의 결정은 그대로 따른다. 모든 API 경로는 `/api/v1` 접두어를 쓴다(트랙백 받기 `/{handle}/{postId}/trackback`만 예외, [contracts/api.md](./contracts/api.md)).

확인일: 2026-10-07 (blog-backend·blog-front main 기준. 001~003은 main에 있다. 004는 `feat/004-core`에서 구현 중이라 원격 브랜치가 아직 없어 [004 plan](../004-blog-features/plan.md)·[tasks](../004-blog-features/tasks.md)를 기준으로 읽었다)

## 현재 코드에서 확인한 것

- 관리자 API 접근: `admin/AdminAccessFilter`가 `/api/v1/admin/**`에서 DB의 현재 `role`·`status`를 다시 확인하고 아니면 404 `NOT_FOUND`(003). 005 관리자 API는 이 경로 아래에 두기만 하면 FR-043을 만족한다.
- 작업 기록: `admin/audit/AdminAuditService`·`AuditActions`(003 값만 있음, "005~007이 더한다").
- 운영 설정: `setting/SettingKey` enum이 키마다 검증·기본값을 정하고 `AdminSettingService`·`/api/v1/admin/settings`가 그대로 다룬다("005·007이 키를 더한다").
- 포털 감점: `portal/service/BlogPenaltyPolicy` 인터페이스와 감점 없는 `NoBlogPenaltyPolicy`(003, "005는 다른 구현을 빈으로 등록해 바꾼다").
- 회원 상태: `UserStatus.SUSPENDED` 값은 있으나 쓰는 곳이 없다. `User.isActive()`(ACTIVE만)를 로그인(`LoginService`), 갱신(`RefreshTokenService`), 블로그 조회(`BlogAccess`), 노출 조각(`PostExposure`), 구독이 이미 쓰므로 정지된 회원의 로그인·글·블로그는 지금도 막힌다. 막히는 응답이 404 `BLOG_NOT_FOUND`라 "이용이 제한된 블로그" 안내만 없다.
- 갱신 토큰 폐기: `RefreshTokenRepository.revokeAllByUserId`(001, 탈퇴에서 사용).
- 트랙백 받기 자리: backend `OriginCheckFilter.EXEMPT_PATHS`에 `/{handle}/{postId:\d+}/trackback`, front `server/middleware/backend-proxy.ts`가 `POST /:handle/:postId/trackback`을 backend로 프록시, 예약어 `trackback`·`report`·`reports`·`rights-request`가 `ReservedHandles`에 있음(001). `TrashPurgeRepository`가 영구 삭제 글의 트랙백을 지우고 `source_post_id`를 NULL로 바꾼다(001).
- 알림: `NotificationType` 주석이 "005 REPORT_RESOLVED"를 예고. 메일: `MailService`가 커밋 후 `@Async(AsyncConfig.EXECUTOR)`로 `MessageSource` 문구를 보낸다.
- 004(계획): 비회원 쓰기 자리 `GuestWriteGuard`(인터페이스, "005가 CAPTCHA·회원 속도로 바꿈")와 IP 속도 제한 `RateLimitGuestWriteGuard`, 댓글 `CommentVisibility.canRead`·방명록 `GuestbookVisibility.canRead`, 공용 `PlainTextNormalizer`, 예약 발행 `ScheduledPublishJob`("트랙백 전송 이벤트는 005가 발행 지점에 붙인다"), 공개 블로그 레이아웃 `routes/blog/layout.tsx`.
- E2E: `tests/e2e/support/backend.ts`의 `requireBackend()`·`requireAdmin()`·`requirePortalTestSettings()`. CI `ci.yml`의 `e2e-backend` 잡과 `e2e.yml`(nightly)이 일회용 MySQL·backend를 띄우고 관리자 계정을 만든다. Playwright `portal` 프로젝트는 전역 상태를 바꾸므로 `workers: 1`.

## M1. 숨김(HIDDEN)과 노출 (FR-041, SC-004)
- **Decision**:
  - `PostStatus.HIDDEN`을 더한다. 001 `PostExposure.listable()`은 `status = PUBLISHED`만 넣으므로 숨긴 글은 블로그 목록·태그·검색·구독 피드·RSS·Atom·사이트맵·포털·관련 글·사이드바·공지·보관함 모두에서 코드 변경 없이 빠진다. 상세는 `isDetailVisibleTo`가 주인에게 `!isDeleted()`면 보여주므로 주인은 계속 보고, 그 외는 `isBodyVisible`(PUBLISHED 필요)로 404다(노출 매트릭스 HIDDEN 행).
  - 글 숨김: `Post.hide()` → `status_before_hidden = status`, `status = HIDDEN`(DELETED·이미 HIDDEN이면 거부, 이미 HIDDEN이면 멱등). 해제 `Post.unhide()` → `status = status_before_hidden`, `status_before_hidden = NULL`. 예약 글(SCHEDULED)을 숨겼다가 해제했는데 시각이 지났으면 다음 예약 작업 주기에 발행된다(004 B5).
  - 숨긴 글 주인 화면: `PostDetail.hidden: true`(front가 "관리자가 숨긴 글입니다" 안내), 관리 글 목록 `status=HIDDEN` 필터. 숨김 동안 주인의 발행·발행 설정 변경·공개 범위 일괄 변경은 409 `POST_HIDDEN`(일괄은 건너뛴 수에 셈), 편집 저장(작성 중 사본)과 휴지통 이동은 허용. 휴지통으로 보내면 001 `moveToTrash`가 `status_before_delete = HIDDEN`을 남기고 복구하면 HIDDEN으로 돌아온다(data-model). 영구 삭제는 001 규칙 그대로.
  - 댓글·방명록·트랙백: `ACTIVE ↔ HIDDEN`만. 읽기 판단은 각자의 `canRead` 한 곳(004 `CommentVisibility`, `GuestbookVisibility`, 새 `TrackbackVisibility`)에 "HIDDEN은 작성 회원만(관리자는 콘솔에서)"을 더한다. 숨긴 댓글·방명록 글에 보이는 답글이 있으면 다른 사람에게는 삭제 자리와 같은 모양 `{ hidden: true, content: null, author: null }`, 없으면 목록에서 뺀다. 작성 회원에게는 내용과 `hidden: true`(안내 문구). 비회원 작성 글은 작성자를 확인할 수 없으므로 숨기면 작성자도 못 본다.
  - 개수: `posts.comment_count`는 ACTIVE 댓글 수다(001). 숨김은 원자적 UPDATE로 1 감소, 해제는 1 증가. 사이드바 최근 댓글·대시보드 최근 방명록·관리 화면 목록(주인)은 HIDDEN을 뺀다(주인도 관리자가 숨긴 남의 댓글을 보지 않음).
- **Rationale**: 001이 노출 매트릭스에 HIDDEN 행과 "작성자에게는 숨김 안내와 함께 보임"을, 004가 `canRead` 한 곳을 이미 정했다. 값만 더하면 규칙이 한 곳에 남는다.
- **Alternatives**: `hidden_at` 같은 별도 플래그 컬럼(스키마 변경, 노출 조각 전체에 조건 추가), 숨김을 휴지통 이동으로 처리(주인이 복구해 우회).

## M2. 신고 접수 (FR-040)
- **Decision**:
  - 회원 신고 `POST /reports` `{ targetType, targetId, reason, detail? }`(로그인 필요). 대상 종류는 1.0에서 POST·COMMENT·GUESTBOOK·TRACKBACK(M4). 처리기가 대상을 **신고자 기준으로** 읽는다: 신고자가 볼 수 없는 대상(남의 비공개 글, 볼 수 없는 비밀 댓글, 이미 숨김·삭제)은 404 `REPORT_TARGET_NOT_FOUND`. 자기 콘텐츠는 422 `CANNOT_REPORT_OWN_CONTENT`. 같은 대상을 이미 신고했으면(상태와 무관) 409 `REPORT_ALREADY_EXISTS`(UNIQUE 위반을 잡아 같은 코드).
  - 사유 8개(data-model) 중 하나, `detail` 1000자 이하이고 OTHER면 필수. `target_user_id`·`target_blog_id`는 접수 시점 값으로 채운다(글·댓글·방명록: 작성 회원·속한 블로그. 비회원 글은 회원 NULL. 트랙백: 서비스 안의 글이 보낸 것이면 그 글의 작성자·블로그, 아니면 둘 다 NULL — 받은 블로그를 감점하지 않음).
  - 남용 방지: 회원당 1시간 30건(`blog.reports.member-per-hour`, 공용 `RateLimiter`, 넘으면 429).
  - 권리 침해 신고 `POST /rights-requests` `{ targetUrl, reason, rightsBasis, contactEmail, captchaToken }`(비로그인 허용, 로그인 회원도 쓸 수 있으나 `reporter_id`는 NULL — 채널 정의상 비회원 양식). 사유는 COPYRIGHT·PRIVACY·DEFAMATION·OTHER만. `targetUrl`은 http/https 1000자 이하, `rightsBasis` 2000자 이하 필수, `contactEmail`은 001 이메일 규칙. CAPTCHA 필수(M9), IP당 1시간 5건. 응답 202(결과 없음, 접수 번호도 주지 않음 — 조회 수단이 없음).
  - 주소 해석(`ReportUrlResolver`): `blog.base-url` 아래 `/{handle}/{postId}`(쿼리·조각 무시)면 POST로, `#comment-{id}`·`#guestbook-{id}`·`#trackback-{id}` 조각이 있으면 그 대상으로 채운다(front가 각 항목에 이 앵커를 단다). 서비스 밖 주소나 해석 실패는 `target_type` NULL로 두고 관리자가 상세 화면에서 대상을 지정한다(M3).
- **Rationale**: data-model의 UNIQUE와 CHECK가 이미 규칙을 담았다. 신고자 기준으로 대상을 읽으면 존재를 확인하는 수단(신고 API로 비공개 글 존재 확인)이 생기지 않는다.
- **Alternatives**: 대상 존재 여부와 무관하게 접수(관리자 목록에 쓰레기가 쌓이고 존재 확인 수단은 여전함), 비회원 신고에 접수 번호·조회 화면(스키마·인증 수단 필요, 범위 밖).

## M3. 관리자 신고 처리 (FR-041, 006 FR-106)
- **Decision**:
  - 목록 `GET /admin/reports?status=PENDING|ACTIONED|DISMISSED&targetType=&channel=&page=`: 대상이 정해진 신고는 (target_type, target_id)로 묶어 한 줄(신고 수, 사유별 수, 첫·마지막 접수 시각, 대상 미리보기 요약), 대상이 없는 권리 침해 신고는 한 줄씩. 첫 접수 오래된 순(대기 처리 순서). 쿼리: 묶음 페이지 1 + 개수 1 + 미리보기는 대상 종류별 IN 1회씩(최대 4) — 대상 수와 무관.
  - 상세 `GET /admin/reports/{id}`: 그 신고와 같은 대상의 모든 신고(신고자 닉네임, 사유, 설명, 시각, 채널), 권리 침해면 `rightsBasis`·`targetUrl`과 복호화한 `contactEmail`(관리자만, `no-store`), 대상 미리보기(M4).
  - 대상 지정 `PATCH /admin/reports/{id}/target` `{ targetType, targetId }`: 대상이 없는 권리 침해 신고만(아니면 409 `REPORT_ALREADY_TARGETED`). 지정 후 목록에서 같은 대상 묶음에 합쳐진다.
  - 처리 `POST /admin/reports/{id}/resolve` `{ decision: "ACTION" | "DISMISS", action?, note? }`: ACTION이면 `action`은 `HIDE_CONTENT`(대상 숨김) 또는 `SUSPEND_USER`(대상 작성 회원 정지, `target_user_id` 필요). 대상의 **모든 PENDING 신고**를 같은 결과(`status`, `action`, `resolution_note`, `handled_by`, `handled_at`)로 조건부 UPDATE 한 번에 닫는다. 이미 처리된 신고면 409 `REPORT_ALREADY_RESOLVED`. 조치는 같은 트랜잭션에서 `ContentHideService`·`SuspensionService`를 부른다. 작업 기록 `REPORT_ACTION`·`REPORT_DISMISS`(target REPORT, 묶은 신고 id 목록과 조치) + 조치 자체의 기록(`CONTENT_HIDE`·`USER_SUSPEND`).
  - 결과 안내: 커밋 후 회원 신고자마다 `REPORT_RESOLVED` 알림(target REPORT/신고 id, `params: { targetType, decision }`, 대상 내용·제목은 넣지 않음), 비회원 권리 침해 신고자에게는 메일(M10).
- **Rationale**: data-model "관리자가 한 대상에 조치하거나 기각하면 그 대상의 PENDING 신고를 모두 같은 결과로 닫는다". 대상 단위 처리가 신고 수만큼 같은 판단을 반복하지 않게 한다.
- **Alternatives**: 신고 한 건씩 처리(같은 글 신고 50건을 50번), 묶음 테이블(스키마 변경).

## M4. 신고 대상 처리기 (FR-040, FR-041, 007 자리)
- **Decision**: `ReportTargetHandler` 인터페이스(대상 종류 1개당 구현 1개, Spring 빈 목록으로 등록): `resolveForReporter(id, reporterId)`(신고자 기준 존재·소유 확인과 작성자·블로그 id), `previews(ids)`(관리자 미리보기, IN 1회), `hide(id)`·`unhide(id)`, `publicUrl(id)`. 1.0 구현은 POST·COMMENT·GUESTBOOK·TRACKBACK 네 개. 미리보기: 글은 제목·블로그·상태·공개 범위와 요약(PRIVATE·PROTECTED는 제목만 — 006 FR-104 "관리자도 비공개 글 본문은 볼 수 없다"), 댓글·방명록 글은 내용 전체(비밀 글 포함 — 신고된 내용을 판단해야 하므로, 결정 표 6번), 트랙백은 제목·요약·보낸 주소. `EXTERNAL_POST`·`EXTERNAL_BLOG`은 enum 값만 두고 처리기가 없으면 신고 접수 400(`targetType` `INVALID`)·처리 선택지에서 빠진다. 007이 처리기 둘과 조치(`REMOVE_FROM_PORTAL`, `BLOCK_EXTERNAL_BLOG`)를 더한다.
- **Rationale**: 대상 종류별 규칙(노출, 작성자, 숨김 방식)이 달라 한 서비스에 분기를 쌓으면 007이 같은 파일을 고쳐야 한다. 처리기 목록이면 007은 새 클래스만 더한다.
- **Alternatives**: `switch(targetType)` 한 곳(007이 고칠 때마다 기존 시험 전부 영향).

## M5. 회원 정지 (FR-042, 006 FR-104)
- **Decision**:
  - 콘솔 회원 검색 `GET /admin/users?q=&by=email|nickname|handle&page=`: 이메일은 정규화 후 HMAC 해시 정확 일치(001 FR-135, 부분 검색 없음), 블로그 주소는 정확 일치(삭제된 블로그 포함), 닉네임은 앞부분 일치 20건(인덱스 없음 — plan.md 선택 제안 1). 결과: id, 닉네임, 상태, 권한, 가입일, 블로그 수. 회원 상세 `GET /admin/users/{id}`: 가입일, 상태, 권한, 글 수(휴지통 제외), 받은 신고 수(`target_user_id`), 블로그 목록과 수/한도(003 블로그 한도 응답과 같은 값). 이메일·비밀번호·비공개 글 본문은 주지 않는다(006 FR-104). 최근 로그인 시각은 001 `login_history`에서 1회 조회해 함께 준다.
  - 정지 `POST /admin/users/{id}/suspend` `{ reason }`(사유 1~500자 필수, 작업 기록 `reason`), 해제 `POST /admin/users/{id}/unsuspend` `{ reason? }`. ACTIVE만 정지(SUSPENDED면 멱등 200, WITHDRAWN이면 409 `USER_NOT_ACTIVE`). 자기 자신 422 `CANNOT_SUSPEND_SELF`. 관리자(ADMIN·SUPER_ADMIN) 정지는 SUPER_ADMIN만 가능하고 마지막 SUPER_ADMIN은 정지할 수 없다(403 `FORBIDDEN`, 409 `LAST_SUPER_ADMIN`) — 006 FR-105의 "최고 관리자 최소 1명" 규칙을 정지에도 적용.
  - 정지 즉시 적용: 같은 트랜잭션에서 `status = SUSPENDED` + 001 `revokeAllByUserId`(갱신 불가). 이미 발급된 접근 토큰(최대 30분)은 `SuspendedUserRegistry`(Caffeine, `expireAfterWrite` = 접근 토큰 수명)에 커밋 후 등록하고 `JwtAuthenticationFilter`가 등록된 회원의 토큰을 인증 없음으로 취급한다(→ 401, front는 로그아웃 상태). 해제 시 목록에서 뺀다. backend 재기동 때 목록이 비지만, 재기동 전에 발급된 접근 토큰의 회원은 이미 정지라 갱신이 막히고 모든 쓰기 서비스가 `BlogAccess`·`isActive`로 거부하므로 남는 위험은 "읽기 화면이 최대 30분 로그인 모양"뿐이다(결정 표 13번).
  - 그 밖의 효과는 `isActive()`로 이미 되어 있다: 로그인 401 `INVALID_CREDENTIALS`(정지 사실을 로그인 화면에 드러내지 않음 — 001 규칙 그대로), 그 회원의 모든 글이 노출 조각에서 빠짐(포털은 5분 캐시 안에, 003 FR-090), 구독 피드에서 빠짐.
  - 이용 제한 블로그: `GET /blogs/{handle}`이 블로그는 ACTIVE인데 주인이 SUSPENDED이면 404 `BLOG_RESTRICTED`(그 외 볼 수 없는 블로그는 지금처럼 404 `BLOG_NOT_FOUND`). 블로그 하위 공개 API(글 목록·글 상세·방명록 등)는 지금처럼 `BLOG_NOT_FOUND`·`POST_NOT_FOUND`(코드 변경 없음). front 공개 블로그 레이아웃(004 T046)이 `GET /blogs/{handle}`을 먼저 부르므로 `/:handle` 아래 모든 공개 화면이 "이용이 제한된 블로그" 안내(HTTP 404, `noindex`)를 그린다. 피드(RSS·Atom)·사이트맵은 404 그대로.
  - 정지 해제 때 콘텐츠는 그대로 돌아온다(숨김과 별개).
- **Rationale**: 001이 `users.status`와 `isActive` 판단을 이미 모든 곳에 넣었으므로 005는 상태 전이·토큰·안내만 더한다. 요청마다 DB 상태를 확인하는 대신 정지 목록을 쓰면 모든 쿼리 수 시험이 그대로다.
- **Alternatives**: 모든 인증 요청에서 `users.status` 조회(요청당 쿼리 +1), 접근 토큰 5분으로 단축(헌법 기술 제약 변경), 정지 회원 블로그를 403으로(노출 매트릭스가 404로 정함).

## M6. 처리 결과 알림과 포털 감점 (FR-041, 003 FR-086)
- **Decision**:
  - `NotificationType.REPORT_RESOLVED`, `NotificationTargetType.REPORT`를 더한다. 문구 키 `notification.reportResolved.{actioned|dismissed}`(4개 언어). 알림을 누르면 이동할 곳이 없으므로 링크 없는 항목(002 알림 화면의 "링크 없음" 표시).
  - `ReportPenaltyPolicy`(003 `BlogPenaltyPolicy`의 005 구현, `@Primary`가 아니라 `NoBlogPenaltyPolicy`를 지우고 대체): 후보 블로그 중 최근 `blog.reports.penalty-window`(기본 90일) 안에 ACTIONED 신고가 있는 블로그에 `1 - reportPenalty` 배수. 쿼리 `SELECT DISTINCT target_blog_id FROM reports WHERE target_blog_id IN (:ids) AND status = 'ACTIONED' AND handled_at >= :since` 1회(`idx_reports_target_blog_status`). 숨김 이력은 숨김 조치가 ACTIONED 신고 또는 관리자 직접 숨김의 작업 기록으로 남는데, 직접 숨김은 블로그 감점에 넣지 않는다(신고가 인정된 경우만, 결정 표 8번).
- **Rationale**: 003이 감점 자리와 `reportPenalty` 가중치를 이미 두었고, `target_blog_id` 인덱스가 이 계산용이다.
- **Alternatives**: 감점 기간 없이 영구(한 번의 신고로 영원히 감점), 직접 숨김까지 감점(작업 기록 JSON을 읽어야 함).

## M7. 관리자 콘텐츠 직접 숨김 (FR-041, 006 "콘텐츠 관리")
- **Decision**: 신고 없이도 숨길 수 있게 `PUT /admin/contents/{targetType}/{id}/hidden` `{ reason }`(멱등, 이미 숨김이면 200), 해제 `DELETE /admin/contents/{targetType}/{id}/hidden`. 대상 종류는 신고와 같은 처리기(M4)의 `hide`·`unhide`. 작업 기록 `CONTENT_HIDE`·`CONTENT_UNHIDE`(target_type = POST·COMMENT·GUESTBOOK·TRACKBACK, before/after에 상태). 숨긴 글 목록 `GET /admin/contents/hidden-posts?page=`(`idx_posts_status_scheduled`의 status). 숨긴 댓글·방명록·트랙백 목록과 글·댓글 전체 검색은 006 "콘텐츠 관리"로 미룬다(해제는 신고 상세나 작업 기록의 대상 id로 가능). 콘솔 화면은 신고 상세의 "숨김 해제" 버튼과 숨긴 글 목록만.
- **Rationale**: 신고 처리 외의 숨김·복구(006 표 "콘텐츠 관리: 숨김·복구")를 최소로 제공한다. 댓글 상태 인덱스가 없어 숨긴 댓글 전체 목록은 006에서 검색과 함께 설계한다.
- **Alternatives**: 숨김을 신고 처리로만(복구 수단이 없음).

## M8. 작성 속도 제한 (FR-142)
- **Decision**:
  - 공용 `RateLimiter`(Caffeine `expireAfterWrite` = 창 길이, 키 `{kind}:{subject}:{windowStart}` → `AtomicInteger`, 테스트용 `Ticker`). `check(kind, subject, limit, window)`가 넘으면 429 `TOO_MANY_REQUESTS` + `Retry-After`(남은 초).
  - 한도는 운영 설정 키(003 `SettingKey`에 추가, 값은 1 이상 정수, 기본값은 `blog.ratelimit.*` 프로퍼티): `ratelimit.post-publish-per-hour`(10, 회원 — 모든 블로그 합계, DRAFT·SCHEDULED에서 처음 PUBLISHED 또는 SCHEDULED로 갈 때만 셈, 수정 재발행·예약 작업의 발행은 세지 않음), `ratelimit.comment-per-minute`(5, 회원 ID 또는 비회원 IP), `ratelimit.guestbook-per-minute`(3, 같음), `ratelimit.media-upload-per-minute`(30, 회원), `ratelimit.signup-per-ip-per-hour`(5, IP). 003 data-model 표의 `ratelimit.*` 객체 하나 대신 005 data-model대로 키를 나눈다(값 하나씩 바꾸고 작업 기록에 키별로 남기기 쉬움, 결정 표 15번).
  - 004 `RateLimitGuestWriteGuard`와 `blog.guest.comment-per-minute`·`guestbook-per-minute`는 지우고 같은 숫자의 위 키로 옮긴다(회원·비회원 같은 한도, 비회원은 IP 기준). E2E 환경 변수 `BLOG_GUEST_*_PER_MINUTE`는 `BLOG_RATELIMIT_*`로 바뀐다(front README·workflow 함께).
  - 관리자는 속도 제한을 받지 않는다(운영 중 정리 작업). 블로그 주인이 자기 블로그에 쓰는 댓글·방명록 답글도 같은 한도(예외 없음).
- **Rationale**: 004가 같은 숫자를 IP 속도에 이미 썼고, 003 설정 체계(검증·기본값·작업 기록·캐시 무효화)를 그대로 쓰면 관리 화면도 기존 설정 API로 된다.
- **Alternatives**: Bucket4j 등 라이브러리(새 의존성, 1대 전제라 불필요), DB 카운터(쓰기마다 UPDATE).

## M9. CAPTCHA (FR-141)
- **Decision**:
  - 적용: 회원가입, 비회원 댓글·방명록 쓰기(004 `GuestWriteGuard` 자리), 권리 침해 신고, 로그인 반복 실패 후 재시도(같은 이메일 해시 또는 같은 IP의 연속 실패가 `blog.captcha.login-failures-before-captcha`(3) 이상이면 다음 로그인에 필요, 성공하면 초기화. 카운터는 공용 `RateLimiter`와 같은 Caffeine, 30분 창). 001의 5회 잠금(`locked_until`)은 그대로 둔다.
  - `CaptchaVerifier` 구현 셋, `blog.captcha.provider`로 고름: `turnstile`(prod 기본. `blog.captcha.site-key`·`secret-key` 필수, JDK `HttpClient`로 `https://challenges.cloudflare.com/turnstile/v0/siteverify`에 `secret`·`response`·`remoteip` POST, 연결·응답 3초, 실패·시간 초과는 거부), `test`(토큰이 `blog.captcha.test-token`(기본 `e2e-pass`)과 같을 때만 통과 — E2E·local 시험용, prod 프로필에서는 기동 실패), `none`(항상 통과, local 기본·단위 테스트).
  - 토큰이 없거나 틀리면 400 `CAPTCHA_FAILED`. 로그인은 필요할 때 토큰이 없으면 400 `CAPTCHA_REQUIRED`(front가 위젯을 보이고 다시 보냄). 요청 필드 이름은 `captchaToken`.
  - front 설정: `GET /captcha/config` → `{ provider, siteKey }`(공개, 1시간 캐시). front `Captcha` 컴포넌트는 `turnstile`이면 공식 스크립트를 그 화면에서만 nonce와 함께 넣어 위젯을 그리고 숨은 입력 `captchaToken`을 채운다. `test`면 "시험용 자동 확인" 표시와 숨은 입력(값 `e2e-pass`를 backend가 주지 않으므로 front 환경 변수 `BLOG_CAPTCHA_TEST_TOKEN`, 기본 `e2e-pass`), `none`이면 아무것도 그리지 않는다. CSP(001 R27)의 `script-src`·`frame-src`·`connect-src`에 `https://challenges.cloudflare.com`을 provider가 `turnstile`일 때만 더한다.
- **Rationale**: 외부 검증 결과만 확인하고 저장하지 않는다(data-model). Turnstile은 무료·추적 쿠키 없음·공식 시험 키가 있고, `test` provider로 CI E2E가 외부망 없이 결정적으로 돈다.
- **Alternatives**: Google reCAPTCHA(추적·개인정보 고지 부담), hCaptcha(비슷하나 시험 키 동작이 덜 단순), 자체 이미지 CAPTCHA(접근성·우회 대응을 직접), CI에서 Turnstile 공식 시험 키(외부망·위젯 로딩 타이밍에 E2E가 흔들림).

## M10. 권리 침해 처리 결과 메일과 연락처 파기 (FR-040)
- **Decision**: 처리(ACTION·DISMISS) 커밋 후 `contact_email_enc`를 복호화해 `MailService`가 결과 메일을 보낸다(접수 사실, 결정 "조치함"/"조치하지 않음", 대상 주소. 관리자 메모는 넣지 않음). 비회원은 언어 설정이 없고 접수 언어를 저장할 컬럼도 없으므로(스키마 변경을 피함) 메일은 **한국어와 영어를 한 메일에 함께** 쓴다(제목은 ko / en 병기, 본문은 ko 단락 뒤 en 단락, 문구는 `messages_ko`·`messages_en`). ja·zh-CN 문구 키도 4개 언어 파일에 넣어 두되 1.0 메일은 두 언어만 쓴다(결정 표 9번). 보존: 처리 후 `blog.privacy.rights-request-retention`(1년)이 지나면 001 개인정보 파기 작업이 `contact_email_enc = NULL`(행·나머지 내용은 남김). 접수 확인 메일은 보내지 않는다(이메일 소유 확인 없이 제3자 주소로 메일을 보내는 수단이 되지 않게).
- **Rationale**: data-model이 보존 기간과 파기 방식을 정했다. 접수 확인 메일을 빼면 양식이 스팸 발송 도구가 되지 않는다.
- **Alternatives**: 접수 언어 컬럼 추가(스키마 변경 — 필요하면 별도 승인), 접수 화면 언어 하나로 보내기(저장할 곳이 없어 처리 시점에 알 수 없음), 메일 없이 화면 안내(spec AS5가 메일 안내를 요구).

## M11. 금칙어 (FR-143)
- **Decision**:
  - 관리 API `GET /admin/banned-words?q=&page=`, `POST`(`{ word, scope, action }` → 201), `PATCH /admin/banned-words/{id}`, `DELETE /admin/banned-words/{id}`. `word`는 NFKC → 앞뒤 공백 제거 → 소문자로 정규화해 1~50자, 중복 409 `BANNED_WORD_EXISTS`. `scope = NAME`이면 `action`은 항상 REJECT(MASK를 보내면 400 `INVALID`). 작업 기록 `BANNED_WORD_CREATE`·`UPDATE`·`DELETE`.
  - `BannedWordMatcher`: 전체 목록을 메모리에 두고(변경 커밋 후 다시 읽음, 기동 시 1회) 같은 정규화를 거친 입력에서 부분 문자열 일치를 찾는다. 이름류에는 공백·구두점을 지운 문자열에도 검사(띄어 쓰기 우회 방지). 단어 수가 수백 개 규모라 단순 반복(`String.indexOf`)으로 충분하다.
  - 적용: 이름류(NAME·ALL) — 닉네임(가입·프로필), 블로그 주소(가입·블로그 만들기), 블로그 제목(만들기·수정), 비회원 이름(004 댓글·방명록) → 포함되면 400 `VALIDATION_FAILED` + field 코드 `BANNED_WORD`(어느 단어인지는 알려주지 않음). 본문류(CONTENT·ALL) — 댓글·방명록 내용 → `REJECT` 단어가 하나라도 있으면 같은 400(field `content`), `MASK` 단어만 있으면 그 부분을 같은 길이의 `*`로 바꿔 저장(원문은 남기지 않음). 글 제목·본문, 트랙백, 카테고리·태그 이름에는 적용하지 않는다(spec 범위). 기존에 저장된 데이터는 다시 검사하지 않는다.
- **Rationale**: spec이 적용 대상과 처리 방식을 정했고, 정규화는 data-model 규칙. 목록이 작아 DB 조회 없이 메모리로 충분하다.
- **Alternatives**: Aho-Corasick 등 자료구조(단어 수가 적어 불필요), 저장 후 표시 때 가림(원문이 DB에 남아 관리 화면·피드로 샘).

## M12. 반복 댓글 차단 (FR-144)
- **Decision**: `DuplicateContentDetector`가 댓글(방명록 포함 — 같은 스팸 경로)마다 작성 주체(회원 ID 또는 비회원 IP) + 정규화한 내용(NFKC·소문자·공백 하나로)의 SHA-256을 키로 `spam.duplicate-comment.windowMinutes`(10분) 창의 횟수를 세고, 같은 키가 `maxCount`(3)에 이미 닿았으면 다음 쓰기를 422 `DUPLICATE_CONTENT_SPAM`으로 거부한다("여러 글에" — 같은 글·다른 글 구분 없이 같은 내용 반복이면 스팸으로 봄). 짧은 내용(정규화 후 10자 미만: "감사합니다" 등)은 세지 않는다(결정 표 18번). 설정 키 `spam.duplicate-comment` = `{ windowMinutes: 1~1440, maxCount: 2~100 }`.
- **Rationale**: 저장 없이 메모리 카운터(data-model). 짧은 인사말까지 막으면 정상 사용자가 막힌다.
- **Alternatives**: DB에서 최근 10분 같은 내용 조회(내용 인덱스 없음, 쓰기마다 쿼리).

## M13. 트랙백 받기 (FR-049~051, FR-053~055) — 001 R16 받기를 옮겨 확정
- **Decision**:
  - 경로 `POST /{handle}/{postId}/trackback`(`/api/v1` 밖, 001 R16·routes.md, Origin 검사 제외는 001에 이미 있음). `SecurityConfig`에서 이 경로 POST만 비로그인 허용. 요청 `application/x-www-form-urlencoded`: `url`(필수, http/https, 1000자 이하), `title`·`excerpt`·`blog_name`(선택). 문자셋은 `Content-Type`의 charset을 우선(EUC-KR 등 오래된 블로그), 없으면 UTF-8로 본문을 직접 디코딩한다(서블릿 기본 ISO-8859-1 해석을 쓰지 않음).
  - 응답은 항상 HTTP 200 + `Content-Type: text/xml; charset=utf-8`, 본문 `<?xml version="1.0" encoding="utf-8"?><response><error>0</error></response>` 또는 `<error>1</error><message>…</message>`(TrackBack 1.2는 HTTP 상태가 아니라 `error` 값으로 판단). 메시지는 영어 고정 문구 몇 개(`Trackback is not allowed`, `Duplicate trackback`, `Too many pings`, `Invalid url`, `Missing url`)이며 XML 이스케이프한다. 공통 응답 틀을 쓰지 않는 예외(contracts/api.md). GET이면 405(XML 아님, 기본 처리).
  - 확인 순서: IP 속도(같은 출처 IP 10분 10회, `blog.trackback.receive-limit`·`receive-window`, 넘으면 error 1 `Too many pings`, 저장 없음) → 글 존재·`handle` 일치·"본문 노출 가능"(001 `PostExposure.isBodyVisible` — 비공개·보호·임시·예약·삭제·숨김·정지 회원 글 모두 거부, FR-055) → 블로그 `trackback_enabled` → `url` 검증 → 정규화(스킴·호스트 소문자, 기본 포트·조각 제거, 끝 `/` 유지)한 `url`의 SHA-256으로 UNIQUE 확인(이미 있으면 DELETED·HIDDEN 행 포함 error 1 `Duplicate trackback`, FR-054·Edge Cases) → 저장. 글이 없거나 볼 수 없으면 존재를 숨기려고 "허용 안 함"과 같은 메시지.
  - 저장 값: `title`·`excerpt`·`blog_name`은 HTML 태그를 지우고(`Jsoup` 없이 001 `PlainTextNormalizer`의 태그 제거 + 엔터티 해제) 제어 문자를 지운 일반 텍스트로 각각 255자에서 자른다(`excerpt`는 FR-051 최대 255자). `title`이 비면 `url`을 제목으로. 송신 IP는 `sender_ip_enc`(AES-256-GCM, 90일 뒤 001 파기 작업이 NULL로 — 개인정보 파기 단계 추가). 화면은 텍스트로만 출력(React 이스케이프)하므로 스크립트가 실행되지 않는다(Edge Cases).
  - 동시 같은 핑: UNIQUE 위반 예외를 잡아 `Duplicate trackback`으로 응답(H2에서도 같은 제약).
- **Rationale**: 001이 경로·Origin 예외·프록시를 이미 정했고, TrackBack 1.2 규격(spec Assumptions)이 응답 모양을 정한다. 볼 수 없는 글을 "허용 안 함"으로 묶으면 핑으로 비공개 글 존재를 확인할 수 없다.
- **Alternatives**: `/api/v1/posts/{id}/trackback`(외부 블로그가 보내는 주소가 글 주소 아래가 아니게 됨, 001 routes.md와 어긋남), 실패 시 HTTP 4xx(오래된 클라이언트가 본문을 읽지 않음).

## M14. 트랙백 목록·주소·자동 발견 (FR-049, FR-051, FR-053)
- **Decision**:
  - 글 상세 `PostDetail`에 `trackbackUrl`(글이 본문 노출 가능이고 블로그 `trackbackEnabled`일 때만, 아니면 null)과 `trackbackCount`(보이는 트랙백 수, 목록 쿼리의 count). 주소는 `{blog.base-url}/{handle}/{postId}/trackback`.
  - 목록 `GET /posts/{id}/trackbacks?page=`(모두, 글 상세를 볼 수 있을 때만, 아니면 404 `POST_NOT_FOUND`): ACTIVE, 최신순 20개, 제목·요약·블로그 이름·보낸 주소·받은 시각. 서비스 안 글이 보낸 트랙백(`source_post_id`)은 그 글이 본문 노출 가능일 때만(LEFT JOIN 출처 글·블로그·작성자에 별칭을 둔 노출 조건 — `PostExposure`에 별칭을 받는 `bodyVisible(QPost, QBlog, QUser)` 오버로드 추가). 쿼리 목록 1 + 개수 1.
  - 트랙백 받기를 끈 블로그도 이미 받은 트랙백은 계속 보여준다(끄는 것은 받기만, 결정 표 22번).
  - 자동 발견: 글 상세 SSR HTML에 TrackBack 1.2의 RDF 블록을 HTML 주석으로 넣는다(`rdf:about`·`dc:identifier` = 글 주소, `dc:title`, `trackback:ping` = 트랙백 주소). `trackbackUrl`이 null이면 넣지 않는다. 화면에는 "이 글의 트랙백 주소"와 복사 버튼(FR-049, AS6).
  - 주인 관리: `GET /blogs/{handle}/manage/trackbacks?page=`(그 블로그 글들이 받은 트랙백, ACTIVE·HIDDEN, 최신순, 받은 글 제목 포함, HIDDEN은 `hidden: true`·삭제 불가 표시), `DELETE /trackbacks/{id}`(그 글의 주인, ACTIVE만 → DELETED, 행은 남겨 같은 주소 재수신을 막음). 블로그 설정 `trackbackEnabled`(PATCH /blogs/{handle}, 기본 true).
- **Rationale**: 받은 쪽이 보여줄 내용(FR-051)과 자동 발견 규격을 따르면 다른 서비스가 주소를 찾을 수 있어 SC-009 수신율이 오른다.
- **Alternatives**: 트랙백을 끄면 목록도 숨김(이미 맺은 연결을 잃음 — 원하면 하나씩 삭제).

## M15. 트랙백 보내기 (FR-052) — 001 R16 보내기를 옮겨 확정
- **Decision**:
  - 발행 설정(`PublishSettings`)에 `trackbackUrls?: string[]`(최대 10개, 각 1000자 이하, 중복 제거, http/https만 — 형식 오류는 400 field `trackbackUrls[i]` `INVALID`). 글이 PUBLIC이 아니면(PRIVATE·PROTECTED) 422 `TRACKBACK_NOT_ALLOWED`(비공개 글 주소를 외부에 알리지 않음). 요청을 받으면 주소마다 `trackback_ping_logs` PENDING 행을 만든다. 발행(즉시)이거나 이미 발행된 글의 수정이면 커밋 후 `TrackbackSendRequested(postId, logIds)` 이벤트, 예약 발행(004)이면 행만 만들고 004 `ScheduledPublishJob`이 발행한 글마다 PENDING 행을 post_id로 찾아(`idx_trackback_ping_logs_post_created`) 같은 이벤트를 낸다. 예약을 취소하거나 글을 휴지통에 보내면 그 글의 PENDING 행은 지운다(보내지 않은 요청이며, data-model의 실패 이유 값에 "보내지 않음"이 없다. 결정 표 25번).
  - 송신(`TrackbackDispatchListener`, `@Async("trackbackExecutor")` 스레드 2개·대기열 100, `@TransactionalEventListener(AFTER_COMMIT)`): 보내기 직전 글이 여전히 본문 노출 가능인지 확인(아니면 그 PENDING 행을 지우고 보내지 않음). 대상이 서비스 안 주소(`{blog.base-url}/{handle}/{postId}` 또는 `/trackback`)면 HTTP 없이 `TrackbackReceiveService.receiveInternal(source, targetPostId)`를 부르고 `source_post_id`를 채운다(IP 속도 제한 없음, 나머지 규칙 동일, FR-052 "서비스 안 주소도 같은 방식"). 밖이면 `OutboundUrlGuard`(M16)를 통과한 주소에 JDK `HttpClient`(리다이렉트 따르지 않음, 연결 5초·응답 5초, `blog.trackback.connect-timeout`·`read-timeout`)로 `application/x-www-form-urlencoded; charset=utf-8` POST: `url`(글 주소), `title`, `excerpt`(글 요약 255자), `blog_name`(블로그 제목). 응답 본문은 64KB까지만 읽고 XXE를 끈 파서로 `<error>`를 읽는다.
  - 결과: `<error>0</error>` → SUCCESS. 2xx가 아니면 `HTTP_ERROR`(메시지에 상태 코드), `<error>1</error>`·XML 아님 → `REMOTE_ERROR`(상대 `<message>`를 태그 제거해 255자), 시간 초과 → `TIMEOUT`, 내부망 → `BLOCKED_ADDRESS`, 주소 해석 실패·형식 → `INVALID_URL`. `attempted_at` 기록. 재시도는 하지 않는다(실패를 보여주고 회원이 다시 보냄).
  - 재기동 복구: 기동 직후(`ApplicationReadyEvent`) 1회, 만든 지 5분 넘은 PENDING 중 글이 발행 상태인 것을 다시 보낸다(예약 글의 미래 PENDING은 그대로). 상태 인덱스가 없어 전체 훑기 — plan.md 선택 제안 2.
  - 결과 보기: `GET /posts/{id}/trackback-pings`(주인, 최신 50개), 발행 설정 레이어와 관리 글 목록의 "트랙백 결과"에서 주소별 성공·실패와 이유(AS2). front는 발행 직후 PENDING이면 "보내는 중"으로 보이고 화면을 다시 열면 결과가 보인다(폴링 없음).
- **Rationale**: 001 R16의 커밋 후 비동기·5초 제한·내부 호출을 그대로 확정했다. 예약 글은 실제 발행 때 보내야 공개 전 글 주소가 새지 않는다.
- **Alternatives**: 정기 작업으로 PENDING 폴링(상태 인덱스 필요), 실패 자동 재시도(상대 서버 부담·스팸처럼 보임).

## M16. 내부망 주소 차단 (spec Assumptions, 007 재사용)
- **Decision**: `common/net/OutboundUrlGuard.check(uri)`: 스킴 http/https, 포트 80·443·8080·8443(설정 `blog.outbound.allowed-ports`), 사용자 정보(`user@`) 금지, 호스트를 `InetAddress.getAllByName`으로 해석해 **하나라도** 루프백·사설(10/8, 172.16/12, 192.168/16, fc00::/7)·링크로컬(169.254/16, fe80::/10)·CGNAT(100.64/10)·멀티캐스트·와일드카드·IPv4 매핑 IPv6면 `BLOCKED_ADDRESS`. 해석한 주소로 연결을 고정하지 못하는 JDK `HttpClient`의 한계(DNS 재바인딩)는 리다이렉트 금지 + 짧은 시간 제한으로 줄이고 남는 위험을 운영 문서에 적는다(결정 표 26번). 시험·E2E는 내부 주소를 쓰므로 `blog.outbound.allow-private`(기본 false, prod에서 true면 기동 실패)를 둔다.
- **Rationale**: SSRF 방지(001 R16). 007 피드 수집도 같은 검사가 필요하다.
- **Alternatives**: 프록시 서버 경유(실행 파트 추가, 원칙 II), 자체 소켓으로 IP 고정 연결(HTTPS SNI·인증서 처리를 직접 해야 함).

## M17. 수신율 측정 (SC-009)
- **Decision**: 수신 쪽은 주요 블로그 서비스가 보내는 실제 요청 모양을 고정 데이터로 두고 `TrackbackXmlControllerTest`·`TrackbackInteropTest`에서 모두 저장되는지 확인한다: Movable Type·WordPress(UTF-8, `blog_name` 포함), 티스토리 형식(UTF-8, `excerpt`에 HTML), 오래된 국내 설치형(EUC-KR charset, 선택 필드 없음), `title`만 없는 요청, 큰 `excerpt`(잘림). 20가지 중 19가지 이상 저장(95%)이 기준이며 지금 목록은 모두 저장되어야 한다. 송신 쪽은 JDK 테스트 HTTP 서버가 위 규격 응답(error 0/1, 200이 아닌 상태, XML 아님, 느린 응답)을 돌려주는 경우를 확인한다. 실제 외부 서비스로의 시험은 수동 quickstart(#33)로 한다.
- **Rationale**: 외부 서비스에 자동으로 보내는 시험은 CI에서 흔들리고 상대에게 스팸이 된다.

## M18. E2E와 CI (헌법 III, 소유자 지시 "E2E는 CI에서 실제로 돈다")
- **Decision**:
  - backend 실행 환경 변수(두 workflow의 "Start backend"에 추가): `BLOG_CAPTCHA_PROVIDER=test`, `BLOG_RATELIMIT_SIGNUP_PER_IP_PER_HOUR=100000`, `BLOG_RATELIMIT_COMMENT_PER_MINUTE=1000`, `BLOG_RATELIMIT_GUESTBOOK_PER_MINUTE=1000`, `BLOG_RATELIMIT_POST_PUBLISH_PER_HOUR=100000`, `BLOG_RATELIMIT_MEDIA_UPLOAD_PER_MINUTE=1000`, `BLOG_TRACKBACK_RECEIVE_LIMIT=100000`, `BLOG_REPORTS_MEMBER_PER_HOUR=100000`, `BLOG_REPORTS_RIGHTS_REQUEST_PER_IP_PER_HOUR=100000`. E2E는 모두 같은 IP(localhost)에서 수십 명을 가입시키므로 이 값이 없으면 001~004 E2E가 가입 단계에서 막힌다. 구현에서는 `BLOG_CAPTCHA_LOGIN_FAILURES_BEFORE_CAPTCHA=100000`도 더했다: 모든 E2E 시나리오가 같은 IP라 로그인 CAPTCHA 기준(같은 IP 연속 3회 실패)이 001의 잠금·오류 문구 시나리오를 서로 막기 때문이다(기준 동작은 `LoginCaptchaPolicyTest`·`LoginServiceTest`가 본다). 004가 더한 `BLOG_GUEST_*_PER_MINUTE`는 지운다(M8).
  - Playwright 환경 변수(두 workflow의 E2E 단계): `E2E_MODERATION_TEST_SETTINGS=1`(위 backend 설정으로 띄웠다는 표시), front 서버용 `BLOG_CAPTCHA_TEST_TOKEN`은 기본값(`e2e-pass`)을 쓰므로 더하지 않는다. 관리자 계정(`E2E_ADMIN_*`)은 003에서 이미 있다.
  - 속도 제한·반복 스팸 자체는 backend 단위 테스트로 확인하고, E2E는 관리자가 설정 화면에서 값을 바꾸고 되돌리는 흐름과 금칙어·CAPTCHA 거부·반복 스팸(새 회원·고유 내용으로 3회)을 확인한다. 전역 설정·금칙어를 바꾸는 시나리오는 `moderation` 프로젝트(`workers: 1`, `e2e` 뒤)에서 돈다.
  - 기존 E2E 영향: 가입 화면에 `test` CAPTCHA 숨은 입력이 자동으로 들어가 `signUp` 도구는 그대로. 로그인 실패 시험(001 us1-account)은 3회 실패 후 `test` 위젯이 자동으로 토큰을 채우므로 그대로. 같은 문구 댓글을 3번 넘게 쓰는 기존 시나리오가 있으면 고유 문구로 바꾼다(tasks.md T006).
- **Rationale**: CI에서 건너뛰는 E2E는 시험이 아니다. 운영 한도는 운영 값 그대로 두고 시험 환경에서만 넓힌다.
