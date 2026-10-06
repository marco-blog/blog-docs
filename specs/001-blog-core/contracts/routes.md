# Route Contract: 001 블로그 핵심 (front)

기준 도메인 `https://blog.java21.net`. React Router framework 모드 라우트 모듈. "SSR"은 `loader`에서 backend를 조회해 서버에서 완성된 HTML을 보내는 화면(JS 없이도 본문·메타 포함, FR-036).

| 경로 | 화면 | 렌더링 | loader 호출 API | meta |
|---|---|---|---|---|
| `/` | 임시 메인(서비스 소개, 로그인·가입 링크) — 003-portal에서 포털로 교체 | SSR | - | 서비스 이름 |
| `/signup` | 회원가입 | SSR(폼은 `action`) | - | noindex |
| `/login` | 로그인 | SSR(폼은 `action`) | - | noindex |
| `/write` | 새 글 작성(작성 → "완료" → 발행 설정 레이어 → 발행). 1분 자동저장, 이어 쓰기 확인 | 클라이언트 전용 에디터(Milkdown Crepe 지연 로딩) | /me, /blogs/{handle}/categories, /posts/drafts/latest | noindex |
| `/write/:postId` | 글 수정 | 위와 같음 | /posts/{id} | noindex |
| `/manage` | 내 블로그 관리: 글 목록(임시저장 포함) | SSR | /blogs/{handle}/manage/posts | noindex |
| `/manage/categories` | 카테고리 관리 | SSR + 클라이언트 상호작용 | /blogs/{handle}/categories | noindex |
| `/manage/settings` | 블로그 설정 | SSR | /blogs/{handle} | noindex |
| `/settings/profile` | 프로필·탈퇴 | SSR | /me | noindex |
| `/tags/:name` | 서비스 전체 태그별 글 | SSR | /tags/{name}/posts | `#태그 - 서비스명` |
| `/:handle` | 블로그 홈 | SSR | /blogs/{handle}, /blogs/{handle}/posts | 블로그 제목·소개, og:image=대표 이미지 |
| `/:handle/category/:categoryId` | 카테고리별 글 | SSR | /blogs/{handle}/posts?category= | 카테고리명 - 블로그 제목 |
| `/:handle/tags/:name` | 블로그 내 태그별 글 | SSR | /blogs/{handle}/posts?tag= | |
| `/:handle/:postId` | 글 상세 + 댓글 | SSR, 댓글 작성은 `action` | /posts/{id}, /posts/{id}/comments, POST /posts/{id}/views | 글 제목, description=summary, og:title/description/image/url, canonical |

비로그인 사용자가 로그인 필요 화면에 접근하면 `/login?next=...`로 리다이렉트. 존재하지 않거나 볼 권한이 없으면 404 화면(HTTP 404 상태 코드로 응답).

## 프록시 (front 서버 → backend)

| 경로 | 대상 |
|---|---|
| `/api/**` | backend `/api/**` |
| `/media/**` | backend `/media/**` |

## 예약어

블로그 주소로 쓸 수 없는 이름. 최상위 경로를 추가할 때 이 목록과 backend의 예약어 상수를 같은 PR에서 함께 고친다(002~005에서 쓸 경로도 미리 포함).

```
admin, api, assets, static, media, public, favicon.ico, robots.txt, sitemap.xml,
signup, login, logout, auth, oauth, me, settings, manage, write, edit,
search, tags, tag, category, feed, rss, atom, notifications, explore, popular,
help, about, terms, privacy, policy, notice, support, blog, www, mail, root, system
```
