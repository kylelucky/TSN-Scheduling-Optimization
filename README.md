# TSN Scheduling Optimization (IEEE 802.1Qbv)

## 📌 프로젝트 개요
- IEEE 802.1Qbv Time-Aware Shaper 기반의 TSN(Time-Sensitive Networking) 전송 문제를 대상으로
- **Guard Time 최소화**를 목표로 IBM CPLEX OPL을 활용한 MILP 최적화 모델 구현
- wrap-around 구조, offset 조정, 충돌 회피 제약 등을 반영하여 현실적인 네트워크 환경에서 최적화된 스케줄링 도출

## 🛠 사용 기술
- Language: OPL (IBM CPLEX Studio)
- Tools: IBM CPLEX Optimization Studio
- Concept: MILP Modeling, Scheduling, Network Optimization

## 🔑 주요 기능
- Hyperperiod 기반 TSN 스케줄링 모델링
- Guard Time 계산 및 최소화
- Wrap-around 시간 반영, Offset 기반 충돌 회피
- 다양한 시뮬레이션을 통한 성능 검증

## 🚀 실행 방법
1. IBM CPLEX Optimization Studio 설치
2. `src/tsn_model.mod` 및 `src/tsn_data.dat` 파일 열기
3. Run → 솔버 실행
4. 결과: Guard Time 최소화 값 및 스케줄링 출력

## 📂 프로젝트 구조
TSN-Scheduling-Optimization/
├─ src/
│ ├─ tsn_model.mod
│ └─ tsn_data.dat
├─ docs/
│ └─ thesis_chanwoo_jung.pdf
└─ README.md

## 📄 참고 자료
- [졸업논문 PDF](./docs/thesis_chanwoo_jung.pdf)

## 🔗 포트폴리오 활용
- 이 프로젝트는 이력서/자기소개서에 첨부하여 **네트워크 최적화 문제 해결 능력**을 보여주기 위한 포트폴리오용 저장소입니다.
