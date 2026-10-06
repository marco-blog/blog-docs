# Route Contract: 003 포털 (front)

003 화면의 loader·action·meta를 정한다. 경로 이름과 예약어의 기준 목록은 [001 contracts/routes.md](../../001-blog-core/contracts/routes.md)이며, 003의 최상위 경로(`/`, `/topics`, `/updates`, `/admin`)는 이미 그 목록과 예약어에 있다. 이 스펙은 예약어를 바꾸지 않는다. 세부 경로 중 001 표에 없던 `/updates/seen`(배너 닫기 리소스 라우트)과 `/admin/topics`·`/admin/portal/**`(콘솔의 003 메뉴)은 001 routes.md "002~007 경로" 표에 함께 적는다. API 경로는 `/api/v1` 접두어를 뺀 것이다([api.md](./api.md)).

## 새 화면

| 경로 | 화면 | 렌더링 | loader 호출 API | action | meta |
|---|---|---|---|---|---|
| `/` (교체) | 포털 메인. 위에서부터 릴리스 노트 카드(게시 14일 이내), 운영자 추천, 주제 탭(대분류, `onTab`), 인기 글, 최신 글("더 보기"), 인기 태그, 새로 시작한 블로그. 로그인 회원에게 "구독 피드 보기"(`/feed`). 빈 영역은 숨기고 모두 비면 "첫 글을 써 보세요"(로그인이면 `/write`, 아니면 `/signup`) | SSR | /portal, /topics, /release-notes (병렬). `?cursor=`가 있으면 /portal/latest?cursor= 도 | - | 서비스명, description `portal:meta.description`, `og:title`·`og:description`·`og:url`·`og:type=website`, canonical `/`. `?cursor=`가 있으면 noindex |
| `/topics/:major` | 대분류 페이지. 주제 이름, 소분류 목록(`onTab`인 것, "전체" 포함), 소속 소분류 글 20편, 정렬(최신순·인기순), 페이지 이동 | SSR | /topics, /topics/{major}/posts?sort=&page= | - | `{주제 이름} - 서비스명`, description `portal:topic.description`, og, canonical(정렬 제외, `page>0`이면 `?page=` 포함). `sort=popular`는 noindex |
| `/topics/:major/:minor` | 소분류 페이지. 위와 같고 그 소분류 글만. `:minor`의 부모가 `:major`가 아니면 404 | SSR | /topics, /topics/{minor}/posts?sort=&page= | - | 위와 같음 |
| `/updates` | 릴리스 노트 위키. 왼쪽: major.minor 묶음 버전 트리(새 버전 위)·검색창. 오른쪽: 최신 버전 본문·목차. 게시된 노트가 없으면 "아직 업데이트 소식이 없습니다" | SSR | /release-notes, /release-notes/{최신 version} | - | `{최신 노트 제목} - 서비스명`, canonical = 최신 버전 주소 `/updates/v{version}` |
| `/updates?q=&page=` | 검색 결과를 오른쪽 영역에(버전·제목·일치 부분, 새 버전부터). `q`가 2자 미만·100자 초과면 입력란 문구 | SSR | /release-notes, /release-notes/search?q=&page= | - | noindex |
| `/updates/:version` (`v\d+\.\d+\.\d+`) | 버전 페이지. 본문(제목마다 앵커), 목차, 대체 언어판 표시, 이전·다음 버전 링크, "수정 이력"(수정본이 2개 이상일 때). 로그인 회원이면 loader가 마지막 확인 버전을 갱신 | SSR | /release-notes, /release-notes/{version}, (로그인) POST /me/release-notes/seen | - | `{제목} - 서비스명`, description = 본문 앞 150자, og, canonical 자기 주소. 형식이 틀리거나 없는·초안 버전은 404 |
| `/updates/:version/history` | 수정 이력: 수정본 번호·수정 시각 목록(관리자 이름 없음) | SSR | /release-notes, /release-notes/{version}, /release-notes/{version}/revisions | - | noindex |
| `/updates/:version/history/:revisionNo` | 이전 수정본 보기(그 수정본의 언어판 본문, "이전 수정본입니다" 표시, 현재 버전 링크) | SSR | /release-notes, /release-notes/{version}/revisions/{revisionNo} | - | noindex |
| `/updates/seen` | 배너 닫기(화면 없음, 리소스 라우트) | `action`만 | - | POST /me/release-notes/seen `{ version }` 후 `next`(같은 사이트 경로만, 001 `safeNextPath`)로 리다이렉트 | - |
| `/admin` | 시스템 관리자 콘솔 진입(화면 없음). `/admin/topics`로 리다이렉트(대시보드는 006 FR-103) | 리다이렉트 | - | - | noindex |
| `/admin/topics` | 주제 관리: 대분류·소분류 트리(숨김 표시, 최근 30일 글 수, 탭 고정), 추가(slug·4개 언어 이름·색), 이름·색 수정, 숨김·해제, 탭 고정·해제, 위·아래 순서 변경 | SSR(폼은 `action`) | /admin/topics | `intent=create\|update\|hide\|unhide\|pin\|unpin\|reorder` → 해당 관리자 API | noindex |
| `/admin/portal/curations` | 포털 추천: 상태 탭(진행 중·예정·종료), 추가(글 주소 또는 번호 → 글 확인 → 기간·순서), 수정, 삭제, 포털 노출 조건을 잃은 추천 표시 | SSR(폼은 `action`) | /admin/portal/curations?status=&page=, (글 확인) /admin/portal/posts/{id} | `intent=lookup\|create\|update\|delete` | noindex |
| `/admin/portal/exclusions` | 포털 제외 목록, 글 주소·번호 + 사유로 제외, 사유 수정, 해제 | SSR(폼은 `action`) | /admin/portal/exclusions?page= | `intent=exclude\|unexclude` | noindex |
| `/admin/portal/settings` | 포털 설정값: 인기 점수 가중치(6개 값), 신규 회원 대기 시간, 최소 본문 길이, 주제 자동 숨김 기준. 기본값 표시와 "기본값으로" | SSR(폼은 `action`) | /admin/settings?prefix=portal. | `intent=save\|reset`(key) → PUT·DELETE /admin/settings/{key} | noindex |

- `/admin/**`: 비로그인이면 `/login?next=...`, 세션 `role`이 ADMIN·SUPER_ADMIN이 아니면 404 화면(HTTP 404). backend가 404 `NOT_FOUND`를 주면(권한 회수) 404 화면. 좌측 메뉴는 "주제", "포털 추천", "포털 제외", "포털 설정"만(006이 나머지 메뉴를 더함, 006 FR-102).
- 콘솔에서 글을 고를 때는 글 주소(`https://blog.java21.net/{handle}/{id}` 또는 `/{handle}/{id}`)나 숫자 번호를 받아 front가 번호를 꺼낸다(`app/admin/postRef.ts`).

## 001·002 화면 변경

| 경로 | 변경 | 추가 API | meta 추가 |
|---|---|---|---|
| 모든 화면(공통 레이아웃) | 로그인 회원에게 `unseenReleaseNote`가 있으면 상단 아래 한 줄 배너(새 버전 번호·제목·"보기" `/updates/v{version}`, 닫기 폼 `/updates/seen`). 비로그인에는 없음 | (root loader의 /me) | - |
| 공통 상단 | 002 T072의 검색창과 001의 로그인·가입 / 글쓰기·내 블로그 링크를 그대로 쓴다(FR-095). 로고는 `/` | - | - |
| `/:handle/write`, `/:handle/write/:postId` | 발행 설정 레이어에 "주제"(포털 분류, 선택) 선택을 "카테고리"와 따로 둔다. 대분류별로 묶은 소분류 목록 + "선택 안 함". 새 글은 블로그 `defaultTopicId`가 미리 선택됨. 고르면 작성 중 사본에 `topicId` 저장(카테고리와 같은 방식) | GET /topics, GET /blogs/{handle}(`defaultTopicId`), DraftWrite·PublishSettings `topicId` | - |
| `/:handle/manage/settings` | "포털에 내 글 노출"(켜기·끄기, 끄면 블로그·검색·RSS에는 영향 없음 안내), "기본 주제"(소분류 선택·선택 안 함) | GET /topics, PATCH /blogs/{handle} `{ portalEnabled, defaultTopicId }` | - |
| `/:handle/:postId` | 본문 끝의 감시 요소가 화면에 들어오면 `POST /api/v1/posts/{id}/read-complete`를 한 번 보낸다(브라우저, JS 있을 때만). 글에 주제가 있으면 본문 위에 주제 링크(`/topics/{major}/{minor}`) | GET /topics (주제 이름), POST /posts/{id}/read-complete | - |

- 상대 시각("3시간 전")은 `Intl.RelativeTimeFormat`(화면 언어)으로 만들고, loader가 넘긴 서버 시각을 기준으로 해 SSR과 브라우저 결과가 같다(`app/i18n/format.ts`의 `formatRelativeTime`).
- 카드 이미지는 `thumbnailUrl` + `/600x400`(001 썸네일 규칙), 없으면 주제 카드 색 배경과 주제 이름으로 그린 기본 이미지.
- 최신 글 "더 보기": JS가 있으면 `useFetcher`로 `/?index&cursor={nextCursor}`를 불러 목록에 붙이고, 없으면 같은 주소로 이동해 그 묶음을 SSR로 보여준다.
- 릴리스 노트 본문은 backend가 살균한 HTML이므로 `dangerouslySetInnerHTML` 허용 목록(001 R27, ESLint 예외)에 `app/routes/updates/version.tsx`·`revision.tsx`를 더한다.

## 사이트맵·robots (002에 더함)

002 `SitemapService`의 `/sitemap/pages.xml`(002 T071)에 다음을 더한다. robots(002 `RobotsController`)에는 `Disallow: /admin`을 더한다.

| 주소 | 조건 | lastmod |
|---|---|---|
| `/topics/{major}`, `/topics/{major}/{minor}` | 운영자 숨김이 아닌 주제(자동 숨김 주제 포함) | 없음 |
| `/updates/v{version}` | 게시(PUBLISHED)된 노트 | 노트 `updated_at` |

## 프록시 (변경 없음)

003의 새 API는 모두 `/api/**`이므로 001 `blog-front/server/middleware/backend-proxy.ts`가 그대로 넘긴다. `/topics/**`, `/updates/**`, `/admin/**`는 front 화면이다(프록시 대상 아님).
