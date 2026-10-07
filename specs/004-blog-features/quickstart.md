# Quickstart: 004 블로그 꾸미기와 글 옵션 검증 가이드

구현이 끝난 뒤 이 순서로 실행해 스펙이 동작함을 확인한다. 세부 API는 [contracts/api.md](./contracts/api.md), 화면은 [contracts/routes.md](./contracts/routes.md), 근거는 [research.md](./research.md).

## 준비

001 [quickstart](../001-blog-core/quickstart.md)의 "준비", 002·003 [quickstart](../003-portal/quickstart.md)의 추가 준비대로 MySQL(또는 Crowfoot 개발 DB `cf_u2_d2`), Mailpit, backend, front를 띄운다. 004에서 더할 것:

```bash
# 1) 백업 파일 디렉터리(로컬 기본값은 ./data/exports). 다른 곳을 쓰려면:
export BLOG_EXPORT_DIR=/tmp/blog-exports

# 2) 수동 검증용(로컬만). 비회원 쓰기 속도 제한(IP당 댓글 1분 5개, 방명록 1분 3개)이 반복 시험을 막지 않게 늘린다.
#    #24의 속도 제한 확인 때는 이 값을 빼고 다시 띄운다.
export BLOG_GUEST_COMMENT_PER_MINUTE=1000
export BLOG_GUEST_GUESTBOOK_PER_MINUTE=1000

# 3) 계정 준비: /signup 으로 A(handle marco), B(handle reader), C(handle third) 세 회원을 만든다.
#    비회원 시나리오는 로그아웃한 다른 브라우저(또는 시크릿 창)로 한다.
```

## 자동 검증

```bash
cd blog/blog-backend && ./mvnw verify          # 슬라이스·H2 테스트 + JaCoCo 80%
# 블로그 내 검색(FULLTEXT)·방문 동시 upsert 테스트(@MySqlRepositoryTest)는 BLOG_TEST_DATASOURCE_* 가 있을 때만 돈다(테스트 스키마 cf_u2_d3)
cd blog/blog-front && npm test -- --coverage   # Vitest 80%, 번역 누락 점검 포함
# E2E: backend를 위 2)의 값으로 띄운 뒤
cd blog/blog-front && E2E_BACKEND_URL=http://localhost:8080 E2E_GUEST_TEST_SETTINGS=1 npm run e2e
```

## 수동 검증 시나리오

| # | 스토리 | 절차 | 기대 결과 |
|---|---|---|---|
| 1 | US1 | B로 `/marco/guestbook`에 "안녕하세요" 남김 → A로 같은 화면에서 답글 "반가워요" | 방명록 맨 위에 B의 글, 그 아래 A의 답글이 들여쓰기로 (Independent Test, AS1, AS3) |
| 2 | US1 | B가 "비밀글"을 골라 하나 더 남김 → C로, 비로그인으로, A로, B로 각각 `/marco/guestbook` | C·비로그인: "비밀글입니다"만 / A·B: 내용이 보임 (AS2, FR-057) |
| 3 | US1 | A가 B의 첫 글(답글 있음)과 두 번째 글(답글 없음) 삭제 | 첫 글은 "삭제된 글입니다" 자리와 답글이 남고, 두 번째 글은 사라짐 (AS3, FR-058) |
| 4 | US1 | C가 B의 글 삭제 시도(`curl -X DELETE -b <C 쿠키> /api/v1/guestbook-entries/{id}`), C가 `parentId`로 답글 시도 | 403 `FORBIDDEN` 둘 다 |
| 5 | US1 | A가 블로그 설정에서 "방명록 사용"을 끔 → 비로그인으로 `/marco`, `/marco/guestbook`, `curl /api/v1/blogs/marco/guestbook` | 블로그 메뉴에 방명록이 없음, 화면 404, API 404 `GUESTBOOK_DISABLED`. A는 `/marco/manage/guestbook`에서 기존 글을 봄 (AS4) |
| 6 | US1 | 방명록을 다시 켜고, A가 "비회원 댓글·방명록 허용"을 켬 → 비로그인으로 이름 "손님"·비밀번호 "1234"로 방명록 작성 → 같은 비밀번호로 수정, 틀린 비밀번호로 삭제 | 글에 "비회원" 표시, 수정됨, 틀린 비밀번호는 오류 문구(403 `GUEST_PASSWORD_MISMATCH`) (FR-066) |
| 7 | US1 | A의 대시보드 `/marco/manage` | 최근 7일 새 방명록 수와 최근 글 (006 FR-100) |
| 8 | US2 | A가 글 하나를 발행 설정에서 "공지로 등록"해 발행 → 비로그인 `/marco`, `/marco/notice` | 홈 목록 위 공지 영역에만 있고 아래 일반 목록에는 없음, 공지 목록 화면에 있음 (Independent Test, AS1, FR-059) |
| 9 | US2 | 같은 공지 글의 카테고리 화면 `/marco/category/{id}`, `/marco/rss` | 일반 글처럼 나옴(공지는 블로그 홈 목록에서만 따로) |
| 10 | US2 | A가 `/marco/manage/design`에서 VISITORS 켜기, ARCHIVE를 맨 위로, CATEGORIES 끄기 → 저장 → 비로그인 `/marco`, `/marco/{글 번호}` | 두 화면 모두 사이드바가 보관함 → … 순서, 카테고리 없음, 방문자 수 있음 (AS2, FR-060) |
| 11 | US2 | A가 2026년 9월·10월에 걸쳐 발행한 글(DB에서 `published_at`을 9월로 바꾼 글 하나 포함)로 사이드바 보관함의 "2026년 9월" 클릭 | `/marco/archive/2026/9`에 9월 공개 글만, 비공개 글 없음 (AS3, FR-061) |
| 12 | US2 | 한국 시간 10월 1일 00:30(UTC 9월 30일 15:30)에 발행된 글 | 보관함에서 10월로 셈 (`blog.stats.time-zone` 기준) |
| 13 | US2 | 비로그인 브라우저 2개(서로 다른 방문자 쿠키)로 `/marco`를 각각 3번씩 → A로 `/marco` → A의 `/marco/manage/stats` | 오늘 2, 전체 2(주인 본인은 세지 않음), 30일 표의 오늘 칸 2 (AS4, FR-067, Edge Cases) |
| 14 | US2 | `curl -A "Googlebot" http://localhost:5173/marco` 후 통계 | 수가 늘지 않음 |
| 15 | US2 | `/marco/search?q=spring`(블로그 안), `/search?q=spring`(전체) | 블로그 검색은 marco 글만 (FR-061) |
| 16 | US2 | `/marco/tags` | 태그가 이름순, 글이 많은 태그가 더 크게 (FR-061) |
| 17 | US3 | A가 비밀번호 "secret1"로 보호 글 발행 → C로 `/marco/{id}` | 제목·작성자·비밀번호 입력란만, 본문·댓글 없음 (Independent Test, AS1) |
| 18 | US3 | C가 "secret1" 입력 → 새로고침 → 31분 뒤 새로고침 | 본문·댓글이 보이고 새로고침해도 유지, 30분이 지나면 다시 잠김 (AS1, research B4) |
| 19 | US3 | 비로그인으로 `/marco`, `/marco/rss`, `/search?q=<보호 글 제목>`, `/sitemap/posts-1.xml`, `/` | 블로그 목록·검색은 제목만(요약·이미지 없음), RSS는 제목·링크만, 사이트맵·포털에는 없음 (AS2, FR-062) |
| 20 | US3 | `curl -s http://localhost:5173/marco/{보호 글 id}` | HTML에 본문 없음, `noindex`, description 없음 |
| 21 | US3 | 다른 브라우저로 틀린 비밀번호 5번 → 6번째에 맞는 비밀번호 | 6번째도 "잠시 후 다시" 안내(429 `PASSWORD_ATTEMPTS_EXCEEDED`), 10분 뒤 맞는 비밀번호로 열림 (FR-063, Edge Cases) |
| 22 | US3 | A가 글을 지금부터 3분 뒤로 예약 발행 → 바로 비로그인으로 그 주소와 `/marco`, `/marco/rss` → 4분 뒤 다시 | 처음엔 404·목록에 없음 / 예약 시각 후 1분 안에 목록·피드에 나오고 `publishedAt`이 실제 발행 시각 (Independent Test, AS3, SC-010) |
| 23 | US3 | A가 지난 시각(1시간 전)으로 예약 → 다른 글을 예약 후 `/marco/manage/posts?status=SCHEDULED`에서 "예약 취소" | 첫 글은 바로 발행 / 둘째 글은 임시저장으로 돌아옴 (Edge Cases, research B5) |
| 24 | US3 | 예약 글을 휴지통으로 옮긴 뒤 예약 시각이 지나고 복구 | 복구 직후 예약 상태로 돌아오고 다음 주기(30초 안)에 발행 |
| 25 | US3 | B가 A의 공개 글에 "비밀 댓글"로 댓글 → C, 비로그인, A, B로 각각 보기 | C·비로그인은 "비밀 댓글입니다", A·B는 내용 (AS4, FR-065) |
| 26 | US3 | A가 비회원 허용을 켠 상태에서 비로그인으로 이름·비밀번호·내용으로 댓글 → 같은 비밀번호로 수정 → 틀린 비밀번호로 삭제 → 맞는 비밀번호로 삭제 | 등록·"비회원" 표시, 수정됨, 틀리면 거부, 맞으면 삭제. A에게 새 댓글 알림(비회원 이름) (AS5, FR-066) |
| 27 | US3 | A가 비회원 허용을 끔 → 비로그인으로 댓글 폼 | 폼 대신 로그인 안내(API는 401 `UNAUTHENTICATED`) (AS6) |
| 28 | US3 | 위 2)의 속도 제한 값을 빼고 재기동 → 비로그인으로 1분 안에 댓글 6개 | 6번째 429 `TOO_MANY_REQUESTS`와 `Retry-After` (research B6) |
| 29 | US3 | DB에서 비회원 댓글·방명록의 `guest_password_hash`, `guest_ip_enc`, 보호 글 `password_hash` 확인 | BCrypt 해시와 암호문만, 평문 없음 (FR-062, FR-066, 001 FR-134) |
| 30 | US3 | 비회원 댓글의 `created_at`을 91일 전으로 바꾸고 개인정보 파기 작업 실행(`blog.jobs.privacy-purge-cron`을 1분 뒤로 두고 재기동) | `guest_ip_enc`가 NULL, 댓글은 그대로 |
| 31 | US4 | A가 `/marco/manage/backup`에서 "백업 만들기" → 1분 이내 새로고침 | 상태가 대기 → 완료, 알림 목록에 "백업이 준비되었습니다" (Independent Test(plan), FR-145) |
| 32 | US4 | 내려받은 zip 풀기 | `blog.json`(카테고리 트리), 임시저장·비공개·보호·예약 글을 포함한 `posts/*.md`(front matter + 원문), 글에 쓴 원본 이미지 `images/*`, `media.json`. 휴지통 글·보호 글 비밀번호 없음 |
| 33 | US4 | 바로 "백업 만들기"를 한 번 더 | "하루에 한 번" 안내(409 `EXPORT_LIMIT_EXCEEDED`) |
| 34 | US4 | DB에서 그 백업의 `expires_at`을 지난 시각으로 바꾸고 정리 작업 시각을 기다림(또는 cron을 가깝게 두고 재기동) → 내려받기 링크 | 파일이 지워지고 상태 만료, 링크는 404 `EXPORT_NOT_FOUND` |
| 35 | US4 | B가 `curl -b <B 쿠키> /api/v1/blogs/marco/exports` | 403 `FORBIDDEN` |
| 36 | US5 | B가 A의 블로그를 구독 → A가 `/marco/manage/comments`에서 B의 댓글 옆 "차단" → `/marco/manage/blocks` | 차단 목록에 B, A 블로그 구독자 수가 1 줄고 B의 구독 목록에서 빠짐 (Independent Test(plan), FR-146) |
| 37 | US5 | B로 A의 글에 댓글, A의 방명록에 글, A의 블로그 구독 시도 | 모두 일반 거부 문구(403 `FORBIDDEN`), B에게 차단 알림 없음. B는 A의 글을 계속 읽을 수 있음 |
| 38 | US5 | A가 차단 해제 → B가 다시 댓글 | 등록됨 |
| 39 | US5 | A가 자기 자신 차단 시도(`curl -X PUT .../blocks/{A의 userId}`) | 422 `CANNOT_BLOCK_SELF` |
| 40 | 공통 | A가 두 번째 블로그(handle marco2)를 만들어 방명록·사이드바·방문자·차단을 따로 설정 | 블로그마다 따로 동작(spec Assumptions) |
| 41 | 공통 | A가 marco2를 삭제하고 DB에서 `deleted_at`을 31일 전으로 바꾼 뒤 휴지통 비우기 작업 실행 | marco2의 방명록·사이드바·방문·차단·백업 행과 백업 파일이 지워지고 `blogs` 행은 남음 (001 FR-159) |
| 42 | 공통 | 4개 언어로 방명록, 공지, 보관함, 블로그 검색, 태그 목록, 사이드바, 보호 글 잠금 화면, 발행 설정(보호·예약·공지), 댓글 폼(비밀·비회원), 관리 5개 화면 확인, `npm test`의 번역 누락 테스트 | 모든 문구가 화면 언어, 사용자가 쓴 글·이름은 그대로, 키 노출 없음, 누락 0건 |
| 43 | 공통 | 폭 360px 브라우저로 블로그 홈(사이드바), 방명록, 관리 꾸미기 | 사이드바가 본문 아래로, 가로 스크롤 없음 |
