# Research: 멀티 유저 블로그 플랫폼 MVP

> R15~R21은 002~005 스펙용으로 미리 조사한 내용이다. 해당 스펙의 `/speckit-plan` 때 그 스펙의 research.md로 옮긴다.

버전 확인일: 2026-10-06 (Maven Central, npm 레지스트리 기준)

## R1. backend 프레임워크 버전
- **Decision**: Spring Boot 4.1.x(확인 시점 최신 정식 4.1.1), Java 21, Maven Wrapper.
- **Rationale**: 사용자 결정(Spring Boot 4). 4.2는 마일스톤 단계라 제외.
- **Alternatives**: 3.5.x(더 많은 레퍼런스지만 사용자 결정과 다름).
- **주의**: Boot 4에서 테스트 슬라이스가 모듈별 스타터로 나뉘었다(`spring-boot-starter-webmvc-test`, `spring-boot-starter-data-jpa-test` 등). `@MockBean`은 제거되어 `@MockitoBean`을 쓴다.

## R2. 인증 토큰 설계 (FR-004~007, SC-006)
- **Decision**:
  - 접근 토큰: JWT(HS256, jjwt 0.13), 만료 30분, 클레임은 userId·role만.
  - 리프레시 토큰: 무작위 256비트 불투명 문자열, DB에는 SHA-256 해시만 저장. `/api/auth/refresh`를 쓸 때마다 새 리프레시 토큰을 발급하고 이전 것은 사용 처리(rotation). 유휴 만료는 발급 후 4시간, 절대 만료는 로그인 계열(family) 최초 발급 후 7일.
  - 재사용 감지: 이미 사용·폐기된 리프레시 토큰이 다시 오면 같은 family의 토큰을 모두 폐기(탈취 대응).
  - 두 토큰 모두 `HttpOnly; Secure; SameSite=Lax` 쿠키. 리프레시 쿠키는 `Path=/api/auth`.
  - 로그아웃 시 해당 family 폐기(FR-006). 회원 정지·탈퇴 시 그 회원의 모든 family 폐기.
  - 동시 요청 경합: 여러 탭이 동시에 리프레시하면 하나만 성공하고 나머지가 재사용으로 오인될 수 있으므로, 사용 처리 후 10초 동안은 같은 토큰 재요청에 방금 발급한 토큰을 다시 돌려준다(유예 기간).
- **Rationale**: 고정 4시간 만료는 긴 글 작성 중 강제 로그아웃을 만든다(2026-10-06 사용자 승인으로 회전 방식 채택). 쿠키 방식이라 SSR 첫 요청에서도 로그인 상태를 렌더링할 수 있다.
- **Alternatives**: 고정 4시간 만료(작성 중 로그아웃), Authorization 헤더 + localStorage(SSR 불가, XSS 취약), 리프레시도 JWT(즉시 폐기 불가).

## R3. CSRF
- **Decision**: 쿠키 인증이므로 상태 변경 요청(POST/PUT/PATCH/DELETE)에 대해 `Origin` 헤더가 `https://blog.java21.net`(개발 시 설정값)인지 backend 필터에서 검사. SameSite=Lax와 함께 사용.
- **Alternatives**: Spring Security CSRF 토큰(SSR·SPA 양쪽에 토큰 전달 로직이 늘어남).

## R4. 도메인과 프록시
- **Decision**: 브라우저는 `blog.java21.net`(front 서버)만 호출. front 서버가 `/api/**`, `/media/**`, 피드·트랙백 경로를 backend로 프록시(React Router framework의 커스텀 Express 서버 엔트리 사용). SSR 중 `loader`는 내부 주소로 backend를 직접 호출하며 요청 쿠키를 전달.
- **Rationale**: 쿠키가 같은 출처로 유지되어 CORS가 필요 없다. 원칙 II(두 파트) 유지.

## R5. 블로그 주소 라우팅과 예약어 (FR-002, FR-022)
- **Decision**: `/{handle}`와 `/{handle}/{postId}`는 front 라우트에서 가장 마지막 우선순위로 매칭. 예약어 목록은 backend `blog` 패키지의 상수 하나로 관리하고, front 최상위 라우트를 추가할 때 이 목록에 같이 추가(contracts/routes.md에 목록 유지).
- **handle 규칙**: `^[a-z0-9](?:[a-z0-9-]{1,18})[a-z0-9]$`, 연속 하이픈 금지.

## R6. 프런트 SSR 구성
- **Decision**: React Router 8 framework 모드(`@react-router/dev` Vite 플러그인). 라우트 모듈의 `loader`(서버 데이터 조회), `action`(폼 처리), `meta`(title·description·Open Graph), `links`(피드 자동 발견 `<link rel="alternate">`)를 사용. 운영은 `react-router build` 산출물을 커스텀 Express 서버(`@react-router/express`)로 띄워 프록시와 함께 제공.
- **Rationale**: Vite 위에서 동작해 "Vite + React" 조건을 지키면서 데이터 선로딩·hydration·스트리밍·head 관리·에러 경계가 기본 제공된다(2026-10-06 사용자 승인). 직접 만든 Vite SSR 대비 작성·유지 코드가 크게 줄어든다.
- **Alternatives**: Vite 공식 SSR 예제 기반 직접 구현(위 기능을 모두 손으로 작성), Next.js(Vite 아님).

## R7. 에디터 (FR-014)
- **Decision**: Milkdown Crepe(`@milkdown/crepe` 7.x). Markdown이 원본 형식이며 입력 즉시 서식 렌더링, `/` 슬래시 명령과 선택 시 플로팅 툴바만 쓰고 상단 고정 툴바는 쓰지 않는다. 이미지 업로드 훅에서 `POST /api/media`(임시 업로드)를 호출해 `/media/{id}`를 넣는다. 작성 화면에서만 클라이언트 지연 로딩(`clientLoader`/`lazy`), SSR 제외.
- **Rationale**: TOAST UI Editor는 2023-02 이후 릴리스가 없고 React 래퍼가 React 17 전용이다. 사용자가 CKEditor식 큰 툴바를 원하지 않아 MDXEditor(툴바 중심)를 제외. Milkdown은 2026-09에도 릴리스되는 활발한 프로젝트.
- **Alternatives**: @uiw/react-md-editor(분할 미리보기, WYSIWYG 없음 — 사용자가 분할 방식을 원하면 교체), MDXEditor(툴바 중심), Tiptap + Markdown 확장(구성 작업 많음), TOAST UI(유지보수 중단).
- **교체 대비**: `components/Editor` 래퍼 인터페이스(`value`, `onChange`, `onUploadImage`)를 고정해 에디터를 바꿔도 화면 코드는 그대로 둔다.

## R8. Markdown 변환과 XSS (FR-021)
- **Decision**: 저장 시 backend에서 commonmark-java(GFM 테이블·취소선 확장)로 HTML 변환 후 OWASP Java HTML Sanitizer로 허용 태그만 남겨 `content_html`에 저장. 조회 시 변환 없이 그대로 사용. 댓글은 Markdown 없이 텍스트로 저장하고 출력 시 이스케이프.
- **Rationale**: 변환 비용을 쓰기 시점에 한 번만 낸다. 살균을 서버 한 곳에서 하므로 front는 신뢰된 HTML만 받는다.

## R9. 검색 (FR-035, SC-007)
- **Decision**: MySQL FULLTEXT(ngram 파서, token size 2)를 `post(title, content_text)`와 태그 이름에 적용. `content_text`는 HTML에서 태그를 뺀 순수 텍스트.
- **Alternatives**: Elasticsearch(원칙 VI 위반, 별도 인프라), LIKE 검색(10만 건에서 2초 목표 불확실).

## R10. 조회수와 인기 글 (FR-020, FR-034)
- **Decision**: 조회 중복 판단은 Caffeine 캐시(키: postId + 회원 ID 또는 방문자 쿠키 ID, TTL 30분). 집계는 `post.view_count` 증가 + `post_daily_stat(post_id, stat_date, views, likes)` upsert. 인기 글은 최근 7일 `views + likes*10` 합계 상위, 결과를 Caffeine에 5분 캐시.
- **Rationale**: 단일 서버 전제(SC-003 규모)에서 충분. 서버가 늘면 Redis로 교체(그때 ADR 갱신).

## R11. 첨부 파일 저장 (FR-038, FR-039, FR-071~074)
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
    ```
    시작 시 두 디렉터리를 만들고 쓰기 가능 여부를 검사해 실패하면 기동을 멈춘다.
  - 업로드: `POST /api/media` → 매직 넘버로 형식 판별 → `temp-dir/{uuid}.{ext}`에 저장 → `media` 행 status=TEMP 생성 → `{ id, url: "/media/{id}" }` 반환. 에디터는 이 URL을 본문 Markdown에 넣는다.
  - 서빙: `GET /media/{id}`는 DB에서 현재 위치(TEMP면 temp-dir, ATTACHED면 upload-dir)를 찾아 스트리밍, 긴 캐시 헤더. 주소가 ID 기반이라 파일을 옮겨도 본문을 고치지 않는다.
  - 등록: 글 저장(임시저장 포함)·발행 시 본문에서 `/media/{id}`를 추출 → 그 회원의 TEMP 파일을 `upload-dir/yyyy/MM/{uuid}.{ext}`로 `Files.move`(같은 파일시스템이면 원자적 이동, 아니면 복사 후 삭제) → status=ATTACHED, post_id 설정. 같은 트랜잭션 안에서 DB 갱신, 파일 이동 실패 시 롤백.
  - 정리: `@Scheduled(cron = "${blog.media.cleanup-cron}")` 작업이 (1) `created_at < now - temp-ttl`인 TEMP, (2) ORPHANED(수정으로 본문에서 빠짐, 영구 삭제된 글)를 파일·행 모두 삭제.
  - `MediaStorage` 인터페이스(`saveTemp`, `promote`, `open`, `delete`)로 감싸 나중에 S3로 교체 가능.
- **Rationale**: 사용자 결정(임시 폴더 → 글 작성 시 등록 → 미등록 삭제, 프로퍼티 기반 경로). 브라우저 이탈은 서버가 알 수 없으므로 TTL로 판단.
- **Alternatives**: 업로드 즉시 정식 저장 후 주기적 고아 탐색(본문 전수 스캔이 필요해 비쌈), 파일 경로를 URL로 노출(이동 시 본문 치환 필요).

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
- **Decision**: posts.password_hash(BCrypt). `POST /api/posts/{id}/unlock`이 맞으면 해당 글 ID가 담긴 서명된 단기 쿠키(30분, HttpOnly)를 발급하고, 글 조회 시 이 쿠키가 있으면 본문 포함. SSR 첫 요청에서도 쿠키로 본문을 렌더링. 실패 횟수는 (postId, 방문자 키)로 Caffeine 10분 카운트.

## R19. 방문자 수 (FR-067)
- **Decision**: 방문자 키 = 로그인 회원 ID 또는 front가 발급하는 익명 방문자 쿠키(UUID, 1년). 블로그 페이지 SSR 시 front가 backend에 방문 기록 API 호출. backend는 Caffeine(키: blogId+방문자키+날짜, TTL 하루)로 중복 제거 후 `blog_daily_visit(blog_id, visit_date, visitors)` upsert, 전체 수는 blogs.total_visitors 증가. 봇(User-Agent에 bot/crawler/spider)은 제외.

## R20. 비회원 댓글·방명록, 비밀 댓글 (FR-065, FR-066, FR-056~058)
- **Decision**: comments·guestbook_entries에 user_id NULL 허용, guest_name, guest_password_hash(BCrypt) 컬럼. 비회원 쓰기는 IP당 1분 5회 제한. 비밀 여부는 secret 컬럼, 조회 응답에서 권한 없는 사람에게는 content를 null로 내려보낸다(필터링은 서비스 계층 한 곳).

## R21. 관련 글·공유 (FR-068, FR-069)
- **Decision**: 관련 글은 같은 블로그의 공개 노출 가능 글 중 태그 겹침 수 + 같은 카테고리 가산점 순으로 5개, 글별 10분 캐시. 공유는 front에서 주소 복사(Clipboard API)와 SNS 공유 링크(카카오톡은 Kakao JS SDK 대신 공유 URL 방식이 없으므로 주소 복사 안내로 대체 가능 여부를 구현 시 확인). Open Graph·Twitter 카드 메타 태그는 SSR로 출력.
