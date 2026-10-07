# Quickstart: 007 외부 블로그 수집 검증 가이드

구현이 끝난 뒤 이 순서로 실행해 스펙이 동작함을 확인한다. 세부 API는 [contracts/api.md](./contracts/api.md), 화면은 [contracts/routes.md](./contracts/routes.md), 근거는 [research.md](./research.md).

## 준비

001 [quickstart](../001-blog-core/quickstart.md)의 "준비", 002~006 quickstart의 추가 준비대로 MySQL(또는 Crowfoot 개발 DB `cf_u2_d2`), Mailpit, backend, front를 띄운다. 007에서 더할 것:

```bash
# 1) 로컬 피드 스텁(인터넷의 실제 블로그를 쓰지 않는다). E2E와 같은 서버를 손으로 띄운다.
cd blog/blog-front && E2E_FEED_STUB_PORT=4610 node tests/e2e/support/feed-stub-server.mjs &
#    피드 하나 만들기: 이름 "alpha", 글 3편(그중 1편은 오늘, 2편은 40일 전), 태그 spring
curl -s -X POST localhost:4610/__stub/alpha -H 'content-type: application/json' \
  -d '{"title":"Alpha Dev","items":[{"n":1,"title":"Spring 4 정리","tags":["spring"],"daysAgo":0,"image":true},
       {"n":2,"title":"옛 글","daysAgo":40},{"n":3,"title":"오래된 글","daysAgo":45}]}'

# 2) backend가 스텁(127.0.0.1:4610)에 요청할 수 있게 하고(시험 전용, prod 금지), 수집을 빠르게 돌린다.
export BLOG_OUTBOUND_ALLOW_PRIVATE=true
export BLOG_OUTBOUND_ALLOWED_PORTS=80,443,8080,8443,4610
export BLOG_EXTERNAL_POLL_INTERVAL=2s BLOG_EXTERNAL_FETCH_INTERVAL=PT5S BLOG_EXTERNAL_FETCH_JITTER=PT0S
export BLOG_PORTAL_CACHE_TTL=0s            # 포털 반영을 바로 확인(003)
# SC-018(30분 주기, 1시간 안 노출)을 실제 주기로 확인할 때(#14)는 BLOG_EXTERNAL_FETCH_INTERVAL을 빼고 다시 띄운다.

# 3) 계정: A(회원, 블로그 marco), B(회원, 블로그 reader), M(관리자, 006 quickstart의 최고 관리자)
```

## 자동 검증

```bash
cd blog/blog-backend && ./mvnw verify          # 슬라이스·H2 테스트 + 외부 HTTP는 JDK 테스트 서버 + JaCoCo 80%
#   생성 컬럼 UNIQUE(active_feed_hash) 시험은 BLOG_TEST_DATASOURCE_URL(테스트 MySQL 스키마)이 있을 때만 돈다(002 방식, Testcontainers 없음)
cd blog/blog-front && npm test -- --coverage   # Vitest 80%, 번역 누락 점검(external namespace 포함)
# E2E: backend를 CI와 같은 값으로 띄운 뒤(결정 표 33번). 피드 스텁은 Playwright webServer가 띄운다.
cd blog/blog-front && E2E_BACKEND_URL=http://localhost:8080 E2E_ADMIN_EMAIL=... E2E_ADMIN_PASSWORD=... \
  E2E_PORTAL_TEST_SETTINGS=1 E2E_GUEST_TEST_SETTINGS=1 E2E_EXTERNAL_TEST_SETTINGS=1 E2E_FEED_STUB_PORT=4610 npm run e2e
```

## 수동 검증 시나리오

### US1 등록과 인증

1. A로 `/marco/manage/external-blogs` → "등록 신청" → `http://127.0.0.1:4610/alpha/`(블로그 주소) 입력 → 미리보기에 "Alpha Dev"와 최근 글 3편(피드 순서), 피드 주소가 `…/alpha/feed.xml`로 찾아짐 (US1 AS1, FR-109)
2. "내 블로그입니다 — 인증하기" → `java21-verify-…` 코드와 "24시간 유효" 안내. 같은 화면을 다시 열어도 같은 코드 (FR-110)
3. 코드를 넣기 전에 "인증 확인" → "피드와 블로그 페이지에서 코드를 찾지 못했습니다"(찾은 곳 2곳 표시). 스텁에 `{"verifyCode":"<코드>"}`를 넣고 다시 확인 → 인증 완료 (US1 AS3)
4. 기본 주제 "IT 인터넷" → "신청" → 상세에 "승인 대기", 소유 인증됨 (US1 AS4)
5. B로 같은 주소 신청 → "이미 등록된 블로그입니다"(넘겨받기는 소유 인증 후) (US1 AS5, FR-112)
6. M으로 `/admin/external-blogs` → 승인 대기 탭에 A의 신청(소유 인증 표시) → 승인 → 몇 초 뒤 상세 "수집된 글"에 1편만(40일·45일 전 글은 최초 수집 30일 범위 밖) (US1 AS6, FR-113)
7. A의 알림에 "외부 블로그 등록이 승인되었습니다". 다른 피드 "beta"로 신청하고 M이 사유와 함께 거절 → A 알림에 사유 (FR-111)
8. M이 `/admin/external-blogs/new`에서 스텁 "gamma" 피드 + 기본 주제 + 등록 근거 "피드 공개 배포" → 바로 "수집 중", 작업 기록 `EXTERNAL_BLOG_CREATE` (US1 AS7)
9. B가 "gamma" 신청 → "이미 등록됨 · 넘겨받기 가능" → 스텁 "gamma"에 B의 코드를 넣고 인증 → "넘겨받기" → B의 목록에 gamma(소유 인증됨) (US1 AS8, FR-129)
10. A가 피드 3개를 더 신청하려 하면 3번째 이후 "외부 블로그는 3개까지" (FR-112)
11. 주소 거부: `http://localhost:5173/marco/rss`(우리 서비스) → "우리 서비스 블로그는 등록할 수 없습니다", `ftp://…` → 형식 오류, 존재하지 않는 경로 → "RSS·Atom을 찾지 못했습니다" (Edge Cases, FR-116)

### US2 포털 노출

12. `/`(포털) 최신 글에 alpha 글 카드: "외부" 배지, 제목·요약(200자 이하, 태그 없음), 블로그 이름 "Alpha Dev"·호스트, 썸네일(A가 소유 인증했으므로 `/media/external/…`), 좋아요·댓글 수 없음 (US2 AS1, FR-123, FR-128)
13. 카드를 누르면 새 탭에서 스텁의 원문 `…/alpha/posts/1`로 이동. M의 콘솔 상세에서 클릭 수 1, 같은 브라우저로 바로 다시 눌러도 1 (US2 AS2, FR-124)
14. 스텁에 새 글을 더하면 수집 주기(시험 5초, 운영 30분) 안에 포털 최신 맨 위에 나옴. 운영 주기로 띄우면 1시간 안 (SC-018)
15. M이 스텁 "delta"(이미지 있는 글)를 직접 등록(소유 인증 없음) → delta 카드는 썸네일 없이 주제 카드 색, 스텁 접근 기록에 이미지 요청 0건 (FR-128)
16. 주제 결정: M이 매핑 규칙 "spring → IT 인터넷"을 두고, 스텁에 태그 `spring` 글·키워드 없는 글·"요리 레시피" 글을 더함 → 콘솔 글 표의 출처가 각각 규칙·기본(검수 대기)·자동(또는 기본+검수) (US2 AS3, FR-118, FR-119)
17. `/topics/it-internet`(IT 인터넷)에 alpha 글이 내부 글과 섞여 발행 최신순. "외부 글만"·"내부 글만" 필터가 동작하고 주소가 `?source=` (FR-123, FR-124)
18. 한 외부 블로그에 새 글 5편 → 포털 메인 최신에는 2편까지 (FR-123 → 003 FR-080)
19. `/search?q=Alpha`, `/marco/rss`, `/sitemap.xml`에 외부 글 없음 (FR-125)
20. 스텁에서 `alpha/posts/1`을 지움 → 원문 링크 점검(시험용으로 `BLOG_EXTERNAL_LINK_CHECK_CRON="*/10 * * * * *"`로 backend를 다시 띄우면 10초마다) → 그 글이 포털에서 사라지고 콘솔에 "내림 · 원문 없음" (US2 AS4, FR-117)
21. 콘솔 `/admin/external-blogs/settings`에서 외부 글 가중치 0 → 포털 인기 글에서 외부 글이 빠짐, 되돌리면 다시 (US2 AS5, FR-124)

### US3 분류 개선과 검수

22. A가 상세의 수집된 글 표에서 alpha 글 주제를 "여행"으로 바꿈 → 포털 `/topics/travel`에 바로 나옴, 출처 "주인". 같은 글이 피드에서 수정되어 다시 와도 주제 유지 (US3 AS1, FR-120)
23. 소유 인증 없는 회원(신청만 한 회원)에게는 주제 바꾸기가 보이지 않고 API는 403 (결정 표 18번)
24. M의 `/admin/external-blogs/reviews`에 #16의 키워드 없는 글이 "예측 없음 · 신뢰도 0"으로 대기. 주제 확정 → 포털 반영, 출처 "검수" (US3 AS2·AS3)
25. 일괄 확정: 대기 3개 선택 → 확정 → 작업 기록 3행 `CLASSIFICATION_CONFIRM`
26. `/admin/external-blogs/stats`에 정확도(표본 수)·주제별 분포·검수 대기 수 (US3 AS4, FR-122)
27. 매핑 규칙 "react → IT 인터넷" 추가 → 이미 수집된 react 글은 그대로, 이후 수집 글에만 적용 (US3 AS5)

### US4 해제와 운영

28. A가 alpha를 "수집된 글도 지금 삭제" 없이 해제 → 포털에서 바로 사라짐(캐시 무효화), 상세에 "해제". 다시 신청 가능 (US4 AS1, SC-020)
29. B가 gamma를 "수집된 글도 지금 삭제"와 함께 해제 → 콘솔 글 표가 비고 썸네일 파일도 지워짐 (FR-126)
30. M이 delta 일시 중지 → 수집 멈춤(스텁에 새 글을 더해도 안 나옴), 기존 글은 포털에 그대로 → 재개 → 새 글 수집 (US4 AS2)
31. M이 delta 차단(사유) → 포털에서 모두 사라짐, 같은 피드를 다시 신청하면 "이미 등록됨 · 넘겨받기 불가" (US4 AS2, FR-127)
32. (005 머지 후) B가 포털의 외부 카드 "삭제 요청" → 신고 레이어(외부 글) → M이 신고 처리 "포털에서 내림" → 사라짐. 로그아웃 상태의 "삭제 요청"은 `/rights-request?url=원문`으로 열리고, 접수된 신고의 대상이 그 외부 글로 채워짐 (US4 AS3, FR-129)
33. 스텁 "epsilon"을 500 응답으로 바꿈 → 콘솔에 연속 실패 수가 늘고 다음 수집이 30분→1시간…으로 늦춰짐. 시험용으로 `BLOG_EXTERNAL_STOP_AFTER=PT1M`으로 띄우면 1분 뒤 "자동 중지"와 관리 회원 알림 "외부 블로그 수집이 중지되었습니다" (US4 AS4, FR-117)
34. 외부 블로그를 가진 회원 C가 탈퇴 → C의 외부 블로그가 해제되고 글이 포털에서 사라짐. 다른 회원이 같은 피드를 새로 신청할 수 있음 (FR-157, SC-020)

### 보안·공통

35. 스텁에 `/evil/feed.xml`이 `http://169.254.169.254/` 로 리다이렉트하도록 두고, `BLOG_OUTBOUND_ALLOW_PRIVATE` 없이 backend를 다시 띄워 신청 → "내부망 주소는 등록할 수 없습니다"(스텁 자체도 127.0.0.1이라 이 상태에서는 모든 스텁 신청이 거부됨을 함께 확인) (FR-116, research E2)
36. 스텁 피드에 `<!DOCTYPE … SYSTEM "file:///etc/passwd">`가 있으면 수집 실패 `PARSE_ERROR`(파일 내용이 어디에도 없음), 3MB 피드는 `TOO_LARGE`, 4번 리다이렉트는 `HTTP_ERROR` (research E2·E3)
37. 피드 요약에 `<script>alert(1)</script><img src=x onerror=alert(2)>`를 넣어도 포털 카드에 글자로도 실행으로도 나오지 않음(태그 제거 텍스트만) (SC-021, 원칙 IV)
38. 본문 50KB 피드를 수집한 뒤 DB `external_posts.summary` 길이 200자 이하, 다른 컬럼에 본문 없음 (SC-021)
39. 화면 언어 en·ja·zh-CN에서 외부 블로그 화면·상태·오류·알림 문구가 그 언어, 외부 블로그 이름·제목은 원문 그대로 (원칙 VII)
40. 폭 360px에서 신청 단계·상세·콘솔 목록이 가로 스크롤 없이 동작(표는 가로 스크롤 상자 안)
