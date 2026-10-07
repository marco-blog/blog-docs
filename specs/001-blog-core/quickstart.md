# Quickstart: 001 블로그 핵심 검증 가이드

구현이 끝난 뒤 이 순서로 실행해 스펙이 동작함을 확인한다. 세부 API는 [contracts/api.md](./contracts/api.md), 화면은 [contracts/routes.md](./contracts/routes.md).

## 준비

- Java 21, Node.js 22, Docker
- 세 저장소를 형제 디렉터리로 체크아웃: `blog/blog-docs`, `blog/blog-backend`, `blog/blog-front`

```bash
# DB: 기본은 Crowfoot 개발 DB(cf_u2_d2). blog-backend/.env 에 DB_PASSWORD 와 암호화 키를 넣으면
#     프로필을 지정하지 않아도(local) 그 DB로 뜬다(.env.example 참고).
# 개인 MySQL을 쓰려면 스키마를 먼저 만든다(Hibernate는 ddl-auto=validate라 빈 DB로는 뜨지 않는다).
docker run -d --name blog-mysql -p 3306:3306 \
  -e MYSQL_DATABASE=blog -e MYSQL_USER=blog -e MYSQL_PASSWORD=blog -e MYSQL_ROOT_PASSWORD=root \
  mysql:8.4 --character-set-server=utf8mb4 --collation-server=utf8mb4_0900_ai_ci --ngram-token-size=2
docker exec -i blog-mysql mysql -uroot -proot blog < blog/blog-docs/db/schema-mysql.sql

# 개발용 메일 서버(Mailpit): SMTP localhost:1025, 받은 메일 확인 http://localhost:8025 (계정 없이 받음)
docker run -d --name blog-mailpit -p 1025:1025 -p 8025:8025 axllent/mailpit

# backend (필수 프로퍼티는 모두 지정해야 기동된다. 아래 값은 개발용 자리표시자이며 실제 비밀값을 저장소·문서에 넣지 않는다)
cd blog/blog-backend
export BLOG_AUTH_JWT_SECRET=$(openssl rand -base64 48)
export BLOG_CRYPTO_KEY_V1=$(openssl rand -base64 32)      # 개인정보 암호화 키(버전 1)
export BLOG_CRYPTO_HASH_KEY=$(openssl rand -base64 32)    # 이메일 검색용 HMAC 키
./mvnw spring-boot:run -Dspring-boot.run.arguments="\
 --spring.datasource.url=jdbc:mysql://localhost:3306/blog \
 --spring.datasource.username=blog --spring.datasource.password=blog \
 --blog.base-url=http://localhost:5173 \
 --blog.media.upload-dir=$HOME/blog-data/media \
 --blog.media.temp-dir=$HOME/blog-data/media-tmp \
 --blog.media.thumbnail-dir=$HOME/blog-data/media-thumb \
 --blog.crypto.keys.1=$BLOG_CRYPTO_KEY_V1 \
 --blog.crypto.active-key-version=1 \
 --blog.crypto.hash-key=$BLOG_CRYPTO_HASH_KEY \
 --blog.mail.host=localhost --blog.mail.port=1025 \
 --blog.mail.from=no-reply@localhost --blog.mail.starttls=false \
 --blog.legal.terms-version=2026-10-06 \
 --blog.admin.bootstrap-super-admin-email=<관리자로 지정할 가입 이메일>"

# front
cd ../blog-front && npm install && npm run dev   # http://localhost:5173
```

## 자동 검증 (커버리지 게이트 포함)

```bash
cd blog/blog-backend && ./mvnw verify      # 슬라이스 테스트 + JaCoCo 라인 80% 미만이면 실패
cd blog/blog-front && npm test -- --coverage   # Vitest, 라인 80% 미만이면 실패
cd blog/blog-front && npm run e2e          # Playwright: 아래 시나리오 자동화
```

## 수동 검증 시나리오

| # | 스토리 | 절차 | 기대 결과 |
|---|---|---|---|
| 1 | US1 | `/signup`에서 handle `marco`로 가입 | 바로 로그인되고 `/marco`가 빈 블로그로 열림 |
| 2 | US1 | 같은 handle, 예약어 `login`으로 다시 가입 | 각각 "이미 사용 중", "사용할 수 없는 주소" |
| 3 | US1 | `/write`(→ `/marco/write`로 이동)에서 한글 제목·본문 입력 → "완료" → 발행 설정에서 공개 범위·카테고리·태그·대표 이미지·댓글 허용 확인 → "공개 발행" (Chrome, Safari, Edge 각각) | 한글 조합 중 글자 중복·누락 없음, "완료"만으로는 발행되지 않음, 발행 후 `/marco/{id}`로 이동 |
| 4 | US1 | 로그아웃 후 `curl -s http://localhost:5173/marco/{id}` | HTML에 제목·본문·`og:title` 포함 (JS 없이) |
| 5 | US1 | 비공개 글을 다른 계정·비로그인으로 열기 | 404 화면, HTTP 404 |
| 6 | US1 | 본문에 `<script>alert(1)</script>` 넣고 발행 | 스크립트 실행 안 됨, 텍스트로도 남지 않음 |
| 7 | US1 | 로그인 후 브라우저를 열어 둔 채 31분 뒤 글 저장 | 다시 로그인 요구 없이 저장됨(자동 리프레시) |
| 8 | US1 | 로그아웃한 뒤 이전 refresh 쿠키로 `/api/v1/auth/refresh` 호출 | 401 REFRESH_INVALID |
| 9 | US2 | 상위·하위 카테고리 생성, 글 분류 후 상위 카테고리 삭제 | 글은 "미분류"로 이동 |
| 10 | US2 | 태그 11개 입력 | 11번째 거부 |
| 11 | US3 | 다른 계정으로 댓글, 주인이 답글, 답글에 답글 시도 | 2단계까지만 허용 |
| 12 | US4 | 에디터에 이미지 붙여넣기 후 저장하지 않고 이탈, `blog.media.temp-ttl=1m`으로 재시작해 정리 주기 대기 | temp-dir에서 파일 삭제, `/media/{key}` 404 |
| 13 | US4 | 이미지 넣고 발행 | 파일이 upload-dir로 이동, 주소는 그대로 |
| 14 | US4 | 발행된 글 수정 화면에서 이미지 제거 후 임시저장만 하고 정리 주기 대기 → 이어서 "수정 발행" 후 정리 주기 대기 | 임시저장만 했을 때는 발행본 이미지가 그대로 열림, 수정 발행 후(다른 글·프로필에서 안 쓰면) upload-dir에서 파일 삭제 |
| 15 | US4 | 11MB 파일, 확장자만 .jpg인 텍스트 파일 업로드 | 각각 413, 415 |
| 16 | US1 | 글을 삭제 → `/marco/manage/posts?status=DELETED`(휴지통)에서 복구 | 삭제 전 상태·공개 범위로 돌아옴. `deleted_at`을 31일 전으로 바꾸고 휴지통 비우기 작업 실행 시 영구 삭제 |
| 17 | US1 | 본문에 ` ```java ` 코드 블록 넣고 발행 → `curl`로 글 상세 HTML 확인 | JS 없이 `hljs-` 강조 span 포함, 언어 미지정 블록은 강조 없음 |
| 18 | US1 | 본문에 YouTube 주소 한 줄, Vimeo 주소 한 줄, 다른 사이트 iframe 넣고 발행 | YouTube(`youtube-nocookie.com/embed`)·Vimeo 재생기만 남고 다른 iframe은 제거 |
| 19 | US1 | `/password-reset`에서 이메일 입력 → Mailpit(http://localhost:8025)의 링크로 새 비밀번호 설정 → 같은 링크 다시 사용 | 재설정 성공, 다른 기기 로그인 끊김, 두 번째 사용은 `PASSWORD_RESET_TOKEN_INVALID`. 없는 이메일도 같은 안내 |
| 20 | US1 | `/settings/password`에서 비밀번호 변경(현재 비밀번호 틀림 → 맞음) | 틀리면 `CURRENT_PASSWORD_MISMATCH`, 맞으면 다른 기기 로그인 끊김 |
| 21 | US1 | 로그인 실패 1회 후 성공 → `/settings/login-history` | 두 기록(실패·성공)과 일부 가린 IP가 보임 |
| 22 | US1 | `mysql -e "SELECT email_enc, email_hash FROM users; SELECT ip_enc FROM login_history"` | 평문 이메일·IP가 하나도 없음(SC-022) |
| 23 | US4 | `/media/{key}/300x200`, `/media/{key}/301x200`, 원본보다 큰 `/media/{key}/2400x1260` 요청, 같은 썸네일 동시 20회 요청 | 300x200 생성, 301x200은 400 `THUMBNAIL_SIZE_NOT_ALLOWED`, 큰 요청은 원본 크기를 넘지 않음, thumbnail-dir에 파일 하나만 생김 |
| 24 | US4 | 다른 계정·비로그인으로 남의 TEMP 이미지 주소 요청 | 404 |
| 25 | US4 | 프로필 이미지 변경 후 정리 주기 대기 | 새 프로필 이미지는 유지(ATTACHED), 이전 이미지는 다른 곳에서 안 쓰면 삭제 |
| 26 | US5 | 브라우저 언어 ja로 첫 방문 → 하단에서 English 선택 → 로그인 후 다른 브라우저에서 로그인 | 처음 일본어, 선택 후 영어(주소 동일), 다른 브라우저도 영어 |
| 27 | US5 | 영어 회원으로 비밀번호 재설정 요청, `/settings/language`에서 시간대를 `America/New_York`으로 변경 | 메일이 영어, 글 작성 시각이 뉴욕 시간·영어 표기로 보임 |
| 28 | US5 | 로그인 실패 등 오류를 4개 언어로 각각 확인, `npm test`의 번역 누락 테스트 | 오류 문구가 화면 언어로 나오고 오류 키가 노출되지 않음, 누락 0건(SC-024) |
| 29 | 006 뼈대 | `/manage`(→ `/marco/manage`) 대시보드, `/marco/manage/posts`에서 글 3편 골라 비공개로 일괄 변경 | 임시저장 수·최근 글·최근 댓글 표시(방문자 수는 004 전까지 숨김), 3편 모두 비공개 |
| 30 | US1 | `/settings/blogs`에서 `marco-dev`, `marco-life` 블로그 만들기 → 네 번째 `marco-x` 만들기 시도 → `/marco-dev/write`에서 글 발행 → `/manage` 접속 | 블로그 3개(2/3 → 3/3), 네 번째는 409 `BLOG_LIMIT_EXCEEDED`. 글은 `/marco-dev/{id}`에만 있고 `/marco` 목록에는 없음. 닉네임·프로필은 세 블로그가 같음. `/manage`는 최근에 쓴 `/marco-dev/manage`로 이동 |
| 31 | US1 | 블로그 2개인 회원으로 `POST /api/v1/blogs`를 동시에 10회 요청(handle은 모두 다르게) | 201은 1건, 나머지 409 `BLOG_LIMIT_EXCEEDED`, `blogs`의 ACTIVE 행이 3개를 넘지 않음 |
| 32 | US1 | `marco-life` 삭제 → 다른 계정으로 `marco-life` 주소로 가입·블로그 만들기 시도 → 남은 블로그를 하나씩 삭제 시도 | `/marco-life`와 그 글은 404, 주소는 `HANDLE_TAKEN`, 마지막 블로그는 409 `LAST_BLOG_CANNOT_BE_DELETED` |
| 33 | 006 | 관리자가 `PATCH /api/v1/admin/users/{marco}/blog-limit` `{ "maxBlogs": 0 }` → marco가 블로그 만들기 시도 → `{ "maxBlogs": null }` (006 콘솔 구현 전에는 API로 확인) | 기존 블로그는 그대로(한도보다 많아도 유지), 새로 만들기는 `BLOG_LIMIT_EXCEEDED`. null이면 기본값 3으로 돌아와 만들 수 있음. 작업 기록에 두 건 |
