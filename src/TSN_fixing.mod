/*******************************************************************
 * TSN-Unicast Scheduling – no-wait + guard 최소화 + 하이퍼피리어드
 * Author: 정찬우, 변개령 
 *******************************************************************/

/*** 0. PARAMETERS *************************************************/
int H_P = ...;
int N_F = ...;
int N_E = ...;
int N_V = ...;

range flow   = 1..N_F;
range edge   = 1..N_E;
range vertex = 1..N_V;

int num_sf[flow] = ...;
int max_num_sf = ...;
range sf_range = 0..max_num_sf-1;

int U = H_P;

int source  [flow] = ...;
int dest    [flow] = ...;
int period  [flow] = ...;
int duration[flow] = ...;

assert forall(f in flow) duration[f] < period[f];

int EE   [edge][edge]  = ...;
int inVE [vertex][edge]= ...;
int outVE[vertex][edge]= ...;

int max_guard_time     = ...;

/*** 1. BIG-M *******************************************************/
int M = 10 * H_P;

/*** 2. DECISION VARIABLES *****************************************/
dvar boolean Use[flow][edge];
dvar int+ guard_t[flow][edge][sf_range];
dvar int+ tx_eff  [flow][edge][sf_range];
dvar int+ end_t   [flow][edge][sf_range];
dvar int+ startUsed[flow][edge][sf_range];
dvar boolean Order[flow][sf_range][flow][sf_range][edge];

dvar int d[flow][sf_range][flow][sf_range][edge]; // Δ: 시작 - 종료 시간차

dvar boolean isPos[flow][sf_range][flow][sf_range][edge]; // Δ > 0 여부

dvar boolean isMin[flow][sf_range][flow][sf_range][edge]; // 최소 Δ 후보 선택

dvar int+ z[flow][sf_range][flow][sf_range][edge];         // Δ × isMin 선형화
dvar int    zSel   [flow][sf_range][edge];   // one-hot으로 고른 Δ 값

dvar int dWrap[flow][sf_range][edge]; // wrap-around Δ (음수→양수 변환)

dvar int    guardB [flow][sf_range][edge];   // zSel ↔ dWrap 스위치 결과
dvar boolean cap   [flow][sf_range][edge];   // 1 ⇒ max_guard, 0 ⇒ guardB

/*  (f, sf, e) 경로에서 ‘양수 Δ 후보가 하나라도 존재’하면 1 */
dvar boolean hasPos[flow][sf_range][edge];

/* Σ isPos = 양수Δ개수 */
dvar boolean isFirst[flow][sf_range][edge];   // 1 ⇒ HP 내 첫 전송

dvar int offset[flow]; // subflow 반복 시작 offset

float epsilon = 1e-5;

int maxPair = N_F * max_num_sf;   // Δ 후보 개수의 최대치

/*** 3. OBJECTIVE **************************************************/
// guard_t 총합 최소화 (총 guard overhead 최소화)
minimize sum(f in flow, sf in 0..num_sf[f]-1, e in edge) guard_t[f][e][sf];

/*** 4. CONSTRAINTS ************************************************/
subject to {
  // offset은 1 이상, period 이하
  forall(f in flow) 1 <= offset[f] <= period[f];

  // 소스 노드 시작 시간은 offset 기준 반복
  forall(f in flow, sf in 0..num_sf[f]-1, e in edge : outVE[source[f]][e] == 1)
    startUsed[f][e][sf] == offset[f] + sf * period[f];

  // 플로우 경로 연결 제약 (송신/도착/중간 노드)
  forall(f in flow) {
    sum(e in edge) outVE[source[f]][e] * Use[f][e] == 1; // 송신노드: out-edge 1개
    sum(e in edge)  inVE[source[f]][e] * Use[f][e] == 0; // 송신노드: in-edge 없음
    sum(e in edge)  inVE[dest[f]][e]  * Use[f][e] == 1; // 도착노드: in-edge 1개
    sum(e in edge) outVE[dest[f]][e]  * Use[f][e] == 0; // 도착노드: out-edge 없음
  }
  forall(f in flow, v in vertex: v!=source[f] && v!=dest[f]) {
    sum(e in edge) inVE[v][e]*Use[f][e] == sum(e in edge) outVE[v][e]*Use[f][e]; // 중간노드: in-out 일치
    sum(e in edge) inVE[v][e]*Use[f][e] <= 1;
  }

  // 시간 변수 선형화
  forall(f in flow, sf in 0..num_sf[f]-1, e in edge) {
    startUsed[f][e][sf] <= tx_eff[f][e][sf];
    startUsed[f][e][sf] <= U * Use[f][e];
    startUsed[f][e][sf] >= tx_eff[f][e][sf] - U * (1 - Use[f][e]);
    startUsed[f][e][sf] >= 0;
  }

  // 종료시간 계산
  forall(f in flow, sf in 0..num_sf[f]-1, e in edge)
    end_t[f][e][sf] == startUsed[f][e][sf] + duration[f]*Use[f][e];

  // no-wait 제약: 연속 edge는 바로 전송
  forall(f in flow, sf in 0..num_sf[f]-1,
         v in vertex,
         eIn in edge, eOut in edge:
         inVE[v][eIn]==1 && outVE[v][eOut]==1) {
    startUsed[f][eOut][sf] - startUsed[f][eIn][sf] - duration[f]
      >= -M*(2 - Use[f][eIn] - Use[f][eOut]) - epsilon;
    startUsed[f][eOut][sf] - startUsed[f][eIn][sf] - duration[f]
      <=  M*(2 - Use[f][eIn] - Use[f][eOut]) + epsilon;
  }

  // tx_eff 선형화: 이전 edge의 종료 = 다음 edge의 시작
  forall(f in flow, sf in 0..num_sf[f]-1,
         v in vertex,
         eIn in edge, eOut in edge:
         inVE[v][eIn]==1 && outVE[v][eOut]==1) {
    tx_eff[f][eOut][sf] >= end_t[f][eIn][sf] - M * (2 - Use[f][eIn] - Use[f][eOut]);
    tx_eff[f][eOut][sf] <= end_t[f][eIn][sf] + M * (2 - Use[f][eIn] - Use[f][eOut]);
  }

  // 동일 edge 내 다른 subflow 충돌 방지
  forall(f1 in flow, sf1 in 0..num_sf[f1]-1,
         f2 in flow, sf2 in 0..num_sf[f2]-1,
         e in edge: (f1 == f2 && sf1 != sf2)) {
    startUsed[f1][e][sf1] + duration[f1]*Use[f1][e]
      <= startUsed[f2][e][sf2] + M * (1 - Order[f1][sf1][f2][sf2][e]);
    startUsed[f2][e][sf2] + duration[f2]*Use[f2][e]
      <= startUsed[f1][e][sf1] + M * Order[f1][sf1][f2][sf2][e];
  }

  // 시간 상한
  forall(f in flow, sf in 0..num_sf[f]-1, e in edge)
    startUsed[f][e][sf] <= H_P;
    
   /* guard_t = max_guard_time * Use */
/*  forall(f in flow, e in edge, sf in 0..num_sf[f]-1)
    guard_t[f][e][sf] == max_guard_time * Use[f][e];*/
    
  /*** POSITIVE-Δ DETECTION ************************************/
  /*  Δ가 양수인 후보가 있으면 hasPos=1, 없으면 0                   */
  forall(f in flow, sf in 0..num_sf[f]-1, e in edge) {
   // hasPos = 1 ⇒ Σ isPos ≥ 1 
   sum(fp in flow, sfp in 0..num_sf[fp]-1) 
       isPos[f][sf][fp][sfp][e] >= hasPos[f][sf][e];

   // Σ isPos > 0 ⇒ hasPos = 1 
   hasPos[f][sf][e] <=
       sum(fp in flow, sfp in 0..num_sf[fp]-1) isPos[f][sf][fp][sfp][e];

   // upper-bound(옵션): Σ isPos ≤ maxPair·hasPos
   sum(fp in flow, sfp in 0..num_sf[fp]-1) 
       isPos[f][sf][fp][sfp][e] <= maxPair * hasPos[f][sf][e];
  }
  
  // isFirst = 1  ⇔  hasPos = 0  (HP 맨 앞 전송)
  forall(f in flow, sf in 0..num_sf[f]-1, e in edge)
    isFirst[f][sf][e] + hasPos[f][sf][e] == 1;    
    
  // Δ 계산 및 후보 필터링
  forall(f in flow, sf in 0..num_sf[f]-1,
         fp in flow, sfp in 0..num_sf[fp]-1, e in edge) {
    d[f][sf][fp][sfp][e] == startUsed[f][e][sf] - end_t[fp][e][sfp];
    d[f][sf][fp][sfp][e] >= -epsilon - M*(3-Use[f][e]-Use[fp][e]-isPos[f][sf][fp][sfp][e]);
    d[f][sf][fp][sfp][e] <= M*isPos[f][sf][fp][sfp][e];
    isMin[f][sf][fp][sfp][e] <= isPos[f][sf][fp][sfp][e];
  }

  // Δ×isMin 선형화
  forall(f in flow, sf in 0..num_sf[f]-1,
         fp in flow, sfp in 0..num_sf[fp]-1, e in edge) {
    z[f][sf][fp][sfp][e] <= d[f][sf][fp][sfp][e] + M * (1 - isMin[f][sf][fp][sfp][e]);
    z[f][sf][fp][sfp][e] >= d[f][sf][fp][sfp][e] - M * (1 - isMin[f][sf][fp][sfp][e]);
    z[f][sf][fp][sfp][e] <= M * isMin[f][sf][fp][sfp][e];
    z[f][sf][fp][sfp][e] >= -M * isMin[f][sf][fp][sfp][e];
  }
  
  forall(f in flow, sf in 0..num_sf[f]-1, e in edge)
   zSel[f][sf][e] == sum(fp in flow, sfp in 0..num_sf[fp]-1)
                        z[f][sf][fp][sfp][e];      // isMin이 1개라 단일 값
  
  // dWrap = d + H_P  ⇔  isFirst = 1
  //isFirst = 0 이면 dWrap = 0  
  forall(f in flow, sf in 0..num_sf[f]-1, e in edge) {
   dWrap[f][sf][e] - (d[f][sf][f][sf][e] + H_P)
        <=  M * (1 - isFirst[f][sf][e]);
   dWrap[f][sf][e] - (d[f][sf][f][sf][e] + H_P)
        >= -M * (1 - isFirst[f][sf][e]);

   // isFirst = 0 ⇒ dWrap = 0 
   dWrap[f][sf][e] <=  M * isFirst[f][sf][e];
   dWrap[f][sf][e] >= -M * isFirst[f][sf][e];
  }
  

  // Δ 후보 중 하나만 선택 (one-hot)
  // one-hot among positive Δ only
  forall(f in flow, sf in 0..num_sf[f]-1, e in edge)
   sum(fp in flow, sfp in 0..num_sf[fp]-1) 
       isMin[f][sf][fp][sfp][e] == hasPos[f][sf][e];

  // guard_t = min(z, max_guard_time)
  forall(f in flow, sf in 0..num_sf[f]-1, e in edge){
   // isFirst = 0 → guardB = zSel 
   guardB[f][sf][e] >= zSel [f][sf][e] - M * isFirst[f][sf][e];
   guardB[f][sf][e] <= zSel [f][sf][e] + M * isFirst[f][sf][e];

   // isFirst = 1 → guardB = dWrap 
   guardB[f][sf][e] >= dWrap[f][sf][e] - M * (1 - isFirst[f][sf][e]);
   guardB[f][sf][e] <= dWrap[f][sf][e] + M * (1 - isFirst[f][sf][e]);
  }
  
  forall(f in flow, sf in 0..num_sf[f]-1, e in edge){
   // cap = 0 ⇒ guard_t = guardB  
   guard_t[f][e][sf] >= guardB[f][sf][e] - M*cap[f][sf][e];
   guard_t[f][e][sf] <= guardB[f][sf][e] + M*cap[f][sf][e];

   // cap = 1 ⇒ guard_t = max_guard_time 
   guard_t[f][e][sf] >= max_guard_time  - M*(1-cap[f][sf][e]);
   guard_t[f][e][sf] <= max_guard_time  + M*(1-cap[f][sf][e]);
  }

  // 동일 플로우의 subflow 간 간격 = period
  forall(f in flow, e in edge, sf in 0..num_sf[f]-2) {
    startUsed[f][e][sf+1] - startUsed[f][e][sf] <= period[f] + M * (1 - Use[f][e]);
    startUsed[f][e][sf+1] - startUsed[f][e][sf] >= period[f] - M * (1 - Use[f][e]);
  }
  // 선택된 Δ는 모든 다른 후보보다 작거나 같아야 함
forall(f in flow, sf in 0..num_sf[f]-1, 
       fp1 in flow, sfp1 in 0..num_sf[fp1]-1,
       fp2 in flow, sfp2 in 0..num_sf[fp2]-1,
       e in edge : 
       fp1 != fp2 || sfp1 != sfp2) {
  
  d[f][sf][fp1][sfp1][e] - d[f][sf][fp2][sfp2][e] 
  <= M * (1 - isMin[f][sf][fp1][sfp1][e] + 1 - isPos[f][sf][fp2][sfp2][e]);
}
  
}
