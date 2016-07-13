/*
*	PARAMETERS:
*	dsn 			-	Input data. Contains columns for dim, by_vars, and time_id
*	adjustment_dsn	-	Adjustment data. Contains columns named from_id, to_id, adjustment, begin_dt and end_dt
*	dim				-	Dimension of id's being mapped
*	by_vars			-	By variables of id's being mapped
*	time_id			-	Column name of time dimension in dsn
*	actuals			-	Column names of actuals
*	outdsn			-	Output dataset
*/
%macro incremental_plm(
	dsn,
	adjustment_dsn,
	dim,
	by_vars,
	time_id,
	actuals,
	outdsn
);

	/* Check Parameters */
	%if not %sysfunc(exist(&dsn)) %then %do;
		%put &dsn does not exist;%return;
	%end;
	%let dsid = %sysfunc(open(&dsn));
	%if not %sysfunc(exist(&adjustment_dsn)) %then %do;
		%put &adjustment_dsn does not exist;%return;
	%end;
	%let adjdsid = %sysfunc(open(&adjustment_dsn));
	%if %sysfunc(varnum(&adjdsid,to_id))=0 %then %do;
		%put Column to_id must exist on &adjustment_dsn;%return;
	%end;
	%if %sysfunc(varnum(&adjdsid,from_id))=0 %then %do;
		%put Column from_id must exist on &adjustment_dsn;%return;
	%end;
	%if %sysfunc(varnum(&adjdsid,adjustment))=0 %then %do;
		%put Column ADJUSTMENT must exist on &adjustment_dsn;%return;
	%end;
	%let j=1;
	%let var=%scan(&by_vars,&j.);
	%do %until(&var eq %nrstr( ));
	 	%if %sysfunc(varnum(&dsid,&var))=0 %then %do;
	 		%put WARNING: Column &var does not exist on &dsn;
			%return;
	 	%end;
	 	%let j=%eval(&j+1);
		%let var=%scan(&by_vars,&j.);
	%end;
	%if %sysfunc(varnum(&dsid,&dim))=0 %then %do;
		%put Column &dim does not exist on &dsn;
		%return;
	%end;
	%if %sysfunc(varnum(&dsid,&time_id))=0 %then %do;
		%put Column &time_id does not exist on &dsn;
		%return;
	%end;
	%let rc=%sysfunc(close(&dsid));
	%let rc=%sysfunc(close(&adjdsid));

	/* Prep Macro Variables */
	data _null_;
		x = tranwrd("&by_vars","&dim", "");
		call symputx("by_vars", x);
	run;
	data _null_;
		x = tranwrd("&by_vars"," ", ",");
		call symputx("sql_vars", x);
	run;
	data _null_;
		x = tranwrd("&actuals"," ", ",");
		call symputx("sql_actuals", x);
	run;
	proc sql noprint;
		select max(&time_id) into : eoh from &dsn;
	quit;


	/* Data Check for Start Dates */

	/* Modify end dates in the future */
	data &adjustment_dsn;
		set &adjustment_dsn;
		if end_dt > &eoh or end_dt = . then do;
			end_dt = &eoh;
	 	end;
	run;

	proc sort data=&dsn;
		by &dim &by_vars &time_id;
	run;

	proc means data=&dsn noprint;
		var &actuals;
		by &dim &by_vars &time_id;
		output out=sums(drop=_FREQ_ _TYPE_) sum=&actuals;
	run;

	proc sql noprint;
		create table full as
		select t1.*, t2.*
		from sums as t1, &adjustment_dsn as t2
		where t1.&dim = t2.from_id;
	quit;

	data full_a full_l;
		set full;
		if type="A" then output full_a;
		else if type="L" then output full_l;
	run;

	proc sql noprint;
		create table calc_a as
		select
		%let i=1;
		%let var=%scan(&actuals,&i.);
		%do %until(&var eq %nrstr( ));
			sum(adjustment*&var) as &var,
			%let i=%eval(&i+1);
			%let var=%scan(&actuals,&i.);
		%end;
		&time_id, to_id, &sql_vars
		from full_a
		where &time_id <= end_dt and &time_id >= begin_dt
		group by &time_id, to_id, &sql_vars;
	quit;

	proc sql noprint;
		create table calc_l as
		select
		%let i=1;
		%let var=%scan(&actuals,&i.);
		%do %until(&var eq %nrstr( ));
			sum(adjustment*&var) as &var,
			%let i=%eval(&i+1);
			%let var=%scan(&actuals,&i.);
		%end;
		&time_id, to_id, &sql_vars
		from full_l
		where &time_id <= end_dt and &time_id >= begin_dt
		group by &time_id, to_id, &sql_vars;
	quit;

	data calc;
		set calc_a calc_l;
	run;

	* remove;
	option varlenchk=nowarn;
	data &outdsn;
		set &dsn calc(in=a rename=(to_id=&dim));
		if a then artificial_hist_flg = 'Y';
		else artificial_hist_flg = 'N';
	run;

	proc sort data=&outdsn;
		by &time_id &dim &by_vars;
	run;

	proc means data=&outdsn noprint;
		var &actuals;
		by &time_id &dim &by_vars artificial_hist_flg;
		output out=&outdsn(drop=_FREQ_ _TYPE_) sum=&actuals;
	run;

%mend;

/********************************************************************/
/* 						Create override dataset 					*/
/*																	*/
/*				  ADDED PARMS  - for Override dataset 				*/
/*	eolvar  														*/
/*	projectpath - get override dataset formats from lowest level 	*/
/*	startdtvar														*/
/********************************************************************/