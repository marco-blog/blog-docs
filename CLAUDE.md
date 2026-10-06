# docs (Blog Platform 스펙 저장소)

티스토리 같은 멀티 유저 블로그의 스펙을 관리한다. GitHub Spec Kit 기반 스펙 주도 개발을 한다.

## 저장소 구성 (형제 디렉터리로 나란히 체크아웃)
```
blog/
├── docs/      ← 이 저장소: 헌법, 스펙, 계획, 작업 목록
├── backend/   ← Spring Boot (Java 21, Maven, JPA)
└── front/     ← React SSR (Vite + React)
```
구현할 때는 이 디렉터리에서 `claude --add-dir ../backend ../front`로 실행한다.

## 규칙
- 원칙과 기술 제약은 `.specify/memory/constitution.md`를 따른다. 충돌하면 헌법이 우선한다.
- 흐름: `/speckit-specify` → `/speckit-clarify` → `/speckit-plan` → `/speckit-tasks` → `/speckit-analyze` → `/speckit-implement`
- 문서와 대화는 한국어, 코드 식별자는 영어.
- tasks.md의 파일 경로는 `backend/...`, `front/...`로 시작해 어느 저장소인지 드러낸다.
