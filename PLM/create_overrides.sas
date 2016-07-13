
/********************************************************************/
/* 						Create override dataset 					*/
/*																	*/
/*				  ADDED PARMS  - for Override dataset 				*/
/*	eolvar  														*/
/*	projectpath - get override dataset formats from lowest level 	*/
/*	startdtvar														*/
/********************************************************************/

%macro create_overrides(
	in_dsn,
	startdt_var
	eol_var,
	project_path,
	dsn,
	adjustment_dsn,
	dim,
	by_vars,
	time_var,
	actuals,
	outdsn
);
/* Directly create override table for fs_studio for events */
     /*   BY variables have to be in hierarchy order
               STYLE_GROUP     FCST_SKU_KEY    FCST_CPG_CODE   WEEK_OF_MONTH
           _NAME_ contains the variable name in the forecast   
           DATE used in forecasting
           OVERRIDE value
           OLOCK = 0 for locked override
           LOWER = Lower limit implied by override, set by system
           LLOCK = 0 for locked
           UPPER = Upper limit implied by override, set by system
           ULOCK = 0 for locked
 
     */
 
     libname project "&project_path";

	data _null_;
		x = tranwrd("&by_vars"," ", ",");
		call symputx("sql_vars", x);
	run;

		%let i = 1;
		%let var=%scan(&actuals,&i.);
		%do %until(&var eq %nrstr( ));
		proc sql;
           create table work.&var as
           select &dim, &sql_vars, &time_var,
           			 STYLE_GROUP, FCST_CPG_CODE,
                      STYLE_NUM format $9.,
                      FCST_SKU_KEY format $80.,
                      5 as week_of_month,
                     upcase("&var") as _NAME_ format=$32. length=32,
                     fiscal_mdate,
                     0 as OVERRIDE,
                     0 as OLOCK,
                     . as LOWER,
                     0 as LLOCK,
                     . as UPPER,
                     0 as ULOCK
           from work.&indsn
           * where &eof_var < ____ and &eof_var > ___;
         quit;
			%let i=%eval(&i+1);
			%let var=%scan(&actuals,&i.);
		%end;

		data &project..outovrd;
			set &actuals;
		run;
%mend;

