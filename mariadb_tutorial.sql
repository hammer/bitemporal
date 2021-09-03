-- Versioned tables: : https://mariadb.com/kb/en/system-versioned-tables/
-- Application time periods: https://mariadb.com/kb/en/application-time-periods/
-- Bitemporal tables: https://mariadb.com/kb/en/bitemporal-tables/
-- Invisible columns: https://mariadb.com/kb/en/invisible-columns/
-- Blog post series start: https://mariadb.com/resources/blog/temporal-tables-part-1/

CREATE DATABASE IF NOT EXISTS bitemporal;
USE bitemporal;

-- ***************
-- * System time *
-- ***************

-- WITH SYSTEM VERSIONING syntax invisibly adds these lines
--   row_start TIMESTAMP(6) GENERATED ALWAYS AS ROW START,
--   row_end TIMESTAMP(6) GENERATED ALWAYS AS ROW END,
--   PERIOD FOR SYSTEM_TIME(start_timestamp, end_timestamp)
-- Add "WITHOUT SYSTEM VERSIONING" to a column to ignore updates.
-- Can also put historical data into partition(s)
DROP TABLE IF EXISTS purchaseOrderLines;
CREATE TABLE purchaseOrderLines(
    purchaseOrderID INTEGER NOT NULL
  , LineNum SMALLINT NOT NULL
  , status VARCHAR(20) NOT NULL
  , itemID INTEGER NOT NULL
  , supplierID INTEGER NOT NULL
  , purchaserID INTEGER NOT NULL
  , quantity SMALLINT NOT NULL
  , price DECIMAL (10,2) NOT NULL
  , discountPercent DECIMAL (10,2) NOT NULL
  , amount DECIMAL (10,2) NOT NULL
  , orderDate DATETIME
  , promiseDate DATETIME
  , shipDate DATETIME
  , PRIMARY KEY (purchaseOrderID, LineNum)
) WITH SYSTEM VERSIONING;

-- Not necessary, but demonstrates that system versioned tables can't be truncated.
ALTER TABLE purchaseOrderLines DROP SYSTEM VERSIONING;
TRUNCATE TABLE purchaseOrderLines;
ALTER TABLE purchaseOrderLines ADD SYSTEM VERSIONING;

-- Insert and update some data
INSERT purchaseOrderLines VALUES (1001, 1, 'OPEN', 1, 1, 1, 1, 1, 0, 1, '2019-05-01', NULL, NULL);
UPDATE purchaseOrderLines SET promiseDate = '2019-05-11' WHERE purchaseOrderID = 1001;
UPDATE purchaseOrderLines SET promiseDate = '2019-05-17' WHERE purchaseOrderID = 1001;
UPDATE purchaseOrderLines SET promiseDate = '2019-05-19', status = 'CANCEL' WHERE purchaseOrderID = 1001;

-- FOR SYSTEM_TIME [ALL|AS OF|BETWEEN <X> AND <Y>|FROM <X> TO <Y>]
--   BETWEEN is closed, FROM is right-open
-- Missing FOR SYSTEM_TIME clause => FOR SYSTEM_TIME AS OF CURRENT_TIMESTAMP
-- FOR SYSTEM_TIME HISTORY proposed in https://jira.mariadb.org/browse/MDEV-26044
SELECT
  purchaseOrderID
, lineNum
, row_start
, row_end
FROM purchaseOrderLines 
  FOR SYSTEM_TIME ALL;

-- ********************
-- * Application time *
-- ********************
DROP TABLE IF EXISTS employees;
CREATE TABLE employees (
    empID INTEGER
  , firstName           VARCHAR(100)
  , lastName            VARCHAR(100)
  , departmentName      VARCHAR(20) 
  , startDate           DATETIME NOT NULL
  , endDate             DATETIME NOT NULL
  , PERIOD FOR appl_time(startDate, endDate)
);

INSERT INTO employees VALUES (1, 'John', 'Smith', 'Sales', '2015-01-01', '2018-12-31');

UPDATE employees
  FOR PORTION OF appl_time
FROM '2016-01-01' to '2016-06-30'
  SET departmentName = 'Marketing'
WHERE empId = 1;

SELECT *
FROM employees
WHERE empId = 1
ORDER BY startDate;

DELETE from employees
FOR PORTION OF appl_time
FROM '2016-02-01' to '2016-04-30';

SELECT *
FROM employees
WHERE empId = 1
ORDER BY startDate;

-- **************
-- * Bitemporal *
-- **************
DROP TABLE IF EXISTS employees;
CREATE TABLE employees (
    empID INTEGER
  , firstName               VARCHAR(100)
  , lastName                VARCHAR(100)
  , address                 VARCHAR(100)
  , departmentName          VARCHAR(20)
  , startDate               DATETIME NOT NULL
  , endDate                 DATETIME NOT NULL
  , PERIOD FOR appl_time (startDate, endDate)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 WITH SYSTEM VERSIONING;

INSERT INTO employees VALUES (1, 'Georgi', 'Facello', '1607 23rd Street NW', 'Human Resources', '2017-08-21', '2039-08-21');
INSERT INTO employees VALUES (2, 'Bezalel', 'Simmel', '664 Dickens Road', 'Sales', '2016-08-21', '2039-08-21');
INSERT INTO employees VALUES (3, 'Parto', 'Bamford', '9520 Faires Farm Road', 'Finance', '2012-08-21', '2039-08-21');
INSERT INTO employees VALUES (4, 'Christian', 'Koblick', '526 Superior Avenue\nSuite 1255', 'Engineering', '2012-08-21', '2039-08-21');

SELECT
  empID
  , firstName
  , lastName
  , address
  , departmentName
  , startDate
  , endDate
  , row_start
  , row_end
FROM employees
FOR SYSTEM_TIME ALL
WHERE empID = 3 ORDER BY startDate;

UPDATE employees
  FOR PORTION OF appl_time
FROM '2016-01-01' to '2016-06-30'
  SET departmentName = 'Marketing'
WHERE empId = 3;

SELECT
  empID
  , firstName
  , lastName
  , address
  , departmentName
  , startDate
  , endDate
  , row_start
  , row_end
FROM employees
FOR SYSTEM_TIME ALL
WHERE empID = 3 ORDER BY startDate;

UPDATE employees
  SET address = '239 Rutherford Ave.'
WHERE empId = 3;

SELECT
  empID
  , firstName
  , lastName
  , address
  , departmentName
  , startDate
  , endDate
  , row_start
  , row_end
FROM employees
FOR SYSTEM_TIME ALL
WHERE empID = 3
ORDER BY startDate;
