--this Rui's sql code to modified based on Xiaowei's SQLs/get_labels
create table #tmpTargetDate

(
	TargetDate Datetime -- cutoff_date, for create table, need var name and var type
)
diststyle all;

INSERT INTO #tmpTargetDate
	(TargetDate)
VALUES
(
	'$cutoff_date' -- Interface for setting cut-off date.
);

Create table #tmpDate --Generate Last One Year Data by month. And Future 3 Month Data.
(
	Month0 Datetime, 
	Month1 Datetime, 
	Month2 Datetime, 
	Month3 Datetime, 
	Month4 Datetime, 
	Month5 Datetime, 
	Month6 Datetime, 
	Month12 Datetime, 
	Month18 Datetime,
	Month24 Datetime,
    Month
)
diststyle all;

Insert into #tmpDate
Select 
	dateadd(month, 	0, t.TargetDate),
	dateadd(month, -1, t.TargetDate),
	dateadd(month, -2, t.TargetDate),
	dateadd(month, -3, t.TargetDate),
	dateadd(month, -4, t.TargetDate),
	dateadd(month, -5, t.TargetDate),
	dateadd(month, -6, t.TargetDate),
	dateadd(month, -12, t.TargetDate),
	dateadd(month, -18, t.TargetDate),
	dateadd(month, -24, t.TargetDate)
FROM #tmpTargetDate as t
;

Create temp table #tmpDoctorID
(
	DoctorID varchar(30) 
)
sortkey
( 
	DoctorID 
);

Insert into #tmpDoctorID
Select 
	Distinct a.AccountID
From fct.[Order] as o 
Inner Join dim.Accounts as a on o.DoctorID = a.AccountID 
	and a.AccountClosed = 0 and a.IsTestAccount = 0 and a.InHouseAccount = 0 AND a.codonly = 0
Cross Join #tmpDate as d 	
Where 
    o.DateInvoicedLocalDTS between '2010-01-01' and d.Month0
and 
    o.originfacilityid in (10) --,20) -- '10' means only GL.
and 
    o.ordertype = 'New' --That means doctor still orders something.
-- limit 5000;
;

CREATE TABLE #tmpExcludeProductLines
            (
              ProductLine VARCHAR(50) PRIMARY KEY
            )
;
        INSERT  INTO #tmpExcludeProductLines
                ( ProductLine
                )
                SELECT
                    'SHIPPING'
                UNION
                SELECT
                    'SAMPLE'
                UNION
                SELECT
                    'license'
                UNION
                SELECT
                    'literature'
                UNION
                SELECT
                    'ped sample sales'
                UNION
                SELECT
                    'training courses'
;

Update #tmpExcludeProductLines
SET ProductLine = upper(ProductLine)
;

CREATE TABLE #tmpOrderItem
    (
      OrderID INT,
      DoctorID VARCHAR(50) ,
      DateInvoiced DATETIME ,
      TotalCharge decimal(14,2) ,
      PF_ProductGroup VARCHAR(50) ,
      PF_ProductLine VARCHAR(50),
      Quantity NUMERIC(11,5)
      
      -- TransactionType VARCHAR(50) ,
      -- RemakeDiscount decimal(14,2) ,
      -- Discount decimal(14,2) ,
      -- ProductID VARCHAR(50) ,
	  -- DiscountID varchar(60), 
	  -- DueDateLocalDTS datetime, 
	  -- OrderProductID int, 
	  -- PF_DepartmentID varchar(120), 
	  -- 
    )
-- diststyle all
distkey
(
	DoctorID
)
sortkey
( 
	DateInvoiced,
	OrderID,
    PF_ProductGroup,
    PF_ProductLine,
    DoctorID
	-- OrderProductID,
	-- TransactionType,
	-- TotalCharge,
	-- RemakeDiscount, 
	-- Discount,
	-- DiscountID, 
	-- DueDateLocalDTS, 
	-- PF_DepartmentID
  
);

INSERT  INTO #tmpOrderItem
        ( 
		  OrderID ,
          DoctorID ,
          DateInvoiced ,
          TotalCharge ,
          PF_ProductGroup ,
          PF_ProductLine,
          Quantity
          -- TransactionType ,
          -- RemakeDiscount ,
          -- Discount ,
          -- ProductID ,
		  -- DiscountID, 
		  -- DueDateLocalDTS, 
		  -- OrderProductID, 
		  -- PF_DepartmentID, 
		  
        )
        SELECT
            o.OrderID ,
            o.DoctorID ,
            o.DateInvoicedLocalDTS ,
            oi.TotalCharge ,
            p.PF_ProductGroup ,
            p.PF_ProductLine,
			oi.Quantity
/* 			oi.TransactionType ,
            oi.RemakeDiscount ,
            oi.Discount ,
            oi.ProductID ,
			oi.discountid, 
			o.duedatelocaldts, 
			oi.OrderProductID, 
			p.PF_DepartmentID, 
 */			
        FROM
            fct.Order AS o 
			Inner join #tmpDoctorID as di on o.DoctorID = di.DoctorID
			Inner Join #tmpDate as d on o.dateinvoicedlocaldts BETWEEN '2010-01-01' AND d.Month0
            INNER JOIN fct.OrderItem AS oi 
                                                      ON oi.OrderID = o.OrderID
            INNER JOIN dim.Products AS p 
                                                      ON p.ProductID = oi.ProductID
                                                      AND upper(p.PF_ProductLine) NOT IN (
	                                                      Select ProductLine from #tmpExcludeProductLines )
												      AND p.PF_DepartmentID NOT IN ( 'GLIDEWELL DIRECT' )
                                                      AND p.pf_isactualunit = 1
                                                      AND UPPER(oi.transactiontype) in ('NEW')
        -- GROUP BY o.orderid, o.doctorid, o.DateInvoicedLocalDTS
;

SELECT toi.doctorid, toi.orderid, toi.dateinvoiced, 'pg_' + toi.pf_productgroup AS product_group, 
       'pl_' + toi.pf_productline AS product_line, 
       sum(toi.totalcharge) AS totalcharge, sum(toi.quantity) AS totalquantity
FROM #tmpOrderItem AS toi
GROUP BY toi.doctorid, toi.orderid, toi.dateinvoiced, toi.pf_productgroup, toi.pf_productline
;



