# REST API 설계 규칙

blog-backend의 모든 HTTP API는 이 규칙을 따른다. 각 스펙의 `contracts/api.md`는 이 규칙 위에서 엔드포인트만 정의한다.
규칙과 다르게 만들어야 하면 해당 api.md에 이유를 적는다.

## 1. 기본

- 기준 경로 `/api/v1`. 브라우저는 front 서버(`blog.java21.net`)를 거쳐 호출한다.
  - 예외: 이미지 `/media/**`, 피드·트랙백(`/{handle}/rss` 등)
- 형식은 JSON, UTF-8, `Content-Type: application/json`이다. 응답은 성공·실패 모두 4절의 공통 틀로 감싼다.
- 필드 이름은 camelCase로 쓴다(`createdAt`, `totalElements`).
- 시간은 ISO-8601 UTC로 쓴다(`2026-10-06T04:24:19Z`). 날짜만 있으면 `2026-10-06`. 시간대 변환은 front가 한다.
- 열거 값은 대문자 스네이크(`PUBLIC`, `PROTECTED`)로 쓴다. DB 값과 같다.
- ID
  - 숫자 ID는 JSON number로 준다. BIGINT이지만 2^53 미만이라 JavaScript에서 안전하다.
  - 밖으로 드러나면 안 되는 자원은 무작위 키를 쓴다(예: 미디어 `key`).
- 값이 없으면 필드를 빼지 않고 `null`로 준다. 목록이 비면 `[]`를 준다.

## 2. 자원과 경로

- 자원은 **복수 명사, 소문자, kebab-case**로 쓴다: `/blogs`, `/release-notes`, `/login-history`
- 블로그는 사람이 읽는 주소 `handle`로 식별한다: `/blogs/{handle}`
- 블로그에 속한 자원은 한 단계만 중첩한다: `/blogs/{handle}/posts`, `/blogs/{handle}/categories`
- 이미 전역 ID로 식별되는 자원은 짧은 경로를 쓴다: `/posts/{id}`, `/comments/{id}`. 깊은 중첩(`/blogs/{h}/posts/{id}/comments/{cid}`)은 쓰지 않는다.
- 로그인한 본인 자원은 `/me` 아래에 둔다: `/me`, `/me/blogs`, `/me/password`
- 관리 화면 전용 목록은 `/blogs/{handle}/manage/...`, 관리자 API는 `/admin/...`
- 경로에 동사를 쓰지 않는다. CRUD로 표현할 수 없는 상태 전이만 예외로, **하위 동작 자원**을 `POST`로 둔다.
  - 허용: `POST /posts/{id}/publish`, `POST /posts/{id}/restore`, `POST /posts/{id}/unlock`, `POST /auth/login`
  - 금지: `POST /posts/{id}/delete`, `GET /getPosts`, `POST /posts/update`
- 여러 개를 한 번에 처리할 때는 `POST /{collection}/bulk`를 쓴다. 본문에 `{ action, ids }`를 넣는다.

## 3. 메서드

| 메서드 | 의미 | 멱등 | 성공 응답 |
|---|---|---|---|
| GET | 조회. 상태를 바꾸지 않는다 | O | 200 |
| POST | 생성 또는 하위 동작 | X | 생성 201 + `Location`, 동작은 200, 비동기 처리는 202 |
| PUT | 전체 교체(순서 목록, 비밀번호, 작성 중 사본처럼 통째로 바꾸는 것) | O | 200 |
| PATCH | 일부 수정. 보낸 필드만 바꾸고, `null`은 값을 지운다(JSON Merge Patch, RFC 7396) | O | 200 + 바뀐 자원 |
| DELETE | 삭제(휴지통 이동 포함) | O | 200(`result: null`). 이미 없으면 404 |

- GET에 본문을 넣지 않는다. 검색 조건은 쿼리 문자열로 보낸다.
- 조회수 기록처럼 부수 효과가 있는 요청은 GET이 아니라 POST로 한다(`POST /posts/{id}/views`).

## 4. 공통 응답 형식 (Dooray 방식 + 실제 HTTP 상태 코드)

성공과 실패 모두 같은 틀로 감싼다. 형태는 NHN Dooray API를 따르고, 아래 두 가지만 다르게 한다.
- HTTP 상태 코드는 실제 값(201, 404, 409 등)을 쓴다. 오류인데 200을 주지 않는다.
- `resultCode`는 숫자 대신 다국어 문구용 **문자열 오류 코드**를 쓴다(FR-154, 헌법 원칙 VII).

```json
{
  "header": { "isSuccessful": true, "resultCode": "OK", "resultMessage": "" },
  "result": { ... },
  "totalCount": 135
}
```

| 필드 | 설명 |
|---|---|
| `header.isSuccessful` | 성공이면 `true`. HTTP 2xx와 항상 같다 |
| `header.resultCode` | 성공은 `"OK"`, 실패는 고정 오류 코드(`POST_NOT_FOUND` 등). 한번 정하면 바꾸지 않는다 |
| `header.resultMessage` | 영어 디버그용 설명. 화면에 보여주지 않는다. front는 `resultCode`를 메시지 키(`errors.{code}`)로 바꿔 화면 언어로 보여준다 |
| `header.fieldErrors` | 입력 검증 실패일 때만 넣는다. `[{ "field": "title", "code": "REQUIRED", "params": { "max": 200 } }]` |
| `header.traceId` | 실패일 때 넣는다. 로그와 맞춰 볼 요청 ID로, 응답 헤더 `X-Request-Id`와 같다 |
| `result` | 단건이면 객체, 목록이면 배열, 돌려줄 것이 없거나 실패면 `null` |
| `totalCount` | 페이지 목록일 때만 넣는다. 조건에 맞는 전체 개수 |

**단건**
```json
{ "header": { "isSuccessful": true, "resultCode": "OK", "resultMessage": "" },
  "result": { "id": 123, "title": "첫 글", "visibility": "PUBLIC", "createdAt": "2026-10-06T04:24:19Z" } }
```

**목록(페이지)**: `?page=0&size=20`
```json
{ "header": { "isSuccessful": true, "resultCode": "OK", "resultMessage": "" },
  "result": [ { "id": 123, "title": "첫 글" } ],
  "totalCount": 135 }
```
- `page`는 0부터 센다. `size`는 기본 20, 최대 50이고, 넘으면 50으로 줄인다. 전체 페이지 수는 front가 `totalCount`로 계산한다.
- 정렬은 `sort=createdAt,desc`로 받는다. 허용한 필드만 받고, 나머지는 400 `VALIDATION_FAILED`를 준다.

**목록(커서)**: 무한 스크롤(포털 피드 등)은 전체 개수를 세지 않는다. `totalCount` 대신 `nextCursor`를 준다.
```json
{ "header": { ... }, "result": [ ... ], "nextCursor": "eyJpZCI6MTIzfQ" }
```
다음이 없으면 `nextCursor`는 `null`이다.

**생성**: 201과 `Location: /api/v1/posts/123`을 주고, `result`에 생성된 자원을 넣는다.

**본문 없는 성공**(삭제, 로그아웃 등): 204 대신 200을 주고 `result: null`을 넣는다. front가 모든 응답을 같은 방식으로 읽게 하기 위해서다.

**실패**
```http
HTTP/1.1 404 Not Found
```
```json
{ "header": { "isSuccessful": false, "resultCode": "POST_NOT_FOUND", "resultMessage": "Post not found: 123",
              "traceId": "4bf92f3577b34da6" },
  "result": null }
```
```json
{ "header": { "isSuccessful": false, "resultCode": "VALIDATION_FAILED", "resultMessage": "Validation failed",
              "fieldErrors": [ { "field": "title", "code": "REQUIRED", "params": {} },
                               { "field": "handle", "code": "TOO_LONG", "params": { "max": 20 } } ],
              "traceId": "4bf92f3577b34da6" },
  "result": null }
```
- 운영(prod)에서는 `resultMessage`에 내부 정보(SQL, 스택, 다른 사람의 데이터)를 넣지 않는다.
- 구현: 응답 record `ApiResponse<T>(Header header, T result, Long totalCount, String nextCursor)`(null 필드는 직렬화하지 않음)와 `@RestControllerAdvice` 하나로 만든다. 컨트롤러는 `ApiResponse.ok(...)`를 돌려주거나 예외(`BusinessException(ErrorCode)`)만 던진다.
- 예외 경로: 이미지(`/media/**`)와 피드(RSS·Atom), 트랙백 핑은 각 표준 형식(바이너리, XML)을 그대로 쓴다.

## 5. 상태 코드

| 코드 | 쓰는 때 |
|---|---|
| 200 / 201 / 202 | 3·4절. 204는 쓰지 않는다 |
| 400 `VALIDATION_FAILED` | 형식·필수값·범위 검증 실패 |
| 401 | 로그인이 필요하거나 토큰이 만료됨 |
| 403 | 로그인은 했지만 권한이 없음(남의 글 수정 등), CSRF(`ORIGIN_NOT_ALLOWED`) |
| 404 | 없음. **볼 권한이 없는 비공개 자원도 404**로 존재를 숨긴다. 관리자 API에 관리자가 아닌 요청도 404 |
| 409 | 현재 상태와 충돌(중복 주소, 동시 수정, 한도 초과) |
| 413 / 415 | 파일 크기·형식 |
| 422 | 형식은 맞지만 업무 규칙 위반(예약된 주소, 깊이 제한) |
| 423 | 계정 잠금 |
| 429 | 요청 한도 초과. `Retry-After` 헤더를 준다 |
| 500 | 예상하지 못한 오류. `resultCode: INTERNAL_ERROR`, 상세는 로그에만 남긴다 |

## 6. 조회 조건

- 필터는 필드 이름 그대로 쓴다: `?status=PUBLISHED&category=12&tag=java`
- 검색어는 `q`로 받는다.
- 여러 값은 쉼표로 받는다: `?status=DRAFT,SCHEDULED`
- 언어는 `?lang=`보다 쿠키·회원 설정·`Accept-Language`를 먼저 본다. 공개 문서(약관, 릴리스 노트)처럼 언어판을 고르는 경우에만 `lang`을 쓴다.

## 7. 동시성·멱등

- 여러 사람이 고칠 수 있는 자원은 낙관적 잠금을 쓴다. 요청에 `baseRevisionNo`(또는 `version`)를 넣고, 다르면 409 `*_CONFLICT`를 준다.
- 재시도해도 안전해야 하는 생성 요청(결제가 없으므로 지금은 해당 없음)에는 나중에 `Idempotency-Key` 헤더를 쓴다.

## 8. 보안·캐시

- 인증은 `access_token` HttpOnly 쿠키로 한다. `Authorization` 헤더는 쓰지 않는다.
- 상태를 바꾸는 요청은 `Origin`을 검사한다(R27).
- 로그인이 필요한 응답에는 `Cache-Control: no-store`를 준다. 공개 이미지·썸네일만 긴 캐시를 쓴다.
- 응답에 비밀번호 해시, 암호문, 이메일 해시, 내부 토큰을 넣지 않는다. 엔티티를 그대로 직렬화하지 않고 응답 record(DTO)를 만든다.

## 9. 문서와 버전

- 각 스펙의 `contracts/api.md`가 기준이다. 구현 후 springdoc OpenAPI(`/v3/api-docs`)와 일치해야 한다. front 타입은 OpenAPI에서 생성한다.
- 호환이 깨지는 변경(필드 삭제·이름 변경·의미 변경)은 `/api/v2`에서만 한다. 필드 추가는 v1 안에서 해도 된다. front는 모르는 필드를 무시한다.
