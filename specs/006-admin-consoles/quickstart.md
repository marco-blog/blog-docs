# Quickstart: 006 관리 화면 검증 가이드

구현이 끝난 뒤 이 순서로 실행해 스펙이 동작함을 확인한다. 세부 API는 [contracts/api.md](./contracts/api.md), 화면은 [contracts/routes.md](./contracts/routes.md), 근거는 [research.md](./research.md).

## 준비

001 [quickstart](../001-blog-core/quickstart.md)의 "준비", 002~005 quickstart의 추가 준비대로 MySQL(또는 Crowfoot 개발 DB `cf_u2_d2`), Mailpit, backend, front를 띄운다. 006에서 더할 것:

```bash
# 1) 대시보드 수치를 바로 확인하려면 캐시를 끈다(기본 5분, FR-103). #12 확인 때는 이 값을 빼고 다시 띄운다.
export BLOG_ADMIN_DASHBOARD_CACHE_TTL=0s

# 2) 첫 최고 관리자(003): 가입한 회원 M의 이메일을 주고 backend를 다시 띄우면 SUPER_ADMIN이 된다(이미 있으면 아무것도 안 함).
export BLOG_ADMIN_BOOTSTRAP_SUPER_ADMIN_EMAIL=m@example.test

# 3) 계정 준비: A(handle marco, 블로그 2개: marco·marco2), B(handle reader), C(handle third)를 /signup으로,
#    M(SUPER_ADMIN, 위 2번)을 만든다. A는 marco에 임시저장 글 "찾을 글"과 공개 글 몇 편, 댓글을 둔다.
```

## 자동 검증

```bash
cd blog/blog-backend && ./mvnw verify          # 슬라이스·H2 테스트 + 행렬 테스트(SC-015·SC-017·AS5) + JaCoCo 80%
#   글 제목 FULLTEXT 검색 시험은 BLOG_TEST_DATASOURCE_URL(테스트 MySQL 스키마)이 있을 때만 돈다(002 방식, Testcontainers 없음)
cd blog/blog-front && npm test -- --coverage   # Vitest 80%, 번역 누락 점검(audit namespace 포함)
# E2E: backend를 CI와 같은 값으로 띄운 뒤(결정 표 25번)
cd blog/blog-front && E2E_BACKEND_URL=http://localhost:8080 E2E_ADMIN_EMAIL=... E2E_ADMIN_PASSWORD=... \
  E2E_PORTAL_TEST_SETTINGS=1 E2E_GUEST_TEST_SETTINGS=1 E2E_ADMIN_TEST_SETTINGS=1 npm run e2e
```

## 수동 검증 시나리오

| # | 스토리 | 절차 | 기대 결과 |
|---|---|---|---|
| 1 | US1 | A로 로그인 → 상단 "내 블로그 관리" | 최근에 관리하거나 글을 쓴 블로그(`last_blog`)의 `/{handle}/manage` 대시보드. 쿠키를 지우고 다시 누르면 블로그 선택(`/settings/blogs`) (AS1) |
| 2 | US1 | `/marco/manage` 대시보드 | 오늘·어제 방문자, 최근 7일 새 댓글·방명록 수와 최근 5건, 최근 글 5편, 임시저장 글 수 (AS2, FR-100) |
| 3 | US1 | 좌측 메뉴 | FR-099 순서(대시보드, 글, 카테고리, 댓글, 방명록, 블로그 설정, 꾸미기, 피드 설정, 통계, 백업, 차단 목록). 005 전에는 "받은 트랙백", 007 전에는 "외부 블로그"가 없음 (FR-099) |
| 4 | US1 | 대시보드에서 시작해 "글 관리" → 상태 "임시저장" → 제목 "찾을" 검색 → 결과의 "찾을 글" → 작성 화면 | 30초 안에 작성 화면 (Independent Test, AS3, SC-016) |
| 5 | US1 | 글 관리에서 공개 글 2편 선택 → "비공개로", "카테고리 이동", "삭제(휴지통)" → 상태 "휴지통"에서 복구 | 한 번에 바뀌고 휴지통에서 복구됨 (AS3, FR-101) |
| 6 | US1 | 카테고리 추가, 블로그 설정에서 제목 변경 → `/marco` | 블로그 홈 제목·카테고리에 반영 (Independent Test) |
| 7 | US1 | 상단 블로그 전환에서 marco2 선택(글 관리 화면에서) | `/marco2/manage/posts`로 이동, marco2의 글만 보임 (AS6) |
| 8 | US1 | B로 `/marco/manage`, `/marco/manage/posts`; `curl -b B쿠키 /api/v1/blogs/marco/manage/dashboard` | 화면 404, API 403 `FORBIDDEN` (AS5, FR-097) |
| 9 | US1 | `curl -I http://localhost:5173/marco/manage` (A 쿠키), `curl http://localhost:5173/robots.txt` | `X-Robots-Tag: noindex, nofollow`, HTML에 `<meta name="robots" content="noindex">`, robots.txt에 `Disallow: /*/manage/` (FR-098) |
| 10 | US2 | M으로 로그인 → 상단 | "내 블로그 관리"와 "시스템 관리"가 둘 다 보임. A에게는 "시스템 관리"가 없음 (FR-096, Edge Cases) |
| 11 | US2 | M이 "시스템 관리" | `/admin` 대시보드: 오늘 가입자·발행 글·댓글, 전체 회원·블로그·공개 글, 최근 7일 가입·발행 막대, "기준 시각·시간대". 005 이후에는 처리 대기 신고 카드 (AS1, AS3, FR-103) |
| 12 | US2 | 캐시 설정을 빼고(기본 5분) 다시 띄움 → 대시보드 → 새 회원 가입 → 대시보드 새로 고침 → 5분 뒤 새로 고침 | 처음에는 그대로, 5분 안에 반영 (FR-103 "최대 5분 지연") |
| 13 | US2 | A로 `/admin`, `/admin/release-notes`; 비로그인으로 `/admin`; `curl -b A쿠키 /api/v1/admin/dashboard` | A는 404 화면(관리 화면 존재를 드러내지 않음), 비로그인은 로그인 화면, API는 404 `NOT_FOUND` (AS2, SC-015) |
| 14 | US2 | M이 주제 관리에서 소분류 "시험 소분류" 추가 → A가 글쓰기 발행 설정의 주제 선택 | 새 소분류가 바로 보임(003 기능, 006 Independent Test) (AS4) |
| 15 | US2 | 콘솔 좌측 메뉴 | FR-102 순서. 005 전에는 회원·신고·스팸, 007 전에는 외부 블로그 메뉴가 없음 (FR-102) |
| 16 | US2 | 콘텐츠 관리 — 글에서 블로그 `marco`, 제목 "찾을" 검색 | A의 글만, 제목·상태·공개 범위·작성자. 본문은 어디에도 없음(비공개 글 포함) (FR-104) |
| 17 | US2 | 콘텐츠 관리 — 댓글에서 범위 없이 "안녕" 검색 / 블로그 `marco`로 범위를 주고 "안녕" 검색 | 범위 없음은 "블로그·글·작성자 중 하나를 먼저 정하세요" 안내, 범위가 있으면 결과. 비밀 댓글은 "비밀 댓글"로만 보임 (결정 표 8·9번) |
| 18 | US2 | (005 머지 후) 콘텐츠 관리 — 글에서 A의 공개 글 "숨김" → 비로그인으로 글 주소 → 콘솔에서 "숨김 해제" | 숨김 동안 404, 해제 후 다시 보임. `/admin/contents/hidden-posts`는 `?status=HIDDEN` 목록으로 이동 (005 FR-041) |
| 19 | US2 | 예약어 메뉴, 서비스 설정 메뉴 | 예약어 목록(admin, manage, updates …, 정렬), 약관 버전·첨부 파일 한도·회원당 기본 블로그 수(3)·작업 기록 보관 365일과 프로퍼티 이름. 바꾸는 입력은 없음 (FR-102, FR-160) |
| 20 | US2 | (005 머지 후) 회원 관리에서 이메일 전체 주소로 A 검색 → 상세 → 블로그 한도 5 → 상세 | "블로그 2 / 한도 5", 작업 기록에 변경 전후 (AS5, AS6, FR-160) |
| 21 | US3 | M이 주제 "시험 소분류" 숨김, A의 블로그 한도를 4로 변경 → 작업 기록 메뉴 | 2건(작업 이름·대상·M·시각), 펼치면 변경 전후 값(`adminHidden: false → true`, `maxBlogs: 5 → 4`). 005 이후에는 회원 정지도 같은 방식 (Independent Test, AS1) |
| 22 | US3 | 작업 기록을 기간·관리자·작업 종류("주제")로 거름 | 해당 기록만 (AS2) |
| 23 | US3 | `curl -X DELETE`·`PATCH`·`PUT /api/v1/admin/audit-logs/{id}` (M 쿠키) | 모두 405 `METHOD_NOT_ALLOWED`(매핑 없음) — 기록은 수정·삭제할 수 없음 (AS2, FR-106) |
| 24 | US3 | M이 `/admin/admins`에서 "회원 번호로 관리자 지정"에 B의 번호, 권한 ADMIN → B로 새로 고침 | B 상단에 "시스템 관리", `/admin` 열림. 작업 기록에 `ROLE_GRANT` (AS3) |
| 25 | US3 | B(ADMIN)가 `/admin/admins` → `curl -X PUT -b B쿠키 /api/v1/admin/users/{C}/role -d '{"role":"ADMIN"}'` | 화면은 읽기 전용, API 403 `FORBIDDEN` (FR-105 "최고 관리자만") |
| 26 | US3 | B가 콘솔을 연 채로 M이 B를 USER로 → B가 콘솔에서 다른 메뉴 클릭 | 404 화면, 상단 "시스템 관리" 사라짐. 작업 기록에 `ROLE_REVOKE` (AS3, Edge Cases) |
| 27 | US3 | M이 자기 권한을 USER로 | 422 "자기 권한은 바꿀 수 없습니다". 최고 관리자가 M뿐일 때 다른 최고 관리자가 있다고 가정한 강등은 단위 시험으로 확인(마지막 최고 관리자 409) (Edge Cases) |
| 28 | US3 | M이 작업 기록 하나를 열고 "요청 IP 보기" / B(ADMIN)로 같은 기록 | M은 IP가 보이고 B는 "최고 관리자만 볼 수 있습니다" |
| 29 | US3 | DB에서 기록 하나의 `created_at`을 2년 전으로 → 정리 작업 실행(`BLOG_JOBS_AUDIT_PURGE_CRON`을 1분 뒤로) | 그 행만 지워지고 나머지는 남음 (FR-106 "1년 보관") |
| 30 | US4 | M이 "릴리스 노트" → "새 노트": 버전 `1.2.0`, 날짜, 한국어판 제목·본문 → "미리보기" → "초안 저장" | 미리보기가 `/updates`와 같은 모양(제목 앵커·목차). 초안 저장, 목록에 "초안" (AS1) |
| 31 | US4 | 비로그인으로 `/updates/v1.2.0` | 404 (Independent Test, AS1) |
| 32 | US4 | 버전 `1.2`·`01.2.0`, 이미 있는 버전, 한국어판 비우기로 저장 | 각각 형식 오류·"이미 있는 버전"·"한국어판은 필수" 필드 문구, 저장 안 됨 (AS2) |
| 33 | US4 | 영어판 넣어 저장 → "게시" → `/updates/v1.2.0`, `/`(포털 카드), A로 로그인(상단 배너) | 게시됨, 세 곳에 보임 (AS3) |
| 34 | US4 | 본문을 고쳐 저장 → `/updates/v1.2.0/history` → 콘솔 "수정본" | 독자에게 바로 반영, 독자 수정 이력에 게시 뒤 수정본, 콘솔 수정본 목록 3건(만들기·영어판 추가·게시 후 수정, 관리자·시각·당시 상태). 버전 입력은 읽기 전용 (Independent Test, AS4) |
| 35 | US4 | 브라우저 창 두 개로 같은 노트를 열고 한쪽 저장 → 다른 쪽 저장 | 나중 저장은 입력이 남은 채 "다른 관리자가 먼저 저장했습니다" + "최신 내용 열기" (AS5, FR-168) |
| 36 | US4 | "게시 중단" → `/updates/v1.2.0`; 삭제 버튼 확인; 새 초안 `1.2.1`을 만들고 삭제 | 독자 404, 게시했던 노트에는 삭제 버튼 없음, 한 번도 게시하지 않은 초안은 삭제됨 (Edge Cases) |
| 37 | US4 | 작업 기록에서 대상 "릴리스 노트" | 만들기·수정·게시·게시 중단·삭제가 버전과 함께 (AS6) |
| 38 | US4 | 수정본 2 보기 → "이 내용으로 편집기 채우기" → 저장 | 수정본 2 내용으로 새 수정본이 생김(되돌리기) |
| 39 | 공통 | 폭 360px로 `/marco/manage`, `/marco/manage/posts`, `/admin`, `/admin/audit-log` | 블로그 관리는 가로 스크롤 없이 모든 기능, 콘솔은 조회가 가능(표는 가로 스크롤 상자 안) (spec Assumptions) |
| 40 | 공통 | 화면 언어를 en·ja·zh-CN으로 바꿔 #3, #11, #21, #30 화면 | 메뉴·카드·작업 종류 이름·편집기 문구가 그 언어(예약어·설정 키·변경 전후 JSON은 원문) |
| 41 | 공통 | JS를 끄고 #5, #24, #30(미리보기 포함), #33 | 모두 폼 제출로 동작 (원칙 V) |
