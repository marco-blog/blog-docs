# Route Contract: 004 블로그 꾸미기와 글 옵션 (front)

004 화면의 loader·action·meta를 정한다. 경로 이름과 예약어의 기준 목록은 [001 contracts/routes.md](../../001-blog-core/contracts/routes.md)이며, 004의 블로그별 하위 경로(`guestbook`, `notice`, `archive`, `search`, `tags`)와 관리 경로는 이미 그 목록과 예약어에 있다. 새 최상위 경로는 없다.

## 공개 블로그 레이아웃 (새)

`blog-front/app/routes.ts`에서 아래 공개 블로그 화면을 경로 없는 레이아웃 `layout("routes/blog/layout.tsx", [...])`으로 감싼다(research B11). 주소는 바뀌지 않는다. 고정 이름 경로(`notice`, `archive`, `search`, `tags`, `guestbook`)는 `:handle/:postId`보다 앞에 둔다.

| 레이아웃 | loader 호출 API | 그리는 것 |
|---|---|---|
| `routes/blog/layout.tsx` | GET /blogs/{handle}, GET /blogs/{handle}/sidebar, POST /blogs/{handle}/visits(실패 무시) 병렬 | 블로그 메뉴(홈·공지·방명록(`guestbookEnabled`일 때)·태그), 사이드바(켜진 항목을 순서대로. PROFILE·CATEGORIES·SEARCH·FEED_LINKS는 `GET /blogs/{handle}` 결과로 그림), 자식 `Outlet` |

- 감싸는 화면: `:handle`, `:handle/category/:categoryId`, `:handle/tags`, `:handle/tags/:name`, `:handle/notice`, `:handle/archive/:year/:month`, `:handle/search`, `:handle/guestbook`, `:handle/:postId`. `:handle/write/**`·`:handle/manage/**`는 밖(방문을 세지 않고 사이드바 없음).
- 자식 화면도 지금처럼 자기 loader에서 `GET /blogs/{handle}`을 부른다. 레이아웃과 자식의 같은 GET은 001 `BackendSession.memo`로 요청당 한 번만 나가게 `api.get`의 메모 대상에 `/blogs/{handle}`을 더한다. 블로그가 없거나 볼 수 없으면 404 화면.
- `shouldRevalidate`: `handle`이 바뀌거나 이 레이아웃 아래 action(방명록·댓글 쓰기)이 끝났을 때만 다시 부른다(같은 블로그 안 이동에는 방문 기록을 다시 보내지 않음, backend가 하루 한 번만 세므로 다시 보내도 결과는 같음).
- 모바일(폭 360px)에서는 사이드바가 본문 아래로 내려간다.

## 새 화면

| 경로 | 화면 | 렌더링 | loader 호출 API | action | meta |
|---|---|---|---|---|---|
| `/:handle/guestbook?page=` | 방명록: 쓰기 폼(로그인 회원은 내용·비밀글, 비회원 허용 블로그의 비로그인은 이름·비밀번호 추가, 허용하지 않으면 로그인 안내), 최상위 글 최신순 20개와 주인 답글, 비밀글은 "비밀글입니다", 비회원 표시, 수정·삭제(비회원은 비밀번호 입력), 주인은 답글·삭제 | SSR(폼은 `action`) | /blogs/{handle}, /blogs/{handle}/guestbook?page= | `intent=create\|reply\|update\|delete\|unlock` | `{방명록} - {블로그 제목}`, 2쪽 이상 `noindex` |
| `/:handle/notice?page=` | 공지 목록(발행 최신순 20개) | SSR | /blogs/{handle}/notices?page= | - | `{공지} - {블로그 제목}` |
| `/:handle/archive/:year/:month?page=` | 그 달의 글 목록(제목에 "2026년 10월", 화면 언어 형식). `:year`·`:month`가 숫자가 아니거나 범위 밖이면 404 | SSR | /blogs/{handle}/posts?year=&month=&page= | - | `{2026년 10월} - {블로그 제목}` |
| `/:handle/search?q=&page=` | 블로그 내 검색: 입력란과 결과(보호 글은 제목만). `q`가 2자 미만·100자 초과면 입력란 문구(002 규칙) | SSR | /search/posts?blog={handle}&q=&page= | - | `noindex` |
| `/:handle/tags` | 블로그 태그 목록: 이름순, 글 수가 많을수록 크게(5단계, `app/blog/tagWeight.ts`), 누르면 `/:handle/tags/:name` | SSR | /blogs/{handle}/tags | - | `{태그} - {블로그 제목}` |
| `/:handle/manage/guestbook?page=` | 방명록 관리: 모든 글(비밀글 내용 포함), 답글 쓰기·삭제, 회원 작성자 "차단"(US5), 방명록이 꺼져 있으면 안내와 설정 링크 | SSR(폼은 `action`) | /blogs/{handle}/guestbook?page= | `intent=reply\|delete\|block` | noindex |
| `/:handle/manage/design` | 꾸미기: 사이드바 항목 켜기·끄기·위아래 순서(JS 없이 "위로"·"아래로" 버튼 폼), 저장. 공지 목록과 "공지 해제" | SSR(폼은 `action`) | /blogs/{handle}/manage/sidebar, /blogs/{handle}/notices?size=50 | `intent=saveSidebar\|unnotice` → PUT /blogs/{handle}/sidebar, POST /blogs/{handle}/manage/posts/bulk `UNNOTICE` | noindex |
| `/:handle/manage/stats` | 통계: 오늘·어제·전체 방문자, 최근 30일 일별 방문자(표 + CSS 막대, 회원 시간대가 아니라 `blog.stats.time-zone` 날짜임을 표시), 조회수 상위 글 10편 | SSR | /blogs/{handle}/manage/stats?days=30 | - | noindex |
| `/:handle/manage/backup` | 백업: "백업 만들기"(하루 1회 안내), 최근 백업 목록(상태·크기·만료), READY는 내려받기 링크(`/api/v1/blogs/{handle}/exports/{id}/file`, 프록시 경유), PENDING·RUNNING이 있으면 30초마다 다시 읽기(JS 있을 때 `useRevalidator`) | SSR(폼은 `action`) | /blogs/{handle}/exports | `intent=create` → POST /blogs/{handle}/exports | noindex |
| `/:handle/manage/blocks?page=` | 차단 목록: 회원(닉네임·프로필)·차단 시각, "해제" | SSR(폼은 `action`) | /blogs/{handle}/blocks?page= | `intent=unblock` → DELETE /blogs/{handle}/blocks/{userId} | noindex |

- 블로그 관리 좌측 메뉴(`routes/manage/layout.tsx`, `app/manage/links.ts`)에 "방명록", "꾸미기", "통계", "백업", "차단 목록"을 더한다(006 spec 블로그 관리 메뉴 순서).
- 방명록 글·댓글의 사용자 입력은 모두 이스케이프해 출력한다(`dangerouslySetInnerHTML` 없음).

## 001~003 화면 변경

| 경로 | 변경 | 추가 API | meta 추가 |
|---|---|---|---|
| `/:handle` | 글 목록 위에 공지(최대 5개, "공지" 표시, 더 있으면 "공지 더 보기" `/:handle/notice`). 목록 API는 공지를 빼고 준다 | GET /blogs/{handle}/notices?size=5 | - |
| `/:handle/:postId` | 열지 않은 보호 글: 제목·작성자·발행일과 비밀번호 입력 폼(`intent=unlock`, JS 없이 동작), 틀리면 오류 문구, 막히면 남은 시간 안내. 열면(쿠키) 본문·댓글·좋아요가 평소대로. 조회수·끝까지 읽음은 열린 뒤에만 | POST /posts/{id}/unlock | 보호 글은 `description`·`og:image` 없음, `noindex` |
| `/:handle/:postId` 댓글 | 쓰기 폼에 "비밀 댓글" 체크, 비로그인 + 비회원 허용이면 이름·비밀번호, 허용하지 않으면 로그인 안내 링크(`/login?next=`). 목록에 "비밀 댓글입니다", "비회원" 표시. 비회원 댓글 수정·삭제는 비밀번호 입력(비밀 댓글 수정은 `intent=unlockComment`로 내용을 먼저 받음) | POST /comments/{id}/unlock | - |
| `/:handle/write`, `/:handle/write/:postId` 발행 설정 레이어 | 공개 범위에 "보호"(고르면 비밀번호 입력, 이미 보호 글이면 "바꾸지 않으려면 비워 두세요"), "예약 발행"(날짜·시각, 회원 시간대로 입력하고 UTC로 보냄, `app/i18n/zonedDateTime.ts`), "공지로 등록" 체크. 이미 발행된 글에는 예약 입력을 숨김. 예약 글을 열면 예약 시각이 채워져 있고 "예약 취소" | POST /posts/{id}/unschedule | - |
| `/:handle/manage/posts` | 상태 필터 "예약", 공개 범위 필터 "보호", 예약 글은 예약 시각 표시, 일괄 작업 "공지로"·"공지 해제" | - | - |
| `/:handle/manage/settings` | "방명록 사용", "비회원 댓글·방명록 허용"(켜면 이름·비밀번호로 쓸 수 있다는 안내) | PATCH /blogs/{handle} `{ guestbookEnabled, guestWriteEnabled }` | - |
| `/:handle/manage` (대시보드) | 오늘·어제 방문자(001이 숨겨 둔 영역), 최근 7일 새 방명록 수와 최근 5건 | (응답 필드 추가) | - |
| `/:handle/manage/comments` | 비밀·비회원 표시, 회원 작성자 "차단"(US5) | PUT /blogs/{handle}/blocks/{userId} | - |
| `/notifications` | `BACKUP_READY` 문구("{blogTitle} 백업이 준비되었습니다. {expiresAt}까지 내려받을 수 있습니다")와 링크 `/{handle}/manage/backup` | - | - |

- 날짜·시각 표시는 001 규칙대로 회원 시간대(기본 한국 시간)로 하되, 보관함의 연·월과 통계의 날짜는 서비스 기준 시간대(`blog.stats.time-zone`) 값이다.
- 보호 글 열람 쿠키(`post_unlock_{id}`)는 backend가 준 `Set-Cookie`를 front가 그대로 브라우저에 싣고, 다음 요청에서 브라우저 쿠키를 그대로 backend로 넘긴다(001 `app/api/backendCookies.server.ts`, 변경 없음).

## 사이트맵·피드 (변경 없음, 확인만)

보호 글은 본문 노출 가능이 아니므로 002 사이트맵에서 빠지고, 피드에는 제목·링크만 나간다(002 T-피드가 이미 처리). 예약 글은 PUBLISHED가 아니므로 어디에도 없다. 004는 코드를 바꾸지 않고 통합 테스트로 확인한다(tasks.md Polish). 방명록·공지 목록·보관함은 사이트맵에 넣지 않는다(글 주소가 이미 들어감).

## 프록시 (변경 없음)

004의 새 API는 모두 `/api/**`이므로 001 `blog-front/server/middleware/backend-proxy.ts`가 그대로 넘긴다. 백업 파일(`/api/v1/blogs/{handle}/exports/{id}/file`)도 같은 프록시로 스트리밍한다(본문을 버퍼에 모으지 않음을 확인하는 단위 테스트를 둔다).
