/******************************************************************************
*
*  Name: neighbor_factors.sas
*
*  Author: Caleb Weaver - caleb.weaver@sas.com
*
*  Description: Outlier Detection and Correction of Neighbors
*
******************************************************************************/

%macro neighbor_factors(
xdsn=,
x=,
p=,
neighbors=,
outdsn=
);

/* Estimate Lognormal Distribition */
proc sql noprint;
create table param_ests as select 
market, prod_id_lvl5, 
mean(log(&x)) as logmu, 
std(log(&x)) as logsigma
from &xdsn
group by market, prod_id_lvl5;
quit;
data param_ests;
set param_ests;
quantl = quantile('LOGNORMAL',&p, logmu, logsigma);
run;

/* Get neighbors */
proc sort data=&xdsn; by market prod_id_lvl5 loc_id_lvl8; run;

proc sql;
create table &xdsn as select * from &xdsn group by market, prod_id_lvl5 having std(&x) > 0; 
quit;

ods _all_ close;
proc modeclus data=&xdsn method=1 k=&neighbors Neighbor; 
id loc_id_lvl8;
by market prod_id_lvl5;
var &x;
ods output neighbor=neighbor;
run;
data neighbor(drop=nbor rename=(_a=nbor)); set neighbor;  _a = input(nbor, best32.); run;
data neighbor; set neighbor; retain loc_id_lvl8 1; if ID ne ' ' then loc_id_lvl8 = input(ID,best32.); run;
proc sort data=neighbor;
by market prod_id_lvl5 loc_id_lvl8;
run;
data neighbor; 
set neighbor;
by market prod_id_lvl5 loc_id_lvl8;
if first.loc_id_lvl8 then do;
output;
nbor = loc_id_lvl8; 
output;
end;
else output;
run;

/* Get my deviation */
proc sql noprint;
create table neighbor as select t1.*, t2.&x as mydev from neighbor t1, &xdsn t2
where t1.prod_id_lvl5=t2.prod_id_lvl5 and t1.loc_id_lvl8=t2.loc_id_lvl8;
quit;
/* Get my neighbors deviations */
proc sql noprint;
create table neighbor as select t1.*, t2.&x as nbordev from neighbor t1, &xdsn t2
where t1.prod_id_lvl5=t2.prod_id_lvl5 and t1.nbor=t2.loc_id_lvl8
order by t1.market, t1.prod_id_lvl5;
quit;
data neighbor;
merge neighbor(in=a) param_ests(keep=market prod_id_lvl5 quantl);
by market prod_id_lvl5;
if a;
run;
/* Get factors */
proc sql noprint;
create table &outdsn as select market, prod_id_lvl5, loc_id_lvl8, mean(mydev) / mean(nbordev) as nborfactor
from neighbor where mydev > quantl group by market, prod_id_lvl5, loc_id_lvl8;
quit;

%mend;
