-- 0002 조회 인덱스 추가 (003·005·006·007 선택 인덱스 제안)
-- 날짜: 2026-10-07
-- 대상: 개발 DB cf_u2_d2 (Crowfoot 커넥션 48)
-- 문서: Crowfoot "blog 1.0" (documentId 646) version 49
-- 승인: marco (2026-10-07, 배포 전 체크리스트 1번 항목 승인)
-- 실행: Crowfoot apply_migration, 9개 문장 실행, 실패 0. 실행 후 plan_migration 차이 0.
--
-- 참고: 주제 인덱스는 원래 기존 idx_posts_topic_status_visibility_published를 같은 이름으로
-- (…, id DESC)로 바꾸려 했으나, Crowfoot plan_migration이 같은 이름의 CREATE를 DROP보다 먼저 내서
-- 실행할 수 없었다. 그래서 새 이름(_id)으로 추가하고 기존 인덱스는 남겼다(새 인덱스의 앞부분과 같아 중복).
-- 기존 인덱스를 지우려면 Crowfoot 화면에서 문서의 인덱스를 지운 뒤 plan_migration을 다시 승인받는다.

CREATE INDEX idx_users_nickname ON users (nickname ASC);
CREATE INDEX idx_users_created ON users (created_at ASC);
CREATE INDEX idx_posts_status_visibility_published ON posts (status ASC, visibility ASC, published_at DESC, id DESC);
CREATE INDEX idx_posts_published_at ON posts (published_at ASC);
CREATE INDEX idx_posts_topic_status_visibility_published_id ON posts (topic_id ASC, status ASC, visibility ASC, published_at DESC, id DESC);
CREATE INDEX idx_comments_status_created ON comments (status ASC, created_at ASC);
CREATE INDEX idx_guestbook_entries_status_created ON guestbook_entries (status ASC, created_at ASC);
CREATE INDEX idx_trackback_ping_logs_status_created ON trackback_ping_logs (status ASC, created_at ASC);
CREATE INDEX idx_external_posts_topic_decided ON external_posts (topic_decided_at ASC);
