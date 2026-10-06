# Research: 007 외부 블로그 피드

`/speckit-plan` 전에 먼저 정한 결정. 계획 단계에서 이 파일에 이어 쓴다.

## E1. 피드 수집 스케줄링 (FR-113, FR-116, FR-117)
- **Decision**: Spring `@Scheduled`로 단순하게 간다(1.0은 backend 1대, 001 R26과 같은 방식).
  - 스케줄러는 1분마다 "수집할 차례인 피드"만 골라낸다: `external_feeds.status = ACTIVE AND next_fetch_at <= now`, 한 번에 최대 `blog.external.batch-size`(기본 50)개.
  - 고른 피드는 크기가 정해진 별도 스레드 풀(`blog.external.fetch-threads`, 기본 4)에서 동시에 받는다. 피드 하나가 느려도 나머지가 밀리지 않게 하기 위해서다. 연결 5초, 읽기 10초, 응답 최대 2MB 제한.
  - 받은 뒤 `next_fetch_at = now + 수집 주기(기본 30분, blog.external.fetch-interval)`로 미룬다. 피드마다 `next_fetch_at`에 무작위 지연(0~5분)을 더해 같은 시각에 몰리지 않게 한다.
  - 변경 확인: 저장해 둔 `ETag`, `Last-Modified`로 조건부 요청(`If-None-Match`, `If-Modified-Since`)을 보내고 304면 내려받지 않는다(FR-116).
  - 파싱은 ROME(RSS 0.9x/1.0/2.0, Atom 1.0)으로 한다. 같은 글 판별은 `guid`, 없으면 원문 링크의 정규화 값(FR-115).
  - 실패하면 다음 시도를 점점 늦춘다(30분 → 1시간 → 2시간 … 최대 12시간). 첫 실패 후 7일 동안 성공이 없으면 `status = STOPPED`로 바꾸고 알린다(FR-117).
  - 외부 주소 요청은 사설·루프백·링크 로컬 IP로 가지 못하게 막는다(SSRF 방지, FR-116). 리다이렉트도 최대 3번까지만 따라가고 매번 같은 검사를 한다.
  - 원문 링크 점검(FR-117 후반)은 주 1회 별도 `@Scheduled` 작업으로 HEAD 요청만 보낸다.
- **나중에 서버가 2대 이상이 되면**: 같은 피드를 두 대가 동시에 수집하지 않도록 ShedLock(DB 잠금)을 붙이거나, 피드를 고를 때 `SELECT … FOR UPDATE SKIP LOCKED`로 가져간다. 1.0에는 넣지 않는다.
- **Alternatives**: Quartz(테이블과 설정이 늘어남, 1대 운영엔 과함), Spring Batch(재시작·청크 처리가 필요할 만큼 무겁지 않음), 메시지 큐(실행 파트 추가, 원칙 위반).
