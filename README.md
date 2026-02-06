# European Pharmacy Sales Profitability Analysis


**Overview**  
This project explores European pharmacy sales data using **SQL for data preparation and querying** and **Power BI for interactive visualization**. The analysis focuses on uncovering sales drivers, profitability patterns, and promotional impacts across different pharmacy types, product categories, and brands.  

**Key Features**  
- **SQL Data Modeling:** Queries to calculate revenue, cost, margin, and category breakdowns.  
- **Power BI Dashboard:** Interactive visuals showing sales distribution, gross margin %, and promotional effects.  
- **Business Insights:**  
  - Urban pharmacies consistently generated higher sales.  
  - Prescription products dominated revenue share.  
  - Branded products outperformed generics in overall sales.  
  - Gross margin averaged **28%**, reflecting competitive pricing pressures in the sector.  
- **Stakeholder Value:** Provides actionable insights into product mix, location strategy, and profitability levers.  

**Deliverables**  
- SQL scripts for data exploration.  
- Power BI dashboard file (.pbix) for data extraction and transformation with interactive visuals.  
- Exported report (PDF/PNG) for quick stakeholder review.  

---

**Data**

### **DimDate**
- `DateKey` – Unique key for each day  
- `Date` – Calendar date  
- `Year`, `Quarter`, `MonthNumber`, `MonthName`, `YearMonth` – Time attributes  

### **DimPharmacy**
- `PharmacyID`, `PharmacyName` – Store identifiers  
- `Country`, `Region`, `City` – Geographic attributes  
- `PharmacyType` – Urban/Suburban/Rural classification  
- `OpenDate` – Store opening date  
- `StoreSizeBand` – Size category (S/M/L)  
- `Latitude`, `Longitude` – Map coordinates  

### **DimProduct**
- `ProductID`, `ProductName` – Product identifiers  
- `Category` – Prescription/OTC grouping  
- `Brand` – Brand family  
- `IsGeneric` – Generic flag  
- `PackSize` – Package format  
- `ListPriceEUR`, `StandardCostEUR` – Base price and cost  
- `LaunchDate` – Product availability date  
- `IsDiscontinued`, `DiscontinuedDate` – Discontinuation details  

### **FactSales**
- `SalesID` – Unique sales record ID  
- `DateKey` – Link to DimDate  
- `PharmacyID` – Link to DimPharmacy  
- `ProductID` – Link to DimProduct  
- `UnitsSold` – Quantity sold  
- `RevenueEUR` – Total revenue  
- `CostEUR` – Total cost  
- `MarginEUR` – Profit (Revenue − Cost)  
- `PromoFlag` – Whether sold under promotion  

---

**Schema**

## 🔹 Disclaimer
*Dataset sourced from the OnyxData & ZoomCharts Jan–Feb Challenge. Analysis, SQL queries, and Power BI dashboards are original work, adapted for portfolio demonstration purposes.*  
 

Would you like me to now **draft the full README structure** (sections like *Introduction, Methodology, SQL Queries, Dashboard Screenshots, Insights, How to Run*) so you can drop it straight into GitHub?
