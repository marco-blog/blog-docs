# Blog Platform Constitution

<!-- Sync Impact Report: 1.0.0 최초 제정 (2026-10-06). 템플릿 변경 없음. -->

## 제품 목표

티스토리 같은 멀티 유저 블로그 플랫폼을 처음부터 만든다. 회원은 가입하면 자신의 블로그를 갖고 글을 쓰며, 방문자는 공개 글을 읽고 검색한다.

## Core Principles

### I. 스펙이 먼저다 (NON-NEGOTIABLE)
모든 기능은 `specs/` 아래의 spec.md → plan.md → tasks.md를 거친 뒤에 구현한다. spec.md는 "무엇을, 왜"만 쓰고 기술 선택은 plan.md에 쓴다. 스펙에 없는 기능은 구현하지 않는다. 모호한 점은 `/speckit-clarify`로 해소한 뒤 계획한다.

### II. 세 저장소, 두 개의 실행 파트
저장소는 `docs`(스펙), `backend`(Spring), `front`(React SSR) 셋으로 나눈다. 실행되는 파트는 backend와 front 둘뿐이며, 그 외 서비스(게이트웨이, BFF, 별도 인증 서버)를 추가하지 않는다. 두 파트는 backend가 제공하는 REST API(OpenAPI 문서)로만 통신한다.

### III. 테스트 우선
tasks.md는 구현 작업보다 테스트 작업을 앞에 둔다. backend는 서비스 단위 테스트와 API 통합 테스트(Testcontainers 실제 DB), front는 주요 사용자 흐름 E2E 테스트를 갖는다. 스펙의 인수 시나리오마다 대응하는 테스트가 있어야 한다.

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
| 인증 | 토큰 기반(JWT). Access Token 유효기간 30분, Refresh Token 유효기간 4시간 | 사용자 결정(토큰, 유효기간), JWT 형식은 기본값 |
| front | React + Vite, SSR은 Vite SSR(Node Express 서버, React `renderToPipeableStream`), 라우팅은 React Router, TypeScript | React·Vite·SSR은 사용자 결정, Express·React Router·TypeScript는 기본값 |
| DB | MySQL 8 | 기본값(미확정) |
| 스키마 마이그레이션 | Flyway | 기본값 |
| 패키지/식별자 | 공통 `net.java21.blog`. backend: Maven groupId `net.java21.blog`, artifactId `backend`, 기본 패키지 `net.java21.blog.backend`. front: 이름 `net.java21.blog.front`(package.json name) | 사용자 결정 |
| API 문서 | springdoc-openapi, front 타입은 OpenAPI에서 생성 | 기본값 |

"기본값"으로 표시된 항목은 plan 단계에서 바꿀 수 있으며, 바꾸면 이 표를 개정한다.

## 개발 흐름

1. `docs` 저장소에서 `/speckit-specify` → `/speckit-clarify` → `/speckit-plan` → `/speckit-tasks` → `/speckit-analyze` 순서로 스펙을 만든다.
2. 구현은 `docs` 저장소에서 Claude Code를 열고 `../backend`, `../front`를 추가 디렉터리로 붙여 `/speckit-implement`로 진행한다. tasks.md의 경로는 `backend/...`, `front/...` 접두어로 저장소를 구분한다.
3. 코드 변경은 해당 저장소에서 PR로 올리고, PR 설명에 스펙 경로(`docs/specs/NNN-...`)를 적는다.

## Governance

이 헌법은 다른 모든 관행보다 우선한다. 개정은 이 파일의 수정과 버전 증가로만 하며, 원칙을 없애거나 뒤집으면 MAJOR, 원칙 추가는 MINOR, 문구 수정은 PATCH를 올린다. 모든 plan.md의 Constitution Check는 위 원칙 I~VI을 확인한다.

**Version**: 1.2.0 | **Ratified**: 2026-10-06 | **Last Amended**: 2026-10-06
