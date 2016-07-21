/********************************************************************************************************
*
*	PROGRAM:
*
*	MACRO PARAMETERS:
*	----Name-------------------Description-------------------------------------------------------------------
*	libn				name of SAS library where final output data set resides
*	outlibn				name of SAS library where temp output data sets resides
*	dsn					input dataset - libname.filname
*	outdsn_accum_ts		name of output accumulted time series
*	outdsn_corr			correlation stat file name
*	outdsn_select		variable selection file name
*	byvar				by variable level
*	y 					dependent variable
*	x					independent variable list
* 	time_var			date variable
*	time_int			time interval
*	stat				statistic for quantifying significance (CORR, RSQ, PVALUE, or T)
*	pw					0 for nonprewhitened variables, 1 for prewhitened variables
*	threshold			threshold for statistic values (execution must contain values for threshold, maxvar, or both)
*	maxvar				maximum numbers of variables to output (execution must contain values for threshold, maxvar, or both)
*	run_association		run associaiton macro=1, skip=0
*	==================================================================================================================
*   AUTHOR:	Christian Haxholdt, Ph.D. (christian.haxholdt@sas.com), SAS Professional Services & Delivery, Cary, NC, USA
*			Caleb Weaver (caleb.weaver@sas.com), SAS Professional Services & Delivery, Cary, NC, USA
*
*	CREATED:	July, 2016
*
********************************************************************************************************************/

%macro var_ts_corr_wrapper(	libn=,
							outlibn=,
							dsn=,
							outdsn_accum_data=,
							outdsn_corr=,
							outdsn_select=,
							outdsn_forecast_x=,
							byvar=,
							y=,
							total_input=,
							ave_input=,
							time_var=,
							time_int=,
							enddate=,
							run_association=1, 
							stat=RSQ,
							pw=, 
							threshold=, 
							maxvar=,
							quantile=
							);

/*==================================================================================*/
/* Include statements */
/*==================================================================================*/

%include "C:\Users\chhaxh\Documents\SAS_CODE_DATA\sas_dp_analytics\Variable Selection\var_ts_corr.sas";
%include "C:\Users\chhaxh\Documents\SAS_CODE_DATA\sas_dp_analytics\Variable Selection\choose_vars.sas";

/*==================================================================================================================================*/
/* Prepare data																			 											                                                     	*/
/*==================================================================================================================================*/

	PROC sort data=&dsn out=&outlibn..sort_data;
		by &byvar. &time_var.;
	RUN;QUIT;

	PROC TIMESERIES DATA=&outlibn..sort_data OUT=&libn..&outdsn_accum_data;
		by &BYVAR.;
		id &time_var. Interval=&time_int.;
		VAR &y. /	ACCUMULATE=TOTAL;
		%if not (&total_input=) %then %do;
			var &total_input. / ACCUMULATE=TOTAL;
		%end;
		%if not (&ave_input=) %then %do;
			var &ave_input. / ACCUMULATE=AVERAGE;
		%end;
		var time_dummy / accumulate=maximum;
	RUN;QUIT;

%let x=&total_input. &ave_input.; 

/*==================================================================================*/
/* Run assosciation macro or skip */
/*==================================================================================*/

%if (&run_association=1) %then %do;


/*==================================================================================*/
/* Variable stats */
/*==================================================================================*/
	%let i=1;
	%let xi=%scan(&x,&i);
	%do %until(&xi eq %nrstr( ));

		%var_ts_corr(	libn=&outlibn,
						outlibn=&outlibn,
						dsn=&libn..&outdsn_accum_data,
						outforecast=&xi._f,
						outdsn=&xi,
						byvar=&byvar,
						x=&xi,
						y=&y,
						time_var=&time_var,
						time_int=&time_int,
						enddate=&enddate
						);

		PROC SORT data=&outlibn..&xi.;
			by &byvar. stat x;
		RUN;QUIT;

		%let i=%eval(&i+1);
		%let xi=%scan(&x,&i.);
	%end;
	
	*Get longest variable name;
	%let len = 0;
	%let i=1;
	%let xi=%scan(&x,&i);
	%do %until(&xi eq %nrstr( ));
		%if %length(&xi) > &len %then %let len = %length(&xi);
		%let i=%eval(&i+1);
		%let xi=%scan(&x,&i.);
	%end;

	DATA &libn..&outdsn_corr;
		length x $ &len;
		merge 
			%let i=1;
			%let xi=%scan(&x,&i);
			%do %until(&xi eq %nrstr( ));
				&outlibn..&xi
				%let i=%eval(&i+1);
				%let xi=%scan(&x,&i.);
			%end;
		;
		by &byvar. stat x;
	RUN;

	DATA &libn..&outdsn_forecast_x;
		merge 
			%let i=1;
			%let xi=%scan(&x,&i);
			%do %until(&xi eq %nrstr( ));
				&outlibn..&xi._f
				%let i=%eval(&i+1);
				%let xi=%scan(&x,&i.);
			%end;
		;
		by &byvar. &time_var;
	RUN;

	PROC DATASETS library=&libn nolist;
	  modify &outdsn_corr;
	  attrib _all_ label='';
	RUN;QUIT;

/*==================================================================================*/
/* Delete intermediate files */
/*==================================================================================*/

	PROC DATASETS library=&outlibn memtype=data nolist;
		delete 	&x
					%let i=1;
			%let xi=%scan(&x,&i);
			%do %until(&xi eq %nrstr( ));
				&xi._f
				%let i=%eval(&i+1);
				%let xi=%scan(&x,&i.);
			%end;
				;
	RUN;QUIT;

/*==================================================================================*/
/* End assosciation code */
/*==================================================================================*/ 

%end;

/*==================================================================================*/
/* Choose varibles */
/*==================================================================================*/

	%choose_vars(	libn=&libn,
					outlibn=&outlibn,
					dsn=&libn..&outdsn_corr,
					outdsn=&outdsn_select, 
					byvar=&byvar, 
					stat=&stat, 
					threshold=&threshold, 
					maxvar=&maxvar,
					quantile=&quantile, 
					pw=&pw
					);

/*==================================================================================*/
/* Delete intermediate files */
/*==================================================================================*/

	PROC DATASETS library=&outlibn memtype=data nolist;
		delete 	sort_data
				;
	RUN;QUIT;

%MEND var_ts_corr_wrapper;



