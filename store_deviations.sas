/******************************************************************************
*
*   Name: store_deviations.sas
*
*   Author: Caleb Weaver - caleb.weaver@sas.com
*
*   Description: Create store strengths
*
*   Parameters:
*   indsn: Input dataset
*   anchor: Anchor date for forecast. 0 for all data.
*   time_var: Time Variable
*   by_var_high: Aggregate level by variables
*   by_var_low: Low level by variables
*   length: Length of length_int to calculate store strengths over
*   length_int: Time interval.
*   outdsn: Output dataset
*   dev_var: Output column name
*   standardize: Standardize to mean at 1 within by_var_high
*
******************************************************************************/

%macro store_deviations(
indsn=,
anchor=,
y=,
by_var_high=,
by_var_low=,
length=,
length_int=,
outdsn=,
dev_var=deviation,
standardize=1
);

/* Get data to calculate strengths over */
data ly;
set &indsn;
if (wk_start_dt le &anchor.) and (wk_start_dt ge intnx("&length_int",&anchor,-&length,"s"));
run;

proc sort data=ly out=low;
by &by_var_low;
run;

proc sort data=ly out=high;
by &by_var_low;
run;

/* Get low level means */
proc means data=low noprint;
var &y;
by &by_var_low;
output out=meanslow(keep=&by_var_low mlow) mean=mlow;
run;

/* Get high level means */
proc means data=high noprint;
var &y;
%if "&by_var_high" ne "" %then %do;
by &by_var_high;
%end;
output out=meanshigh(keep=&by_var_high mhigh) mean=mhigh;
run;

%if "&by_var_high" ne "" %then %do;
proc sort data=meanslow;
by &by_var_high;
run;
%end;

%if "&by_var_high" ne "" %then %do;
proc sort data=meanshigh;
by &by_var_high;
run;
%end;

/* Calculate Strengths */

%if "&by_var_high" ne "" %then %do;
data &outdsn(keep=&by_var_low &dev_var);
merge meanshigh meanslow;
%if "&by_var_high" ne "" %then %do;
by &by_var_high;
%end;
if mhigh > 0 then &dev_var = mlow / mhigh;
else &dev_var = 0;
run;
%end;

%else %do;
data &outdsn(keep=&by_var_low &dev_var);
set meanslow;
do i=1 to n;
set meansshigh point=i nobs=n;
if migh > 0 then &dev_var = mlow / mhigh;
else &dev_var = 0;
output;
end;
run;
%end;

/* Standardize Strengths */

%if &standardize %then %do;
proc sort data=&outdsn; by &by_var_high; run;
proc means data=&outdsn noprint;
by &by_var_high;
var &dev_var;
output out=mstd(keep=&by_var_high m&dev_var) mean=m&dev_var;
run;

/* Output */
data &outdsn(drop=&dev_var rename=(temp=&dev_var));
merge &outdsn mstd;
by &by_var_high;
if m&dev_var > 0 then temp = &dev_var / m&dev_var;
else temp = 0;
run;
%end;

%mend;
