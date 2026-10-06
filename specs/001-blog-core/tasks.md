---
description: "001 블로그 핵심 작업 목록"
---

# Tasks: 블로그 핵심 (가입·글·카테고리·댓글·이미지)

**Input**: `/specs/001-blog-core/`의 설계 문서 (spec.md, plan.md, research.md, data-model.md, contracts/api.md, contracts/routes.md, quickstart.md)

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, 헌법 v2.5.0, [api-guidelines.md](../../api-guidelines.md), [db/README.md](../../db/README.md)

**Tests**: 헌법 원칙 III(NON-NEGOTIABLE)에 따라 모든 스토리에 테스트 작업이 있고, 각 스토리 안에서 테스트 작업이 구현 작업보다 앞선다. 테스트를 먼저 쓰고 **실패하는 것을 확인한 뒤** 구현한다. backend·front 모두 라인 커버리지 80% 미만이면 빌드가 실패한다.

**Organization**: 사용자 스토리별로 묶었다. US1은 plan.md 구현 순서의 1·1a·1b 단계를 세 Phase로 나눴다(가입·글쓰기 / 계정 설정 / 블로그 관리 뼈대).

## Format: `[ID] [P?] [Story] Description`

- **[X]**: 이미 끝났거나 별도 브랜치에서 진행 중이라 기반으로 간주하는 작업(새로 하지 않는다)
- **[P]**: 병렬 가능(다른 파일, 끝나지 않은 작업에 의존하지 않음)
- **[Story]**: 해당 사용자 스토리(US1~US5)
- 경로는 저장소 이름(`blog-backend/`, `blog-front/`)으로 시작한다(blog-docs CLAUDE.md 규칙)

## Path Conventions

- backend 소스: `blog-backend/src/main/java/net/java21/blog/backend/{domain}/{controller|service|repository|domain|dto|job}/`
- backend 테스트: `blog-backend/src/test/java/net/java21/blog/backend/{domain}/...` (Controller `*ControllerTest` = `@WebMvcTest` + `@MockitoBean`, Service `*ServiceTest` = Mockito 단위, Repository `*RepositoryTest` = H2 `@JpaRepositoryTest`(아래 Phase 2에서 만듦), MySQL 전용만 `@MySqlRepositoryTest`)
- backend 리소스: `blog-backend/src/main/resources/`
- front: `blog-front/app/` (routes, components, locales, i18n, api, content, seo), 단위 테스트 `blog-front/tests/unit/`, E2E `blog-front/tests/e2e/`
- 화면 문구는 모두 `blog-front/app/locales/{ko,en,ja,zh-CN}/{namespace}.json` 키로 쓰고 4개 언어를 같은 작업에서 넣는다(원칙 VII). 아래 front 구현 작업의 "문구"는 모두 이 규칙을 따른다.
- backend 오류 코드는 `ErrorCode` enum에 contracts/api.md 표의 이름·HTTP 상태 그대로 더한다.

## 스키마 변경

없음. Crowfoot 문서 "blog 1.0"의 40개 테이블(db/schema-mysql.sql, db/migrations/0001-baseline.sql)에 001에 필요한 테이블·컬럼·인덱스·외래 키가 모두 있다. 엔티티는 기존 스키마에 맞춰 만들며(`ddl-auto=validate`), 작업 중 스키마 변경이 필요해지면 새 작업을 만들어 [db/README.md](../../db/README.md) 절차(data-model·erd.md 수정 → Crowfoot 문서 → `plan_migration` → **marco 승인** → `apply_migration` → `migrations/NNNN-*.sql` → `schema-mysql.sql`·backend 테스트 스냅숏 갱신 → 엔티티)를 따른다.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: 두 저장소의 빌드·테스트·CI 기반

- [X] T001 backend 뼈대: Spring Boot 4.1.1, Java 21, Maven Wrapper, `blog-backend/pom.xml`, `blog-backend/src/main/java/net/java21/blog/backend/BlogBackendApplication.java`
- [X] T002 설정 프로필 local(기본)·prod·test와 `.env` 비밀 값 가져오기: `blog-backend/src/main/resources/application.yml`, `application-local.yml`, `application-prod.yml`, `blog-backend/src/test/resources/application-test.yml`, `blog-backend/.env.example`
- [X] T003 테스트 MySQL 스키마 지원: `blog-backend/src/test/java/net/java21/blog/backend/support/MySqlRepositoryTest.java`, `TestSchemaInitializer.java`, `TestSchemaGuard.java`, 스냅숏 `blog-backend/src/test/resources/db/schema-mysql.sql`, `blog-backend/src/test/java/net/java21/blog/backend/db/SchemaSnapshotTest.java`
- [X] T004 JaCoCo 라인 커버리지 80% 게이트(`./mvnw verify` 실패): `blog-backend/pom.xml`
- [X] T005 front 뼈대(별도 브랜치 진행 중): React Router framework 모드 SSR, `blog-front/package.json`(name `net.java21.blog.front`), `blog-front/react-router.config.ts`(`ssr: true`), `blog-front/vite.config.ts`, `blog-front/server.ts`(Express, `/api/**`·`/media/**` backend 프록시)
- [X] T006 front Vitest + Testing Library, 라인 80% 게이트(별도 브랜치 진행 중): `blog-front/vitest.config.ts`
- [ ] T007 [P] QueryDSL(OpenFeign 포크 `io.github.openfeign.querydsl:querydsl-jpa` 7.x, `querydsl-apt` jakarta 프로세서)를 `blog-backend/pom.xml`에 추가하고 annotation processor 경로를 `maven-compiler-plugin`에 등록, JaCoCo 측정에서 생성된 `Q*` 클래스 제외
- [ ] T008 [P] H2 의존성(`com.h2database:h2`, test scope)을 `blog-backend/pom.xml`에 추가
- [ ] T009 [P] Playwright E2E 기반: `blog-front/playwright.config.ts`(front·backend 주소는 환경 변수), 가입 계정·글 생성 헬퍼 `blog-front/tests/e2e/support/fixtures.ts`, Mailpit API 헬퍼 `blog-front/tests/e2e/support/mailpit.ts`, `blog-front/package.json` 스크립트 `e2e`
- [ ] T010 [P] OpenAPI 타입 생성 스크립트 `gen:api`(openapi-typescript, backend `/v3/api-docs` → `blog-front/app/api/schema.d.ts`)를 `blog-front/package.json`에 추가(뼈대 브랜치에 이미 있으면 [X]로 표시)
- [ ] T011 [P] backend CI `blog-backend/.github/workflows/ci.yml`: PR·main push 트리거, JDK 21(temurin), Maven 캐시, `./mvnw -B verify`(JaCoCo 게이트 포함). `@MySqlRepositoryTest`용 `BLOG_TEST_DATASOURCE_URL/USERNAME/PASSWORD`·`BLOG_TEST_ALLOW_CLEAN`은 저장소 secret에서 주입하고, 없으면 해당 테스트는 건너뜀(개발 DB `cf_u2_d2` 접속 정보는 절대 넣지 않음)
- [ ] T012 [P] front CI `blog-front/.github/workflows/ci.yml`: Node 22, `npm ci`, `npm run typecheck`, `npm run lint`, `npm test -- --coverage`(80% 게이트, 번역 누락 테스트 포함), `npm run build`
- [ ] T013 [P] `blog-backend/CLAUDE.md`를 헌법 2.5.0에 맞게 고침: Flyway → Crowfoot(blog-docs/db/README.md), Testcontainers → H2 `@DataJpaTest` + MySQL 전용 쿼리만 `@MySqlRepositoryTest`, 오류 응답 `{code,message}` → 공통 틀(api-guidelines.md), QueryDSL·N+1 규칙

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: 모든 스토리가 쓰는 공통 기반(테스트 지원, JPA·QueryDSL, 인증 토큰 검증, 공통 화면 틀)

**⚠️ CRITICAL**: 이 Phase가 끝나기 전에는 어떤 스토리도 시작하지 않는다

### 이미 있는 기반

- [X] T014 공통 응답 `blog-backend/src/main/java/net/java21/blog/backend/common/api/ApiResponse.java`, `FieldError.java`
- [X] T015 오류 처리 `blog-backend/src/main/java/net/java21/blog/backend/common/error/ErrorCode.java`, `BusinessException.java`, `GlobalExceptionHandler.java`, `ApiErrorWriter.java`, 테스트 `blog-backend/src/test/java/net/java21/blog/backend/common/CommonResponseWebMvcTest.java`
- [X] T016 요청 추적 ID(MDC `traceId`, `X-Request-Id`) `blog-backend/src/main/java/net/java21/blog/backend/common/web/RequestIdFilter.java`
- [X] T017 기본 보안 설정(stateless, 401/403 공통 형식) `blog-backend/src/main/java/net/java21/blog/backend/config/SecurityConfig.java`
- [X] T018 개인정보 암호화(별도 브랜치 진행 중, FR-134~136): AES-256-GCM `AttributeConverter`(키 버전 1바이트 + IV 12바이트 + 암호문 + 태그 16바이트), HMAC-SHA256 해시, 프로퍼티 `blog.crypto.keys`·`active-key-version`·`hash-key` — `blog-backend/src/main/java/net/java21/blog/backend/crypto/`
- [X] T019 Origin 검사 필터(별도 브랜치 진행 중, R3·R27): 상태 변경 요청의 `Origin`이 `blog.base-url`이 아니면 403 `ORIGIN_NOT_ALLOWED`, 예외 경로 목록 하나 — `blog-backend/src/main/java/net/java21/blog/backend/security/`
- [X] T020 정기 작업 기반(별도 브랜치 진행 중, R26): `@EnableScheduling`, 스케줄링 스레드 풀, `feedFetchExecutor` — `blog-backend/src/main/java/net/java21/blog/backend/config/`
- [X] T021 front API 클라이언트(별도 브랜치 진행 중): 공통 응답 틀을 벗겨 `result`·`totalCount`를 돌려주고 실패는 `resultCode`·`fieldErrors`를 담은 오류로 던짐, SSR 요청 쿠키 전달 — `blog-front/app/api/`
- [X] T022 front 다국어 기반(별도 브랜치 진행 중, R22): i18next + react-i18next, `blog-front/app/locales/{ko,en,ja,zh-CN}/*.json`, `fallbackLng: ["en","ko"]`, `returnNull: false`, 번역 누락(키 집합 비교·`t()` 키 존재) 테스트 — `blog-front/app/i18n/`, `blog-front/tests/unit/`

### Tests for Foundation ⚠️

> 먼저 쓰고 실패를 확인한다

- [ ] T023 [P] H2 Repository 테스트 메타 애너테이션 `blog-backend/src/test/java/net/java21/blog/backend/support/JpaRepositoryTest.java`: `@DataJpaTest` + `@AutoConfigureTestDatabase(replace = NONE)` + H2 `jdbc:h2:mem:blog;MODE=MySQL;DATABASE_TO_LOWER=TRUE;NON_KEYWORDS=USER,VALUE` + `ddl-auto=create-drop` + `hibernate.generate_statistics=true` + `@Import(QueryDslConfig, JpaAuditingConfig, TimeConfig)` (개발 DB·테스트 MySQL에 붙지 않음)
- [ ] T024 [P] 실행 쿼리 수 확인 도구 `blog-backend/src/test/java/net/java21/blog/backend/support/QueryCounter.java`(Hibernate `Statistics.getPrepareStatementCount()`로 `assertQueryCount(expected, Runnable)`)와 자체 테스트 `blog-backend/src/test/java/net/java21/blog/backend/support/QueryCounterTest.java`(테스트 전용 부모·자식 엔티티로 N+1을 일부러 만들어 검출되는지, fetch join이면 1회인지)
- [ ] T025 [P] `blog-backend/src/test/java/net/java21/blog/backend/common/persistence/BaseTimeEntityTest.java`(`@JpaRepositoryTest`): 저장 시 `createdAt`·`updatedAt`이 고정 `Clock` 값으로 채워지고, 수정 시 `updatedAt`만 바뀐다
- [ ] T026 [P] `blog-backend/src/test/java/net/java21/blog/backend/common/api/PageRequestsTest.java`: `page` 0부터, `size` 기본 20·최대 50(넘으면 50), 허용하지 않은 `sort` 필드는 400 `VALIDATION_FAILED`(api-guidelines 4절)
- [ ] T027 [P] `blog-backend/src/test/java/net/java21/blog/backend/security/JwtProviderTest.java`: HS256 발급·검증, 클레임 userId·role, 만료 30분(`blog.auth.access-ttl`, 고정 `Clock`), 변조·만료 토큰 거부, `jwt-secret`이 32바이트 미만이면 기동 실패
- [ ] T028 [P] `blog-backend/src/test/java/net/java21/blog/backend/security/AuthenticationWebMvcTest.java`: `access_token` 쿠키로 인증(`Authorization` 헤더는 무시), 쿠키 없음·만료면 보호 경로 401 `UNAUTHENTICATED` 공통 틀, 공개 GET(`/api/v1/blogs/**`, `/api/v1/posts/{id}`, `/api/v1/tags/**`, `/api/v1/legal/**`, `/media/**`, `/v3/api-docs`, health)은 비로그인 허용, `@CurrentUser` 주입
- [ ] T029 [P] `blog-backend/src/test/java/net/java21/blog/backend/i18n/MessageKeysConsistencyTest.java`: `messages_ko/en/ja/zh_CN.properties`의 키 집합이 같고 빈 값이 없다(SC-024, R22)
- [ ] T030 [P] `blog-backend/src/test/java/net/java21/blog/backend/db/EntitySchemaValidationTest.java`(`@SpringBootTest` + 테스트 MySQL 스키마, 변수 없으면 건너뜀): 실제 스키마(`schema-mysql.sql`)에 대해 `ddl-auto=validate`로 모든 엔티티 매핑이 통과한다. 이후 스토리에서 엔티티를 더할 때마다 이 테스트가 확인한다
- [ ] T031 [P] `blog-front/tests/unit/server/securityHeaders.test.ts`: HTML 응답에 R27의 CSP(요청별 nonce, `frame-src`는 youtube-nocookie·player.vimeo만, `object-src 'none'`, `frame-ancestors 'none'`), `X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin`, 운영에서만 HSTS
- [ ] T032 [P] `blog-front/tests/unit/api/errorMessage.test.ts`: `resultCode` → `errors.{code}`, `fieldErrors[].code` → `fieldErrors.{code}`(`params` 보간), 모르는 코드는 `errors.UNKNOWN`, 화면에 키나 `resultMessage`가 나오지 않음(FR-154)
- [ ] T033 [P] `blog-front/tests/unit/root.test.tsx`: 공통 레이아웃 상단(로그인 여부에 따라 로그인·가입 / 글쓰기·내 블로그 관리·설정·로그아웃), 하단(`/terms`·`/privacy` 링크, 언어 선택 자리), 없는 경로·404 오류 경계가 HTTP 404 상태로 "찾을 수 없음" 화면
- [ ] T034 [P] `blog-front/tests/unit/auth/session.test.ts`: `getSessionUser(request)`가 `/api/v1/me`를 쿠키와 함께 호출해 회원 또는 null, `requireUser(request)`는 비로그인이면 `/login?next={현재 경로}`로 리다이렉트, `next`는 같은 사이트 상대 경로만 허용

### Implementation for Foundation

- [ ] T035 [P] `JPAQueryFactory` 빈 `blog-backend/src/main/java/net/java21/blog/backend/common/persistence/QueryDslConfig.java`
- [ ] T036 [P] UTC `Clock` 빈 `blog-backend/src/main/java/net/java21/blog/backend/common/time/TimeConfig.java`(토큰 만료·정기 작업 테스트에서 고정 Clock으로 교체)
- [ ] T037 `blog-backend/src/main/java/net/java21/blog/backend/common/persistence/BaseTimeEntity.java`(`@MappedSuperclass`, `created_at`·`updated_at` `Instant`, DATETIME(6) UTC)와 `JpaAuditingConfig.java`(`@EnableJpaAuditing`, `DateTimeProvider`는 `Clock` 사용)
- [ ] T038 JPA 공통 설정을 `blog-backend/src/main/resources/application.yml`에 추가: `spring.jpa.properties.hibernate.default_batch_fetch_size: 100`, `open-in-view: false` 유지, 엔티티 연관관계는 모두 LAZY라는 규칙을 주석으로 명시
- [ ] T039 페이지 요청 해석 `blog-backend/src/main/java/net/java21/blog/backend/common/api/PageRequests.java`(page·size·sort 허용 목록)와 `ApiResponse`의 페이지 응답(`result` 배열 + `totalCount`) 사용 예를 `GlobalExceptionHandler` 검증 오류와 연결
- [ ] T040 jjwt 0.13(`jjwt-api`, `jjwt-impl`, `jjwt-jackson`)을 `blog-backend/pom.xml`에 추가하고 `blog-backend/src/main/java/net/java21/blog/backend/security/AuthProperties.java`(`blog.auth.access-ttl` 30m, `refresh-idle-ttl` 4h, `refresh-absolute-ttl` 7d, `refresh-reuse-grace` 10s, `jwt-secret` 필수, `login-max-failures` 5, `login-lock-duration` 10m), `JwtProvider.java` 구현
- [ ] T041 `blog-backend/src/main/java/net/java21/blog/backend/security/JwtAuthenticationFilter.java`(`access_token` 쿠키 → `SecurityContext`), `CurrentUser.java`(애너테이션)·`AuthUser.java`(record userId, role)·`CurrentUserArgumentResolver.java`, `blog-backend/src/main/java/net/java21/blog/backend/config/SecurityConfig.java`에 필터와 공개 경로 규칙 등록
- [ ] T042 [P] 테스트 지원 `blog-backend/src/test/java/net/java21/blog/backend/support/AuthCookies.java`(테스트용 `access_token` 쿠키 생성)와 `WebMvcTestSupport.java`(보안 설정·`CurrentUserArgumentResolver`·`GlobalExceptionHandler`를 가져오는 `@WebMvcTest` 공통 구성)
- [ ] T043 [P] 메일 문구용 `MessageSource` 설정 `blog-backend/src/main/java/net/java21/blog/backend/i18n/I18nConfig.java`(basename `messages`, 기본 en, 없으면 ko)와 빈 틀 `blog-backend/src/main/resources/messages_ko.properties`, `messages_en.properties`, `messages_ja.properties`, `messages_zh_CN.properties`
- [ ] T044 [P] 보안 헤더 `blog-front/app/server/securityHeaders.ts`를 `blog-front/server.ts`에 연결하고 nonce를 `blog-front/app/entry.server.tsx`의 스크립트에 전달
- [ ] T045 [P] `blog-front/eslint.config.js`에 `react/no-danger` 규칙을 켜고 예외는 `blog-front/app/components/post/PostContent.tsx` 한 파일만 허용(R27)
- [ ] T046 [P] 오류 문구 변환 `blog-front/app/api/errorMessage.ts`와 공통 오류 키(`VALIDATION_FAILED`, `UNAUTHENTICATED`, `FORBIDDEN`, `ORIGIN_NOT_ALLOWED`, `NOT_FOUND`, `INTERNAL_ERROR`, `UNKNOWN`)를 `blog-front/app/locales/{ko,en,ja,zh-CN}/errors.json`에 추가
- [ ] T047 세션 도우미 `blog-front/app/auth/session.server.ts`(`getSessionUser`, `requireUser`, `next` 검증)
- [ ] T048 공통 레이아웃 `blog-front/app/root.tsx`(오류 경계, 404 상태), `blog-front/app/components/layout/Header.tsx`, `blog-front/app/components/layout/Footer.tsx`(약관·개인정보처리방침 링크, 언어 선택 자리), `blog-front/app/components/NotFound.tsx`, 문구 `common` namespace

**Checkpoint**: 기반 완료. `./mvnw verify`, `npm test -- --coverage`가 통과하고 CI가 두 저장소에서 돈다

---

## Phase 3: User Story 1 - 가입하고 내 블로그에 글 쓰기 (Priority: P1) 🎯 MVP

**Goal**: 가입과 동시에 블로그가 생기고(회원당 여러 블로그, 기본 3개), 로그인(회전 리프레시)해서 글을 작성 → 완료 → 발행 설정 → 발행하면 비로그인 방문자가 SSR 블로그 홈·글 상세에서 읽는다. 휴지통·복구, 코드 강조, 동영상 삽입, XSS 살균 포함.

**Independent Test**: 새 계정 가입 → 글 작성 → "완료" → 발행 설정에서 "공개" → "공개 발행" → 로그아웃 상태에서 `/{handle}`과 `/{handle}/{id}`가 JS 없이 제목·본문·`og:title`을 포함하는지 확인. "완료" 전에 떠난 글은 임시저장에만 남는지 확인(quickstart #1~8, #16~18, #30~32).

FR: FR-001~007, FR-010~022, FR-036, FR-070, FR-081, FR-083, FR-084, FR-107, FR-108, FR-140, FR-158, FR-159

### Tests for User Story 1 (backend) ⚠️

- [ ] T049 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/blog/service/HandlePolicyTest.java`: `^[a-z0-9](?:[a-z0-9-]{1,18})[a-z0-9]$`(3~20자), 연속 하이픈 금지 → `HANDLE_INVALID`, contracts/routes.md "예약어" 목록 전체(admin … updates)와 대소문자·공백·특수문자 거부 → `HANDLE_RESERVED`(AS1·2, Edge Cases)
- [ ] T050 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/auth/service/SignupServiceTest.java`: 이메일 소문자 정규화 후 `email_hash`(HMAC)로 중복 판단 → 409 `EMAIL_TAKEN`, handle 중복(삭제된 블로그 포함) → 409 `HANDLE_TAKEN`, BCrypt 저장, `agreeTerms`·`agreePrivacy`·`over14` 중 하나라도 false면 400 `VALIDATION_FAILED`, `termsVersion`이 `blog.legal.terms-version`과 다르면 422 `TERMS_VERSION_OUTDATED`, 회원·첫 블로그를 한 트랜잭션에서 생성, 블로그 제목 기본값 "{닉네임}의 블로그", `terms_version`·`terms_agreed_at` 기록, `locale`(ko·en·ja·zh-CN만)·`timeZone`(IANA, 기본 `Asia/Seoul`) 저장 (FR-001~003, FR-081, AS1·2·14)
- [ ] T051 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/auth/service/LoginServiceTest.java`: 5회 연속 실패 시 10분 잠금 → 423 `ACCOUNT_LOCKED`, 성공 시 `failed_login_count` 0, 없는 이메일·틀린 비밀번호 모두 401 `INVALID_CREDENTIALS`, `WITHDRAWN`·`SUSPENDED` 회원은 로그인 불가, 응답 `blogs`는 삭제하지 않은 블로그를 만든 순 (FR-004, FR-007, FR-009, R12)
- [ ] T052 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/auth/service/RefreshTokenServiceTest.java`: 256비트 무작위 토큰·DB에는 SHA-256만, 사용할 때마다 회전(`used_at`, `replaced_by_id`), 유휴 4시간·family 절대 7일 만료, 이미 사용·폐기된 토큰 재사용 시 family 전체 `revoked_at`, 10초 유예 안의 같은 토큰 재요청은 방금 발급한 토큰 반환, 로그아웃 시 family 폐기 → 이후 401 `REFRESH_INVALID` (FR-005·006, R2, AS4·5, quickstart #8)
- [ ] T053 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/auth/repository/RefreshTokenRepositoryTest.java`(`@JpaRepositoryTest`): `token_hash` 조회, family 일괄 폐기·회원 전체 폐기가 각각 UPDATE 1회(`QueryCounter`)
- [ ] T054 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/auth/controller/AuthControllerTest.java`: `POST /api/v1/auth/signup` 201 + `Location` + 두 쿠키(`HttpOnly; Secure; SameSite=Lax`, 리프레시 `Path=/api/v1/auth`), 비밀번호 8~64자 영문+숫자 아니면 `fieldErrors` `PASSWORD_WEAK`, `GET /auth/handle-availability`(`TAKEN`·`RESERVED`·`INVALID`), `POST /auth/login` 200 `{ userId, nickname, role, blogs }`, `POST /auth/refresh` 200 + 새 쿠키, `POST /auth/logout` 200 `result: null` + 쿠키 삭제, 오류 코드와 상태가 contracts/api.md 표와 같음
- [ ] T055 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/blog/service/BlogServiceTest.java`: 만들기 시 회원 행 잠금 후 ACTIVE 블로그 수 ≥ `COALESCE(users.max_blogs, blog.blogs.default-max-per-member)`면 409 `BLOG_LIMIT_EXCEEDED`, title 1~100자(생략 시 "{닉네임}의 블로그"), 삭제는 같은 잠금 안에서 ACTIVE가 2개 이상일 때만(아니면 409 `LAST_BLOG_CANNOT_BE_DELETED`), 비밀번호 틀리면 400 `CURRENT_PASSWORD_MISMATCH`, 삭제 시 `status=DELETED`·`deleted_at` 설정 + 그 블로그의 DELETED 아닌 글을 `status_before_delete` 보관 후 DELETED, 주인 아님 403 `FORBIDDEN`, 삭제된 블로그·정지·탈퇴 회원의 블로그는 404 `BLOG_NOT_FOUND`, PATCH는 title·description(≤500)·commentEnabled (FR-010~012, FR-158·159, AS17~19)
- [ ] T056 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/blog/repository/BlogRepositoryTest.java`(`@JpaRepositoryTest`): ACTIVE handle 조회, 회원별 ACTIVE 수, 회원 행 `PESSIMISTIC_WRITE` 조회, `/me/blogs`(postCount 포함) DTO projection이 블로그 수와 관계없이 고정 쿼리 수
- [ ] T057 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/blog/BlogCreationConcurrencyTest.java`(`@MySqlRepositoryTest` + 서비스, InnoDB 행 잠금 확인): 블로그 2개인 회원이 서로 다른 handle로 10개 동시 생성 → 성공 1건, 나머지 `BLOG_LIMIT_EXCEEDED`, ACTIVE 3개 초과 없음(quickstart #31, R28)
- [ ] T058 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/blog/controller/BlogControllerTest.java`: `GET /api/v1/me/blogs` `{ items, count, limit }`, `POST /blogs` 201 + `Location`, `DELETE /blogs/{handle}` `{ password }`, `GET /blogs/{handle}` 응답 형식(owner, categories 빈 배열), `PATCH /blogs/{handle}`, 401·403·404·409·422
- [ ] T059 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/content/MarkdownRendererTest.java`: GFM 표·취소선, `<script>`는 태그와 내용 모두 제거, `<img onerror>`·`javascript:` 링크·`style` 속성 제거, 코드 블록은 `<pre><code class="language-java">`만 남고(`language-[a-z0-9+#-]+`) 다른 class 제거, 한 줄 YouTube(`watch?v=`, `youtu.be/`) → `https://www.youtube-nocookie.com/embed/{11자}` iframe, Vimeo → `https://player.vimeo.com/video/{id}`, 그 밖의 iframe 제거, iframe 속성은 `src, width, height, allowfullscreen, loading, title, referrerpolicy`만, `content_text`(태그 제거)·`summary`(앞 150자) 생성 (FR-021, FR-083, FR-140, R8·R25, quickstart #6·18)
- [ ] T060 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/post/service/PostDraftServiceTest.java`: `POST /blogs/{handle}/posts/drafts`가 posts(DRAFT) + post_drafts 생성, 임시저장은 빈 제목 허용·제목 0~200자·본문 최대 200,000자, 발행된 글의 `PUT /posts/{id}/draft`는 발행본을 바꾸지 않음(FR-108), `GET /posts/{id}/draft`는 사본이 없으면 발행본 내용, `DELETE /posts/{id}/draft`는 발행 전 글이면 409 `POST_NOT_PUBLISHED`, 블로그별 최신 임시저장(`drafts/latest`, 없으면 null), 주인 아님 403, 삭제된 블로그 404 (FR-013, FR-016, AS8·9)
- [ ] T061 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/post/service/PostPublishServiceTest.java`: 제목 1~200자 필수, 본문이 비면 422 `POST_CONTENT_EMPTY`, 사본을 HTML 변환·살균해 posts에 반영하고 post_drafts 삭제, `visibility` PUBLIC/PRIVATE, `commentEnabled`, `published_at`은 최초 발행 때만, 수정 발행 시 주소(id) 불변, PUBLISHED → DRAFT 불가 (FR-013, FR-015, FR-070, FR-107·108, AS6·7)
- [ ] T062 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/post/service/PostServiceTest.java`: 상세 조회가 data-model "글 노출 매트릭스"를 따름(주인 외에게 PRIVATE·DRAFT·DELETED·작성자 SUSPENDED/WITHDRAWN·삭제된 블로그 글은 모두 404 `POST_NOT_FOUND`, 주인은 DRAFT·PRIVATE를 볼 수 있으나 DELETED는 상세에서도 404), `contentMarkdown`은 주인에게만, 이전·다음은 같은 블로그의 "목록 노출 가능" 글, 삭제는 `status_before_delete` 보관 후 DELETED·`deleted_at`, 복구는 휴지통 글만(아니면 422 `POST_NOT_IN_TRASH`) 삭제 전 상태로, 남의 글 수정·삭제 403 (FR-017~019, FR-084, AS11~13·15)
- [ ] T063 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/post/repository/PostExposureRepositoryTest.java`(`@JpaRepositoryTest`): 노출 매트릭스의 001 행(PUBLISHED·PUBLIC·ACTIVE / PUBLISHED·PRIVATE / DRAFT / DELETED / 작성자 SUSPENDED / WITHDRAWN) 각각에 대해 "목록 노출 가능"·"본문 노출 가능" 조각이 맞게 거르고, 블로그 글 목록이 `published_at` 내림차순·20개 페이지·`totalCount`를 주며 쿼리 수가 글 수와 무관 (FR-011, FR-018, SC-004)
- [ ] T064 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/post/service/ViewCountServiceTest.java`: 키 postId + (회원 ID 또는 방문자 쿠키 ID), 30분 안 재조회는 증가하지 않음(Caffeine, 고정 Ticker), 볼 수 없는 글은 404 (FR-020)
- [ ] T065 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/post/controller/PostControllerTest.java`: contracts/api.md 글 절의 모든 엔드포인트 상태 코드·응답 형식(PostDetail·PostSummary 필드), 비로그인 쓰기 401, 남의 글 403, 비공개 글 비로그인 404, `POST /posts/{id}/views` 200 `result: null`
- [ ] T066 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/post/job/TrashPurgeJobTest.java`: `deleted_at < now - 30일` 글을 정해진 건수씩 영구 삭제(post_drafts·post_tags는 FK CASCADE), 삭제된 블로그는 30일 뒤 카테고리를 지우고 `blogs` 행은 남기되 title·description을 비움, 처리 건수 로그 (FR-084, FR-159, R26, quickstart #16)
- [ ] T067 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/integration/SignupToPublishFlowTest.java`(`@SpringBootTest`, 핵심 흐름 1개): 가입 → 쿠키로 임시저장 → 발행 → 비로그인 `GET /api/v1/posts/{id}`·`/blogs/{handle}/posts`에 노출, 비공개로 바꾸면 404

### Tests for User Story 1 (front) ⚠️

- [ ] T068 [P] [US1] `blog-front/tests/unit/routes/signup.test.tsx`: 필수 입력·약관/개인정보/만 14세 체크, 약관 링크, handle 사용 가능 여부 표시(`TAKEN`·`RESERVED`·`INVALID`), `action`이 `fieldErrors`·`EMAIL_TAKEN`·`HANDLE_TAKEN`을 해당 입력란 문구로 보여줌, 성공 시 `/{handle}`로 이동, `meta` noindex
- [ ] T069 [P] [US1] `blog-front/tests/unit/routes/login.test.tsx`: `INVALID_CREDENTIALS`·`ACCOUNT_LOCKED` 문구, 성공 시 `next`(같은 사이트 경로만) 또는 `/`로 이동, 로그아웃 `action`
- [ ] T070 [P] [US1] `blog-front/tests/unit/auth/refresh.test.ts`(아래 "구현 전 결정 사항" 1번): 브라우저 API 호출이 401 `UNAUTHENTICATED`면 `POST /api/v1/auth/refresh`를 한 번만(동시 요청은 하나로 합쳐) 부르고 원 요청을 재시도, 리프레시가 401이면 `/login?next=`로 이동 (AS4, quickstart #7)
- [ ] T071 [P] [US1] `blog-front/tests/unit/routes/blogHome.test.tsx`: `/:handle` loader가 `/blogs/{handle}`·`/blogs/{handle}/posts` 호출, 없는 블로그 HTTP 404, `meta` 블로그 제목·소개·`og:image`, 글 목록(최신순 20개)과 페이지 이동, 빈 블로그 안내
- [ ] T072 [P] [US1] `blog-front/tests/unit/routes/postDetail.test.tsx`: `postId`가 숫자가 아니면 404(React Router는 정규식 경로를 지원하지 않으므로 loader에서 검사), `meta` title·description(summary)·`og:title/description/image/url`·canonical, 제목·본문·작성자·작성일, 이전·다음 글, `POST /posts/{id}/views` 호출, 비공개·없는 글 HTTP 404 (FR-019, FR-036, AS10·11)
- [ ] T073 [P] [US1] `blog-front/tests/unit/content/highlight.test.ts`: `language-xxx`가 등록 언어면 `hljs-` span으로 바꾸고, 언어 미지정·미등록은 그대로, 자동 감지 없음 (FR-083, R24, quickstart #17)
- [ ] T074 [P] [US1] `blog-front/tests/unit/routes/write.test.tsx`: "완료"는 API 호출 없이 발행 설정 레이어를 열고, 닫으면 작성 화면으로(글은 임시저장 유지), 버튼 이름은 공개 범위에 따라 "공개 발행"/"비공개 저장", 발행된 글이면 "수정 발행", 1분마다 자동저장·"임시저장" 버튼, 열 때 `drafts/latest`가 있으면 이어 쓸지 묻기, `:handle`의 글이 아니면 404 (FR-013, FR-016, FR-107·108, AS6~9)
- [ ] T075 [P] [US1] `blog-front/tests/unit/routes/settingsBlogs.test.tsx`: 블로그 목록과 "블로그 수 / 한도", 만들기(`BLOG_LIMIT_EXCEEDED`·`HANDLE_TAKEN`·`HANDLE_RESERVED` 문구), 비밀번호 확인 후 삭제(`LAST_BLOG_CANNOT_BE_DELETED`), 각 블로그의 관리·글쓰기 바로가기 (FR-158·159)
- [ ] T076 [P] [US1] `blog-front/tests/unit/routes/writeEntry.test.ts`: `/write`가 블로그 1개면 그 블로그로, 여러 개면 쿠키 `last_blog`가 내 블로그일 때만 그 블로그로, 아니면 `/settings/blogs`로 리다이렉트, 비로그인은 `/login?next=/write`
- [ ] T077 [P] [US1] `blog-front/tests/unit/routes/reservedPaths.test.ts`: `blog-front/app/routes.ts`의 모든 최상위 경로 조각이 contracts/routes.md 예약어 목록(테스트 안 상수)에 들어 있음(새 최상위 경로 추가 시 예약어 누락 방지, FR-002)
- [ ] T078 [P] [US1] E2E `blog-front/tests/e2e/us1-signup-publish.spec.ts`: Independent Test 전체, `javaScriptEnabled: false` 컨텍스트로 글 상세 HTML에 제목·본문·`og:title` 포함(SC-005), 비공개 글 다른 계정·비로그인 404, `<script>` 본문 무력화, java 코드 블록 `hljs-` 포함, YouTube·Vimeo만 iframe (quickstart #1~6, #17·18)
- [ ] T079 [P] [US1] E2E `blog-front/tests/e2e/us1-multi-blog.spec.ts`: 블로그 3개까지 만들기, 네 번째 거부, `/marco-dev/write`에서 발행한 글이 `/marco` 목록에 없음, 블로그 삭제 후 404·주소 재사용 `HANDLE_TAKEN`, 마지막 블로그 삭제 거부 (quickstart #30·32)

### Implementation for User Story 1 (backend)

- [ ] T080 [US1] `blog-backend/pom.xml`에 commonmark-java(`commonmark`, `commonmark-ext-gfm-tables`, `commonmark-ext-gfm-strikethrough`), OWASP Java HTML Sanitizer, Caffeine 추가
- [ ] T081 [US1] `blog-backend/src/main/java/net/java21/blog/backend/common/error/ErrorCode.java`에 `INVALID_CREDENTIALS`(401), `REFRESH_INVALID`(401), `ACCOUNT_LOCKED`(423), `EMAIL_TAKEN`·`HANDLE_TAKEN`·`BLOG_LIMIT_EXCEEDED`·`LAST_BLOG_CANNOT_BE_DELETED`·`POST_NOT_PUBLISHED`(409), `HANDLE_RESERVED`·`HANDLE_INVALID`·`TERMS_VERSION_OUTDATED`·`POST_CONTENT_EMPTY`·`POST_NOT_IN_TRASH`(422), `CURRENT_PASSWORD_MISMATCH`(400), `BLOG_NOT_FOUND`·`POST_NOT_FOUND`·`DRAFT_NOT_FOUND`(404)
- [ ] T082 [P] [US1] 회원 엔티티 `blog-backend/src/main/java/net/java21/blog/backend/user/domain/User.java`(`BaseTimeEntity` 상속): `email_enc` VARBINARY(512) 암호화 컨버터, `email_hash` CHAR(64) UNIQUE, `password_hash` VARCHAR(100) BCrypt, `nickname` VARCHAR(30) 필수, `bio` VARCHAR(300), `profile_media_id` BIGINT NULL, `role` VARCHAR(15) USER/ADMIN/SUPER_ADMIN, `status` VARCHAR(10) ACTIVE/SUSPENDED/WITHDRAWN, `locale` VARCHAR(10) ko/en/ja/zh-CN NULL=미설정, `time_zone` VARCHAR(40) 기본 `Asia/Seoul`, `failed_login_count` INT 기본 0, `locked_until`, `withdrawn_at`, `terms_version` VARCHAR(20), `terms_agreed_at`, `max_blogs` INT NULL(0 이상), 열거형 `UserRole.java`·`UserStatus.java`
- [ ] T083 [P] [US1] `blog-backend/src/main/java/net/java21/blog/backend/user/repository/UserRepository.java`(`findByEmailHash`, `findByIdForUpdate` `@Lock(PESSIMISTIC_WRITE)`)
- [ ] T084 [P] [US1] 리프레시 토큰 엔티티 `blog-backend/src/main/java/net/java21/blog/backend/auth/domain/RefreshToken.java`(`family_id` CHAR(36), `token_hash` CHAR(64) UNIQUE, `expires_at` 발급+4h, `family_expires_at` 최초+7d, `used_at`, `replaced_by_id`, `revoked_at`, user LAZY)와 `blog-backend/src/main/java/net/java21/blog/backend/auth/repository/RefreshTokenRepository.java`
- [ ] T085 [P] [US1] 블로그 엔티티 `blog-backend/src/main/java/net/java21/blog/backend/blog/domain/Blog.java`: `user_id` FK LAZY(인덱스, 회원당 여러 개), `handle` VARCHAR(20) UNIQUE(삭제 포함)·변경 불가, `title` VARCHAR(100) 기본 "{닉네임}의 블로그", `description` VARCHAR(500), `cover_media_id` NULL, `comment_enabled` 기본 true, `status` VARCHAR(10) ACTIVE/DELETED, `deleted_at`, `BlogStatus.java`
- [ ] T086 [US1] `blog-backend/src/main/java/net/java21/blog/backend/blog/repository/BlogRepository.java`와 QueryDSL `BlogQueryRepository.java`(내 블로그 목록 + postCount DTO projection)
- [ ] T087 [P] [US1] 예약어 상수 `blog-backend/src/main/java/net/java21/blog/backend/blog/ReservedHandles.java`(contracts/routes.md 예약어 목록 그대로, 코드 상수 한 곳)와 `blog-backend/src/main/java/net/java21/blog/backend/blog/service/HandlePolicy.java`
- [ ] T088 [P] [US1] `blog-backend/src/main/java/net/java21/blog/backend/blog/BlogsProperties.java`(`blog.blogs.default-max-per-member` 기본 3)와 `blog-backend/src/main/java/net/java21/blog/backend/legal/LegalProperties.java`(`blog.legal.terms-version` 필수)
- [ ] T089 [US1] `blog-backend/src/main/java/net/java21/blog/backend/blog/service/BlogService.java`(만들기·삭제는 회원 행 잠금 안에서, 조회·수정) + 소유 확인 `BlogAccess.java`(`requireOwnedActiveBlog(handle, userId)`, `requireVisibleBlog(handle)` — 주인 ACTIVE·블로그 ACTIVE가 아니면 `BLOG_NOT_FOUND`)
- [ ] T090 [US1] `blog-backend/src/main/java/net/java21/blog/backend/blog/controller/BlogController.java`(`/api/v1/me/blogs`, `/blogs`, `/blogs/{handle}`)와 DTO `blog-backend/src/main/java/net/java21/blog/backend/blog/dto/`(`BlogResponse`, `MyBlogsResponse`, `CreateBlogRequest`, `UpdateBlogRequest`, `DeleteBlogRequest`)
- [ ] T091 [US1] 비밀번호 규칙 `blog-backend/src/main/java/net/java21/blog/backend/auth/validation/PasswordPolicy.java`(8~64자, 영문+숫자 → `PASSWORD_WEAK`)와 `PasswordEncoder`(BCrypt) 빈
- [ ] T092 [US1] `blog-backend/src/main/java/net/java21/blog/backend/auth/service/SignupService.java`, `LoginService.java`(잠금 포함), `RefreshTokenService.java`(회전·재사용 감지·유예)
- [ ] T093 [US1] 인증 쿠키 작성기 `blog-backend/src/main/java/net/java21/blog/backend/auth/web/AuthCookieWriter.java`(`access_token` Path=/, `refresh_token` Path=/, HttpOnly·Secure·SameSite=Lax, 삭제)와 `blog-backend/src/main/java/net/java21/blog/backend/auth/controller/AuthController.java`, DTO `blog-backend/src/main/java/net/java21/blog/backend/auth/dto/`
- [ ] T094 [US1] `GET /api/v1/me`(회원 기본 정보 + 내 블로그, `unseenReleaseNote`는 003 전까지 항상 null) `blog-backend/src/main/java/net/java21/blog/backend/user/controller/MeController.java`, `blog-backend/src/main/java/net/java21/blog/backend/user/service/MeQueryService.java`
- [ ] T095 [P] [US1] Markdown 변환 `blog-backend/src/main/java/net/java21/blog/backend/content/MarkdownRenderer.java`, 살균 정책 `HtmlSanitizerPolicy.java`(R8 허용 태그, `language-` class, R25 iframe 허용 목록), 동영상 줄 변환 `VideoEmbedTransformer.java`, 결과 record `RenderedContent.java`(html, text, summary 150자)
- [ ] T096 [P] [US1] 글 엔티티 `blog-backend/src/main/java/net/java21/blog/backend/post/domain/Post.java`: `blog_id` FK LAZY, `category_id` NULL=미분류(엔티티 연관은 US2), `title` VARCHAR(200) 필수, `content_md`·`content_html`·`content_text` MEDIUMTEXT, `summary` VARCHAR(300), `thumbnail_url` VARCHAR(500), `visibility` VARCHAR(10) PUBLIC/PRIVATE, `status` VARCHAR(10) DRAFT/PUBLISHED/DELETED, `status_before_delete`, `comment_enabled` 기본 true, `view_count`·`comment_count` INT, `published_at`, `deleted_at`, 열거형 `PostStatus.java`·`PostVisibility.java`(004·005 값은 그때 추가)
- [ ] T097 [P] [US1] 작성 중 사본 엔티티 `blog-backend/src/main/java/net/java21/blog/backend/post/domain/PostDraft.java`(`post_id` PK·FK `@MapsId`, `title` VARCHAR(200), `content_md`, `category_id` FK 없음, `tags_json` JSON ↔ `List<String>` 컨버터, `saved_at`)와 `PostRepository.java`, `PostDraftRepository.java`
- [ ] T098 [US1] 노출 조건 조각(한 곳) `blog-backend/src/main/java/net/java21/blog/backend/post/repository/PostExposure.java`: QueryDSL `listable()` = `status=PUBLISHED AND visibility IN (PUBLIC) AND 작성자 status=ACTIVE AND 블로그 status=ACTIVE`, `bodyVisible()` = `listable() AND visibility=PUBLIC`(004가 PROTECTED를 더할 자리 주석) — 모든 목록 쿼리는 이 조각만 사용
- [ ] T099 [US1] `blog-backend/src/main/java/net/java21/blog/backend/post/repository/PostQueryRepository.java`: 블로그 글 목록(PostSummary DTO projection, 페이지), 이전·다음 글, 블로그별 최신 임시저장
- [ ] T100 [US1] `blog-backend/src/main/java/net/java21/blog/backend/post/service/PostDraftService.java`, `PostPublishService.java`, `PostService.java`(상세·삭제·복구, 노출 매트릭스)
- [ ] T101 [P] [US1] `blog-backend/src/main/java/net/java21/blog/backend/post/service/ViewCountService.java`(Caffeine 30분, `view_count` 원자적 증가 UPDATE)
- [ ] T102 [US1] `blog-backend/src/main/java/net/java21/blog/backend/post/controller/PostController.java`(`/blogs/{handle}/posts`, `/blogs/{handle}/posts/drafts`, `/blogs/{handle}/posts/drafts/latest`, `/posts/{id}`, `/posts/{id}/draft`, `/posts/{id}/publish`, `/posts/{id}/restore`, `/posts/{id}/views`)와 DTO `blog-backend/src/main/java/net/java21/blog/backend/post/dto/`(`DraftWriteRequest`, `PublishSettingsRequest`, `PostDetailResponse`, `PostSummaryResponse`, `SavedDraftResponse`)
- [ ] T103 [US1] 휴지통 비우기 작업 `blog-backend/src/main/java/net/java21/blog/backend/post/job/TrashPurgeJob.java`(`blog.jobs.trash-purge-cron` 기본 `0 30 3 * * *`, 건수 단위 처리)와 `blog-backend/src/main/java/net/java21/blog/backend/common/job/JobsProperties.java`
- [ ] T104 [US1] `blog-backend/src/main/resources/application.yml`에 `blog.auth.*`, `blog.blogs.*`, `blog.legal.*`, `blog.jobs.trash-purge-cron` 기본값(contracts/api.md 프로퍼티 표), `blog-backend/.env.example`에 `BLOG_AUTH_JWT_SECRET` 자리표시자

### Implementation for User Story 1 (front)

- [ ] T105 [US1] `blog-front/package.json`에 `@milkdown/crepe` 7.x, `highlight.js` 추가
- [ ] T106 [US1] 라우트 정의 `blog-front/app/routes.ts`: 고정 경로를 먼저, `/:handle/*` 계열을 마지막에(contracts/routes.md 001 화면 표)
- [ ] T107 [P] [US1] 브라우저용 API 호출과 자동 리프레시 `blog-front/app/api/client.ts`, `blog-front/app/auth/refresh.client.ts`
- [ ] T108 [P] [US1] 임시 메인 `blog-front/app/routes/home.tsx`(`/`, 서비스 소개·로그인·가입 링크, 003에서 포털로 교체)
- [ ] T109 [P] [US1] 회원가입 `blog-front/app/routes/signup.tsx`(약관 버전은 `/api/v1/legal/terms`에서 받아 `termsVersion`으로 전송, 현재 화면 언어·브라우저 시간대 전송), 문구 `auth` namespace
- [ ] T110 [P] [US1] 로그인·로그아웃 `blog-front/app/routes/login.tsx`, `blog-front/app/routes/logout.ts`(`action`만)
- [ ] T111 [P] [US1] SEO 도우미 `blog-front/app/seo/meta.ts`(title, description, Open Graph, canonical, noindex)
- [ ] T112 [P] [US1] 본문 출력 `blog-front/app/components/post/PostContent.tsx`(`dangerouslySetInnerHTML`을 쓰는 유일한 곳)와 서버 전용 강조 `blog-front/app/content/highlight.server.ts`(java, kotlin, javascript, typescript, json, xml/html, css, sql, bash, yaml, python, go, diff 등록, 테마 CSS만 브라우저로)
- [ ] T113 [P] [US1] 글 목록 `blog-front/app/components/post/PostList.tsx`, `blog-front/app/components/Pagination.tsx`
- [ ] T114 [US1] 블로그 홈 `blog-front/app/routes/blog-home.tsx`(`/:handle`, SSR loader·meta)
- [ ] T115 [US1] 글 상세 `blog-front/app/routes/post-detail.tsx`(`/:handle/:postId`, 숫자 검사, SSR loader·meta, 조회수 기록, 이전·다음)
- [ ] T116 [P] [US1] 에디터 래퍼 `blog-front/app/components/Editor/Editor.tsx`(인터페이스 `value`, `onChange`, `onUploadImage`; Milkdown Crepe 클라이언트 지연 로딩, top-bar·AI 기능 끔, SSR 제외)
- [ ] T117 [P] [US1] 발행 설정 레이어 `blog-front/app/components/post/PublishSettingsDialog.tsx`(공개 범위, 발행 시각=현재, 댓글 허용, 버튼 이름 규칙; 카테고리·태그는 US2, 대표 이미지는 US4에서 채움)
- [ ] T118 [US1] 글쓰기 `blog-front/app/routes/write.tsx`(`/:handle/write`, `/:handle/write/:postId`, 1분 자동저장, 이어 쓰기 확인, `last_blog` 쿠키 저장), 진입 리다이렉트 `blog-front/app/routes/write-entry.ts`(`/write`), 쿠키 도우미 `blog-front/app/auth/lastBlog.server.ts`, 문구 `editor`·`post` namespace
- [ ] T119 [US1] 계정 설정 레이아웃 `blog-front/app/routes/settings.tsx`(로그인 필요, `/settings` → `/settings/profile`)와 내 블로그 `blog-front/app/routes/settings.blogs.tsx`, 문구 `settings` namespace
- [ ] T120 [US1] US1에서 쓰는 모든 오류 코드의 `errors.*`·`fieldErrors.*` 문구를 `blog-front/app/locales/{ko,en,ja,zh-CN}/errors.json`에 추가

**Checkpoint**: US1 Independent Test(E2E)가 통과하고 MVP로 시연 가능

---

## Phase 4: User Story 1 (계속) - 계정 설정 (Priority: P1)

**Goal**: 비밀번호 변경·재설정(메일), 로그인 기록, 프로필 수정, 탈퇴, 개인정보 파기 작업, 약관·개인정보처리방침 페이지 (plan 1a 단계)

**Independent Test**: 비밀번호 재설정 메일 링크로 새 비밀번호 설정 → 같은 링크 재사용 거부, 비밀번호 변경 후 다른 기기 로그인 끊김, 로그인 기록에 실패·성공과 가린 IP, DB에 평문 이메일·IP 없음(quickstart #19~22)

FR: FR-008, FR-009, FR-082, FR-133~139

### Tests for User Story 1 계정 설정 ⚠️

- [ ] T121 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/user/service/AccountServiceTest.java`: 프로필 수정(nickname 1~30자, bio ≤300자), `locale`은 ko·en·ja·zh-CN만·`timeZone`은 IANA ID만(아니면 `VALIDATION_FAILED`), 탈퇴는 비밀번호 확인 후 `status=WITHDRAWN`·`withdrawn_at`, 모든 블로그의 모든 글 `visibility=PRIVATE`(이전 값 보관 안 함), 모든 family 폐기, 되돌리기 없음 (FR-008·009)
- [ ] T122 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/user/service/PasswordChangeServiceTest.java`: 현재 비밀번호 틀리면 400 `CURRENT_PASSWORD_MISMATCH`, 새 비밀번호 규칙, 성공 시 현재 기기 family를 뺀 모든 family 폐기 (FR-082, quickstart #20 — 아래 "구현 전 결정 사항" 2번)
- [ ] T123 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/auth/service/PasswordResetServiceTest.java`: 가입되지 않은 이메일도 같은 202, 토큰은 SHA-256만 저장·30분 만료·한 번만 사용(아니면 400 `PASSWORD_RESET_TOKEN_INVALID`), 재설정 시 모든 family 폐기, 메일은 커밋 후 비동기로 회원 `locale` 언어 (FR-133, quickstart #19)
- [ ] T124 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/user/service/LoginHistoryServiceTest.java`: 로그인 성공·실패마다 기록(없는 이메일은 user_id NULL), IP는 암호화 컬럼 `ip_enc`, user_agent 300자 자르기, 조회 시 IP 일부 가림(예: `211.234.*.*`) (FR-139, quickstart #21)
- [ ] T125 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/user/repository/LoginHistoryRepositoryTest.java`(`@JpaRepositoryTest`): 회원별 최신순 페이지, 90일 지난 기록 일괄 삭제
- [ ] T126 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/crypto/PersonalDataAtRestTest.java`(`@JpaRepositoryTest` + `JdbcTemplate`): 가입·로그인 기록 저장 후 `users.email_enc`·`login_history.ip_enc` 원시 값에 평문이 없고 `email_hash`로 조회됨 (SC-022, quickstart #22)
- [ ] T127 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/user/job/PrivacyPurgeJobTest.java`: `withdrawn_at < now - 30일` 회원의 개인정보 파기(`email_enc`·`email_hash`는 NOT NULL·UNIQUE를 지키는 익명 값, nickname 익명화, bio·profile_media_id NULL), 90일 지난 로그인 기록 삭제, 만료된 재설정 토큰·리프레시 토큰 삭제, 건수 로그 (FR-138·139, R26)
- [ ] T128 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/mail/MailServiceTest.java`: 회원 `locale`의 `MessageSource` 문구로 제목·본문 생성(없으면 en, 그다음 ko), 재설정 링크는 `blog.base-url` + `/password-reset/confirm?token=`, 발송 실패는 로그만
- [ ] T129 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/legal/controller/LegalControllerTest.java`: `GET /api/v1/legal/terms?lang=`·`/legal/privacy?lang=`가 `{ version, lang, authoritativeLang: "ko", effectiveAt, contentHtml }`, 언어판이 없으면 en, en도 없으면 ko (FR-137, FR-155)
- [ ] T130 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/user/controller/MeControllerTest.java`: `PATCH /api/v1/me`, `DELETE /me` `{ password }`, `PUT /me/password`, `GET /me/login-history?page=` 형식·401·검증 오류
- [ ] T131 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/auth/controller/PasswordResetControllerTest.java`: `POST /auth/password-reset/request` 202(항상 같은 응답), `/confirm` 200 `result: null`·400
- [ ] T132 [P] [US1] `blog-front/tests/unit/routes/passwordReset.test.tsx`: 요청 화면은 가입 여부와 관계없이 같은 안내, 확인 화면 `token` 처리와 `PASSWORD_RESET_TOKEN_INVALID` 문구
- [ ] T133 [P] [US1] `blog-front/tests/unit/routes/settingsAccount.test.tsx`: `/settings/profile`(닉네임·소개 저장, 탈퇴 확인 대화상자·비밀번호), `/settings/password`(`CURRENT_PASSWORD_MISMATCH`), `/settings/login-history`(시각·성공 여부·가린 IP·기기, 페이지), 모두 noindex·로그인 필요
- [ ] T134 [P] [US1] `blog-front/tests/unit/routes/legal.test.tsx`: `/terms`·`/privacy` SSR, 화면 언어판 + "한국어판 우선" 안내, `meta` 제목
- [ ] T135 [P] [US1] E2E `blog-front/tests/e2e/us1-account.spec.ts`: 재설정 메일(Mailpit) → 새 비밀번호 → 링크 재사용 거부, 비밀번호 변경, 로그인 기록 (quickstart #19~21)

### Implementation for User Story 1 계정 설정

- [ ] T136 [US1] `blog-backend/pom.xml`에 `spring-boot-starter-mail` 추가, `blog-backend/src/main/java/net/java21/blog/backend/common/error/ErrorCode.java`에 `PASSWORD_RESET_TOKEN_INVALID`(400) 추가
- [ ] T137 [P] [US1] 로그인 기록 엔티티 `blog-backend/src/main/java/net/java21/blog/backend/user/domain/LoginHistory.java`(`user_id` NULL 가능, `success`, `ip_enc` VARBINARY(128) 암호화, `user_agent` VARCHAR(300), `created_at`)와 `blog-backend/src/main/java/net/java21/blog/backend/user/repository/LoginHistoryRepository.java`
- [ ] T138 [P] [US1] 재설정 토큰 엔티티 `blog-backend/src/main/java/net/java21/blog/backend/auth/domain/PasswordResetToken.java`(`token_hash` CHAR(64) UNIQUE, `expires_at` 발급+30분, `used_at`)와 `blog-backend/src/main/java/net/java21/blog/backend/auth/repository/PasswordResetTokenRepository.java`
- [ ] T139 [US1] `blog-backend/src/main/java/net/java21/blog/backend/user/service/LoginHistoryService.java`(기록·가린 IP 조회)를 `LoginService`에 연결
- [ ] T140 [P] [US1] 메일 `blog-backend/src/main/java/net/java21/blog/backend/mail/MailProperties.java`(`blog.mail.host/port/username/password/from/starttls`), `MailConfig.java`(`JavaMailSenderImpl`), `MailService.java`(`@TransactionalEventListener(AFTER_COMMIT)` + `@Async`), 문구 키 `mail.passwordReset.subject`·`mail.passwordReset.body`를 `messages_{ko,en,ja,zh_CN}.properties`에 4개 언어로
- [ ] T141 [US1] `blog-backend/src/main/java/net/java21/blog/backend/auth/service/PasswordResetService.java`와 `blog-backend/src/main/java/net/java21/blog/backend/auth/controller/PasswordResetController.java`
- [ ] T142 [US1] `blog-backend/src/main/java/net/java21/blog/backend/user/service/AccountService.java`(프로필·탈퇴), `PasswordChangeService.java`, `MeController`에 `PATCH /me`·`DELETE /me`·`PUT /me/password`·`GET /me/login-history` 추가, DTO `blog-backend/src/main/java/net/java21/blog/backend/user/dto/`
- [ ] T143 [P] [US1] 약관 `blog-backend/src/main/java/net/java21/blog/backend/legal/LegalService.java`·`LegalController.java`(본문은 US1의 `MarkdownRenderer`로 변환), 본문 리소스 `blog-backend/src/main/resources/legal/terms_{ko,en,ja,zh-CN}.md`, `privacy_{ko,en,ja,zh-CN}.md`(문안은 운영자가 제공, 한국어판 기준)
- [ ] T144 [US1] 개인정보 파기 작업 `blog-backend/src/main/java/net/java21/blog/backend/user/job/PrivacyPurgeJob.java`(`blog.jobs.privacy-purge-cron` 기본 `0 0 4 * * *`)와 `blog-backend/src/main/java/net/java21/blog/backend/user/PrivacyProperties.java`(`blog.privacy.withdrawn-retention` 30d, `login-history-retention` 90d)
- [ ] T145 [P] [US1] `blog-front/app/routes/password-reset.tsx`, `blog-front/app/routes/password-reset.confirm.tsx`
- [ ] T146 [P] [US1] `blog-front/app/routes/settings.profile.tsx`(탈퇴 포함), `blog-front/app/routes/settings.password.tsx`, `blog-front/app/routes/settings.login-history.tsx`
- [ ] T147 [P] [US1] `blog-front/app/routes/terms.tsx`, `blog-front/app/routes/privacy.tsx`, 문구 `legal` namespace

**Checkpoint**: 계정 설정 E2E 통과, SC-022 확인

---

## Phase 5: User Story 1 (계속) - 블로그 관리 뼈대 (006 FR-096~101 중 001 범위) (Priority: P1)

**Goal**: `/:handle/manage` 레이아웃·블로그 전환, `/manage` 리다이렉트, 대시보드(글 수치), 글 관리(필터·검색·일괄 작업·휴지통), 블로그 설정, noindex. 관리자 API 공통 규칙과 회원별 블로그 한도(006 FR-160, quickstart #33)

**Independent Test**: `/manage` → `/marco/manage` 대시보드, `/marco/manage/posts`에서 글 3편을 골라 비공개로 일괄 변경, 휴지통에서 복구(quickstart #16·29·33)

### Tests for 블로그 관리 뼈대 ⚠️

- [ ] T148 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/manage/repository/ManagePostQueryRepositoryTest.java`(`@JpaRepositoryTest`): `status`(생략 시 휴지통 제외, `DELETED`면 휴지통과 `purgeAt` = `deleted_at` + 30일)·`visibility`·`category`·제목 `q` 동적 조건, 최신순 페이지, 쿼리 수 고정
- [ ] T149 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/manage/service/ManagePostServiceTest.java`: `POST /blogs/{handle}/manage/posts/bulk` `CHANGE_VISIBILITY`·`DELETE`, 최대 100개, 하나라도 그 블로그 글이 아니면 403, 결과 `{ updated: n }` (006 FR-101)
- [ ] T150 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/manage/service/ManageDashboardServiceTest.java`: `draftCount`, `recentPosts` 5건(댓글 수치는 US3에서)
- [ ] T151 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/manage/controller/ManageControllerTest.java`: 주인만, 주인 아님 403·삭제된 블로그 404, 응답 형식
- [ ] T152 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/admin/AdminAccessWebMvcTest.java`: `/api/v1/admin/**`는 요청마다 DB의 `role`(ADMIN·SUPER_ADMIN)·`status`(ACTIVE)를 다시 읽고, 비로그인·일반 회원·권한 회수된 회원은 404 `NOT_FOUND`(JWT role 클레임 무시)
- [ ] T153 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/admin/user/AdminUserServiceTest.java`: `PATCH /admin/users/{id}/blog-limit` `{ maxBlogs }`(0 이상 정수 또는 null), 응답 `{ userId, blogCount, maxBlogs, effectiveLimit }`, 블로그 수보다 낮춰도 허용, `admin_audit_logs`에 변경 전후 값(개인정보 평문 없이) 기록 (006 FR-106·160, quickstart #33)
- [ ] T154 [P] [US1] `blog-backend/src/test/java/net/java21/blog/backend/admin/SuperAdminBootstrapTest.java`: 기동 시 SUPER_ADMIN이 없고 `blog.admin.bootstrap-super-admin-email`이 있으면 그 이메일(해시로 조회) 회원을 SUPER_ADMIN으로, 이미 있으면 아무것도 안 함 (006 FR-105)
- [ ] T155 [P] [US1] `blog-front/tests/unit/routes/manage.test.tsx`: `/:handle/manage/**` 레이아웃(001 메뉴만: 대시보드·글 관리·카테고리·댓글·블로그 설정, 블로그 전환, noindex), 남의 블로그·삭제된 블로그 404, `last_blog` 쿠키 저장, `/manage` 리다이렉트 규칙, 대시보드(방문자 수 숨김), 글 관리 필터 → 쿼리 문자열, 일괄 작업, 휴지통 복구
- [ ] T156 [P] [US1] E2E `blog-front/tests/e2e/us1-manage.spec.ts`: quickstart #16·29

### Implementation for 블로그 관리 뼈대

- [ ] T157 [US1] `blog-backend/src/main/java/net/java21/blog/backend/manage/repository/ManagePostQueryRepository.java`(QueryDSL, `PostSummary` + `hasDraft`·`deletedAt`·`purgeAt`)
- [ ] T158 [US1] `blog-backend/src/main/java/net/java21/blog/backend/manage/service/ManagePostService.java`, `ManageDashboardService.java`, `blog-backend/src/main/java/net/java21/blog/backend/manage/controller/ManageController.java`(`/blogs/{handle}/manage/dashboard`, `/manage/posts`, `/manage/posts/bulk`), DTO `blog-backend/src/main/java/net/java21/blog/backend/manage/dto/`
- [ ] T159 [P] [US1] 관리자 접근 규칙 `blog-backend/src/main/java/net/java21/blog/backend/admin/AdminAccessFilter.java`(DB role 재확인, 아니면 404 공통 틀)를 `SecurityConfig`에 등록
- [ ] T160 [P] [US1] 작업 기록 `blog-backend/src/main/java/net/java21/blog/backend/admin/audit/AdminAuditLog.java`(엔티티, `admin_audit_logs`, 수정·삭제 메서드 없음), `AdminAuditLogRepository.java`, `AdminAuditService.java`(요청 IP는 암호화 컬럼)
- [ ] T161 [US1] `blog-backend/src/main/java/net/java21/blog/backend/admin/user/AdminUserController.java`·`AdminUserService.java`(blog-limit), `blog-backend/src/main/java/net/java21/blog/backend/admin/AdminProperties.java`·`SuperAdminBootstrap.java`(`ApplicationRunner`)
- [ ] T162 [P] [US1] `blog-front/app/routes/manage-entry.ts`(`/manage`), `blog-front/app/routes/manage/layout.tsx`(메뉴·블로그 전환·noindex·`last_blog`), `blog-front/app/routes/manage/dashboard.tsx`
- [ ] T163 [P] [US1] `blog-front/app/routes/manage/posts.tsx`(필터·검색·일괄 작업·휴지통·복구, 임시저장 글 다시 열기), `blog-front/app/routes/manage/settings.tsx`(제목·소개·댓글 허용; 대표 이미지는 US4), 문구 `manage` namespace

**Checkpoint**: US1 전체(가입·글쓰기·계정 설정·관리 뼈대) 완료

---

## Phase 6: User Story 2 - 카테고리와 태그로 글 정리하기 (Priority: P2)

**Goal**: 블로그별 2단계 카테고리 관리, 글 분류, 서비스 공통 태그(글당 10개), 카테고리·태그별 목록

**Independent Test**: 카테고리 2개(상위·하위) 생성 → 글 3편을 서로 다른 카테고리·태그로 발행 → 카테고리·태그별 목록에 해당 공개 글만 최신순으로 나오는지, 상위 카테고리 삭제 시 글이 미분류로 가는지, 11번째 태그 거부(quickstart #9·10)

FR: FR-023~026

### Tests for User Story 2 ⚠️

- [ ] T164 [P] [US2] `blog-backend/src/test/java/net/java21/blog/backend/category/service/CategoryServiceTest.java`: name 1~50자, 같은 부모 아래 이름 중복 409 `CATEGORY_NAME_TAKEN`(최상위는 `parent_id` NULL이라 DB UNIQUE가 막지 못하므로 서비스에서 확인), 부모의 부모가 있으면 422 `CATEGORY_DEPTH_EXCEEDED`, 이름 변경, 순서 변경(`PUT .../order`의 모든 id가 이 블로그 것이고 깊이 규칙 유지), 삭제 시 소속 글과 하위 카테고리 글을 `category_id` NULL(미분류)로 옮기고 하위 카테고리도 삭제, 다른 블로그 카테고리 404 `CATEGORY_NOT_FOUND`, 주인만 (FR-023·024, AS1·2)
- [ ] T165 [P] [US2] `blog-backend/src/test/java/net/java21/blog/backend/category/repository/CategoryRepositoryTest.java`(`@JpaRepositoryTest`): `CategoryNode` 트리 + postCount("목록 노출 가능" 글 기준)를 카테고리 수와 무관한 쿼리 수로
- [ ] T166 [P] [US2] `blog-backend/src/test/java/net/java21/blog/backend/tag/service/TagServiceTest.java`: 정규화(앞뒤 공백 제거 + 소문자, 단어 사이 공백 유지: " Spring Boot " → "spring boot"), 각 1~30자, 글당 최대 10개(넘으면 422 `TAG_LIMIT_EXCEEDED`), 중복 제거, 서비스 공통 태그 get-or-create(UNIQUE 경합 시 다시 조회) (FR-025, AS3)
- [ ] T167 [P] [US2] `blog-backend/src/test/java/net/java21/blog/backend/tag/repository/TagRepositoryTest.java`(`@JpaRepositoryTest`): 블로그 태그 목록 `[{ name, postCount }]`, 서비스 전체 태그별 글(PostSummary + blogHandle, "목록 노출 가능"만), 목록의 `tags` 필드를 글 수와 무관한 쿼리 수로 채움(N+1 없음)
- [ ] T168 [P] [US2] `blog-backend/src/test/java/net/java21/blog/backend/post/repository/PostCategoryTagFilterRepositoryTest.java`(`@JpaRepositoryTest`): `GET /blogs/{handle}/posts?category=&tag=` 필터가 노출 조각과 함께 동작, 최신순 (FR-026, AS4)
- [ ] T169 [P] [US2] `blog-backend/src/test/java/net/java21/blog/backend/post/service/PostCategoryTagServiceTest.java`: 임시저장은 `categoryId`·`tags`를 사본(`category_id`, `tags_json`)에 저장, 발행 시 `categoryId`가 같은 블로그 카테고리가 아니면 404 `CATEGORY_NOT_FOUND`, `post_tags` 교체, PostDetail·PostSummary의 `category`·`tags`, 일괄 작업 `MOVE_CATEGORY`
- [ ] T170 [P] [US2] `blog-backend/src/test/java/net/java21/blog/backend/category/controller/CategoryControllerTest.java`와 `blog-backend/src/test/java/net/java21/blog/backend/tag/controller/TagControllerTest.java`: 엔드포인트 상태 코드·형식, 주인 아님 403
- [ ] T171 [P] [US2] `blog-front/tests/unit/components/TagInput.test.tsx`(정규화 표시, 11번째 추가 안 됨)와 `blog-front/tests/unit/components/CategoryTree.test.tsx`(계층 표시, "미분류")
- [ ] T172 [P] [US2] `blog-front/tests/unit/routes/categoryTagLists.test.tsx`: `/:handle/category/:categoryId`(meta "카테고리명 - 블로그 제목"), `/:handle/tags/:name`, `/tags/:name`(meta "#태그 - 서비스명") SSR, 없는 카테고리 404
- [ ] T173 [P] [US2] `blog-front/tests/unit/routes/manageCategories.test.tsx`: 만들기·이름 변경·순서 변경·삭제 확인, 오류 문구
- [ ] T174 [P] [US2] E2E `blog-front/tests/e2e/us2-category-tag.spec.ts`: Independent Test 전체

### Implementation for User Story 2

- [ ] T175 [US2] `blog-backend/src/main/java/net/java21/blog/backend/common/error/ErrorCode.java`에 `CATEGORY_NOT_FOUND`(404), `CATEGORY_NAME_TAKEN`(409), `CATEGORY_DEPTH_EXCEEDED`·`TAG_LIMIT_EXCEEDED`(422) 추가
- [ ] T176 [P] [US2] 카테고리 엔티티 `blog-backend/src/main/java/net/java21/blog/backend/category/domain/Category.java`(`blog_id` FK LAZY, `parent_id` 자기 참조 LAZY NULL=상위, `name` VARCHAR(50) 같은 부모 아래 UNIQUE, `sort_order` INT)와 `CategoryRepository.java`, QueryDSL `CategoryQueryRepository.java`
- [ ] T177 [P] [US2] 태그 엔티티 `blog-backend/src/main/java/net/java21/blog/backend/tag/domain/Tag.java`(`name` VARCHAR(30) UNIQUE), `PostTag.java`(복합 PK post_id·tag_id), `TagRepository.java`, `PostTagRepository.java`, `TagNormalizer.java`
- [ ] T178 [US2] `blog-backend/src/main/java/net/java21/blog/backend/category/service/CategoryService.java`, `blog-backend/src/main/java/net/java21/blog/backend/category/controller/CategoryController.java`(`/blogs/{handle}/categories`, `/{id}`, `/order`), DTO `CategoryNode`
- [ ] T179 [US2] `blog-backend/src/main/java/net/java21/blog/backend/tag/service/TagService.java`, `blog-backend/src/main/java/net/java21/blog/backend/tag/controller/TagController.java`(`/tags/{name}/posts`, `/blogs/{handle}/tags`)
- [ ] T180 [US2] 글·블로그 확장: `blog-backend/src/main/java/net/java21/blog/backend/post/domain/Post.java`에 `category` LAZY 연관, `blog-backend/src/main/java/net/java21/blog/backend/post/service/PostDraftService.java`·`PostPublishService.java`(categoryId·tags), `blog-backend/src/main/java/net/java21/blog/backend/post/repository/PostQueryRepository.java`(category·tag 필터, tags 일괄 조회), `blog-backend/src/main/java/net/java21/blog/backend/manage/service/ManagePostService.java`(`MOVE_CATEGORY`), `blog-backend/src/main/java/net/java21/blog/backend/blog/service/BlogService.java`(`GET /blogs/{handle}`의 `categories`)
- [ ] T181 [US2] `blog-backend/src/main/java/net/java21/blog/backend/post/job/TrashPurgeJob.java`가 삭제된 블로그의 카테고리를 지우기 전에 남은 글의 `category_id`를 정리하도록 확장
- [ ] T182 [P] [US2] `blog-front/app/components/post/TagInput.tsx`, `blog-front/app/components/blog/CategoryTree.tsx`(블로그 홈 사이드), 카테고리 선택을 `write.tsx`·`PublishSettingsDialog.tsx`에 연결
- [ ] T183 [P] [US2] `blog-front/app/routes/blog-category.tsx`, `blog-front/app/routes/blog-tag.tsx`, `blog-front/app/routes/tag.tsx`
- [ ] T184 [P] [US2] `blog-front/app/routes/manage/categories.tsx`, 문구 `category`·`tag` namespace와 새 오류 코드 `errors.json`

**Checkpoint**: US1·US2가 각각 독립적으로 동작

---

## Phase 7: User Story 3 - 댓글로 소통하기 (Priority: P3)

**Goal**: 로그인 회원의 댓글·답글(1단계), 작성자 수정·삭제, 글 주인 삭제, 블로그·글별 댓글 허용, 댓글 관리 메뉴와 대시보드 댓글 수치

**Independent Test**: 회원 A의 글에 B가 댓글, A가 답글, 답글에 답글 시도 거부, A가 B의 댓글 삭제, 비로그인은 로그인 안내(quickstart #11)

FR: FR-027~029 (+ 006 FR-099·100의 댓글 관리·대시보드 댓글 수치)

### Tests for User Story 3 ⚠️

- [ ] T185 [P] [US3] `blog-backend/src/test/java/net/java21/blog/backend/comment/service/CommentServiceTest.java`: 볼 수 있는 글에만(노출 매트릭스, 아니면 404 `POST_NOT_FOUND`), content 1~1000자 일반 텍스트, 답글의 부모는 같은 글의 최상위 댓글이어야 함(아니면 422 `REPLY_DEPTH_EXCEEDED`), 블로그 `comment_enabled` 또는 글 `comment_enabled`가 false면 422 `COMMENTS_DISABLED`, 수정은 작성자만, 삭제는 작성자 또는 글 주인(아니면 403), 답글이 있는 댓글 삭제 시 자리만 남김(`deleted: true`, `content: null`), `comment_count` 갱신 (FR-027~029, AS1~4)
- [ ] T186 [P] [US3] `blog-backend/src/test/java/net/java21/blog/backend/comment/repository/CommentRepositoryTest.java`(`@JpaRepositoryTest`): 글 댓글 트리(작성순, `replies`)와 작성자·프로필을 댓글 수와 무관한 쿼리 수로, 블로그별 댓글 관리 목록(최신순 페이지, postId·postTitle), 최근 7일 새 댓글 수
- [ ] T187 [P] [US3] `blog-backend/src/test/java/net/java21/blog/backend/comment/controller/CommentControllerTest.java`: `GET/POST /posts/{postId}/comments`, `PATCH/DELETE /comments/{id}`, 비로그인 POST 401(AS5), 404·403·422
- [ ] T188 [P] [US3] `blog-backend/src/test/java/net/java21/blog/backend/manage/service/ManageCommentServiceTest.java`: `GET /blogs/{handle}/manage/comments`와 대시보드 `newComments7d`·`recentComments`(최근 5건)
- [ ] T189 [P] [US3] `TrashPurgeJobTest`에 영구 삭제되는 글의 댓글(답글 먼저) 삭제 확인 추가: `blog-backend/src/test/java/net/java21/blog/backend/post/job/TrashPurgeJobTest.java`
- [ ] T190 [P] [US3] `blog-front/tests/unit/components/CommentSection.test.tsx`: 작성자·작성 시각 표시, 비로그인은 로그인 안내(`/login?next=`), 답글은 한 단계 들여쓰기·답글의 답글 버튼 없음, 권한에 따른 수정·삭제 버튼, 삭제된 댓글 자리 표시, `COMMENTS_DISABLED` 안내, 출력은 이스케이프
- [ ] T191 [P] [US3] `blog-front/tests/unit/routes/manageComments.test.tsx`: 댓글 관리 목록·삭제, 대시보드 댓글 수치
- [ ] T192 [P] [US3] E2E `blog-front/tests/e2e/us3-comments.spec.ts`: Independent Test 전체

### Implementation for User Story 3

- [ ] T193 [US3] `blog-backend/src/main/java/net/java21/blog/backend/common/error/ErrorCode.java`에 `COMMENT_NOT_FOUND`(404), `REPLY_DEPTH_EXCEEDED`·`COMMENTS_DISABLED`(422) 추가
- [ ] T194 [P] [US3] 댓글 엔티티 `blog-backend/src/main/java/net/java21/blog/backend/comment/domain/Comment.java`(`post_id` FK LAZY, `user_id` FK LAZY, `parent_id` 자기 참조 NULL=댓글, `content` VARCHAR(1000), `status` VARCHAR(10) ACTIVE/DELETED; 004·005 컬럼은 매핑하지 않음), `CommentStatus.java`, `CommentRepository.java`, QueryDSL `CommentQueryRepository.java`
- [ ] T195 [US3] `blog-backend/src/main/java/net/java21/blog/backend/comment/service/CommentService.java`, `blog-backend/src/main/java/net/java21/blog/backend/comment/controller/CommentController.java`, DTO `Comment`(`{ id, content, author, deleted, createdAt, updatedAt, replies }`)
- [ ] T196 [US3] 연결: `blog-backend/src/main/java/net/java21/blog/backend/manage/controller/ManageController.java`에 `/manage/comments`, `blog-backend/src/main/java/net/java21/blog/backend/manage/service/ManageDashboardService.java`에 댓글 수치, `blog-backend/src/main/java/net/java21/blog/backend/post/job/TrashPurgeJob.java`에 댓글 삭제(답글 먼저), `blog-backend/src/main/java/net/java21/blog/backend/post/service/PostService.java` 상세 응답의 `commentCount`·`commentEnabled`(블로그 설정 반영)
- [ ] T197 [P] [US3] `blog-front/app/components/comment/CommentSection.tsx`, `CommentForm.tsx`, 글 상세 `post-detail.tsx`에 댓글 loader·`action`(작성·수정·삭제) 연결
- [ ] T198 [P] [US3] `blog-front/app/routes/manage/comments.tsx`, 대시보드 댓글 영역, 문구 `comment` namespace와 새 오류 코드 `errors.json`

**Checkpoint**: US1~US3이 각각 독립적으로 동작

---

## Phase 8: User Story 4 - 글에 이미지 넣기 (Priority: P4)

**Goal**: 이미지 임시 업로드(무작위 키) → 글 저장·발행·프로필·블로그 대표 이미지로 등록, 참조 관계(post_media)와 정리 작업, 허용 목록 썸네일

**Independent Test**: 글 작성 화면에서 이미지 1장 업로드 → 본문 삽입 → 발행 후 방문자 화면에서 이미지가 보임. 저장하지 않은 이미지는 TTL 뒤 삭제, 남의 TEMP는 404, 썸네일 허용 목록(quickstart #12~15, #23~25)

FR: FR-038, FR-039, FR-071~074, FR-107(대표 이미지), FR-130~132, FR-156

### Tests for User Story 4 ⚠️

- [ ] T199 [P] [US4] `blog-backend/src/test/java/net/java21/blog/backend/media/service/ImageInspectorTest.java`: 매직 넘버로 jpeg·png·gif·webp 판별, 확장자만 .jpg인 텍스트·SVG·HTML은 415 `MEDIA_TYPE_NOT_ALLOWED`, 가로·세로 읽기 (FR-039, R27)
- [ ] T200 [P] [US4] `blog-backend/src/test/java/net/java21/blog/backend/media/service/MediaUploadServiceTest.java`: `blog.media.max-size`(기본 10MB) 초과 413 `MEDIA_TOO_LARGE`, 회원 TEMP 합계가 `temp-quota`(기본 200MB) 초과 시 429 `MEDIA_TEMP_QUOTA_EXCEEDED`, `media_key`는 `SecureRandom` 128비트 base62 22자(`^[0-9A-Za-z]{22}$`), `stored_name` `{uuid}.{ext}`(원래 이름 안 씀), `purpose` POST/PROFILE/BLOG_COVER, status TEMP (FR-038·039, FR-074, FR-156, AS1·2)
- [ ] T201 [P] [US4] `blog-backend/src/test/java/net/java21/blog/backend/media/service/MediaReferenceServiceTest.java`: 본문 `/media/{key}` 추출, 글 작성자 본인이 올린 이미지만 연결, 작성 중 사본 저장 → DRAFT 행 교체, 발행 → PUBLISHED 행 교체·DRAFT 행 삭제, 사본 폐기 → DRAFT 행만 삭제, TEMP → ATTACHED 시 temp-dir에서 `upload-dir/yyyy/MM/`로 이동(주소 불변), 정리 대상 판단(post_media·`users.profile_media_id`·`blogs.cover_media_id` 모두 없을 때만 ORPHANED), 작성 중 사본에서만 빠진 이미지는 유지, ORPHANED 재참조 → ATTACHED, 파일 이동 실패 시 롤백 (FR-071·073, AS4, quickstart #13·14)
- [ ] T202 [P] [US4] `blog-backend/src/test/java/net/java21/blog/backend/media/repository/MediaRepositoryTest.java`(`@JpaRepositoryTest`): 회원별 TEMP 합계, 정리 후보(만료 TEMP·ORPHANED), 참조 존재 확인을 이미지 수와 무관한 쿼리 수로
- [ ] T203 [P] [US4] `blog-backend/src/test/java/net/java21/blog/backend/media/storage/LocalMediaStorageTest.java`(`@TempDir`): `saveTemp`·`promote`·`open`·`delete`, 시작 시 upload·temp·thumbnail 디렉터리 생성과 쓰기 가능 검사(실패 시 기동 중단)
- [ ] T204 [P] [US4] `blog-backend/src/test/java/net/java21/blog/backend/media/thumbnail/ThumbnailServiceTest.java`: 허용 목록(`blog.media.thumbnail.sizes`) 밖 크기 400 `THUMBNAIL_SIZE_NOT_ALLOWED`, `fit` cover(기본)·contain, 원본보다 크게 늘리지 않음, 움직이는 GIF는 첫 장면, WebP 원본은 PNG 출력, 같은 썸네일 20개 동시 요청에도 파일 하나(키별 락 + 임시 파일 + `ATOMIC_MOVE`), 저장 위치 `thumbnail-dir/{key}/{w}x{h}-{fit}.{ext}` (FR-130~132, AS5, quickstart #23)
- [ ] T205 [P] [US4] `blog-backend/src/test/java/net/java21/blog/backend/media/controller/MediaControllerTest.java`: `POST /api/v1/media` multipart 201 `{ key, url, mime, size, width, height }`, `GET /media/{key}`는 TEMP면 올린 회원에게만(`Cache-Control: private, no-store`) 그 외 404 `MEDIA_NOT_FOUND`, ATTACHED·ORPHANED는 누구나(`public, max-age=31536000, immutable`), `Content-Type`·`nosniff`·`Content-Disposition: inline`, 키 형식이 아니면 404, 비로그인 업로드 401 (FR-156, AS6, quickstart #24)
- [ ] T206 [P] [US4] `blog-backend/src/test/java/net/java21/blog/backend/media/job/MediaCleanupJobTest.java`: `created_at < now - temp-ttl` TEMP와 ORPHANED의 파일·썸네일 디렉터리·행 삭제, 건수 로그 (FR-072·073, AS3, quickstart #12)
- [ ] T207 [P] [US4] `blog-backend/src/test/java/net/java21/blog/backend/media/MediaIntegrationHooksTest.java`: 발행 설정 `thumbnailMediaKey`는 본문 이미지 중 하나(생략 시 첫 이미지, 없으면 null) → `thumbnail_url` `/media/{key}`, `PATCH /me` `profileImageMediaKey`(purpose PROFILE 본인 이미지만)·`PATCH /blogs/{handle}` `coverImageMediaKey`(BLOG_COVER 본인 이미지만) → ATTACHED + 이전 이미지 판단, 휴지통 영구 삭제 시 post_media 삭제 후 판단, 응답의 `profileImageUrl`·`coverImageUrl` (FR-107, quickstart #25)
- [ ] T208 [P] [US4] `blog-front/tests/unit/components/EditorUpload.test.tsx`: 붙여넣기·끌어놓기 이미지가 `onUploadImage` → `POST /api/v1/media` → 본문에 `/media/{key}` 삽입, 413·415·429 문구
- [ ] T209 [P] [US4] `blog-front/tests/unit/components/PublishThumbnail.test.tsx`(본문 이미지 중 대표 이미지 선택, 기본 첫 이미지)와 `blog-front/tests/unit/media/thumbnail.test.ts`(화면별 크기 300x200·600x400·50x50·100x100·1200x630 주소와 2배 `srcset`)
- [ ] T210 [P] [US4] `blog-front/tests/unit/server/mediaProxy.test.ts`: `/media/**` 프록시가 바이너리·캐시 헤더를 그대로 전달하고, `/api/v1/media` 업로드 본문(10MB)을 크기 제한 없이 스트리밍
- [ ] T211 [P] [US4] E2E `blog-front/tests/e2e/us4-images.spec.ts`: Independent Test, 11MB·가짜 jpg 거부, 남의 TEMP 404 (quickstart #13·15·24)

### Implementation for User Story 4

- [ ] T212 [US4] `blog-backend/pom.xml`에 Thumbnailator(`net.coobird:thumbnailator`), TwelveMonkeys `imageio-webp` 추가, `blog-backend/src/main/java/net/java21/blog/backend/common/error/ErrorCode.java`에 `MEDIA_NOT_FOUND`(404), `MEDIA_TOO_LARGE`(413), `MEDIA_TYPE_NOT_ALLOWED`(415), `MEDIA_TEMP_QUOTA_EXCEEDED`(429), `THUMBNAIL_SIZE_NOT_ALLOWED`(400) 추가, `blog-backend/src/main/java/net/java21/blog/backend/common/error/GlobalExceptionHandler.java`에서 `MaxUploadSizeExceededException` → `MEDIA_TOO_LARGE`
- [ ] T213 [P] [US4] `blog-backend/src/main/java/net/java21/blog/backend/media/MediaProperties.java`(`@ConfigurationProperties("blog.media")`: `upload-dir`·`temp-dir`·`thumbnail-dir` 필수, `temp-ttl` 24h, `temp-quota` 200MB, `max-size` 10MB, `cleanup-cron` `0 0 * * * *`, `allowed-types` 4종, `thumbnail.sizes` 50x50·100x100·160x160·200x200·300x200·320x320·600x400·1200x630·1200x800·2400x1260)와 `application.yml`의 `spring.servlet.multipart.max-file-size` 정렬
- [ ] T214 [P] [US4] 이미지 엔티티 `blog-backend/src/main/java/net/java21/blog/backend/media/domain/Media.java`(`media_key` CHAR(22) UNIQUE, `owner_id` FK LAZY, `owner_type` VARCHAR(12) POST/PROFILE/BLOG_COVER, `status` VARCHAR(10) TEMP/ATTACHED/ORPHANED, `stored_name` VARCHAR(100), `stored_path` VARCHAR(300), `mime` VARCHAR(20), `size_bytes`, `width`, `height`), `PostMedia.java`(복합 PK post_id·media_id·source PUBLISHED/DRAFT), `MediaRepository.java`, `PostMediaRepository.java`
- [ ] T215 [P] [US4] 저장소 `blog-backend/src/main/java/net/java21/blog/backend/media/storage/MediaStorage.java`(인터페이스 `saveTemp`, `promote`, `open`, `delete`)와 `LocalMediaStorage.java`
- [ ] T216 [US4] `blog-backend/src/main/java/net/java21/blog/backend/media/service/MediaKeyGenerator.java`, `ImageInspector.java`, `MediaUploadService.java`, `MediaReferenceService.java`(참조 갱신·정리 대상 판단)
- [ ] T217 [US4] `blog-backend/src/main/java/net/java21/blog/backend/media/thumbnail/ThumbnailService.java`와 `ThumbnailLocks.java`(Caffeine 만료 락 맵)
- [ ] T218 [US4] `blog-backend/src/main/java/net/java21/blog/backend/media/controller/MediaUploadController.java`(`/api/v1/media`)와 `MediaServeController.java`(`/media/{key}`, `/media/{key}/{w}x{h}`, 선택 인증), `SecurityConfig`·Origin 검사 규칙 확인
- [ ] T219 [US4] 정리 작업 `blog-backend/src/main/java/net/java21/blog/backend/media/job/MediaCleanupJob.java`
- [ ] T220 [US4] 연결: `blog-backend/src/main/java/net/java21/blog/backend/post/service/PostDraftService.java`(저장·폐기), `blog-backend/src/main/java/net/java21/blog/backend/post/service/PostPublishService.java`(발행·`thumbnailMediaKey`), `blog-backend/src/main/java/net/java21/blog/backend/post/job/TrashPurgeJob.java`(post_media 삭제 후 판단, 삭제된 블로그 대표 이미지), `blog-backend/src/main/java/net/java21/blog/backend/user/service/AccountService.java`(`profileImageMediaKey`), `blog-backend/src/main/java/net/java21/blog/backend/blog/service/BlogService.java`(`coverImageMediaKey`), `User`·`Blog` 엔티티의 이미지 연관 LAZY
- [ ] T221 [P] [US4] `blog-front/app/components/Editor/Editor.tsx`의 `onUploadImage` 구현(브라우저 `POST /api/v1/media`), `PublishSettingsDialog.tsx` 대표 이미지 선택, 썸네일 주소 도우미 `blog-front/app/media/thumbnail.ts`
- [ ] T222 [P] [US4] 프로필 이미지(`blog-front/app/routes/settings.profile.tsx`)와 블로그 대표 이미지(`blog-front/app/routes/manage/settings.tsx`) 업로드, 글 카드·프로필·`og:image`(1200x630)에 썸네일 사용, `blog-front/server.ts` 프록시 업로드 스트리밍 확인, 문구 `media` namespace와 새 오류 코드

**Checkpoint**: US1~US4가 각각 독립적으로 동작

---

## Phase 9: User Story 5 - 내 언어로 서비스 이용하기 (Priority: P5)

**Goal**: 언어 결정(회원 설정 → 쿠키 → 브라우저 → 영어), 하단 언어 선택(`/locale`), `/settings/language`(언어·시간대), 날짜·시간대 표기, 에디터 메뉴 번역, 4개 언어 번역 누락 0건

**Independent Test**: 브라우저 언어 ja로 첫 방문 → 일본어 → 하단에서 English → 같은 주소가 영어로, 로그인 후 다른 브라우저에서도 영어, 번역 키가 화면에 노출되지 않음(quickstart #26~28)

FR: FR-148~155 (단, 각 화면 문구의 4개 언어 번역은 US1~US4 작업에서 이미 함께 넣는다)

### Tests for User Story 5 ⚠️

- [ ] T223 [P] [US5] `blog-front/tests/unit/i18n/resolveLanguage.test.ts`: (1) 로그인 회원 `locale` → (2) 쿠키 `lang` → (3) `Accept-Language`(q 값 순서, `zh`·`zh-Hans`·`zh-CN` → zh-CN, `en-US` → en) → (4) en, 지원하지 않는 값 무시 (FR-149, AS1)
- [ ] T224 [P] [US5] `blog-front/tests/unit/routes/locale.test.ts`: `/locale` `action`이 쿠키 `lang`(1년) 저장, 로그인 상태면 `PATCH /api/v1/me` `locale`, 원래 페이지(같은 사이트 경로만)로 리다이렉트, JS 없이 폼 전송으로 동작 (FR-150, AS2·3)
- [ ] T225 [P] [US5] `blog-front/tests/unit/i18n/format.test.ts`: `Intl.DateTimeFormat`으로 ko "2026년 10월 6일", en "Oct 6, 2026", ja·zh-CN "2026年10月6日", 회원 `timeZone`(비회원 `Asia/Seoul`) 적용, 숫자 표기 (FR-153)
- [ ] T226 [P] [US5] `blog-front/tests/unit/i18n/fallback.test.ts`: 일부 키가 빠진 언어는 en, en도 없으면 ko 문구가 나오고 키 이름이 나오지 않음, SSR `<html lang>`과 hydration 리소스가 같은 언어 (FR-152, AS6)
- [ ] T227 [P] [US5] `blog-front/tests/unit/i18n/errorCodes.test.ts`: contracts/api.md 오류 코드 표의 001 코드 전부(`blog-front/app/api/errorCodes.ts` 상수)가 4개 언어 `errors.json`에 있음 (FR-154)
- [ ] T228 [P] [US5] `blog-front/tests/unit/components/LanguageSelector.test.tsx`와 `blog-front/tests/unit/routes/settingsLanguage.test.tsx`(언어·시간대 선택 저장, IANA 시간대 목록)
- [ ] T229 [P] [US5] `blog-front/tests/unit/components/EditorI18n.test.tsx`: Crepe 메뉴·플레이스홀더 문구가 `editor` namespace의 화면 언어 번역 (FR-148)
- [ ] T230 [P] [US5] `blog-backend/src/test/java/net/java21/blog/backend/mail/MailLocaleTest.java`: 회원 `locale`이 en이면 재설정 메일이 영어, `locale` NULL이면 기본 en (AS5, quickstart #27)
- [ ] T231 [P] [US5] E2E `blog-front/tests/e2e/us5-i18n.spec.ts`: Independent Test, 일본어 화면에서 한국어 글 본문은 그대로(AS4), 4개 언어 오류 문구 (quickstart #26~28)

### Implementation for User Story 5

- [ ] T232 [US5] 언어 결정 `blog-front/app/i18n/resolveLanguage.server.ts`를 `blog-front/app/root.tsx` loader에 연결(서버 i18next 인스턴스, `<html lang>`, hydration 리소스 전달)
- [ ] T233 [P] [US5] `blog-front/app/routes/locale.ts`(리소스 라우트 `action`)와 `blog-front/app/components/layout/LanguageSelector.tsx`를 `Footer.tsx`에 연결
- [ ] T234 [P] [US5] `blog-front/app/routes/settings.language.tsx`(언어·시간대, `PATCH /me`)
- [ ] T235 [P] [US5] 날짜·숫자 형식 `blog-front/app/i18n/format.ts`를 글 목록·글 상세·댓글·로그인 기록·관리 화면의 시각 표시에 적용
- [ ] T236 [P] [US5] Crepe 문구 설정을 `editor` namespace 번역으로 채움: `blog-front/app/components/Editor/Editor.tsx`, `blog-front/app/locales/{ko,en,ja,zh-CN}/editor.json`
- [ ] T237 [US5] `blog-front/app/api/errorCodes.ts`와 4개 언어 전체 번역 점검·보완(모든 namespace 누락 0건, SC-024)

**Checkpoint**: 모든 스토리가 독립적으로 동작하고 번역 누락 0건

---

## Phase 10: Polish & Cross-Cutting Concerns

**Purpose**: 여러 스토리에 걸친 검증과 운영 최소 범위(헌법 "1.0 운영 범위")

- [ ] T238 [P] `blog-backend/src/test/java/net/java21/blog/backend/integration/ExposureMatrixIntegrationTest.java`(`@SpringBootTest`): 노출 매트릭스 001 행 전체를 글 상세·블로그 목록·카테고리·블로그 태그·서비스 태그·관리 목록 API에서 한 번에 확인(주인 외 노출 0건, SC-004)
- [ ] T239 [P] `blog-backend/src/test/java/net/java21/blog/backend/integration/XssDefenseIntegrationTest.java`: `<script>`, `<img onerror>`, `javascript:` 링크, 허용 목록 밖 iframe 본문과 SVG 업로드가 저장 후 무력화·거부됨(R27 검증)
- [ ] T240 [P] `blog-backend/src/test/java/net/java21/blog/backend/openapi/OpenApiContractTest.java`: `/v3/api-docs`에 contracts/api.md의 001 엔드포인트(메서드·경로)가 모두 있고 응답이 공통 틀임. 이어서 `npm run gen:api`로 `blog-front/app/api/schema.d.ts`를 갱신하고 `npm run typecheck` 통과
- [ ] T241 [P] 로그인이 필요한 API 응답에 `Cache-Control: no-store`가 붙는지 확인하는 테스트 `blog-backend/src/test/java/net/java21/blog/backend/security/CacheHeadersWebMvcTest.java`(api-guidelines 8절)
- [ ] T242 [P] 로그 최소 범위 `blog-backend/src/main/resources/logback-spring.xml`: 일별 롤링·30일 보관, `traceId` MDC 출력, 에러 스택(prod에서 `resultMessage`에 내부 정보 없음 확인)
- [ ] T243 [P] 운영 문서 `blog-backend/docs/operations.md`: 필수 프로퍼티·환경 변수 목록, `blog.media.upload-dir` 일일 백업 절차(thumbnail-dir 제외), 정기 작업 cron, 첫 SUPER_ADMIN 지정
- [ ] T244 [P] 두 저장소 README를 4개 언어로 갱신(실행·테스트 명령): `blog-backend/README.md`·`README.en.md`·`README.ja.md`·`README.zh-CN.md`, `blog-front/README.md`·`README.en.md`·`README.ja.md`·`README.zh-CN.md`
- [ ] T245 [P] front E2E CI `blog-front/.github/workflows/e2e.yml`(수동 실행·야간): MySQL 서비스에 `schema-mysql.sql` 적용, Mailpit, backend 체크아웃·기동 후 `npm run e2e`
- [ ] T246 성능 확인(`blog-front/app/routes/post-detail.tsx` SSR + `blog-backend/src/main/java/net/java21/blog/backend/post/service/PostService.java`): 글 10만·회원 1만 데이터에서 글 상세 SSR p95 1초 이내, 동시 200(SC-002·003). 측정 도구는 저장소에 추가하지 않고 절차와 결과를 PR 설명에 기록
- [ ] T247 커버리지 확인: `blog-backend`의 `./mvnw verify`, `blog-front`의 `npm test -- --coverage` 모두 라인 80% 이상
- [ ] T248 `blog-docs/specs/001-blog-core/quickstart.md` 수동 검증 시나리오 #1~33 전체 실행(backend·front 함께 기동)

---

## 구현 전 결정 사항 (2026-10-06 확정)

marco가 "묻지 말고 진행"하라고 해서 Claude가 기본값으로 정했다. 바꾸려면 이 표와 관련 문서를 함께 고친다.

| # | 문제 | 결정 | 반영 문서 |
|---|---|---|---|
| 1 | SSR 요청에는 리프레시 쿠키(`Path=/api/v1/auth`)가 실리지 않아 30분 뒤 SSR에서 로그아웃처럼 보임 | 리프레시 쿠키 `Path=/`로 변경(HttpOnly·Secure·SameSite=Lax 유지). front 서버 SSR loader가 401을 받으면 들어온 쿠키로 `POST /api/v1/auth/refresh`를 한 번 부르고, 새 `Set-Cookie`를 응답에 실어 원 요청을 다시 실행한다. 브라우저 쪽은 T070대로 | research R2, contracts/api.md 인증 |
| 2 | 비밀번호 변경 시 "현재 기기"를 알 수 없음 | 접근 토큰에 로그인 계열 ID 클레임 `fid`를 넣는다(클레임: userId·role·fid). `/me/password`는 `fid`를 뺀 모든 family를 폐기 | research R2 |
| 3 | `POST_CONTENT_EMPTY`가 오류 표에 없음 | 422 `POST_CONTENT_EMPTY`(본문이 비어 발행 불가) 추가 | contracts/api.md |
| 4 | 카테고리 목록·`postCount` 기준, 최상위 이름 중복 | 상위 카테고리 글 목록은 하위 카테고리 글을 포함한다. `postCount`는 보는 사람 기준 목록 노출 가능(`listable()`) 글 수이고, 상위는 하위를 포함한다(주인 관리 화면은 상태별 전체 수). 같은 부모(최상위 포함) 아래 이름 중복은 서비스에서 `CATEGORY_NAME_TAKEN`으로 막는다 | 이 표 |
| 5 | `comment_count` 기준 | 삭제·숨김을 뺀 표시되는 댓글 수(답글 포함). 댓글 작성·삭제·숨김 때 같은 트랜잭션에서 증감 | 이 표 |
| 6 | quickstart 로컬 실행이 빈 MySQL이라 `ddl-auto=validate`에서 뜨지 않음 | 로컬은 Crowfoot 개발 DB `cf_u2_d2`를 쓰고(`.env`의 `DB_PASSWORD`), 개인 MySQL을 쓰려면 `db/schema-mysql.sql`을 먼저 실행 | quickstart.md |
| 7 | plan.md가 Flyway·파일 이름 등에서 현재 코드와 다름 | plan.md를 현재 코드에 맞춤(Flyway 삭제, `BlogBackendApplication`, `config/SecurityConfig`, artifactId `blog-backend`) | plan.md, constitution |
| 8 | api.md에 003·006 API 포함 | 001 구현에서는 빼고 해당 스펙 구현 때 만든다. `unseenReleaseNote`는 003 전까지 null. 관리자 블로그 한도 API는 Phase 5에서 만든다 | 이 표 |
| 9 | 동시 블로그 생성 테스트는 MySQL 행 잠금이 필요 | `@MySqlRepositoryTest`는 "MySQL 전용 쿼리·동작(FULLTEXT, 행 잠금 동시성)"에 쓴다 | constitution |
| 10 | 기타 | 탈퇴 30일 파기 시 `email_hash` = HMAC(`withdrawn:{userId}`), `email_enc` = 같은 문자열 암호문(UNIQUE·NOT NULL 유지). IP 가림은 IPv4 뒤 두 자리(`211.234.*.*`), IPv6 앞 3블록만(`2001:db8:85a3::*`). 약관·개인정보 본문은 초안 자리표시자로 두고 운영자가 채운다. 글 번호 숫자 검사는 loader에서 한다 | 이 표 |

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: 바로 시작. [X] 작업은 별도 브랜치가 main에 들어오면 끝
- **Foundational (Phase 2)**: Setup의 QueryDSL·H2 의존성(T007, T008) 이후. 모든 스토리를 막는다
- **US1 가입·글쓰기 (Phase 3)**: Phase 2 이후. MVP
- **US1 계정 설정 (Phase 4)**: Phase 3의 회원·인증(T082, 로그인·리프레시 서비스) 이후. Phase 5와 병렬 가능
- **US1 관리 뼈대 (Phase 5)**: Phase 3의 블로그·글(T089, T098) 이후
- **US2 (Phase 6)**, **US3 (Phase 7)**, **US4 (Phase 8)**: Phase 3 이후. 서로 독립이라 병렬 가능하지만 같은 파일(`PostDraftService`, `PostPublishService`, `TrashPurgeJob`, `ManageDashboardService`, `ErrorCode`, `errors.json`)을 고치는 연결 작업은 순서대로 머지한다
- **US5 (Phase 9)**: Phase 3 이후 언제든. 각 스토리의 번역은 그 스토리 작업에서 이미 넣으므로 US5는 언어 결정·선택·형식·누락 점검 마무리
- **Polish (Phase 10)**: 원하는 스토리가 모두 끝난 뒤

### User Story Dependencies

- **US1 (P1)**: Phase 2 이후. 다른 스토리에 의존하지 않음. 회원·블로그·글 엔티티와 노출 조각(T098)을 만든다
- **US2 (P2)**: US1의 Post·Blog·노출 조각을 확장. US1만 있으면 독립 테스트 가능
- **US3 (P3)**: US1의 Post·User를 사용. 관리 메뉴는 Phase 5 이후에 붙인다
- **US4 (P4)**: US1의 글 저장·발행과 Phase 4의 프로필 수정에 연결. 프로필 이미지 부분만 Phase 4에 의존
- **US5 (P5)**: Phase 2의 front i18n 기반과 Phase 4의 `PATCH /me`(locale·timeZone)에 의존

### Within Each User Story

- 테스트를 먼저 쓰고 실패를 확인한 뒤 구현한다(원칙 III)
- 엔티티 → 리포지토리(QueryDSL) → 서비스 → 컨트롤러 → front 라우트 → E2E
- 엔티티를 더할 때마다 `EntitySchemaValidationTest`(실제 스키마 대상 `ddl-auto=validate`)가 통과해야 한다
- 새 화면 문구·오류 코드는 같은 작업에서 4개 언어 번역을 넣는다(원칙 VII)
- 스토리의 E2E(Independent Test)가 통과해야 다음 우선순위로 넘어간다

### Parallel Opportunities

- Setup의 [P] 작업(의존성 추가, CI 두 개, Playwright, CLAUDE.md)은 모두 병렬
- Phase 2 테스트 작업은 모두 [P]. 구현은 `QueryDslConfig`·`TimeConfig`·front 작업이 병렬
- 각 스토리의 테스트 작업(backend·front)은 모두 [P]
- 엔티티([P] 표시)는 서로 다른 파일이라 병렬
- Phase 3 이후 US2·US3·US4·US5와 Phase 4·5는 사람이 여럿이면 병렬

---

## Parallel Example: User Story 1

```bash
# backend 테스트를 함께 시작:
Task: "HandlePolicyTest in blog-backend/src/test/java/net/java21/blog/backend/blog/service/HandlePolicyTest.java"
Task: "RefreshTokenServiceTest in blog-backend/src/test/java/net/java21/blog/backend/auth/service/RefreshTokenServiceTest.java"
Task: "MarkdownRendererTest in blog-backend/src/test/java/net/java21/blog/backend/content/MarkdownRendererTest.java"
Task: "PostExposureRepositoryTest in blog-backend/src/test/java/net/java21/blog/backend/post/repository/PostExposureRepositoryTest.java"

# front 테스트를 함께 시작:
Task: "signup.test.tsx in blog-front/tests/unit/routes/signup.test.tsx"
Task: "postDetail.test.tsx in blog-front/tests/unit/routes/postDetail.test.tsx"
Task: "write.test.tsx in blog-front/tests/unit/routes/write.test.tsx"

# 엔티티를 함께 만들기:
Task: "User in blog-backend/src/main/java/net/java21/blog/backend/user/domain/User.java"
Task: "Blog in blog-backend/src/main/java/net/java21/blog/backend/blog/domain/Blog.java"
Task: "Post in blog-backend/src/main/java/net/java21/blog/backend/post/domain/Post.java"
```

## Parallel Example: User Story 4

```bash
Task: "ImageInspectorTest in blog-backend/src/test/java/net/java21/blog/backend/media/service/ImageInspectorTest.java"
Task: "ThumbnailServiceTest in blog-backend/src/test/java/net/java21/blog/backend/media/thumbnail/ThumbnailServiceTest.java"
Task: "LocalMediaStorageTest in blog-backend/src/test/java/net/java21/blog/backend/media/storage/LocalMediaStorageTest.java"
Task: "EditorUpload.test.tsx in blog-front/tests/unit/components/EditorUpload.test.tsx"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1 Setup, Phase 2 Foundational
2. Phase 3 (US1 가입·글쓰기)
3. **멈추고 확인**: US1 Independent Test E2E, quickstart #1~8·16~18·30~32
4. 시연·배포 가능

### Incremental Delivery

1. Setup + Foundational → 기반 완료
2. US1(Phase 3) → MVP
3. 계정 설정(Phase 4) + 관리 뼈대(Phase 5) → US1 완성
4. US2 → US3 → US4 → US5 순으로, 각 스토리의 E2E 통과 후 다음
5. Polish → quickstart 전체 검증

### Parallel Team Strategy

1. 함께 Setup + Foundational
2. 한 명이 Phase 3(US1)을 끝내면:
   - 개발자 A: Phase 4 → US5
   - 개발자 B: Phase 5 → US3
   - 개발자 C: US2 → US4
3. 같은 파일을 고치는 연결 작업은 머지 순서를 맞춘다

---

## Notes

- [P] = 다른 파일, 끝나지 않은 작업에 의존하지 않음
- [Story] = spec.md 사용자 스토리 추적용
- 각 PR 설명에 스펙 경로 `blog-docs/specs/001-blog-core`를 적는다(헌법 개발 흐름 6)
- 엔티티는 API 응답으로 직렬화하지 않고 DTO record를 쓴다. 연관관계는 모두 LAZY, 목록은 fetch join 또는 DTO projection
- 002~007이 더한 컬럼(`posts.like_count`, `blogs.portal_enabled` 등)은 DB 기본값이 있으므로 001 엔티티에 매핑하지 않는다
- 테스트가 실패하는 것을 먼저 확인하고, 작업 단위로 커밋한다
