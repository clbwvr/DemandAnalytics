/********************************************************************************************************
*
*	PROGRAM: 	Generates a forecast of items with no history
*
*	PROJECT: HBI
*
*	MACRO PARAMETERS:
*	----Name-------------------Description-------------------------------------------------------------------	
*	libn							name of SAS library where input data set resides 
*	outlibn							name of SAS library where output data sets reside
*	dsn_train						data set name of input file using to train models
*	dsn_score						data set name of input file using to score models
*	outdsn_exc_c					data set name of output file with items excluded from the modeling training in the pattern cluster procedure
*	outdsn_center_c					data set name of output file for pattern cluster centroids,
*	outdsn_all_ts_c					data set name of output file for the original time series data set with pattern cluster added,
*	outdsn_clus_byvar_c				data set name of output file for with by variables and pattern cluster column,
*	outdsn_exc_v					data set name of output file with items excluded from the modeling training in the volume cluster procedure
*	outdsn_center_v					data set name of output file for cluster statistics for volume, 
*	outdsn_all_ts_v					data set name of output file for with by variable and pattern cluster column,
*	outdsn_clus_byvar_v				data set name of output file for with by variables and volume cluster column,
*	outdsn_train_final_pattern		
*	outdsn_score_final_pattern		
*	outdsn_train_final_volume		
*	outdsn_score_final_volume		
*	outdsn_train_ensemble_volume	
*	outdsn_score_ensemble_volume	
*	outdsn_predict_file				data set name of output file final prediction
*	cluster_name_c					name of pattern cluster variable,
*	cluster_name_v					name of volume cluster variable,
*	likelihood_name					name of likelihood vector,
*	likelihood_loess_name			name of Loess likelihood smooth vector,
*	NPF_predict_name				name of final NPF prediction,
*	y								response variable
*	input_var						all input varaibles that are used in the analysis 
*	byvar_clus_patn					by variabls level that is used by pattern clustering,
*	byvar_clus_vol					by variabls level that is used by volume clustering,
*	byvar_low						by variable that identify the lowest level
*	byvar_reg						by variable that might be used in the volume regression 
*	attrb_dist						attributes used in the pattern cluster classification - HPSPLIT,
*	attrb_vol						attributes used volume classification - HPSPLIT&FOREST,
*	reg_class						class regression variables in the volume regression,
*	reg_input						all regression variables in the volume regression,
*	neural_input_nom 				nominal variables in the neural network model - at least one,
*	neural_input_int				interval varaibles in the neural network model - at least one,
*	min_ts_length					minimum lenght of time series included in the cluster training		
*	index_no						number of indexes used for each time series where pattern or volume are clustering is performed on 
*	cluster_threshold				determine number of clusters - default set to 0.02
*	loess							indicator 0/1 - 1=use Loess smoothed likelihood vector in NPF=volume x likelihoodvector
*	volume_model					what model to use in volume modeling, options (forest, reg, neural, all(default))
* 	datevar							date variable name
*	timeint_season					time interval in the input data set
*	enddate							end date of the historical observations
*	score_only						if set to 0 then the models are train and scored, if set to 1, only scoring is taking place
*	========================================================================================================================
*   AUTHOR:	Christian Haxholdt, Ph.D. (christian.haxholdt@sas.com), SAS Professional Services & Delivery, Cary, NC, USA	
*			Chris Houck, Ph.D. (chris.houck@sas.com), SAS Professional Services & Delivery, Cary, NC, USA
*			
*
*	CREATED:	April, 2015	 
********************************************************************************************************************/


%MACRO new_product_forcasting(	libn=ss, 
								outlibn=ss_out,
								dsn_train=,
								dsn_score=,
								outdsn_exc_c=excluded_cluster,
								outdsn_center_c=cluster_center_pattern, 
								outdsn_all_ts_c=all_ts_cluster_pattern,
								outdsn_clus_byvar_c=cluster_byvar_pattern,
								outdsn_exc_v=excluded_volume,
								outdsn_center_v=cluster_center_volume, 
								outdsn_all_ts_v=all_ts_cluster_volume,
								outdsn_clus_byvar_v=cluster_byvar_volume,
								outdsn_train_final_pattern=train_final_pattern,
								outdsn_score_final_pattern=score_final_pattern,
								outdsn_train_final_volume=train_final_volume,
								outdsn_score_final_volume=score_final_volume,
								outdsn_train_ensemble_volume=train_ensemble_volume,
								outdsn_score_ensemble_volume=score_ensemble_volume,
								outdsn_predict_file=final_prediction,
								cluster_name_c=cluster_pattern,
								cluster_name_v=cluster_volume,
								likelihood_name=likelihood,
								likelihood_loess_name=likelihood_loess,
								predict_name_volume=prediction_volume,
								NPF_predict_name=predict,
								y=,
								input_var=,
								byvar_low=,
								byvar_clus_patn=&byvar_low,
								byvar_clus_vol=&byvar_low,
								byvar_reg=, 
								attrb_dist=,
								forest_input=,
								reg_class=,
								reg_input=,
								neural_input_nom=,
								neural_input_int=,
								min_ts_length=,
								index_no=,
								cluster_threshold=0.05,
								loess=0,
								volume_model=all,
								datevar=,
								timeint_season=,
								enddate=,
								score_only=0
								);


%include "C:\Users\chhaxh\Documents\SAS_CODE_DATA\Clustering\Code\cluster_season.sas";
%include "C:\Users\chhaxh\Documents\SAS_CODE_DATA\Clustering\Code\cluster_volume_ts.sas";
%include "C:\Users\chhaxh\Documents\SAS_CODE_DATA\NPF\Code\pattern_classification.sas";
%include "C:\Users\chhaxh\Documents\SAS_CODE_DATA\NPF\Code\volume_prediction.sas";
%include "C:\Users\chhaxh\Documents\SAS_CODE_DATA\Time_Series_Forecasting_Engines\Ensemble\forecast_ensemble.sas";
ods noresults;
/*====================================================================================================*/
/* Program abort if parameter setting for cluster is wrong */
/*====================================================================================================*/

%if not (&score_only=0 or &score_only=1) %then %do;
	%let score_only=1;
	%put ERROR: score_only must be 0 or 1 - set 1;
%end;

/*====================================================================================================*/
/* Program abort if parameter setting for cluster is wrong */
/*====================================================================================================*/

%if (&volume_model=forest or &volume_model=reg or &volume_model=neural or &volume_model=all) %then %do;
%end;
%else %do;
	%let volume_model=tree;
	%put ERROR: volume_model, must be set to either <tree>, ,forest>, <reg>, <neural>, or <all> - it is default set to <tree>;
%end;

/*====================================================================================================*/
/* Train START */
/*====================================================================================================*/

%if (&score_only=0) %then %do;

/*====================================================================================================*/
/* Cluster the lcp timeseries to create cluster variable*/
/*====================================================================================================*/

	%cluster_season(	libn=&libn., 
						outlibn=&outlibn., 
						dsn=&libn..&dsn_train., 
						outdsn_exc=&outdsn_exc_c.,
						outdsn_center=&outdsn_center_c.,
						outdsn_byvar_ts=&outdsn_clus_byvar_c.,
						outdsn_all_ts=&outdsn_all_ts_c., 
						y=&y.,
						byvar_clus=&byvar_clus_patn.,
						byvar_low=&byvar_low.,
						datevar=&datevar., 
						time_int=&timeint_season., 
						index_cycle=1,
						min_ts_length=&min_ts_length.,
						index_no=&index_no.,
						dist=0,
						enddate=&enddate., 
						maxclus=20,
						minclus=2, 
						threshold=&cluster_threshold., 
						k=10,
						cluster_distance_metric=ward,
						cluster_method=Fast, 
						cluster_name=&cluster_name_c.,
						likelihood_name=&likelihood_name.,
						likelihood_loess_name=&likelihood_loess_name.
						);

/*====================================================================================================*/
/* Volume clustering for volume regression */
/*====================================================================================================*/

	%cluster_volume_ts(	libn=&libn., 
						outlibn=&outlibn., 
						dsn=&libn..&outdsn_all_ts_c.,
						outdsn_exc=&outdsn_exc_v.,
						outdsn_center=&outdsn_center_v.,
						outdsn_byvar=&outdsn_clus_byvar_v.,
						outdsn_all=&outdsn_all_ts_v.,
						y=&y.,
						byvar_clus=&byvar_clus_vol.,
						byvar_low=&byvar_low., 
						datevar=&datevar., 
						time_int=&timeint_season.,
						index_cycle=1, 
						min_ts_length=&min_ts_length.,
						index_no=&index_no.,
						enddate=&enddate., 
						maxclus=200,
						minclus=2, 
						threshold=0.01, 
						k=10,
						cluster_method=Fast,
						cluster_distance_metric=ward,
						cluster_name=&cluster_name_v.
						);

/*====================================================================================================*/
/* Train END */
/*====================================================================================================*/

%end;

/*====================================================================================================*/
/* Predict demand pattern */
/*====================================================================================================*/

%if (&score_only=0) %then %do;
	DATA &outlibn..ts_data_train_pattern;
		set &libn..&outdsn_all_ts_c.;
		by &byvar_low.;
		if (_cycle_ > &index_no.) then delete;
		if not (missing(&cluster_name_c.));
	RUN;
%end;

	%pattern_classification(libn=&libn., 
							outlibn=&outlibn.,
							dsn_train=&outlibn..ts_data_train_pattern,
							dsn_score=&libn..&dsn_score.,
							outdsn_train=&outdsn_train_final_pattern.,
							outdsn_score=&outdsn_score_final_pattern.,
							byvar=&byvar_low.,
							y=&y.,
							input_var=&input_var.,
							attrb_dist=&attrb_dist.,
							cluster_name=&cluster_name_c.,
							score_only=&score_only.
							);



/*====================================================================================================*/
/* Predict demand volume */
/*====================================================================================================*/

%if (&score_only=0) %then %do;
	DATA &outlibn..ts_data_train_volume;
		set &libn..&outdsn_all_ts_v.;
		by &byvar_low.;
		if (_cycle_ > &index_no.) then delete;
		if not (missing(&cluster_name_v.));
	RUN;
%end;

	%volume_prediction(	libn=&libn., 
						outlibn=&outlibn.,
						dsn_train=&outlibn..ts_data_train_volume,
						dsn_center_clus=&libn..&outdsn_center_v.,
						dsn_score=&libn..&outdsn_score_final_pattern.,
						outdsn_train=&outdsn_train_final_volume.,
						outdsn_score=&outdsn_score_final_volume.,
						byvar=&byvar_low.,
						byvar_reg=,
						y=&y.,
						input_var=&input_var.,
						forest_input=&forest_input.,
						reg_input_class=&reg_class.,
						reg_input_int=,
						neural_input_nom=&reg_class.,
						neural_input_int=,
						cluster_name=&cluster_name_v.,
						score_only=&score_only.
						);

* Ensemble;
*--------------------------------------------------------------;

%forecast_ensemble(	libn=&libn., 
					outlibn=&outlibn.,
					dsn_train=&libn..&outdsn_train_final_volume.,
					dsn_score=&libn..&outdsn_score_final_volume.,
					outdsn_train=&outdsn_train_ensemble_volume.,
					outdsn_score=&outdsn_score_ensemble_volume.,
					outdsn=test,
					id_var=&byvar_low.,
					by_var=,
					y=&y.,
					input_pred=predict_reg predict_neural,
					predict_name=&predict_name_volume
					);

/*====================================================================================================*/
/* NPF forecasting */
/*====================================================================================================*/
%local likelihood_use;
 
%if (&loess=1) %then %let likelihood_use=&likelihood_loess_name.;
%else %let likelihood_use=&likelihood_name.;

	DATA &libn..&outdsn_predict_file.;
		set &libn..&outdsn_center_c.;
		match=0; 
		do i=1 to xnobs;
			set &libn..&outdsn_score_ensemble_volume. (rename=(&cluster_name_c=_id_)) nobs=xnobs point=i;
			if &cluster_name_c=_id_ then do;
				match=1; 
				&NPF_predict_name.=&predict_name_volume.*&Likelihood_use.;
				output;
			end;
		end;
		rename match=_id_;
		drop _id_;
	RUN;
	
	PROC SORT data=&libn..&outdsn_predict_file.(keep=&byvar_low. _cycle_ &predict_name_volume. &Likelihood_use. &NPF_predict_name.);
		by &byvar_low.;
	RUN;QUIT;

/*====================================================================================================*/
/*   delete intermediate files */
/*====================================================================================================*/

	PROC DATASETS library=&outlibn. memtype=data nolist;
		delete  ts_data_train_pattern
				ts_data_train_volume
				&outdsn_exc_c.
				&outdsn_center_c.
				&outdsn_clus_byvar_c.
				&outdsn_all_ts_c.
				&outdsn_exc_v.
				&outdsn_center_v.
				&outdsn_clus_byvar_v.
				&outdsn_all_ts_v.
				&outdsn_train_final_pattern.
				&outdsn_score_final_pattern.
				&outdsn_train_final_volume.
				&outdsn_score_final_volume.
				&outdsn_train_ensemble_volume.
				&outdsn_score_ensemble_volume.
				;
	RUN;QUIT;  

	PROC DATASETS library=work memtype=data nolist;
		delete  _namedat
				;
	RUN;QUIT; 

%MEND new_product_forcasting;

%new_product_forcasting(dsn_train=train,
						dsn_score=score,
						y=order_qty,
						input_var=PRODUCT_LVL_NM2 PRODUCT_LVL_NM3 STORE_LOCATION_LVL_NM2 STORE_LOCATION_LVL_NM3,
						byvar_low=PRODUCT_id STORE_LOCATION_ID,
						attrb_dist=PRODUCT_LVL_NM2 PRODUCT_LVL_NM3 STORE_LOCATION_LVL_NM2 STORE_LOCATION_LVL_NM3 PRODUCT_ID,
						forest_input=PRODUCT_LVL_NM2 PRODUCT_LVL_NM3 STORE_LOCATION_LVL_NM2 STORE_LOCATION_LVL_NM3,
						reg_class=PRODUCT_LVL_NM2 PRODUCT_LVL_NM3 STORE_LOCATION_LVL_NM2 STORE_LOCATION_LVL_NM3,
						reg_input=PRODUCT_LVL_NM2 PRODUCT_LVL_NM3 STORE_LOCATION_LVL_NM2 STORE_LOCATION_LVL_NM3,
						neural_input_nom=PRODUCT_LVL_NM2 PRODUCT_LVL_NM3 STORE_LOCATION_LVL_NM2 STORE_LOCATION_LVL_NM3,
						neural_input_int=,
						min_ts_length=52,
						index_no=52,
						datevar=start_dt,
						timeint_season=week,
						enddate='31mar2015'd
						);


