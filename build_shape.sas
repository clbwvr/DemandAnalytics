/******************************************************************************
*
* Name: build_shape.sas
*
* Author: Caleb Weaver - caleb.weaver@sas.com
*
* Description: build shape indices
*
* Parameters:    
* indsn: List of input dataset names (one for each recon level)
* seasonality: Seasonality dataset
* by_var: Seasonality modeling by variables
* predict_name: Prediction variable column name
* predict_no_use: Number of predict variables (# indsn tables)
*
******************************************************************************/

%macro build_shape(
indsn=,
outdsn=,
by_var=,
predict_name=,
predict_no_use=
);

%let i = 1;
%let dsn_iter = %scan(&indsn, &i, ' ');
%do %while("&dsn_iter" ne "");

/* Create dataset of shapes by indsn table */
proc sql;
create table _ts_&i as
select
%let j = 1;
%let by_var_iter = %scan(&by_var, &j);
%do %while("&by_var_iter" ne "");
t1.&by_var_iter,
%let j = %eval(&j + 1);
%let by_var_iter = %scan(&by_var., &j);
%end;
t1.wk_start_dt,
t1.sales_qty_dp,
t1.&predict_name as predict&i
from
&dsn_iter t1;
quit;

proc sort data=_ts_&i;
by &by_var.;
run;quit;

%let i = %eval(&i + 1);
%let dsn_iter = %scan(&indsn, &i, ' ');
%end;

/* Join datasets of shapes */
data pinned;
merge
%let k = 1;
%do k=1 %to &i - 1;
_ts_&k
%end;
; by &by_var.;
run;

data tmp1.pinned;set pinned; run;

/* Average shapes */
data pinned;
set pinned;
shape =  mean( ifn(predict1,predict1,.) %do i=2 %to %sysevalf(&predict_no_use-1); , ifn(predict&i,predict&i,.)  %end; );
yr = year(wk_start_dt);
run;

data tmp1.pinned1; set pinned; run;

/* Standardize shapes to indices centered at 1 */
proc sql;
create table mns as
select prod_id_lvl8, loc_id_lvl8, yr, mean(shape) as mn
from pinned
group by prod_id_lvl8, loc_id_lvl8, yr;
quit;

proc sql;
create table &outdsn(keep=prod_id_lvl8 loc_id_lvl8 wk_start_dt index) as select t1.*, coalesce(t1.shape/t2.mn,1) as index
from pinned t1, mns t2 where t1.prod_id_lvl8=t2.prod_id_lvl8 and t1.loc_id_lvl8=t2.loc_id_lvl8 and t1.yr=t2.yr
order by prod_id_lvl8, loc_id_lvl8, wk_start_dt;
quit;

%mend;


