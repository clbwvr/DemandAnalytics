/******************************************************************************
*
* Name: shape_volume.sas
*
* Author: Caleb Weaver - caleb.weaver@sas.com
*
* Description: Seasonalize flat demand predictions
*
* Parameters: 
* indsn: Input dataset
* outdsn: Output dataset
* shape: shape index var name
* volume: volume prediction var name
* time_Var: time var name
* end_date: end date of the forecast
* ids: Leaf level by vars
* prediction_var: output prediction var name
*
******************************************************************************/

%macro shape_volume(
indsn=,
outdsn=,
shape=,
volume=,
time_var=,
end_date=,
ids=,
prediction_var=
);

data _null_;
x = tranwrd("&ids"," ", ",");
call symputx("sql_ids", x);
run; 

/* Aggregate shapes by by vars */
PROC SQL;
CREATE TABLE a AS 
SELECT t1.prod_id_lvl8, 
t1.loc_id_lvl8, 
(N(t1.&shape)) AS cnt, 
(SUM(t1.&shape)) AS sm
FROM &indsn t1
WHERE t1.&time_var > &end_date
GROUP BY t1.prod_id_lvl8, t1.loc_id_lvl8;
QUIT;

/* Get aggregate values */
PROC SQL;
CREATE TABLE b AS 
SELECT t2.prod_id_lvl8, 
t2.loc_id_lvl8, 
t2.&time_var, 
t2.&shape, 
t2.&volume,
t1.cnt, 
t1.sm
FROM a t1, &indsn t2
WHERE (t1.prod_id_lvl8 = t2.prod_id_lvl8 AND t1.loc_id_lvl8 = t2.loc_id_lvl8);
QUIT;

/* Standardize shapes */
PROC SQL;
CREATE TABLE c AS 
SELECT t1.prod_id_lvl8, 
t1.loc_id_lvl8, 
t1.&time_var, 
(t1.&shape/t1.sm) AS prop, 
t1.cnt, 
t1.&volume, 
t1.sm
FROM b t1
WHERE &time_var >= &end_date;
QUIT;

/* Scale shapes */
PROC SQL;
CREATE TABLE d AS 
SELECT t1.prod_id_lvl8, 
t1.loc_id_lvl8, 
t1.&time_var, 
(t1.prop*t1.&volume*t1.cnt) AS &prediction_var
FROM c t1;
QUIT;

/* Output results */
proc sql;
create table &outdsn as select t1.*, t2.&prediction_var 
from &indsn t1 left join d t2 on t1.prod_id_lvl8=t2.prod_id_lvl8
and t1.loc_id_lvl8 = t2.loc_id_lvl8 and t1.wk_start_dt=t2.wk_start_dt;
quit;

proc datasets lib=work noprint;
delete a b c d;
run;

%mend;

