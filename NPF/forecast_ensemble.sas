/********************************************************************************************************
*
*	PROGRAM: 	Ensemble a set of time series forecasts
*
*	PROJECT: 
*
*	MACRO PARAMETERS:
*	----Name-------------------Description-------------------------------------------------------------------	
*	libn				name of SAS library where input data set resides 
*	outlibn				name of SAS library where output data sets reside
*	dsn					set of forecast time series data sets, that reside in 'libn'
*	outdsn				the ensembled output data set
*	by_var				by variables used in identification by variables
*	y					response variable name
*	predict				name of prediction variable, it is presumeed that all data sets has the same name of the prediction column
*	input				set of prediction variables used in the final ensemble
*	time_var			name of date variable column		
*	time_int			time interval in the input data set			
*	score_start_date	start of the time preiod to be forecasted or scored - format:'31dec2015'd
*	predict_no_use		number of predicts to use in the ensamble, e.g. #recom levels and the leaf
*	no_time_per			no of time periods to be used in modeling
*	========================================================================================================================
*   AUTHOR:	Christian Haxholdt, Ph.D. (christian.haxholdt@sas.com), SAS Professional Services & Delivery, Cary, NC, USA	
*			Caleb Weaver (caleb.weaver@sas.com), SAS Professional Services & Delivery, Cary, NC, USA
*		
*	CREATED:	July, 2016	 
********************************************************************************************************************/

%MACRO forecast_ensemble(	libn=, 
							outlibn=,
							dsn_train=,
							dsn_score=,
							outdsn_train=,
							outdsn_score=,
							outdsn=,
							id_var=,
							by_var=,
							y=,
							input_pred=,
							predict_name=
							);


/*====================================================================================================*/
/* Training forecast model HPF, HPREG, HPNEURAL */
/*====================================================================================================*/

%if not (&by_var.=) %then %do;
	PROC SORT data=&dsn_train.;
		by &by_var.;
	RUN;QUIT;
%end;


* Regression train;
*------------------------------------------------------------------------------------------------------;

	PROC HPREG data=&dsn_train. noprint;
		id &id_var. &y.;
		%if not (&by_var.=) %then %do; by &by_var.; %end;
		model &y=&input_pred.;
		output out=&outlibn..pred_train_reg predicted=predict_reg_ensemble;
		code file="hpreg_code.sas";
	RUN;QUIT;

* Neural train;
*------------------------------------------------------------------------------------------------------;

	PROC HPNEURAL data=&dsn_train. noprint;
		id &id_var. &y.;
		input &input_pred.  / level=int;
		target &y / level=int act=tanh;
		hidden 3;
		train outmodel=&outlibn..model_info maxiter=1000;
		score out=&outlibn..pred_train_neural(rename=(P_&y = predict_neural_ensemble)); 
		code file="hpneural_code.sas";
	RUN;QUIT;
 
/*====================================================================================================*/
/* Ensemble final train */
/*====================================================================================================*/

	DATA &outlibn..train_models(drop=_WARN_);
		merge &outlibn..pred_train_neural &outlibn..pred_train_reg;
		by &by_var.;
	RUN;

	PROC HPNEURAL data=&outlibn..train_models noprint;
		id &id_var.;
		input predict_reg_ensemble  predict_neural_ensemble / level=int;
		target &y / level=int act=tanh;
		hidden 3;
		train outmodel=&outlibn..model_info maxiter=1000;
		score out=&outlibn..train_all; 
		code file="hpneural_opt_code.sas";
	RUN;QUIT;

	DATA &libn..&outdsn_train(drop=_WARN_);
		merge &outlibn..train_all &outlibn..train_models &dsn_train. ;
		if (P_&y<0 or P_&y=.) then P_&y=0;
		rename P_&y=&predict_name.;
	RUN;

/*====================================================================================================*/
/* Score regression and neural network forecast data set */
/*====================================================================================================*/

%if not (&by_var.=) %then %do;
	PROC SORT data=&outlibn..out_score;
		by &by_var.;
	RUN;QUIT;
%end;

* Regression score;
*------------------------------------------------------------------------------------------------------;

	DATA &outlibn..pred_score_reg;
		set &dsn_score.;
		%include "hpreg_code.sas";
		if (P_&y<0) then P_&y=0;
		rename P_&y = predict_reg_ensemble;
	RUN;

* Neural score;
*------------------------------------------------------------------------------------------------------;

	DATA &outlibn..pred_score_neural(drop=_WARN_);
		set &dsn_score.;
		%include "hpneural_code.sas";
		if (P_&y<0) then P_&y=0;
		rename P_&y = predict_neural_ensemble;
	RUN;

/*====================================================================================================*/
/* Ensemble final score */
/*====================================================================================================*/

	DATA &outlibn..score_models;
		merge &outlibn..pred_score_reg &outlibn..pred_score_neural;
		by &id_var.;
	RUN; 

	DATA &libn..&outdsn_score(drop=_WARN_);
		set &outlibn..score_models;
		%include "hpneural_opt_code.sas";
		if (P_&y<0 or P_&y=.) then P_&y=0;
		rename P_&y=&predict_name.;
	RUN;


/*==================================================================================*/
/*   delete intermediate files */
/*==================================================================================*/

	PROC DATASETS library=&outlibn memtype=data nolist;
		delete 	train_sort
				pred_train_reg
				pred_train_neural
				train_models
				train_final
				train_all
				pred_score_reg
				pred_score_neural
				model_info
				score_models
				score_final
				;
	RUN;QUIT; 

	PROC DATASETS library=work memtype=data nolist;
		delete _namedat;
	RUN;QUIT;


%MEND forecast_ensemble;