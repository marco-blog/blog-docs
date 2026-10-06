# Quickstart: 002 구독과 탐색 검증 가이드

구현이 끝난 뒤 이 순서로 실행해 스펙이 동작함을 확인한다. 세부 API는 [contracts/api.md](./contracts/api.md), 화면은 [contracts/routes.md](./contracts/routes.md), 근거는 [research.md](./research.md).

## 준비

001 [quickstart](../001-blog-core/quickstart.md)의 "준비"대로 MySQL(또는 Crowfoot 개발 DB `cf_u2_d2`), Mailpit, backend, front를 띄운다. 002에서 더할 것:

```bash
# 1) FULLTEXT ngram 설정 확인(검색 D4). 2가 아니면 검색 결과가 달라진다.
mysql -e "SHOW VARIABLES LIKE 'ngram_token_size'"      # Value = 2

# 2) 카카오톡 공유(선택, D9): Kakao Developers에 사이트 도메인(로컬은 http://localhost:5173)을 등록한 JavaScript 키
#    키는 공개 값이지만 저장소에 커밋하지 않고 blog-front/.env에만 둔다.
echo "BLOG_KAKAO_JS_KEY=<JavaScript 키>" >> blog/blog-front/.env

# 3) 계정 준비: /signup 으로 A(handle marco), B(handle reader), C(handle third) 세 회원을 만든다.
```

피드·사이트맵은 front 주소(`http://localhost:5173`)로 요청해 프록시까지 함께 확인한다. backend `blog.base-url`과 front `BLOG_PUBLIC_URL`은 같은 값(로컬 `http://localhost:5173`)이어야 피드·사이트맵의 절대 주소가 맞다.

## 자동 검증

```bash
cd blog/blog-backend && ./mvnw verify          # 슬라이스·H2 테스트 + JaCoCo 80%
# FULLTEXT 검색·동시성 테스트(@MySqlRepositoryTest)는 BLOG_TEST_DATASOURCE_* 가 있을 때만 돈다(테스트 스키마 cf_u2_d3)
cd blog/blog-front && npm test -- --coverage   # Vitest 80%, 번역 누락 점검 포함
cd blog/blog-front && E2E_BACKEND_URL=http://localhost:8080 npm run e2e   # 아래 시나리오 중 E2E로 자동화한 것
```

## 수동 검증 시나리오

| # | 스토리 | 절차 | 기대 결과 |
|---|---|---|---|
| 1 | US1 | B로 로그인 → A의 공개 글 `/marco/{id}`에서 좋아요 → 새로 고침 → 다시 좋아요(취소) | 좋아요 수 1 → 새로 고침 후에도 1이고 버튼이 "눌림" → 취소 후 0 (AS1) |
| 2 | US1 | B로 `PUT /api/v1/me/likes/{id}`를 동시에 20번(`xargs -P 20 curl ...`) → `DELETE`를 동시에 20번 | 응답은 모두 200 `liked: true`·`likeCount: 1`, `post_likes` 행 1개 → 모두 200 `liked: false`, `like_count` 0 (D1) |
| 3 | US1 | 비로그인으로 글 상세 → 좋아요 버튼 / `curl -X PUT .../me/likes/{id}` | 버튼 대신 로그인 링크(`/login?next=/marco/{id}`) / 401 `UNAUTHENTICATED` |
| 4 | US1 | B로 A의 비공개 글 id에 `PUT /api/v1/me/likes/{id}` | 404 `POST_NOT_FOUND` |
| 5 | US1 | B로 `/marco`에서 "구독" → 구독자 수 확인 → A로 `/marco` 열기 | 구독자 수 0 → 1, 버튼이 "구독 중" (AS2). A 화면에는 구독 버튼이 없음 (AS3) |
| 6 | US1 | A가 자기 두 번째 블로그(`marco-dev`)를 `PUT /api/v1/me/subscriptions/marco-dev`로 구독 시도 | 422 `CANNOT_SUBSCRIBE_OWN_BLOG` (FR-031) |
| 7 | US1 | B가 `marco`와 `third`를 구독 → A·C가 각각 새 공개 글 발행, A는 비공개 글도 하나 발행 → B로 `/feed` | 두 블로그의 공개 글이 최신순(가장 늦게 발행한 글이 맨 위), 비공개 글은 없음 (AS4, Independent Test) |
| 8 | US1 | 관리자가 C를 정지(006 콘솔 전에는 `UPDATE users SET status='SUSPENDED' WHERE ...`) → B로 `/feed` | C의 글이 피드에서 빠짐 (Edge Cases) |
| 9 | US1 | B가 탈퇴(`/settings/profile`) → A로 `/marco` | 구독자 수가 1 줄어듦 (결정 3) |
| 10 | US1 알림 | C로 A의 글에 댓글 → A로 로그인 | 상단 알림 배지 1, `/notifications`에 "C님이 「글 제목」에 댓글을 남겼습니다"(화면 언어), 누르면 `/marco/{id}#comment-{cid}`로 이동하고 읽음 처리, 배지 0 (FR-033) |
| 11 | US1 알림 | A가 자기 글에 댓글·답글 | A에게 알림이 생기지 않음 |
| 12 | US1 알림 | B가 `marco` 구독 → 취소 → 다시 구독(24시간 안) | A의 NEW_SUBSCRIBER 알림은 1건뿐 (결정 6) |
| 13 | US1 알림 | A의 화면 언어를 en·ja·zh-CN으로 바꿔 `/notifications` 확인 | 알림 문구가 각 언어로, 글 제목은 원문 그대로 |
| 14 | US1 알림 | 알림 3건을 만든 뒤 "모두 읽음" | 3건 모두 읽음, 배지 사라짐. `notifications.created_at`을 91일 전으로 바꾸고 정리 작업 실행 시 삭제 |
| 15 | US2 | 공개 글 3편(제목·본문·태그에 "스프링"을 각각 한 곳씩)과 비공개 글 1편(제목에 "스프링") 발행 → 비로그인으로 상단 검색창에 "스프링" | 공개 글 3편만 최신순, 비공개 글 없음 (AS1, AS2, Independent Test) |
| 16 | US2 | 검색어 "스"(1자), 101자, "스프링 부트"(두 낱말) | 1자·101자는 입력란 오류 문구(`TOO_SHORT`·`TOO_LONG`), 두 낱말은 둘 다 포함한 글만 |
| 17 | US2 | 글을 휴지통으로 이동, 작성자 정지, 블로그 삭제 각각 후 같은 검색 | 해당 글이 검색 결과에서 빠짐 (AS2, SC-004) |
| 18 | US2 | `curl -s http://localhost:5173/marco/{id}` (스크립트 실행 없이) | HTML에 제목·본문·`<meta name="description">`·`og:title`·RSS/Atom `<link rel="alternate">` 포함 (AS3) |
| 19 | US2 | `curl -s http://localhost:5173/robots.txt`, `/sitemap.xml`, `/sitemap/pages.xml`, `/sitemap/posts-1.xml` | robots에 `Sitemap:` 줄과 `/settings` 등 차단 규칙, 색인이 pages·posts 파일을 가리킴, posts에 공개 글 주소만(비공개·임시저장·삭제 글 없음), 모든 주소가 절대 주소 (FR-037) |
| 20 | US2 | 검색 성능: 글 10만 편 데이터에서 자주 쓰는 낱말·드문 낱말 각각 50회(`hey`·`k6` 등, 도구는 저장소에 추가하지 않음) | p95 2초 이내 (SC-007). 결과를 PR 설명에 기록 |
| 21 | 관련 글 | 같은 블로그에 태그 `java`·`jpa` 글 X, `java` 글 Y, `jpa`·`java` 글 Z, 같은 카테고리만 같은 글 W, 아무것도 안 겹치는 글 V → X 상세 | 관련 글이 Z, Y·W 순(점수 2, 1, 1 — 같은 점수는 최신순), V와 X 자신은 없음, 비공개 글 없음 (FR-068) |
| 22 | 공유 | 글 상세의 공유: 주소 복사, X, 페이스북, 카카오톡(키 설정 시) → 각 공유 미리보기 | 클립보드에 글 주소, X·페이스북 공유 창에 제목·주소, 카카오톡 공유 창에 제목·요약·대표 이미지 (FR-069). 키가 없으면 카카오톡 버튼 없음. 브라우저 콘솔에 CSP 위반 없음 |
| 23 | 공유 | `curl -s` 글 상세(대표 이미지 있는 글·없는 글) | `og:title`·`og:description`·`og:url`, 이미지 있으면 `og:image`(1200x630)와 `twitter:card=summary_large_image`, 없으면 `twitter:card=summary` |
| 24 | US3 | `marco`에 공개 글 3편, 비공개 글 1편, 임시저장 1편 → `curl -s http://localhost:5173/marco/rss`, `/marco/atom` | 공개 글 3편만 최신순, 각 글에 본문 HTML(이미지 주소는 절대 주소) (AS1, AS5, Independent Test) |
| 25 | US3 | `/marco/manage/feed`에서 "요약", 글 수 10 저장 → 다시 피드 요청 | 각 항목이 본문 대신 요약만, 최대 10개 (AS2, FR-046) |
| 26 | US3 | 카테고리 "Spring"(하위 "Boot") 글 2편 + 다른 카테고리 글 1편 → `/marco/category/{Spring id}/rss` | Spring·Boot 글만 (AS3) |
| 27 | US3 | `curl -si /marco/rss` → 받은 `ETag`로 `curl -si -H 'If-None-Match: <ETag>' /marco/rss` → 글 하나를 비공개로 바꾼 뒤 다시 같은 요청 | 두 번째는 304(본문 없음), 세 번째는 200이고 그 글이 빠짐 (Edge Cases, SC-004) |
| 28 | US3 | `/marco`, `/marco/{id}`, `/marco/category/{id}`의 HTML `<head>` | `application/rss+xml`·`application/atom+xml` `<link rel="alternate">`(절대 주소), 카테고리 화면은 카테고리 RSS가 먼저 (AS4) |
| 29 | US3 | `/marco/rss`·`/marco/atom`·카테고리 RSS의 XML을 W3C Feed Validation Service(https://validator.w3.org/feed/ "Validate by Direct Input")에 붙여 넣기. 운영 배포 후에는 주소로 검증 | 오류 0건(경고는 기록) (SC-008, FR-048) |
| 30 | US3 | Feedly 또는 Inoreader에 `https://blog.java21.net/marco`(운영) 입력 | 리더가 자동 발견으로 피드를 찾아 새 글을 받음 (AS4) |
| 31 | US3 | 없는 handle·삭제된 블로그·정지 회원 블로그의 `/x/rss`, 다른 블로그 카테고리 id의 카테고리 RSS | 각각 404 |
| 32 | 공통 | 4개 언어로 `/search`, `/feed`, `/notifications`, `/marco/manage/feed`, 글 상세 공유·관련 글 영역 확인, `npm test`의 번역 누락 테스트 | 모든 문구가 화면 언어, 키 노출 없음, 누락 0건 |
