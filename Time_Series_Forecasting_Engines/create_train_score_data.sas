/********************************************************************************************************
*
*	PROGRAM: 	Split data in Test and Train using a random sample
*
*	MACRO PARAMETERS:
*	----Name-------------------Description-------------------------------------------------------------------
*	libn 					Input Library
*	outlibn					Output Library
*	dsn						List of input datasets (Contain byvar, date_var, ACTUAL, and PREDICT)
*	out_dsn					Output dataset
*	out_train				Training output dataset
*	out_score				Scoring output dataset
*	byvar					List of by variables
*	date_var				Date variable
*	score_start_date		Score start date
*	==================================================================================================================
*  	AUTHOR:	Christian Haxholdt, Ph.D. (christian.haxholdt@sas.com), SAS Professional Services & Delivery, Cary, NC, USA
*			Caleb Weaver (caleb.weaver@sas.com), SAS Professional Services & Delivery, Cary, NC, USA
*
*	CREATED:	May, 2016	 
********************************************************************************************************************/

%MACRO create_train_score_data(	libn=, 
								outlibn=,
								dsn=,
								out_dsn=,
								out_train=,
								out_score=,
								byvar=,
								predict=,
								date_var=,
								score_start_date=
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
	t1.ACTUAL,
	t1.&PREDICT as PREDICT&i
    FROM 
	&libn..&dsn_iter t1;
QUIT;
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
/* Spilt data into train and score */
/*=======================================================================================================*/

	DATA &libn..&out_train. &libn..&out_score.;
		set &outlibn..merge_forecast;
		if (&date_var. < &score_start_date.) then output &libn..&out_train.;
		else output &libn..&out_score.;
	RUN;
					
/*=======================================================================================================*/
/*   delete intermediate files */
/*=======================================================================================================*/

	PROC DATASETS library=&outlibn. memtype=data nolist;
	   delete %let k = 1;
		%let dsn_iter = %scan(&dsn, &i);
	  	%do k=1 %to &i - 1;
		    ts_&k 
	    %end;
		merge_forecast
	RUN;QUIT;  

%MEND create_train_score_data;