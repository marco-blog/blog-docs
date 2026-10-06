# Route Contract: 001 블로그 핵심 (front)

기준 도메인 `https://blog.java21.net`. React Router framework 모드 라우트 모듈. "SSR"은 `loader`에서 backend를 조회해 서버에서 완성된 HTML을 보내는 화면(JS 없이도 본문·메타 포함, FR-036).

이 문서는 **001~007 전체의 최상위 경로와 블로그별 하위 경로의 기준 목록**이다. 001 밖의 경로는 "스펙" 열에 표시했으며, 화면 세부(loader·meta)는 해당 스펙의 contracts에서 정한다. 새 경로를 추가하는 스펙은 이 표와 [예약어](#예약어)를 같은 PR에서 고친다. 아래 API 경로는 모두 `/api/v1` 접두어를 뺀 것이다([api.md](./api.md)).

## 001 화면

| 경로 | 화면 | 렌더링 | loader 호출 API | meta |
|---|---|---|---|---|
| `/` | 임시 메인(서비스 소개, 로그인·가입 링크) — 003-portal에서 포털로 교체 | SSR | - | 서비스 이름 |
| `/signup` | 회원가입(약관·개인정보 동의, 만 14세 확인) | SSR(폼은 `action`) | /legal/terms | noindex |
| `/login` | 로그인 | SSR(폼은 `action`) | - | noindex |
| `/password-reset` | 비밀번호 재설정 요청(이메일 입력) (FR-133) | SSR(폼은 `action`) | - | noindex |
| `/password-reset/confirm?token=` | 새 비밀번호 입력 (FR-133) | SSR(폼은 `action`) | - | noindex |
| `/terms` | 이용약관(화면 언어판 + "한국어판 우선" 안내) (FR-137, FR-155) | SSR | /legal/terms?lang= | 이용약관 - 서비스명 |
| `/privacy` | 개인정보처리방침 (FR-137, FR-155) | SSR | /legal/privacy?lang= | 개인정보처리방침 - 서비스명 |
| `/write` | 상단 "글쓰기" 진입점(화면 없음). 블로그가 1개면 그 블로그의 `/:handle/write`로, 여러 개면 최근에 쓴 블로그(쿠키 `last_blog`, 아래 참고)로, 알 수 없으면 `/settings/blogs`(블로그 선택)로 리다이렉트 | 리다이렉트 | /me/blogs | noindex |
| `/manage` | 상단 "내 블로그 관리" 진입점(화면 없음). 블로그가 1개면 `/:handle/manage`로, 여러 개면 최근에 쓴 블로그의 `/:handle/manage`로, 알 수 없으면 `/settings/blogs`(블로그 선택)로 리다이렉트 | 리다이렉트 | /me/blogs | noindex |
| `/settings` | 계정 설정 첫 화면(`/settings/profile`로 이동) | 리다이렉트 | - | noindex |
| `/settings/profile` | 프로필(닉네임·소개·프로필 이미지)·탈퇴 (FR-008, FR-009) | SSR | /me | noindex |
| `/settings/password` | 비밀번호 변경 (FR-082) | SSR(폼은 `action`) | - | noindex |
| `/settings/login-history` | 최근 로그인 기록 (FR-139) | SSR | /me/login-history | noindex |
| `/settings/language` | 언어·시간대 설정 (FR-149, FR-153) | SSR(폼은 `action`) | /me | noindex |
| `/settings/blogs` | 내 블로그 목록(블로그 수 / 한도), 새 블로그 만들기(주소·제목), 블로그 삭제(마지막 블로그 제외), 각 블로그의 관리·글쓰기 바로가기. 여러 블로그가 있을 때 `/manage`·`/write`의 블로그 선택 화면을 겸함 (FR-158, FR-159) | SSR(폼은 `action`) | /me/blogs, /auth/handle-availability | noindex |
| `/locale` | 하단 언어 선택의 저장 처리(리소스 라우트, 화면 없음). 쿠키 `lang` 설정, 로그인 상태면 PATCH /me `locale`, 원래 페이지로 리다이렉트 (FR-150) | `action`만 | - | - |
| `/tags/:name` | 서비스 전체 태그별 글 | SSR | /tags/{name}/posts | `#태그 - 서비스명` |
| `/:handle` | 블로그 홈 | SSR | /blogs/{handle}, /blogs/{handle}/posts | 블로그 제목·소개, og:image=대표 이미지 |
| `/:handle/category/:categoryId` | 카테고리별 글 | SSR | /blogs/{handle}/posts?category= | 카테고리명 - 블로그 제목 |
| `/:handle/tags/:name` | 블로그 내 태그별 글 | SSR | /blogs/{handle}/posts?tag= | |
| `/:handle/:postId` (`postId`는 `\d+`) | 글 상세 + 댓글 | SSR, 댓글 작성은 `action` | /posts/{id}, /posts/{id}/comments, POST /posts/{id}/views | 글 제목, description=summary, og:title/description/image/url, canonical |
| `/:handle/write` | 이 블로그에 새 글 작성(작성 → "완료" → 발행 설정 레이어 → 발행). 1분 자동저장, 이어 쓰기 확인 | 클라이언트 전용 에디터(Milkdown Crepe 지연 로딩) | /me, /blogs/{handle}/categories, /blogs/{handle}/posts/drafts/latest | noindex |
| `/:handle/write/:postId` | 글 수정(작성 중 사본이 있으면 사본, 없으면 발행본을 불러옴). 글이 `:handle` 블로그의 글이 아니면 404 | 위와 같음 | /posts/{id}/draft | noindex |
| `/:handle/manage` | 블로그 관리 대시보드 (006 FR-100. 004 전에는 글·댓글 수치만) | SSR | /blogs/{handle}/manage/dashboard | noindex |
| `/:handle/manage/posts` | 글 관리: 상태·공개 범위·카테고리 필터, 제목 검색, 일괄 작업 (006 FR-101) | SSR | /blogs/{handle}/manage/posts?status=&visibility=&category=&q= | noindex |
| `/:handle/manage/posts?status=DELETED` | 휴지통(30일 내 삭제 글, 복구) (FR-084) | 위와 같음 | /blogs/{handle}/manage/posts?status=DELETED | noindex |
| `/:handle/manage/categories` | 카테고리 관리 | SSR + 클라이언트 상호작용 | /blogs/{handle}/categories | noindex |
| `/:handle/manage/comments` | 댓글 관리 (006 FR-099) | SSR | /blogs/{handle}/manage/comments | noindex |
| `/:handle/manage/settings` | 블로그 설정(제목·소개·대표 이미지·댓글 허용) | SSR | /blogs/{handle} | noindex |

- 비로그인 사용자가 로그인 필요 화면(`/write`, `/manage`, `/:handle/write/**`, `/:handle/manage/**`, `/settings/**`)에 접근하면 `/login?next=...`로 리다이렉트. 존재하지 않거나 볼 권한이 없으면 404 화면(HTTP 404 상태 코드로 응답). 로그인한 회원이 자기 블로그가 아닌(또는 삭제된) `:handle`의 `write`·`manage` 화면에 접근해도 404다.
- 모든 화면 하단에 언어 선택(FR-150)과 `/terms`·`/privacy` 링크(FR-137)가 있다. 페이지 주소에는 언어 접두어를 넣지 않는다.
- 블로그 관리(`/:handle/manage/**`, 블로그마다 따로)와 계정 설정(`/settings/**`, 회원 단위)은 별개 화면이다. 블로그 관리는 006의 레이아웃을 쓰며, 001에서는 대시보드·글 관리(휴지통 포함)·카테고리·댓글·블로그 설정 메뉴만 있다. 레이아웃 상단에 블로그 전환(내 다른 블로그의 같은 메뉴로 이동)이 있다.
- 최근에 쓴 블로그: front가 `/:handle/manage/**`나 `/:handle/write/**`를 열 때 쿠키 `last_blog`(handle, 1년, HttpOnly)를 저장한다. `/manage`·`/write`는 이 값이 `/me/blogs`의 내 블로그 중 하나일 때만 쓴다(서버 저장 없음).

## 002~007 경로 (기준 목록)

블로그 관리 화면은 모두 `/:handle/manage/...`(블로그마다 따로)이며 001의 블로그 관리 규칙(주인만, 아니면 404)을 따른다.

| 경로 | 화면 | 스펙 |
|---|---|---|
| `/search?q=` | 서비스 전체 검색 | 002 FR-035 |
| `/feed` | 구독 피드(로그인) | 002 FR-032 |
| `/notifications` | 알림 목록(로그인) | 002 FR-033 |
| `/sitemap.xml`, `/robots.txt` | 사이트맵(필요하면 `/sitemap/...` 하위 파일로 나눔), 검색 엔진 규칙 | 002 FR-037 |
| `/:handle/rss`, `/:handle/atom` | 블로그 RSS 2.0 / Atom 1.0 피드(backend가 생성, 프록시) | 002 FR-044 |
| `/:handle/category/:categoryId/rss` | 카테고리 피드 | 002 FR-045 |
| `/:handle/manage/feed` | 피드 설정 | 002 FR-046, 006 FR-099 |
| `/` (교체) | 포털 메인 | 003 FR-034 |
| `/topics/:major`, `/topics/:major/:minor` | 주제 대분류·소분류 페이지 | 003 FR-078 |
| `/updates` | 릴리스 노트(위키 형태): 왼쪽 major.minor 버전 트리, 오른쪽 최신 버전 본문·자동 목차. canonical은 최신 버전 주소. SSR, loader는 GET /release-notes, GET /release-notes/{version} | 003 FR-161, FR-164 |
| `/updates/:version` (`:version`은 `v\d+\.\d+\.\d+`, 예: `/updates/v1.2.0`) | 버전별 릴리스 노트 고유 주소. 제목마다 앵커(`#새-기능`), 이전·다음 버전 링크. 버전 페이지를 열면 로그인 회원의 마지막 확인 버전 갱신(POST /me/release-notes/seen). 초안·없는 버전은 404. 사이트맵 포함 | 003 FR-161, FR-163, FR-164 |
| `/updates/:version/history`, `/updates/:version/history/:revisionNo` | 수정 이력(게시 후 수정본 목록)과 이전 수정본 보기. noindex | 003 FR-166 |
| `/updates?q=` | 릴리스 노트 검색(화면 언어, 게시된 노트만). 결과는 오른쪽 영역에 표시. noindex | 003 FR-165 |
| `/updates/seen` | 릴리스 노트 배너 닫기(리소스 라우트, `action`만. POST /me/release-notes/seen 후 원래 화면으로) | 003 FR-163 |
| `/:handle/guestbook` | 방명록 | 004 FR-056 |
| `/:handle/notice` | 공지 목록 | 004 FR-059 |
| `/:handle/archive/:year/:month` | 월별 보관함 | 004 FR-061 |
| `/:handle/search?q=` | 블로그 내 검색 | 004 FR-061 |
| `/:handle/tags` | 블로그 태그 목록 | 004 FR-061 |
| `/:handle/manage/guestbook`, `/:handle/manage/design`, `/:handle/manage/stats`, `/:handle/manage/backup`, `/:handle/manage/blocks` | 방명록 관리, 꾸미기(사이드바·공지), 통계, 백업, 차단 목록 | 004, 006 FR-099 |
| `POST /:handle/:postId/trackback` | 트랙백 받기(backend, 프록시, Origin 검사 제외) | 005 FR-050 |
| `/:handle/manage/trackbacks` | 받은 트랙백 | 005 FR-053, 006 FR-099 |
| `/rights-request` | 비회원 권리 침해(저작권 등) 신고 양식 | 005 FR-040 |
| `/admin`, `/admin/**` | 시스템 관리자 콘솔(대시보드, topics, portal, users, content, reports, external-blogs, reserved-handles, settings, admins, audit-log, release-notes). 관리자가 아니면 404 | 006 FR-096~106 |
| `/admin/topics`, `/admin/portal/curations`, `/admin/portal/exclusions`, `/admin/portal/settings` | 콘솔의 003 메뉴: 주제 관리, 포털 추천, 포털 제외, 포털 설정값(003 contracts/routes.md). `/admin`은 006 대시보드 전까지 `/admin/topics`로 리다이렉트 | 003 FR-079, FR-086·088·091~093·147, 006 FR-102 |
| `/admin/release-notes`, `/admin/release-notes/new`, `/admin/release-notes/:id`, `/admin/release-notes/:id/revisions` | 릴리스 노트 목록·만들기·수정(언어별 탭, 미리보기, 게시·게시 중단)·수정본 | 006 FR-167·168 |
| `/:handle/manage/external-blogs`, `/:handle/manage/external-blogs/new` | 내 외부 블로그(등록 신청·소유 인증·수집된 글 주제 변경·해제). 외부 블로그는 회원에 속하므로 내 어느 블로그의 관리 화면에서 열어도 같은 목록이다 | 007 FR-109~112, FR-120, FR-126, 006 FR-099 |

- 릴리스 노트 배너(003 FR-163): 로그인 회원의 모든 화면 공통 레이아웃 상단에 한 줄로 보이며, GET /me 응답의 `unseenReleaseNote`로 그린다. 닫기는 POST /me/release-notes/seen. 포털 메인(`/`)의 릴리스 노트 카드(003 FR-162)는 GET /release-notes 응답의 `portalCard`로 그린다.

## 블로그별 하위 경로 (`/:handle/...`)

`/:handle/:postId`는 `postId`가 숫자(`\d+`)일 때만 매칭한다. 그 밖의 하위 경로는 아래 고정 이름만 쓴다. 이 이름들은 숫자가 아니므로 글 번호와 겹치지 않으며, 블로그 안에서 사용자가 만드는 이름(카테고리 등)은 경로에 ID를 쓰므로 충돌하지 않는다. 새 하위 경로를 추가하면 이 목록을 고친다.

```
category, tag, tags, rss, atom, guestbook, notice, archive, search, manage, write
```

`/:handle/:postId/trackback`(005)은 글 상세 아래의 고정 하위 경로다. `manage`(블로그 관리)와 `write`(글쓰기) 아래 경로는 블로그 주인만 쓰는 화면이다(001 화면 표).

## 프록시 (front 서버 → backend)

| 경로 | 대상 |
|---|---|
| `/api/**` | backend `/api/**` (API는 모두 `/api/v1/...`) |
| `/media/**` | backend `/media/**` |
| `/:handle/rss`, `/:handle/atom`, `/:handle/category/:categoryId/rss` | backend 같은 경로 (002) |
| `POST /:handle/:postId/trackback` | backend 같은 경로 (005) |
| `/sitemap.xml`, `/sitemap/**`, `/robots.txt` | backend 같은 경로 (002) |

## 예약어

블로그 주소로 쓸 수 없는 이름. backend `blog` 패키지의 코드 상수 하나로만 관리하며, 운영 중 관리자 화면에서 추가·수정하지 않는다(006 시스템 관리자 콘솔은 읽기 전용으로 보여준다). 최상위 경로를 추가할 때 이 목록과 backend 상수를 같은 PR에서 함께 고친다. 001~007의 모든 최상위 경로(위 표의 첫 경로 조각)를 포함하며, 앞으로 쓸 수 있는 일반 이름도 미리 막는다. 001 FR-002의 예시는 이 목록의 일부다.

```
admin, api, assets, static, media, public, build, favicon.ico, robots.txt, sitemap, sitemap.xml,
signup, login, logout, auth, oauth, me, settings, manage, write, edit, password-reset,
search, tags, tag, topics, topic, category, feed, rss, atom, notifications, explore, popular,
external, external-blogs, report, reports, rights-request, trackback, locale, lang, legal,
help, about, terms, privacy, policy, notice, support, health, blog, www, mail, root, system,
updates
```

`manage`, `write`는 블로그별 하위 경로이기도 하지만 최상위 진입점(`/manage`, `/write` 리다이렉트)으로도 쓰므로 계속 예약어로 둔다. `me`처럼 handle 규칙(3~20자, 영문 소문자·숫자·하이픈)으로는 원래 만들 수 없는 이름도 경로 이름이므로 목록에 남겨 둔다.
