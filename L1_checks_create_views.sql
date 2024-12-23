-- create L1 views


-- CONTRACT
-- check if contract id is unique
select 
  contract_id,
  count(*) as cnt
from `agile-producer-437112-g6.L1.L1_contract`
group by contract_id
having cnt > 1
;

-- check if contract_id is null
select *
from `agile-producer-437112-g6.L1.L1_contract`
where contract_id is null
;

-- create L1_contract
create or replace view agile-producer-437112-g6.L1.L1_contract as
select
  id_contract as contract_id,
  id_branch as branch_id,
  date(date_contract_valid_from, "Europe/Prague") as contract_valid_from,
  date(timestamp(date_contract_valid_to), "Europe/Prague") as contract_valid_to,
  date(date_registered, "Europe/Prague") as registered_date,
  date(date_signed, "Europe/Prague") as signed_date,
  date(activation_process_date, "Europe/Prague") as activation_process_date,
  date(prolongation_date, "Europe/Prague") as prolongation_date,
  registration_end_reason,
  flag_prolongation,
  -- Invoce status. Invoice status < 100  have been issued. >= 100 - not issued HOW DOES INVOICE COME INTO PLAY HERE
  flag_send_inv_email as flag_sent_email,
  contract_status
from `agile-producer-437112-g6.L0_crm.contract`
;


-- PRODUCT
-- create L1_product
create or replace view agile-producer-437112-g6.L1.L1_product as
select
  distinct id_product as product_id,
  name as product_name,
  type as product_type,
  category as product_category 
from `agile-producer-437112-g6.L0_google_sheets.all_products`
;


-- create L1_product_status
create or replace view agile-producer-437112-g6.L1.L1_product_status as
select
  id_status as product_status_id,
  status_name as product_status_name
from `agile-producer-437112-g6.L0_google_sheets.status`
;


-- create L1_product_purchase
create or replace view agile-producer-437112-g6.L1.L1_product_purchase as
with ps as (
  select *
  from `agile-producer-437112-g6.L1.L1_product_status`
  ),
  p as (
  select *
  from `agile-producer-437112-g6.L1.L1_product`
  )
  select 
    id_package as product_purchase_id,
    id_contract as contract_id,
    id_package_template	as product_id,
    date(date_insert, "Europe/Prague") as create_date,
    date(timestamp(start_date), "Europe/Prague") as product_valid_from,
    date(timestamp(end_date), "Europe/Prague") as	product_valid_to,
    fee as price_wo_vat,
    date(pp.date_update, "Europe/Prague") as date_update,
    package_status as	product_status_id,
    product_status_name as product_status,
    product_name,
    product_type,
    product_category
  from `agile-producer-437112-g6.L0_crm.product_purchase` as pp
  left join ps on pp.package_status = ps.product_status_id
  left join p on pp.id_package_template = p.product_id
  ;


-- INVOICE
-- check for null primary keys
 select count(*)
 from `agile-producer-437112-g6.L0_accounting_system.invoice`
 where id_invoice is null
 ;

-- see if all invoice ids are unique
 select id_invoice, count(*) as cnt
from `agile-producer-437112-g6.L0_accounting_system.invoice`
group by id_invoice
having cnt > 1
;

--checking and removing dupes
select *
from `agile-producer-437112-g6.L0_accounting_system.invoice`
qualify row_number() over (partition by id_invoice) = 1
;

--check old_invoice_id
select id_invoice_old, count(*) as cnt
from `agile-producer-437112-g6.L0_accounting_system.invoice`
group by id_invoice_old
having cnt > 1
order by cnt desc
;                                                             -- Are dupes okay in old invoice ids?? Ask the client--

-- rename columns, change datetime to Prague time zone, set values for invoice_type and flag_invoice_issued
-- create L1_invoice
create or replace view agile-producer-437112-g6.L1.L1_invoice as
select
  id_invoice as invoice_id,
  id_invoice_old as invoice_previous_id,
  invoice_id_contract as contract_id,
  date(date, "Europe/Prague") as date_issue,
  date(scadent, "Europe/Prague") as due_date,
  date(date_paid, "Europe/Prague") as paid_date,
  date(start_date, "Europe/Prague") as start_date,
  date(end_date, "Europe/Prague") as end_date,
  value as amount_w_vat,
  invoice_type as invoice_type_id,
  case                                                        -- Invoice_type: 1 - invoice, 3 -  credit_note, 2 - return, 4 - other
    when invoice_type = 1 then "invoice"
    when invoice_type = 2 then "return"
    when invoice_type = 3 then "credit_note"
    when invoice_type = 4 then "other"
  end as invoice_type,                                  
  value_storno as return_w_vat,
  date(date_insert, "Europe/Prague") as date_insert,
  status as invoice_status_id,
  if(status < 100, true, false) as flag_invoice_issued,       -- Invoice status. Invoice status < 100  have been issued. >= 100 - not issued
  date(date_update, "Europe/Prague") as update_date,
  id_branch as branch_id,
from `agile-producer-437112-g6.L0_accounting_system.invoice`
;

  