-- 0003 blogs.first_published_at 백필 (003 T131, 일회성 데이터 보정)
-- 날짜: 2026-10-07
-- 대상: 003이 배포되는 DB(개발 cf_u2_d2, 운영)마다 한 번
-- 승인: marco (2026-10-07, 배포 전 체크리스트 1번 항목 승인)
-- 실행: 대기. Crowfoot 도구는 데이터 SQL을 실행하지 않고 작업 환경에서는 DB에 접속할 수 없어,
--       marco가 DB에 직접 실행한다. 여러 번 실행해도 결과가 같다(NULL인 행만 채운다).

UPDATE blogs b
   SET b.first_published_at = (SELECT MIN(p.published_at) FROM posts p
                                WHERE p.blog_id = b.id AND p.published_at IS NOT NULL)
 WHERE b.first_published_at IS NULL;
