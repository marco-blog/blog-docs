# Implementation Plan: 블로그 핵심 (가입·글·카테고리·댓글·이미지)

**Branch**: `001-blog-core` | **Date**: 2026-10-06 | **Spec**: [spec.md](./spec.md)

**Status**: Phase 1 완료 (contracts, quickstart 작성). 다음 단계는 `/speckit-tasks`.

**Input**: Feature specification from `/specs/001-blog-core/spec.md`

## Summary

서비스의 기반 스펙. 회원가입과 동시에 `blog.java21.net/{블로그주소}` 블로그가 생기고, Markdown 에디터로 글을 써서 발행하면 방문자는 서버 렌더링된 페이지로 읽는다. 카테고리·태그, 댓글, 이미지(임시 업로드 → 글 저장 시 등록, 썸네일), 계정 설정(비밀번호 변경·재설정, 로그인 기록, 언어·시간대), 개인정보 암호화, 4개 언어 화면(US5), 006 블로그 관리의 뼈대(FR-096~101 중 001 메뉴)를 포함한다. 002~007 스펙은 이 위에 쌓는다.

기술 접근: backend는 Spring Boot 4 REST API(JWT 접근 토큰 30분 + 회전되는 DB 리프레시 토큰, 유휴 4시간·절대 7일, HttpOnly 쿠키). front는 React Router framework 모드(Vite) SSR. 브라우저는 front 서버 하나만 보고, front 서버가 `/api/**`(API는 `/api/v1/...`)·`/media/**`를 backend로 프록시한다. 화면 문구는 react-i18next로 4개 언어(ko·en·ja·zh-CN)를 제공한다. 세부 근거는 [research.md](./research.md).

## Technical Context

**Language/Version**: backend Java 21 / front TypeScript 5.x, Node.js 22 LTS

**Primary Dependencies**:
- backend: Spring Boot 4.1.x(Web MVC, Security, Data JPA, Validation, Mail), jjwt 0.13, Flyway, springdoc-openapi 3.x, commonmark-java, OWASP Java HTML Sanitizer, Caffeine, Thumbnailator + TwelveMonkeys ImageIO WebP(R11), Spring MessageSource(메일 문구, R22·R23)
- front: React 19, Vite 8, React Router 8 framework 모드(@react-router/dev, @react-router/express), Express 5, @milkdown/crepe 7.x(R7), openapi-typescript, i18next + react-i18next(R22), highlight.js(R24, 서버 렌더링 전용)

**Storage**: MySQL 8(InnoDB, utf8mb4), 이미지·썸네일 파일은 로컬 디스크(저장소 인터페이스로 추상화). 검색용 FULLTEXT ngram 인덱스는 002에서 추가

**Testing**:
- backend: JUnit 5, Spring 슬라이스(`@WebMvcTest`, `@DataJpaTest`), Mockito, Testcontainers 2.x MySQL, JaCoCo(라인 80% 미만 시 `verify` 실패)
- front: Vitest 5 + Testing Library(coverage threshold 80%), Playwright E2E
- 번역 누락 점검(SC-024): front 키 집합 비교 테스트(Vitest), backend `messages_*.properties` 키 비교 테스트(JUnit), R22

**Target Platform**: Linux 서버 1대(Docker Compose: mysql, backend, front), 최신 데스크톱/모바일 브라우저

**Project Type**: 웹 서비스(REST API + SSR 웹 앱), 저장소 3개(docs, backend, front)

**Performance Goals**: 글 상세 SSR 응답 p95 1초 이내(SC-002), 동시 접속 200(SC-003). 검색(SC-007)은 002

**Constraints**: 공개 페이지는 JS 없이 본문·메타 포함(원칙 V), 비공개 콘텐츠 노출 0건(원칙 IV, SC-004, data-model 글 노출 매트릭스), 커버리지 80%(원칙 III), 개인정보 컬럼 평문 0건(SC-022), 번역 누락 0건(원칙 VII, SC-024)

**Scale/Scope**: 회원 1만, 글 10만, 화면 약 20개, API 약 45개

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| 원칙 | 확인 | 결과 |
|---|---|---|
| I. 스펙이 먼저다 | spec.md 확정, NEEDS CLARIFICATION 0개, 본 plan은 spec의 FR만 다룸 | 통과 |
| II. 세 저장소, 두 실행 파트 | 실행 파트는 backend, front뿐. front의 `/api` 프록시는 front 서버 내부 기능이며 별도 서비스 아님 | 통과 |
| III. 테스트 우선·커버리지 | 슬라이스 테스트 전략과 JaCoCo/Vitest 80% 게이트를 quickstart와 tasks에 반영 | 통과 |
| IV. 보안과 공개 범위 | JWT + DB 리프레시 토큰, 소유자 검증, 비공개 404, 저장 시 HTML 살균(iframe은 YouTube·Vimeo만), 노출 규칙은 data-model 글 노출 매트릭스 한 곳, 이미지 주소는 추측 불가 키·TEMP는 올린 사람만, 개인정보 AES-256-GCM | 통과 |
| V. SSR | 공개 라우트는 React Router `loader`로 서버 조회, `meta`로 메타 태그 | 통과 |
| VI. 단순함 | 캐시는 Caffeine(프로세스 내), 파일은 로컬 디스크, 정기 작업은 `@Scheduled`(1대 전제). 외부 검색엔진·Redis·S3·Quartz는 도입하지 않음. 새 라이브러리(Thumbnailator·TwelveMonkeys, highlight.js)는 Complexity Tracking에 기록 | 통과 |
| VII. 다국어 우선 | 화면 문구는 react-i18next 메시지 키(`blog-front/app/locales/{ko,en,ja,zh-CN}`), 메일은 MessageSource, API 오류는 코드만(`message`는 영어 디버그용), 에디터 메뉴도 번역, 번역 누락 테스트가 CI에서 실패 처리(SC-024), 주소에 언어 접두어 없음 | 통과 |
| 기술 제약 | Java 21, Maven, Spring Boot 4, JPA, `net.java21.blog.backend`, 토큰 30분 + 회전 리프레시(4시간/7일), React Router framework(Vite), 첨부 파일·썸네일 프로퍼티, `blog.crypto.*`, `blog.java21.net` | 통과 |

**Phase 1 이후 재확인**: data-model, contracts, quickstart 작성 후 원칙 I~VII을 다시 점검했고 위반 없음. 새 라이브러리 도입 이유는 Complexity Tracking에 적었다.

## Project Structure

### Documentation (this feature)

```text
specs/001-blog-core/
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
blog-backend/                              # 저장소: blog-backend
├── pom.xml                                # groupId net.java21.blog, artifactId backend
├── src/main/java/net/java21/blog/backend/
│   ├── BackendApplication.java
│   ├── common/        # 에러 응답(code + fieldErrors[].code, message는 영어 디버그용), 예외 핸들러, 페이지 응답, 시간
│   ├── security/      # SecurityConfig, JwtProvider, JwtAuthFilter, CurrentUser, Origin 검사 필터(예외 목록), 관리자 API 역할 DB 확인
│   ├── crypto/        # AES-256-GCM AttributeConverter, HMAC 해시, 키 버전·재암호화 배치 (FR-134~136)
│   ├── auth/          # 가입(약관 동의), 로그인, 리프레시, 로그아웃, 로그인 잠금, 비밀번호 재설정·변경, 로그인 기록
│   ├── user/          # 회원, 프로필, 언어·시간대, 탈퇴, 개인정보 파기 작업
│   ├── blog/          # 블로그 정보·설정, 예약어 상수
│   ├── manage/        # 006 블로그 관리 뼈대: 대시보드 수치, 글 관리 일괄 작업, 댓글 관리 (FR-096~101 중 001 범위)
│   ├── category/
│   ├── post/          # 글, 작성 중 사본, 발행, 휴지통·복구·영구 삭제 작업, 조회수, 이전/다음, 노출 조건 쿼리 조각
│   ├── tag/
│   ├── content/       # Markdown → HTML 변환 + 살균(동영상 iframe 허용 목록)
│   ├── comment/
│   ├── media/         # 업로드(무작위 키), 저장소 인터페이스, post_media, 정리 작업
│   │   └── thumbnail/ # 허용 크기 검사, Thumbnailator 생성, 키별 락 + 원자적 이름 변경
│   ├── mail/          # JavaMailSender 구성(blog.mail.*), 언어별 메일 문구
│   ├── i18n/          # MessageSource 설정, 회원 locale 해석
│   └── legal/         # 약관·개인정보처리방침 4개 언어 본문, 약관 버전
│   (각 도메인 패키지 안: controller, service, repository, domain, dto)
│   (002 like·subscription·notification·search, 003 portal, 004·005·006·007 패키지는 각 스펙의 plan에서 추가)
├── src/main/resources/
│   ├── application.yml
│   ├── messages_{ko,en,ja,zh_CN}.properties   # 메일 문구 (R22, R23)
│   ├── legal/{terms,privacy}_{ko,en,ja,zh-CN}.md
│   └── db/migration/V1__init.sql ...
└── src/test/java/net/java21/blog/backend/
    ├── {domain}/controller/*ControllerTest.java   # @WebMvcTest
    ├── {domain}/service/*ServiceTest.java         # Mockito 단위
    ├── {domain}/repository/*RepositoryTest.java   # @DataJpaTest + Testcontainers
    └── support/                                   # 테스트 픽스처, 컨테이너 설정

blog-front/                                # 저장소: blog-front
├── package.json                           # name net.java21.blog.front
├── react-router.config.ts                 # ssr: true
├── vite.config.ts
├── server.ts                              # Express: /api·/media 프록시 + React Router 요청 핸들러
├── app/
│   ├── root.tsx                           # 공통 레이아웃, 에러 경계
│   ├── routes.ts                          # 라우트 정의 (contracts/routes.md 기준)
│   ├── routes/                            # 라우트 모듈: loader, action, meta, 컴포넌트 (manage/*, settings/* 포함)
│   ├── locales/{ko,en,ja,zh-CN}/*.json    # 번역 파일 (R22)
│   ├── i18n/                              # i18next 설정, 서버 언어 결정, Intl 날짜·숫자 형식
│   ├── content/                           # contentHtml 코드 블록 강조(highlight.js, 서버 전용, R24)
│   ├── components/
│   │   └── Editor/                        # 에디터 래퍼(value, onChange, onUploadImage) - 라이브러리 교체 지점
│   ├── api/
│   │   ├── schema.d.ts                    # openapi-typescript 생성물
│   │   └── client.server.ts               # loader/action용 backend 호출(쿠키 전달)
│   └── seo/
├── tests/unit/                            # Vitest (번역 키 누락 점검 포함)
└── tests/e2e/                             # Playwright
```

**Structure Decision**: 저장소 3개(docs, backend, front)를 형제 디렉터리로 둔다(원칙 II). backend는 도메인별 패키지, front는 React Router framework 모드 기본 구조(`app/`)에 커스텀 Express 서버를 둔다.

## 구현 순서 (사용자 스토리 기준)

| 단계 | 스토리 | 핵심 산출물 | FR |
|---|---|---|---|
| 0 | 기반 | 두 앱 뼈대, Flyway V1, 보안 설정(Origin 검사·예외 목록), 에러 응답 형식, 개인정보 암호화 컨버터, i18n 기반(react-i18next·locales·MessageSource·번역 누락 테스트), SSR 서버와 프록시, 정기 작업 설정, 커버리지 게이트, CI | FR-134~136, FR-148, FR-152, FR-154 |
| 1 | US1 가입·글쓰기 (P1) | auth(가입·약관 동의·로그인·리프레시·잠금·로그아웃), user, blog, post(작성 중 사본·완료·발행 설정·수정 발행), content(변환·살균·동영상 iframe), 코드 강조, 블로그 홈/글 상세 SSR, 에디터 래퍼, 휴지통·복구·영구 삭제 작업 | FR-001~007, FR-010~022, FR-036, FR-070, FR-081, FR-083, FR-084, FR-107, FR-108, FR-140 |
| 1a | US1 계정 설정 | 비밀번호 변경·재설정(메일), 로그인 기록, 프로필·탈퇴, 개인정보 파기 작업, 약관·개인정보처리방침 페이지 | FR-008, FR-009, FR-082, FR-133, FR-137~139 |
| 1b | 006 블로그 관리 뼈대 | `/manage` 레이아웃·좌측 메뉴, 대시보드(글·댓글 수치만, 방문자는 004), 글 관리(필터·검색·일괄 작업·휴지통), 블로그 설정, noindex | 006 FR-096~101(001 범위) |
| 2 | US2 카테고리·태그 (P2) | category, tag, 목록 필터, 카테고리 관리 메뉴 | FR-023~026 |
| 3 | US3 댓글 (P3) | comment, 글별·블로그별 댓글 허용, 댓글 관리 메뉴 | FR-027~029 |
| 4 | US4 이미지 (P4) | media(무작위 키, 임시 업로드, 등록, post_media, 프로필·대표 이미지, 정리 작업), 썸네일 | FR-038, FR-039, FR-071~074, FR-130~132, FR-156 |
| 5 | US5 다국어 (P5) | 4개 언어 번역 완성, 언어 결정·하단 선택(`/locale`), `/settings/language`(언어·시간대), 날짜·시간대 표기, 메일 언어, 에디터 메뉴 번역 | FR-148~155 |

각 단계는 끝날 때 해당 스토리의 Independent Test를 E2E로 통과해야 한다. 0단계의 i18n 기반 위에서 1~4단계의 모든 화면 문구는 처음부터 메시지 키로 쓰고 4개 언어 번역을 같은 PR에 넣는다(원칙 VII). 5단계는 언어 선택·설정 화면과 누락 점검 0건 확인을 마무리한다. 좋아요·구독·검색·RSS(002), 포털(003), 방명록·보호 글·예약·방문자 수(004), 신고·트랙백(005), 시스템 관리자 콘솔과 006의 나머지 메뉴, 외부 블로그(007)는 이 계획에 포함하지 않는다.

## Complexity Tracking

| 도입 | 이유 | 더 단순한 대안을 쓰지 않은 이유 |
|---|---|---|
| Thumbnailator + TwelveMonkeys ImageIO(WebP 읽기) | FR-130~132 썸네일 생성(축소·자르기·GIF 첫 장면·WebP 원본) | JDK ImageIO만으로는 WebP를 읽지 못하고 고품질 축소 코드를 직접 써야 함 |
| highlight.js(front 서버 렌더링 전용) | FR-083 코드 블록 문법 강조 | commonmark-java에 강조 기능이 없음. 브라우저에는 스크립트를 보내지 않음(R24) |
| i18next + react-i18next | FR-148~155, 원칙 VII | 헌법 기술 제약의 기본값. 직접 구현하면 대체 언어·namespace·SSR 리소스 전달을 다시 만들어야 함(R22) |
