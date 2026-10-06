# Data Model: 멀티 유저 블로그 플랫폼 MVP

DB: MySQL 8, utf8mb4, 모든 시간은 UTC `DATETIME(6)`. PK는 `BIGINT AUTO_INCREMENT`. 공통 컬럼 `created_at`, `updated_at`.

## users
| 컬럼 | 타입 | 제약 / 규칙 |
|---|---|---|
| id | BIGINT | PK |
| email | VARCHAR(255) | UNIQUE, 소문자로 정규화 (FR-001) |
| password_hash | VARCHAR(100) | BCrypt (FR-003) |
| nickname | VARCHAR(30) | 필수 |
| bio | VARCHAR(300) | |
| profile_image_url | VARCHAR(500) | |
| role | VARCHAR(10) | USER / ADMIN |
| status | VARCHAR(10) | ACTIVE / SUSPENDED / WITHDRAWN |
| failed_login_count | INT | 기본 0 (FR-007) |
| locked_until | DATETIME(6) | NULL 가능 |
| withdrawn_at | DATETIME(6) | |

상태 전이: ACTIVE ↔ SUSPENDED(관리자), ACTIVE → WITHDRAWN(본인, 되돌릴 수 없음). WITHDRAWN 전이 시 그 회원의 모든 글 visibility=PRIVATE, 모든 리프레시 토큰 무효화(FR-009).

## refresh_tokens
| 컬럼 | 타입 | 제약 |
|---|---|---|
| id | BIGINT | PK |
| user_id | BIGINT | FK users |
| family_id | CHAR(36) | 한 번의 로그인에서 이어진 토큰 묶음(UUID) |
| token_hash | CHAR(64) | UNIQUE, SHA-256 |
| expires_at | DATETIME(6) | 발급 + 4시간(유휴 만료) |
| family_expires_at | DATETIME(6) | family 최초 발급 + 7일(절대 만료) |
| used_at | DATETIME(6) | 교체되어 사용 처리된 시각 |
| replaced_by_id | BIGINT | 교체로 새로 발급된 토큰 |
| revoked_at | DATETIME(6) | 로그아웃·재사용 감지·정지·탈퇴 시 설정 |

## blogs
| 컬럼 | 타입 | 제약 |
|---|---|---|
| id | BIGINT | PK |
| user_id | BIGINT | FK users, UNIQUE (FR-010) |
| handle | VARCHAR(20) | UNIQUE, 규칙·예약어 검사, 변경 불가 (FR-002) |
| title | VARCHAR(100) | 기본값 "{닉네임}의 블로그" |
| description | VARCHAR(500) | |
| cover_image_url | VARCHAR(500) | |
| comment_enabled | BOOLEAN | 기본 true (FR-029) |

## categories
| 컬럼 | 타입 | 제약 |
|---|---|---|
| id | BIGINT | PK |
| blog_id | BIGINT | FK blogs |
| parent_id | BIGINT | FK categories, NULL=상위. 부모의 parent_id는 NULL이어야 함(2단계, FR-023) |
| name | VARCHAR(50) | 같은 부모 아래 UNIQUE |
| sort_order | INT | |

삭제 시 소속 글의 category_id를 NULL(=미분류)로 변경, 하위 카테고리가 있으면 하위의 글도 미분류로 옮기고 하위 카테고리도 삭제(FR-024).

## posts
| 컬럼 | 타입 | 제약 |
|---|---|---|
| id | BIGINT | PK, 글 주소의 글번호 |
| blog_id | BIGINT | FK blogs |
| category_id | BIGINT | FK categories, NULL=미분류 |
| title | VARCHAR(200) | 필수 |
| content_md | MEDIUMTEXT | 원문 Markdown |
| content_html | MEDIUMTEXT | 변환·살균된 HTML (FR-021) |
| content_text | MEDIUMTEXT | 태그 제거 텍스트, FULLTEXT ngram |
| summary | VARCHAR(300) | content_text 앞 150자, 메타 description |
| thumbnail_url | VARCHAR(500) | 본문 첫 이미지 |
| visibility | VARCHAR(10) | PUBLIC / PRIVATE (FR-015) |
| status | VARCHAR(10) | DRAFT / PUBLISHED / DELETED / HIDDEN |
| view_count, like_count, comment_count | INT | 비정규화 카운터 |
| published_at | DATETIME(6) | 최초 발행 시각 |

인덱스: (blog_id, status, visibility, published_at DESC), (category_id), FULLTEXT(title, content_text) WITH PARSER ngram.

"공개 노출 가능" 조건(모든 목록·검색·피드·사이트맵·RSS 공통, FR-018):
`status = PUBLISHED AND visibility = PUBLIC AND 작성자 users.status = ACTIVE`. 이 조건은 리포지토리 한 곳의 공통 스펙/쿼리 조각으로만 표현한다.

상태 전이: DRAFT → PUBLISHED(발행), PUBLISHED ↔ DRAFT 불가, PUBLISHED/DRAFT → DELETED(주인), PUBLISHED → HIDDEN(관리자), HIDDEN → PUBLISHED(관리자 복구).

## tags / post_tags
- tags: id, name VARCHAR(30) UNIQUE(소문자·앞뒤 공백 제거로 정규화), FULLTEXT 불필요.
- post_tags: (post_id, tag_id) PK. 글당 최대 10개(서비스 검증, FR-025).

## comments
| 컬럼 | 타입 | 제약 |
|---|---|---|
| id | BIGINT | PK |
| post_id | BIGINT | FK posts |
| user_id | BIGINT | FK users |
| parent_id | BIGINT | NULL=댓글, 값=답글. 부모의 parent_id는 NULL이어야 함(1단계, FR-027) |
| content | VARCHAR(1000) | 일반 텍스트 |
| status | VARCHAR(10) | ACTIVE / DELETED / HIDDEN |

답글이 있는 댓글을 삭제하면 "삭제된 댓글입니다"로 자리만 남긴다.

## post_likes
(user_id, post_id) PK, created_at. 생성·삭제 시 posts.like_count와 post_daily_stat.likes 갱신 (FR-030).

## subscriptions
(subscriber_id, blog_id) PK, created_at. subscriber의 블로그와 blog_id가 같으면 거부 (FR-031).

## notifications
id, user_id(받는 사람), type(COMMENT / REPLY / SUBSCRIBE), actor_id, target_id, read_at, created_at (FR-033).

## post_daily_stat
(post_id, stat_date) PK, views INT, likes INT. 인기 글 계산용 (FR-034).

## media
id, owner_id, post_id(NULL 가능), stored_path VARCHAR(300), mime VARCHAR(20), size_bytes INT (FR-038, FR-039).

## reports
id, reporter_id, target_type(POST / COMMENT), target_id, reason(SPAM / ABUSE / ADULT / COPYRIGHT / ETC), detail VARCHAR(500), status(PENDING / ACCEPTED / REJECTED), handled_by, handled_at. 같은 사람이 같은 대상을 중복 신고하면 거부 (FR-040, FR-041).
