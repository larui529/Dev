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
    Month1Future Datetime,
    Month3Future Datetime,
    Month6Future Datetime,
    Month9Future Datetime,
    MOnth12Future Datetime
)
diststyle all;

Insert into #tmpDate
Select 
	dateadd(month, 	0, t.TargetDate), --previous month
	dateadd(month, -1, t.TargetDate),
	dateadd(month, -2, t.TargetDate),
	dateadd(month, -3, t.TargetDate),
	dateadd(month, -4, t.TargetDate),
	dateadd(month, -5, t.TargetDate),
	dateadd(month, -6, t.TargetDate),
	dateadd(month, -12, t.TargetDate),
	dateadd(month, -18, t.TargetDate),
	dateadd(month, -24, t.TargetDate),
    dateadd(month, +1, t.TargetDate), --the future month
    dateadd(month, +3, t.TargetDate),
    dateadd(month, +6, t.TargetDate),
    dateadd(month, +9, t.TargetDate),
    dateadd(month, +12, t.TargetDate)
FROM #tmpTargetDate as t
;

--DEBUG
-- select * from #tmpDate;


Create temp table #tmpDoctorID -- this is to creat a tmp table with doctor who ordered in given time period
(
	DoctorID varchar(30) 
)
sortkey -- sort key is a way to sort output data
( 
	DoctorID 
);
-- the @DoctorIDs@ parameter below's format is like ('10-1234567')

Insert into #tmpDoctorID
Select 
	Distinct a.AccountID
From fct.[Order] as o 
Inner Join dim.Accounts as a on o.DoctorID = a.AccountID -- doctor who ordered before
	and a.AccountClosed = 0 and a.IsTestAccount = 0 and a.InHouseAccount = 0 AND a.codonly = 0 -- some accounts are created for test
Cross Join #tmpDate as d -- cross join with tmp table date to define doctors ordered product in certain time
Where 
    o.DateInvoicedLocalDTS between '2010-01-01' and d.Month0 -- ordered product from '2010-01-01' to now
and 
    o.originfacilityid in (10) --,20) -- '10' means only GL.
and 
    o.ordertype = 'New' --That means doctor still orders something.
-- limit 5000;
;

CREATE TABLE #tmpExcludeProductLines --some productline need to be exclude for the orders
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

Update #tmpExcludeProductLines -- update all the tmpExcludeProductline to be upper case
SET ProductLine = upper(ProductLine)
;

CREATE TABLE #tmpIncludeProductLines
    (
        ProductLine VARCHAR(50) PRIMARY KEY
    )
;
    INSERT INTO #tmpIncludeProductLines
        (
            SELECT  'BIOTEMPS' union
			SELECT  'BRUXZIR' union
			SELECT  'CAPTEK' union
			SELECT  'COMPOSITE' union
			SELECT  'CUSTOM ABUTMENT' union
			SELECT  'CZ' union
			SELECT  'DENTURE' union
			SELECT  'DESIGN' union
			SELECT  'DWAX' union
			SELECT  'EMAX' union
			SELECT  'EMPRESS' union
			SELECT  'FLIPPER' union
			SELECT  'FULL CAST' union
			SELECT  'GZ' union
			SELECT  'IMPLANT' union
			SELECT  'IMPLANT BAR' union
			SELECT  'IMPLANT DENTURE' union
			SELECT  'IMPLANT INCLUSIVE' union
			SELECT  'IMPLANT MANUF COMPONENT' union
			SELECT  'IMPLANT FLIPPER' union
			SELECT  'IMPLANT MISC' union
			SELECT  'IMPLANT SMILE COMPOSER' UNION
			SELECT  'IMPLANT STENT' union
			SELECT  'LAVA' union
			SELECT  'LAVA ULTIMATE' union
			SELECT  'NIGHTGUARD' union
			SELECT  'OBSIDIAN' union
			SELECT  'OVERDENTURE' union
			SELECT  'PARTIAL' union
			SELECT  'PFM' union
			SELECT  'PLAYSAFE' union
			SELECT  'PREMISE' union
			SELECT  'PROCERA' union
			SELECT  'RETAINER' union
			SELECT  'SLEEP DEVICE' union
			SELECT  'VALPLAST'
        )
;


CREATE TABLE #tmpOrderItem
    (
      OrderID INT, -- order id
      DoctorID VARCHAR(50) ,
      DateInvoiced DATETIME , --order invoced date
      TotalCharge decimal(14,2) , -- price
      PF_ProductGroup VARCHAR(50) , -- product group
      PF_ProductLine VARCHAR(50), -- product line
      Quantity NUMERIC(11,5), -- number of purchase
      TransactionType VARCHAR(50) , -- type of transactions 
      RemakeDiscount decimal(14,2) , -- discount for the remake
      Discount decimal(14,2) , -- discount on this order
      ProductID VARCHAR(50) , -- product ID of this order
	  DiscountID varchar(60), -- discount ID 
	  DueDateLocalDTS datetime,  --due date of this order
	  OrderProductID int, -- order product ID 
	  PF_DepartmentID varchar(120) 
	  -- 
    )
-- diststyle all
distkey
(
	DoctorID -- distkey usually split data evenly in slice
)
sortkey
( 
	DateInvoiced,
	OrderID,
    PF_ProductGroup,
    PF_ProductLine,
    DoctorID,
	OrderProductID,
	TransactionType,
	RemakeDiscount, 
	TotalCharge,
	Discount,
	DiscountID, 
	DueDateLocalDTS, 
	PF_DepartmentID
  
);

INSERT  INTO #tmpOrderItem
        ( 
		  OrderID ,
          DoctorID ,
          DateInvoiced ,
          TotalCharge ,
          PF_ProductGroup ,
          PF_ProductLine,
          Quantity,
          TransactionType ,
          RemakeDiscount ,
          Discount ,
          ProductID ,
		  DiscountID, 
		  DueDateLocalDTS, 
		  OrderProductID, 
		  PF_DepartmentID, 
		  
        )
        SELECT
            o.OrderID ,
            o.DoctorID ,
            o.DateInvoicedLocalDTS ,
            oi.TotalCharge ,
            p.PF_ProductGroup ,
            p.PF_ProductLine,
			oi.Quantity,
 			oi.TransactionType ,
            oi.RemakeDiscount ,
            oi.Discount ,
            oi.ProductID ,
			oi.discountid, 
			o.duedatelocaldts, 
			oi.OrderProductID, 
			p.PF_DepartmentID, 
 			
        FROM
            fct.Order AS o  
			Inner join #tmpDoctorID as di on o.DoctorID = di.DoctorID
			Inner Join #tmpDate as d on o.dateinvoicedlocaldts BETWEEN '2010-01-01' AND d.Month0 -- order of time from '2010-01-01' to now
            INNER JOIN fct.OrderItem AS oi 
                                                      ON oi.OrderID = o.OrderID
            INNER JOIN dim.Products AS p 
                                                      ON p.ProductID = oi.ProductID
                                                      AND upper(p.PF_ProductLine) IN (
	                                                      Select ProductLine from #tmpIncludeProductLines )
												      AND p.PF_DepartmentID NOT IN ( 'GLIDEWELL DIRECT' )
                                                      AND p.pf_isactualunit = 1
                                                      AND UPPER(oi.transactiontype) in ('NEW')
        -- GROUP BY o.orderid, o.doctorid, o.DateInvoicedLocalDTS
;

CREATE TABLE #tmpAccountMonth
    (
        DoctorID VARCHAR (30) ,
        RowID VARCHAR (100), 
        Month1 DATETIME ,
        Month2 DATETIME ,
        Month3 DATETIME ,
	    Month4 DATETIME ,
	    Month5 DATETIME ,
        Month6 DATETIME ,
        Month12 DATETIME ,
        Month18 DATETIME ,
        Month24 DATETIME, 
	    Month0 DATETIME,
	    Month1Future DATETIME,
	    Month3Future DATETIME,
	    Month6Future DATETIME,
	    Month9Future DATETIME,
	    Month12Future DATETIME
    )
diststyle all
sortkey
(
    DoctorID
)
;

INSERT INTO #tmpAccountMonth
       SELECT d.DoctorID,
        concat(CAST (trunc(t.Month0) as varchar (10)), concat (cast (' ' as varchar(1)), d.DoctorID)) as RowID,
        t.Month1, 
		t.Month2, 
		t.Month3, 
		t.Month4, 
		t.Month5, 
		t.Month6, 
		t.Month12, 
		t.Month18, 
		t.Month24,
		t.Month0,
		t.Month1Future,
		t.Month3Future,
		t.Month6Future,
		t.Month9Future,
		t.Month12Future
    from #tmpDoctorID as d
    cross join #tmpDate as t
;

-- select * from #tmpAccountMonth limit 100;
-- DEBUG

-----------------------------------------
---Doctor/Month total sales
-----------------------------------------

SELECT
    cd.DoctorID ,
    cd.Month0 ,

    SUM(CASE WHEN s.DateInvoiced BETWEEN cd.Month1 AND cd.Month0
             THEN SUM(ISNULL(s.TotalCharge, 0))
             ELSE 0
        END) AS Month1_NetSales ,
    SUM(CASE WHEN s.DateInvoiced BETWEEN cd.Month2 AND cd.Month0
             THEN SUM(ISNULL(s.TotalCharge, 0))
             ELSE 0
        END) AS Month2_NetSales ,
    SUM(CASE WHEN s.DateInvoiced BETWEEN cd.Month3 AND cd.Month0
             THEN SUM(ISNULL(s.TotalCharge, 0))
             ELSE 0
        END) AS Month3_NetSales ,
    SUM(CASE WHEN s.DateInvoiced BETWEEN cd.Month6 AND cd.Month0
             THEN SUM(ISNULL(s.TotalCharge, 0))
             ELSE 0
        END) AS Month6_NetSales ,
    SUM(CASE WHEN s.DateInvoiced BETWEEN cd.Month12 AND cd.Month0
             THEN SUM(ISNULL(s.TotalCharge, 0))
             ELSE 0
        END) AS Month12_NetSales ,
    SUM(CASE WHEN s.DateInvoiced BETWEEN cd.Month18 AND cd.Month0
             THEN SUM(ISNULL(s.TotalCharge, 0))
             ELSE 0
        END) AS Month18_NetSales ,
    SUM(CASE WHEN s.DateInvoiced BETWEEN cd.Month24 AND cd.Month0
             THEN SUM(ISNULL(s.TotalCharge, 0))
             ELSE 0
        END) AS Month24_NetSales ,
	SUM(CASE WHEN s.DateInvoiced BETWEEN cd.Month0 AND cd.Month1Future
             THEN SUM(ISNULL(s.TotalCharge, 0))
             ELSE 0
        END) AS Month1Future_NetSales ,
	SUM(CASE WHEN s.DateInvoiced BETWEEN cd.Month0 AND cd.Month3Future
             THEN SUM(ISNULL(s.TotalCharge, 0))
             ELSE 0
        END) AS Month3Future_NetSales ,
	SUM(CASE WHEN s.DateInvoiced BETWEEN cd.Month0 AND cd.Month6Future
             THEN SUM(ISNULL(s.TotalCharge, 0))
             ELSE 0
        END) AS Month6Future_NetSales ,
	SUM(CASE WHEN s.DateInvoiced BETWEEN cd.Month0 AND cd.Month9Future
             THEN SUM(ISNULL(s.TotalCharge, 0))
             ELSE 0
        END) AS Month9Future_NetSales ,
	SUM(CASE WHEN s.DateInvoiced BETWEEN cd.Month0 AND cd.Month12Future
             THEN SUM(ISNULL(s.TotalCharge, 0))
             ELSE 0
        END) AS Month12Future_NetSales ,
    SUM(CASE WHEN s.DateInvoiced <= cd.Month0 
			 THEN SUM(ISNULL(s.TotalCharge, 0))
             ELSE 0
        END) AS TotalHistoricalSales
-- INTO
    -- #doctorMonthlyNetSales
FROM
    #tmpAccountMonth AS cd 
    INNER JOIN #tmpOrderItem AS s 
                                       ON s.DoctorID = cd.DoctorID
GROUP BY
    cd.DoctorID ,
    cd.Month0
ORDER BY
    cd.DoctorID ,
    cd.Month0
;