-- L3 explorations


-- L3_invoice
create or replace table agile-producer-437112-g6.L3.L3_invoice as
select 
  contract_id,
  sum(amount_wo_vat) as rev_per_contract
from agile-producer-437112-g6.L2.L2_invoice
where paid_date is not null                                           -- only paid invoices
group by contract_id
; 


-- L3_pp_product_contract
create or replace table agile-producer-437112-g6.L3.L3_pp_product_contract as
select
  pp.product_purchase_id,
  pp.contract_id,
  pp.product_id,
  pp.product_valid_from,
  pp.product_valid_to,
  date_diff(product_valid_to, product_valid_from, day) as product_life,
  pp.price_wo_vat,
  pp.product_name,
  pp.product_type,
  c.contract_valid_from,
  c.contract_valid_to,
  date_diff(contract_valid_to, contract_valid_from, day) as contract_duration,
  c.prolongation_date,
  c.contract_status
from agile-producer-437112-g6.L2.L2_product_purchase as pp
join agile-producer-437112-g6.L2.L2_contract as c
  on pp.contract_id = c.contract_id
;

select count(contract_id)
from agile-producer-437112-g6.L3.L3_pp_product_contract
limit 10
;


-- L3_contract_duration_bins

create or replace table agile-producer-437112-g6.L3.L3_contract_duration_bins as
select
  case
    when contract_duration <= 30 then "M1"
    when contract_duration <= 61 then "M2"
    when contract_duration <= 91 then "M3"
    when contract_duration <= 122 then "M4"
    when contract_duration <= 152 then "M5"
    when contract_duration <= 183 then "M6"
    when contract_duration <= 365 then "M6-M12"
    when contract_duration <= 1230 then "Y2"
    else "Y2+"
  end as contract_duration,
  count(distinct contract_id) as cnt
from agile-producer-437112-g6.L3.L3_pp_product_contract
where contract_valid_to is not null
group by contract_duration
order by contract_duration
;




-- 1. BUYING BEHAVIOR


-- Average revenue per customer (based on paid invoices)
select (sum(rev_per_contract) / count(contract_id)) as rev_per_cust
from agile-producer-437112-g6.L3.L3_invoice
;


-- Median revenue per customer
select approx_quantiles(rev_per_customer, 2)[offset(1)] as median
from (
  select sum(amount_wo_vat) / count(distinct contract_id) as rev_per_customer
  from agile-producer-437112-g6.L2.L2_invoice
  where paid_date is not null
)
;


-- Customer quartiles by revenue per customer
create or replace table agile-producer-437112-g6.L3.L3_invoice_pp as
with combined_data as (
    select
        i.contract_id,
        i.invoice_id,
        i.paid_date,
        i.amount_wo_vat,
        pp.product_purchase_id,
        pp.product_type,
        pp.product_valid_from,
        pp.product_valid_to
    from agile-producer-437112-g6.L2.L2_invoice i
    left join agile-producer-437112-g6.L2.L2_product_purchase pp
        on i.contract_id = pp.contract_id
    where i.paid_date is not null
), 
revenue_per_customer as (
    select
        contract_id,
        sum(amount_wo_vat) as total_revenue,
        count(product_purchase_id) as total_purchases
    from combined_data
    group by contract_id
),
revenue_segments as (
    select
        *,
        case
            when total_revenue <= percentile_cont(total_revenue, 0.25) over () then 'Light spenders (bottom quartile)'
            when total_revenue <= percentile_cont(total_revenue, 0.50) over () then 'Moderate spenders (3rd quartile)'
            when total_revenue <= percentile_cont(total_revenue, 0.75) over () then 'Heavy spenders (2nd quartile)'
            else 'Superstars (top quartile)'
        end as revenue_segment
    from revenue_per_customer
)
select
    revenue_segment,
    count(distinct contract_id) as num_customers,
    cast(sum(total_revenue) as int64) as total_revenue,
    sum(total_purchases) as total_purchases,
from revenue_segments
group by revenue_segment
order by revenue_segment
;




-- 2. CUSTOMER CHURN

-- Customers churned
-- create or replace table agile-producer-437112-g6.L3.L3_customers_churned as
select *
from agile-producer-437112-g6.L3.L3_pp_contract
where true
  and contract_valid_to = product_valid_to
  and contract_valid_to < '2024-09-01'
order by product_lifecycle desc
;


-- Were these customers using other products as well?
select c.contract_id, count(c.contract_id) as cnt
from agile-producer-437112-g6.L3.L3_pp_contract c
join (select *
      from agile-producer-437112-g6.L3.L3_pp_contract
      where true
        and contract_valid_to = product_valid_to
        and contract_valid_to < '2024-09-01') ch
on c.contract_id = ch.contract_id
group by c.contract_id
having cnt > 1
order by cnt desc
limit 50;


-- Total number of unique customers (contracts)
-- 117 643 unique where contract_valid_from is not null
select count(distinct contract_id)
from agile-producer-437112-g6.L1.L1_contract
where contract_valid_from is not null
;


-- How many get a trial first?
-- 30 665 unique where product_valid_from is not null => about 1/4
select count(distinct contract_id)
from agile-producer-437112-g6.L2.L2_product_purchase
where true
  and product_type = 'product_trial'
  and product_valid_from is not null
  and contract_id in 
  (select contract_id
  from agile-producer-437112-g6.L2.L2_contract
  where contract_valid_from is not null
  )
;


-- How many never had a trial?
-- 110 982 unique where product_valid_from is not null
select count(distinct contract_id)
from agile-producer-437112-g6.L2.L2_product_purchase
where true
  and product_type <> 'product_trial'
  and product_valid_from is not null
  and contract_id in 
    (select contract_id
    from agile-producer-437112-g6.L2.L2_contract
    where contract_valid_from is not null
    )
;


-- How many continue after the trial ends?
with trial_customers as
  (select *
  from agile-producer-437112-g6.L3.L3_pp_product_contract
  where true
    and product_type = 'product_trial'
    and product_valid_from is not null
  )
select count(distinct pp.contract_id)
from agile-producer-437112-g6.L3.L3_pp_product_contract pp
join trial_customers t
  on pp.contract_id = t.contract_id
where true
  and (pp.product_valid_to > t.product_valid_to or pp.product_valid_to is null)
  and pp.product_type <> 'product_trial'
;


-- How many customers churned at the same time their product was discontinued?
with product_cancellations as (
  select
    p.contract_id,
    p.product_id,
    p.product_valid_to as product_cancel_date,
    p.contract_valid_to as contract_cancel_date
  from `agile-producer-437112-g6.L3.L3_pp_product_contract` p
  where p.product_valid_to is not null
),
churned_on_same_day as (
  select contract_id
  from product_cancellations
  where date(product_cancel_date) = date(contract_cancel_date)
),
kept_subscription as (
  select contract_id
  from product_cancellations
  where date(product_cancel_date) < date(contract_cancel_date)
)
select
  (select count(distinct contract_id) from churned_on_same_day) as churned_on_same_day_count,
  (select count(distinct contract_id) from kept_subscription) as kept_subscription_count
;


-- How many of the churned and non-churned customers were using other products
with product_cancellations as (
  select
    p.contract_id,
    p.product_id,
    p.product_valid_to as product_cancel_date,
    p.contract_valid_to as contract_cancel_date
  from `agile-producer-437112-g6.L3.L3_pp_product_contract` p
  where p.product_valid_to is not null
),
churned_on_same_day as (
  select contract_id
  from product_cancellations
  where date(product_cancel_date) = date(contract_cancel_date)
),
kept_subscription as (
  select contract_id
  from product_cancellations
  where date(product_cancel_date) < date(contract_cancel_date)
),
churned_with_other_products as (
  select distinct p.contract_id
  from`agile-producer-437112-g6.L3.L3_pp_product_contract` p
  join churned_on_same_day c
    on p.contract_id = c.contract_id
  join product_cancellations pc
    on p.contract_id = pc.contract_id
  and p.product_id != pc.product_id
  where
    p.product_valid_to is not null
    and p.product_valid_to > p.product_valid_from                       -- product was active at the time of churn
),
kept_with_other_products as (
  select distinct p.contract_id
  from `agile-producer-437112-g6.L3.L3_pp_product_contract` p
  join kept_subscription k
    on p.contract_id = k.contract_id
  join product_cancellations pc
    on p.contract_id = pc.contract_id
    and p.product_id != pc.product_id
  where
    p.product_valid_to is not null
    and p.product_valid_to > p.product_valid_from                       -- product was active after discontinuation
)

select
  (select count(distinct contract_id) from churned_with_other_products) as churned_with_other_products_count,
  (select count(distinct contract_id) from kept_with_other_products) as kept_with_other_products_count
;


-- what types of products were churned customers using
with product_cancellations as (
  select
    p.contract_id,
    p.product_id,
    p.product_type,
    p.product_valid_to,
    p.contract_valid_to
  from
    `agile-producer-437112-g6.L3.L3_pp_product_contract` p
  where
    p.product_valid_to is not null
),
churned_on_same_day as (
  select
    contract_id,
    product_type,
    product_valid_to,
    product_id
  from
    product_cancellations
  where
    date(product_valid_to) = date(product_valid_to)
    and product_type = 'equipment'                                  -- filter for "equipment" that got discontinued
),
other_products_at_time as (
  select distinct
    p.contract_id,
    p.product_id,
    p.product_type
  from
    `agile-producer-437112-g6.L3.L3_pp_product_contract` p
  join churned_on_same_day c
    ON p.contract_id = c.contract_id
  where
    p.product_valid_to is not null
    and date(p.product_valid_from) <= date(c.product_valid_to) 
    and date(p.product_valid_to) >= date(c.product_valid_to)        -- products that were active at the time of churn
    and p.product_id != c.product_id                                -- exclude canceled products
)
select
  c.contract_id,
  c.product_type as discontinued_product,
  p.product_type as other_product_at_same_time
from
  churned_on_same_day c
join other_products_at_time p
  on c.contract_id = p.contract_id
order by
  c.contract_id;


-- Churn timing segmentation: how long before a customer churns? 
create or replace table agile-producer-437112-g6.L3.L3_contract_duration_bins as
select
  case
    when contract_duration <= 30 then "M1"
    when contract_duration <= 61 then "M2"
    when contract_duration <= 91 then "M3"
    when contract_duration <= 122 then "M4"
    when contract_duration <= 152 then "M5"
    when contract_duration <= 183 then "M6"
    when contract_duration <= 365 then "M6-M12"
    when contract_duration <= 1230 then "Y1-Y2"
    else "Y2+"
  end as contract_duration,
  count(distinct contract_id) as cnt
from agile-producer-437112-g6.L3.L3_pp_product_contract
where contract_valid_to is not null
group by contract_duration
order by contract_duration
;


-- How many had a trial and how many purchased something else
select count(contract_id)
from agile-producer-437112-g6.L3.L3_pp_contract
where true
  and product_type <> "product_trial"
  and contract_id in
  (select contract_id
  from agile-producer-437112-g6.L3.L3_pp_contract
  where true
    and product_type = "product_trial"
    and product_valid_from is not null
  )
;

select sum(price_wo_vat)
  from agile-producer-437112-g6.L3.L3_pp_contract
  where true
    and product_type <> "product_trial"
    and contract_id in
    (select contract_id
    from agile-producer-437112-g6.L3.L3_pp_contract
    where true
      and product_type = "product_trial"
      and product_valid_from is not null
    )
;


-- How much revenue did we get from trials
select sum(price_wo_vat)
from agile-producer-437112-g6.L3.L3_pp_contract
where true
  and product_type = "product_trial"
  and product_valid_from is not null
;


-- What are the top dates and months for canceled contracts
select contract_valid_to, count(distinct contract_id) as cnt
from agile-producer-437112-g6.L2.L2_contract
where contract_valid_to is not null
group by contract_valid_to
order by cnt desc
limit 50
;


-- And how many cancel on an avg day
select avg(cnt) as avg_cancellations_per_day
from (
  select contract_valid_to, count(*) as cnt                           -- contracts ending each day
  from agile-producer-437112-g6.L2.L2_contract
  where contract_valid_to between '2021-01-01' and '2024-09-30'
  group by contract_valid_to
);


-- How many customers whose product got canceled on Jul 31, 2023 left?
with discontinued_products as (
    select distinct product_id
    from agile-producer-437112-g6.L3.L3_pp_product_contract
    where product_valid_to = '2023-07-31'
),
subscribing_customers as (
    select distinct contract_id
    from agile-producer-437112-g6.L3.L3_pp_product_contract
    where product_id in (select product_id from discontinued_products)
),
continuing_customers as (
    select distinct contract_id
    from agile-producer-437112-g6.L3.L3_pp_product_contract
    where contract_valid_to > '2023-07-31' or contract_valid_to is null
)

select count(distinct s.contract_id) as customer_count
from subscribing_customers s
left join continuing_customers c
    on c.contract_id = s.contract_id
where c.contract_id is null
;


select count(distinct product_id)
from agile-producer-437112-g6.L3.L3_pp_product_contract
where true 
  and contract_valid_to = product_valid_to
  and product_valid_to = '2023-07-31'
;


select product_valid_to, count(product_id) as cnt
from agile-producer-437112-g6.L3.L3_pp_product_contract
where product_valid_to is not null
group by product_valid_to
order by cnt desc
limit 20
;


-- Top days when the last invoice was paid
with max_invoice_order as (
  select 
    contract_id, 
    max(invoice_order) as max_invoice_order
  from agile-producer-437112-g6.L2.L2_invoice
  group by
    contract_id
),
max_order_invoices as (
  select 
    t.contract_id,
    t.end_date,
    t.invoice_order
  from agile-producer-437112-g6.L2.L2_invoice t
  join 
    max_invoice_order m
  on 
    t.contract_id = m.contract_id 
    and t.invoice_order = m.max_invoice_order
)
select 
  end_date, 
  count(*) as end_date_count
from 
  max_order_invoices
group by
  end_date
order by 
  end_date_count desc
;


select 
  end_date,
  invoice_order,
  count(*) as end_date_count
from agile-producer-437112-g6.L2.L2_invoice
group by
  end_date, invoice_order
order by 
  end_date, end_date_count desc
;


-- Median contract duration
select approx_quantiles(contract_duration, 2)[offset(1)] as median
from agile-producer-437112-g6.L3.L3_pp_contract
;




-- 3. CUSTOMER BEHAVIOR

-- Who spent the most
select contract_id, sum(amount_wo_vat) as sum
from agile-producer-437112-g6.L2.L2_invoice
where paid_date is not null
group by contract_id
order by sum desc
limit 50
;


-- Quartiles for invoice amounts
select approx_quantiles(amount_wo_vat, 4) as quartiles
from agile-producer-437112-g6.L2.L2_invoice
where paid_date is not null
-- where amount_wo_vat > 0
;


-- Average invoice amount
select avg(amount_wo_vat)
from agile-producer-437112-g6.L2.L2_invoice
-- where amount_wo_vat > 0
;


-- Average price of product_purchase
select avg(price_wo_vat)
from agile-producer-437112-g6.L2.L2_product_purchase
where price_wo_vat > 0
;


-- How many customers are responsible for zero-amount product purchases exclusively?
with zero_paying as (
  select contract_id
  from agile-producer-437112-g6.L2.L2_product_purchase
  where true
    -- include customers who are paying nothing
    and contract_id in 
    (select contract_id
    from agile-producer-437112-g6.L2.L2_product_purchase
    where price_wo_vat = 0
    )
    -- exclude customers who at other times paid
    and contract_id not in
    (select contract_id --, count(product_purchase_id) as cnt
    from agile-producer-437112-g6.L2.L2_product_purchase
    where price_wo_vat > 0
    )
)
select count(c.contract_id)
from agile-producer-437112-g6.L2.L2_contract as c
join zero_paying as z on z.contract_id = c.contract_id
where true
  and contract_valid_to is null
limit 100
;


-- Average number of invoices per customer
select avg(cnt)
from
  (select contract_id, count(invoice_id) as cnt
  from agile-producer-437112-g6.L2.L2_invoice
  group by contract_id
  )
;


-- Median revenue per customer
select approx_quantiles(total, 4) as quartiles
from 
  (select contract_id, sum(amount_wo_vat) as total
  from agile-producer-437112-g6.L2.L2_invoice
  group by contract_id
  )
;


-- Median number of invoices per customer
select approx_quantiles(cnt, 4) as quartiles
from 
  (select contract_id, count(invoice_id) as cnt
  from agile-producer-437112-g6.L2.L2_invoice
  group by contract_id
  )
;


-- Correlation between # of invoices and total sum of invoices
with contract_invoice as (
  select
    contract_id,
    count(invoice_id) as num_invoices,
    sum(amount_wo_vat) as total_amount_wo_vat
  from
    agile-producer-437112-g6.L2.L2_invoice
  group by
    contract_id
)
select corr(num_invoices, total_amount_wo_vat) as correlation
from contract_invoice
;


-- Correlation bw # of invoices and # of products
with contract_invoice as (
  select
    contract_id,
    count(invoice_id) as num_invoices
  from
    agile-producer-437112-g6.L2.L2_invoice
  group by
    contract_id
),
contract_product as (
  select
    contract_id,
    count(product_id) as num_products
  from
    agile-producer-437112-g6.L2.L2_product_purchase
  group by
    contract_id
)
select corr(ci.num_invoices, cp.num_products) as correlation
from contract_invoice ci
join contract_product cp
  on ci.contract_id = cp.contract_id
;


-- Correlation bw # of invoices and # of product_purchases
with contract_invoice as (
  select
    contract_id,
    count(invoice_id) as num_invoices
  from
    agile-producer-437112-g6.L2.L2_invoice
  group by
    contract_id
),
contract_product as (
  select
    contract_id,
    count(product_purchase_id) as num_pp
  from
    agile-producer-437112-g6.L2.L2_product_purchase
  group by
    contract_id
)
select corr(ci.num_invoices, cp.num_pp) as correlation
from contract_invoice ci
join contract_product cp
  on ci.contract_id = cp.contract_id
;


-- Correlation btw # of products and total rev
with contract_invoice as (
  select
    contract_id,
    sum(amount_wo_vat) as total_rev
  from
    agile-producer-437112-g6.L2.L2_invoice
  group by
    contract_id
),
contract_product as (
  select
    contract_id,
    count(product_id) as num_products
  from
    agile-producer-437112-g6.L2.L2_product_purchase
  group by
    contract_id
)
select corr(ci.total_rev, cp.num_products) as correlation
from contract_invoice ci
join contract_product cp
  on ci.contract_id = cp.contract_id
;


-- Which products have been offered for free?
select distinct(product_type)
from agile-producer-437112-g6.L2.L2_product_purchase pp
where price_wo_vat = 0
;


-- How much each product type made and how many customers per type?
with rev_type as (
  -- total rev per product type
  select product_type, sum(price_wo_vat) as rev
  from agile-producer-437112-g6.L2.L2_product_purchase pp
  group by product_type
  order by rev desc
),
customer_type as (
-- total customers per product type
  select product_type, count(contract_id) as cnt
  from agile-producer-437112-g6.L2.L2_product_purchase pp
  group by product_type
  order by cnt desc
)
select rt.product_type, rt.rev / ct.cnt as rev_per_customer
from rev_type rt
join customer_type ct
  on rt.product_type = ct.product_type
;


-- Avg trial duration
select avg(date_diff(product_valid_to, product_valid_from, day))
from agile-producer-437112-g6.L2.L2_product_purchase
where product_type = "product_trial"
;


-- How many days in do customers buy equipment?
select avg(date_diff(product_valid_from, contract_valid_from, day)) as avg_days_after_contract
from agile-producer-437112-g6.L3.L3_pp_product_contract
where product_type = 'equipment'
  and product_valid_from is not null
  and contract_valid_from is not null
;


-- Number of customers (contract_valid_from) each year
select extract(year from contract_valid_from) as year, count(distinct contract_id)
from agile-producer-437112-g6.L3.L3_pp_product_contract
where contract_valid_from < contract_valid_to
group by year
order by year
;
