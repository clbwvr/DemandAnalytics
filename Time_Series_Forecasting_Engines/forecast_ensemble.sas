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
*	byvar				by variables used in identification by variables
*	y					response variable name
*	predict				name of prediction variable, it is presumeed that all data sets has the same name of the prediction column
*	input				set of prediction variables used in the final ensemble
*	date_var			name of date variable column		
*	time_int			time interval in the input data set			
*	score_start_date	start of the time preiod to be forecasted or scored - format:'31dec2015'd
*	no_time_per			no of time period to be used in modeling
*	========================================================================================================================
*   AUTHOR:	Christian Haxholdt, Ph.D. (christian.haxholdt@sas.com), SAS Professional Services & Delivery, Cary, NC, USA	
*			Caleb Weaver (caleb.weaver@sas.com), SAS Professional Services & Delivery, Cary, NC, USA
*		
*	CREATED:	July, 2016	 
********************************************************************************************************************/

%MACRO forecast_ensemble(	libn=, 
							outlibn=,
							dsn=,
							outdsn=,
							byvar=,
							y=,
							predict=,
							input=,
							date_var=,
							time_int=,
							score_start_date=,
							no_time_per=
							);

/*=======================================================================================================*/
/* Merge forecast files */
/*=======================================================================================================*/

	%let i = 1;
	%let dsn_iter = %scan(&dsn, &i);
	%do %while("&dsn_iter" ne "");
	PROC SQL;
	   CREATE TABLE &outlibn..ts_&i AS 
	   SELECT
	    %let j = 1;
		%let byvar_iter = %scan(&byvar, &j);
	  	%do %while("&byvar_iter" ne "");
		    t1.&byvar_iter,
		    %let j = %eval(&j + 1);
		    %let byvar_iter = %scan(&byvar, &j); 
	    %end; 
		t1.&date_var, 
		t1.&y,
		t1.&PREDICT as PREDICT&i
	    FROM 
		&libn..&dsn_iter t1;
	QUIT;

	PROC SORT data=&outlibn..ts_&i;
		by &byvar.;
	RUN;QUIT;

	%let i = %eval(&i + 1);
	%let dsn_iter = %scan(&dsn, &i);
	%end;

	DATA &outlibn..merge_forecast;
		merge 
	    %let k = 1;
		%let dsn_iter = %scan(&dsn, &i);
	  	%do k=1 %to &i - 1;
			&outlibn..ts_&k 
	    %end;
		; by &byvar.;
	RUN;

/*=======================================================================================================*/
/* Spilt data into train and score for regression and neural network */
/*=======================================================================================================*/

	DATA &outlibn..out_train &outlibn..out_score;
		set &outlibn..merge_forecast;
		if (&date_var. < &score_start_date.) then output &outlibn..out_train;
		else output &outlibn..out_score;
	RUN; 

/*====================================================================================================*/
/* Truncating train data */
/*====================================================================================================*/

	DATA &outlibn..train_add;
		set &outlibn..out_train;	
		if &date_var >= intnx("&time_int", &score_start_date., -&no_time_per) then do;
			train = 1;
		end;
		else do;
			train = 0;
		end;
		if &no_time_per=0 then train=1;
	RUN;
		
/*====================================================================================================*/
/* Training forecast model HPF, HPREG, HPNEURAL */
/*====================================================================================================*/

	PROC SORT data=&outlibn..train_add;
		by &byvar. &date_var.;
	RUN;QUIT;

* HPF score and train;
*------------------------------------------------------------------------------------------------------;

	PROC HPFDIAGNOSE data=&outlibn..merge_forecast
		outest=&outlibn..in_est
		modelrepository=mycat
		prefilter=extreme 
		errorcontrol=(severity=HIGH stage=(PROCEDURELEVEL)) 
		EXCEPTIONS=CATCH
		errorcontrol=(severity=none stage=all);
		by &byvar;
		forecast &y / accumulate=total;
		input &input. / required=YES accumulate=Total setmissing=previous;
		id &date_var interval=&time_int notsorted;
		arimax;
		esm method=best;
	RUN;QUIT;

	PROC HPFENGINE data=&outlibn..merge_forecast
		inest=&outlibn..in_est
		modelrepository=mycat
		out=_NULL_
		outfor=&outlibn..forecast_hpf(keep=&byvar &date_var predict rename=(predict=predict_hpf))
		lead=24
		errorcontrol=(severity=HIGH, stage=(PROCEDURELEVEL))
		EXCEPTIONS=CATCH;
		by &byvar.;
		id &date_var interval=&time_int notsorted;
		forecast &y  / accumulate=total;
		input &input. / required=YES accumulate=Total setmissing=previous;
	RUN;QUIT;

	DATA &outlibn..pred_train_hpf(keep=&byvar. &date_var. predict_hpf) &outlibn..scored_predict_hpf(keep=&byvar. &date_var. predict_hpf);
		set &outlibn..forecast_hpf;
		if (&date_var. < &score_start_date.) then output &outlibn..pred_train_hpf;
		else output &outlibn..scored_predict_hpf;
	RUN; 


* Regression train;
*------------------------------------------------------------------------------------------------------;

	PROC HPREG data=&outlibn..train_add noprint;
		id &byvar. &date_var.;
		by &byvar.;
		%if not (&no_time_per=0) %then %do; partition rolevar=train(train='1' validate='0'); %end;
		model &y=&input.;
		output out=&outlibn..pred_train_reg predicted=predict_reg;
		code file="hpreg_code.sas";
	RUN;QUIT;

* Neural train;
*------------------------------------------------------------------------------------------------------;
*loop needed for by var;
	PROC HPNEURAL data=&outlibn..train_add noprint;
		id &byvar. &date_var.;
		%if not (&no_time_per=0) %then %do; partition rolevar=train( train=1); %end;
		input &input. / level=int;
		target &y / level=int act=tanh;
		hidden 3;
		train outmodel=&outlibn..model_info_1 maxiter=1000;
		score out=&outlibn..pred_train_neural(drop=_WARN_ rename=(P_&y = predict_neural));
		code file="hpneural_code.sas";
	RUN;QUIT;

* Merge;
*------------------------------------------------------------------------------------------------------;

	DATA &outlibn..pred_train_hpf_reg_neural;
		merge &outlibn..pred_train_hpf &outlibn..pred_train_reg &outlibn..pred_train_neural &outlibn..train_add;
		by &byvar. &date_var.;
	RUN;
 
/*====================================================================================================*/
/* Ensemble final train */
/*====================================================================================================*/

	PROC HPNEURAL data=&outlibn..pred_train_hpf_reg_neural noprint;
		id &byvar. &date_var.;
		%if not (&no_time_per=0) %then %do; partition rolevar=train( train=1); %end;
		input predict_hpf predict_reg predict_neural / level=int;
		target &y / level=int act=tanh;
		hidden 3;
		train outmodel=&outlibn..model_info_2 maxiter=1000;
		score out=&outlibn..pred_train_final(drop=_WARN_ rename=(P_&y = predict_final));
		code file="hpneural_code_opt.sas";
	RUN;QUIT;

	DATA &outlibn..pred_train_final_all(drop=train);
		merge &outlibn..pred_train_hpf_reg_neural &outlibn..pred_train_final;
		by &byvar. &date_var.;
	RUN;

/*====================================================================================================*/
/* Score regression and neural network forecast data set */
/*====================================================================================================*/

	PROC SORT data=&outlibn..out_score;
		by &byvar. &date_var.;
	RUN;QUIT;

* Regression score;
*------------------------------------------------------------------------------------------------------;

	DATA &outlibn..scored_predict_reg(drop=&y);
		set &outlibn..out_score;
		%include "hpreg_code.sas";
		if (P_&y<0) then P_&y=0;
		rename P_&y = predict_reg;
	RUN;

* Neural score;
*------------------------------------------------------------------------------------------------------;

	DATA &outlibn..scored_predict_neural(drop=_WARN_ &y);
		set &outlibn..out_score;
		%include "hpneural_code.sas";
		if (P_&y<0) then P_&y=0;
		rename P_&y = predict_neural;
	RUN;

/*====================================================================================================*/
/* Score final neural network */
/*====================================================================================================*/

	DATA &outlibn..scored_predict_final;
		merge &outlibn..scored_predict_hpf &outlibn..scored_predict_reg &outlibn..scored_predict_neural;
		by &byvar. &date_var.;
	RUN; 

	DATA &outlibn..scored_predict_final_all(drop=_WARN_);
		set &outlibn..scored_predict_final;
		%include "hpneural_code_opt.sas";
		if (P_&y<0 or P_&y=.) then P_&y=0;
		rename P_&y=predict_final;
	RUN;

/*==================================================================================*/
/* Final forecast data set */
/*==================================================================================*/

	DATA &libn..&outdsn;
		set &outlibn..pred_train_final_all &outlibn..scored_predict_final_all;
		by &byvar. &date_var.;
		diff_n=abs(&y-predict_neural);
		diff_r=abs(&y-predict_reg);
		diff_h=abs(&y-predict_hpf);
		diff_f=abs(&y-predict_final);
		diff_1=abs(&y-predict1);
		diff_2=abs(&y-predict2);
		diff_3=abs(&y-predict3);
		diff_4=abs(&y-predict4);
		diff_5=abs(&y-predict5);
	RUN;


/*==================================================================================*/
/*   delete intermediate files */
/*==================================================================================*/

	PROC DATASETS library=&outlibn memtype=data nolist;
		delete  %let k = 1;
				%let dsn_iter = %scan(&dsn, &i);
			  	%do k=1 %to &i - 1;
				    ts_&k 
			    %end;
				merge_forecast
				out_train
				out_score
				train_add
				in_est
				forecast_hpf
				pred_train_hpf
				pred_train_reg
				pred_train_neural
				model_info_1
				pred_train_hpf_reg_neural
				model_info_2
				pred_train_final
				pred_train_final_all
				scored_predict_hpf
				scored_predict_reg
				scored_predict_neural
				scored_predict_final	
				scored_predict_final_all
	RUN;QUIT; 

	PROC DATASETS library=work memtype=data nolist;
		delete _namedat
	RUN;QUIT;


%MEND forecast_ensemble;