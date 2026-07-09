# HSF2–NETosis Cross-Organ Fibrosis Dry-Lab Analysis

PHMG(polyhexamethylene guanidine) 처리 호중구에서 관찰된 HSF2 전사인자 상승이, 간·폐 섬유화 조직에서
NETosis(호중구 세포외 트랩 형성) 관련 유전자 발현과 어떤 관계에 있는지를 공개 GEO 데이터로 검증한
dry-lab 분석. Wet-lab(PHMG 처리 호중구 western blot, HSF2 농도/시간 의존적 상승 관찰)의 후속 in silico
검증 파트.

## 배경 및 가설

- 실험실 wet-lab 관찰: PHMG 3 µg/mL, 6hr 처리 호중구에서 HSF2 밴드 상승 (n=1 pilot)
- 원 가설: HSF2 상승 → N2 호중구 극성화/NETosis 유전자 발현 촉진 → 섬유화·HCC 면역회피 촉진
- 이 저장소는 그 가설의 **하위 예측**("섬유화 조직에서 HSF2와 NETosis 유전자 발현이 양의 상관관계를
  가질 것")을 4개의 독립 공개 GEO 코호트(간 2개, 폐 2개, 서로 다른 3개 플랫폼)로 검증한다.

## 사전 지정 분석 계획 (pre-specified, see `scripts/00_functions.R` 상단 주석)

- **1차 endpoint**: 섬유화/질환 조직 내에서 HSF2 vs `NET_core` score (PADI4/ELANE/MPO 평균 z-score)의
  Spearman rho
- **재현 규칙**: 동일 장기의 1차/재현 코호트가 같은 부호 + 둘 다 nominal p<0.05일 때만 "재현됨"으로 판정
- 개별 유전자 상관관계는 탐색적(secondary)로 취급, BH-FDR 보정
- Bootstrap 95% CI(2000회), leave-one-out 민감도 분석을 모든 상관계수에 동반

## 데이터 (4개 코호트, 2개 장기, 3개 플랫폼)

| 코호트 | 장기 | 역할 | 플랫폼 | n (질환군) |
|---|---|---|---|---|
| GSE135251 (Govaere et al.) | 간 (NAFLD, F0-F4) | 1차 | RNA-seq | 206 |
| GSE14323 (Wurmbach et al.) | 간 (cirrhosis/HCC) | 재현 | Affymetrix HG-U133A | 96 |
| GSE47460 (LTRC/LGRC) | 폐 (UIP/IPF) | 1차 | Agilent GPL14550 | 122 |
| GSE53845 | 폐 (IPF) | 재현 | Agilent GPL6480 (2-color) | 40 |

원본 데이터는 `data/`에 두되 git에는 커밋하지 않음(`.gitignore`). 재현하려면:
- GSE14323/GSE47460/GSE53845: 스크립트가 `GEOquery::getGEO()`로 자동 재다운로드
- GSE135251: NCBI GEO의 `GSE135251_RAW.tar` 보충파일을 받아 `data/GSE135251_RAW/`에 압축 해제
  (개별 `GSM*.counts.txt`, Ensembl gene ID 카운트)

## 실행 순서

```
scripts/00_functions.R              # 공통 함수 (NET 유전자 패널, bootstrap CI, DL meta-analysis 등) - source만 됨
scripts/01_liver_GSE135251.R        # 간 1차
scripts/02_liver_GSE14323.R         # 간 재현
scripts/03_lung_GSE47460.R          # 폐 1차
scripts/04_lung_GSE53845.R          # 폐 재현
scripts/05_meta_analysis.R          # 4개 코호트 통합 (DerSimonian-Laird random-effects), forest plot
scripts/06_specificity_check_PTPRC.R # 특이성 대조: HSF2 vs PTPRC(CD45, 범백혈구 마커)
```

`scripts/exploration/`에는 데이터 구조 파악용 1회성 recon 스크립트를 보존(재현성 목적, 파이프라인
실행에는 불필요).

## 결과 요약

**1차 endpoint (HSF2 vs NET_core), 4개 코호트 전부 방향 일치 (음의 상관) — 원 가설과 반대 방향:**

| 코호트 | n | rho | p |
|---|---|---|---|
| GSE135251 (간) | 206 | -0.145 | 0.038 |
| GSE14323 (간) | 96 | -0.550 | 6.2e-09 |
| GSE47460 (폐) | 122 | -0.392 | 8.1e-06 |
| GSE53845 (폐) | 40 | -0.050 | 0.76 (n.s., underpowered) |

**Random-effects meta-analysis (Fisher z, DerSimonian-Laird, from-scratch 구현, `metafor` 미사용):**
pooled rho = **-0.308** (95% CI [-0.508, -0.076]), p = 0.010, I² = 83.5% (이질성 높음, 주로
GSE53845의 과소검정력 때문)

**특이성 대조 (`06_specificity_check_PTPRC.R`)**: HSF2는 범백혈구 마커 PTPRC(CD45)와는 오히려
**양의 상관**(간 두 코호트 모두 p<0.05)을 보이는데, NETosis 핵심 유전자와는 특이적으로 음의 상관을
보임 → 단순 "섬유화될수록 면역세포가 늘어 벌크조직에서 HSF2 신호가 희석된다"는 아티팩트로는 설명되지
않음.

## 해석 및 한계

- 원 가설("HSF2↑ → NETosis 유전자↑")은 이 4개 벌크조직 코호트에서 **지지되지 않음**. 오히려 HSF2가
  NETosis 기계장치 유전자 발현과 반비례하는 패턴이 3/4 코호트에서 유의하게, 특이성 대조까지 통과하며
  재현됨.
- 벌크조직 상관분석은 **세포특이성과 인과관계를 증명하지 못함**. HSF2가 실제로 어느 세포(간세포/폐
  상피세포 vs 침윤 호중구 자체)에서 이 신호를 내는지 이 데이터만으로는 알 수 없음.
- GSE53845(n=40)는 방향은 일치하나 유의성 재현 실패 — 과소검정력 문제로 해석, 반증으로 보지 않음.
- 다음 단계로 **분리된 순수 호중구**에서 HSF2와 NET 마커(PADI4 등)를 직접 같이 측정하는 wet-lab
  실험이 이 벌크조직 상관관계의 세포특이성 모호함을 해소하는 핵심 실험임.

## 산출물

- `results/ALL_COHORTS_primary_endpoint_summary.csv`, `ALL_COHORTS_meta_analysis_summary.csv`: 종합표
- `results/SPECIFICITY_check_PTPRC_vs_NETcore.csv`: 특이성 대조 결과
- `results/*_individual_gene_results.csv`: 코호트별 개별 유전자 FDR 보정 결과
- `figures/FOREST_HSF2_vs_NETcore_all_cohorts.png`: 전체 forest plot
- `figures/*_HSF2_vs_NETcore.png`, `*_HSF2_by_{stage,group}.png`: 코호트별 산점도/박스플롯

## Step 3: HCC 면역항암제(ICI) 반응성 (`scripts/07_hcc_ICI_GSE215011.R`)

**게이트체크 결과 — GSE140901은 사용 불가로 판정:** 원래 계획했던 GSE140901(HCC, anti-PD-1/anti-CTLA-4,
n=24)은 NanoString PanCancer Immune Profiling 785유전자 패널이며, 확인 결과 **HSF2가 패널에 아예
없음** (NET_core 3유전자 중에서도 PADI4·MPO 없음, ELANE만 존재). 대체 패널 유전자로 억지로 끼워맞추지
않고 이 데이터셋은 배제함 (`scripts/exploration/_debug_gse140901_suppl.R`에 근거 기록).

**대안으로 채택**: GSE215011 (HCC, **nivolumab 단독요법**, whole-transcriptome tumor RNA-seq, n=10:
responder 5 / non-responder 5) — HSF2 및 NET_core 유전자 전부(13/13) 측정됨.

| 비교 | n | 결과 | p |
|---|---|---|---|
| HSF2: Responder vs Non-responder | 5 vs 5 | Responder에서 근소하게 높음 | 0.31 (n.s.) |
| NET_core: Responder vs Non-responder | 5 vs 5 | Responder에서 근소하게 높음 | 0.67 (n.s.) |
| HSF2 vs NET_core (전체 10개 종양) | 10 | rho=+0.17 | 0.65 (n.s., CI [-0.51, 0.92]) |

**해석**: n=5 vs 5는 매우 큰 효과크기가 아니면 애초에 유의성 도달이 불가능한 표본 크기. 모든 검정이
비유의 — 이 데이터셋은 가설을 지지도 반박도 못 함, "정보 없음"으로 취급해야 함. 흥미롭게도 이 코호트
에서는 HSF2-NET_core 상관관계 부호가 섬유화 코호트(음의 상관)와 달리 양의 방향으로 나왔지만, 신뢰
구간이 -0.51~+0.92로 사실상 무정보이므로 "종양 조직에서는 반대 방향일 수 있다"는 결론도 낼 수 없음.
더 큰 코호트(GSE279750 n=10, GSE235863 n=15 등, 병용요법이라 이질적)를 추가로 pooling하면 검정력을
보강할 수 있으나 현재는 미착수.
