/********************************************************************************************************
*
*	PROGRAM:
*
*	MACRO PARAMETERS:
*	----Name-------------------Description-------------------------------------------------------------------
*	libn				name of SAS library where final output data set resides
*	outlibn				name of SAS library where temp output data sets resides
*	dsn					input dataset - libname.filname
*	stat				statistic for quantifying significance (CORR, RSQ, PVALUE, or T)
*	pw					0 for nonprewhitened variables, 1 for prewhitened variables
*	byvar				by variable level
*	y					response variable
*	value				name of column that contains association stats
*	prewhite_indicator	name of prewhitning indicator column (1=prewhite, 0=default)
*	stat_var_name		name of column that contains association stats
*	threshold			threshold for statistic values
*						- execution must contain values for at least one of threshold, maxvar, quantile
*						- absolute value for T and CORR
*	maxvar				maximum numbers of variables to output
*						- execution must contain values for at least one of threshold, maxvar, quantile
* 	quantile			quantile threshold for values
*						- execution must contain values for at least one of threshold, maxvar, quantile
*	outdsn				output dataset
*	==================================================================================================================
*    AUTHOR:	Christian Haxholdt, Ph.D. (christian.haxholdt@sas.com), SAS Professional Services & Delivery, Cary, NC, USA
*				Caleb Weaver (caleb.weaver@sas.com), SAS Professional Services & Delivery, Cary, NC, USA
*
*	CREATED:	July, 2016
*
********************************************************************************************************************/

%macro choose_vars(	libn=,
					outlibn=,
					dsn=, 
					outdsn=, 
					byvar=,
					y=y,
					value=value,
					prewhite_indicator=pw,
					stat_var_name=stat,
					stat=RSQ,  
					threshold=, 
					maxvar=, 
					quantile=,
					pw=
					);

/*==================================================================================================================================*/
/* Warnings 																                                                     	*/
/*==================================================================================================================================*/

	options minoperator;
	%if %cmpres(&threshold.)= and %cmpres(&maxvar.)= and %cmpres(&quantile.)=  %then %do;
		%put WARNING: threshold, maxvar, and quantile null - quantile set 0.25; 
		%let quantile=0.25;
	%end;
	%if not(%cmpres(&threshold.)=) and not(%cmpres(&quantile.)=)  %then %do;
		%put WARNING: Non-null threshold and quantile values. Quantile will override threshold value.;
	%end;
	%if not(%upcase(&stat.) in CORR RSQ PVALUE T) %then %do;
		%put WARNING: Valid statistics are (CORR, RSQ, PVALUE, and T);%return;
	%end;

/*==================================================================================================================================*/
/* Add rank 																	                                                    */
/*==================================================================================================================================*/

	data &outlibn..t1;
		set &dsn;
		&value._abs = abs(value);
	run;

	PROC SORT data=&outlibn..t1;
		where &stat_var_name.=upcase("&stat") and &prewhite_indicator. = "&pw";
		by
		%if %upcase(&stat) in RSQ CORR T %then %do;
			&y &byvar descending &value._abs;
		%end;
		%else %if %upcase(&stat) in PVALUE %then %do;
			&y &byvar &value;
		%end;
	RUN;QUIT;

	DATA _null_;
		call symputx("lastby", scan("&byvar",-1));
	RUN;

	DATA &outlibn..t1;
		set &outlibn..t1;
		retain rank 0;
		by &y &byvar;
		if first.&lastby then rank=0;
		rank + 1;
		output;
	RUN;

/*==================================================================================================================================*/
/* Add percentiles																                                                    */
/*==================================================================================================================================*/

	%if not(%cmpres(&quantile.)=) %then	%do;
		*Normalize;
		proc means data=&outlibn..t1 sum noprint;
			var &value._abs;
			by &y &byvar;
			output out=&outlibn..sums sum=sum;
		run;
		data &outlibn..t1;
			merge &outlibn..t1(in=a) &outlibn..sums;
			if a;
			by &y &byvar;
		run;
		data &outlibn..t1(drop=sum);
			set &outlibn..t1;
			norm_&y = &value._abs/sum;
		run;

		* Step through distribution;
		proc sort data=&outlibn..t1; 
			by &y &byvar 
			%if %upcase(&stat) in RSQ CORR T %then %do;
				descending 
			%end; 
			norm_&y;
		run;
		data &outlibn..t1(drop=_type_ _freq_);
			set &outlibn..t1;
			retain accum 0;
			by &y &byvar;
			if first.&lastby then accum = 0;
			accum + norm_&y;
			output;
		run;
	%end;

/*==================================================================================================================================*/
/* Select vars																	                                                    */
/*==================================================================================================================================*/
	
	DATA &libn..&outdsn.;
		set &outlibn..t1;
		where
			%let and=;
			%if not(%cmpres(&quantile)= ) %then %do;
				%let and = and;
				accum <
				%if %upcase(&stat) in RSQ CORR T %then %do;
					&quantile
				%end;
				%else %if %upcase(&stat) = PVALUE %then %do;
					&quantile
				%end;
			%end;
			%else %if not(%cmpres(&threshold)= ) %then %do;
				%let and = and;
				%if %upcase(&stat) in RSQ %then %do;
					&value >= &threshold
				%end;
				%if %upcase(&stat) in T CORR %then %do;
					&value._abs >= &threshold
				%end;
				%else %if %upcase(&stat) in PVALUE %then %do;
					&value <= &threshold
				%end;
				
			%end;
			%if not(%cmpres(&maxvar)= ) %then %do;
				&and rank <= &maxvar
			%end;
			;
	RUN;

/*==================================================================================*/
/*   delete intermediate files */
/*==================================================================================*/

	PROC DATASETS library=&outlibn memtype=data nolist;
		delete 	t1 sums
				;
	RUN;QUIT;

%mend;
