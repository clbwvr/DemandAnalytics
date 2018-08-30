/******************************************************************************
*
*  Name: seasonalize.sas
*
*  Author: Caleb Weaver - caleb.weaver@sas.com
*
*  Description: Seasonalize flat demand predictions
*
*  Parameters: 
*  indsn: Input fact dataset
*  seasonality: Seasonaity dataset
*  gapseason: Flag for using Gap seasonality (0/1)
*  predict_var_name: Prediction variable name
*  
*
******************************************************************************/

%macro seasonalize(
indsn=,
seasonality=,
gapseason=,
predict_var_name=,
shaped_var=,
outdsn=
);

/* Split data for shaping and data with time series predictions */

proc sort data=&indsn;
by prod_id_lvl8 loc_id_lvl8;
run;

data reshape noreshape;
set &indsn;
by prod_id_lvl8 loc_id_lvl8;
if ists then do;
output noreshape;
end;
else do;
output reshape;
end;
run;

%let x=0;
data _null_;
set reshape;
call symput('x',_n_);
stop;
run;
%if &x=0 %then %do;
%return;
%end;


proc delete data=&indsn;
run;

%if &gapseason %then %do;

/* Get Class */

proc sort data=dm.product_hierarchy_lst(keep=prod_id_lvl8 prod_id_lvl5) out=p nodupkey;
by prod_id_lvl8;
run;

data reshape;
merge reshape(in=a) p(keep=prod_id_lvl8 prod_id_lvl5);
by prod_id_lvl8;
if a;
run;

/* Get Gap Seasonality */

proc sort data=reshape; by prod_id_lvl5 loc_id_lvl8 wk_start_dt; run;

data reshape;
merge reshape(in=a) &seasonality(rename=(product_id=prod_id_lvl5 location_id=loc_id_lvl8));
by prod_id_lvl5 loc_id_lvl8 wk_start_dt;
if a;
run;


/* Seasonalize demand */
%shape_volume(
indsn=reshape,
outdsn=&outdsn,
shape=index,
volume=&predict_var_name,
time_var=wk_Start_dt,
end_date=&anchor,
prediction_var=&shaped_var
)

%end;
%else %do;

/* Get SAS Seasonality */
proc sort data=reshape; by prod_id_lvl8 loc_id_lvl8 wk_start_dt; run;
data reshape;
merge reshape(in=a) &seasonality;
by prod_id_lvl8 loc_id_lvl8 wk_start_dt;
if a;
run;
proc sql;
create table default as select wk_Start_dt, mean(index) as defindex from &seasonality group by wk_start_dt;
quit;
proc sort data=reshape; by wk_start_dt; run;
data reshape(drop=defindex);
merge reshape(in=a) default;
by wk_start_dt;
if a;
if index = . then index = defindex;
run;

/* Seasonalize demand */
%shape_volume(
indsn=reshape,
outdsn=&outdsn,
shape=index,
volume=&predict_var_name,
time_var=wk_Start_dt,
end_date=&anchor,
prediction_var=&shaped_var
)

%end;

%mend;

