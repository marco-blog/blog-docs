# Route Contract: 005 트랙백과 운영 (front)

005 화면의 loader·action·meta를 정한다. 경로 이름과 예약어의 기준 목록은 [001 contracts/routes.md](../../001-blog-core/contracts/routes.md)이며, 005의 경로(`/rights-request`, `/:handle/manage/trackbacks`, `POST /:handle/:postId/trackback` 프록시, `/admin/**`)와 예약어(`report`, `reports`, `rights-request`, `trackback`)는 이미 그 목록·backend `ReservedHandles`·front 프록시에 있다. 새 예약어는 없다(`tests/unit/routes/reservedPaths.test.ts`가 `rights-request`를 이미 확인).

## 새 화면

| 경로 | 화면 | 렌더링 | loader 호출 API | action | meta |
|---|---|---|---|---|---|
| `/rights-request` | 권리 침해 신고 양식: 대상 주소(쿼리 `?url=`로 미리 채움), 사유(저작권·개인정보·명예훼손·기타), 권리 근거, 연락 이메일, 개인정보 수집 안내(보관 1년), CAPTCHA, 제출 후 "접수되었습니다. 처리 결과는 이메일로 안내합니다" | SSR(폼은 `action`) | GET /captcha/config | POST /rights-requests → 같은 화면 `?submitted=1` | `{권리 침해 신고}`, `noindex` |
| `/:handle/manage/trackbacks?page=` | 받은 트랙백: 받은 글 제목·보낸 글 제목·요약·블로그 이름·주소·받은 시각, "삭제"(확인), 관리자가 숨긴 트랙백은 "숨김" 표시·삭제 불가. 위쪽에 "트랙백 받기" 상태와 설정 링크 | SSR(폼은 `action`) | GET /blogs/{handle}/manage/trackbacks?page= | `intent=delete` → DELETE /trackbacks/{id} | noindex |
| `/admin/reports?status=&targetType=&page=` | 신고 관리: 대기·조치·기각 탭, 대상 종류 거르기, 대상별 묶음 표(대상 미리보기, 신고 수, 사유별 수, 첫 접수), 권리 침해는 "권리 침해" 표시, 행을 누르면 상세 | SSR | GET /admin/reports | - | noindex |
| `/admin/reports/:id` | 신고 상세: 대상 미리보기와 "원래 화면 열기" 링크, 같은 대상의 신고 목록(신고자·사유·설명·시각), 권리 침해면 주소·근거·연락 이메일, 대상 미정이면 "대상 지정"(주소 또는 종류+id), 처리 폼("숨김", "작성자 정지"(사유), "기각", 메모), 처리된 신고는 결과와 "숨김 해제" | SSR(폼은 `action`) | GET /admin/reports/{id} | `intent=target\|resolve\|unhide` → PATCH …/target, POST …/resolve, DELETE /admin/contents/{type}/{id}/hidden | noindex |
| `/admin/users?q=&by=&page=` | 회원 관리: 검색(이메일 정확·닉네임 앞부분·블로그 주소 정확), 결과 표(닉네임·상태·권한·가입일·블로그 수) | SSR | GET /admin/users | - | noindex |
| `/admin/users/:id` | 회원 상세: 가입일·상태·권한·글 수·받은 신고 수·최근 로그인·블로그 목록과 수/한도(003 한도 API의 폼), "정지"(사유 필수, 확인)·"정지 해제" | SSR(폼은 `action`) | GET /admin/users/{id} | `intent=suspend\|unsuspend\|blogLimit` | noindex |
| `/admin/spam` | 스팸 방어 설정: 작성 속도 한도 5개와 반복 댓글 기준(현재 값·기본값·바꾼 관리자, "기본값으로"), 금칙어 목록(검색·추가·적용 범위/처리 방식 변경·삭제) | SSR(폼은 `action`) | GET /admin/settings?prefix=ratelimit., GET /admin/settings?prefix=spam., GET /admin/banned-words?q=&page= | `intent=setting\|resetSetting\|addWord\|updateWord\|deleteWord` | noindex |
| `/admin/contents/hidden-posts?page=` | 숨긴 글 목록(제목·블로그·숨긴 시각), "숨김 해제" | SSR(폼은 `action`) | GET /admin/contents/hidden-posts | `intent=unhide` | noindex |

- 콘솔 좌측 메뉴(`routes/admin/layout.tsx`, `app/admin/links.ts`)에 "회원 관리", "신고 관리"(처리 대기 수 배지, `GET /admin/reports/summary`), "숨긴 글", "스팸 방어 설정"을 006 spec 메뉴 순서대로 더한다. 003은 블로그 한도 API(`PATCH /admin/users/{id}/blog-limit`)만 있고 화면이 없으므로 회원 상세에 한도 폼을 둔다.
- 관리자가 아니면 003 `admin/access.server.ts`가 404 화면(존재를 드러내지 않음).
- 블로그 관리 좌측 메뉴(`routes/manage/layout.tsx`, `app/manage/links.ts`)에 "받은 트랙백"(006 spec 블로그 관리 메뉴 순서). 구현은 006 FR-099 순서대로 통계 다음이다(T104의 "댓글 다음"이 아님).

## "이용이 제한된 블로그" 화면

| 위치 | 동작 |
|---|---|
| 004 공개 블로그 레이아웃 `routes/blog/layout.tsx` loader | `GET /blogs/{handle}`이 404 `BLOG_RESTRICTED`면 `data({ restricted: true }, { status: 404 })`를 돌려주고, 레이아웃이 자식 대신 `components/blog/RestrictedBlog.tsx`("이용이 제한된 블로그입니다. 운영 정책에 따라 이 블로그는 지금 볼 수 없습니다.")를 그린다. 사이드바·방문 기록 없음. `BLOG_NOT_FOUND`는 지금처럼 404 화면 |
| meta | `{이용이 제한된 블로그}`, `noindex` |
| 레이아웃 밖 `:handle/write`, `:handle/manage` | 정지 회원은 로그인할 수 없으므로 영향 없음 |

## 001~004 화면 변경

| 경로 | 변경 | 추가 API | meta 추가 |
|---|---|---|---|
| `/:handle/:postId` (글 상세) | 글 아래(댓글 위)에 "트랙백" 영역: 이 글의 트랙백 주소와 "복사"(JS 없으면 선택 가능한 입력란), 받은 트랙백 목록(제목 링크 `rel="nofollow ugc noopener"`·요약·블로그 이름·시각, 최신 10개 + "더 보기" `?tbPage=`), `trackbackUrl`이 null이면 주소 대신 "트랙백을 받지 않는 글". HTML 주석으로 TrackBack RDF(자동 발견). 로그인 회원(주인 제외)에게 "신고" 버튼(글·각 트랙백). 주인에게 숨긴 글이면 상단 "관리자가 숨긴 글입니다" 안내 | GET /posts/{id}/trackbacks?page=, POST /reports | 숨긴 글(주인)은 `noindex` |
| `/:handle/:postId` 댓글, `/:handle/guestbook` | 각 항목에 "신고"(로그인 회원, 자기 글 제외) → 사유 선택 레이어(JS 없으면 `?report=comment-{id}` 폼 화면), 항목 앵커 `#comment-{id}`·`#guestbook-{id}`·`#trackback-{id}`(권리 침해 주소 해석용). 숨긴 내 댓글·방명록 글은 "관리자가 숨긴 글입니다" 표시. 비회원 쓰기 폼에 CAPTCHA. 금칙어·반복 스팸·속도 제한 오류 문구 | POST /reports, GET /captcha/config | - |
| 신고 레이어 공통 | 사유 8개 라디오, 설명(기타면 필수), "신고"·"취소". 접수 후 "신고가 접수되었습니다", 이미 신고했으면 "이미 신고한 콘텐츠입니다". 화면 아래 "회원이 아니신가요? 권리 침해 신고" 링크(`/rights-request?url=`) | - | - |
| `/:handle/write` 발행 설정 레이어 | "트랙백 보내기" 입력(주소 한 줄에 하나, 최대 10개, 공개 범위가 공개일 때만 활성), 이미 보낸 주소별 결과(성공·실패와 이유, 보내는 중) | GET /posts/{id}/trackback-pings | - |
| `/:handle/manage/posts` | 상태 필터 "숨김", 숨긴 글 "숨김" 표시(발행 설정·공개 범위 변경 버튼 비활성), 글마다 "트랙백 결과" 펼침 | GET /posts/{id}/trackback-pings | - |
| `/:handle/manage/settings` | "트랙백 받기"(기본 켜짐, 끄면 새 트랙백을 받지 않고 받은 것은 남는다는 안내). 블로그 제목 금칙어 오류 | PATCH /blogs/{handle} `{ trackbackEnabled }` | - |
| `/signup` | CAPTCHA, 닉네임·블로그 주소 금칙어 오류, 가입 한도 429 문구 | GET /captcha/config | - |
| `/login` | backend가 `CAPTCHA_REQUIRED`를 주면 같은 화면에 CAPTCHA를 보이고 다시 로그인 | GET /captcha/config | - |
| `/settings/profile`, `/settings/blogs` | 닉네임·블로그 주소·제목 금칙어 오류 | - | - |
| `/notifications` | `REPORT_RESOLVED` 문구("신고하신 콘텐츠를 검토해 조치했습니다" / "…검토했으나 조치하지 않았습니다"), 링크 없음 | - | - |
| 글쓰기 이미지 업로드 | 429 문구("잠시 후 다시 올려 주세요") | - | - |

- CAPTCHA 컴포넌트(`components/captcha/Captcha.tsx`): `turnstile`이면 Cloudflare 스크립트를 그 화면에서만 CSP nonce와 함께 넣고 위젯이 채운 토큰을 숨은 입력 `captchaToken`으로 보낸다. `test`면 "시험 모드" 표시와 숨은 입력(값은 front 환경 변수 `BLOG_CAPTCHA_TEST_TOKEN`, 기본 `e2e-pass`), `none`이면 아무것도 그리지 않는다. JS가 없으면 Turnstile 위젯이 동작하지 않으므로 "자바스크립트를 켜야 합니다" 안내(`<noscript>`).
- 보안 헤더(001 `app/server/securityHeaders.ts`): provider가 `turnstile`일 때 `script-src`·`frame-src`·`connect-src`에 `https://challenges.cloudflare.com`.
- 트랙백·신고·관리 화면의 사용자 입력(트랙백 제목·요약·블로그 이름, 신고 설명, 권리 근거)은 모두 텍스트로 출력한다(`dangerouslySetInnerHTML` 없음). 트랙백 주소 링크는 `http(s):`만 링크로, 그 밖은 텍스트로.
- 날짜·시각은 001 규칙대로 회원 시간대(관리자도 자기 시간대)로 표시한다.

## 프록시 (변경 없음)

트랙백 받기 `POST /:handle/:postId/trackback`은 001 `blog-front/server/middleware/backend-proxy.ts`가 이미 backend로 넘긴다(본문·`Content-Type`·charset을 바꾸지 않고 그대로, 방문자 IP는 `X-Forwarded-For`). 새 API는 모두 `/api/**`라 그대로 넘어간다. 프록시가 트랙백 본문을 그대로 넘기는지(EUC-KR 바이트 보존) 단위 테스트를 더한다.

## 사이트맵·피드 (변경 없음, 확인만)

숨긴 글과 정지 회원 글은 PUBLISHED·ACTIVE 조건으로 사이트맵·피드에서 이미 빠진다(002). 005는 코드를 바꾸지 않고 통합 테스트로 확인한다(tasks.md Polish). `/rights-request`는 사이트맵에 넣지 않는다.
