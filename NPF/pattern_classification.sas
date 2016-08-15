
/********************************************************************************************************
*
*	PROGRAM: 	Generates a forecast of items with no history
*
*	PROJECT: 
*
*	MACRO PARAMETERS:
*	----Name-------------------Description-------------------------------------------------------------------	
*	libn					name of SAS library where input data set resides 
*	outlibn					name of SAS library where output data sets reside
*	dsn_train				data set name of input file using to train models
*	dsn_score				data set name of input file using to score models
*	========================================================================================================================
*   AUTHOR:	Christian Haxholdt, Ph.D. (christian.haxholdt@sas.com), SAS Professional Services & Delivery, Cary, NC, USA	
*			Chris Houck, Ph.D. (chris.houck@sas.com), SAS Professional Services & Delivery, Cary, NC, USA
*			
*
*	CREATED:	April, 2015	 
********************************************************************************************************************/


%MACRO pattern_classification(	libn=, 
								outlibn=,
								dsn_train=,
								dsn_score=,
								outdsn_train=,
								outdsn_score=,
								byvar=,
								y=,
								input_var=,
								attrb_dist=,
								cluster_name=,
								score_only=0
								);


%local cluster_q;

/*====================================================================================================*/
/* Train START */
/*====================================================================================================*/

%if (&score_only=0) %then %do;

/*====================================================================================================*/
/* Create model training data for demand pattern and volume */
/*====================================================================================================*/

	PROC MEANS data=&dsn_train. noprint;
		by &byvar.;
		id &cluster_name. &input_var.;
		var &y.;
		output out=&outlibn..reg_data_train_pattern sum(&y)=;
	RUN;QUIT;

/*====================================================================================================*/
/* Check if there is only one cluster */
/*====================================================================================================*/
%let cluster_q=1;

	PROC MEANS data=&outlibn..reg_data_train_pattern noprint;
		var &cluster_name;
		output out=&outlibn..test_num_cluster(drop=_type_ _freq_) STD(&cluster_name_c)=STD;
	RUN;QUIT; 

	DATA _NULL_;
		set &outlibn..test_num_cluster1;
		if (STD=0) then do;
		 	call symput('cluster_q',0);
		end;
	RUN;

	%if (&cluster_q=0) %then %do;
		%put ERROR: There is only ONE pattern Cluster, no classification is performed, please check input data, and DO NOT only score;

		DATA &outlibn..scored_pattern_done;
			set &libn..&dsn_score;
			&cluster_name.=1;
		RUN;

		EXIT;
	%end;

/*====================================================================================================*/
/* Based on attributes, predict cluster pattern membership - training */
/*====================================================================================================*/

*Model 1;
*--------------------------------------------------------------;
	PROC HPSPLIT data=&outlibn..reg_data_train_pattern;
		target &cluster_name. / level=nom;
		id &byvar.;
		input &attrb_dist. / level=nom;
		score out=&outlibn..train_tree_pattern;
		code file="hpsplit_code.sas";
	RUN;QUIT;

	DATA &outlibn..train_tree_pattern_done(drop=i max P_&cluster_name.: _NODE_ _LEAF_);
		set &outlibn..train_tree_pattern;
		array x {*} P_&cluster_name.:;    
		max = max(of x[*]);
		do i=1 to (dim(x));
			if x{i}=max then hpsplit_pattern_cluster=dim(x)-i+1;
		end; 
	RUN;

*Model 2;
*--------------------------------------------------------------;
	PROC HPFOREST data=&outlibn..reg_data_train_pattern vars_to_try=all;
		target &cluster_name.  / level=nominal;
		id &byvar;
		input &attrb_dist. / level=nominal; 
		score out=&outlibn..train_forest_pattern;
		save file="hpforest1_code.sav";
	RUN;QUIT;

	DATA &outlibn..train_forest_pattern_done(drop=i max F_&cluster_name. I_&cluster_name. P_&cluster_name.: _WARN_);
		set &outlibn..train_forest_pattern;
		array x {*} P_&cluster_name.:;    
		max = max(of x[*]);
		do i=1 to (dim(x));
			if x{i}=max then hpforest_pattern_cluster=i;
		end; 
	RUN;

/*====================================================================================================*/
/* Ensemble - training */
/*====================================================================================================*/

	PROC SORT data=&outlibn..train_tree_pattern_done;
		by &byvar.;
	RUN;QUIT;

	PROC SORT data=&outlibn..train_forest_pattern_done;
		by &byvar.;
	RUN;QUIT;

	DATA &outlibn..train_models;
		merge &outlibn..train_tree_pattern_done &outlibn..train_forest_pattern_done;
		by &byvar.;
	RUN;

	PROC HPNEURAL data=&outlibn..train_models noprint;
		id &byvar.;
		input hpsplit_pattern_cluster hpforest_pattern_cluster / level=nom;
		target &cluster_name. / level=nom;
		hidden 3;
		train outmodel=&outlibn..model_info_pattern maxiter=1000;
		score out=&outlibn..train_ensemble;
		code file="hpneural_pattern_code.sas";
	RUN;QUIT;

	DATA &libn..&outdsn_train(drop=i max _WARN_ P_&cluster_name.: I_&cluster_name. );
		set &outlibn..train_ensemble;
		array x {*} P_&cluster_name.;    
		max = max(of x[*]);
		do i=1 to (dim(x));
			if x{i}=max then &cluster_name.=dim(x)-i+1;
		end; 
	RUN;

/*====================================================================================================*/
/* Train END */
/*====================================================================================================*/

%end;

/*====================================================================================================*/
/* Cluster scoring - classification */
/*====================================================================================================*/

* Score HPSLIT;
*--------------------------------------------------------------;
	DATA &outlibn..scored_tree_pattern;
		set &dsn_score;
		%include "hpsplit_code.sas";
	RUN;

	DATA &outlibn..scored_tree_pattern_done(drop=i max P_&cluster_name.: _NODE_ _LEAF_ _WARN_);
		set &outlibn..scored_tree_pattern;
		array x {*} P_&cluster_name.:;    
		max = max(of x[*]);
		do i=1 to (dim(x));
			if x{i}=max then hpsplit_pattern_cluster=dim(x)-i+1;
		end; 
	RUN;

* Score HPFOREST;
*--------------------------------------------------------------;
	PROC HP4SCORE data=&dsn_score;
		id &byvar.;
		score file="hpforest1_code.sav" out=&outlibn..scored_forest_pattern;
	RUN;QUIT;

	DATA &outlibn..scored_forest_pattern_done(drop=i max I_&cluster_name. P_&cluster_name.: _WARN_);
		set &outlibn..scored_forest_pattern;
		array x {*} P_&cluster_name.:;    
		max = max(of x[*]);
		do i=1 to (dim(x));
			if x{i}=max then hpforest_pattern_cluster=i;
		end; 
	RUN;

/*====================================================================================================*/
/* Ensemble - score */
/*====================================================================================================*/

	PROC SORT data=&outlibn..scored_forest_pattern_done;
		by &byvar.;
	RUN;QUIT;

	DATA &outlibn..score_models;
		merge &outlibn..scored_tree_pattern_done &outlibn..scored_forest_pattern_done;
		by &byvar.;
	RUN;
	
	DATA &outlibn..score_ensemble;
		set &outlibn..score_models;
		%include "hpneural_pattern_code.sas";
	RUN;

	DATA &libn..&outdsn_score(drop=i max _WARN_ P_&cluster_name.:);
		set &outlibn..score_ensemble;
		array x {*} P_&cluster_name.;    
		max = max(of x[*]);
		do i=1 to (dim(x));
			if x{i}=max then &cluster_name.=dim(x)-i+1;
		end; 
	RUN;

/*==================================================================================*/
/*   delete intermediate files */
/*==================================================================================*/

	PROC DATASETS library=&outlibn memtype=data nolist;
		delete  test_num_cluster
				ts_data_train_pattern
				reg_data_train_pattern 
				ts_data_train_volume
				reg_data_train_volume 
				train_tree_pattern
				train_tree_pattern_done
				train_forest_pattern
				train_forest_pattern_done
				train_models
				train_ensemble
				model_info_pattern
				scored_tree_pattern
				scored_forest_pattern
				scored_tree_pattern_done
				scored_forest_pattern_done
				scored_pattern_neural
				scored_tree_forest_pattern
				score_models
				score_ensemble
				;
	RUN;QUIT;  

	PROC DATASETS library=work memtype=data nolist;
		delete  _namedat
				;
	RUN;QUIT; 

%MEND;