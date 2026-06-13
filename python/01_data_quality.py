"""
# Lumière E-Commerce Analytics Pipeline
* Phase 1: Data Quality Assessment
* Phase 2: Data Cleaning & Validation
* Author: Analytics Engineering Team
"""

# ─── 1. IMPORTS ───────────────────────────────────────────────────────────────
# %%
import pandas as pd
import numpy as np
from datetime import datetime
import warnings
warnings.filterwarnings("ignore")
import openpyxl as pxl
import os


# ─── 2. CONFIGURATION ─────────────────────────────────────────────────────────
# %%
# Path of the source file containing all tables
SOURCE_FILE = "../data/raw/Lumiere_EU_Ecommerce.xlsx"
# Folder where the cleaned files will be saved
CLEAN_OUTPUT = "data/cleaned"
# Location of the data quality report
REPORT_OUTPUT = "reports/data_quality_report.txt"

# List of countries that are considered valid
VALID_COUNTRIES = [
    "Belgium",
    "France",
    "Germany",
    "Ireland",
    "Italy",
    "Netherlands",
    "Portugal",
    "Spain",
]

# Valid product categories
VALID_CATEGORIES = [
    "Accessories",
    "Apparel",
    "Beauty",
    "Footwear",
    "Home & Living",
]

# Valid sales channels
VALID_CHANNELS = [
    "Marketplace",
    "Mobile App",
    "Web",
]

# Valid customer segments
VALID_SEGMENTS = ["Consumer", "Business", "Premium"]

# Accepted payment methods
VALID_PAYMENT = ["Credit Card", "PayPal", "Bank Transfer", "Apple Pay", "Klarna"]

# Dictionary used to standardize country names
COUNTRY_ALIASES = {
    "Deutschland": "Germany", "Allemagne": "Germany",
    "FR": "France", "España": "Spain", "Italia": "Italy",
    "Belgique": "Belgium", "Pays-Bas": "Netherlands",
    "Irlande": "Ireland", "Portugal": "Portugal",
}


# ─── 3. DATA QUALITY REPORT CLASS ─────────────────────────────────────────────
# %%
class DataQualityReport:
    # Constructor runs automatically when an instance is created
    def __init__(self):
        # Empty list that will accumulate all validation check results
        self.checks = []

    def add(self, table, check, result, detail=""):
        """Record one validation check and its pass/fail outcome."""
        # If result is True → PASS
        # If result is False → FAIL
        status = "PASS" if result else "FAIL"

        # Append a dict with all check metadata to the internal list
        self.checks.append({
            "table": table,    # which table was checked (e.g. "Orders")
            "check": check,    
            "status": status,  # "PASS" or "FAIL"
            "detail": detail,  
        })

    # Print report
    def print_report(self):
        """Print a formatted summary of all recorded checks to stdout."""
        print("LUMIERE DATA QUALITY REPORT")
    
        print(f"Generated {datetime.now().strftime('%Y-%m-%d %H:%M')}")

        # Track the current table so we only print its name when it changes
        current_table = None

        # Loop through every stored check and display its result
        for c in self.checks:
            # Print a section header the first time we see each table name
            if c["table"] != current_table:
                print(f"\n{c['table']}")
                current_table = c["table"]

            # Print PASS / FAIL followed by the rule description
            print(f"  {c['status']}  {c['check']}")

            # Print the optional detail line if one was provided
            if c["detail"]:
                print(f"       → {c['detail']}")

        # Count how many checks passed to compute the summary fraction
        passed = sum(1 for c in self.checks if c["status"] == "PASS")
        total = len(self.checks)

        # BUG FIX: was "SUMARRY" (typo) — corrected to "SUMMARY"
        print(f"\nSUMMARY: {passed}/{total} checks passed")


# ─── 4. LOAD DATA ─────────────────────────────────────────────────────────────
# %%
def load_data(path):
    """Read all sheets from the Excel workbook and return them as DataFrames."""

    # Read every excel sheet into its own df
    xl = pd.read_excel(path, sheet_name=None)

    # Extract each sheet into its own DataFrame 
    orders    = xl["Orders"].copy()
    products  = xl["Products"].copy()
    customers = xl["Customers"].copy()
    returns   = xl["Returns"].copy()
    targets   = xl["Sales Targets"].copy()

    # Confirm how many rows were loaded per table
    print(
        f"[INFO] Loaded: "
        f"Orders={len(orders)}, "
        f"Products={len(products)}, "
        f"Customers={len(customers)}, "
        f"Returns={len(returns)}, "
        f"Targets={len(targets)}"
    )
    # Return all tables
    return orders, products, customers, returns, targets


# ─── 5. DATA PROFILING ────────────────────────────────────────────────────────
# %%
def profile_table(df, name):
    """Print shape, dtypes, nulls, duplicates, and numeric stats for a table."""

    # Print basic table dimensions
    print(f"\nTABLE: {name}")
    print(f"Rows: {len(df)}, Columns: {len(df.columns)}")

    # Show the data type of every column
    print("Column Types:")
    print(df.dtypes)

    # df.info() prints a concise summary; memory_usage=False keeps output clean
    print(df.info(memory_usage=False))

    # --- Null values ---
    # Count missing values per column
    null_counts = df.isnull().sum()
    # Keep only columns that actually have missing values
    null_columns = null_counts[null_counts > 0]

    if null_columns.empty:
        print("No missing values found.")
    else:
        # Report each column with its missing-value count
        for col, n in null_columns.items():
            print(f"  {col}: {n} missing values")

    # --- Duplicates ---
    print(f"Duplicates: {df.duplicated().sum()}")

    # --- Numeric statistics ---
    # Loop through numeric columns only and print min / mean / max
    for col in df.select_dtypes(include="number").columns:
        # describe() returns count, mean, std, min, 25%, 50%, 75%, max
        s = df[col].describe()
        print(
            f"  {col}: "
            f"min={s['min']:.2f}, "
            f"mean={s['mean']:.2f}, "
            f"max={s['max']:.2f}"
        )


# ─── 6. OUTLIER DETECTION ─────────────────────────────────────────────────────
def detect_outliers_iqr(series):
    """Return the count of values that fall outside 1.5 × IQR from Q1/Q3."""

    # First quartile (25th percentile)
    Q1 = series.quantile(0.25)
    # Third quartile (75th percentile)
    Q3 = series.quantile(0.75)
    # Interquartile range — the spread of the middle 50 % of values
    IQR = Q3 - Q1

    # Count values that are too low or too high relative to the IQR fences
    return int(
        (
            (series < Q1 - 1.5 * IQR)   # below lower fence
            |
            (series > Q3 + 1.5 * IQR)   # above upper fence
        ).sum()
    )


# ─── 7. QUALITY CHECKS ────────────────────────────────────────────────────────
# %%
def run_quality_checks(orders, products, customers, returns, targets):
    """Run all validation rules across every table and print the report."""

    # Create a fresh report object to accumulate results
    rpt = DataQualityReport()

    # --- ORDERS ---
    rpt.add("Orders", "No null values",
            orders.isnull().sum().sum() == 0,
            f"{orders.isnull().sum().sum()} nulls found")

    rpt.add("Orders", "No duplicate Order IDs",
            not orders["Order ID"].duplicated().any(),
            f"{orders['Order ID'].duplicated().sum()} dups")

    rpt.add("Orders", "Discount in [0, 0.5]",
            orders["Discount"].between(0, 0.5).all(),
            f"Out-of-range: {(~orders['Discount'].between(0, 0.5)).sum()}")

    rpt.add("Orders", "Valid countries",
            orders["Country"].isin(VALID_COUNTRIES).all(),
            f"Invalid: {orders[~orders['Country'].isin(VALID_COUNTRIES)]['Country'].unique()}")

    rpt.add("Orders", "Valid channels",
            orders["Channel"].isin(VALID_CHANNELS).all())

    rpt.add("Orders", "Ship Date >= Order Date",
            (pd.to_datetime(orders["Ship Date"]) >= pd.to_datetime(orders["Order Date"])).all(),
            f"Violations: {(pd.to_datetime(orders['Ship Date']) < pd.to_datetime(orders['Order Date'])).sum()}")

    rpt.add("Orders", "Positive unit prices",
            (orders["Unit Price"] > 0).all())

    rpt.add("Orders", "Quantity in [1, 5]",
            orders["Quantity"].between(1, 5).all())

    rpt.add("Orders", "Shipping cost non-negative",
            (orders["Shipping Cost"] >= 0).all())

    # --- PRODUCTS ---
    rpt.add("Products", "No null values",
            products.isnull().sum().sum() == 0)

    rpt.add("Products", "No duplicate Product IDs",
            not products["Product ID"].duplicated().any())

    rpt.add("Products", "Valid categories",
            products["Category"].isin(VALID_CATEGORIES).all())

    rpt.add("Products", "Unit Cost < List Price",
            (products["Unit Cost"] < products["List Price"]).all(),
            f"Violations: {(products['Unit Cost'] >= products['List Price']).sum()}")

    # Compute gross margin ratio per product to check profitability floor
    margin = (products["List Price"] - products["Unit Cost"]) / products["List Price"]
    rpt.add("Products", "Gross margin > 10%",
            (margin > 0.10).all(),
            f"Low-margin products: {(margin <= 0.10).sum()}")

    # --- CUSTOMERS ---
    rpt.add("Customers", "No null values",
            customers.isnull().sum().sum() == 0)

    rpt.add("Customers", "No duplicate Customer IDs",
            not customers["Customer ID"].duplicated().any())

    rpt.add("Customers", "Valid segments",
            customers["Segment"].isin(VALID_SEGMENTS).all())

    rpt.add("Customers", "Valid countries",
            customers["Country"].isin(VALID_COUNTRIES).all())

    # --- RETURNS ---
    rpt.add("Returns", "No duplicate Return records",
            not returns["Order ID"].duplicated().any(),
            f"Dup returns: {returns['Order ID'].duplicated().sum()}")

    # Every return must reference an order that actually exists
    rpt.add("Returns", "Return Order IDs exist in Orders",
            returns["Order ID"].isin(orders["Order ID"]).all(),
            f"Orphan returns: {(~returns['Order ID'].isin(orders['Order ID'])).sum()}")

    # --- REFERENTIAL INTEGRITY ---
    # Every order must have a matching customer and product record
    rpt.add("Referential", "All Order Customer IDs exist",
            orders["Customer ID"].isin(customers["Customer ID"]).all())

    rpt.add("Referential", "All Order Product IDs exist",
            orders["Product ID"].isin(products["Product ID"]).all())

    # Print the full report and return the object for further inspection
    rpt.print_report()
    return rpt


# ─── 8. CLEANING FUNCTIONS ────────────────────────────────────────────────────
def clean_orders(df):
    """Standardize dates, country names, discount range, and derive shipping days."""
    df = df.copy()

    # Parse date columns from strings/mixed types to proper datetime objects
    df["Order Date"] = pd.to_datetime(df["Order Date"])
    df["Ship Date"]  = pd.to_datetime(df["Ship Date"])

    # Normalize country names using the alias map, then title-case and strip whitespace
    df["Country"] = df["Country"].replace(COUNTRY_ALIASES).str.strip().str.title()

    # Clamp discounts to the valid range [0, 0.5] — silently fixes edge cases
    df["Discount"] = df["Discount"].clip(0, 0.5)

    # Drop fully-duplicate rows, keeping the first occurrence per Order ID
    before = len(df)
    df.drop_duplicates(subset=["Order ID"], keep="first", inplace=True)
    print(f"[Orders] Removed {before - len(df)} duplicate rows")

    # Derive fulfillment speed as an integer number of calendar days
    df["Shipping Days"] = (df["Ship Date"] - df["Order Date"]).dt.days

    return df


def clean_products(df):
    """Parse launch dates, normalize text fields, and add a margin column."""
    df = df.copy()

    # Parse the product launch date to datetime
    df["Launch Date"] = pd.to_datetime(df["Launch Date"])

    # Normalize category and brand strings
    df["Category"] = df["Category"].str.strip().str.title()
    df["Brand"]    = df["Brand"].str.strip()

    # Compute gross margin as a decimal fraction for downstream analysis
    df["Product Margin Pct"] = (
        (df["List Price"] - df["Unit Cost"]) / df["List Price"]
    )

    return df


def clean_customers(df):
    """Parse acquisition date, normalize segment/country, strip whitespace."""
    df = df.copy()

    # Parse the date when each customer was first acquired
    df["Acquisition Date"] = pd.to_datetime(df["Acquisition Date"])

    # Normalize segment and country labels
    df["Segment"] = df["Segment"].str.strip().str.title()
    df["Country"] = df["Country"].replace(COUNTRY_ALIASES).str.strip().str.title()

    # Strip leading/trailing whitespace from the acquisition channel field
    df["Acquisition Channel"] = df["Acquisition Channel"].str.strip()

    return df


def clean_returns(df):
    """Parse return dates, strip reason text, and deduplicate by Order ID."""
    df = df.copy()

    # Parse return dates to datetime
    df["Return Date"] = pd.to_datetime(df["Return Date"])

    # Strip whitespace from free-text reason field
    df["Reason"] = df["Reason"].str.strip()

    # Keep only the first return record per order to remove duplicates
    df.drop_duplicates(subset=["Order ID"], keep="first", inplace=True)

    return df


def clean_targets(df):
    """Normalize country names and split the Year-Month column into integers."""
    df = df.copy()

    # Normalize country labels to match VALID_COUNTRIES format
    df["Country"] = df["Country"].str.strip().str.title()

    # Split "YYYY-MM" string into separate integer Year and Month columns
    df[["Year", "Month"]] = df["Year-Month"].str.split("-", expand=True)
    df["Year"]  = df["Year"].astype(int)
    df["Month"] = df["Month"].astype(int)

    return df


def run_cleaning_pipeline(orders, products, customers, returns, targets):
    """Apply all cleaning functions in sequence and return the cleaned tables."""
    print("\n[INFO] Running cleaning pipeline...")

    orders_clean    = clean_orders(orders)
    products_clean  = clean_products(products)
    customers_clean = clean_customers(customers)
    returns_clean   = clean_returns(returns)
    targets_clean   = clean_targets(targets)

    print("[INFO] Cleaning complete")
    return orders_clean, products_clean, customers_clean, returns_clean, targets_clean


# ─── MAIN ─────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    # Load all raw tables from the Excel source file
    orders, products, customers, returns, targets = load_data(SOURCE_FILE)

    print("\n" + "=" * 50)
    print("  PHASE 1 — DATA PROFILING")
    print("=" * 50)
    # Profile each table to understand its shape, nulls, and distributions
    for name, df in [
        ("Orders", orders), ("Products", products),
        ("Customers", customers), ("Returns", returns),
        ("Sales Targets", targets),
    ]:
        profile_table(df, name)

    print("\n" + "=" * 50)
    print("  QUALITY CHECKS")
    print("=" * 50)
    # Run all validation rules and print the pass/fail report
    run_quality_checks(orders, products, customers, returns, targets)

    print("\n" + "=" * 50)
    print("  PHASE 2 — CLEANING")
    print("=" * 50)
    # Apply cleaning pipeline and unpack all five cleaned DataFrames
    (orders_c, products_c, customers_c,
     returns_c, targets_c) = run_cleaning_pipeline(
        orders, products, customers, returns, targets
    )

