# Route Contract: 002 구독과 탐색 (front)

002 화면의 loader·action·meta를 정한다. 경로 이름과 예약어의 기준 목록은 [001 contracts/routes.md](../../001-blog-core/contracts/routes.md)이며, 002의 경로(`/search`, `/feed`, `/notifications`, `/sitemap.xml`, `/robots.txt`, `/:handle/rss`, `/:handle/atom`, `/:handle/category/:categoryId/rss`, `/:handle/manage/feed`)는 이미 그 목록과 예약어에 있다. 이 스펙은 예약어를 바꾸지 않는다. API 경로는 `/api/v1` 접두어를 뺀 것이다([api.md](./api.md)).

## 새 화면

| 경로 | 화면 | 렌더링 | loader 호출 API | action | meta |
|---|---|---|---|---|---|
| `/search?q=&page=` | 서비스 전체 검색. 검색창, 결과(제목·요약·블로그 이름·발행일), 페이지 이동. `q`가 비면 검색창만, 검증 오류는 입력란 문구 | SSR | /search/posts?q=&page= | - | `"{q}" 검색 - 서비스명`, noindex |
| `/feed?page=` | 구독 피드(로그인). 구독한 블로그들의 글 최신순, 빈 상태 안내 | SSR | /me/feed?page= | - | noindex |
| `/notifications?page=` | 알림 목록(로그인). 종류별 문구(`notification:types.{TYPE}`), 안 읽은 표시, "모두 읽음" | SSR | /me/notifications?page= | `intent=read`(id, 읽음 처리 후 대상 화면으로 리다이렉트), `intent=read-all` | noindex |
| `/:handle/manage/feed` | 블로그 관리 "피드 설정"(글 수 10·20·30·50, 전문·요약), 이 블로그의 RSS·Atom·카테고리 피드 주소 안내 | SSR(폼은 `action`) | /blogs/{handle} | PATCH /blogs/{handle} `{ feedItemCount, feedContentMode }` | noindex |

- `/feed`, `/notifications`, `/:handle/manage/feed`는 비로그인이면 `/login?next=...`로, 남의 블로그 관리 화면이면 404(001 규칙).
- 블로그 관리 좌측 메뉴(001 `manage/layout.tsx`)에 "피드 설정"을 더한다(006 FR-099).

## 001 화면 변경

| 경로 | 변경 | 추가 API | meta 추가 |
|---|---|---|---|
| 모든 화면(공통 상단) | 검색창(`GET /search`), 로그인 회원에게 "구독 피드"(`/feed`)와 알림(`/notifications`, 안 읽은 수 배지 `unreadNotificationCount`, 100 이상이면 "99+") | (root loader의 /me) | - |
| `/:handle` | 구독자 수와 구독·구독 취소 버튼(비로그인은 로그인 링크, 내 블로그면 버튼 없음). `action` `intent=subscribe\|unsubscribe` | PUT·DELETE /me/subscriptions/{handle} | RSS·Atom 자동 발견 `<link rel="alternate">` |
| `/:handle/category/:categoryId` | - | - | 카테고리 RSS, 블로그 RSS·Atom 자동 발견 |
| `/:handle/:postId` | 좋아요 수와 좋아요 버튼(`action` `intent=like\|unlike`, 비로그인은 로그인 링크), 관련 글(최대 5편, 없으면 영역 숨김), 공유(주소 복사, 카카오톡, X, 페이스북) | PUT·DELETE /me/likes/{postId}, GET /posts/{id}/related | RSS·Atom 자동 발견, 대표 이미지가 없으면 `twitter:card=summary` |

- 좋아요·구독 폼은 JS 없이도 동작한다(POST 후 같은 화면으로 리다이렉트). JS가 있으면 화면 이동 없이 수가 바뀐다(React Router `useFetcher`).
- 자동 발견 링크의 `href`는 절대 주소(`publicOrigin`), `title`은 `{블로그 제목} RSS`·`{블로그 제목} Atom`·`{카테고리} - {블로그 제목} RSS`(번역 키 `discovery:feedLink.*`).
- 공유의 카카오톡 버튼은 `BLOG_KAKAO_JS_KEY`가 있을 때만 보인다. X·페이스북은 새 창 링크라 JS 없이도 동작하고, 주소 복사는 JS가 없으면 주소 입력란을 보여준다.

## 프록시 (변경 없음)

`/:handle/rss`, `/:handle/atom`, `/:handle/category/:categoryId/rss`, `/sitemap.xml`, `/sitemap/**`, `/robots.txt`는 001 front 서버의 `blog-front/server/middleware/backend-proxy.ts`가 이미 backend로 넘긴다. 002는 이 동작을 테스트로만 확인한다.
