/***************************************************************************************************
*
*  Name: outlier_detection.sas 
*
*  Author:  Caleb Weaver (caleb.weaver@sas.com)
*           Katrina Weck (katrina.weck@sas.com)
*
****************************************************************************************************/


%macro outlier_detection(
dsn=,
outdsn=,
by_var=,
y=,
time_var=,
time_int=,
no_std=,
quantl=.95,
distr=,
num_ids=0
);

%local i;
data _dsn_top 
%if &num_ids %then %do;
( 
drop =
%let i = 1;
%do %while (%scan(&by_var, &i) ne );
%let by_var_iter = %scan(&by_var, &i);
&by_var_iter 
%let i = %eval(&i + 1);
%end; 
rename = (
%let i = 1;
%do %while (%scan(&by_var, &i) ne );
%let by_var_iter = %scan(&by_var, &i);
&by_var_iter.c = &by_var_iter 
%let i = %eval(&i + 1);
%end;
)
);
%end;
set &dsn.;
top=1;
%if &num_ids %then %do;
%let i=1;
%do %while (%scan(&by_var, &i) ne );
%let by_var_iter = %scan(&by_var, &i);
&by_var_iter.c = put(&by_var_iter,32.);
%let i = %eval(&i + 1);
%end;
%end;
run;


proc sort data=_dsn_top out=_sorted_table;
by top &by_var. &time_var.;
run;quit;

proc timeseries data=_sorted_table out=_ts outsum=_outsum_ts;
by top &by_var.;
id &time_var. interval=&time_int;
var &y. / accumulate=total;
run;quit;

data _ts_long(drop=_name_--sum) _ts_short;
merge _outsum_ts _ts;
by top &by_var.;
if (n<9) then output _ts_short;
else output _ts_long;
run;

/*==================================================================================*/
/* estimate a a segment using expand */
/*==================================================================================*/

proc expand data=_ts_long out=_ts_long_1;
by &by_var.;
id &time_var.;
convert &y.=predict_median_1 /  transformout=( cmovmed 5);
run;quit; 

proc expand data=_ts_long_1 out=_ts_long_2;
by &by_var.;
id &time_var.;
convert predict_median_1=predict_median_2 /  transformout=( cmovmed 9);
run;quit; 

/*==================================================================================*/
/* get lags and abs diffs */
/*==================================================================================*/

data _diff;
set _ts_long_2;
by top &by_var &time_var;
lag_expand=lag(predict_median_2);
absdiff_expand = abs(predict_median_2 - lag_expand);
if
%let i=1;
%let by_var_iter = %scan(&by_var, &i);
first.&by_var_iter
%let i=2;
%do %while (%scan(&by_var, &i) ne );
%let by_var_iter = %scan(&by_var, &i);
or first.&by_var_iter
%let i = %eval(&i + 1);
%end;
then do;
lag_expand = .;
absdiff_expand = .;
end;
run;

proc means data=_diff noprint;
by top &by_var;
var absdiff_expand &y.;
output out=_diff_mean std(absdiff_expand)=ds_expand_std max(&y.)=max_y;
run;quit;

data _diff_ts(drop= _type_ _freq_);
merge _diff _diff_mean;
by top &by_var;
run;

data _label_1;
set _diff_ts;
by &by_var &time_var;
retain label 1;
if
%let i=1;
%let by_var_iter = %scan(&by_var, &i);
first.&by_var_iter
%let i=2;
%do %while (%scan(&by_var, &i) ne );
%let by_var_iter = %scan(&by_var, &i);
or first.&by_var_iter
%let i = %eval(&i + 1);
%end;
then label = 1;
else do;
if  absdiff_expand > &no_std. * ds_expand_std
then do; 
label + 1;
end;
end;
run;


data _label_2(keep=top &by_var. &time_var. &y. label predict_median_2 lag_expand);
set _label_1;
by top &by_var. &time_var.;
if _n_ = 1 then do;
label = 1;
end;
run;

proc sort data=_label_2;
by top &by_var. label;
run;quit;

proc means data=_label_2 noprint;
by top &by_var. label;
var &y.;
output out=_label_2_count n=n;
run;quit;

data _label_2_merge (drop=_type_ _freq_);
merge _label_2 _label_2_count;
by top &by_var. label;
run;

/* prep data to create a descending format */
proc sort data=_label_2_merge out=_label_2_desc;
by top &by_var. descending label &time_var.;
run;

/* if there is a transition point (n=1), then set its label to missing */
data _label_2_desc_prep;
set _label_2_desc;
if n=1 then level_desc =.;
else level_desc=label;
run;

/* fill in the missing labels through a retain statement */
data _label_2_desc_retain (drop=_x rename=(label=level));
set _label_2_desc_prep;
by top &by_var.;
retain _x;
if
%let i=1;
%let by_var_iter = %scan(&by_var, &i);
first.&by_var_iter
%let i=2;
%do %while (%scan(&by_var, &i) ne );
%let by_var_iter = %scan(&by_var, &i);
or first.&by_var_iter
%let i = %eval(&i + 1);
%end;
then do;
if level_desc ne . then _x=level_desc;
end;

if
%let i=1;
%let by_var_iter = %scan(&by_var, &i);
first.&by_var_iter
%let i=2;
%do %while (%scan(&by_var, &i) ne );
%let by_var_iter = %scan(&by_var, &i);
or first.&by_var_iter
%let i = %eval(&i + 1);
%end;
then do;
if level_desc eq . then do;
level_desc=1;
_x=level_desc;
end;
end;
else do;
if missing(level_desc) then do;
level_desc = _x;
end;
else do;
_x = level_desc;
end;
end;
run;

/* prep data to create an ascending format */
proc sort data=_label_2_merge out=_label_2_asc;
by top &by_var. label &time_var.;
run;

/* if there is a transition point (n=1), then set its label to missing */
data _label_2_asc_prep;
set _label_2_asc;
if n=1 then level_asc =.;
else level_asc=label;
run;

/* fill in the missing labels through a retain statement */
data _label_2_asc_retain (drop=_x rename=(label=level));
set _label_2_asc_prep;
by top &by_var.;
retain _x;
if 
%let i=1;
%let by_var_iter = %scan(&by_var, &i);
first.&by_var_iter
%let i=2;
%do %while (%scan(&by_var, &i) ne );
%let by_var_iter = %scan(&by_var, &i);
or first.&by_var_iter
%let i = %eval(&i + 1);
%end;
then do;
if level_asc ne . then _x=level_asc;
end;

if 
%let i=1;
%let by_var_iter = %scan(&by_var, &i);
first.&by_var_iter
%let i=2;
%do %while (%scan(&by_var, &i) ne );
%let by_var_iter = %scan(&by_var, &i);
or first.&by_var_iter
%let i = %eval(&i + 1);
%end;
then do;
if level_asc eq . then do;
level_asc=1;
_x=level_asc;
end;
end;
else do;
if missing(level_asc) then do;
level_asc = _x;
end;
else do;
_x = level_asc;
end;
end;
run;

/* sort descending and ascending data sets prior to merging them */
proc sort data=_label_2_asc_retain out=_label_2_asc_sorted;
by top &by_var. &time_var.;
run;

proc sort data=_label_2_desc_retain out=_label_2_desc_sorted;
by top &by_var. &time_var.;
run;

/* merge ascending and descending data sets, and determine the final label */
data _label_2_merge_asc_desc;
merge _label_2_asc_sorted _label_2_desc_sorted;
by top &by_var. &time_var.;

if predict_median_2 - lag_expand < 0 then should_be_label=level_desc;
if predict_median_2 - lag_expand >= 0 then should_be_label=level_asc;

lag_n=lag(n);
lag_should_be=lag(should_be_label);

if n=1 and lag_n=1 and should_be_label<=lag_should_be then final_label=.;
else final_label=should_be_label;

if 
%let i=1;
%let by_var_iter = %scan(&by_var, &i);
first.&by_var_iter
%let i=2;
%do %while (%scan(&by_var, &i) ne );
%let by_var_iter = %scan(&by_var, &i);
or first.&by_var_iter
%let i = %eval(&i + 1);
%end;
then do;
lag_n=.;
lag_should_be=.;
end;
run;

/* sort prior to by group processing, which will retain values across missing labels*/
proc sort data=_label_2_merge_asc_desc out=_label_2_merge_asc_desc_sort;
by top &by_var. &time_var.;
run;

data _label_2_merge_retain (drop=_x);
set _label_2_merge_asc_desc_sort;
by top &by_var.;
retain _x;
if 
%let i=1;
%let by_var_iter = %scan(&by_var, &i);
first.&by_var_iter
%let i=2;
%do %while (%scan(&by_var, &i) ne );
%let by_var_iter = %scan(&by_var, &i);
or first.&by_var_iter
%let i = %eval(&i + 1);
%end;
then do;
if final_label ne . then _x=final_label;
end;

else do;
if missing(final_label) then do;
final_label = _x;
end;
else do;
_x = final_label;
end;
end;
run;

%let by_var_concat = %sysfunc(tranwrd(&by_var,%str( ),%str(!!)));


/* create format to apply new labels to transition points (where n=1) */
data _label_2_format_final;
set _label_2_merge_retain;
length start   $255
label   $10
type    $1
fmtname $10
hlo     $1
;
type = 'c';
fmtname = 'n1_label';
start = compress(&by_var_concat. !! strip(put(level,8.)) !! strip(put(&time_var.,8.)));
label = final_label;
if n=1;
keep start label type fmtname hlo;
run;
%put &by_var_concat;

/* create other format catch-all to ensure format is created */
data _label_2_format_other;
length start   $255
label   $10
type    $1
fmtname $10
hlo     $1
;
type = 'c';
fmtname = 'n1_label';
start = 'hlo';
hlo = 'o';
label = '^';
keep start label type fmtname hlo;
run;

/* create appended data set for the format */
data _label_2_format_final_append;
set _label_2_format_final _label_2_format_other;
run;

/* create the label format for transition points */
proc format cntlin=_label_2_format_final_append;
run;

/* apply the label format to transition points (i.e. if n=1) */
data _label_2_merge_cleanup (drop=new_label);
set _label_2_merge;
if n=1 and put(compress(&by_var_concat. !! strip(put(label,8.)) !! strip(put(&time_var.,8.))), $n1_label.) ne '^' 
then do;
new_label=put(compress(&by_var_concat. !! strip(put(label,8.)) !! strip(put(&time_var.,8.))), $n1_label.);
label=input(strip(new_label),8.);
end;
run;

* create level intervals around values based on parameterized distribution and label as outlier if outside interval of level;
*------------------------------------------------------------------------------;

data _label_3(drop=n--sum lag_expand);
set _label_2_merge_cleanup _ts_short;
if (missing(label)) then label=1;
run;

proc sort data=_label_3;
by top &by_var. label;
run;quit;

proc means data=_label_3 noprint;
by top &by_var. label;
var &y.;
output out=_stds std=std_label mean=mean_label;
run;quit;

data _outlier_1(drop=_freq_ _type_);
merge _label_3 _stds;
by top &by_var. label;
critval = quantile("gaussian",&quantl,0,1);
upper = mean_label + critval * std_label;
lower = mean_label - critval * std_label;
if (&y. > upper or &y. < lower) then outlier_1 = 1;
else outlier_1 = 0;
run;

data &outdsn (keep=&by_var. &y. &time_var. outlier_1 rename=(outlier_1=outlier)
%if &num_ids %then %do; 
/*    rename = (*/
/*       %let i = 1;*/
/*       %do %while (%scan(&by_var, &i) ne );*/
/*          %let by_var_iter = %scan(&by_var, &i);*/
/*                &by_var_iter.n = &by_var_iter */
/*          %let i = %eval(&i + 1);*/
/*       %end;*/
/*    )*/
%end;
);
set _outlier_1;
%if &num_ids %then %do;
%let i=1;
%do %while (%scan(&by_var, &i) ne );
%let by_var_iter = %scan(&by_var, &i);
format &by_var_iter.n 32.;
&by_var_iter.n = input(&by_var_iter,32.);
drop &by_var_iter;
rename &by_var_iter.n = &by_var_iter;
%let i = %eval(&i + 1);
%end;
%end;

run;

%mend;

