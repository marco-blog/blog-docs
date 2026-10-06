# Quickstart: 001 블로그 핵심 검증 가이드

구현이 끝난 뒤 이 순서로 실행해 스펙이 동작함을 확인한다. 세부 API는 [contracts/api.md](./contracts/api.md), 화면은 [contracts/routes.md](./contracts/routes.md).

## 준비

- Java 21, Node.js 22, Docker
- 세 저장소를 형제 디렉터리로 체크아웃: `blog/blog-docs`, `blog/blog-backend`, `blog/blog-front`

```bash
# MySQL
docker run -d --name blog-mysql -p 3306:3306 \
  -e MYSQL_DATABASE=blog -e MYSQL_USER=blog -e MYSQL_PASSWORD=blog -e MYSQL_ROOT_PASSWORD=root \
  mysql:8.4 --character-set-server=utf8mb4 --collation-server=utf8mb4_0900_ai_ci

# backend (첨부 디렉터리는 프로퍼티로 지정)
cd blog/blog-backend
export BLOG_AUTH_JWT_SECRET=$(openssl rand -base64 48)
./mvnw spring-boot:run -Dspring-boot.run.arguments="\
 --blog.base-url=http://localhost:5173 \
 --blog.media.upload-dir=$HOME/blog-data/media \
 --blog.media.temp-dir=$HOME/blog-data/media-tmp"

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
| 3 | US1 | `/write`에서 한글 제목·본문 입력 후 발행 (Chrome, Safari, Edge 각각) | 한글 조합 중 글자 중복·누락 없음, `/marco/{id}`로 이동 |
| 4 | US1 | 로그아웃 후 `curl -s http://localhost:5173/marco/{id}` | HTML에 제목·본문·`og:title` 포함 (JS 없이) |
| 5 | US1 | 비공개 글을 다른 계정·비로그인으로 열기 | 404 화면, HTTP 404 |
| 6 | US1 | 본문에 `<script>alert(1)</script>` 넣고 발행 | 스크립트 실행 안 됨, 텍스트로도 남지 않음 |
| 7 | US1 | 로그인 후 브라우저를 열어 둔 채 31분 뒤 글 저장 | 다시 로그인 요구 없이 저장됨(자동 리프레시) |
| 8 | US1 | 로그아웃한 뒤 이전 refresh 쿠키로 `/api/v1/auth/refresh` 호출 | 401 REFRESH_INVALID |
| 9 | US2 | 상위·하위 카테고리 생성, 글 분류 후 상위 카테고리 삭제 | 글은 "미분류"로 이동 |
| 10 | US2 | 태그 11개 입력 | 11번째 거부 |
| 11 | US3 | 다른 계정으로 댓글, 주인이 답글, 답글에 답글 시도 | 2단계까지만 허용 |
| 12 | US4 | 에디터에 이미지 붙여넣기 후 저장하지 않고 이탈, `blog.media.temp-ttl=1m`으로 재시작해 정리 주기 대기 | temp-dir에서 파일 삭제, `/media/{id}` 404 |
| 13 | US4 | 이미지 넣고 발행 | 파일이 upload-dir로 이동, 주소는 그대로 |
| 14 | US4 | 글 수정으로 이미지 제거 후 저장, 정리 주기 대기 | upload-dir에서 파일 삭제 |
| 15 | US4 | 11MB 파일, 확장자만 .jpg인 텍스트 파일 업로드 | 각각 413, 415 |
