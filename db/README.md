# DB 스키마 관리

스키마는 **Crowfoot ERD 문서 "blog 1.0"** 하나로 관리한다
(https://crowfoot.java21.net/workspaces/53/models/646).
Flyway 같은 다른 마이그레이션 도구는 쓰지 않는다. 두 도구를 함께 쓰면 변경 이력이 어긋나기 때문이다.

## 데이터베이스

| 용도 | 스키마 | Crowfoot 커넥션 | 반영 방법 |
|---|---|---|---|
| 개발 | `cf_u2_d2` | 48 (MySQL #2) | Crowfoot `plan_migration` → `apply_migration` (ALTER) |
| 테스트 | `cf_u2_d3` | 49 (MySQL #3) | backend 테스트가 실행마다 `schema-mysql.sql` 스냅숏으로 다시 만든다 |

접속 정보는 Crowfoot 화면의 데이터베이스 탭에서 확인하고, 환경 변수로만 넘긴다. 저장소에 커밋하지 않는다.

## 스키마를 바꾸는 순서

1. 스펙의 `data-model.md`와 [erd.md](../erd.md)를 고친다.
2. Crowfoot 문서를 고친다(`apply_schema`, 또는 Crowfoot 화면).
3. `plan_migration`으로 개발 DB에 실행될 ALTER를 받고, marco의 승인을 받는다.
   - 삭제 문장(DROP)은 기본으로 실행되지 않는다. 데이터가 사라지므로 따로 승인받고 `acceptDestructive=true`로 실행한다.
   - 이름 변경은 `RENAME COLUMN`/`RENAME TABLE`로 나와 데이터가 유지된다.
4. `apply_migration`으로 개발 DB에 반영한다.
5. 실행된 ALTER를 `migrations/NNNN-설명.sql`로 저장한다(번호는 4자리 순번, 맨 위에 날짜·문서 버전·승인자 주석).
6. `export_ddl`로 `schema-mysql.sql`을 다시 받아 저장하고, blog-backend의 `src/test/resources/db/schema-mysql.sql`도 같은 내용으로 바꾼다.
7. 엔티티를 고친다. Hibernate는 `ddl-auto=validate`라서 엔티티와 스키마가 다르면 앱이 뜨지 않는다.

1~6은 blog-docs 한 PR, 6~7의 backend 변경은 blog-backend 한 PR로 낸다.

## 초기 데이터

주제 목록, 기본 설정값 같은 기준 데이터는 SQL 파일이 아니라 backend 시작 시점의 초기화 코드가 넣는다.
이미 있으면 건너뛰므로(멱등) 여러 번 실행해도 된다. 데이터를 바꾸는 일회성 작업은 `migrations/`에 SQL로 남기고 같은 승인 절차를 따른다.
