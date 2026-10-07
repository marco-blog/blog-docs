# Routes Contract: 007 외부 블로그 RSS 수집과 주제 자동 분류

007 화면의 loader·action·meta를 정한다. 경로 이름과 예약어의 기준 목록은 [001 contracts/routes.md](../../001-blog-core/contracts/routes.md)이며, 007의 화면은 모두 이미 있는 최상위 경로(`/admin/**`, `/:handle/manage/**`, `/manage`) 아래라 **새 예약어가 없다**. 메뉴 자리는 [006 contracts/routes.md](../../006-admin-consoles/contracts/routes.md)("외부 블로그 관리" `/admin/external-blogs`, 블로그 관리 "외부 블로그" `/external-blogs`, 둘 다 "007이 켬"). API 경로는 `/api/v1` 접두어를 뺀 것이다([api.md](./api.md)).

모든 화면은 SSR이고 폼은 `action`으로 동작한다(JS 없이 동작, 원칙 V). 화면 문구는 새 namespace `external`(4개 언어)과 기존 `portal`·`admin`·`manage`·`notification`·`errors`. 외부에서 온 블로그 이름·제목·요약은 번역하지 않고 이스케이프 출력만 한다.

## 블로그 관리: 외부 블로그 (회원)

회원의 외부 블로그는 회원에 속하므로 어느 블로그의 관리 화면에서 열어도 같은 목록이다(spec Assumptions). 레이아웃은 001 `/:handle/manage` 그대로(주인만, 아니면 404).

| 경로 | 화면 | 렌더링 | loader | action | meta |
|---|---|---|---|---|---|
| `/:handle/manage/external-blogs` | 내 외부 블로그 목록: 이름·피드 주소·상태 배지(승인 대기·거절(사유)·수집 중·일시 중지·자동 중지·차단·해제 — 남긴 글이 있으면 "해제 · 글 남김")·소유 인증 여부·마지막 수집 결과·글 수, "외부 블로그 등록 신청"(3개 한도면 비활성 + 안내), 이용 안내(제목·요약·썸네일만 포털에 노출, 원문 링크로 이동, 언제든 해제) | SSR | GET /me/external-blogs | - | noindex |
| `/:handle/manage/external-blogs/new` | 신청: (1) 주소 입력 → "미리보기"(블로그 이름·최근 글 3편, 이미 등록되어 있으면 "이미 등록된 블로그입니다" + 넘겨받기 가능 여부) → (2) 소유 인증(선택): "내 블로그입니다 — 인증하기"(코드 발급, 넣을 곳 안내: 새 글 또는 소개란, 24시간 유효, 복사 버튼) → "인증 확인"(찾은 곳·못 찾은 이유) / "건너뛰기(추천하는 다른 블로그)" → (3) 기본 주제(소분류, 003 주제 트리) → "신청". 이미 등록된 블로그를 인증했으면 "넘겨받기" | SSR(단계는 `?step=preview\|verify\|topic`와 숨은 입력, 미리보기 결과는 action 응답) | GET /topics | `intent=preview` → POST /external-blog-previews; `intent=issue-code` → POST /me/external-blog-verifications; `intent=check` → POST …/{id}/check; `intent=submit` → POST /me/external-blogs → 상세로 리다이렉트; `intent=claim` → POST /external-blogs/{id}/claim → 상세로 | noindex |
| `/:handle/manage/external-blogs/:id` | 상세: 상태와 안내(승인 대기·거절 사유·자동 중지면 마지막 실패 결과와 "피드가 다시 열리면 운영자가 재개합니다(문의: 서비스 안내 메일)" 안내 — 회원이 직접 재개하지는 않음, 결정 표 18번), 소유 인증(미인증이면 코드 발급·확인 — 인증되면 썸네일 노출과 주제 수정이 켜진다는 안내), 기본 주제 변경(인증된 주인), 수집된 글 표(제목 = 원문 새 탭 링크, 발행 시각, 주제 + 출처 표시(주인·검수·규칙·자동·기본), 상태, 클릭 수, 글별 주제 바꾸기 — 인증된 주인), 등록 해제 폼(필수 선택 라디오 두 개, 기본 선택 없음: "수집된 글 남기기 — 이미 수집된 글은 포털에 계속 보이고 새 글은 더 가져오지 않습니다" / "수집된 글 삭제 — 포털에서 바로 사라지며 되돌릴 수 없습니다", 결정 표 24번). 해제된 등록이면 폼 대신 "해제됨 · 남긴 글 N편이 포털에 보이는 중" 안내와 "남긴 글 삭제"(확인 문구, 남긴 글이 없으면 숨김), 주제 바꾸기는 숨김 | SSR | GET /me/external-blogs/{id}, GET /me/external-blogs/{id}/posts?page=, GET /topics | `intent=issue-code\|check\|claim\|default-topic\|post-topic\|release` | noindex |
| `/manage/external-blogs`, `/manage/external-blogs/:id` | (화면 없음) 최근 블로그(`last_blog` 쿠키, 001 `/manage`와 같은 규칙)의 같은 하위 경로로 리다이렉트. 알림 링크용 | 리다이렉트 | - | - | noindex |

- 블로그 관리 메뉴(006 `manage/links.ts`)의 "외부 블로그"를 `available: true`로. 006 머지 전이면 001 `routes/manage/layout.tsx`의 `MANAGE_MENU`에 같은 항목을 마지막에 더한다.
- 오류 문구: `EXTERNAL_FEED_URL_NOT_ALLOWED`(`params.reason`별 문구 — "우리 서비스 블로그는 등록할 수 없습니다", "내부망 주소는 등록할 수 없습니다" 등), `EXTERNAL_FEED_NOT_FOUND`("RSS·Atom 주소를 직접 넣어 보세요"), `EXTERNAL_FEED_UNREADABLE`(`params.result`별), `EXTERNAL_BLOG_ALREADY_REGISTERED`(넘겨받기 안내), `EXTERNAL_BLOG_LIMIT_EXCEEDED`, `EXTERNAL_VERIFICATION_*`, `TOO_MANY_REQUESTS`.

## 시스템 관리자 콘솔: 외부 블로그 관리

레이아웃은 003·006 `/admin` 그대로(관리자만, 아니면 404, noindex). 콘솔 메뉴(006 `admin/links.ts`)의 "외부 블로그 관리"를 `available: true`로 하고, 화면 안 하위 탭으로 아래 경로를 묶는다. 006 머지 전이면 003 `admin/links.ts`의 `ADMIN_MENU`에 항목을 더한다.

| 경로 | 화면 | 렌더링 | loader | action | meta |
|---|---|---|---|---|---|
| `/admin/external-blogs?status=&q=&page=` | 외부 블로그 목록: 상태 탭(승인 대기(수) 먼저·수집 중·일시 중지·자동 중지·차단·거절·해제·전체), 검색, 표(이름·피드 주소·등록 경로·신청 회원·소유 인증·상태·마지막 수집·연속 실패·검수 대기), "직접 등록" | SSR | GET /admin/external-blogs | - | noindex |
| `/admin/external-blogs/new` | 직접 등록: 피드 주소(또는 블로그 주소 → 미리보기), 기본 주제, 등록 근거(필수, 예시 "피드 공개 배포", "주인 허락 메일 2026-10-01") | SSR | GET /topics | `intent=preview` → POST /external-blog-previews(관리자도 회원이므로 같은 API); `intent=create` → POST /admin/external-blogs → 상세로 | noindex |
| `/admin/external-blogs/:id` | 상세: 등록 정보(경로·근거·회원·소유 인증·검토자), 수집 상태(다음 수집·마지막 결과·HTTP 상태·연속 실패·첫 실패), 동작 버튼(상태에 맞는 것만: 승인 / 거절(사유) / 일시 중지 / 재개 / 차단(사유, 확인 문구 "모든 글이 포털에서 내려가며 되돌릴 수 없습니다" — 글을 남기고 해제한 등록에도 보임, 같은 피드에 다른 활성 등록이 있으면 그 등록으로 가는 링크)), 기본 주제 변경, 수집된 글 표(상태 필터, 원문 링크, 주제·출처·분류 신뢰도, 클릭 수, "포털 제외"(사유)·"제외 해제", "내림"(사유)) | SSR | GET /admin/external-blogs/{id}, GET /admin/external-blogs/{id}/posts?status=&page=, GET /topics | `intent=approve\|reject\|pause\|resume\|block\|default-topic\|exclude\|unexclude\|remove` | noindex |
| `/admin/external-blogs/reviews?externalBlogId=&page=` | 분류 검수: 대기 목록(오래된 것 먼저) — 글 제목(원문 링크)·요약·피드 태그·블로그와 기본 주제·자동 분류 예측과 신뢰도·지금 노출 주제, 행마다 주제 선택(기본값 = 예측, 없으면 지금 주제) + "확정", 선택한 행 "일괄 확정"(최대 50) | SSR | GET /admin/classification-reviews, GET /topics | `intent=confirm\|confirm-batch` | noindex |
| `/admin/external-blogs/stats` | 분류 현황: 최근 30일 자동 분류 정확도(표본 수와 함께), 최종 주제 정확도(SC-019 근사, 정의 설명), 주제별 분포(출처별 막대 — 006 `DailyBarChart`가 아니라 표 + 막대 SVG), 검수 대기 수(검수 화면 링크), 지금 신뢰도 기준·분류 방식 버전, 계산 시각 | SSR | GET /admin/classification-stats, GET /topics | - | noindex |
| `/admin/external-blogs/rules?q=&page=` | 매핑 규칙: 목록(키워드·대상 주제·우선순위·만든 사람), 추가·수정·삭제, "규칙은 이후 수집되는 글에만 적용됩니다" 안내 | SSR | GET /admin/topic-mapping-rules, GET /topics | `intent=create\|update\|delete` | noindex |
| `/admin/external-blogs/settings` | 외부 블로그 설정: 수집 주기, 자동 분류 신뢰도 기준, 외부 글 인기 점수 가중치. 기본값 표시와 "기본값으로" | SSR | GET /admin/settings?prefix=external. | `intent=save\|reset`(key) → PUT·DELETE /admin/settings/{key} | noindex |

- 상태 배지·작업 이름은 `external:status.*`, 작업 기록 화면(006)의 작업 이름은 `audit:actions.EXTERNAL_*` 등 007 값 4개 언어(006 `audit` namespace에 추가).

## 포털 화면 변경 (003)

| 경로 | 변경 | 추가 API | meta 추가 |
|---|---|---|---|
| `/` | 최신 글 영역 위에 출처 필터(전체·내부 글만·외부 글만). JS 있으면 `/portal/latest?source=`로 그 영역만 다시 읽음, 없으면 `/?source=external` 링크(SSR이 최신 글 영역만 그 필터로). 인기·최신 카드에 외부 카드가 섞임 | GET /portal/latest?source= | `?source=`가 있으면 noindex(003의 `?cursor=` 규칙과 같음) |
| `/topics/:major`, `/topics/:major/:minor` | 정렬 옆에 같은 출처 필터(`?source=`) | GET /topics/{slug}/posts?source= | `?source=`가 있으면 noindex, canonical에서 제외 |
| 포털 카드(`components/portal/PortalCard.tsx`) | `source === "EXTERNAL"`이면: 카드 링크가 `visitUrl`(새 탭, `rel="noopener nofollow"`, `aria` 설명 "새 탭에서 원래 블로그로 이동"), 제목 옆 "외부" 배지, 블로그 이름 + 사이트 호스트(작성자 프로필 자리), 좋아요·댓글 수 숨김, 썸네일 없으면 주제 카드 색, 카드 아래 작은 "삭제 요청" 링크(로그인 회원: 005 신고 레이어 `targetType=EXTERNAL_POST`, 비로그인: `/rights-request?url={원문 링크}`). React 키 `${source}-${id}` | - | - |

- `/api/v1/external-posts/{id}/visit`는 front 프록시(001)가 그대로 backend로 넘긴다. backend가 404 JSON을 돌려주고 요청의 `Accept`가 `text/html`이면 프록시가 001 404 화면을 대신 보낸다(새 탭에 JSON이 보이지 않게, `server/middleware/backend-proxy.ts`의 이 경로 한 줄 규칙).
- 외부 카드의 썸네일 `/media/external/{key}`는 `/media/**` 프록시 그대로. CSP `img-src 'self'` 변경 없음.

## 001~006 화면 변경

| 경로 | 변경 | 추가 API | meta 추가 |
|---|---|---|---|
| `/notifications`, 알림 레이어(002) | `EXTERNAL_BLOG_APPROVED`·`EXTERNAL_BLOG_REJECTED`(사유 표시)·`EXTERNAL_FEED_STOPPED`(마지막 결과) 문구 4개 언어, 링크 `/manage/external-blogs/{id}` | - | - |
| 신고 레이어(005) | 대상 종류 `EXTERNAL_POST`·`EXTERNAL_BLOG` 문구(“외부 글”, “외부 블로그”) | - | - |
| `/admin/reports/**`(005) | 외부 글·외부 블로그 미리보기와 조치 버튼 "포털에서 내림", "외부 블로그 차단"(처리기가 주는 선택지) | - | - |
| `/admin/audit-log`(006) | 007 작업 이름(`audit:actions.EXTERNAL_*`, `TOPIC_MAPPING_RULE_*`, `CLASSIFICATION_CONFIRM`)과 대상 종류 이름, 대상 링크(`EXTERNAL_BLOG` → `/admin/external-blogs/{id}`) | - | - |
| 콘솔 대시보드(006) | 변경 없음(외부 블로그 신청 대기 수는 메뉴 배지로만 — 1.0은 목록 화면의 탭 수) | - | - |

## 검색 엔진 제외

모든 `/admin/**`, `/:handle/manage/**`, `/manage/**`는 기존 noindex(meta + 006 `X-Robots-Tag` + robots.txt)를 그대로 받는다. 클릭 이동 `/api/v1/external-posts/**`는 robots.txt `Disallow: /api/`(002)로 이미 막혀 있다.

## 프록시 (변경 1곳)

007의 새 API는 모두 `/api/**`, 썸네일은 `/media/**`라 001 `server/middleware/backend-proxy.ts`가 그대로 넘긴다. 변경은 위 "visit 404를 HTML 404 화면으로" 규칙 하나.
