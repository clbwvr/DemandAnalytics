/*
*	PARAMETERS:
*	dsn 			-	Input data. Contains columns for dim, by_vars, and time_id
*	adjustment_dsn	-	Adjustment data. Contains columns named OLD_ID, NEW_ID, ADJUSTMENT, BEGIN and END
*	dim				-	Dimension of id's being mapped
*	by_vars			-	By variables of id's being mapped
*	time_id			-	Column name of time dimension in dsn
*	actuals			-	Column names of actuals
*	outdsn			-	Output dataset
*/
%macro nonincremental_plm(
	dsn,
	adjustment_dsn,
	dim,
	by_vars,
	time_id,
	actuals,
	outdsn
);

	%include "C:\Users\calwea\Dropbox\DDPO\Code\plm\code\incremental_plm.sas";
	%incremental_plm(
		dsn=&dsn,
		adjustment_dsn=&adjustment_dsn,
		dim=&dim,
		by_vars=&by_vars,
		time_id=&time_id,
		actuals=&actuals,
		outdsn=temp
	)

	data _null_;
		x = tranwrd("&actuals"," ", ",");
		call symputx("actualsc", x);
	run;
	proc sql noprint;	
	 	select name
		into : chars 
		separated by ' '
	 	from dictionary.columns
	  	where upcase(memname) = 'TEMP'
		and type = 'char'
		and name not in ("&actualsc","&time_id","artificial_hist_flg");
	quit;

	proc sql noprint;	
	 	select name
		into : nums 
		separated by ' '
	 	from dictionary.columns
	  	where upcase(memname) = 'TEMP'
			and type = 'num'
			and name not in ("&actualsc","&time_id","artificial_hist_flg");
	quit;

	data ah;	
		length
		%if (%SYMEXIST(nums)) %then %do;
			%let i=1;
			%let num=%scan(&nums,1);
			%do %until(&num eq %nrstr( ));
			 	&num 8
				%let i=%eval(&i+1);
				%let num=%scan(&nums,&i.);
			%end;
		%end;
		%let i=1;
		%let char=%scan(&chars,&i.);
		%do %until(&char eq %nrstr( ));
		 	&char $32
			%let i=%eval(&i+1);
			%let char=%scan(&chars,&i.);
		%end;
		;
		set temp;

		if artificial_hist_flg = "Y" then do;
			%let i=1;
			%let var=%scan(&actuals,&i.);
			%do %until(&var eq %nrstr( ));
				&var = -&var;
				%let i=%eval(&i+1);
				%let var=%scan(&actuals,&i.);
			%end;
			%if (%SYMEXIST(nums)) %then %do;
				%let i=1;
				%let num=%scan(&nums,&i.);
				%do %until(&num eq %nrstr( ));
				 	&num = .;
				 	%let i=%eval(&i+1);
					%let num=%scan(&nums,&i.);
				%end;
			%end;
			%let i=1;
			%let char=%scan(&chars,&i.);
			%do %until(&char eq %nrstr( ));
			 	&char = "PLM";
			 	%let i=%eval(&i+1);
				%let char=%scan(&chars,&i.);
			%end;
			output;
		end;
	run;

	proc sort data=ah; by &time_id &chars %if %SYMEXIST(nums) %then %do; &nums; %end; ; run;
	proc means data=ah noprint;
		var &actuals;
		by &time_id &chars artificial_hist_flg;
			%if %SYMEXIST(nums) %then %do; &nums; %end;
		;
		output out=ahsum(drop=_FREQ_ _TYPE_) sum=&actuals;
	run;

	data &outdsn;
		set temp ahsum;
	run;

	proc sort data=&outdsn;
		by &time_id;
	run;

%mend;