/******************************************************************************
*
*  Name: knn.sas
*
*  Author: Caleb Weaver - caleb.weaver@sas.com
*
*  Description: Neighbor Classification
*
******************************************************************************/

%macro knn(
indsn=,
list=,
x=,
y=,
neighbors=,
scoremaxhist=,
outdsn=
);

%let k = 1;

%do %while (%scan(&list, &k,!) ne );
%let p = %scan(&list, &k,!);

proc sort data=&indsn; by &p loc_id_lvl8; run;

proc means data=&indsn noprint;
by &p loc_id_lvl8;
var &x &y;
output out=ma(keep=&p loc_id_lvl8 &x &y)  mean=&x &y;
run;

proc means data=ma noprint;
by &p;
var &x;
output out=stds(keep=&p std) std=std;
run;

data ma(where=(std>0));
merge ma(in=a) stds;
by &p;
if a;
run;

proc sort data=ma; by &p loc_id_lvl8; run;

ods _all_ close;

%let mc = %sysevalf(&neighbors+1);
proc modeclus data=ma method=1 k=&mc Neighbor; 
id loc_id_lvl8;
by &p;
var &x;
ods output neighbor=neighbor;
run;
data neighbor(drop=nbor rename=(_a=nbor)); set neighbor;  _a = input(nbor, best32.); run;
data neighbor; set neighbor; retain loc_id_lvl8 1; if ID ne ' ' then loc_id_lvl8 = input(ID,best32.); run;
proc sort data=neighbor;
by &p loc_id_lvl8;
run;
data neighbor; 
set neighbor;
by &p loc_id_lvl8;
run;
proc sort data=&indsn; by &p loc_id_lvl8; run;
proc sort data=neighbor; by &p nbor; run;
data neighborpreds;
merge neighbor(in=a) &indsn(keep=&p loc_id_lvl8 &y rename=(loc_id_lvl8=nbor));
by &p nbor;
if a;
run;
proc sort data=neighborpreds; by &p loc_id_lvl8; run;

proc means data=neighborpreds noprint;
by &p loc_id_lvl8;
var &y;
output out=mnneighborpreds(where=(numk >= &neighbors)) mean=estimate n=numk;
run;

proc sort data=&indsn; by &p loc_id_lvl8; run;
proc sort data=mnneighborpreds(keep = &p loc_id_lvl8 estimate numk); by &p loc_id_lvl8; run;

data knn_&k;
merge &indsn(in=a) mnneighborpreds;
if a;
by &p loc_id_lvl8;
run;

proc sort data=knn_&k; by prod_id_lvl5 prod_id_lvl6 prod_id_lvl7 prod_id_lvl8 loc_id_lvl8;


%let k = %eval(&k + 1);
%end;

data &outdsn(drop=est_:);
merge
%let k = 1;
%do %while (%scan(&list, &k,!) ne );
%let p = %scan(&list, &k,!);
knn_&k(rename=(estimate=est_&k))
%let k = %eval(&k + 1);
%end;
;
by prod_id_lvl5 prod_id_lvl6 prod_id_lvl7 prod_id_lvl8 loc_id_lvl8;
if hist <= &scoremaxhist then do;
knnest =  coalesce(
%let k = 1;
%let p = %scan(&list, &k,!);
est_&k
%let k = 2;
%do %while (%scan(&list, &k,!) ne );
%let p = %scan(&list, &k,!);
, est_&k
%let k = %eval(&k + 1);
%end;
);
&y = mean(&y,knnest);
end;
else &y = &y;
run;

%mend;
