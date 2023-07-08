# RetailAnalytics v1.0

Retail analytics data upload, its simple analysis, statistics, customer segmentation and creation of personal offers.

## 1. Creating a database

Write a *part1.sql* script that creates the database and tables described above in the [Input data](#input-data).

Also, add procedures to the script that allow you to import and export data for each table from/to a file with *.csv* and *.tsv* extensions. \
A separator is specified as a parameter of each procedure for importing from a *csv* file.

## 2. Creating views

Create a *part2.sql* script and write the views described above in the Output data. Also add test queries for each view. It is acceptable to create a separate script starting with *part2_* for each view.

You can find more information for each field in the materials.

## 3. Role model

Create roles in the *part3.sql* script and give them permissions as described below.

#### Administrator
The administrator has full permissions to edit and view any information, start and stop the processing.

#### Visitor
Only view information of all tables.

## 4. Forming personal offers aimed at the growth of the average check

### Write a function that determines offers that aimed at the growth of the average check
Function parameters:
- average check calculation method (1 - per period, 2 - per quantity)
- first and last dates of the period (for method 1)
- number of transactions (for method 2)
- coefficient of average check increase
- maximum churn index
- maximum share of transactions with a discount (in percent)
- allowable share of margin (in percent)


## Part 5. Forming personal offers aimed at increasing the frequency of visits

Create a *part5.sql* script and add the following function to it.

### Write a function that determines offers aimed at increasing the frequency of visits
Function parameters:
- first and last dates of the period
- added number of transactions
- maximum churn index
- maximum share of transactions with a discount (in percent)
- allowable margin share (in percent)

## 6. Forming personal offers aimed at cross-selling

Create a *part6.sql* script and add the following function to it.

### Write a function that determines offers aimed at cross-selling (margin growth)
Function parameters:
- number of groups
- maximum churn index
- maximum consumption stability index
- maximum SKU share (in percent)
- allowable margin share (in percent)

