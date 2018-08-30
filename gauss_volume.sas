/*****************************************************************************
*
*    Name: gauss_volume.sas
*
*    Author: Caleb Weaver - caleb.weaver@sas.com
*
*    Description: Kernel Estimation Smoother
*
*    Parameters:    
*    indsn: Input dataset
*    outdsn: Output dataset
*    by_var: Seasonality modeling by variables
*    time_var: Time Variable
*    time_int: Time Interval
*    y: Dependent Variable
*    bandwidth: bandwidth of kernel. Represents SD of Gaussian.
*    anchor: Anchor date for forecast. 0 for all data.
*    predict_var_name: Prediction variable column name
*    plot: Flag for plotting fit (0/1)
*    
*****************************************************************************/

%macro gauss_volume(
indsn=,
outdsn=,
by_var=,
time_var=,
time_int=,
y=,
bandwidth=,
anchor=0,
predict_var=predict,
plot=0
);

/* Create macro variables */

%let by_var_c = %sysfunc(tranwrd(&by_var,%str( ),%str(,)));
%let by_var_firsts = first.%sysfunc(tranwrd(&by_var,%str( ),%str( or first.)));
%if &time_int=week %then %let bandwidth = %sysevalf(&bandwidth * 7);
%if &time_int=month %then %let bandwidth = %sysevalf(&bandwidth * 30);
%if &time_int=year %then %let bandwidth = %sysevalf(&bandwidth * 365);

%if &anchor=0 %then %do;
proc sql noprint;
select max(&time_var) into : anchor from &indsn where &y ne .;
quit;
%end;

/* Create aggregate dataset */
proc sql;
create table agg as 
select &by_var_c, 
&time_var, 
sum(&y) as &y
from &indsn
group by &by_var_c, &time_var
order by &by_var_c, &time_var;
quit;

/* Create weights */
data agg;
set agg;
w = pdf('NORMAL',&time_var,&anchor,&bandwidth);
run;


/* Plot weights */
%if &plot %then %do;
proc sql noprint;select min(&time_var) into : a from agg;quit;
proc sql noprint;select max(&time_var) into : b from agg;quit;
data plotter;
do time = &a to &b by .01;
weight = pdf('NORMAL',time,&anchor,&bandwidth);
output;
end;
run;
data plotter;
format time date9.;
set plotter;
run;
title "Gaussian Weight by Time";
proc sgplot data=plotter;
series x=time y=weight;
run;
proc delete data=plotter; run;
%end;

/* Create kernel estimated smoother */
proc sql;
create table preds as select
&by_var_c, sum(w*&y) / sum(w) as &predict_var
from agg
where &time_var <= &anchor
group by &by_var_c
order by &by_var_c;
quit;

proc contents data = &indsn out = vars(keep = name) noprint;
run;
proc sql noprint;
select distinct name into :vars separated by ' ' from vars;
quit; 

/* If prediction alredy exists on dataset */
%if %index(&vars,&predict_var) %then %do;
proc sort data=&indsn; by &by_var; run;
data &outdsn(drop=hvar);
merge &indsn(in=a) agg(rename=(&predict_var=hvar));
by &by_var;
if a;
if &predict_var = . then &predict_var = hvar;
run;
%end;

/* Add smoothed y to output dataset */

%else %do;
proc sql;
create table &outdsn
as select t1.*, t2.&predict_var
from &indsn t1 left join preds t2
on 
%let i=1;
%let v = %scan(&by_var, &i);
t1.&v = t2.&v
%let i=2;
%do %while (%scan(&by_var, &i) ne );
%let v = %scan(&by_var, &i);
and t1.&v = t2.&v
%let i = %eval(&i + 1);
%end;
;
quit;
%end;
%mend;

