/******************************************************************************
*
*  Name: impute_seasonality.sas
*
*  Author: Caleb Weaver - caleb.weaver@sas.com
*
*  Description: Create default seasonality indices
*
******************************************************************************/

%macro impute_seasonality(
seasonality=,
fcst_horizon=,
retail=,
outdsn=
);

%if &retail %then %let filter = facility_type = '1' and channel ne 2;
%else %let filter = facility_type = '3';

proc sql;
create table a as 
select distinct t2.prod_id_lvl4, 
t1.product_id, 
t1.location_id, 
t1.wk_start_dt, 
t1.index
from &seasonality t1
inner join (select distinct prod_id_lvl4, prod_id_lvl5 from dm.product_hierarchy_lst) t2 on (t1.product_id = t2.prod_id_lvl5);
quit;

proc sql;
create table amarket as 
select distinct t1.prod_id_lvl4, 
t1.product_id, 
t1.location_id,
t2.market, 
t1.wk_start_dt, 
t1.index
from a t1
inner join dm.location_master(where=(&filter)) t2 on (t1.location_id = t2.location_id);
quit;

proc sql;
create table b as 
select t1.prod_id_lvl4, 
t1.product_id as prod_id_lvl5, 
t1.market,
t1.wk_start_dt, 
(mean(t1.index)) as index_classchain
from amarket t1
group by t1.prod_id_lvl4,
t1.product_id,
t1.market,
t1.wk_start_dt;
quit;

proc sql;
create table c as 
select t1.prod_id_lvl4, 
t1.location_id, 
t1.wk_start_dt, 
(mean(t1.index)) as index_deptstore
from amarket t1
group by t1.prod_id_lvl4,
t1.location_id,
t1.wk_start_dt;
quit;

proc sql;
create table fh as 
select distinct t2.prod_id_lvl4, 
t2.prod_id_lvl5, 
t1.location_id
from &fcst_horizon t1
inner join (select distinct prod_id_lvl4, prod_id_lvl5, prod_id_lvl8 from dm.product_hierarchy_lst) t2 on (t1.product_id = t2.prod_id_lvl8);
quit;

proc sql;
create table fhmarket as 
select distinct t1.*,
t2.market
from fh t1
inner join dm.location_master t2 on (t1.location_id = t2.location_id);
quit;

proc sql;
create table d as 
select distinct t1.prod_id_lvl5, 
t2.location_id, 
t1.wk_start_dt, 
t1.index_classchain
from b t1, fhmarket t2
where (t1.prod_id_lvl4 = t2.prod_id_lvl4 and t1.prod_id_lvl5 = t2.prod_id_lvl5 and t1.market=t2.market);
quit;

proc sql;
create table e as 
select distinct t2.prod_id_lvl5, 
t1.location_id, 
t1.wk_start_dt, 
t1.index_deptstore
from c t1, fhmarket t2
where (t1.prod_id_lvl4 = t2.prod_id_lvl4 and t1.location_id = t2.location_id);
quit;

proc sort data=d; by prod_id_lvl5 location_id wk_start_dt; run;
proc sort data=e; by prod_id_lvl5 location_id wk_start_dt; run;

data f;
merge d e;
by prod_id_lvl5 location_id wk_start_dt;
run;

data &outdsn(keep=product_id location_id wk_start_dt index);
merge f(rename=(prod_id_lvl5=product_id)) &seasonality;
by product_id location_id wk_start_dt;
index = coalesce(index, index_classchain, index_deptstore);
run;

%mend;

