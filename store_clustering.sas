/******************************************************************************
*
*   Name:                   store_clustering.sas
*
*   Author:                 Caleb Weaver - caleb.weaver@sas.com
*
*   Description:            Store clustering
*
*   Parameters:
*   iddsn – ID dataset
*   predict_dsn – Quantitative dataset 
*   predict_var – Prediction variable name
*   clus_pred_var – Cluster Membership variable name
*   y – Quantitative Variable
*   list – List of hierarchical values to perform cluster analysis within
*   neighbors – Optional input of number of neighbors in each cluster
*   maxiter – Optional input of maximum iterations of cluster analysis
*
*
******************************************************************************/

%macro store_clustering(
iddsn=,
predict_dsn=,
predict_var=,
clus_pred_var=cluspred,
y=,
list=,
neighbors=10,
maxiter=100
);

%let pass=0;
%let k = 1;

/* loop over list */
%do %while (%scan(&list, &k,!) ne );
%let p = %scan(&list, &k,!);
proc sort data=&predict_dsn; by &p loc_id_lvl8; run;

/* Get hierarchy hist */
/*proc means data=&predict_dsn noprint;*/
/*by &p;*/
/*var cchist;*/
/*output out=hist(keep=&p prodhist) max=prodhist;*/
/*run;*/

/*data &predict_dsn;*/
/*merge &predict_dsn*/
/*%if &k>1 %then %do;(drop=prodhist)%end;*/
/*hist;*/
/*by &p;*/
/*run;*/


/* Mean Dev Within Prod Hier / Store */
proc sort data=&iddsn; by &p loc_id_lvl8; run;
proc means data=&iddsn noprint;
by &p loc_id_lvl8;
var &y;
output out=iddsn_high(keep=&p loc_id_lvl8 &y) mean=&y;
run;
/*data iddsn_high_hist;*/
/*merge iddsn_high hist;*/
/*by &p;*/
/*run;*/

/* Calculate k as number of stores in a cluster */
proc sql noprint;
select ceil(mean(y) / &neighbors) into : maxc from (select count(*) as y from iddsn_high group by &p);
quit;
%put &maxc;
data clusin;
merge &iddsn iddsn_high;
by &p;
run;

proc sort data=clusin out=sclusin nodupkey;
by &p loc_id_lvl8;
run;

/* Cluster Analysis */
proc fastclus data=sclusin(where=(&y ne .)) 
noprint 
/*r=.2 */
maxc = &maxc
maxiter=100 
out=clusout(keep=&p loc_id_lvl8 cluster_&p) 
cluster=cluster_&p;
by &p;
var &y;
run;quit;

/* Get Cluster membership */
proc sort data=clusout nodupkey;
by &p loc_id_lvl8 cluster_&p;
run;
proc sql;
create table &predict_dsn as
select t1.*, t2.cluster_&p
from &predict_dsn t1 left join
clusout t2
on t1.&p=t2.&p
and t1.loc_id_lvl8=t2.loc_id_lvl8;
quit;

/* Get each cluster level prediction */
proc sql;
create table &predict_dsn as select *, 
case
when cluster_&p ne . then mean(&predict_var)
else . 
end as cluspred_&p
from &predict_dsn
group by &p, cluster_&p;
quit;

%let pass=1;
%let k = %eval(&k + 1);
%end;

/* Get Prediction as coalesce of Cluster Predictions in order of prod hier */
data &predict_dsn
/*
(drop=
%let k = 1;
%do %while (%scan(&list, &k,!) ne );
%let p = %scan(&list, &k,!);
cluster_&p cluspred_&p
%let k = %eval(&k + 1);
%end;
)
*/; set &predict_dsn;
&clus_pred_var = coalesce(
%let p = %scan(&list, 1,!);
cluspred_&p
%let k = 2;
%do %while (%scan(&list, &k,!) ne );
%let p = %scan(&list, &k,!);
, cluspred_&p
%let k = %eval(&k + 1);
%end;
);
run;

%mend;

