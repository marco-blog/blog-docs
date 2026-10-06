# Research: 001 블로그 핵심

> R15~R21은 002·004·005 스펙용으로(R15·R21은 002, R17~R20은 004, R16은 005) 미리 조사한 내용이다. R9(검색, 002 FR-035)와 R10의 인기 글 부분(003 FR-034·086)도 해당 스펙의 결정이다. 이들은 해당 스펙의 `/speckit-plan` 때 그 스펙의 research.md로 옮긴다. R22~R28은 001의 결정이다.
>
> 모든 API 경로는 `/api/v1` 접두어를 쓴다(contracts/api.md).

버전 확인일: 2026-10-06 (Maven Central, npm 레지스트리 기준)

## R1. backend 프레임워크 버전
- **Decision**: Spring Boot 4.1.x(확인 시점 최신 정식 4.1.1), Java 21, Maven Wrapper.
- **Rationale**: 사용자 결정(Spring Boot 4). 4.2는 마일스톤 단계라 제외.
- **Alternatives**: 3.5.x(더 많은 레퍼런스지만 사용자 결정과 다름).
- **주의**: Boot 4에서 테스트 슬라이스가 모듈별 스타터로 나뉘었다(`spring-boot-starter-webmvc-test`, `spring-boot-starter-data-jpa-test` 등). `@MockBean`은 제거되어 `@MockitoBean`을 쓴다.

## R2. 인증 토큰 설계 (FR-004~007, SC-006)
- **Decision**:
  - 접근 토큰: JWT(HS256, jjwt 0.13), 만료 30분, 클레임은 userId·role만. role 클레임은 화면 메뉴 표시용 힌트이며, 관리자 API(`/api/v1/admin/**`)는 요청마다 DB의 현재 role·status를 다시 확인한다(권한 회수는 다음 요청부터 적용, 006 Edge Cases). 일반 API의 소유자 검증은 userId로 한다.
  - 리프레시 토큰: 무작위 256비트 불투명 문자열, DB에는 SHA-256 해시만 저장. `/api/v1/auth/refresh`를 쓸 때마다 새 리프레시 토큰을 발급하고 이전 것은 사용 처리(rotation). 유휴 만료는 발급 후 4시간, 절대 만료는 로그인 계열(family) 최초 발급 후 7일.
  - 재사용 감지: 이미 사용·폐기된 리프레시 토큰이 다시 오면 같은 family의 토큰을 모두 폐기(탈취 대응).
  - 두 토큰 모두 `HttpOnly; Secure; SameSite=Lax` 쿠키. 리프레시 쿠키는 `Path=/api/v1/auth`(이 경로가 다르면 브라우저가 리프레시 쿠키를 보내지 않는다).
  - 로그아웃 시 해당 family 폐기(FR-006). 회원 정지·탈퇴 시 그 회원의 모든 family 폐기.
  - 동시 요청 경합: 여러 탭이 동시에 리프레시하면 하나만 성공하고 나머지가 재사용으로 오인될 수 있으므로, 사용 처리 후 10초 동안은 같은 토큰 재요청에 방금 발급한 토큰을 다시 돌려준다(유예 기간).
- **Rationale**: 고정 4시간 만료는 긴 글 작성 중 강제 로그아웃을 만든다(2026-10-06 사용자 승인으로 회전 방식 채택). 쿠키 방식이라 SSR 첫 요청에서도 로그인 상태를 렌더링할 수 있다.
- **Alternatives**: 고정 4시간 만료(작성 중 로그아웃), Authorization 헤더 + localStorage(SSR 불가, XSS 취약), 리프레시도 JWT(즉시 폐기 불가).

## R3. CSRF
- **Decision**: 쿠키 인증이므로 상태 변경 요청(POST/PUT/PATCH/DELETE)에 대해 `Origin` 헤더가 `https://blog.java21.net`(개발 시 설정값)인지 backend 필터에서 검사. SameSite=Lax와 함께 사용.
- **예외**: 외부 블로그 서버가 보내는 트랙백 핑 `POST /{handle}/{postId}/trackback`(005, R16)은 Origin 검사에서 제외한다. 쿠키 인증을 쓰지 않는 공개 수신 엔드포인트라 CSRF 대상이 아니며, 출처 IP 속도 제한과 입력 검증으로 보호한다. 예외 경로는 필터의 명시적 목록 하나로만 관리한다.
- **Alternatives**: Spring Security CSRF 토큰(SSR·SPA 양쪽에 토큰 전달 로직이 늘어남).

## R4. 도메인과 프록시
- **Decision**: 브라우저는 `blog.java21.net`(front 서버)만 호출. front 서버가 `/api/**`, `/media/**`, 피드·트랙백 경로를 backend로 프록시(React Router framework의 커스텀 Express 서버 엔트리 사용). SSR 중 `loader`는 내부 주소로 backend를 직접 호출하며 요청 쿠키를 전달.
- **Rationale**: 쿠키가 같은 출처로 유지되어 CORS가 필요 없다. 원칙 II(두 파트) 유지.

## R5. 블로그 주소 라우팅과 예약어 (FR-002, FR-022)
- **Decision**: `/{handle}`와 `/{handle}/{postId}`는 front 라우트에서 가장 마지막 우선순위로 매칭. `postId`는 숫자(`\d+`)만 매칭해 `/{handle}/rss`, `/{handle}/guestbook` 같은 블로그별 하위 경로와 겹치지 않게 한다. 예약어 목록은 backend `blog` 패키지의 코드 상수 하나로만 관리하고(관리자 화면에서 추가하지 않음, 006은 읽기 전용 표시), front 최상위 라우트를 추가할 때 같은 PR에서 이 목록에 같이 추가한다. 001~007 전체 경로와 예약어의 기준 목록은 contracts/routes.md.
- **handle 규칙**: `^[a-z0-9](?:[a-z0-9-]{1,18})[a-z0-9]$`, 연속 하이픈 금지.

## R6. 프런트 SSR 구성
- **Decision**: React Router 8 framework 모드(`@react-router/dev` Vite 플러그인). 라우트 모듈의 `loader`(서버 데이터 조회), `action`(폼 처리), `meta`(title·description·Open Graph), `links`(피드 자동 발견 `<link rel="alternate">`)를 사용. 운영은 `react-router build` 산출물을 커스텀 Express 서버(`@react-router/express`)로 띄워 프록시와 함께 제공.
- **Rationale**: Vite 위에서 동작해 "Vite + React" 조건을 지키면서 데이터 선로딩·hydration·스트리밍·head 관리·에러 경계가 기본 제공된다(2026-10-06 사용자 승인). 직접 만든 Vite SSR 대비 작성·유지 코드가 크게 줄어든다.
- **Alternatives**: Vite 공식 SSR 예제 기반 직접 구현(위 기능을 모두 손으로 작성), Next.js(Vite 아님).

## R7. 에디터 (FR-014)
- **Decision**: Milkdown Crepe(`@milkdown/crepe` 7.x). Markdown이 원본 형식이며 입력 즉시 서식 렌더링, `/` 슬래시 명령과 선택 시 플로팅 툴바만 쓰고 상단 고정 툴바는 쓰지 않는다. 이미지 업로드 훅에서 `POST /api/v1/media`(임시 업로드)를 호출해 `/media/{key}`를 넣는다. 에디터 메뉴·플레이스홀더 문구는 Crepe의 문구 설정에 화면 언어의 번역(R22)을 넣는다(4개 언어). 작성 화면에서만 클라이언트 지연 로딩(`clientLoader`/`lazy`), SSR 제외.
- **Rationale**: TOAST UI Editor는 2023-02 이후 릴리스가 없고 React 래퍼가 React 17 전용이다. 사용자가 CKEditor식 큰 툴바를 원하지 않아 MDXEditor(툴바 중심)를 제외. Milkdown은 2026-09에도 릴리스되는 활발한 프로젝트.
- **Alternatives**: @uiw/react-md-editor(분할 미리보기, WYSIWYG 없음 — 사용자가 분할 방식을 원하면 교체), MDXEditor(툴바 중심), Tiptap + Markdown 확장(구성 작업 많음), TOAST UI(유지보수 중단).
- **교체 대비**: `components/Editor` 래퍼 인터페이스(`value`, `onChange`, `onUploadImage`)를 고정해 에디터를 바꿔도 화면 코드는 그대로 둔다.

## R8. Markdown 변환과 XSS (FR-021)
- **Decision**: 저장 시 backend에서 commonmark-java(GFM 테이블·취소선 확장)로 HTML 변환 후 OWASP Java HTML Sanitizer로 허용 태그만 남겨 `content_html`에 저장. 조회 시 변환 없이 그대로 사용. 댓글은 Markdown 없이 텍스트로 저장하고 출력 시 이스케이프. 코드 블록은 `<pre><code class="language-xxx">`로 남기고(살균 정책이 `language-[a-z0-9+#-]+` class만 허용) 문법 강조는 front가 한다(R24). 동영상 iframe 허용 목록은 R25.
- **Rationale**: 변환 비용을 쓰기 시점에 한 번만 낸다. 살균을 서버 한 곳에서 하므로 front는 신뢰된 HTML만 받는다.

## R9. 검색 (FR-035, SC-007)
- **Decision**: MySQL FULLTEXT(ngram 파서, token size 2)를 `post(title, content_text)`와 태그 이름에 적용. `content_text`는 HTML에서 태그를 뺀 순수 텍스트.
- **Alternatives**: Elasticsearch(원칙 VI 위반, 별도 인프라), LIKE 검색(10만 건에서 2초 목표 불확실).

## R10. 조회수와 인기 글 (FR-020, 003 FR-034·086)
- **Decision**: 조회 중복 판단은 Caffeine 캐시(키: postId + 회원 ID 또는 방문자 쿠키 ID, TTL 30분). 집계는 `post.view_count` 증가 + `post_daily_stat(post_id, stat_date, views, likes)` upsert. ~~인기 글은 최근 7일 `views + likes*10` 합계 상위~~ → **대체됨**: 인기 점수 공식은 003 FR-086(조회 수만으로 정하지 않고 끝까지 읽음·좋아요·댓글 가중, 시간 감쇠, 운영자 조정)을 따르며 003의 plan/research에서 정한다. 외부 글은 007 FR-124. 결과를 Caffeine에 5분 캐시하는 방식만 유지.
- **Rationale**: 단일 서버 전제(SC-003 규모)에서 충분. 서버가 늘면 Redis로 교체(그때 ADR 갱신).

## R11. 첨부 파일 저장과 썸네일 (FR-038, FR-039, FR-071~074, FR-130~132, FR-156)
- **Decision**:
  - 설정은 `@ConfigurationProperties(prefix = "blog.media")` 레코드 하나로 관리:
    ```yaml
    blog:
      media:
        upload-dir: /var/blog/media        # 정식 보관
        temp-dir: /var/blog/media-tmp      # 임시 보관
        temp-ttl: 24h
        cleanup-cron: "0 0 * * * *"        # 매시 정각
        max-size: 10MB
        temp-quota: 200MB                  # 회원별 TEMP 합계 한도
        allowed-types: [image/jpeg, image/png, image/gif, image/webp]
        thumbnail-dir: /var/blog/media-thumb   # 썸네일(다시 만들 수 있어 백업 제외)
        thumbnail:
          # FR-131 기본 크기(50x50, 100x100, 160x160, 300x200, 600x400, 1200x630)와 각 2배를 중복 없이
          sizes: [50x50, 100x100, 160x160, 200x200, 300x200, 320x320, 600x400, 1200x630, 1200x800, 2400x1260]
    ```
    시작 시 세 디렉터리를 만들고 쓰기 가능 여부를 검사해 실패하면 기동을 멈춘다.
  - 업로드: `POST /api/v1/media`(purpose=POST/PROFILE/BLOG_COVER) → 매직 넘버로 형식 판별 → 가로·세로 읽기 → `temp-dir/{uuid}.{ext}`에 저장 → `media` 행 status=TEMP, `media_key`=무작위 128비트 base62 22자(`SecureRandom`) 생성 → `{ key, url: "/media/{key}" }` 반환. 에디터는 이 URL을 본문 Markdown에 넣는다.
  - 서빙: `GET /media/{key}`는 DB에서 현재 위치(TEMP면 temp-dir, ATTACHED면 upload-dir)를 찾아 스트리밍. TEMP는 올린 회원의 요청에만 `Cache-Control: private, no-store`로 주고 그 외 404. ATTACHED는 긴 캐시 헤더. 주소가 키 기반이라 파일을 옮겨도 본문을 고치지 않는다.
  - 접근 범위: 순번 ID 대신 추측할 수 없는 키를 써서 다른 이미지 주소를 찾아낼 수 없게 한다. 등록된 이미지는 소속 글의 공개 범위를 확인하지 않는다(비공개·임시저장·휴지통 글의 이미지도 주소를 알면 열림). 매 요청 권한 확인은 CDN·브라우저 캐시를 못 쓰게 만들고 여러 글이 같은 이미지를 쓰면 판단이 복잡해지므로, 티스토리와 같은 수준의 절충으로 받아들인다(FR-156).
  - 등록: 글 저장(임시저장 포함)·발행 시 본문에서 `/media/{key}`를 추출 → 그 회원의 TEMP 파일을 `upload-dir/yyyy/MM/{uuid}.{ext}`로 `Files.move`(같은 파일시스템이면 원자적 이동, 아니면 복사 후 삭제) → status=ATTACHED, `post_media`(source=DRAFT 또는 PUBLISHED) 갱신. 프로필·블로그 대표 이미지는 PATCH /me·/blogs/{handle} 저장 시 같은 방식으로 ATTACHED. 같은 트랜잭션 안에서 DB 갱신, 파일 이동 실패 시 롤백.
  - 정리 대상 판단: 이미지를 참조하는 `post_media` 행(발행본·작성 중 사본, 휴지통 글 포함)도, `users.profile_media_id`·`blogs.cover_media_id`도 없을 때만 ORPHANED. 발행, 작성 중 사본 저장·폐기, 글 영구 삭제, 프로필·대표 이미지 변경 때 영향받은 이미지만 다시 판단한다(data-model media). 작성 중 사본에서만 지운 이미지는 발행본이 쓰므로 남는다.
  - 정리: `@Scheduled(cron = "${blog.media.cleanup-cron}")` 작업이 (1) `created_at < now - temp-ttl`인 TEMP, (2) ORPHANED를 파일·썸네일 디렉터리·행 모두 삭제.
  - 썸네일 (FR-130~132): Thumbnailator(`net.coobird:thumbnailator`)로 축소·자르기, WebP 읽기는 TwelveMonkeys ImageIO(`imageio-webp`) 플러그인. JDK ImageIO는 GIF의 첫 프레임만 읽으므로 움직이는 GIF는 첫 장면으로 만든다. WebP 원본은 쓰기 지원이 없으므로 PNG로, 나머지는 원본 형식으로 출력. 원본(width·height)보다 크게 늘리지 않는다: 요청 크기가 원본보다 크면 비율만 맞춰 원본 안에서 자르거나(cover) 원본 크기 그대로 둔다(contain). 동시에 같은 썸네일 요청이 와도 한 번만 만든다: 키(`{key}/{w}x{h}-{fit}`)별 락(Caffeine로 만료되는 `ReentrantLock` 맵) → 락 안에서 파일 존재 재확인 → 같은 디렉터리의 임시 파일에 쓴 뒤 `Files.move(ATOMIC_MOVE)`로 이름 변경. 다른 요청은 완성된 파일만 본다.
  - `MediaStorage` 인터페이스(`saveTemp`, `promote`, `open`, `delete`)로 감싸 나중에 S3로 교체 가능.
- **Rationale**: 사용자 결정(임시 폴더 → 글 작성 시 등록 → 미등록 삭제, 프로퍼티 기반 경로). 브라우저 이탈은 서버가 알 수 없으므로 TTL로 판단. 썸네일 라이브러리는 의존성이 없는 작은 라이브러리(Thumbnailator)와 ImageIO 플러그인으로 한정했다(원칙 VI, plan Complexity Tracking).
- **Alternatives**: 업로드 즉시 정식 저장 후 주기적 고아 탐색(본문 전수 스캔이 필요해 비쌈), 파일 경로를 URL로 노출(이동 시 본문 치환 필요), 순번 ID + 요청마다 글 권한 확인(캐시 불가, 여러 글 공유 시 판단 복잡), imgscalr(GIF·WebP 처리는 같음, API만 다름)·libvips(네이티브 의존성).

## R12. 로그인 잠금 (FR-007)
- **Decision**: `users.failed_login_count`, `users.locked_until` 컬럼. 5회 연속 실패 시 10분 잠금, 성공 시 0으로 초기화. 존재하지 않는 이메일과 비밀번호 오류는 같은 에러 코드로 응답.

## R13. 테스트와 커버리지
- **Decision**:
  - Controller: `@WebMvcTest` + MockMvc. 보안 필터를 포함해 401/403을 검증하고, 서비스는 `@MockitoBean`.
  - Service: `MockitoExtension` 단위 테스트.
  - Repository: `@DataJpaTest` + `@AutoConfigureTestDatabase(replace = NONE)` + Testcontainers MySQL(`@ServiceConnection`), 컨테이너는 정적 필드로 재사용. Flyway 마이그레이션을 그대로 적용해 FULLTEXT 쿼리도 검증.
  - JaCoCo `check` 규칙: BUNDLE LINE COVEREDRATIO ≥ 0.80, `verify` 단계에서 실행. 설정 클래스, `*Application`, DTO record는 제외.
  - front: Vitest `coverage.thresholds.lines = 80`, Playwright는 스토리별 Independent Test 시나리오.

## R14. 로컬 실행 환경
- **Decision**: 각 저장소에 Docker Compose 없이 개발할 수 있게 하되, docs 저장소의 quickstart에서 MySQL 컨테이너 한 줄 실행 명령을 안내. 운영용 Compose 파일은 backend 저장소에 둔다(배포 스펙에서 확정).

## R15. RSS·Atom 피드 (FR-044~048, SC-008)
- **Decision**: backend가 피드 XML을 직접 생성(ROME 라이브러리 사용, `com.rometools:rome`). 경로: `/{handle}/rss`, `/{handle}/atom`, `/{handle}/category/{id}/rss`. front Express가 이 경로를 backend로 프록시. 응답에 `Last-Modified`/`ETag`를 붙여 리더의 조건부 요청에 304로 응답, 5분 캐시. 페이지 `<head>`에 `<link rel="alternate" type="application/rss+xml">`와 Atom 링크를 넣는다.
- **Alternatives**: 문자열 템플릿(이스케이프·날짜 형식 오류 위험), front에서 생성(데이터 로직이 front로 새어 원칙 II 위반).

## R16. 트랙백 (FR-049~055, SC-009)
- **Decision**:
  - 받기: `POST /{handle}/{postId}/trackback`, `application/x-www-form-urlencoded`(url 필수, title·excerpt·blog_name 선택), 응답은 TrackBack 1.2 XML(`<response><error>0</error></response>` 또는 `<error>1</error><message>…</message>`). front가 backend로 프록시. 문자셋은 `Content-Type`의 charset을 우선, 없으면 UTF-8.
  - 검증: 글 공개·트랙백 허용 확인, 같은 (post, url) 중복 거부, 출처 IP당 10분 10회 제한(Caffeine), 제목·요약은 태그 제거 후 길이 제한.
  - 보내기: 글 저장 후 트랜잭션 커밋 이벤트에서 비동기(`@Async` + 전용 스레드 풀)로 각 대상에 핑 전송. 연결·응답 시간 제한 각 5초. 결과는 `trackback_ping_log`에 기록. 서비스 안의 주소면 HTTP를 거치지 않고 내부 서비스 호출로 처리.
  - SSRF 방지: 보낼 주소가 사설·루프백·링크로컬 IP로 해석되면 거부, http/https만 허용, 리다이렉트는 따라가지 않음.
- **Alternatives**: Pingback(XML-RPC, 범위 밖으로 결정), 동기 전송(외부 지연이 발행을 막음).

## R17. 예약 발행 (FR-064, SC-010)
- **Decision**: posts.status=SCHEDULED + scheduled_at. `@Scheduled(fixedDelay = 30s)` 작업이 `scheduled_at <= now`인 글을 PUBLISHED로 바꾸고 published_at을 설정, 트랙백 전송 이벤트도 이때 발생. 단일 서버 전제라 분산 락은 두지 않음(서버가 늘면 ShedLock 검토).

## R18. 보호 글 (FR-062, FR-063)
- **Decision**: posts.visibility=PROTECTED(004에서 값 추가) + posts.password_hash(BCrypt). 목록·피드·검색 노출은 001 data-model의 "목록 노출 가능"·"본문 노출 가능" 조건과 글 노출 매트릭스를 따른다. `POST /api/v1/posts/{id}/unlock`이 맞으면 해당 글 ID가 담긴 서명된 단기 쿠키(30분, HttpOnly)를 발급하고, 글 조회 시 이 쿠키가 있으면 본문 포함. SSR 첫 요청에서도 쿠키로 본문을 렌더링. 실패 횟수는 (postId, 방문자 키)로 Caffeine 10분 카운트.

## R19. 방문자 수 (FR-067)
- **Decision**: 방문자 키 = 로그인 회원 ID 또는 front가 발급하는 익명 방문자 쿠키(UUID, 1년). 블로그 페이지 SSR 시 front가 backend에 방문 기록 API 호출. backend는 Caffeine(키: blogId+방문자키+날짜, TTL 하루)로 중복 제거 후 `blog_daily_visit(blog_id, visit_date, visitors)` upsert, 전체 수는 blogs.total_visitors 증가. 봇(User-Agent에 bot/crawler/spider)은 제외.

## R20. 비회원 댓글·방명록, 비밀 댓글 (FR-065, FR-066, FR-056~058)
- **Decision**: comments·guestbook_entries에 user_id NULL 허용, guest_name, guest_password_hash(BCrypt) 컬럼. 비회원 쓰기는 IP당 1분 5회 제한. 비밀 여부는 secret 컬럼, 조회 응답에서 권한 없는 사람에게는 content를 null로 내려보낸다(필터링은 서비스 계층 한 곳).

## R21. 관련 글·공유 (FR-068, FR-069)
- **Decision**: 관련 글은 같은 블로그의 "본문 노출 가능" 글 중 태그 겹침 수 + 같은 카테고리 가산점 순으로 5개, 글별 10분 캐시. 공유는 front에서 주소 복사(Clipboard API)와 SNS 공유 링크(X·페이스북은 공유 URL 방식). 카카오톡 공유는 공유 URL 방식이 없으므로 Kakao JS SDK(`Kakao.Share`, 공식 CDN 지연 로딩, 공유 버튼을 누를 때만 로드)를 쓴다. 새 외부 라이브러리이므로 002의 plan.md Complexity Tracking에 도입 이유(002 FR-069의 카카오톡 공유는 SDK 없이 불가)를 적는다. Open Graph·Twitter 카드 메타 태그는 SSR로 출력.

## R22. 다국어 (FR-148~155, SC-024, 원칙 VII)
- **Decision**:
  - front: i18next + react-i18next. 번역 파일 `blog-front/app/locales/{ko,en,ja,zh-CN}/{namespace}.json`(namespace: common, auth, post, editor, manage, settings, errors 등). 기준 언어는 ko, `fallbackLng: ["en", "ko"]`(FR-152), `returnNull: false`로 키가 화면에 나오지 않게 한다.
  - 언어 결정(FR-149): SSR `root.tsx` loader에서 (1) 로그인 회원의 `locale`(/me) → (2) 쿠키 `lang` → (3) `Accept-Language` → (4) en. 결정한 언어로 서버에서 i18next 인스턴스를 만들어 렌더링하고 `<html lang>`을 설정, 같은 리소스를 hydration 데이터로 넘겨 깜빡임을 막는다. 하단 언어 선택은 `/locale` 리소스 라우트 `action`이 쿠키 `lang`(1년)을 쓰고 로그인 상태면 PATCH /me `locale`을 호출한다. 주소에는 언어 접두어가 없다(FR-150).
  - 날짜·숫자(FR-153): `Intl.DateTimeFormat`/`Intl.NumberFormat`을 화면 언어와 시간대로 사용. 시간대는 회원 `time_zone`, 비회원은 `Asia/Seoul`.
  - 오류(FR-154): API의 `code`·`fieldErrors[].code`를 `errors.{code}`·`fieldErrors.{code}` 키로 번역. backend `message`는 영어 디버그용이라 화면에 쓰지 않는다.
  - backend: 메일 문구만 Spring `MessageSource`(`messages_{ko,en,ja,zh_CN}.properties`, 기본 en, 없으면 ko). API 응답에는 번역 문구를 넣지 않는다.
  - 에디터(FR-148): Milkdown Crepe의 문구 설정에 `editor` namespace 번역을 넣는다.
  - 번역 누락 점검(FR-152, SC-024): front Vitest 테스트가 ko의 모든 namespace 키 집합과 en·ja·zh-CN의 키 집합을 비교해 하나라도 빠지거나 빈 값이면 실패. 같은 테스트가 소스에서 `t("...")`로 쓴 키가 ko에 있는지 확인. backend는 JUnit 테스트가 4개 `messages_*.properties`의 키 집합이 같은지 확인. 둘 다 CI 기본 테스트에 포함.
- **Rationale**: React Router SSR과 함께 쓰는 사례가 많고, namespace·대체 언어·복수형을 기본 지원한다(헌법 기술 제약의 기본값).
- **Alternatives**: FormatJS(react-intl, ICU 메시지가 강력하지만 SSR 리소스 분할 설정이 더 많음), Lingui(컴파일 단계 필요), URL 언어 접두어(FR-150 위반).

## R23. 메일 발송 (FR-133, FR-148)
- **Decision**: Spring Boot Mail(`spring-boot-starter-mail`)의 `JavaMailSender`로 SMTP 발송. 접속 정보는 `blog.mail.host/port/username/password/from/starttls` 프로퍼티(비밀번호는 환경 변수)를 `@ConfigurationProperties`로 받아 `JavaMailSenderImpl`을 직접 구성한다. 문구는 받는 회원의 `locale` 언어 `MessageSource`로 만든 텍스트 + 단순 HTML. 발송은 트랜잭션 커밋 후 `@Async`로 하고 실패는 로그에 남긴다(재설정 요청 응답은 발송 결과와 관계없이 202). 개발 환경은 Mailpit 컨테이너(quickstart).
- **Alternatives**: 외부 메일 API(SES 등, 계정·SDK 추가), 동기 발송(SMTP 지연이 응답을 막음).

## R24. 코드 블록 문법 강조 (FR-083)
- **Decision**: front가 SSR 렌더링 시 highlight.js(`highlight.js/lib/core` + 자주 쓰는 언어만 등록: java, kotlin, javascript, typescript, json, xml/html, css, sql, bash, yaml, python, go, diff 등)로 강조한다. 글 상세 loader가 받은 `contentHtml`의 `<pre><code class="language-xxx">` 블록만 골라 `hljs.highlight(code, { language })`로 바꾼다. 언어 자동 감지(`highlightAuto`)는 쓰지 않으며, 펜스에 언어를 쓰지 않았거나 등록되지 않은 언어는 강조 없이 일반 텍스트로 둔다. 브라우저에는 강조된 HTML과 테마 CSS만 가고 highlight.js 스크립트는 보내지 않는다(JS 없이도 강조됨, 원칙 V). highlight.js 출력은 코드 내용을 이스케이프하고 `span class="hljs-*"`만 만들므로 살균 결과를 해치지 않는다.
- **Rationale**: commonmark-java에는 강조 기능이 없다. 강조를 front에 두면 언어 목록·테마 변경 시 저장된 글을 다시 변환할 필요가 없다.
- **Alternatives**: backend 강조(자바 라이브러리 선택지가 적음, 변경 시 전체 재변환), 브라우저에서 강조(JS 없이 강조 안 됨, 깜빡임), Shiki(번들이 크고 SSR 비용이 큼).

## R25. 동영상 삽입 허용 목록 (FR-140)
- **Decision**: 허용 사이트는 YouTube와 Vimeo 플레이어뿐이다. backend 변환 단계에서 한 줄에 동영상 주소만 있는 문단(`youtube.com/watch?v=`, `youtu.be/`, `vimeo.com/{id}`)을 iframe으로 바꾸고, Markdown에 직접 쓴 iframe도 같은 살균 정책을 거친다. OWASP 살균 정책은 `iframe`의 `src`가 `^https://www\.youtube(-nocookie)?\.com/embed/[A-Za-z0-9_-]{11}(\?[^"]*)?$` 또는 `^https://player\.vimeo\.com/video/\d+(\?[^"]*)?$`일 때만 남기고, 속성은 `src, width, height, allowfullscreen, loading, title, referrerpolicy`만 허용한다. 그 밖의 iframe은 제거. YouTube 변환 결과는 `youtube-nocookie.com/embed`를 쓴다.
- **Alternatives**: oEmbed 조회(외부 요청이 저장 경로에 들어감), 카카오TV·네이버TV 포함(1.0 범위 밖으로 결정, FR-140).

## R26. 정기 작업 (FR-072~073, FR-084, FR-138, FR-139)
- **Decision**: Spring `@Scheduled`(`@EnableScheduling`). 1.0은 backend 1대 전제라 분산 락을 두지 않는다(서버가 늘면 ShedLock 검토, R17과 같은 방침). 작업 목록:
  - 이미지 정리(`blog.media.cleanup-cron`, 매시): 만료된 TEMP, ORPHANED 삭제(R11).
  - 휴지통 비우기(`blog.jobs.trash-purge-cron`, 매일): `deleted_at < now - 30일`인 글 영구 삭제 → post_media 삭제 → 이미지 정리 대상 판단. 같은 작업이 `deleted_at < now - 30일`인 삭제된 블로그(FR-159)의 카테고리·블로그별 데이터를 지우고 대표 이미지 정리 대상을 판단한다(`blogs` 행은 주소 재사용 방지를 위해 남김).
  - 개인정보 파기(`blog.jobs.privacy-purge-cron`, 매일): `withdrawn_at < now - 30일`인 회원의 개인정보 파기, 90일 지난 로그인 기록 삭제, 만료된 비밀번호 재설정 토큰·리프레시 토큰 삭제.
  - 각 작업은 한 번에 정해진 건수씩 나눠 처리하고 결과 건수를 로그에 남긴다.
- **Alternatives**: Quartz(DB 테이블 추가, 지금 필요 없음), 외부 cron(실행 파트 밖 설정이 늘어남).

## R27. 보안 헤더와 XSS 방어 계층 (FR-016, FR-140, 원칙 IV)
- **Decision**: XSS는 세 겹으로 막는다.
  1. 저장 시: 본문은 R8의 OWASP Sanitizer로 허용 태그만 남긴다. `<script>`, `on*` 속성, `javascript:` 주소, `style` 속성은 허용 목록에 없으므로 제거된다. iframe은 R25 허용 목록(YouTube, Vimeo)만 통과한다. 댓글, 방명록, 닉네임, 블로그 이름은 HTML을 받지 않는 일반 텍스트로 저장한다.
  2. 표시 시: front는 sanitize된 `content_html`에만 `dangerouslySetInnerHTML`을 쓰고, 나머지는 React의 기본 이스케이프로 출력한다. 이 규칙은 ESLint 규칙(`react/no-danger` 예외 목록)으로 강제한다.
  3. 브라우저: nginx가 아닌 front 서버(Express)가 모든 HTML 응답에 보안 헤더를 붙인다.
     - `Content-Security-Policy`: `default-src 'self'; script-src 'self' 'nonce-{요청별}'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; frame-src https://www.youtube-nocookie.com https://player.vimeo.com; object-src 'none'; base-uri 'self'; form-action 'self'; frame-ancestors 'none'`. 외부 블로그 썸네일(007)은 backend가 받아 `/media`로 제공하므로 `img-src`에 외부 도메인을 넣지 않는다.
     - `X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin`, `Strict-Transport-Security: max-age=31536000`(운영만).
  - `/media/**` 응답은 저장된 형식(이미지 4종)의 `Content-Type`과 `nosniff`, `Content-Disposition: inline`을 붙인다. 업로드 형식은 확장자가 아니라 파일 내용으로 판별하고, SVG와 HTML은 받지 않는다(R11 `allowed-types`).
- **CSRF**: R3(SameSite=Lax 쿠키 + 상태 변경 요청의 `Origin` 검사)로 막는다. 쿠키 인증이라 토큰을 JS에서 읽을 수 없으므로(HttpOnly) XSS가 생겨도 토큰 자체는 빼낼 수 없다.
- **검증**: 통합 테스트로 악성 본문(`<script>`, `<img onerror>`, `javascript:` 링크, 허용 목록 밖 iframe, SVG 업로드)이 저장 후 무력화되는지, HTML 응답에 CSP 헤더가 있는지 확인한다.
- **Alternatives**: 클라이언트 쪽 DOMPurify만 사용(SSR, RSS, 포털 요약에 같은 HTML이 쓰이므로 서버에서 한 번 정리하는 편이 안전), Spring Security 헤더만 사용(HTML은 front가 내려주므로 front에서 붙여야 함).

## R28. 회원당 여러 블로그와 블로그 수 한도 (FR-010, FR-158, FR-159, 006 FR-160)
- **Decision**: 회원 1 : 블로그 N. `blogs.user_id`의 UNIQUE를 없애고 인덱스만 둔다. handle은 `blogs`에 그대로 두며 삭제된 블로그를 포함해 서비스 전체에서 유일하다(삭제 후에도 행을 남겨 재사용을 막음, 사칭 방지). 한도는 `COALESCE(users.max_blogs, blog.blogs.default-max-per-member)`(기본 3)이고, 블로그 만들기와 삭제는 한 트랜잭션 안에서 `users` 행을 `SELECT ... FOR UPDATE`로 잠근 뒤 ACTIVE 블로그 수를 세고 INSERT(또는 status 변경)한다. 같은 회원의 동시 요청은 이 잠금에서 줄을 서므로 한도를 넘거나 마지막 블로그를 지우는 경우가 생기지 않는다. 다른 회원의 요청은 서로 막지 않는다.
- **블로그 단위 주소**: 블로그별 소유자 화면은 `/:handle/manage/**`, `/:handle/write`로 옮기고 API도 `/blogs/{handle}/...`로 대상 블로그를 정한다. 주소만 보고 어느 블로그를 다루는지 알 수 있어 "현재 선택한 블로그" 같은 서버 상태가 필요 없다. 최상위 `/manage`·`/write`는 front 쿠키 `last_blog`(최근에 쓴 블로그)로 리다이렉트만 한다.
- **Rationale**: 회원 행 잠금은 MySQL InnoDB 기본 기능만 쓰고, 잠금 범위가 그 회원 한 명이며 블로그 만들기는 드물어 경합이 없다. 회원 단위 한도를 DB 제약으로 표현할 수 없으므로 서비스 계층에서 직렬화한다.
- **Alternatives**: 낙관적 검사(COUNT 후 INSERT, 잠금 없음: 동시 요청 두 개가 모두 통과해 한도를 넘음), 블로그 번호 슬롯 컬럼 + UNIQUE(user_id, slot)(한도가 바뀌면 슬롯 재배치가 필요하고 삭제 후 빈 슬롯 처리 복잡), `users.blog_count` 카운터 컬럼(잠금은 여전히 필요하고 값이 어긋날 위험만 늘어남), 현재 블로그를 세션·회원 컬럼에 저장(탭마다 다른 블로그를 다룰 때 꼬임).
