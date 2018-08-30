/*****************************************************************************
*
*    Name: impute_nulls.sas
*
*    Author: Caleb Weaver - caleb.weaver@sas.com
*
*    Description: demand modeling
*
*    Parameters:    
*    indsn: Input dataset
*    outdsn: Output dataset
*    y: dependent variable
*    cond: where clause
*    
*****************************************************************************/

%macro impute_nulls(
indsn=,
outdsn=,
list=,
y=,
cond=
);

/* Add top level */
data &indsn; set &indsn; top = 1; run;

%let i = 1;
%do %while (%scan(&list,&i,!) ne );
%let v = %scan(&list, &i,!);

proc sort data=&indsn nodupkey out=sin;
by &v &y;
run;

/* Get Prediction means */
proc means data=sin noprint;
by &v;
var &y;
&cond;
output out=m(keep=&v x) mean=x;
run;

/* Impute Prediction Means  */

proc sort data=&indsn; by &v; run;

data &indsn;
merge &indsn m;
by &v;
run;

data &indsn(drop=x);
set &indsn;
if &y = . then &y = x;
run;

%let i = %eval(&i + 1);

%end;

proc sql noprint;
alter table &indsn drop top;
quit;

%mend;

