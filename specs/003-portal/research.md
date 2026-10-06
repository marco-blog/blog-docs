# Research: 003 포털

> 001 research R10의 인기 글 부분(003 FR-034·086)을 이 문서의 P4로 옮겨 확정했다(001 research 머리말). 001 문서의 해당 절은 그대로 두며, 내용이 다르면 이 문서가 우선한다.
>
> 001의 결정(R1~R28: 인증, 프록시, SSR 구성, 노출 조각 `PostExposure`, 테스트 방식, 정기 작업, 보안 헤더, 다국어)과 002의 결정(D1~D11)은 그대로 따른다. 모든 API 경로는 `/api/v1` 접두어를 쓴다([contracts/api.md](./contracts/api.md)).

확인일: 2026-10-06 (blog-backend·blog-front main 기준. 002 Phase 5~8은 `feat/002-rest`에서 구현 중이며 002 tasks.md를 기준으로 참조)

## P1. 포털 노출 조각 (FR-088, SC-004)
- **Decision**:
  - `blog-backend/.../portal/repository/PortalExposure.java`에 QueryDSL 조각 하나를 둔다.
    ```
    portalVisible(c) = PostExposure.bodyVisible()                      // 001 "본문 노출 가능"(보호 글 제외)
                       AND blog.portalEnabled = true                     // FR-089
                       AND NOT EXISTS (portal_exclusions WHERE post_id = post.id)   // FR-093
                       AND user.createdAt <= c.now - c.newMemberDelay    // 가입 24시간(회원 가입 시각 기준)
                       AND length(post.contentText) >= c.minContentLength // 본문 텍스트 200자
    ```
    `c`(`PortalCriteria`)는 요청 시각과 운영 설정값(P3)을 묶은 값이다. 쿼리는 001처럼 `from(post).join(post.blog, blog).join(blog.user, user)`로 시작한다.
  - 이미 읽은 글 한 편의 판단(추천 지정 검증, 관리자 "포털 노출 여부" 표시)은 같은 규칙의 자바 메서드 `PortalExposure.evaluate(Post, PortalCriteria, boolean excluded)`가 하며, 만족하지 않는 이유 목록(`NOT_BODY_VISIBLE`, `BLOG_PORTAL_DISABLED`, `EXCLUDED`, `NEW_MEMBER`, `TOO_SHORT`)을 돌려준다. 두 구현이 같은지는 `PortalExposureRepositoryTest`가 같은 픽스처로 확인한다.
  - 길이는 문자 수(`CHAR_LENGTH`)다. QueryDSL `stringExpr.length()`는 Hibernate `length()`→ MySQL `CHAR_LENGTH`, H2 `LENGTH`(문자 수)로 바뀐다.
  - 모든 포털 목록(추천, 인기, 최신, 주제 페이지, 인기 태그, 새 블로그, 주제별 글 수)은 이 조각만 쓴다. 외부 글(007)은 이 조각을 쓰지 않고 007 FR-123을 따른다.
- **Rationale**: 001이 노출 규칙을 한 곳(`PostExposure`)에 둔 방식을 그대로 확장한다(원칙 IV). 조건값이 운영 중 바뀌므로 상수가 아니라 인자로 받는다.
- **Alternatives**: `posts.content_text_length` 컬럼 추가(스키마 변경, 5분 캐시가 있어 이득이 작음), 조건을 뷰(view)로(Crowfoot·H2 양쪽 관리 부담).

## P2. 주제 (FR-075~079, FR-147)
- **Decision**:
  - 초기 목록: `blog-backend/src/main/resources/portal/topics-seed.json`(대분류 5개, 소분류 39개, 각 slug·4개 언어 이름·순서, 대분류 카드 색)을 `TopicSeeder`(`ApplicationRunner`)가 기동 때 넣는다. slug가 이미 있으면 건너뛰고(멱등), 운영자가 바꾼 이름·순서·숨김은 덮어쓰지 않는다(db/README "초기 데이터"). 4개 언어 이름이 모두 없으면 기동을 멈춘다(`TopicSeedTest`).
  - slug(주소용 영문 식별자, 서비스 전체 유일):

    | 대분류 slug | 소분류 slug |
    |---|---|
    | `life` 라이프 | `daily-thoughts`, `parenting-marriage`, `pets`, `fashion-beauty`, `interior-diy`, `cooking-recipe`, `product-review`, `gardening` |
    | `travel-food` 여행·맛집 | `domestic-travel`, `overseas-travel`, `camping-hiking`, `restaurants`, `cafe-dessert` |
    | `culture` 문화·연예 | `tv`, `stars`, `movies`, `music`, `books`, `comics-animation`, `shows-exhibitions-festivals`, `creative-works` |
    | `sports` 스포츠 | `soccer`, `baseball`, `basketball`, `volleyball`, `golf`, `general-sports` |
    | `knowledge` 지식·동향 | `it-internet`, `mobile`, `science`, `it-product-review`, `business-work`, `economy`, `society`, `politics`, `education`, `health-medicine`, `history`, `foreign-languages` |

    spec의 예(`/topics/knowledge/it-internet`)와 맞춘다. 출시 전 티스토리 현행 목록과 대조해 확정하는 일(FR-075)은 marco의 운영 작업이며, 바뀌면 seed 파일만 고친다(이미 넣은 행은 콘솔에서 고친다).
  - 카드 색: 대분류만 seed에 넣는다(`life #F2A541`, `travel-food #3FA796`, `culture #8E6CCB`, `sports #E2574C`, `knowledge #3D7DD8`). 소분류는 NULL이며 대분류 색을 쓴다(data-model).
  - 출시 초기 탭 고정(FR-147 "IT·개발 관련 소분류부터"): seed가 `it-internet`, `mobile`, `it-product-review`의 `pinned_on_tab = true`로 넣는다(처음 넣을 때만).
  - 주제 탭 판단(FR-147, 저장하지 않음): 소분류는 `!adminHidden(자신·부모) AND (pinnedOnTab OR 최근 30일 포털 노출 글 수 >= threshold)`이면 탭에 보인다. 대분류는 숨김이 아니고 `(자신 pinnedOnTab OR 소속 소분류 합계 >= threshold OR 탭에 보이는 소분류가 하나라도 있음)`이면 메인 주제 탭에 보인다. 대분류 페이지의 소분류 목록도 같은 판단으로 거른다. 글 수는 `PortalExposure` + `published_at >= now - 30일`을 소분류별 `GROUP BY` 한 번으로 세고 포털 캐시(P5)로 5분 둔다.
  - 공개 주제 API `GET /topics`는 운영자 숨김이 아닌 주제 트리(4개 언어 이름 모두, 카드 색, `onTab`)를 준다. 화면 언어 이름 고르기는 front가 한다(주제 수가 40여 개라 응답이 작고, 언어별 캐시가 필요 없다).
  - 글·블로그 기본 주제는 소분류만(`parent_id IS NOT NULL`), 운영자 숨김이 아닌 것(부모 숨김 포함)만 새로 고를 수 있다. 이미 고른 주제가 나중에 숨겨지면 값은 그대로 두고 주제 페이지에만 나오지 않는다(data-model). 같은 값으로 다시 발행하는 것은 허용한다.
- **Rationale**: 주제는 서비스 기준 데이터라 SQL 파일이 아니라 멱등 초기화 코드로 넣는다(db/README). 탭 판단을 저장하지 않으면 운영자가 기준값을 바꿔도 바로 반영된다.
- **Alternatives**: 주제 이름을 front 번역 파일에 두기(FR-079가 운영자가 4개 언어로 입력하도록 정함), 자동 숨김을 정기 작업으로 저장(저장값과 기준 변경이 어긋남).

## P3. 운영 설정값 (FR-086, FR-088, FR-147, 006 FR-102)
- **Decision**:
  - `setting` 패키지의 `SettingKey` enum이 키·값 형식·기본 프로퍼티를 정한다. 003 키는 `portal.score-weights`(객체), `portal.new-member-delay`(ISO-8601 기간 문자열), `portal.min-content-length`(정수 0~10000), `portal.topic-auto-hide-threshold`(정수 0~1000). 005·007은 enum에 값을 더한다.
  - `SystemSettingsService.get(SettingKey)`는 `system_settings` 행을 읽고 없으면 `blog.portal.*` 프로퍼티(`PortalProperties`)를 쓴다. 전체 행을 메모리에 캐시하고(`AtomicReference<Map>`), 관리자가 바꾸면 같은 트랜잭션 커밋 뒤 캐시를 비우고 포털 캐시(P5)도 비운다.
  - 인기 점수 가중치 기본값(data-model 예시를 확정): `{ "view": 1, "readComplete": 5, "like": 10, "comment": 8, "halfLifeHours": 48, "reportPenalty": 0.5 }`. 각 값은 0 이상(가중치 0~1000, `halfLifeHours` 1~720, `reportPenalty` 0~1).
  - 관리자 API는 `GET /admin/settings?prefix=portal.`와 `PUT /admin/settings/{key}` `{ value }`. 형식이 틀리면 400 `VALIDATION_FAILED`(field `value`), 모르는 키는 404 `SETTING_NOT_FOUND`. 바꾸면 006 FR-106 작업 기록 `SETTING_CHANGE`(`target_type=SETTING`, `target_key`=키, 전후 값). 기본값으로 되돌리기는 `DELETE /admin/settings/{key}`(행 삭제).
- **Rationale**: data-model이 "값이 없으면 같은 의미의 프로퍼티가 기본값"으로 정했다. 키 목록을 코드에 두면 알 수 없는 키를 막을 수 있다.
- **Alternatives**: 프로퍼티만 사용(FR-086·088이 운영자 변경을 요구), 키별 전용 테이블(005·007이 키를 더할 때마다 스키마 변경).

## P4. 인기 점수 (FR-086) — 001 R10 인기 글 부분을 옮겨 확정
- **Decision**:
  - 신호(최근 7일 = `now - 7일` 이후, 일별 통계는 `stat_date >= today - 6`):
    - 조회 `v` = Σ `post_daily_stats.views`, 끝까지 읽음 `r` = Σ `post_daily_stats.read_completes`
    - 좋아요 `l` = `post_likes` 중 `created_at >= now - 7일` 수, 댓글 `c` = `comments` 중 `created_at >= now - 7일`이고 삭제·숨김이 아닌 수
  - 점수 = `(w.view·v + w.readComplete·r + w.like·l + w.comment·c) × 2^(-age / halfLifeHours) × penalty(blog)`. `age`는 발행 후 시간(시간 단위), `penalty`는 `BlogPenaltyPolicy`가 주는 값(1 또는 `reportPenalty`). 조회 가중치를 가장 낮게 두어 "클릭 수만으로 정하지 않는다"를 지킨다.
  - 계산: `PopularityCalculator`가 위 네 집계를 각각 `GROUP BY post_id` 쿼리 1회로 읽고(쿼리 4회 + 후보 글의 발행 시각·블로그·주제 1회), 점수 > 0인 포털 노출 글을 `PopularitySnapshot`(글 id, 블로그 id, 주제 id, 점수, 발행 시각; 점수 내림차순)으로 만든다. 스냅숏은 포털 캐시(P5)에 한 항목으로 두어 5분마다 다시 만든다. 점수 자체는 저장하지 않는다(data-model).
  - 감점(`BlogPenaltyPolicy`): 신고·숨김 데이터는 005가 만든다. 003은 인터페이스와 "감점 없음"(항상 1.0) 기본 구현만 두고, 005가 `reports`(ACTIONED, `target_blog_id`)·숨김 이력으로 구현을 바꾼다(결정 표 9번).
  - 메인 인기 글: 스냅숏 앞에서부터 같은 블로그 2편까지(FR-080) 12편. 주제 페이지 인기순: 스냅숏을 주제로 거른 순서(점수 > 0인 글만, 결정 표 11번).
  - 조회 일별 집계: 001 `ViewCountService.record`가 조회수를 올리는 같은 트랜잭션에서 `INSERT INTO post_daily_stats (post_id, stat_date, views, read_completes) VALUES (?, ?, 1, 0) ON DUPLICATE KEY UPDATE views = views + 1`(네이티브, H2 MySQL 모드도 지원). 날짜는 UTC.
  - 끝까지 읽음: 새 API `POST /posts/{id}/read-complete`(비로그인 허용, Origin 검사). 상세를 볼 수 있는 글만(아니면 404), 같은 방문자 키(회원 ID 또는 방문자 쿠키, 001 R10)로 30분(`blog.posts.view-dedup-ttl`) 안에 다시 오면 세지 않는다(같은 Caffeine 방식, 별도 캐시). front는 글 상세 본문 끝의 감시 요소가 화면에 들어오면 한 번 보낸다(`IntersectionObserver`). JS가 없으면 보내지 않는다(받아들인 한계).
  - 보관: `PostStatsPurgeJob`(`blog.jobs.post-stats-purge-cron` 기본 `0 45 4 * * *`)이 `stat_date < today - 90일` 행을 건수 단위로 지운다.
- **Rationale**: 001 R10이 "결과를 Caffeine에 5분 캐시"를 이미 정했다. 감쇠는 반감기 하나로 표현해 운영자가 조정하기 쉽다. 일별 통계는 이미 스키마에 있다.
- **Alternatives**: 조회수만(FR-086 위반), 점수 테이블과 정기 배치(스키마·작업 증가), Hacker News식 `(age+2)^gravity`(조정 값이 직관적이지 않음).

## P5. 포털 캐시와 반영 시간 (FR-090, SC-012, SC-013)
- **Decision**:
  - `PortalCache`: Caffeine `expireAfterWrite = blog.portal.cache-ttl`(기본 5m), 최대 항목 2,000. 항목은 메인 묶음(`HOME`), 최신 글 커서 페이지(`LATEST:{cursor}`), 주제 글 페이지(`TOPIC:{id}:{sort}:{page}`), 인기 점수 스냅숏, 주제별 최근 30일 글 수. 값은 DTO(엔티티 아님)이다.
  - 5분 TTL이므로 글의 발행·수정·비공개 전환·삭제·숨김·회원 정지·블로그 포털 끄기는 최대 5분 뒤 모든 영역에 반영된다(FR-090). 운영자의 포털 제외·추천·주제 변경·설정 변경은 커밋 후 `PortalCache.invalidateAll()`로 즉시 반영한다(006 Acceptance "바로 반영").
  - `blog.portal.cache-ttl=0s`이면 캐시를 쓰지 않는다(E2E·통합 테스트용).
  - HTTP 캐시는 두지 않는다(기본 `no-store` 유지). 응답은 사람마다 같지만 SSR HTML에는 로그인 상단이 섞이고, 서버 캐시로 충분하다.
- **Rationale**: 001 R10의 5분 캐시를 포털 전체로 넓혔다. backend 1대 전제(001 R26)에서 프로세스 안 캐시로 충분하다.
- **Alternatives**: 글 상태 변경 이벤트로 항목별 무효화(이벤트 지점이 001·002·004·005 곳곳에 흩어짐, 5분 허용이므로 불필요), Redis(실행 파트·인프라 추가).

## P6. 메인 영역과 같은 블로그 2편 제한 (FR-034, FR-080, FR-087, SC-014)
- **Decision**:
  - `GET /portal` 한 번으로 메인 영역을 모두 준다: `curations`(최대 5), `popular`(12), `latest`(20 + `nextCursor`), `popularTags`(20), `newBlogs`(6). 주제 탭은 `GET /topics`의 `onTab`으로 그린다. 릴리스 노트 카드는 001 contracts대로 `GET /release-notes`의 `portalCard`.
  - 같은 블로그 2편 제한은 영역마다 자바에서 적용한다(`PerBlogCap`): 후보를 넉넉히 읽어(`limit × 5`, 최대 200) 순서대로 보며 블로그별 2편이 넘는 글을 건너뛴다. 추천 영역은 운영자가 고른 것이라 제한하지 않는다(최대 5편). 주제 페이지는 메인 영역이 아니므로 제한하지 않는다(FR-080 "메인의 각 영역").
  - 최신 글 "더 보기"는 커서 방식(api-guidelines 4절 "포털 피드"): `GET /portal/latest?cursor=`. 커서는 마지막으로 **살펴본** 행의 `(published_at, id)`를 base64url로 감싼 값이다. 2편 제한으로 건너뛴 글은 다음 묶음에도 나오지 않는다(한 화면 안의 제한을 지키면서 커서를 단순하게, 결정 표 10번). 묶음마다 2편 제한을 새로 센다.
  - 인기 태그: 최근 7일 발행된 포털 노출 글의 태그를 `COUNT` 내림차순, 같으면 이름순 20개. 누르면 001 서비스 전체 태그 화면(`/tags/{name}`).
  - 새로 시작한 블로그: `first_published_at >= now - 30일`, 블로그 ACTIVE·주인 ACTIVE·`portal_enabled`, 포털 노출 글이 1편 이상인 블로그를 `first_published_at` 내림차순 6개. `first_published_at`은 발행 트랜잭션에서 NULL일 때만 채운다(`Blog.markFirstPublished`, 삭제해도 되돌리지 않음, data-model).
  - 추천: 지금 기간 안(`starts_at <= now < ends_at`)이고 포털 노출 조건을 만족하는 행을 `sort_order`, `id` 순으로. 조건을 잃은 글은 화면에서만 빠진다(FR-092).
  - 빈 영역은 응답에서 빈 배열이고 front가 숨긴다. 모든 영역이 비면 "첫 글을 써 보세요" 안내(Edge Cases).
- **Rationale**: 한 API로 메인을 그리면 SSR loader가 단순하고 캐시 항목 하나로 묶인다. 2편 제한을 SQL 윈도 함수로 하면 H2·MySQL 차이와 쿼리 복잡도가 커진다.
- **Alternatives**: 영역별 API 6개(loader 호출 증가), `ROW_NUMBER() OVER (PARTITION BY blog_id)`(H2 호환은 되지만 페이지·커서와 함께 쓰기 어려움), 건너뛴 글을 다음 묶음에 다시 넣기(커서가 두 개 필요).

## P7. 글 카드 (FR-085)
- **Decision**: `PortalCard` = `{ id, title, summary, thumbnailUrl, topicId, blog: { handle, title }, author: { nickname, profileImageUrl }, publishedAt, likeCount, commentCount }`. 한 쿼리의 DTO projection(post + blog + user + 프로필 media LEFT JOIN, 002 `SubscriptionFeedQueryRepository`와 같은 방식)으로 읽는다. 쿼리 수는 카드 수와 무관하다.
  - 대표 이미지가 없으면 front가 `topicId`의 카드 색(소분류 NULL이면 대분류, 주제 없으면 기본 회색 `#9AA0A6`)으로 기본 이미지를 그린다(Edge Cases).
  - 요약 2줄은 front CSS(`line-clamp: 2`)로 자른다. 상대 시각("3시간 전")은 front가 `Intl.RelativeTimeFormat`으로 만들며, SSR과 브라우저가 같은 결과를 내도록 loader가 서버 시각(`now`)을 함께 넘긴다.
  - 썸네일 주소는 001 `/media/{key}/600x400`(카드 300x200의 2배) 규칙을 front가 붙인다.
- **Rationale**: 001 PostSummary에 없는 블로그·작성자·좋아요를 한 번에 담아야 한다. 주제 이름은 `GET /topics`에서 이미 받은 트리로 찾으므로 카드에 넣지 않는다.

## P8. 주제 페이지 (FR-078, FR-094)
- **Decision**:
  - `GET /topics/{slug}/posts?sort=latest|popular&page=&size=` (slug는 서비스 전체 유일이라 대분류·소분류 모두 이 경로). 대분류는 소속 소분류(운영자 숨김 소분류 제외) 글 전체, 소분류는 그 글만. 운영자 숨김 주제(부모 숨김 포함)는 404 `TOPIC_NOT_FOUND`. 자동 숨김(FR-147)은 영향 없음.
  - 최신순: `PortalExposure` + `topic_id IN (...)` + `published_at DESC, id DESC`, 페이지(`page`·`totalCount`, 20편). 인기순: 스냅숏(P4)을 주제로 거른 목록의 페이지.
  - front 주소 `/topics/:major/:minor`는 `GET /topics` 트리로 소분류의 부모가 `:major`인지 확인하고 아니면 404(대분류 slug 자리에 소분류를 넣은 주소 포함).
  - SSR meta: 제목 `{주제 이름} - {서비스명}`, 설명 `portal:topic.description`(주제 이름 보간), `og:title`·`og:description`·`og:url`, canonical(정렬·페이지 쿼리 제외, `page>0`은 `?page=`를 포함한 자기 주소). 인기순은 `noindex`(같은 글의 다른 순서).
  - 사이트맵(002 `SitemapService`의 `pages.xml`, 002 T071): 운영자 숨김이 아닌 대분류·소분류 페이지 주소를 더한다. `lastmod`는 넣지 않는다.

## P9. 글에 주제 지정과 블로그 포털 설정 (FR-076, FR-077, FR-089)
- **Decision**:
  - `DraftWrite`에 `topicId`(작성 중 사본 `post_drafts.topic_id`, 외래 키 없음, 저장 때 검증하지 않음), `PublishSettings`에 `topicId`. 발행 때의 값은 001 카테고리(T169)와 같은 규칙: 발행 설정에 값이 있으면 그것, 없으면(null) 작성 중 사본의 값, 사본이 없으면 지금 발행본의 값. "선택 안 함"은 front가 발행 설정 레이어에서 바꿀 때 작성 중 사본을 `topicId: null`로 저장해서 표현한다(카테고리와 같음).
  - 발행 때 검증: 값이 지금 발행본의 주제와 같으면 통과(나중에 숨겨진 주제 유지). 다르면 존재(아니면 404 `TOPIC_NOT_FOUND`), 소분류이고 운영자 숨김 아님(부모 포함, 아니면 422 `TOPIC_NOT_SELECTABLE`). 검증은 글을 바꾸기 전에 한다.
  - 블로그 기본 주제: `PATCH /blogs/{handle}`에 `defaultTopicId`(Merge Patch, null이면 지움, 같은 검증)와 `portalEnabled`(null 불가), `GET /blogs/{handle}`에 두 값. 새 글 작성 화면은 새 사본을 만들 때 블로그의 `defaultTopicId`를 `DraftWrite.topicId`로 넣어 미리 선택한다(backend는 자동으로 채우지 않는다). 발행된 글을 고칠 때는 그 글의 주제를 보여준다.
  - `GET /posts/{id}/draft`(작성 화면 불러오기)와 `PostDetail`에 `topicId`를 더한다(주인 화면이 현재 값을 알아야 함).
- **Rationale**: 001 카테고리와 같은 흐름이라 front·backend 모두 익숙한 코드를 재사용한다. POST 본문에서 "없음"과 "null"을 구분하는 새 도구가 필요 없다.

## P10. 운영자 큐레이션·제외·주제 관리 API (FR-079, FR-091~093)
- **Decision**:
  - 경로는 001 관리자 규칙(`/api/v1/admin/**`, 요청마다 DB role 재확인, 아니면 404 `NOT_FOUND`)을 그대로 쓴다. 001이 블로그 한도 API(`admin/user`)를 콘솔 화면 없이 먼저 만든 것처럼, 003은 주제·포털 관리 API와 그 화면(006 FR-102의 003 메뉴)을 만든다.
  - 추천: 만들 때 글이 포털 노출 조건을 만족해야 한다(아니면 422 `POST_NOT_PORTAL_ELIGIBLE`). `ends_at > starts_at`(아니면 400). 기간이 겹치는 추천이 이미 5개면 409 `CURATION_LIMIT_EXCEEDED`(data-model "기간이 겹치는 행 수를 세어 검증"; 겹치는 행 수로 보수적으로 센다). 관리자 동시 저장 경합은 드물어 잠금을 두지 않는다(결정 표 13번). 수정은 기간·순서만, 삭제는 행 삭제(지난 행은 이력으로 남기되 운영자가 지울 수 있음).
  - 포털 제외: `PUT /admin/portal/exclusions/{postId}` `{ reason }`(1~500자)으로 만들거나 사유를 바꾼다(멱등). 글 상태와 관계없이 제외할 수 있다(없는 글만 404). 해제는 `DELETE`(행 삭제, 이력은 작업 기록).
  - 주제: 추가(소분류는 대분류 아래만, 아니면 422 `TOPIC_DEPTH_EXCEEDED`; slug 중복 409 `TOPIC_SLUG_TAKEN`; 4개 언어 이름 필수), 수정(이름·카드 색·`adminHidden`·`pinnedOnTab`; slug는 요청에 없음 = 바꿀 수 없음), 순서(`PUT /admin/topics/order` `{ parentId, ids }`: 그 부모의 자식 전체를 새 순서로, 집합이 다르면 400). 부모를 옮기는 기능은 없다(주소가 바뀜). 삭제 API 없음(FR-079).
  - 모든 쓰기는 같은 트랜잭션에서 001 `AdminAuditService`로 작업 기록(006 data-model 동작 코드: `TOPIC_CREATE`, `TOPIC_UPDATE`, `TOPIC_REORDER`, `TOPIC_HIDE`, `TOPIC_UNHIDE`, `TOPIC_PIN`, `TOPIC_UNPIN`, `CURATION_CREATE`, `CURATION_UPDATE`, `CURATION_DELETE`, `PORTAL_EXCLUDE`, `PORTAL_UNEXCLUDE`, `SETTING_CHANGE`)을 남기고, 커밋 후 포털 캐시를 비운다(`@TransactionalEventListener(AFTER_COMMIT)`의 `PortalChangedEvent`).
  - 콘솔 화면에서 글을 고를 때 쓰는 `GET /admin/portal/posts/{id}`는 글 제목·블로그·포털 노출 여부와 이유(P1 `evaluate`)를 준다.
- **Rationale**: 006 spec 머리말과 헌법 개발 흐름 2번이 "시스템 관리자 콘솔 뼈대와 주제·큐레이션 메뉴는 003과 함께"로 정했다.

## P11. 릴리스 노트 읽기 (FR-161~166)와 관리 API
- **Decision**:
  - 독자 API는 001 contracts/api.md "릴리스 노트" 절을 그대로 구현한다. 관리 API(006 FR-167·168)도 001 contracts에 이미 정의되어 있으므로 003에서 backend만 만든다(US5 Independent Test가 관리자 게시를 전제로 하고, 화면은 006의 `/admin/release-notes/**`, 결정 표 4번). 저장 규칙은 006 data-model(낙관적 잠금 `current_revision_no`, 수정본 INSERT, 작업 기록)을 따른다.
  - 변환: `ReleaseNoteRenderer`가 001 `MarkdownRenderer`(commonmark + 동영상 변환)에 제목 앵커를 더한다. h2~h4에 `id`를 붙이고(규칙: 소문자 → 공백을 `-` → 문자·숫자·`-` 외 제거, 한글·한자·가나 유지 → 같은 노트 안 중복은 `-2`, `-3`), 같은 앵커로 `toc_json`(`[{level, text, anchor}]`)을 만든다. 살균은 001 정책에 "h2~h4의 `id`(앵커 형식 정규식)"만 더한 변형 정책(`HtmlSanitizerPolicy.releaseNotes()`)으로 하며 회원 글에는 쓰지 않는다. 저장할 때 `content_html`·`content_text`·`toc_json`을 함께 저장한다.
  - 언어판 고르기: 요청 `lang`(없으면 화면 언어 결정 규칙, 001 FR-149) → en → ko 중 처음 있는 언어판. 제목·본문은 한 언어판 단위로 대체한다(`lang`이 실제 언어판, `requestedLang`이 요청).
  - 버전 순서: `(version_major, version_minor, version_patch)` 숫자 정렬(`idx_release_notes_status_version`). 이전·다음은 게시 노트에서 바로 앞·뒤.
  - 포털 카드(FR-162): 가장 높은 버전의 게시 노트의 `first_published_at >= now - blog.release-notes.portal-card-days`(14d)이면 `portalCard`.
  - 배너(FR-163): `GET /me`의 `unseenReleaseNote`(001 contracts). 가장 높은 버전의 게시 노트가 `users.last_seen_release_version`보다 높고(NULL이면 높음), `first_published_at > users.created_at`이면 `{ version, title }`(화면 언어판). 계산은 노트 1회 + 언어판 1회 조회(노트가 없으면 1회). `POST /me/release-notes/seen` `{ version }`은 게시된 버전이어야 하며(아니면 404 `RELEASE_NOTE_NOT_FOUND`), 저장값보다 높을 때만 `UPDATE users SET last_seen_release_version = :new WHERE id = :id AND (last_seen_release_version <=> :old)`(읽은 값 기준 비교 후 갱신)으로 바꿔 동시에 두 요청이 와도 낮아지지 않는다. 버전 페이지를 연 로그인 회원은 SSR loader가 이 API를 부른다(배너 닫기와 같은 효과).
  - 게시 중단·삭제로 최신 노트가 바뀌면 카드·배너는 남은 게시 노트 중 최신 기준(Edge Cases). 저장값이 더 높은 버전을 가리켜도(게시 중단된 버전) 그보다 낮은 노트는 알리지 않는다.
  - 검색(FR-165): 게시 노트마다 고른 언어판 한 행에서만 `MATCH(title, content_text) AGAINST(? IN BOOLEAN MODE)`(002 `MySqlFullTextFunctions.matchTitleContent`와 같은 함수, 002 `SearchQueryParser`의 낱말 규칙 재사용, 2~100자). 구현은 ① 게시 노트의 (노트 id, 고른 언어) 목록을 읽고(노트 수십~수백) ② MATCH로 일치한 (노트 id, 언어) 행을 읽어 ③ 고른 언어와 같은 것만 남겨 버전 내림차순 페이지로 자른다. `snippet`은 `content_text`에서 첫 일치 낱말 앞뒤로 최대 160자. MySQL 전용이라 Repository 테스트는 `@MySqlRepositoryTest`.
  - 수정 이력(FR-166): `revision_no >= first_published_revision_no`인 수정본의 번호와 저장 시각만(관리자는 주지 않음). 수정본 내용은 `contents_json`에서 언어판을 같은 규칙으로 골라 저장 때와 같은 변환을 다시 한다(수정본에는 HTML을 저장하지 않으므로).
- **Rationale**: 001 contracts가 독자·관리 API 모양을 이미 정했다. 앵커 규칙도 001 contracts에 있다.
- **Alternatives**: 앵커를 front에서 붙이기(SSR HTML과 목차가 따로 계산되어 어긋날 수 있음, 001 contracts와 다름), 관리 API를 006으로 미루기(US5를 SQL로만 시험해야 함).

## P12. front 화면과 다국어 (원칙 V·VII)
- **Decision**:
  - 새 라우트: `/`(포털 메인으로 교체), `/topics/:major`, `/topics/:major/:minor`(한 모듈 `routes/topic.tsx`), `/updates`(레이아웃: 왼쪽 버전 트리·검색창, 오른쪽 `Outlet`), `/updates/:version`, `/updates/:version/history`, `/updates/:version/history/:revisionNo`, `/updates/seen`(배너 닫기 리소스 라우트, action만), `/admin`(콘솔 레이아웃) 아래 `topics`, `portal/curations`, `portal/exclusions`, `portal/settings`. 경로는 001 contracts/routes.md 기준 목록과 예약어(`topics`, `updates`, `admin`)에 이미 있다. `/updates/seen`·`/admin/portal/**` 세부는 이 스펙 routes.md에 적고 001 routes.md 표에 한 줄을 더한다.
  - 포털 메인 SSR loader: `GET /portal`, `GET /topics`, `GET /release-notes`를 병렬로 부르고, 하나가 실패해도 나머지 영역은 그린다(릴리스 노트·주제 실패 시 그 영역만 숨김, `/portal` 실패는 오류 화면). `?cursor=`가 있으면 그 커서의 최신 글 묶음을 함께 그린다(JS 없는 "더 보기", `noindex`·canonical `/`). JS가 있으면 "더 보기"는 `useFetcher`로 `/?index&cursor=`를 불러 이어 붙인다.
  - 공통 상단(FR-095): 002 T072의 검색창 + 001의 로그인·가입 / 글쓰기·내 블로그 링크를 그대로 쓰고, 포털 메인에 로그인 회원용 "구독 피드 보기"(`/feed`) 링크를 둔다(spec Assumptions).
  - 배너(FR-163): `root.tsx`가 `SessionUser.unseenReleaseNote`로 상단 아래에 한 줄(버전·제목·"보기" 링크·닫기 폼). 닫기는 `/updates/seen`에 `POST`(JS 없이 동작, 원래 화면으로 리다이렉트), JS가 있으면 `useFetcher`로 화면 이동 없이 숨긴다.
  - `/updates` 트리: `GET /release-notes`의 `items`를 front가 major.minor로 묶는다(`app/updates/versionTree.ts`, 새 버전이 위). 버전 본문은 SSR(`dangerouslySetInnerHTML` 허용 목록에 릴리스 노트 본문 추가 — 001 R27 ESLint 예외 목록과 `tests/unit/lint/noDanger.test.ts`). 목차는 응답 `toc`. 앵커 이동은 브라우저 기본 동작이라 JS 없이 된다. 대체 언어판이면 본문 위에 "이 노트는 {언어} 판입니다" 표시.
  - 관리자 콘솔 뼈대: `/admin/*`는 로그인 필요(비로그인 `/login?next=`), 세션 `role`이 ADMIN·SUPER_ADMIN이 아니면 404 화면, 실제 권한은 backend가 매 요청 확인. 좌측 메뉴는 003 메뉴(주제, 포털 추천, 포털 제외, 포털 설정)만 보이고 나머지는 006이 더한다(006 FR-102 "구현되지 않은 메뉴는 숨김"). `/admin`은 `/admin/topics`로 리다이렉트(대시보드는 006 FR-103).
  - 번역 namespace 3개를 새로 둔다: `portal`(메인 영역·카드·주제 페이지·빈 상태), `updates`(릴리스 노트 화면·배너·언어판 표시), `admin`(콘솔 레이아웃·주제·포털 관리). 글쓰기의 주제 선택은 `post`, 블로그 설정의 포털 항목은 `manage`, 상단 링크는 `common`에 더한다. 새 오류 코드는 `errors.json`과 `blog-front/app/api/errorCodes.ts`에 4개 언어로.
  - 응답 타입은 001·002처럼 `blog-front/app/api/models.ts`에 계약 문서를 옮겨 적는다.

## P13. 정기 작업과 프로퍼티
- **Decision**: 새 정기 작업은 `PostStatsPurgeJob` 하나(P4). 인기 점수·자동 숨김은 정기 작업이 아니라 캐시 만료 시 다시 계산한다. 새 프로퍼티는 contracts/api.md "프로퍼티" 표(`blog.portal.*`, `blog.jobs.post-stats-purge-cron`). 끝까지 읽음의 중복 판단은 조회수와 같은 `blog.posts.view-dedup-ttl`·`view-dedup-max-size`를 쓴다. `blog.release-notes.portal-card-days`는 001 contracts에 이미 있다.

## P14. 테스트 전략 (원칙 III)
- **Decision**:
  - Repository: `@JpaRepositoryTest`(H2)로 포털 노출 조각(노출 매트릭스 001 행 전부 + FR-088 조건 다섯 가지), 카드·최신 커서·주제 글·인기 태그·새 블로그·주제별 글 수·추천 기간·인기 신호 집계·`post_daily_stats` upsert·릴리스 노트 목록·이전/다음·수정 이력을 확인하고 모든 목록 쿼리에 `QueryCounter.assertQueryCount`를 둔다. `@MySqlRepositoryTest`는 릴리스 노트 FULLTEXT 검색과 `post_daily_stats` 동시 upsert(같은 글 20회 동시 → views 20)만.
  - Service: Mockito 단위(점수 공식·감쇠·가중치, 2편 제한, 커서 인코딩, 탭 판단, 주제 검증, 추천 겹침, 설정값 형식, 언어판 대체, 앵커 규칙, 마지막 확인 버전 비교). 시각은 `support/MutableClock`.
  - Controller: `@WebMvcTest` + `WebMvcTestSupport`로 상태 코드·공통 틀·커서 응답(`nextCursor`)·401/404/409/422, 관리자 API는 001 `AdminAccessWebMvcTest` 방식으로 일반 회원 404.
  - 통합(`@SpringBootTest`, H2, `blog.portal.cache-ttl=0s`): 노출 매트릭스와 FR-088 조건을 포털 메인·최신 커서·주제 페이지·인기 태그·새 블로그·추천에서 한 번에(SC-004·013), 관리자 제외 후 즉시 빠짐, 캐시가 켜져 있을 때 비공개 전환이 TTL 뒤 빠짐(`MutableClock` + Caffeine `Ticker`).
  - front: Vitest + Testing Library(각 라우트의 loader·action·meta·화면, 상대 시각, 트리 묶음, 카드 기본 이미지 색), Playwright E2E는 스토리별 Independent Test를 실제 backend로. E2E용 backend는 `BLOG_PORTAL_CACHE_TTL=0s`, `BLOG_PORTAL_NEW_MEMBER_DELAY=PT0S`, `BLOG_PORTAL_TOPIC_AUTO_HIDE_THRESHOLD=1`로 띄우고(quickstart), 그 설정이 필요한 시나리오는 `E2E_PORTAL_TEST_SETTINGS=1`일 때만 돈다. 관리자 시나리오는 `E2E_ADMIN_EMAIL`·`E2E_ADMIN_PASSWORD`(backend의 `blog.admin.bootstrap-super-admin-email`과 같은 회원)가 있을 때만(`requireAdmin()`). JaCoCo·Vitest 라인 80% 게이트 유지.
