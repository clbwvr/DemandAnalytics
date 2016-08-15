
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


%MACRO volume_prediction(	libn=, 
							outlibn=,
							dsn_train=,
							dsn_center_clus=,
							dsn_score=,
							outdsn_train=,
							outdsn_score=,
							byvar=,
							byvar_reg=,
							y=,
							input_var=,
							forest_input=,
							reg_input_class=,
							reg_input_int=,
							neural_input_nom=,
							neural_input_int=,
							attrb_vol=,
							cluster_name=,
							score_only=0
							);

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
		var &y;
		output out=&outlibn..reg_data_train_volume sum(&y)=;
	RUN;QUIT;

/*====================================================================================================*/
/* Based on attributes, predict volume - training */
/*====================================================================================================*/

*Model 1;
*--------------------------------------------------------------;
	PROC HPFOREST data=&outlibn..reg_data_train_volume vars_to_try=all;
		target &cluster_name.  / level=nominal;
		id &byvar.;
		input &forest_input. / level=nominal; 
		score out=&outlibn..train_forest_vol_pred_v1;
		save file="hpforest2_code.sav";
	RUN;QUIT;

	DATA &outlibn..train_forest_vol_pred_v2(drop=P_&cluster_name.: F_&cluster_name.: I_&cluster_name.: _WARN_) ;
		set &outlibn..train_forest_vol_pred_v1;
		&cluster_name. = input(I_&cluster_name.,8.);
	RUN;

	PROC SORT data=&outlibn..train_forest_vol_pred_v2;
		by &cluster_name.;
	RUN;QUIT;

	DATA &outlibn..train_forest(drop=mean--N &cluster_name.);
		merge &outlibn..train_forest_vol_pred_v2(in=a) &dsn_center_clus;
		by &cluster_name.;
		if a;
		if (median>0) then predict_forest=median;
		else predict_forest=mean;
	RUN;

*Model 2;
*--------------------------------------------------------------;
	%if not (&byvar_reg=) %then %do;
		PROC SORT data=&outlibn..reg_data_train_volume;
			by &byvar_reg;
		RUN;QUIT;
	%end;

	PROC HPREG data=&outlibn..reg_data_train_volume noprint;
		%if not (&byvar_reg.=) %then by &byvar_reg.;
		id &byvar.;
		class &reg_input_class.;
		model &y=&reg_input_class. &reg_input_int.;
		selection method=lasso;
		output out=&outlibn..train_reg_v1 predicted=predict_reg;
		code file="hpreg_code.sas";
	RUN;QUIT;

	DATA &outlibn..train_reg;
		set &outlibn..train_reg_v1;
		if (predict_reg<0) then predict_reg=0;
	RUN;

*Model 3;
*--------------------------------------------------------------;

	PROC HPNEURAL data=&outlibn..reg_data_train_volume noprint;
		id &byvar.;
		input &neural_input_nom. / level=nom;
		%if not (&neural_input_int.=) %then %do; 
			input &neural_input_int. / level=int;
		%end;
		target &y / level=int act=tanh;
		hidden 3;
		train outmodel=&outlibn..model_info maxiter=1000;
		score out=&outlibn..train_neural(drop=_WARN_ rename=(P_&y = predict_neural)); 
		code file="hpneural_code.sas";
	RUN;QUIT;

/*====================================================================================================*/
/* Merge data sets train */
/*====================================================================================================*/

	PROC SORT data=&outlibn..train_forest;
		by &byvar.;
	RUN;QUIT;

	PROC SORT data=&outlibn..train_reg;
		by &byvar.;
	RUN;QUIT;

	PROC SORT data=&outlibn..train_neural;
		by &byvar.;
	RUN;QUIT;

	DATA &libn..&outdsn_train(keep=&byvar_low predict_forest predict_reg predict_neural &y);
		merge &outlibn..train_forest  &outlibn..train_reg &outlibn..train_neural &outlibn..reg_data_train_volume;
		by &byvar.;
	RUN;

/*====================================================================================================*/
/* Train END */
/*====================================================================================================*/

%end;

/*====================================================================================================*/
/* Volume scoring */
/*====================================================================================================*/

* Score HPFOREST;
*--------------------------------------------------------------;
	PROC HP4SCORE data=&dsn_score.;
		id &byvar.;
		score file="hpforest2_code.sav" out=&outlibn..score_forest_vol_pred_v1;
	RUN;QUIT;

	DATA &outlibn..score_forest_vol_pred_v2(drop=P_: I_: _WARN_);
		set &outlibn..score_forest_vol_pred_v1;
		&cluster_name. = input(I_&cluster_name,8.);
	RUN;

	PROC SORT data=&outlibn..score_forest_vol_pred_v2;
		by &cluster_name;
	RUN;QUIT;

	DATA &outlibn..scored_predict_forest(drop=mean--N &cluster_name.);
		merge &outlibn..score_forest_vol_pred_v2(in=a) &dsn_center_clus.;
		by &cluster_name.;
		if a;
		if (median>0) then predict_forest=median;
		else predict_forest=mean;
	RUN;

* Score HPREG;
*--------------------------------------------------------------;
	DATA &outlibn..scored_predict_reg;
		set &dsn_score;
		%include "hpreg_code.sas";
		if (P_&y<0) then P_&y=0;
		rename P_&y = predict_reg;
	RUN;

* Score HPNEURAL;
*--------------------------------------------------------------;
	DATA &outlibn..scored_predict_neural(drop=_WARN_);
		set &dsn_score;
		%include "hpneural_code.sas";
		if (P_&y<0) then P_&y=0;
		rename P_&y = predict_neural;
	RUN;

/*====================================================================================================*/
/* Merge data sets score */
/*====================================================================================================*/

	PROC SORT data=&outlibn..scored_predict_forest;
		by &byvar.;
	RUN;QUIT;

	PROC SORT data=&outlibn..scored_predict_reg;
		by &byvar.;
	RUN;QUIT;

	PROC SORT data=&outlibn..scored_predict_neural;
		by &byvar.;
	RUN;QUIT;

	DATA &libn..&outdsn_score.;
		merge &outlibn..scored_predict_forest &outlibn..scored_predict_reg &outlibn..scored_predict_neural;
		by &byvar.;
	RUN;

/*==================================================================================*/
/*   delete intermediate files */
/*==================================================================================*/

	PROC DATASETS library=&outlibn memtype=data nolist;
		delete  reg_data_train_volume
				train_forest_vol_pred_v1
				train_forest_vol_pred_v2
				train_forest
				train_reg_v1
				train_reg
				model_info
				train_neural
				frst_reg_neu_predictions
				train_all
				train_final
				score_forest_vol_pred_v1
				score_forest_vol_pred_v2
				scored_predict_forest
				scored_predict_reg
				scored_predict_neural
				scored_predict_all
				;
	RUN;QUIT;  

	PROC DATASETS library=work memtype=data nolist;
		delete  _namedat
				;
	RUN;QUIT; 

%MEND;