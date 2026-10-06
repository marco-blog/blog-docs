# Quickstart: 003 포털 검증 가이드

구현이 끝난 뒤 이 순서로 실행해 스펙이 동작함을 확인한다. 세부 API는 [contracts/api.md](./contracts/api.md), 화면은 [contracts/routes.md](./contracts/routes.md), 근거는 [research.md](./research.md).

## 준비

001 [quickstart](../001-blog-core/quickstart.md)의 "준비"와 002 [quickstart](../002-discovery-feeds/quickstart.md)의 추가 준비대로 MySQL(또는 Crowfoot 개발 DB `cf_u2_d2`), Mailpit, backend, front를 띄운다. 003에서 더할 것:

```bash
# 1) 첫 최고 관리자: 관리자 시나리오(US4·US5)는 SUPER_ADMIN 회원이 필요하다.
#    가입할 관리자 이메일을 backend 환경 변수로 주고 backend를 다시 띄우면, SUPER_ADMIN이 없을 때 그 회원을 지정한다(001 T154).
#    값은 .env에만 두고 커밋하지 않는다.
echo "BLOG_ADMIN_BOOTSTRAP_SUPER_ADMIN_EMAIL=<관리자 이메일>" >> blog/blog-backend/.env

# 2) 수동 검증용 포털 설정(로컬만). 새로 만든 계정은 가입 24시간이 지나야 포털에 나오고(FR-088),
#    포털 목록은 5분 캐시된다(FR-090). 시나리오를 바로 확인하려면 backend를 아래 값으로 띄운다.
#    운영·개발 DB에 system_settings 행이 있으면 그 값이 우선한다(관리자 콘솔 "포털 설정"에서 "기본값으로").
export BLOG_PORTAL_CACHE_TTL=0s
export BLOG_PORTAL_NEW_MEMBER_DELAY=PT0S
export BLOG_PORTAL_TOPIC_AUTO_HIDE_THRESHOLD=1

# 3) 계정 준비: /signup 으로 A(handle marco), B(handle reader), C(handle third)와 관리자 M(위 이메일) 네 회원을 만든다.
#    포털에 나오려면 본문 텍스트가 200자 이상이어야 한다(FR-088). 아래 시나리오의 "글"은 모두 200자 이상이다.
```

기동 로그에 `TopicSeeder`가 넣은 주제 수(처음 기동 때 대분류 5·소분류 39, 이후 0)가 남는지 확인한다.

## 자동 검증

```bash
cd blog/blog-backend && ./mvnw verify          # 슬라이스·H2 테스트 + JaCoCo 80%
# 릴리스 노트 검색(FULLTEXT)·일별 통계 동시 upsert 테스트(@MySqlRepositoryTest)는 BLOG_TEST_DATASOURCE_* 가 있을 때만 돈다(테스트 스키마 cf_u2_d3)
cd blog/blog-front && npm test -- --coverage   # Vitest 80%, 번역 누락 점검 포함
# E2E: backend를 위 2)의 값으로 띄운 뒤
cd blog/blog-front && E2E_BACKEND_URL=http://localhost:8080 E2E_PORTAL_TEST_SETTINGS=1 \
  E2E_ADMIN_EMAIL=<관리자 이메일> E2E_ADMIN_PASSWORD=<비밀번호> npm run e2e
```

## 수동 검증 시나리오

| # | 스토리 | 절차 | 기대 결과 |
|---|---|---|---|
| 1 | US1 | 비로그인으로 `/` (글이 하나도 없을 때) | 포털 영역 없이 "첫 글을 써 보세요" 안내와 가입 링크 (Edge Cases) |
| 2 | US1 | A·B·C가 주제·대표 이미지가 다른 공개 글을 모두 30편(A 14, B 10, C 6) 발행 → 비로그인 `/` | 위에서부터 (추천 없음이므로) 주제 탭, 인기 글, 최신 글 20편, 인기 태그, 새로 시작한 블로그(A·B·C) 순. 각 영역에서 같은 블로그 글은 2편 이하 (AS1, FR-080, SC-014) |
| 3 | US1 | 카드 하나를 살펴봄(대표 이미지 있는 글·없는 글) | 대표 이미지(없으면 주제 색 기본 이미지), 제목, 요약 2줄, 블로그 이름, 글쓴이 프로필 이미지, "N분 전", 좋아요·댓글 수. 누르면 `/{handle}/{id}` (AS2, FR-085) |
| 4 | US1 | `curl -s http://localhost:5173/` (스크립트 없이) | HTML에 카드 제목들, `<title>`·`description`·`og:title` 포함 (Independent Test, FR-094) |
| 5 | US1 | 최신 글 "더 보기" 클릭(JS 켬) → JS를 끄고 같은 링크 | 다음 20편이 이어서 붙음 / `/?cursor=...`로 이동해 다음 묶음이 SSR로 보임, `noindex` (AS4) |
| 6 | US1 | B로 A의 글 X를 열어 끝까지 스크롤, 좋아요, 댓글. C도 같은 글에 좋아요 → `/` | X가 인기 글 맨 앞쪽. `post_daily_stats`에 오늘 행(views·read_completes 증가) (AS3, FR-086) |
| 7 | US1 | 같은 브라우저로 X를 끝까지 두 번 더 읽음(30분 안) | `read_completes`가 1만 늘어 있음(중복 제거) |
| 8 | US1 | A가 글 하나를 비공개로, B가 글 하나를 휴지통으로, 관리자가 C를 정지(`UPDATE users SET status='SUSPENDED' ...`) → `/` | 세 경우의 글이 모든 영역에서 빠짐(캐시 0s. 기본 5m이면 5분 안) (AS5, SC-013) |
| 9 | US1 | 새 회원 D(가입 직후)가 공개 글 발행, `BLOG_PORTAL_NEW_MEMBER_DELAY`를 기본값(24h)으로 되돌려 재기동 → `/` | D의 글은 포털에 없고 `/d-handle`에는 있음 (Edge Cases, FR-088) |
| 10 | US1 | 본문 텍스트 150자인 공개 글 발행 → `/` | 그 글은 포털에 없음 (FR-088) |
| 11 | US2 | "IT 인터넷" 글 3편(A 2, B 1), "모바일" 글 1편, 주제 없는 글 1편 → `/topics/knowledge/it-internet`, `/topics/knowledge` | 각각 3편, 4편. 주제 없는 글은 둘 다 없음 (Independent Test, AS1, FR-078) |
| 12 | US2 | 주제 페이지에서 정렬을 "인기순" → 다시 "최신순" | 순서가 최근 7일 인기 점수 순으로 바뀜, 인기순 URL은 `noindex` (AS2) |
| 13 | US2 | `curl -s http://localhost:5173/topics/knowledge/it-internet` | `<title>IT 인터넷 - …`, description, 글 목록이 HTML에 포함 (AS3, FR-094) |
| 14 | US2 | `/topics/life/it-internet`(부모가 다름), `/topics/nope` | 404 화면 |
| 15 | US2 | 기준을 기본값(20)으로 되돌림 → `/` 주제 탭 → `/topics/sports` 직접 열기 | 글이 20편 미만인 대분류는 탭에서 빠지지만(고정된 `knowledge`는 보임) 주소는 정상으로 열림 (AS4, FR-147, SC-023) |
| 16 | US2 | `curl -s http://localhost:5173/sitemap/pages.xml` | 숨기지 않은 주제 페이지 주소 포함 (FR-094) |
| 17 | US3 | A의 블로그 설정에서 기본 주제 "국내여행" 저장 → `/marco/write` → 발행 설정 레이어 | "카테고리"와 "주제"가 따로 있고 주제에 "국내여행"이 미리 선택됨 (AS1, AS3) |
| 18 | US3 | 주제를 "선택 안 함"으로 바꿔 발행 → `/topics/travel-food/domestic-travel`, `/` | 주제 페이지에는 없고 최신 글에는 있음 (AS2, Independent Test) |
| 19 | US3 | 발행한 글의 주제를 "IT 인터넷"으로 바꿔 다시 발행 → `/topics/knowledge/it-internet` | 바로(캐시 0s) 그 페이지에 나옴 (AS5) |
| 20 | US3 | `curl`로 발행 설정 `topicId`에 대분류 id, 숨긴 주제 id, 없는 id | 422 `TOPIC_NOT_SELECTABLE`, 422, 404 `TOPIC_NOT_FOUND` |
| 21 | US3 | A의 블로그 설정에서 "포털에 내 글 노출"을 끄고 새 글 발행 → `/`, `/marco`, `/marco/rss`, `/search?q=` | 포털 어디에도 없고 블로그·RSS·검색에는 있음 (AS4, FR-089) |
| 22 | US4 | M으로 `/admin` → B로 `/admin`, `curl -b <B 쿠키> /api/v1/admin/topics` | M은 `/admin/topics` 주제 트리 / B는 404 화면, API 404 `NOT_FOUND` (006 FR-097) |
| 23 | US4 | M이 공개 글 3편을 추천으로 지정(종료 내일, 순서 2·1·3) → `/` | 맨 위 추천 영역에 순서 1·2·3대로 (AS1, Independent Test) |
| 24 | US4 | 추천 6번째를 같은 기간으로 지정 시도 / 가입 직후 회원의 글(지연 기본값일 때)을 추천 시도 | 409 `CURATION_LIMIT_EXCEEDED` / 422 `POST_NOT_PORTAL_ELIGIBLE` (FR-091) |
| 25 | US4 | 추천 글 하나를 A가 비공개로 전환 → `/`, 콘솔 추천 목록 | 메인 추천 영역에서 빠짐, 콘솔에는 "포털 노출 조건 없음" 표시 (AS2, FR-092) |
| 26 | US4 | `ends_at`을 지난 시각으로 고쳐 저장 → `/` | 추천 영역이 사라지고 다음 영역부터 보임 (AS5) |
| 27 | US4 | M이 글 하나를 사유 "광고성"으로 포털 제외 → `/`, 주제 페이지, `/marco`, `/search`, `/marco/rss` → 해제 | 포털 모든 영역에서 바로 빠지고 블로그·검색·RSS에는 그대로, 해제하면 다시 나옴 (AS4, FR-093) |
| 28 | US4 | M이 소분류 "캠핑·등산" 이름을 4개 언어로 바꾸고 순서를 맨 위로, "골프"를 숨김, 대분류 "스포츠"를 숨김 | 글쓰기 화면 주제 목록·메인 탭·`/topics/...`에 바로 반영, 숨긴 주제 주소는 404, 대분류를 숨기면 소분류도 고를 수 없음 (AS3, FR-079) |
| 29 | US4 | M이 slug 중복 주제 추가, 소분류 아래 주제 추가 시도 | 409 `TOPIC_SLUG_TAKEN`, 422 `TOPIC_DEPTH_EXCEEDED` |
| 30 | US4 | M이 포털 설정에서 좋아요 가중치 0, 최소 본문 길이 500 저장 → `/` → "기본값으로" | 좋아요만 많은 글의 순위가 내려가고 500자 미만 글이 빠짐 → 원래대로 (FR-086, FR-088) |
| 31 | US4 | DB `admin_audit_logs`에서 M의 작업 확인 | `TOPIC_UPDATE`, `TOPIC_REORDER`, `TOPIC_HIDE`, `CURATION_CREATE`, `PORTAL_EXCLUDE`, `PORTAL_UNEXCLUDE`, `SETTING_CHANGE`(target_key) 행과 전후 값 (006 FR-106) |
| 32 | US5 | M이 관리 API로 v1.2.0(ko·en), v1.2.1(ko), v1.3.0(ko) 만들기·게시(`POST /api/v1/admin/release-notes`, `/publish`) → 비로그인 `/` | 맨 위에 v1.3.0 카드, 누르면 `/updates/v1.3.0` (AS1, Independent Test) |
| 33 | US5 | `/updates` | 왼쪽 "1.3"(1.3.0)·"1.2"(1.2.1, 1.2.0) 트리, 오른쪽 v1.3.0 본문과 목차, canonical `/updates/v1.3.0` (AS3) |
| 34 | US5 | 목차 항목 클릭, `/updates/v1.2.0#새-기능` 직접 열기(JS 끔), 아래 이전·다음 링크 | 그 절로 이동, 이웃 버전으로 이동 (AS4) |
| 35 | US5 | 화면 언어를 일본어로 → `/updates/v1.2.0`, `/updates/v1.2.1` | v1.2.0은 영어판, v1.2.1은 한국어판이며 본문 위에 언어판 표시 (Independent Test, FR-161) |
| 36 | US5 | `/updates?q=기능`(2자 이상), `q=기`(1자) | 일치한 버전·제목·일치 부분이 새 버전부터 / 입력란 문구 (AS5, FR-165) |
| 37 | US5 | M이 v1.2.0을 두 번 고쳐 저장 → `/updates/v1.2.0` "수정 이력" → 이전 수정본 열기 | 수정본 번호·시각 목록(관리자 이름 없음), 이전 내용 (AS6, FR-166) |
| 38 | US5 | M이 v1.3.1 초안만 만든 뒤 비로그인으로 `/updates/v1.3.1` | 404 화면 (AS7) |
| 39 | US5 | B(가입이 v1.3.0 게시보다 먼저)로 로그인 → 상단 배너 닫기 → 다른 브라우저에서 B로 로그인 | 첫 화면에 v1.3.0 배너, 닫은 뒤 어느 브라우저에서도 다시 보이지 않음 (AS2, Independent Test) |
| 40 | US5 | v1.3.0 게시 뒤에 가입한 회원 E로 로그인 | 배너 없음(가입 전 게시 노트는 알리지 않음, FR-163) |
| 41 | US5 | M이 v1.3.0을 게시 중단 → `/`, `/updates/v1.3.0`, B·E 화면 | 카드는 v1.2.1(14일 이내면), v1.3.0 주소는 404, 배너는 남은 최신 버전 기준 (Edge Cases) |
| 42 | US5 | `curl -s http://localhost:5173/updates/v1.2.0`, `/sitemap/pages.xml` | 본문·제목·description이 HTML에 포함, 사이트맵에 게시 버전 주소 (FR-164) |
| 43 | 공통 | 4개 언어로 `/`, 주제 페이지, `/updates`, 콘솔 4개 화면, 발행 설정의 주제, 블로그 설정의 포털 항목 확인, `npm test`의 번역 누락 테스트 | 모든 문구가 화면 언어, 주제 이름도 화면 언어, 키 노출 없음, 누락 0건 |
| 44 | 성능 | 글 10만 편·회원 1만 데이터에서 `/`와 주제 페이지를 캐시 기본값(5m)으로 각 200회(`hey` 등, 도구는 저장소에 추가하지 않음), 캐시를 비운 첫 요청의 시간과 `EXPLAIN`도 기록 | p95 1초 이내 (SC-012). 결과와 plan.md "스키마 변경" 제안 인덱스 필요 여부를 PR 설명에 기록 |
