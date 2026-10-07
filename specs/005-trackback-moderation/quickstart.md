# Quickstart: 005 트랙백과 운영 검증 가이드

구현이 끝난 뒤 이 순서로 실행해 스펙이 동작함을 확인한다. 세부 API는 [contracts/api.md](./contracts/api.md), 화면은 [contracts/routes.md](./contracts/routes.md), 근거는 [research.md](./research.md).

## 준비

001 [quickstart](../001-blog-core/quickstart.md)의 "준비", 002~004 quickstart의 추가 준비대로 MySQL(또는 Crowfoot 개발 DB `cf_u2_d2`), Mailpit, backend, front를 띄운다. 005에서 더할 것:

```bash
# 1) CAPTCHA: 로컬 기본은 none(검증 안 함). 화면 흐름을 보려면 test로(토큰 e2e-pass가 자동으로 채워짐).
#    실제 Turnstile을 보려면 Cloudflare 공식 시험 키(항상 통과)를 쓴다:
#    BLOG_CAPTCHA_PROVIDER=turnstile BLOG_CAPTCHA_SITE_KEY=1x00000000000000000000AA BLOG_CAPTCHA_SECRET_KEY=1x0000000000000000000000000000000AA
export BLOG_CAPTCHA_PROVIDER=test

# 2) 수동 반복 시험용(로컬만). 같은 PC에서 여러 계정을 만들고 여러 번 쓰므로 한도를 넓힌다.
#    #21~#26의 한도 확인 때는 이 값을 빼고 다시 띄운다.
export BLOG_RATELIMIT_SIGNUP_PER_IP_PER_HOUR=1000
export BLOG_RATELIMIT_COMMENT_PER_MINUTE=1000
export BLOG_RATELIMIT_GUESTBOOK_PER_MINUTE=1000
export BLOG_TRACKBACK_RECEIVE_LIMIT=1000

# 3) 트랙백 보내기를 로컬 시험 서버(127.0.0.1)로 보내 보려면(#33). 운영에서는 절대 켜지 않는다.
export BLOG_OUTBOUND_ALLOW_PRIVATE=true

# 4) 계정 준비: A(handle marco), B(handle reader), C(handle third)를 /signup으로 만들고,
#    관리자 계정 M을 만든 뒤 role을 SUPER_ADMIN으로(003 quickstart의 bootstrap 또는 scripts/e2e-provision-admin.sh).
```

## 자동 검증

```bash
cd blog/blog-backend && ./mvnw verify          # 슬라이스·H2 테스트 + JaCoCo 80%. 005는 MySQL 전용 테스트가 없다
cd blog/blog-front && npm test -- --coverage   # Vitest 80%, 번역 누락 점검 포함
# E2E: backend를 CI와 같은 값으로 띄운 뒤(결정 표 29번)
cd blog/blog-front && E2E_BACKEND_URL=http://localhost:8080 E2E_ADMIN_EMAIL=... E2E_ADMIN_PASSWORD=... \
  E2E_MODERATION_TEST_SETTINGS=1 npm run e2e
```

## 수동 검증 시나리오

| # | 스토리 | 절차 | 기대 결과 |
|---|---|---|---|
| 1 | US1 | A가 글 "신고 시험" 발행 → B로 글 상세에서 "신고" → 사유 "스팸" | "신고가 접수되었습니다". 같은 글 다시 신고하면 "이미 신고한 콘텐츠입니다" (AS1, FR-040) |
| 2 | US1 | B가 A 글의 댓글·방명록 글(004)을 각각 신고, A가 자기 글을 신고 시도(`curl -X POST /api/v1/reports`) | 댓글·방명록 접수. 자기 글 422 `CANNOT_REPORT_OWN_CONTENT` |
| 3 | US1 | 비로그인으로 신고 API 호출, B가 A의 비공개 글 id로 신고 | 401, 404 `REPORT_TARGET_NOT_FOUND`(비공개 글 존재를 드러내지 않음) |
| 4 | US1 | 사유 "기타"를 설명 없이 신고 | 400 field `detail` `REQUIRED` |
| 5 | US1 | M으로 `/admin/reports` | 대기 탭에 A 글 묶음(신고 1건), 댓글·방명록 묶음. 메뉴 배지에 대기 수 |
| 6 | US1 | M이 A 글 상세에서 "숨김" 처리 → 비로그인·B·C로 `/marco/신고시험글`, `/marco`, `/search?q=신고`, `/marco/rss`, `/sitemap.xml`, `/` | 상세 404, 어디에도 없음. 포털은 캐시(기본 5분) 뒤 (Independent Test, AS2, SC-004) |
| 7 | US1 | A로 같은 글 상세, `/marco/manage/posts?status=HIDDEN` | 글이 "관리자가 숨긴 글입니다"와 함께 보이고, 관리 목록 "숨김" 필터에 나옴. 발행 설정 저장 시 409 `POST_HIDDEN` 문구 (FR-041) |
| 8 | US1 | B의 알림 화면 | "신고하신 콘텐츠를 검토해 조치했습니다"(링크 없음) (FR-041) |
| 9 | US1 | M이 댓글 신고를 "숨김"으로 처리 → 비로그인·A·B(신고자)·댓글 작성자로 글 상세 | 작성자만 내용과 "관리자가 숨긴 글입니다". 다른 사람에게는 안 보임(답글이 있으면 자리만). 글 댓글 수가 1 줄어듦 |
| 10 | US1 | M이 방명록 신고를 "기각" | 방명록 글은 그대로, 신고자 알림 "…조치하지 않았습니다" |
| 11 | US1 | M이 `/admin/reports?status=ACTIONED`에서 #6 글 "숨김 해제" | A 글이 이전 상태(발행·공개)로 돌아와 다시 보임. 작업 기록에 `CONTENT_HIDE`·`CONTENT_UNHIDE`·`REPORT_ACTION`(DB `admin_audit_logs`) |
| 12 | US1 | M이 `/admin/users?by=nickname&q=닉C` → C 상세 → "정지"(사유) | 상세에 글 수·받은 신고 수·블로그 목록. 상태 "정지" |
| 13 | US1 | 정지 직후, 로그인해 있던 C의 브라우저에서 아무 화면 새로 고침 → C로 다시 로그인 | 로그아웃 상태(접근 토큰도 즉시 무효), 로그인은 "이메일 또는 비밀번호가 맞지 않습니다" (AS3, FR-042) |
| 14 | US1 | 비로그인으로 `/third`, `/third/{글번호}`, `/third/guestbook`, `curl /api/v1/blogs/third` | 화면은 "이용이 제한된 블로그"(HTTP 404, noindex), API 404 `BLOG_RESTRICTED`. C의 다른 블로그도 같음 (AS3) |
| 15 | US1 | M이 C "정지 해제" | C 로그인 가능, 블로그·글이 다시 보임 |
| 16 | US1 | B(일반 회원)로 `/admin/reports`, `curl /api/v1/admin/reports`, 비로그인으로 같은 요청 | 화면 404, API 404 `NOT_FOUND` (AS4, FR-043) |
| 17 | US1 | ADMIN 권한 관리자 M2가 SUPER_ADMIN M 정지 시도, M이 자기 자신 정지 시도 | 403 `FORBIDDEN`, 422 `CANNOT_SUSPEND_SELF` |
| 18 | US1 | 로그아웃 상태로 `/rights-request?url=http://localhost:5173/marco/{글번호}` → 사유 "저작권", 근거, 이메일 `owner@example.test` 입력·제출 | "접수되었습니다…". DB `reports`에 RIGHTS_REQUEST, `contact_email_enc`는 암호문, 대상이 그 글로 채워짐 (AS5) |
| 19 | US1 | M이 그 신고를 "숨김"으로 처리 → Mailpit | `owner@example.test`로 한국어·영어 결과 메일(관리자 메모 없음) (AS5, FR-040) |
| 20 | US1 | 서비스 밖 주소(`https://example.com/x`)로 권리 침해 신고 → M이 상세에서 "대상 지정"(A 글 주소) → 처리 | 대상 없이 접수된 한 줄이 지정 후 그 글 묶음에 합쳐짐 |
| 21 | US2 | (한도 기본값으로 다시 띄움) 같은 PC에서 6번째 가입 | 429와 "잠시 후 다시 시도해 주세요" (FR-142) |
| 22 | US2 | B로 1분 안에 댓글 6개 | 6번째 429 (FR-142) |
| 23 | US2 | 새 회원 D로 서로 다른 글 3개에 "같은 홍보 문구입니다 연락주세요"를 쓴 뒤 4번째 | 4번째 422 `DUPLICATE_CONTENT_SPAM` 문구. "감사합니다"(10자 미만)는 계속 써짐 (FR-144) |
| 24 | US2 | M이 `/admin/spam`에서 금칙어 "나쁜말"(이름류·거부), "비속어"(본문류·가림) 추가 → 닉네임 "나쁜말짱"으로 가입, 블로그 제목 "나쁜 말 블로그"(공백) | 둘 다 "사용할 수 없는 단어가 있습니다" (FR-143) |
| 25 | US2 | B가 댓글 "이건 비속어 입니다" | 저장되고 "이건 *** 입니다"로 보임(DB에도 가린 값). 금칙어 처리 방식을 "거부"로 바꾸면 같은 댓글이 거부됨 |
| 26 | US2 | M이 `/admin/spam`에서 댓글 한도 1분 5개 → 2개로 저장 → B로 댓글 3개 → "기본값으로" | 3번째 429, 되돌린 뒤 다시 5개. 작업 기록 `SETTING_CHANGE` 2건 |
| 27 | US2 | `BLOG_CAPTCHA_PROVIDER=turnstile`(시험 키)로 띄우고 `/signup`, 비회원 댓글(004 비회원 허용 블로그), `/rights-request` | 위젯이 보이고 통과 후 저장. `curl`로 `captchaToken` 없이 가입 → 400 `CAPTCHA_FAILED` (FR-141) |
| 28 | US2 | 같은 이메일로 틀린 비밀번호 3번 → 4번째 | 4번째부터 CAPTCHA가 보이고, 토큰 없이 API로 로그인하면 400 `CAPTCHA_REQUIRED` (FR-141) |
| 29 | US3 | A 글 상세 | "트랙백 주소 http://localhost:5173/marco/{id}/trackback"과 복사 버튼, 페이지 소스에 RDF 주석 (AS6, FR-049) |
| 30 | US3 | `curl -X POST -d "url=https://other.example/p/1&title=<script>alert(1)</script>참고&excerpt=요약&blog_name=Other" http://localhost:5173/marco/{id}/trackback` | `<error>0</error>`. 글 아래 트랙백에 제목 "alert(1)참고"(태그 제거, 실행 없음)·요약·블로그 이름·링크 (Independent Test, AS1, FR-050·051) |
| 31 | US3 | #30을 다시 보냄, EUC-KR로 인코딩한 요청(`-H "Content-Type: application/x-www-form-urlencoded; charset=EUC-KR" --data-binary @euckr.txt`) | 다시 보낸 것은 `<error>1</error><message>Duplicate trackback</message>`, EUC-KR 요청은 한글이 깨지지 않고 저장 (FR-054, SC-009) |
| 32 | US3 | A의 비공개 글·보호 글·없는 글 번호로 핑, A가 블로그 설정에서 "트랙백 받기"를 끈 뒤 공개 글로 핑 | 모두 `Trackback is not allowed`, 저장 없음. 이미 받은 트랙백은 그대로 보임 (AS3, FR-055) |
| 33 | US3 | B가 글을 쓰며 발행 설정 "트랙백 보내기"에 A 글 주소(`http://localhost:5173/marco/{id}`)와 로컬 시험 서버 주소(`python3 -m http.server`처럼 아무 응답 서버) 입력 → 발행 → 관리 글 목록 "트랙백 결과" | A 글에 B 글 트랙백(서비스 안 직접 처리). 시험 서버는 "실패: REMOTE_ERROR"(규격 응답이 아님). 발행은 바로 끝남 (Independent Test, AS2, FR-052) |
| 34 | US3 | `BLOG_OUTBOUND_ALLOW_PRIVATE` 없이 다시 띄우고 `http://127.0.0.1:9/x`, `http://169.254.169.254/latest` 로 보내기 | 둘 다 "실패: BLOCKED_ADDRESS" (spec Assumptions) |
| 35 | US3 | 응답하지 않는 주소(`http://10.255.255.1/` 대신 허용 설정에서 `nc -l 9999` 처럼 응답 없는 서버)로 보내기 | 약 5초 뒤 "실패: TIMEOUT", 발행은 즉시 완료 (Edge Cases) |
| 36 | US3 | B가 글을 비공개로 바꾸고 트랙백 보내기 | 422 `TRACKBACK_NOT_ALLOWED` 문구 |
| 37 | US3 | B가 예약 발행(004) 글에 A 글 주소를 넣고 예약 → 예약 시각 전 A 글 확인 → 시각 뒤 확인 | 예약 전에는 트랙백 없음, 발행 뒤 1분 안에 생김 |
| 38 | US3 | B가 #33 글을 비공개로 바꿈 → A 글 상세 | B 글이 보낸 트랙백이 목록에서 빠짐(행은 남음) (001 노출 매트릭스) |
| 39 | US3 | A가 `/marco/manage/trackbacks`에서 #30 트랙백 "삭제" → 같은 핑 다시 | 목록에서 사라지고, 다시 보낸 핑은 `Duplicate trackback` (AS4, FR-053·054) |
| 40 | US3 | 같은 IP에서 10분 안에 핑 11번(한도 기본값으로 다시 띄움) | 11번째 `Too many pings`, 저장 없음 (AS5, FR-054) |
| 41 | US3 | B가 A 글의 트랙백 신고 → M이 숨김 | 트랙백이 A 글에서 사라지고 A의 관리 화면에 "숨김"(삭제 불가) (FR-040·041·054) |
| 42 | 공통 | 모바일 폭 360px로 글 상세 트랙백 영역, 신고 레이어, `/rights-request`, `/admin/reports` | 가로 스크롤 없음 |
| 43 | 공통 | 화면 언어를 en·ja·zh-CN으로 바꿔 #1, #18, #24, #29 화면 | 모든 새 문구가 그 언어(트랙백 제목·요약은 원문 그대로) |
| 44 | 공통 | 1년 지난 처리 신고를 만들기(DB에서 `handled_at`을 과거로) → 개인정보 파기 작업 실행(`blog.jobs.privacy-purge-cron`을 짧게) | `contact_email_enc`가 NULL, 나머지 내용은 남음. 90일 지난 트랙백 `sender_ip_enc`도 NULL |
