/******************************************************************************
*
*  Name: learn_neighbors.sas
*
*  Author: Caleb Weaver - caleb.weaver@sas.com
*
*  Description: Optimize Neighbor k
*
******************************************************************************/

%macro learn_neighbors(indsn=,x=,break=,outdsn=);

options nomlogic nomprint;
proc sql noprint;select distinct market into : markets separated by ' ' from &indsn; quit;

%let j=1;;
%do %while (%scan(&markets, &j) ne );
%let k=1;
%let marketj = %scan(&markets, &j);
data indsn_&marketj.; set &indsn; if market = &marketj; run;

proc sql noprint;select distinct prod_id_lvl5 into : prod_id_lvl5s separated by ' ' from indsn_&marketj.; quit;

%do %while (%scan(&prod_id_lvl5s, &k) ne );

%let prod_id_lvl5k = %scan(&prod_id_lvl5s, &k);

data indsn_&marketj._&prod_id_lvl5k(keep=&x);
set indsn_&marketj.;
if prod_id_lvl5 = &prod_id_lvl5k; 
run;

/* Start here with indsn_&marketj */
proc distance data=indsn_&marketj._&prod_id_lvl5k out=dist method=euclid nostd prefix=dist;  
var interval(&x); 
run;  

proc sql noprint;select sum(1) into : n from dist; quit;

proc transpose data=dist out=t(drop=_NAME_) prefix=dist;
run;

data dist; set dist; id=_N_; run;
data t; set t; id=_N_; run;
data upandlow;
update dist t;
by id;
run;

data mirror;
set upandlow;
w=sum(dist1 < &break %do i = 2 %to &n; , dist&i < &break %end; ); 
x=sum(dist1 = . %do i = 2 %to &n; , dist&i = . %end; );
y=sum(dist1 = 0 %do i = 2 %to &n; , dist&i = 0 %end; );
z=w-(x+y);
run;

proc means data=mirror noprint;
var z;
output out=learn_&marketj._&prod_id_lvl5k(keep=k) median=k;
run;

data learn_&marketj._&prod_id_lvl5k; 
set learn_&marketj._&prod_id_lvl5k; 
market = &marketj; 
run;

%let k=%sysevalf(&k+1);
%end;
%let j=%sysevalf(&j+1);
%end;

data temp; set learn_:; run;

proc means data=temp(keep=market k) noprint;
by market;
var k;
output out=&outdsn(keep=market k) median=k;
run;

data &outdsn;
set &outdsn;
k = ceil(k);
run;

proc datasets lib=work;
delete learn_:;
run;

options mlogic mprint;

%mend;
