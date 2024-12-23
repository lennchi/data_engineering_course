-- create external tables for L0
-- accounting system
create or replace external table `agile-producer-437112-g6.L0_accounting_system.invoice`
options (
  format = 'CSV',
  uris = ['gs://revolt_accounting_system/invoice.csv'],
  skip_leading_rows = 1
);

create or replace external table `agile-producer-437112-g6.L0_accounting_system.invoice_load`
options (
  format = 'CSV',
  uris = ['gs://revolt_accounting_system/invoices_load.csv'],
  skip_leading_rows = 1
);

-- crm
create or replace external table `agile-producer-437112-g6.L0_crm.contract`
options (
  format = 'CSV',
  uris = ['gs://revolt_crmm/contracts.csv'],
  skip_leading_rows = 1
);

create or replace external table `agile-producer-437112-g6.L0_crm.product_purchase`
options (
  format = 'CSV',
  uris = ['gs://revolt_crmm/product_purchases.csv'],
  skip_leading_rows = 1
);

-- google sheets
create or replace external table `agile-producer-437112-g6.L0_google_sheets.status`
options (
  format = 'GOOGLE_SHEETS',
  uris = ['https://docs.google.com/spreadsheets/d/1Sy_5BZZ_rDGq79v1N0PcDXVLmK2RuOik_RgrdH16_ns/edit?gid=0#gid=0'],
  skip_leading_rows = 1
);

create or replace external table `agile-producer-437112-g6.L0_google_sheets.all_products`
options (
  format = 'GOOGLE_SHEETS',
  uris = ['https://docs.google.com/spreadsheets/d/1m6xDFZdVkr671ot1zUUcVpUNDP7wKN_gZDfEhXsB9DQ/edit?gid=1174952767#gid=1174952767'],
  skip_leading_rows = 1
);

create or replace external table `agile-producer-437112-g6.L0_google_sheets.branch`
options (
  format = 'GOOGLE_SHEETS',
  uris = ['https://docs.google.com/spreadsheets/d/1Sy_5BZZ_rDGq79v1N0PcDXVLmK2RuOik_RgrdH16_ns/edit?gid=1710515388#gid=1710515388'],
  skip_leading_rows = 1
);



-- drop table `agile-producer-437112-g6.LO_accounting_system.acc_sys_invoice_load`;

-- drop table `agile-producer-437112-g6.LO_accounting_system.acc_sys_invoice`;
