# Blog Platform Constitution

<!--
Sync Impact Report (2026-10-06)
- 버전: 1.0.0 → 2.3.1
- 1.x: 패키지 이름(net.java21.blog), Spring Boot 4·Vite + React SSR, 커버리지 80%와 backend 슬라이스 테스트(원칙 III), 서비스 도메인 blog.java21.net, 블로그 고유 기능·첨부 파일 임시 업로드 방식 추가.
- 2.0.0 (MAJOR): 리프레시 토큰 회전(rotation, 유휴 4시간·절대 7일), front를 React Router framework 모드로 변경, 에디터를 TOAST UI에서 Milkdown Crepe로 교체, 스펙을 기능 단위(001~)로 분할.
- 2.1.0: data-model의 Mermaid ERD 규칙, 003 포털·006 관리 화면·007 외부 블로그 수집 스펙 반영, 썸네일 URL 규칙.
- 2.2.0: 개인정보 AES-256-GCM 암호화(blog.crypto.*), 1.0 운영 범위(HTTPS·DB·백업·로그) 추가.
- 2.3.0: 원칙 VII(다국어 우선, ko·en·ja·zh-CN) 추가, 저장소 README 4개 언어 규칙.
- 2.3.1 (PATCH): 에디터 UI 문구를 화면 언어로, 첨부 파일 주소를 추측 불가 키(`/media/{key}`)로, 공개 범위 판단 기준을 001 data-model 노출 매트릭스로 명시, 전체 스펙 일관성 점검 반영.
- 템플릿: 변경 없음. 후속 작업: 없음.
-->

## 제품 목표

티스토리 같은 멀티 유저 블로그 플랫폼을 처음부터 만든다. 회원은 가입하면 자신의 블로그를 갖고 글을 쓰며, 방문자는 공개 글을 읽고 검색한다.

## Core Principles

### I. 스펙이 먼저다 (NON-NEGOTIABLE)
모든 기능은 `specs/` 아래의 spec.md → plan.md → tasks.md를 거친 뒤에 구현한다. spec.md는 "무엇을, 왜"만 쓰고 기술 선택은 plan.md에 쓴다. 스펙에 없는 기능은 구현하지 않는다. 모호한 점은 `/speckit-clarify`로 해소한 뒤 계획한다.

### II. 세 저장소, 두 개의 실행 파트
저장소는 `blog-docs`(스펙), `blog-backend`(Spring), `blog-front`(React SSR) 셋과 조직 소개용 `.github`로 나눈다. 실행되는 파트는 backend와 front 둘뿐이며, 그 외 서비스(게이트웨이, BFF, 별도 인증 서버)를 추가하지 않는다. 두 파트는 backend가 제공하는 REST API(OpenAPI 문서)로만 통신한다.

### III. 테스트 우선과 커버리지 (NON-NEGOTIABLE)
tasks.md는 구현 작업보다 테스트 작업을 앞에 둔다. 스펙의 인수 시나리오마다 대응하는 테스트가 있어야 한다.
- 커버리지: backend와 front 모두 라인 커버리지 80% 이상을 유지한다. 80% 미만이면 빌드가 실패해야 한다(backend는 JaCoCo, front는 Vitest coverage).
- backend는 Spring 슬라이스 테스트를 기본으로 한다.
  - Controller: `@WebMvcTest` + MockMvc, 서비스는 `@MockitoBean`으로 대체. 요청 검증, 응답 형식, 인증·인가(401/403/404)를 확인한다.
  - Service: Spring 컨텍스트 없이 JUnit 5 + Mockito 단위 테스트. 비즈니스 규칙을 확인한다.
  - Repository: `@DataJpaTest` + Testcontainers(MySQL). 쿼리, 연관관계, 제약조건을 확인한다.
  - 그 밖의 슬라이스(`@JsonTest` 등)는 필요할 때 쓴다. `@SpringBootTest` 전체 컨텍스트 테스트는 핵심 흐름 몇 개의 통합 확인에만 쓴다.
- front는 Vitest + Testing Library 단위 테스트와 주요 사용자 흐름 Playwright E2E를 갖는다.

### IV. 보안과 공개 범위
인증은 토큰 기반이다. 모든 쓰기 API는 리소스 소유자를 검증한다. 비공개 글은 주인 외에게 404로 응답하며 목록, 검색, RSS, 사이트맵 어디에도 노출되지 않는다. 글이 어디에 어떻게 노출되는지는 001 data-model의 "글 노출 매트릭스" 한 곳에서 정하고, 각 스펙은 이를 참조한다. 사용자 입력 HTML(본문, 댓글)은 서버에서 XSS 필터링한다.

### V. 검색 엔진 친화 (SSR)
블로그 홈, 글 상세, 목록 같은 공개 페이지는 서버에서 렌더링하여 JavaScript 없이도 본문과 메타 태그(title, description, Open Graph)가 HTML에 포함되어야 한다.

### VI. 단순함
지금 필요한 것만 만든다. 추상화나 새 라이브러리는 plan.md의 Complexity Tracking에 이유를 적어야 도입할 수 있다.

### VII. 다국어 우선
화면에 보이는 모든 문구는 코드에 직접 쓰지 않고 메시지 키로 관리하며, 한국어·영어·일본어·중국어(간체) 4개 언어 번역을 같은 PR에 함께 넣는다. 번역 누락은 자동 점검(테스트)으로 막는다. backend 오류는 코드만 돌려주고 문구는 front가 언어에 맞게 보여준다(메일 문구는 backend 메시지 파일).

## 기술 제약

| 구분 | 결정 | 출처 |
|---|---|---|
| backend 언어 | Java 21 | 사용자 결정 |
| backend 빌드 | Maven | 사용자 결정 |
| backend 프레임워크 | Spring Boot 4.x, Spring Web, Spring Security | 사용자 결정(Spring Boot 4) |
| 영속성 | Spring Data JPA | 사용자 결정 |
| 인증 | 토큰 기반(JWT 접근 토큰 30분) + DB 저장 리프레시 토큰. 리프레시는 사용할 때마다 교체(rotation)하며 마지막 사용 후 4시간 유휴 만료, 최초 로그인 후 7일 절대 만료. 재사용 감지 시 해당 로그인 계열 전체 폐기 | 사용자 결정(토큰, 30분/4시간, 회전 방식 2026-10-06 승인). 7일은 기본값 |
| front | React + Vite, React Router framework 모드(SSR 내장, Vite 플러그인 기반), TypeScript | 사용자 결정(2026-10-06 승인) |
| DB | MySQL 8 | 기본값(미확정) |
| 스키마 마이그레이션 | Flyway | 기본값 |
| 패키지/식별자 | 공통 `net.java21.blog`. backend: Maven groupId `net.java21.blog`, artifactId `backend`, 기본 패키지 `net.java21.blog.backend`. front: 이름 `net.java21.blog.front`(package.json name) | 사용자 결정 |
| 서비스 도메인 | `blog.java21.net`. 블로그는 `blog.java21.net/{블로그주소}`, 글은 `blog.java21.net/{블로그주소}/{글번호}` | 사용자 결정 |
| 글 에디터 | Milkdown Crepe (Markdown 저장, 입력 즉시 서식 렌더링, `/` 명령·플로팅 메뉴, 큰 툴바 없음). 독자 화면은 서버에서 Markdown을 HTML로 변환하고 XSS 필터링 | 사용자 결정(2026-10-06 확정. TOAST UI 대체, CKEditor 스타일 배제). 상단 툴바(top-bar)와 AI 기능은 끔, UI 문구는 화면 언어(4개 언어)를 따름 |
| 첨부 파일 저장 | backend 프로퍼티로 관리: `blog.media.upload-dir`(정식), `blog.media.temp-dir`(임시), `blog.media.temp-ttl`(기본 24h), `blog.media.cleanup-cron`, `blog.media.max-size`(기본 10MB), `blog.media.temp-quota`(회원별 임시 한도, 기본 200MB), `blog.media.thumbnail-dir`, `blog.media.thumbnail.sizes`(허용 썸네일 크기 목록). 이미지 주소는 순번 ID가 아닌 추측할 수 없는 무작위 키(`/media/{key}`, 썸네일 `/media/{key}/{w}x{h}`)를 쓰며 허용 목록 외 크기는 거부. 임시(TEMP) 이미지는 올린 사람에게만 제공. 에디터 업로드는 임시 폴더 → 글 저장 시 정식 폴더로 이동, 미등록 임시 파일은 스케줄러가 삭제 | 사용자 결정 |
| 개인정보 암호화 | 개인정보 컬럼은 AES-256-GCM으로 암호화 저장, 조회 시 복호화(JPA AttributeConverter). 검색이 필요한 이메일은 HMAC 해시 컬럼 병행. 키는 프로퍼티 `blog.crypto.*`(환경 변수·외부 설정 파일로 주입, 저장소 커밋 금지), 키 버전으로 교체 지원 | 사용자 결정(암호화·프로퍼티 키), 해시 컬럼·GCM은 기본값 |
| 다국어 | 지원 언어 ko(기준)·en(기본 대체)·ja·zh-CN. front는 react-i18next(기본값), 번역 파일 `blog-front/app/locales/{lang}/*.json`. backend 메일 문구는 Spring MessageSource `messages_{lang}.properties`. 주소에 언어 접두어를 넣지 않음(쿠키·회원 설정·Accept-Language) | 사용자 결정(4개 언어), 라이브러리·URL 방식은 기본값 |
| API 문서 | springdoc-openapi, front 타입은 OpenAPI에서 생성 | 기본값 |

"기본값"으로 표시된 항목은 plan 단계에서 바꿀 수 있으며, 바꾸면 이 표를 개정한다.

## 1.0 운영 범위

| 항목 | 1.0 결정 | 출처 |
|---|---|---|
| HTTPS | certbot(Let's Encrypt)으로 인증서 발급·자동 갱신. 앞단 리버스 프록시(nginx 기본값)가 TLS를 처리하고 front로 전달하며, 이는 실행 "파트"로 세지 않는 인프라 | 사용자 결정(certbot), nginx는 기본값 |
| DB | 운영 측에서 별도 관리(설치·백업·복구). 애플리케이션은 접속 정보만 프로퍼티로 받음 | 사용자 결정 |
| 첨부 파일 백업 | DB 밖에 있는 `blog.media.upload-dir`·`thumbnail-dir`는 DB 백업에 포함되지 않으므로, 최소한 upload-dir의 일일 백업 절차를 문서화한다(썸네일은 다시 만들 수 있어 제외) | 기본값(검토 필요) |
| 로그 | 1.0은 최소 수준만: 애플리케이션 로그 파일(일별 롤링, 30일 보관), 요청 ID, 에러 스택. 헬스체크 엔드포인트 하나 | 사용자 결정(모니터링·장애 알림은 1.0 이후), 최소 로그는 기본값 |
| 모니터링·장애 알림·대시보드 | 1.0 이후 버전에서 도입 | 사용자 결정 |
| SEO 소유확인 등 | 1.0 이후 | 사용자 결정 |

## 개발 흐름

1. `blog-docs` 저장소에서 `/speckit-specify` → `/speckit-clarify` → `/speckit-plan` → `/speckit-tasks` → `/speckit-analyze` 순서로 스펙을 만든다.
2. 스펙은 기능 단위로 나눈다(현재 001 핵심 → 002 구독·탐색 → 003 포털 → 004 블로그 기능 → 005 트랙백·운영 → 007 외부 블로그 수집 순서. 006 관리 화면은 001(블로그 관리 뼈대)과 003(시스템 관리자 콘솔 뼈대)에서 시작해 각 스펙과 함께 채운다). 한 스펙이 사용자 스토리 5개를 넘으면 나눈다.
3. 구현은 `blog-docs` 저장소에서 Claude Code를 열고 `../blog-backend`, `../blog-front`를 추가 디렉터리로 붙여 `/speckit-implement`로 진행한다. tasks.md의 경로는 `blog-backend/...`, `blog-front/...` 접두어로 저장소를 구분한다.
4. 각 스펙의 data-model.md는 Mermaid `erDiagram`으로 ERD를 포함한다(GitHub에서 바로 렌더링). 이전 스펙의 테이블과 연결되는 관계도 표시한다.
5. 저장소 소개 문서는 4개 언어로 둔다. 조직 프로필은 `.github` 저장소의 `profile/README.md`(한국어, 기본)와 `README.en.md`·`README.ja.md`·`README.zh-CN.md`, 각 저장소 README도 같은 파일 규칙을 따르고 상단에 언어 전환 링크를 둔다.
6. 코드 변경은 해당 저장소에서 PR로 올리고, PR 설명에 스펙 경로(`blog-docs/specs/NNN-...`)를 적는다.

## Governance

이 헌법은 다른 모든 관행보다 우선한다. 개정은 이 파일의 수정과 버전 증가로만 하며, 원칙을 없애거나 뒤집으면 MAJOR, 원칙 추가는 MINOR, 문구 수정은 PATCH를 올린다. 모든 plan.md의 Constitution Check는 위 원칙 I~VII을 확인한다.

**Version**: 2.3.1 | **Ratified**: 2026-10-06 | **Last Amended**: 2026-10-06
