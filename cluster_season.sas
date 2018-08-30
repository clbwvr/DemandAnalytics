
%macro cluster_season(  libn=, 
outlibn=, 
dsn=,
y=,
byvar_clus=,
byvar_low=&byvar_clus.,
time_var=, 
time_int=, 
min_ts_length=12,
index_no=12,
dist=0,
end_date=, 
maxclus=200,
minclus=2, 
threshold=0.02, 
k=10,
);


/*==================================================================================================================================*/
/* Sort data set and add index and season */
/*==================================================================================================================================*/

PROC SORT data=&dsn. out=dsn_sort;
by &byvar_clus &time_var;
RUN;QUIT; 

PROC TIMEDATA data=dsn_sort out=_null_ outarray=timedata;
by &byvar_clus;
id &time_var interval=&time_int ACCUMULATE=total;
var &y;
RUN;QUIT;

/*==================================================================================================================================*/
/* Sort data set and add index and season                                              */
/*==================================================================================================================================*/

PROC SORT data=timedata;
by &byvar_clus _cycle_ &time_var;
RUN;QUIT;

PROC MEANS data=timedata noprint;
by &byvar_clus;
var _cycle_;
output out=max_cycle max=high;
RUN;QUIT;

DATA train_cluster(drop=_type_ _freq_ high) outdsn_exc(drop=_type_ _freq_ high);
merge timedata max_cycle(in=a);
by &byvar_clus;
if a;
if (&y<0 or missing(&y)) then &y=0;
if (high < &min_ts_length) then output outdsn_exc;
else output train_cluster;
RUN;

/*=====================================================================================================================================*/
/* Index=0. Aggregate to byvar level, and create season file. Estimate SEASONAL likelihood of demand by byvar and create transpose*/
/*=====================================================================================================================================*/ 

PROC SORT data=train_cluster;
by &byvar_clus &time_var;
RUN;QUIT;

%let datevarMax = %sysfunc(inputn(&end_date,mmddyy8.),date9.); 

PROC TIMESERIES data=train_cluster out=_null_ outseason=outseason(rename=(_season_=_CYCLE_));
by &byvar_clus;
id &time_var interval=&time_int end="&datevarMax"d;
var &y / accumulate=total;
RUN;QUIT;

PROC MEANS data=outseason noprint;
var mean;
by &byvar_clus;
output out=sum_season(drop=_type_ _freq_) sum(mean)=Sum_mean;
RUN;QUIT; 

DATA probability_dist(drop=Sum_mean);
merge sum_season outseason;
by &byvar_clus;
if (Sum_mean ne 0 and not missing(mean)) then do;
_LIKELIHOOD_=mean/Sum_mean;
end;
else _LIKELIHOOD_ = 0;
RUN;

PROC TRANSPOSE data=probability_dist prefix=&prefix_use out=Prob_transpose(drop=_name_);
by &byvar_clus;
var _LIKELIHOOD_;
id _CYCLE_;
*  where nmiss(_LIKELIHOOD_)=0;
RUN;QUIT;

DATA Prob_transpose (drop=i);
set Prob_transpose;
array varlist {*} &prefix_use:;
do i=1 to dim(varlist);
if varlist{i}=. then varlist{i}=0;
end;
RUN; 

/*==================================================================================*/
/* Perform cluster analysis*/
/*==================================================================================*/    

PROC FASTCLUS data=Prob_transpose summary maxc=&maxclus maxiter=99 converge=0 drift cluster=Pre_Clus_Fast out=pre_clus_fast mean=cluster_mean noprint;
var &prefix_use:;
RUN;QUIT;

PROC MEANS data=pre_clus_fast noprint;
var Pre_Clus_Fast;
output out=pre_clus_fast_stat(drop=_type_ _freq_) STD(Pre_Clus_Fast)=STD;
RUN;QUIT; 

DATA _NULL_;
set pre_clus_fast_stat;
if (STD=0) then do;
call symput('cluster_q',0);
end;
RUN;

PROC CLUSTER data=cluster_mean method=ward pseudo ccc outtree=cluster_tree;
var &prefix_use:;
copy Pre_Clus_Fast;
RUN;QUIT;

PROC SORT data=cluster_tree;
by _NCL_;
RUN;

DATA optimal_clusters(drop=Pre_Clus_Fast);
set cluster_tree;
if (_SPRSQ_ < &threshold and _NCL_>&minclus) then delete;
RUN;

DATA optimal_clusters;
set optimal_clusters;
call symput('ncl_F', _ncl_);
RUN;

PROC TREE data=cluster_tree ncl=&ncl_F out=tree(rename=(cluster=_cluster_)) noprint;
copy Pre_Clus_Fast;
RUN;QUIT;


/*==================================================================================*/
/* Merge FAST Cluster results back on original data set */
/*==================================================================================*/

PROC SORT data=pre_clus_fast;
by Pre_Clus_Fast;
RUN;QUIT; 

PROC SORT data=tree;
by Pre_Clus_Fast;
RUN;QUIT;

DATA fast_clus_season(drop = _cluster_ distance clusname _NAME_  pre_clus_fast);
merge pre_clus_fast tree;
by Pre_Clus_Fast;
if (_cluster_=.) then _cluster_c_=0;
_cluster_c_=_cluster_;
RUN; 

PROC SORT data=fast_clus_season;
by &byvar_clus;
RUN;QUIT;

DATA cluster_center_calc;
merge probability_dist fast_clus_season;
by &byvar_clus;
RUN;

PROC SORT data=cluster_center_calc;
by _cluster_c_;
RUN;QUIT;

PROC MEANS data=cluster_center_calc noprint;
var _LIKELIHOOD_;
by _cluster_c_;
output out=sum_cluster(drop=_type_ _freq_) sum(_LIKELIHOOD_)=Sum_cluster;
RUN;QUIT; 

PROC SORT data=cluster_center_calc;
by _cluster_c_. _CYCLE_;
RUN;QUIT;

PROC MEANS data=cluster_center_calc noprint;
var _LIKELIHOOD_;
by _cluster_c_. _CYCLE_;
output out=sum_index(drop=_type_ _freq_) sum(_LIKELIHOOD_)=Sum;
RUN;QUIT; 

DATA outdsn_center(drop=sum sum_cluster);
merge sum_index sum_cluster;
by _cluster_c_.;
if (Sum_cluster ne 0) then do;
_LIKELIHOOD_CLUSTER_=sum/Sum_cluster;
end;
else _LIKELIHOOD_CLUSTER_= 0;
RUN;

PROC LOESS data=outdsn_center.;
by _cluster_c_.;
model _LIKELIHOOD_CLUSTER_=_CYCLE_ / smooth=0.9 direct;
output out=Loess_result predicted=Predicted;
RUN;QUIT;

DATA Loess_result;
set Loess_result;
if (predicted<0) then predicted=_LIKELIHOOD_CLUSTER_;
RUN;

PROC MEANS data=Loess_result noprint;
var Predicted;
by _cluster_c_;
output out=sum_index_loess(drop=_type_ _freq_) sum(Predicted)=Sum;
RUN;QUIT; 

DATA outdsn_center.(drop=sum predicted SmoothingParameter--Obs);
merge sum_index_loess Loess_result;
by _cluster_c_;
if (Sum ne 0) then do;
_LIKELIHOOD_LOESS_=predicted/Sum;
end;
else _LIKELIHOOD_LOESS_=0;
RUN;


DATA index_cluster_ts(drop=&prefix_use:);
merge train_cluster fast_clus_season probability_dist;
by &byvar_clus;
RUN;

PROC SORT data=index_cluster_ts;
by _cluster_c_ _CYCLE_;
RUN;QUIT;

DATA outdsn_byvar_ts;
merge index_cluster_ts outdsn_center.;
by _cluster_c_ _CYCLE_;
RUN;

PROC SORT data=outdsn_byvar_ts;
by &byvar_clus _CYCLE_;
RUN;QUIT;

DATA outdsn_all_ts(drop=&prefix_use:);
merge dsn_sort fast_clus_season;
by &byvar_clus;
RUN;

PROC SORT data=outdsn_all_ts;
by &byvar_low &time_var;
RUN;QUIT; 

%MEND cluster_season;

