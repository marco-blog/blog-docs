# Implementation Plan: 멀티 유저 블로그 플랫폼 MVP

**Branch**: `001-blog-platform-mvp` | **Date**: 2026-10-06 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-blog-platform-mvp/spec.md`

## Summary

티스토리 같은 멀티 유저 블로그 MVP. 회원가입과 동시에 `blog.java21.net/{블로그주소}` 블로그가 생기고, TOAST UI Editor로 Markdown 글을 써서 발행하면 방문자는 서버 렌더링된 페이지로 읽는다. 카테고리·태그·댓글·좋아요·구독 피드·검색·이미지·신고를 사용자 스토리 우선순위(P1~P7) 순서로 쌓는다.

기술 접근: backend는 Spring Boot 4 REST API(JWT 접근 토큰 30분 + DB 저장 리프레시 토큰 4시간, HttpOnly 쿠키), front는 Vite + React SSR(Express 서버). 브라우저는 front 서버 하나만 보고, front 서버가 `/api/**`를 backend로 프록시해 쿠키를 같은 도메인으로 유지한다. 세부 근거는 [research.md](./research.md).

## Technical Context

**Language/Version**: backend Java 21 / front TypeScript 5.x, Node.js 22 LTS

**Primary Dependencies**:
- backend: Spring Boot 4.1.x(Web MVC, Security, Data JPA, Validation), jjwt 0.13, Flyway, springdoc-openapi 3.x, commonmark-java, OWASP Java HTML Sanitizer, Caffeine
- front: React 19, Vite 8, React Router(라이브러리 모드), Express 5, @toast-ui/editor 3.2(코어 직접 사용), openapi-typescript

**Storage**: MySQL 8(InnoDB, utf8mb4, FULLTEXT ngram 파서), 이미지 파일은 로컬 디스크(저장소 인터페이스로 추상화)

**Testing**:
- backend: JUnit 5, Spring 슬라이스(`@WebMvcTest`, `@DataJpaTest`), Mockito, Testcontainers 2.x MySQL, JaCoCo(라인 80% 미만 시 `verify` 실패)
- front: Vitest 5 + Testing Library(coverage threshold 80%), Playwright E2E

**Target Platform**: Linux 서버 1대(Docker Compose: mysql, backend, front), 최신 데스크톱/모바일 브라우저

**Project Type**: 웹 서비스(REST API + SSR 웹 앱), 저장소 3개(docs, backend, front)

**Performance Goals**: 글 상세 SSR 응답 p95 1초 이내(SC-002), 검색 p95 2초 이내(SC-007), 동시 접속 200(SC-003)

**Constraints**: 공개 페이지는 JS 없이 본문·메타 포함(원칙 V), 비공개 콘텐츠 노출 0건(원칙 IV, SC-004), 커버리지 80%(원칙 III)

**Scale/Scope**: 회원 1만, 글 10만, 화면 약 20개, API 약 45개

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| 원칙 | 확인 | 결과 |
|---|---|---|
| I. 스펙이 먼저다 | spec.md 확정, NEEDS CLARIFICATION 0개, 본 plan은 spec의 FR만 다룸 | 통과 |
| II. 세 저장소, 두 실행 파트 | 실행 파트는 backend, front뿐. front의 `/api` 프록시는 front 서버 내부 기능이며 별도 서비스 아님 | 통과 |
| III. 테스트 우선·커버리지 | 슬라이스 테스트 전략과 JaCoCo/Vitest 80% 게이트를 quickstart와 tasks에 반영 | 통과 |
| IV. 보안과 공개 범위 | JWT + DB 리프레시 토큰, 소유자 검증, 비공개 404, 저장 시 HTML 살균 | 통과 |
| V. SSR | 공개 라우트는 `renderToPipeableStream` + 라우트별 데이터 선로딩 + 메타 태그 | 통과 |
| VI. 단순함 | 캐시는 Caffeine(프로세스 내), 검색은 MySQL FULLTEXT, 파일은 로컬 디스크. 외부 검색엔진·Redis·S3는 도입하지 않음 | 통과 |
| 기술 제약 | Java 21, Maven, Spring Boot 4, JPA, `net.java21.blog.backend`, 토큰 30분/4시간, Vite+React SSR, TOAST UI, `blog.java21.net` | 통과 |

**Phase 1 이후 재확인**: data-model, contracts, quickstart 작성 후 위 표를 다시 점검했고 위반 없음. Complexity Tracking 비어 있음.

## Project Structure

### Documentation (this feature)

```text
specs/001-blog-platform-mvp/
├── plan.md              # 이 문서
├── research.md          # Phase 0: 기술 결정과 근거
├── data-model.md        # Phase 1: 엔티티·테이블·상태 전이
├── quickstart.md        # Phase 1: 실행·검증 시나리오
├── contracts/
│   ├── api.md           # REST API 계약(엔드포인트, 요청/응답, 에러 코드)
│   └── routes.md        # front 화면 라우트 계약(SSR 여부, 메타 태그)
├── checklists/requirements.md
└── tasks.md             # Phase 2: /speckit-tasks가 생성
```

### Source Code

```text
backend/                                   # 저장소: backend
├── pom.xml                                # groupId net.java21.blog, artifactId backend
├── src/main/java/net/java21/blog/backend/
│   ├── BackendApplication.java
│   ├── common/        # 에러 응답, 예외 핸들러, 페이지 응답, 시간
│   ├── security/      # SecurityConfig, JwtProvider, JwtAuthFilter, CurrentUser
│   ├── auth/          # 가입, 로그인, 리프레시, 로그아웃, 로그인 잠금
│   ├── user/          # 회원, 프로필, 탈퇴
│   ├── blog/          # 블로그 정보·설정, 예약어 검사
│   ├── category/
│   ├── post/          # 글, 임시저장, 조회수, 이전/다음
│   ├── tag/
│   ├── content/       # Markdown → HTML 변환 + 살균
│   ├── comment/
│   ├── like/
│   ├── subscription/  # 구독, 피드
│   ├── notification/
│   ├── discover/      # 메인 최신/인기, 검색, 사이트맵, RSS
│   ├── media/         # 업로드, 저장소 인터페이스
│   ├── report/
│   └── admin/
│   (각 도메인 패키지 안: controller, service, repository, domain, dto)
├── src/main/resources/
│   ├── application.yml
│   └── db/migration/V1__init.sql ...
└── src/test/java/net/java21/blog/backend/
    ├── {domain}/controller/*ControllerTest.java   # @WebMvcTest
    ├── {domain}/service/*ServiceTest.java         # Mockito 단위
    ├── {domain}/repository/*RepositoryTest.java   # @DataJpaTest + Testcontainers
    └── support/                                   # 테스트 픽스처, 컨테이너 설정

front/                                     # 저장소: front
├── package.json                           # name net.java21.blog.front
├── server.ts                              # Express: 정적 파일, /api 프록시, SSR
├── vite.config.ts
├── src/
│   ├── entry-client.tsx                   # hydrateRoot
│   ├── entry-server.tsx                   # renderToPipeableStream
│   ├── routes.tsx                         # 라우트 정의 + 라우트별 loader
│   ├── pages/                             # 화면 (contracts/routes.md 기준)
│   ├── components/                        # 공통 UI, Editor(TOAST UI 래퍼)
│   ├── api/
│   │   ├── schema.d.ts                    # openapi-typescript 생성물
│   │   └── client.ts                      # fetch 래퍼(서버/브라우저 공용)
│   └── seo/                               # 메타 태그 헬퍼
├── tests/unit/                            # Vitest
└── tests/e2e/                             # Playwright
```

**Structure Decision**: 저장소 3개(docs, backend, front)를 형제 디렉터리로 둔다(원칙 II). backend는 도메인별 패키지, front는 Vite 공식 SSR 구조(entry-client / entry-server / server)를 따른다.

## 구현 순서 (사용자 스토리 기준)

| 단계 | 스토리 | 핵심 산출물 |
|---|---|---|
| 0 | 기반 | 두 앱 뼈대, Docker Compose, Flyway V1, 보안 설정, SSR 서버, 커버리지 게이트, CI |
| 1 | US1 가입·글쓰기 (P1) | auth, user, blog, post, content, 블로그 홈/글 상세 SSR, 에디터 |
| 2 | US2 카테고리·태그 (P2) | category, tag, 목록 필터 |
| 3 | US3 댓글 (P3) | comment |
| 4 | US4 좋아요·구독·피드 (P4) | like, subscription, notification |
| 5 | US5 둘러보기·검색 (P5) | discover, 사이트맵, RSS, 메타 태그 점검 |
| 6 | US6 이미지 (P6) | media |
| 7 | US7 신고·운영 (P7) | report, admin |

각 단계는 끝날 때 해당 스토리의 Independent Test를 E2E로 통과해야 한다.

## Complexity Tracking

없음.
