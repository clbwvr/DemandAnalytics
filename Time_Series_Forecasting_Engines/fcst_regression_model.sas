/*********************************************************************************************************************
*
*	PROGRAM: This is a mockup of a process to combine successive forecast files, average
* 			corresponding forecast results, and output the results to a single data set
*
*
*	MACRO PARAMETERS:

*	==================================================================================================================
*
*	AUTHORS: 		Christian Haxholdt, PhD. (christian.haxholdt@sas.com)
*							Caleb Weaver (caleb.weaver@sas.com)
*
*	CREATED:
*
********************************************************************************************************************/


%include "C:\Users\chhaxh\Documents\SAS_CODE_DATA\Variable_Selection\var_ts_corr_wrapper.sas";
%include "C:\Users\chhaxh\Documents\SAS_CODE_DATA\Time_Series_Forecasting_Engines\model_step.sas";
%include "C:\Users\chhaxh\Documents\SAS_CODE_DATA\Time_Series_Forecasting_Engines\recon.sas";
%include "C:\Users\chhaxh\Documents\SAS_CODE_DATA\Time_Series_Forecasting_Engines\forecast_ensemble.sas";

/*libname ss "C:\Users\chhaxh\Documents\Clients\GoodYear\data\SS\";*/
/*libname ss_out "C:\Users\chhaxh\Documents\Clients\GoodYear\data\SS_out\";*/

%macro fcst_regression_model(libn=,
							outlibn=,
							dsn=,
							outdsn_accum_ts_data=,
							outdsn_corr=,
							outdsn_select=,
							outdsn_fcst_x=,
							outdsn_model=,
							outdsn_fcst=,
							outdsn_final_fcst=,
							by_var=,
							by_var_leaf=,
							total_input=,
							ave_input=,
							y=,
							predict_var_name=,
							time_var=,
							time_int=,
							end_date=,
							score_start_date=,
							stat=,
							pw=,
							threshold=,
							maxvar=,
							quantile=,
							no_time_per=
							);


/*==================================================================================================================================*/
/* Variable selection level									*/
/*==================================================================================================================================*/
%let by_var_hier=&by_var &by_var_leaf;

%let k=1;
%do %while (%scan(&by_var, &k) ne );
	%let this_var = %scan(&by_var, &k);

	%var_ts_corr_wrapper(	libn=&outlibn.,
							outlibn=&outlibn.,
							dsn=&dsn.,
							outdsn_accum_data=&outdsn_accum_ts_data.&k.,
							outdsn_corr=&outdsn_corr.&k.,
							outdsn_select=&outdsn_select.&k.,
							outdsn_fcst_x=&outdsn_fcst_x.&k.,
							by_var=&this_var.,
							total_input=&total_input.,
							ave_input=&ave_input.,
							y=&y.,
							time_var=&time_var.,
							time_int=&time_int.,
							end_date=&end_date.,
							run_association=1,
							stat=&stat.,
							pw=&pw.,
							threshold=&threshold.,
							maxvar=&maxvar.,
							quantile=&quantile.
							);

   %let k = %eval(&k + 1);
%end;


	%var_ts_corr_wrapper(	libn=&outlibn.,
				            outlibn=&outlibn.,
				            dsn=&dsn.,
				            outdsn_accum_data=&outdsn_accum_ts_data.leaf,
				            outdsn_corr=&outdsn_corr.leaf,
				            outdsn_select=&outdsn_select.leaf,
				            outdsn_fcst_x=&outdsn_fcst_x.leaf,
				            by_var=&by_var_hier,
							total_input=&total_input.,
							ave_input=&ave_input.,
							y=&y.,
							time_var=&time_var.,
							time_int=&time_int.,
							end_date=&end_date.,
							run_association=1,
							stat=&stat.,
							pw=&pw.,
							threshold=&threshold.,
							maxvar=&maxvar.,
							quantile=&quantile.
				          );



/*==================================================================================================================================*/
/* Modeling Step */
/*==================================================================================================================================*/

%let k=1;
  %do %while (%scan(&by_var, &k) ne );
    %let this_var = %scan(&by_var, &k);

	%model_step(libn=&outlibn.,
   				outlibn=&outlibn.,
   				dsn_var_sel=&outlibn..&outdsn_select.&k.,
   				dsn_ts_train=&outlibn..&outdsn_accum_ts_data.&k.,
   				dsn_ts_score=&outlibn..&outdsn_fcst_x.&k.,
   				outdsn=&outdsn_model.&k.,
				by_var=&this_var,
   				ycol=y,
   				xcol=x,
   				y=&y,
				predict_var_name=&predict_var_name,
   				time_var=&time_var
   				);

     %let k = %eval(&k + 1);
  %end;

  %model_step(libn=&outlibn.,
		      outlibn=&outlibn.,
		      dsn_var_sel=&outlibn..&outdsn_select.leaf,
		      dsn_ts_train=&outlibn..&outdsn_accum_ts_data.leaf,
		      dsn_ts_score=&outlibn..&outdsn_fcst_x.leaf,
		      outdsn=&outdsn_model.leaf,
			  by_var=&by_var_hier,
		      ycol=y,
		      xcol=x,
		      y=&y,
			  predict_var_name=&predict_var_name,
		      time_var=&time_var
		      );

/*==================================================================================================================================*/
/* Delete intermediate files */
/*==================================================================================================================================*/

	PROC DATASETS library=&outlibn. memtype=data nolist;
		delete	&outdsn_corr:	
				&outdsn_select:
				&outdsn_accum_ts_data:
				&outdsn_fcst_x:
				;
	RUN;QUIT;

/*==================================================================================================================================*/
/* Reconciliation */
/*==================================================================================================================================*/

%let k=1;
%do %while (%scan(&by_var, &k) ne );
   %let this_var = %scan(&by_var, &k);

   %recon(	libn=&outlibn.,
		    outlibn=&outlibn.,
 			dsn_disagg=&outlibn..&outdsn_model.leaf,
 			dsn_agg=&outlibn..&outdsn_model.&k.,
 			outdsn_fcst=&outdsn_fcst.&k.,
 			y=&y.,
 			prediction=&predict_var_name.,
 			by_var_leaf=&by_var_leaf.,
 			time_var=&time_var.,
 			time_int=&time_int.
 			);

   %let k = %eval(&k + 1);

%end;


/*==================================================================================================================================*/
/* Ensemble */
/*==================================================================================================================================*/

	%forecast_ensemble(	libn=&libn.,
						outlibn=&outlibn.,
						dsn=&outlibn..leaf_recon_1 &outlibn..leaf_recon_2 &outlibn..leaf_recon_3 &outlibn..leaf_recon_4 &outlibn..final_leaf,
						outdsn=&outdsn_final_fcst., 
						by_var=&by_var_leaf.,
						y=&y.,
						predict=&predict_var_name.,
						input=predict1 predict2 predict3 predict4 predict5,
						time_var=&time_var.,
						time_int=&time_int.,
						score_start_date=&score_start_date.,
						no_time_per=&no_time_per.
						);

/*==================================================================================================================================*/
/* Delete intermediate files */
/*==================================================================================================================================*/
/**/
/*	PROC DATASETS library=&outlibn memtype=data nolist;*/
/*		delete	t1*/
/*				;*/
/*	RUN;QUIT;*/

%MEND fcst_regression_model;

%fcst_regression_model(	libn=ss,
						outlibn=ss_out,
						dsn=ss.gy_ts,
						outdsn_accum_ts_data=ts_,
						outdsn_corr=corr_,
						outdsn_select=var_,
						outdsn_fcst_x=forecast_x_,
						outdsn_model=final_,
						outdsn_fcst=leaf_recon_,
						outdsn_final_fcst=final_forecast,
						by_var=region pbu category product_line,
						by_var_leaf=material,
						total_input=TOTBUSSMSA Disp_Inc_STLFed VMT_STLFed,
						ave_input=CFNAI ISRatio_STLFed Gas_Price_STLFed Comm_SAAR__M__Wards LV_SAAR__M__Wards,
						y=shipments,
						predict_var_name=prediction,
						time_var=start_dt,
						time_int=month,
						end_date='01FEB2015'd,
						score_start_date='01MAR2015'd,
						stat=RSQ,
						pw=1,
						threshold=0.1,
						maxvar=4,
						quantile=,
						no_time_per=0
						);

						/*	x=CUSR0000SETB01  FEDFUNDS isratio NAPMPI RECPROUSM156N T10Y2YM
							houst ir TOTBUSSMSA TRFVOLUSM227NFWA  TRUCKD11 TSITTL TTLCONS Con_Sent_STLFed
							UMTMVS UNRATE USSLIND   ,*/
