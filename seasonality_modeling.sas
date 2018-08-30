/******************************************************************************
*
* Name: build_shape.sas
*
* Author: Caleb Weaver - caleb.weaver@sas.com
*
* Description: model seasonality
*
* Parameters:    
* indsn: Input Dataset
* by_var: Seasonality modeling by variables
* outdsn: Output dataset
*
******************************************************************************/

%macro seasonality_modeling(
indsn=,
by_var=,
retail=1,
outdsn=
);

%let k = 1;

%do %while (%scan(&by_var., &k,!) ne );
%let this_var = %scan(&by_var., &k,!);

proc sort data=leaf; by &this_var; run;
proc sort data=leaf nodupkey out=a;
by &this_var wk_start_dt prod_id_lvl8;
run;
proc means data=a;
by &this_var wk_start_dt;
var prod_id_lvl8;
output out=b(keep=&this_var wk_start_dt distro) n=distro;
run;
data ts_&k;
merge ts_&k(in=a) b;
by &this_var wk_start_dt;
if a;
run;

proc sort data=ts_&k nodupkey out=a;
by &this_var wk_start_dt;
run;
proc means data=a(where=(sales_qty_dp>0));
by &this_var;
var wk_start_dt;
output out=b(keep=&this_var weeks) n=weeks;
run;
data ts_&k;
merge ts_&k(in=a) b;
by &this_var;
if a;
run;

proc means data=ts_&k;
by &this_var;
var distro;
output out=a(keep=&this_var maxdistro) max=maxdistro;
run;
data ts_&k;
merge ts_&k(in=a) a;
by &this_var;
if a;
week = week(wk_start_dt);
run;

proc sql;select distinct market into : markets separated by "!" from ts_&k; quit;
%let j=1;
%do %while (%scan(&markets, &j) ne );
%let marketj = %scan(&markets, &j);
data ts_&k._&marketj;
set ts_&k;
if market = &marketj;
run;
%create_holiday_dummies(indsn=ts_&k._&marketj, holiday_dsn=holidays, outdsn=ts_&k._&marketj)
proc sql;select distinct holiday_id into : hols separated by " " from holidays where market = &marketj; quit;
proc sort data=ts_&k._&marketj; by &this_var; run;
proc glm data=ts_&k._&marketj(where=(sales_qty_dp ne . and weeks > 53));
by &this_var;
class week;
model sales_qty_dp = week %if &retail %then %do; distro %end; &hols;
store store;
run;

data ts_&k._&marketj; set ts_&k._&marketj; distro = maxdistro; run;

proc plm restore=store; score data=ts_&k._&marketj out=temp_&k._&marketj(rename=(predicted=seasindex));; run;

%let j = %eval(&j + 1);
%end;

data temp_&k; 
set temp_&k:;
/* For missing Week 53 */
if seasindex = . then seasindex = lag(seasindex);
if seasindex < 0 then seasindex = 0; 
run;

%let k = %eval(&k + 1);
%end;

/*===========================================================================*/
/* Shape Reconciliation */
/*===========================================================================*/

%let k=1;

%do %while (%scan(&by_var, &k,!) ne );
%let this_var = %scan(&by_var, &k,!);

data want;
length word new $200;
old = "&this_var. prod_id_lvl8 loc_id_lvl8";

do i=1 to countw(old, ' ');
word=scan(old,i,' ');

if indexw(new,word,' ') then
continue;
new=catx(' ',new,word);
end;

call symputx("recon_by_var",new);
run;

/* Reconcile shapes to leaf level ID's. */
/* Magnititude doesn't matter as they gets scaled later */
%recon(
dsn_disagg=dsn_disagg,
dsn_agg=temp_&k.,
outdsn_fcst=leaf_recon_&k.,
y=seasindex,
by_var=&this_var.,
by_var_leaf=&recon_by_var.,
time_var=wk_start_dt,
time_int=week
);

%let k = %eval(&k + 1);
%end;

%let i=1;
%let recon_levels=0;

%do %while (%scan(&by_var, &i,!) ne );
%let var = %scan(&by_var, &i,!);
%let recon_levels = %sysevalf(&recon_levels + 1);
%let i = %eval(&i + 1);
%end;

%let recon_names=;

%do i = 1 %to &recon_levels;

%let recon_names=&recon_names leaf_recon_&i;
%end;

%let predict_no_use = %eval(&recon_levels+1);

/* Create seasonal indices from shapes */
%build_shape(
indsn=&recon_names,
by_var=prod_id_lvl8 loc_id_lvl8,
predict_name=seasindex,
predict_no_use=&predict_no_use,
outdsn=&outdsn
)

data tmp1.caleb; set &outdsn; run;

%mend;



