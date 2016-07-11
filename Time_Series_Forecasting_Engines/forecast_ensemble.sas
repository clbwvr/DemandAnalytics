/********************************************************************************************************
*
*	PROGRAM: 	Generates a forecast of items with no history
*
*	PROJECT: HBI
*
*	MACRO PARAMETERS:
*	----Name-------------------Description-------------------------------------------------------------------	
*	libn			name of SAS library where input data set resides 
*	outlibn			name of SAS library where output data sets reside
*	dsn_train		training data set with response
*	dsn_score		scoring data set with no response
*	id_var			by variables used in identification by variables
*	y				response variable name
*	input			set of prediction variables
*	date_var		name of date variable column		
*	time_int		time interval in the input data set			
*	hist_end_date	enn of history date - '31dec2015'd
*	no_time_per		no of time period to be used in modeling
*	========================================================================================================================
*   AUTHOR:	Christian Haxholdt, Ph.D. (christian.haxholdt@sas.com), SAS Professional Services & Delivery, Cary, NC, USA	
*			Caleb Weaver (caleb.weaver@sas.com), SAS Professional Services & Delivery, Cary, NC, USA
*		
*	CREATED:	February, 2016	 
********************************************************************************************************************/

%MACRO forecast_ensemble(	libn=, 
							outlibn=,
							dsn_train=,
							dsn_score=,
							outdsn=,
							id_var=,
							y=,
							input=,
							date_var=,
							time_int=,
							hist_end_date=,
							no_time_per=
							);

/*====================================================================================================*/
/* Truncating train data */
/*====================================================================================================*/

	DATA &outlibn..train_add;
		set /*&libn..&dsn_train.*/ &dsn_train.;	
		if &date_var >= intnx("&time_int", &hist_end_date, -&no_time_per) then do;
			train = 1;
		end;
		else do;
			train = 0;
		end;
		if &no_time_per=0 then train=1;
	RUN;
		
/*====================================================================================================*/
/* Training forecast model HPREG, HPNEURAL */
/*====================================================================================================*/

	PROC SORT data=&outlibn..train_add;
		by &id_var.;
	RUN;QUIT;

	PROC HPREG data=&outlibn..train_add noprint;
		id &id_var.;
		%if not (&no_time_per=0) %then %do; partition rolevar=train(train='1' validate='0'); %end;
		model &y=&input.;
		output out=&outlibn..pred_train_reg predicted=predict_reg;
		code file="hpreg_code.sas";
	RUN;QUIT;

	PROC HPNEURAL data=&outlibn..train_add noprint;
		id &id_var.;
		%if not (&no_time_per=0) %then %do; partition rolevar=train( train=1); %end;
		input &input. / level=int;
		target &y / level=int act=tanh;
		hidden 3;
		train outmodel=&outlibn..model_info_1 maxiter=1000;
		score out=&outlibn..pred_train_neural(drop=_WARN_ rename=(P_&y = predict_neural));
		code file="hpneural_code.sas";
	RUN;QUIT;

	DATA &outlibn..pred_train_reg_neural;
		merge &outlibn..pred_train_reg &outlibn..pred_train_neural &outlibn..train_add;
		by &id_var.;
	RUN;

/*====================================================================================================*/
/* Ensemble final */
/*====================================================================================================*/

	PROC HPNEURAL data=&outlibn..pred_train_reg_neural noprint;
		id &id_var.;
		%if not (&no_time_per=0) %then %do; partition rolevar=train( train=1); %end;
		input predict_reg predict_neural / level=int;
		target &y / level=int act=tanh;
		hidden 3;
		train outmodel=&outlibn..model_info_2 maxiter=1000;
		score out=&outlibn..pred_train_final(drop=_WARN_ rename=(P_&y = predict_final));
		code file="hpneural_code_opt.sas";
	RUN;QUIT;

	DATA &outlibn..pred_train_final_all(drop=train);
		merge &outlibn..pred_train_reg_neural &outlibn..pred_train_final;
		by &id_var.;
	RUN;

/*====================================================================================================*/
/* Score regression and neural network forecast data set */
/*====================================================================================================*/

	DATA &outlibn..scored_predict_reg(drop=&y);
		set /* &libn..&dsn_score.*/ &dsn_score.;
		%include "hpreg_code.sas";
		if (P_&y<0) then P_&y=0;
		rename P_&y = predict_reg;
	RUN;


	DATA &outlibn..scored_predict_neural(drop=_WARN_ &y);
		set /* &libn..&dsn_score.*/ &dsn_score.;
		%include "hpneural_code.sas";
		if (P_&y<0) then P_&y=0;
		rename P_&y = predict_neural;
	RUN;

	DATA &outlibn..scored_predict_final;
		merge &outlibn..scored_predict_reg &outlibn..scored_predict_neural;
		by &id_var.;
	RUN; 

/*====================================================================================================*/
/* Score final neural network */
/*====================================================================================================*/

	DATA &outlibn..scored_predict_final_all(drop=_WARN_);
		set &outlibn..scored_predict_final;
		%include "hpneural_code_opt.sas";
		if (P_&y<0 or P_&y=.) then P_&y=0;
		rename P_&y=predict_final;
	RUN;

/*==================================================================================*/
/* Final forecast data set */
/*==================================================================================*/

	DATA /*&libn..&outdsn*/ &outdsn;
		set &outlibn..pred_train_final_all &outlibn..scored_predict_final_all;
		by &id_var.;
	RUN;

/*		diff_n=abs(actual-predict_neural);
		diff_r=abs(actual-predict_reg);
		diff_f=abs(actual-predict_final);
		diff_1=abs(actual-predict1);
		diff_2=abs(actual-predict2);

/*==================================================================================*/
/*   delete intermediate files */
/*==================================================================================*/

	PROC DATASETS library=&outlibn memtype=data nolist;
		delete  train_add
				pred_train_reg
				pred_train_neural
				model_info_1
				pred_train_reg_neural
				model_info_2
				pred_train_final
				pred_train_final_all
				scored_predict_reg
				scored_predict_neural
				scored_predict_final	
				scored_predict_final_all
	RUN;QUIT; 

	PROC DATASETS library=work memtype=data nolist;
		delete _namedat
	RUN;QUIT;


%MEND forecast_ensemble;


