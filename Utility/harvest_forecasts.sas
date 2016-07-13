/*****************************************************************
*
* Macro: 	harvest_forecast
*
* 			This macro appends the forecast from a Forecast Studio project onto an existing dataset
*			as a new column. 
*		
*			The dataset MUST have the same key as the level of the Forecast Studio project.
*
*			The common usage of this macro would be to append the forecast results back onto the ABT
*			that was used to create the studio project. This allows for simple MTCA workflows.
*
*			E.g. we have an ABT named fs_abt with format of key, date, shipments, pos
*			This ABT is used to create a Studio Project named Consumption. 
*			Call this macro as:
*			%harvest_forecast(	project_dir  	= /sas_home/fs_studio_environment/Consumption/,
								lowest_level 	= Customer,
								out				= fs_abt,
								predict_var		= pos_fcst,
								actual_hist		= 1);
*
*			We can then create a second studio project to forecast shipments using the pos_fcst 
*			variable as an input variable.
*
* Parameters:
*			project_dir - 	The fully qualified CASE SENSITIVE directory path on the compute tier 
*							to the fs_studio project. E.g. /sas_home/fs_studio_environment/Project1/
*			lowest_level-	The CASE SENSISTIVE name of the lowest level (level to harvest) of
							the studio project. E.g. Item
*			out			- 	Existing dataset to append the forecast back onto. This dataset 
							MUST have the same key (by variables & date).
*			predictvar	- 	Name of the new column on &out. to create with the forecast
*			actual_hist	- 	Flag to harvest forecast or actuals historically. 
							0 - Harvest historical forecasts
							1 - Harvest actuals historically
*/

%macro harvest_forecast(project_dir	= /* directory path to the root of the fs_studio project */,
						lowest_level= /* name of the lowest level of the forecast this IS case sensitive */,
						out			= /* Dataset to merge forecasts onto must have same key variables as the forecast */,
						predictvar	= /* Name of the forecast variable to create on the out dataset */,
						actual_hist	= 0 /* 0 - Harvest historical forecast, 1 - historical values of the forecast should be the actuals */);

libname _FSLL_ "&project_dir.hierarchy/&lowest_level.";

proc contents 	data=_FSLL_.finalfor out=work.ff_contents noprint; run;

proc sql noprint; 
	select 	varnum 
	into	:name_col
	from work.ff_contents
	where 	name = "_NAME_";
run; quit;

proc sql noprint;
	select 		name
	into 		:key	SEPARATED by ' '
	from 		work.ff_contents
	where 		(varnum < &name_col.) 
			or (varnum = &name_col+1)
	order by varnum	;
run; quit;

/* merge renaming predict to &cvar and dropping everything else from recfor */
proc sort 	data	= &out. 
			out		= &out. force;
			by 		&key.;
run; quit;

%if %sysfunc(exist(_FSLL_.recfor)) %then %do; /* Use recfor if it exists */
	proc sort 	data	= _FSLL_.recfor(drop=lower upper error std _RECONSTATUS_ _NAME_) 
				out		= work.for force;
				by 		&key.;
	run; quit;
%end; %else %do; /* if it's a bottom up reconcilation, there's no recfor at leaf, use outfor */
	proc sort 	data	= _FSLL_.outfor(drop=lower upper error std _NAME_) 
				out		= work.for force;
				by 		&key.;
	run; quit;
%end; /* End of if recfor or outfor */

/* Grab finalfor for any overrides */
proc sort 	data=_FSLL_.finalfor(drop=lower upper error std _NAME_ _RECONSTATUS_ prebfovr lowbfovr uppbfovr stdbfovr) 
			out=work.finalfor force;
			by &key.;
run; quit;

/* Get the datevariable, is always last variable in key */
%let wordcount = %sysfunc(countw(&key.,' '));
%let datevar = %scan(&key.,&wordcount., ' ');

/* Get's the first date of forecasts in finalfor, assume this is first week of future */
proc sql noprint; 
	select 	min(&datevar.)
	into 	:forecast_start_dt
	from 	_FSLL_.finalfor;
run; quit;

/* Update the &out. with the forecasts or actuals based on &actual_hist */
data &out. (drop=actual predict); 
	merge 	&out. (in=in_fs_ds) work.for(in=in_for) work.finalfor;
	by  	&key.;

	if(in_for) then do;
			if(&actual_hist.) then 	
				if(&datevar < &forecast_start_dt) then 	&predictvar. = actual;
				else									&predictvar. = predict;
			else	&predictvar. = predict; 
	end;
	if in_fs_ds=1;
run; quit; 

/* Clean up */
libname _FSLL_ clear; run;
proc datasets nolist nowarn library=work;
	delete ff_contents for finalfor;
run;

%mend;


/*%harvest_forecast(	project_dir = /home/sasdemo/fs_projs/GY_hTest2/,*/
/*					lowest_level= Material,*/
/*					out 		= fs_data.GY_TO2014,*/
/*					predictvar	= testharvest);	*/