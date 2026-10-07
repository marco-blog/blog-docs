# Route Contract: 006 관리 화면 (front)

006 화면의 loader·action·meta를 정한다. 경로 이름과 예약어의 기준 목록은 [001 contracts/routes.md](../../001-blog-core/contracts/routes.md)이며, 006의 최상위 경로(`/admin`, `/manage`)와 블로그 하위 경로(`/:handle/manage`)는 이미 그 목록과 backend `ReservedHandles`에 있다. **새 예약어는 없다.** 콘솔 공통 규칙(비로그인 `/login?next=`, 관리자가 아니면 404, backend 404 `NOT_FOUND`면 404)은 003 `admin/access.server.ts`, 블로그 관리 공통 규칙(주인이 아니면 404)은 001 `manage/access.server.ts`를 그대로 쓴다. 모든 관리 화면의 meta는 `privatePageMeta`(noindex).

## 새 화면 (시스템 관리자 콘솔)

| 경로 | 화면 | 렌더링 | loader 호출 API | action | meta |
|---|---|---|---|---|---|
| `/admin` (index, 003 리다이렉트 대체) | 콘솔 대시보드: 오늘 가입자·발행 글·댓글, 전체 회원·블로그·공개 글, 처리 대기 신고(005 이후, `/admin/reports` 링크), 최근 7일 가입·발행 막대(`DailyBarChart`), "n분 전 기준·시간대" | SSR | GET /admin/dashboard | - | `{관리자 콘솔}`, noindex |
| `/admin/contents/posts?q=&handle=&authorId=&status=&visibility=&page=` | 콘텐츠 관리 — 글: 검색 폼, 표(제목 → 글 주소, 블로그, 작성자(→ 회원 상세, 005 이후), 상태·공개 범위, 발행 시각, 댓글 수), 005 이후 행마다 "숨김"/"숨김 해제". 숨김은 행마다 숨김 사유 입력란(필수, 1~500자, 005 API가 본문 `{ reason }`을 요구) | SSR(폼은 GET, 숨김은 `action`) | GET /admin/contents/posts | `intent=hide\|unhide` → PUT·DELETE /admin/contents/posts/{id}/hidden (005, PUT 본문 `{ reason }`) | noindex |
| `/admin/contents/comments?postId=&authorId=&handle=&status=&q=&page=` | 콘텐츠 관리 — 댓글: 같은 형태, 내용 앞 200자(비밀 댓글은 "비밀 댓글"), 글 제목 링크 `/{handle}/{postId}#comment-{id}` | 같음 | GET /admin/contents/comments | `intent=hide\|unhide` → …/comments/{id}/hidden (005, hide는 `reason` 필수 1~500자) | noindex |
| `/admin/contents/guestbook?handle=&authorId=&status=&q=&page=` | 콘텐츠 관리 — 방명록 | 같음 | GET /admin/contents/guestbook-entries | `intent=hide\|unhide` → …/guestbook-entries/{id}/hidden (005, hide는 `reason` 필수 1~500자) | noindex |
| `/admin/contents` | 화면 없음, `/admin/contents/posts`로 리다이렉트 | 리다이렉트 | - | - | - |
| `/admin/reserved-handles` | 예약어 목록(읽기 전용) + "코드 상수로 관리합니다(블로그 주소 규칙 001 FR-002)" | SSR | GET /admin/reserved-handles | - | noindex |
| `/admin/settings` | 서비스 설정(읽기 전용): 약관 버전, 첨부 파일 한도, 회원당 기본 블로그 수, 작업 기록 보관 기간, 대시보드 갱신 주기와 각 프로퍼티 이름 | SSR | GET /admin/service-settings | - | noindex |
| `/admin/admins` | 관리자 권한: 관리자 목록(닉네임 → 회원 상세(005 이후), 권한, 상태, 가입일). 최고 관리자에게만 행마다 "권한 바꾸기"(USER·ADMIN·SUPER_ADMIN 선택 + 확인)와 "회원 번호로 관리자 지정" 폼. 일반 관리자는 읽기 전용 | SSR(폼은 `action`) | GET /admin/admins | `intent=role` → PUT /admin/users/{id}/role | noindex |
| `/admin/audit-log?from=&to=&adminId=&action=&targetType=&targetId=&targetKey=&page=` | 작업 기록: 필터(기간, 관리자 선택, 작업 종류 묶음 선택, 대상 종류·ID), 표(시각·관리자·작업 이름·대상(링크)·사유), 행 펼침(`<details>`)으로 변경 전후 값 비교(`JsonDiff`), 최고 관리자에게만 "요청 IP 보기"(상세 API) | SSR(필터는 GET 폼) | GET /admin/audit-logs, GET /admin/audit-logs/actions, GET /admin/admins | - | noindex |
| `/admin/audit-log/:id` | 기록 하나(요청 IP 포함 — 최고 관리자) | SSR | GET /admin/audit-logs/{id} | - | noindex |
| `/admin/release-notes?status=&page=` | 릴리스 노트 목록: 상태 탭(전체·초안·게시), 버전·상태·릴리스 날짜·언어판·수정본 번호·게시 시각, "새 노트" | SSR | GET /admin/release-notes | - | noindex |
| `/admin/release-notes/new` | 만들기: 버전, 릴리스 날짜, 언어 탭(ko 필수, en·ja·zh-CN 선택)별 제목·Markdown 본문, "미리보기", "초안 저장" | SSR(폼은 `action`) | - | `intent=preview` → POST /admin/release-notes/preview, `intent=save` → POST /admin/release-notes → `/admin/release-notes/{id}` | noindex |
| `/admin/release-notes/:id` | 수정: 위와 같고 숨은 `baseRevisionNo`, 처음 게시 뒤 버전 읽기 전용, 상태·수정본 번호·만든/고친 관리자, "게시"/"게시 중단", "삭제"(한 번도 게시하지 않은 초안만), "독자에게 보기"(게시 상태), "수정본", "이 노트의 작업 기록" | SSR(폼은 `action`) | GET /admin/release-notes/{id} | `intent=preview\|save\|publish\|unpublish\|delete` → preview·PUT·POST publish·POST unpublish·DELETE | noindex |
| `/admin/release-notes/:id/revisions` | 수정본 목록(번호·수정한 관리자·시각·당시 상태) | SSR | GET /admin/release-notes/{id}, GET /admin/release-notes/{id}/revisions | - | noindex |
| `/admin/release-notes/:id/revisions/:revisionNo` | 수정본 보기(버전·날짜·언어판별 제목·Markdown 원문, 읽기 전용), "이 내용으로 편집기 채우기"(`/admin/release-notes/{id}?fromRevision={no}`) | SSR | GET /admin/release-notes/{id}/revisions/{revisionNo} | - | noindex |

- 릴리스 노트 편집 화면은 `?fromRevision=`이 있으면 그 수정본 내용으로 입력을 채우고 `baseRevisionNo`는 현재 번호를 둔다(저장하면 새 수정본).
- 충돌(409 `RELEASE_NOTE_REVISION_CONFLICT`)이면 입력을 유지하고 "다른 관리자가 먼저 저장했습니다" 안내와 "최신 내용 열기"(새 창 `/admin/release-notes/{id}`).
- 미리보기 HTML은 backend가 살균한 값이므로 `components/admin/MarkdownPreview.tsx`를 `dangerouslySetInnerHTML` 허용 목록(001 R27, ESLint 예외)에 더한다.
- 작업 종류 이름은 `audit` namespace(`audit:actions.{CODE}`), 없으면 코드 그대로.

## 콘솔 메뉴 (FR-102 순서, `app/admin/links.ts`)

| 묶음 | 항목 | 경로 | 출처 | 006 머지 때 |
|---|---|---|---|---|
| 운영 | 대시보드 | `/admin` | 006 | 보임 |
| 포털 | 주제 관리 | `/admin/topics` | 003 | 보임 |
| 포털 | 포털 관리(추천·제외·설정) | `/admin/portal/curations`, `/exclusions`, `/settings` | 003 | 보임 |
| 운영 | 회원 관리 | `/admin/users` | 005 | 숨김(005가 켬) |
| 운영 | 콘텐츠 관리 | `/admin/contents/posts` | 006(숨김 버튼 005) | 보임 |
| 운영 | 신고 관리(대기 수 배지) | `/admin/reports` | 005 | 숨김(005가 켬) |
| 포털 | 외부 블로그 관리 | `/admin/external-blogs` | 007 | 숨김(007이 켬) |
| 운영 | 스팸 방어 설정 | `/admin/spam` | 005 | 숨김(005가 켬) |
| 서비스 | 예약어 | `/admin/reserved-handles` | 006 | 보임 |
| 서비스 | 서비스 설정 | `/admin/settings` | 006 | 보임 |
| 서비스 | 관리자 권한 | `/admin/admins` | 006 | 보임 |
| 서비스 | 작업 기록 | `/admin/audit-log` | 006 | 보임 |
| 서비스 | 릴리스 노트 | `/admin/release-notes` | 006 | 보임 |

항목 순서는 FR-102 표 순서이고, 묶음 제목은 좁은 화면에서 접히는 표시용이다(research A2). 숨긴 항목의 경로는 `routes.ts`에도 없다(주소로 들어가면 404).

## 블로그 관리 메뉴 (FR-099 순서, `app/manage/links.ts`)

| 항목 | 경로 | 출처 | 006 머지 때 |
|---|---|---|---|
| 대시보드 | `/:handle/manage` | 001·004 | 보임 |
| 글 관리 | `/posts` | 001 | 보임 |
| 카테고리 관리 | `/categories` | 001 | 보임 |
| 댓글 관리 | `/comments` | 001 | 보임 |
| 방명록 관리 | `/guestbook` | 004 | 보임 |
| 블로그 설정 | `/settings` | 001 | 보임 |
| 꾸미기 | `/design` | 004 | 보임 |
| 피드 설정 | `/feed` | 002 | 보임 |
| 통계 | `/stats` | 004 | 보임 |
| 받은 트랙백 | `/trackbacks` | 005 | 숨김(005가 켬) |
| 백업 | `/backup` | 004 | 004 머지 상태 그대로 |
| 차단 목록 | `/blocks` | 004 | 004 머지 상태 그대로 |
| 외부 블로그 | `/external-blogs` | 007 | 숨김(007이 켬) |

005 routes.md는 "받은 트랙백"을 "댓글 다음"에 두었지만 FR-099 표 순서(통계 다음)를 따른다(tasks 결정 표 3번).

## 001~005 화면 변경

| 경로 | 변경 | 추가 API | meta 추가 |
|---|---|---|---|
| 공통 상단(`components/layout/Header.tsx`) | 세션 `role`이 ADMIN·SUPER_ADMIN이면 "내 블로그 관리" 다음에 "시스템 관리"(`/admin`) | - (root loader의 /me) | - |
| `/admin/**` 레이아웃(003) | 메뉴를 위 표로(묶음 제목, `available`만), 머리글에 관리자 권한 이름 | - | - |
| `/admin` (003 `routes/admin/index.ts`) | `/admin/topics` 리다이렉트를 없애고 대시보드 index | GET /admin/dashboard | - |
| `/:handle/manage/**` 레이아웃(001) | `MANAGE_MENU`를 `app/manage/links.ts`로 옮기고 위 표 순서 | - | - |
| `/admin/users/:id` (005) | "관리자 권한" 영역: 지금 권한, 최고 관리자에게 권한 바꾸기 폼, "이 회원 대상 작업 기록"(`/admin/audit-log?targetType=USER&targetId={id}`), "이 회원의 글·댓글"(`/admin/contents/posts?authorId={id}`) | PUT /admin/users/{id}/role | - |
| `/admin/contents/hidden-posts` (005) | `/admin/contents/posts?status=HIDDEN`으로 리다이렉트(화면 흡수) | - | - |

## 검색 엔진 제외 (FR-098)

- front 서버 미들웨어 `server/middleware/robotsHeader.ts`: `/admin`, `/admin/**`, `/manage`, `/:handle/manage`, `/:handle/manage/**`(React Router 데이터 요청 `*.data` 포함)의 모든 응답에 `X-Robots-Tag: noindex, nofollow`.
- robots.txt(002·003 `RobotsController`)는 이미 `/admin`·`/manage`·`/*/manage`를 막는다(변경 없음, 시험으로 확인만).

## 프록시 (변경 없음)

006의 새 API는 모두 `/api/**`이므로 001 `server/middleware/backend-proxy.ts`가 그대로 넘긴다. `/admin/**`, `/:handle/manage/**`는 front 화면이다.
