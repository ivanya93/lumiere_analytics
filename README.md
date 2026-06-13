# Lumière EU E-Commerce Analytics

End-to-end analytics engineering project for **Lumière**, a fictional European DTC apparel & lifestyle retailer operating in 8 EU countries. Built for the AIDVS Executive Master group project (Porto Business School).

**Business question:** *"Where should Lumière focus its commercial attention over the next two quarters to grow profitably?"*

---

## 📊 Project Overview

| | |
|---|---|
| **Dataset** | 82,000 orders · 5,200 customers · 177 products · 6,150 returns |
| **Period** | Jan 2024 – Dec 2025 |
| **Markets** | France, Germany, Italy, Spain, Portugal, Netherlands, Belgium, Ireland |
| **Channels** | Web · Mobile App · Marketplace |
| **Stack** | Python · PostgreSQL · dbt · Tableau · Git |

## 🏗️ Architecture

```
Excel (raw)
   │
   ├─► 01_data_quality.ipynb ──► data/cleaned/*.parquet
   │        profiling · quality checks · cleaning
   │
   ├─► 02_data_enrichment.ipynb ──► data/curated/*.parquet
   │        revenue & margin metrics · RFM · CLV · country KPIs
   │
   └─► 03_load_to_postgres.ipynb ──► PostgreSQL (raw schema)
            │
            └─► dbt ──► staging → intermediate → marts
                     │
                     └─► Tableau executive dashboard
```

The Python notebooks **explore and validate** the logic; dbt **productionises** the same metrics as tested, version-controlled SQL models that Tableau consumes directly.

## 📁 Repository Structure

```
lumiere_analytics/
├── data/
│   ├── raw/                  # Lumiere_EU_Ecommerce.xlsx (git-ignored)
│   ├── cleaned/              # parquet output of notebook 01
│   └── curated/              # parquet output of notebook 02
├── notebooks/
│   ├── 01_data_quality.ipynb       # profiling, quality report, cleaning
│   ├── 02_data_enrichment.ipynb    # metrics, RFM, CLV, country KPIs
│   └── 03_load_to_postgres.ipynb   # load raw tables to PostgreSQL
├── dbt/
│   ├── dbt_project.yml
│   ├── profiles.yml          # connection config (git-ignored)
│   └── models/
│       ├── staging/          # typed, renamed views over raw tables
│       ├── intermediate/     # business logic (enrichment, RFM)
│       └── marts/            # Tableau-ready fact & KPI tables
├── tableau/                  # .twbx workbook + .tds data source
├── .env                      # LUMIERE_DB_URL (git-ignored)
├── .gitignore
├── requirements.txt
└── README.md
```

## 🔄 Pipeline Phases

### Phase 1 — Data Quality (`01_data_quality.ipynb`)
- Profiling of all 5 source tables (nulls, duplicates, IQR outliers)
- 20+ automated quality checks via a `DataQualityReport` class
- Referential integrity validation (Orders → Customers, Orders → Products, Returns → Orders)
- Cleaning: date parsing, country alias normalization, discount clipping to [0, 0.5], deduplication
- Output: cleaned parquet files

### Phase 2 — Enrichment (`02_data_enrichment.ipynb`)
- **Order metrics:** Gross Revenue, Discount Amount, Net Revenue, COGS, Gross Profit, Margin %
- **Date dimensions:** Year, Quarter, Month, Week, Year-Month, Fiscal Year/Quarter
- **RFM segmentation** (quintile scoring, snapshot 2026-01-01) into 5 segments: Champions, Loyal Customers, Potential Loyalists, Needs Attention, At Risk
- **CLV estimate:** total revenue × 1.5 retention factor
- **Country KPIs:** YoY growth %, target achievement %, revenue per customer
- **Retention:** retention rate, churn rate, repeat purchase rate
- Output: curated parquet files (`orders_enriched`, `customer_analytics`, `country_kpis`, `dim_date`)

### Phase 3 — Load (`03_load_to_postgres.ipynb`)
- Loads the 5 raw Excel sheets into PostgreSQL `raw` schema via SQLAlchemy
- Column names converted to snake_case
- Post-load row count verification

### Phase 4 — dbt Transformations (`dbt/`)
Three-layer architecture:

| Layer | Materialization | Purpose |
|---|---|---|
| `staging` | view | Type casting, renaming, business-rule filters |
| `intermediate` | table | Joins, margin metrics, RFM window functions |
| `marts` | table | Tableau-ready fact & aggregated KPI tables |

Tests applied: `unique`, `not_null`, `accepted_values`, `relationships`.

Key models:
- `fct_orders` — one row per order with full product, margin, and return context
- `mart_commercial_kpis` — revenue/margin/discount/returns by month × country × channel × category × brand
- `mart_customer_kpis` — one row per customer with RFM scores, segment, CLV
- `mart_country_targets` — actual vs target revenue with YoY growth

### Phase 5 — Tableau Dashboard (`tableau/`)
Executive dashboard answering the strategic question, with a curated data source (friendly field names, folders, hierarchies, field descriptions for AI readiness).

## 🚀 Getting Started

### Prerequisites
- Python 3.9+
- PostgreSQL 14+ (local or Docker)
- dbt-postgres (`pip install dbt-postgres`)
- Tableau Desktop (for the dashboard)

### Setup

```bash
# 1. Clone and install dependencies
git clone https://github.com/<ivanya93>/lumiere_analytics.git
cd lumiere_analytics
pip install -r requirements.txt

# 2. Configure the database connection
echo 'LUMIERE_DB_URL=postgresql://postgres:<password>@localhost:5432/lumiere' > .env

# 3. Place the source file
#    data/raw/Lumiere_EU_Ecommerce.xlsx

# 4. Run the notebooks in order
#    01_data_quality.ipynb  →  02_data_enrichment.ipynb  →  03_load_to_postgres.ipynb

# 5. Run dbt
cd dbt
dbt deps
dbt build        # runs all models + tests
```

### requirements.txt

```
pandas
numpy
openpyxl
pyarrow
sqlalchemy
psycopg2-binary
python-dotenv
matplotlib
```

## 📈 Key Findings

- **Revenue grew 2.5×** in 2025 vs 2024, led by Germany and France (44% of total)
- **52.9% blended gross margin**, but orders with 30%+ discounts compress margin by ~31pp
- **98% customer retention** 2024→2025; ~7% of customers are At Risk and recoverable
- **Netherlands underperforms targets** (68% achievement) despite high growth — targets or operations need review
- Highest-margin brands (Lumière Maison, North Coast) are underrepresented in the revenue mix

## 🤖 AI Disclosure

AI assistants (Claude by Anthropic) were used for: dataset schema interpretation, dbt model scaffolding, KPI framework structuring, and drafting documentation. All analytical logic was validated against computed results from the actual dataset, in line with the project brief's disclosure requirements.

## 📄 License

Academic project — Porto Business School, AIDVS Executive Master. Dataset is synthetic.
