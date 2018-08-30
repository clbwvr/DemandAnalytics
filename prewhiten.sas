/******************************************************************************
*
* Name: prewhiten.sas
*
* Author: Caleb Weaver - caleb.weaver@sas.com
*
******************************************************************************/

%macro prewhiten(dsn=, byvar=, x=, y=, time_var=, time_int=, outdsn=);
proc sort data=&dsn; 
by &byvar &time_var; 
run;
proc hpfdiagnose data=&dsn outest=est modelrepository=work.mycat;
by &byvar;
id &time_var interval= &time_int;
forecast &x;
arimax;
run;quit;

proc hpfengine data=&dsn inest=est outest=fest modelrepository=work.mycat outfor=outfor; 
id &time_var interval= &time_int;
by &byvar;
forecast &x / task=select ;
run;quit;

* Filter x;
/*proc hpfengine data=&dsn inest=fest modelrepository=work.mycat outfor=outfor2;
id &time_var interval=&time_int;
by &byvar;
forecast &x / task=fit ;
run;*/
data xoutfor(rename=(error=&x._residuals));
set outfor(keep=&byvar error);
where error ne .;
run;

* Filter y with model x;
data fest;
set fest;
_NAME_ = "&y";
run;

proc hpfengine data=&dsn inest=fest modelrepository=work.mycat outfor=outfor;
id &time_var interval=&time_int;
by &byvar;
forecast &y / task=fit ;
run;quit;

data youtfor(rename=(error=&y._residuals));
set outfor(keep=&byvar error);
where error ne .;
run;

*Merge residuals;
data &outdsn;
merge xoutfor youtfor;
run;

*Regression;
/*proc reg data=&outdsn;
by &byvar;
model sale_residuals =  price_residuals;
run;quit;*/

proc hpreg data=&outdsn;
by &byvar;
model sale_residuals =  price_residuals;
run;quit;

%mend;