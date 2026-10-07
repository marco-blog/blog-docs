-- 0004 주제 인덱스 교체 (0002의 우회를 정리)
-- 날짜: 2026-10-07
-- 대상: 개발 DB cf_u2_d2 (Crowfoot 커넥션 48)
-- 문서: Crowfoot "blog 1.0" (documentId 646) version 51
-- 승인: marco (2026-10-07, 배포 전 체크리스트 1번 "교체" 승인, Crowfoot 수정 후 진행 지시)
-- 실행: Crowfoot apply_migration, 3개 문장 실행, 실패 0. 실행 후 plan_migration 차이 0.
--
-- 0002에서 Crowfoot 순서 버그(커뮤니티 글 47) 때문에 _id 이름으로 따로 만든 인덱스를 지우고,
-- 원래 이름의 인덱스를 (…, id DESC)로 바꿨다. _id는 맨 마지막에 지워 그 사이에도 주제 쿼리용 인덱스가 남아 있었다.

DROP INDEX idx_posts_topic_status_visibility_published ON posts;
CREATE INDEX idx_posts_topic_status_visibility_published ON posts (topic_id ASC, status ASC, visibility ASC, published_at DESC, id DESC);
DROP INDEX idx_posts_topic_status_visibility_published_id ON posts;
