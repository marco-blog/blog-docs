# Blog Platform Constitution

<!-- Sync Impact Report: 1.0.0 최초 제정 (2026-10-06). 템플릿 변경 없음. -->

## 제품 목표

티스토리 같은 멀티 유저 블로그 플랫폼을 처음부터 만든다. 회원은 가입하면 자신의 블로그를 갖고 글을 쓰며, 방문자는 공개 글을 읽고 검색한다.

## Core Principles

### I. 스펙이 먼저다 (NON-NEGOTIABLE)
모든 기능은 `specs/` 아래의 spec.md → plan.md → tasks.md를 거친 뒤에 구현한다. spec.md는 "무엇을, 왜"만 쓰고 기술 선택은 plan.md에 쓴다. 스펙에 없는 기능은 구현하지 않는다. 모호한 점은 `/speckit-clarify`로 해소한 뒤 계획한다.

### II. 세 저장소, 두 개의 실행 파트
저장소는 `docs`(스펙), `backend`(Spring), `front`(React SSR) 셋으로 나눈다. 실행되는 파트는 backend와 front 둘뿐이며, 그 외 서비스(게이트웨이, BFF, 별도 인증 서버)를 추가하지 않는다. 두 파트는 backend가 제공하는 REST API(OpenAPI 문서)로만 통신한다.

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
인증은 토큰 기반이다. 모든 쓰기 API는 리소스 소유자를 검증한다. 비공개 글은 주인 외에게 404로 응답하며 목록, 검색, RSS, 사이트맵 어디에도 노출되지 않는다. 사용자 입력 HTML(본문, 댓글)은 서버에서 XSS 필터링한다.

### V. 검색 엔진 친화 (SSR)
블로그 홈, 글 상세, 목록 같은 공개 페이지는 서버에서 렌더링하여 JavaScript 없이도 본문과 메타 태그(title, description, Open Graph)가 HTML에 포함되어야 한다.

### VI. 단순함
지금 필요한 것만 만든다. 추상화나 새 라이브러리는 plan.md의 Complexity Tracking에 이유를 적어야 도입할 수 있다.

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
| 글 에디터 | Milkdown Crepe (Markdown 저장, 입력 즉시 서식 렌더링, `/` 명령·플로팅 메뉴, 큰 툴바 없음). 독자 화면은 서버에서 Markdown을 HTML로 변환하고 XSS 필터링 | 사용자 결정(2026-10-06 확정. TOAST UI 대체, CKEditor 스타일 배제). 상단 툴바(top-bar)와 AI 기능은 끔, UI 문구는 한국어로 설정 |
| 첨부 파일 저장 | backend 프로퍼티로 관리: `blog.media.upload-dir`(정식), `blog.media.temp-dir`(임시), `blog.media.temp-ttl`(기본 24h), `blog.media.cleanup-cron`, `blog.media.max-size`(기본 10MB), `blog.media.temp-quota`(회원별 임시 한도, 기본 200MB). 에디터 업로드는 임시 폴더 → 글 저장 시 정식 폴더로 이동, 미등록 임시 파일은 스케줄러가 삭제 | 사용자 결정 |
| API 문서 | springdoc-openapi, front 타입은 OpenAPI에서 생성 | 기본값 |

"기본값"으로 표시된 항목은 plan 단계에서 바꿀 수 있으며, 바꾸면 이 표를 개정한다.

## 개발 흐름

1. `docs` 저장소에서 `/speckit-specify` → `/speckit-clarify` → `/speckit-plan` → `/speckit-tasks` → `/speckit-analyze` 순서로 스펙을 만든다.
2. 스펙은 기능 단위로 나눈다(현재 001 핵심 → 002 구독·탐색 → 003 포털 → 004 블로그 기능 → 005 트랙백·운영 순서. 006 관리 화면은 001(블로그 관리 뼈대)과 003(시스템 관리자 콘솔 뼈대)에서 시작해 각 스펙과 함께 채운다). 한 스펙이 사용자 스토리 5개를 넘으면 나눈다.
3. 구현은 `docs` 저장소에서 Claude Code를 열고 `../backend`, `../front`를 추가 디렉터리로 붙여 `/speckit-implement`로 진행한다. tasks.md의 경로는 `backend/...`, `front/...` 접두어로 저장소를 구분한다.
4. 각 스펙의 data-model.md는 Mermaid `erDiagram`으로 ERD를 포함한다(GitHub에서 바로 렌더링). 이전 스펙의 테이블과 연결되는 관계도 표시한다.
5. 코드 변경은 해당 저장소에서 PR로 올리고, PR 설명에 스펙 경로(`docs/specs/NNN-...`)를 적는다.

## Governance

이 헌법은 다른 모든 관행보다 우선한다. 개정은 이 파일의 수정과 버전 증가로만 하며, 원칙을 없애거나 뒤집으면 MAJOR, 원칙 추가는 MINOR, 문구 수정은 PATCH를 올린다. 모든 plan.md의 Constitution Check는 위 원칙 I~VI을 확인한다.

**Version**: 2.1.0 | **Ratified**: 2026-10-06 | **Last Amended**: 2026-10-06
