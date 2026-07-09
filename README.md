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

## 유전자별 코호트 간 일관성 (`scripts/08_cross_cohort_gene_consistency.R`)

개별 NET 패널 유전자를 코호트 4개에 걸쳐 교차 검증한 결과, 명확히 두 그룹으로 나뉨:

- **일관되게 음의 상관 (4개 코호트 전부 같은 방향)**: CAMP, MPO, DEFA4, 그리고 대체로 PADI4·ELANE도
  같은 경향(3/4 유의). NETosis 효소·항균과립 단백질 계열.
- **장기 간 방향이 뒤집힘 (간 vs 폐 불일치)**: LTF, NCF2, ITGAM, LCN2. 특히 LCN2는 간세포/상피세포
  스트레스 반응에서도 널리 발현되는 유전자로 알려져 있어, 호중구 특이적 신호가 아닐 가능성을 항상
  같이 고려해야 함.

전체 표: `results/CROSS_COHORT_gene_consistency.csv`

## ChEA3 in silico 검증 (`scripts/09_chea3_analysis.R`)

위에서 가장 일관됐던 유전자 세트(PADI4/ELANE/MPO/CAMP/DEFA4)를 ChEA3에 질의해 HSF2가 이들의 상위
조절인자로 예측되는지 확인. **HSF2는 8개 라이브러리(ENCODE ChIP-seq, ReMap ChIP-seq, Literature
ChIP-seq 포함) 중 어디에서도 상위권에 들지 못함** — 순위는 항상 하위 10% 이내(예: Integrated
meanRank 1444/1632위), 유전자 중첩(intersect)은 전부 0. ChIP-seq 3개 라이브러리에서는 아예 결과에
등장조차 안 함. → 기존 공개 데이터베이스에는 "HSF2가 이 유전자들을 켠다"는 근거가 전무함. 이는
관계가 음의 방향(억제성)이라 co-expression 기반 도구가 원래 못 잡는 것과도 부합하고, 동시에 이 축이
정말 미개척임을 다시 확인해줌. 전체 표: `results/CHEA3_HSF2_enrichment_results.csv`

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

**해석**: n=5 vs 5는 매우 큰 효과크기가 아니면 애초에 유의성 도달이 불가능한 표본 크기. GSE215011
단독으로는 모든 검정이 비유의 — "정보 없음"으로 취급.

### ICI 코호트 pooling (`scripts/12_hcc_ICI_pooled_summary.R`)

GSE279750(anti-PD-L1 combo, post-tx, n=10)과 GSE235863(anti-PD-1+lenvatinib combo, post-tx, n=15)를
추가로 찾아 분석(`scripts/10_*`, `scripts/11_*`). HSF2 vs Responder/Non-responder를 rank-biserial
상관계수(Wilcoxon 효과크기, scale-free)로 3개 코호트를 통합:

| 코호트 | regimen | n | r_rb (양수=responder에서 HSF2 높음) | p |
|---|---|---|---|---|
| GSE215011 | anti-PD-1 단독요법 | 10 | +0.44 | 0.30 (n.s.) |
| GSE279750 | anti-PD-L1 병용, post-tx | 10 | **-0.92** | **0.025** |
| GSE235863 | anti-PD-1+lenvatinib 병용, post-tx | 15 | **-0.73** | **0.043** |
| **Pooled (RE)** | 3개 통합 | 35 | -0.59 | **0.223 (n.s.)**, I²=87.1% |

**해석**: 개별로는 2/3 코호트(병용요법 2개)에서 "HSF2 낮을수록 반응 좋음"이 유의했지만, formal
meta-analysis는 GSE215011(단독요법, 반대 방향 경향)과의 이질성 때문에 **비유의**(I²=87%, 매우 높은
이질성). 단독요법 vs 병용요법, 그리고 채취 시점(baseline vs 치료 후)이 섞여 있어 이 불일치가 진짜
생물학적 차이인지 잡음인지 이 데이터만으로는 결론 못 냄. **"확정된 발견"이 아니라 "추가 검증이
필요한 흥미로운 단서"로만 취급.**
