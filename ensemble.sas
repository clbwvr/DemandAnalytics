/********************************************************************************************************
*
*	PROGRAM: 	ensemble: ensemble forecasts by model fit (rmse)
*
*
*	=================================================================================================
*   	AUTHOR:		Caleb Weaver
*		
*	CREATED:	July 2016	 
*********************************************************************************************************/

%macro ensemble(libn=, 
	outlibn=,
	dsn=,
	outdsn=,
	by_var=,
	y=,
	predict_name=,
	time_var=,
	time_int=,
	predict_no_use=
);

/* Merge forecast files */
	%let i = 1;
	%let dsn_iter = %scan(&dsn, &i, ' ');
	%do %while("&dsn_iter" ne "");
		%put &dsn_iter;
		PROC SQL;
		   CREATE TABLE &outlibn.._ts_&i AS 
		   SELECT
		    %let j = 1;
			%let by_var_iter = %scan(&by_var, &j);
		  	%do %while("&by_var_iter" ne "");
			    t1.&by_var_iter,
			    %let j = %eval(&j + 1);
			    %let by_var_iter = %scan(&by_var., &j);
		    %end; 
			t1.&time_var, 
			t1.&y,
			t1.&PREDICT_name as PREDICT&i
		    FROM 
			&dsn_iter t1;
		QUIT;

		PROC SORT data=&outlibn.._ts_&i;
			by &by_var.;
		RUN;QUIT;

		%let i = %eval(&i + 1);
		%let dsn_iter = %scan(&dsn, &i, ' ');
	%end;

	DATA &outlibn..merge_forecast;
		merge 
	    %let k = 1;
		%let dsn_iter = %scan(&dsn, &i);
	  	%do k=1 %to &i - 1;
			&outlibn.._ts_&k 
	    %end;
		; by &by_var.;
	RUN;


	DATA &outlibn..out_train &outlibn..out_score;
		set &outlibn..merge_forecast;
		if (&y = .) then output &outlibn..out_train;
		else output &outlibn..out_score;
	RUN; 

	PROC SORT data=&outlibn..out_train;
		by &by_var. &time_var.;
	RUN;QUIT;
      
	/* RMSE logic */
	DATA &outlibn..accuracy_SE;
		set &outlibn..merge_forecast;
		%do i = 1 %to &predict_no_use;
			SE&i=(&y-predict&i)**2; 
		%end;
	RUN;

	PROC MEANS data=&outlibn..accuracy_SE noprint;
		by &by_var.;
		var 		
		%do i = 1 %to &predict_no_use;
			SE&i
		%end;
		;
		output out=&outlibn..accuracy_MSE 
		%do i = 1 %to &predict_no_use;
			mean(SE&i)=MSE&i
		%end;
		;

	RUN;QUIT; 

	DATA &outlibn..outstat_rmse_weight(drop=_type_ _freq_ MSE:);
		set &outlibn..accuracy_MSE;
		%do i = 1 %to &predict_no_use;
			RMSE&i=sqrt(MSE&i);
			if (RMSE&i<0.0001) then RMSE&i=0.01;
		%end;
		factor_RMSE= 1/RMSE1
		%do i = 2 %to &predict_no_use;
			+ 1/RMSE&i
		%end;
		;
		%do i = 1 %to &predict_no_use;
			weight&i = (1/RMSE&i)/factor_RMSE;
		%end;
	RUN;

	DATA &outlibn..train_predict_final_all(drop=RMSE: weight: factor_rmse);
		merge &outlibn..outstat_rmse_weight &outlibn..out_train;
		by &by_var.;
		predict_final= weight1 * predict1
		%do i = 2 %to &predict_no_use;
			+ weight&i*predict&i
		%end;
		;
	RUN; 

	PROC SORT data=&outlibn..out_score;
		by &by_var. &time_var.;
	RUN;QUIT;


	DATA &outlibn..scored_predict_final_all(drop=RMSE: weight: factor_RMSE);
		merge &outlibn..outstat_rmse_weight &outlibn..out_score;
		by &by_var.;
		predict_final= weight1 * predict1
		%do i = 2 %to &predict_no_use;
			+ weight&i*predict&i
		%end;
		;
	RUN; 

	DATA &libn..&outdsn;
		set &outlibn..train_predict_final_all &outlibn..scored_predict_final_all;
		by &by_var. &time_var.;
	RUN;


%mend;
