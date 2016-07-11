/********************************************************************************************************
*
*	PROGRAM: 	Split data in Test and Train using a random sample
**
*	PROJECT: BAC
*
*	MACRO PARAMETERS:
*	----Name-------------------Description-------------------------------------------------------------------
*	dsn					data set name of input file from PROC TIMESERIES
*	odsn				output dataset name	containing final forecast
*	fvar				forecast variable to place forecast into
*	byvar				by variable used aggregate the dependent variable currently only supports single by variable;
*	y 					response variable
* 	datevar				date variable
*	attribs				whitespace seperated list of attributes to use in the regression
*	forecast_horizon	number of periods to forecast, should match forecasting horizon for ongoing products
*	new_product_periods	how many periods to consider a new product as new
* 	intro_dt			column that contains the product introduction date
*	interval			forecasting interval (e.g. week, month, R445mon, etc.)
*	curr_date			current date
*	==================================================================================================================
*  	AUTHOR:	Christian Haxholdt, Ph.D. (christian.haxholdt@sas.com), SAS Professional Services & Delivery, Cary, NC, USA
*			Caleb Weaver (caleb.weaver@sas.com), SAS Professional Services & Delivery, Cary, NC, USA
*
*	CREATED:	May, 2016	 
********************************************************************************************************************/

libname ss 'C:\Users\chhaxh\Documents\Clients\BOA\DATA\SS';
libname ss_out 'C:\Users\chhaxh\Documents\Clients\BOA\DATA\SS_OUT';

%MACRO simple_ts_forecast_wrapper(	libn=, 
									outlibn=,	
									cts_dsn=,
									out_train=,
									out_score=,
									byvar=,
									id_var=,
									date_var=,
									time_int=,
									score_start_date=,
									no_time_per=,
									y=,
									predict=,
									input=
									);

%include 'C:\Users\chhaxh\Documents\SAS_CODE_DATA\Time_Series_Forecasting_Engine\create_train_score_data.sas';
%include 'C:\Users\chhaxh\Documents\SAS_CODE_DATA\Time_Series_Forecasting_Engine\forecast_ensemble.sas';
/*=======================================================================================================*/
/* Create train and scare data set */
/*=======================================================================================================*/

%create_train_score_data(	libn=&libn, 
							outlibn=&outlibn,
							dsn=&cts_dsn,
							out_train=&out_train,
							out_score=&out_score,
							byvar=&byvar,
							predict=&predict,
							date_var=&date_var,
							score_start_date=&score_start_date
							);

/*=======================================================================================================*/
/* Determine input paramter for ensamble modeling */
/*=======================================================================================================*/

	PROC SQL noprint;
		select name into :input separated by ' '
		from dictionary.columns
		where memname=upcase("&out_train")
		and name like "PREDICT%";
	QUIT;

/*=======================================================================================================*/
/* Create train and scare data set */
/*=======================================================================================================*/

%forecast_ensemble(	libn=&libn, 
					outlibn=&outlibn,
					dsn_train=&out_train,
					dsn_score=&out_score,
					id_var=&id_var,
					y=&y,
					input=&input,
					date_var=&date_var,
					time_int=&time_int,
					hist_end_date=&score_start_date,
					no_time_per=&no_time_per
					);

/*==================================================================================*/
/*   delete intermediate files */
/*==================================================================================*/

	PROC DATASETS library=&libn memtype=data nolist;
		delete  &out_train.
				&out_score.	
	RUN;QUIT; 


%MEND simple_ts_forecast_wrapper;

%simple_ts_forecast_wrapper(	libn=ss, 
								outlibn=ss_out,	
								cts_dsn=recfor outfor,
								out_train=train,
								out_score=score,
								byvar=regionName productLine productName,
								id_var=regionName productLine productName date,
								time_int=month,
								date_var=date,
								score_start_date='01jan2003'd,
								no_time_per=0,
								y=actual,
								predict=predict,
								input=predict1 predict2
								);