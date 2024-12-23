-- L2_contract
create or replace table agile-producer-437112-g6.L2.L2_contract as
select
  contract_id,
  branch_id,
  contract_valid_from, 
  contract_valid_to,
  registered_date,
  signed_date,
  activation_process_date,
  prolongation_date,
  registration_end_reason,
  flag_prolongation,
  flag_sent_email,
  contract_status
from agile-producer-437112-g6.L1.L1_contract
where registered_date is not null
;

-- compare counts OK
select count(*)
from agile-producer-437112-g6.L2.L2_contract
union all
select count(*)
from agile-producer-437112-g6.L1.L1_contract
;


-- L2_invoice
create or replace table agile-producer-437112-g6.L2.L2_invoice as
select
  l1_invoice.invoice_id,
  l1_invoice.contract_id,
  l1_invoice.date_issue,
  l1_invoice.due_date,
  l1_invoice.paid_date,
  l1_invoice.start_date,
  l1_invoice.end_date,
  l1_invoice.amount_w_vat,
  case
    when l1_invoice.amount_w_vat <= 0 then 0
    when l1_invoice.amount_w_vat > 0 then l1_invoice.amount_w_vat / 1.2
  end as amount_wo_vat, -- why are some amounts <= 0
  l1_invoice.date_insert,
  l1_invoice.update_date,
  l1_invoice.branch_id,
  row_number() over (partition by l1_invoice.contract_id order by l1_invoice.date_issue asc) as invoice_order -- enumerate rows based on issue date
from agile-producer-437112-g6.L1.L1_invoice as l1_invoice
join agile-producer-437112-g6.L2.L2_contract as l2_contract
on l1_invoice.contract_id = l2_contract.contract_id -- invoices that have contracts in L2
where
  l1_invoice.invoice_type = "invoice"
  and l1_invoice.flag_invoice_issued -- invoices that have been sent
;

-- compare counts 583 568 vs 3 548 680	
select count(*)
from agile-producer-437112-g6.L2.L2_invoice
union all
select count(*)
from agile-producer-437112-g6.L1.L1_invoice
;


-- L2_product
create or replace table agile-producer-437112-g6.L2.L2_product as
select
  product_id,
  product_name,
  product_type,
  product_category
from agile-producer-437112-g6.L1.L1_product
where product_category in ("product", "rent")
;

-- compare counts 198 vs 230; excluded "other"
select count(*)
from agile-producer-437112-g6.L2.L2_product
union all 
select count(*)
from agile-producer-437112-g6.L1.L1_product
;


-- L2_product_purchase
create or replace table agile-producer-437112-g6.L2.L2_product_purchase as
select
  product_purchase_id,
  contract_id,
  product_id,
  create_date,
  product_valid_from,
  product_valid_to,
  price_wo_vat,
  price_wo_vat * 1.2 as price_w_vat,
  date_update,
  product_name,
  product_type,
  if (product_valid_to = '2035-12-31', true, false) as flag_unlimited_product
from agile-producer-437112-g6.L1.L1_product_purchase
where true
  and product_category in ("product", "rent")
  and product_id in (select product_id from agile-producer-437112-g6.L2.L2_product)
;
