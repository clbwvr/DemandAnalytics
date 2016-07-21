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



 

%macro forecast_single_var();


/*==================================================================================================================================*/
/* Variable selection level									*/
/*==================================================================================================================================*/
*region pbu category product_line material;
%let by_var=region pbu category product_line;
%let by_var_leaf = product_line material;
%let ext=v;


%let k=1;
%do %while (%scan(&by_var, &k) ne );
   %let this_var = %scan(&by_var, &k);

   %var_ts_corr_wrapper(	libn=ss,
               outlibn=ss_out,
               dsn=ss.gy_ts,
               outdsn_accum_data=&ext._ts_&k,
               outdsn_corr=corr_&ext._&k,
               outdsn_select=var_&ext._&k,
               outdsn_forecast_x=forecast_x_&ext._&k,
               byvar=&this_var.,
               total_input=TOTBUSSMSA Disp_Inc_STLFed VMT_STLFed,
               ave_input=CFNAI ISRatio_STLFed Gas_Price_STLFed Comm_SAAR__M__Wards LV_SAAR__M__Wards,
               y=shipments,
               time_var=start_dt,
               time_int=month,
               enddate='01FEB2015'd,
               run_association=1,
               stat=RSQ,
               pw=1,
               threshold=0.1,
               maxvar=4,
               quantile=
             );

   %let k = %eval(&k + 1);
%end;


%var_ts_corr_wrapper(	libn=ss,
            outlibn=ss_out,
            dsn=ss.gy_ts,
            outdsn_accum_data=&ext._ts_leaf,
            outdsn_corr=corr_&ext._leaf,
            outdsn_select=var_&ext._leaf,
            outdsn_forecast_x=forecast_x_&ext._leaf,
            byvar=&by_var_leaf,
            total_input=TOTBUSSMSA Disp_Inc_STLFed VMT_STLFed,
            ave_input=CFNAI ISRatio_STLFed Gas_Price_STLFed Comm_SAAR__M__Wards LV_SAAR__M__Wards,
            y=shipments,
            time_var=start_dt,
            time_int=month,
            enddate='01FEB2015'd,
            run_association=1,
            stat=RSQ,
            pw=1,
            threshold=0.1,
            maxvar=4,
            quantile=
          );



/*==================================================================================================================================*/
/* Modeling Step */
/*==================================================================================================================================*/
/*
  %let k=1;
  %do %while (%scan(&by_var, &k) ne );
     %let this_var = %scan(&by_var, &k);

     %model_step(libn=ss,
   				outlibn=ss_out,
   				dsn_var_sel=ss.var_&ext,
   				dsn_ts_train=ss.&ext._ts,
   				dsn_ts_score=ss.forecast_x_&ext,
   				outdsn=&ext._final_&k,
   				ycol=y,
   				xcol=x,
   				y=shipments,
   				byvar=&this_var,
   				time_var=start_dt
   				);

     %let k = %eval(&k + 1);
  %end;

  %model_step(libn=ss,
       outlibn=ss_out,
       dsn_var_sel=ss.var_&ext,
       dsn_ts_train=ss.&ext._ts,
       dsn_ts_score=ss.forecast_x_&ext,
       outdsn=&ext._final_leaf,
       ycol=y,
       xcol=x,
       y=shipments,
       byvar=&by_var_leaf,
       time_var=start_dt
       );

/*==================================================================================================================================*/
/* Reconciliation */
/*==================================================================================================================================*/
/*
%let k=1;
%do %while (%scan(&by_var, &k) ne );
   %let this_var = %scan(&by_var, &k);

   %recon(	libn=ss,
 			outlibn=ss_out,
 			dsn_disagg=ss.v_final,
 			dsn_agg=ss.d_final,
 			outdsn_forecast=d_v_recon,
 			y=shipments,
 			prediction=prediction,
 			byvar_leaf=material,
 			datevar=start_dt,
 			time_int=month
 			);

   %let k = %eval(&k + 1);
%end;


/*==================================================================================================================================*/
/* Ensemble */
/*==================================================================================================================================*/
/*
	%forecast_ensemble(	libn=ss,
						outlibn=ss_out,
						dsn=a_v_recon b_v_recon c_v_recon d_v_recon v_final,
						outdsn=test_tt,
						byvar=material,
						y=shipments,
						predict=prediction,
						input=predict1 predict2 predict3 predict4 predict5,
						date_var=start_dt,
						time_int=month,
						score_start_date='01MAR2015'd,
						no_time_per=0
						);

/*==================================================================================================================================*/
/* Delete intermediate files */
/*==================================================================================================================================*/
/**/
/*	PROC DATASETS library=&outlibn memtype=data nolist;*/
/*		delete	t1*/
/*				;*/
/*	RUN;QUIT;*/

%MEND;



						/*	x=CUSR0000SETB01  FEDFUNDS isratio NAPMPI RECPROUSM156N T10Y2YM
							houst ir TOTBUSSMSA TRFVOLUSM227NFWA  TRUCKD11 TSITTL TTLCONS Con_Sent_STLFed
							UMTMVS UNRATE USSLIND   ,*/
