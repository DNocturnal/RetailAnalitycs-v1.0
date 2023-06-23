DROP TABLE IF EXISTS "DateOfAnalysisFormation";
DROP TABLE IF EXISTS "Stores";
DROP TABLE IF EXISTS "Checks";
DROP TABLE IF EXISTS "ProductGrid";
DROP TABLE IF EXISTS "SKUGroup";
DROP TABLE IF EXISTS "Transactions";
DROP TABLE IF EXISTS "Cards";
DROP TABLE IF EXISTS "PersonalInformation";

CREATE TABLE "PersonalInformation"(
  Customer_ID SERIAL PRIMARY KEY,
  Customer_Name VARCHAR CHECK (Customer_Name ~ '(^[A-Z]([a-z]|-|\s)*|^[А-Я]([а-я]|-|\s)*)'),
  Customer_Surname VARCHAR CHECK (Customer_Surname ~ '(^[A-Z]([a-z]|-|\s)*|^[А-Я]([а-я]|-|\s)*)'),
  Customer_Primary_Email VARCHAR CHECK (Customer_Primary_Email ~ '^[-\w\.]+@([\w]+\.)+[\w]{2,4}$'),
  Customer_Primary_Phone VARCHAR CHECK (Customer_Primary_Phone ~ '^\+7\d{10}$')
);

CREATE TABLE "Cards"(
  Customer_Card_ID SERIAL PRIMARY KEY,
  Customer_ID BIGINT NOT NULL,
  CONSTRAINT fk_Cards_PersonalInformation_Customer_ID FOREIGN KEY (Customer_ID) REFERENCES "PersonalInformation"(Customer_ID)
);

CREATE TABLE "Transactions"(
  Transaction_ID SERIAL PRIMARY KEY UNIQUE,
  Customer_Card_ID BIGINT NOT NULL,
  Transaction_Summ NUMERIC,
  Transaction_DateTime timestamp,
  Transaction_Store_ID BIGINT NOT NULL,
  CONSTRAINT fk_Transactions_Cards_Customer_Card_ID FOREIGN KEY (Customer_Card_ID) REFERENCES "Cards"(Customer_Card_ID)
);

CREATE TABLE "SKUGroup"(
  Group_ID SERIAL PRIMARY KEY,
  Group_Name VARCHAR CHECK (Group_Name ~ '^[A-Za-zА-Яа-яЁё0-9_@!#%&()+-=*\s\[\]{};:''''"\\|,.<>?/`~^$]*$')
);

CREATE TABLE "ProductGrid"(
  SKU_ID SERIAL PRIMARY KEY,
  SKU_Name VARCHAR CHECK (SKU_Name ~ '^[A-Za-zА-Яа-яЁё0-9_@!#%&()+-=*\s\[\]{};:''''"\\|,.<>?/`~^$]*$'),
  Group_ID BIGINT,
  CONSTRAINT fk_ProductGrid_SKUGroup_Group_ID FOREIGN KEY (Group_ID) REFERENCES "SKUGroup"(Group_ID)
);

CREATE TABLE "Checks"(
  Transaction_ID SERIAL PRIMARY KEY,
  SKU_ID BIGINT NOT NULL,
  SKU_Amount NUMERIC,
  SKU_Summ NUMERIC,
  SKU_Sum_Paid NUMERIC,
  SKU_Discount NUMERIC,
  CONSTRAINT fk_Checks_ProductGrid_SKU_ID FOREIGN KEY (SKU_ID) REFERENCES "ProductGrid"(SKU_ID)
);

CREATE TABLE "Stores"(
  Transaction_Store_ID BIGINT NOT NULL,
  SKU_ID BIGINT NOT NULL,
  SKU_Purchase_Price NUMERIC,
  SKU_Retail_Price NUMERIC,
  CONSTRAINT fk_Stores_Transaction_Store_ID FOREIGN KEY (Transaction_Store_ID) REFERENCES "Transactions"(Transaction_ID),
  CONSTRAINT fk_Stores_ProductGrid_SKU_ID FOREIGN KEY (SKU_ID) REFERENCES "ProductGrid"(SKU_ID)
);

CREATE TABLE "DateOfAnalysisFormation"(
  Analysis_Formation timestamp
);

CREATE OR REPLACE PROCEDURE procedure_insert(table_name_ TEXT, directory TEXT, operation_type TEXT, csv_header TEXT, del VARCHAR(1))
    LANGUAGE plpgsql AS
$$
DECLARE
    str TEXT;
BEGIN
    str := 'COPY ' || table_name_ ||
           ' ' || operation_type || '''' || directory ||
           ''' DELIMITER E''' || del ||'''
		   ' || csv_header;
    EXECUTE (str);
END
$$;

CREATE OR REPLACE PROCEDURE procedure_insert_from_csv_file_to_table(table_name_ TEXT, directory TEXT, del VARCHAR(1))
    LANGUAGE plpgsql AS
$$
BEGIN
  CALL procedure_insert(table_name_, directory, 'FROM', 'CSV HEADER', del);
END
$$;

CREATE OR REPLACE PROCEDURE procedure_insert_from_table_to_csv_file(table_name_ TEXT, directory TEXT, del VARCHAR(1))
  LANGUAGE plpgsql AS
$$
BEGIN
  CALL procedure_insert(table_name_, directory, 'TO', 'CSV HEADER', del);
END
$$;

CREATE OR REPLACE PROCEDURE procedure_insert_from_tsv_file_to_table(table_name_ TEXT, directory TEXT)
  LANGUAGE plpgsql AS
$$
DECLARE
  del TEXT;
BEGIN
  del := '\t';
  CALL procedure_insert(table_name_, directory, 'FROM', '', del);
END
$$;

CREATE OR REPLACE PROCEDURE procedure_insert_from_table_to_tsv_file(table_name_ TEXT, directory TEXT)
  LANGUAGE plpgsql AS
$$
DECLARE
  del TEXT;
BEGIN
  del := '\t';
  CALL procedure_insert(table_name_, directory, 'TO', '', del);
END
$$;

SET datestyle = "european";
CALL procedure_insert_from_tsv_file_to_table('"PersonalInformation"', '/Users/noisejaq/Documents/SQL3_RetailAnalitycs_v1.0-1/datasets/Personal_Data_Mini.tsv');
CALL procedure_insert_from_tsv_file_to_table('"Cards"', '/Users/noisejaq/Documents/SQL3_RetailAnalitycs_v1.0-1/datasets/Cards_Mini.tsv');
CALL procedure_insert_from_tsv_file_to_table('"Transactions"', '/Users/noisejaq/Documents/SQL3_RetailAnalitycs_v1.0-1/datasets/Transactions_Mini.tsv');
CALL procedure_insert_from_tsv_file_to_table('"SKUGroup"', '/Users/noisejaq/Documents/SQL3_RetailAnalitycs_v1.0-1/datasets/Groups_SKU_Mini.tsv');
CALL procedure_insert_from_tsv_file_to_table('"ProductGrid"', '/Users/noisejaq/Documents/SQL3_RetailAnalitycs_v1.0-1/datasets/SKU_Mini.tsv');
CALL procedure_insert_from_tsv_file_to_table('"Checks"', '/Users/noisejaq/Documents/SQL3_RetailAnalitycs_v1.0-1/datasets/Checks_Mini.tsv');
CALL procedure_insert_from_tsv_file_to_table('"Stores"', '/Users/noisejaq/Documents/SQL3_RetailAnalitycs_v1.0-1/datasets/Stores_Mini.tsv');
CALL procedure_insert_from_tsv_file_to_table('"DateOfAnalysisFormation"', '/Users/noisejaq/Documents/SQL3_RetailAnalitycs_v1.0-1/datasets/Date_Of_Analysis_Formation.tsv');
