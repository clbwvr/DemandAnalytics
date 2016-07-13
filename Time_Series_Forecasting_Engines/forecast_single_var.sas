/*********************************************************************************************************************
*
*	PROGRAM: This is a mockup of a process to combine successive forecast files, average 
* 			corresponding forecast results, and output the results to a single data set
*
*	PROJECT: Tractor Supply Company
*
*	MACRO PARAMETERS:
*	----Name------  -------------Description--------------------------------------------------------------------------
*	libn			name of SAS library where input data set resides
*	outlibn			name of SAS library where output data sets reside
*	dsn				data set name of input file from PROC TIMESERIES
*	----Name-------------------Set within the MACRO-------------------------------------------------------------------
*	---GLOBAL---
*	startdate		time series start date 
*	==================================================================================================================
*
*   AUTHOR:		
*
*	CREATED:  	
* 
********************************************************************************************************************/


%include "C:\Users\chhaxh\Documents\SAS_CODE_DATA\sas_dp_analytics\Variable Selection\var_ts_corr_wrapper.sas";
%include "C:\Users\chhaxh\Documents\SAS_CODE_DATA\sas_dp_analytics\Time_Series_Forecasting_Engines\model_step.sas";
%include "C:\Users\chhaxh\Documents\SAS_CODE_DATA\sas_dp_analytics\Time_Series_Forecasting_Engines\recon.sas";

libname ss "C:\Users\chhaxh\Documents\Clients\GoodYear\data\SS\";
libname ss_out "C:\Users\chhaxh\Documents\Clients\GoodYear\data\SS_out\";


  
 /*  

%macro forecast_single_var(libn=, outlibn=, dslist=,      
               byvar=,
			   startdt=,
               datevar=,
			   mode=I,       
			   forecastvar=,  
			   name_index=
              ); 


/*==================================================================================================================================*/
/* Variable selection level									*/
/*==================================================================================================================================*/
*region pbu category product_line material;
%let by_var=region pbu;
%let ext=b;

/*%var_ts_corr_wrapper(	libn=ss,
						outlibn=ss_out,
						dsn=ss.gy_ts,
						outdsn_accum_data=&ext._ts,
						outdsn_corr=corr_&ext,
						outdsn_select=var_&ext,
						outdsn_forecast_x=forecast_x_&ext,
						byvar=&by_var.,
						x=CFNAI CUSR0000SETB01 Disp_Inc_STLFed FEDFUNDS isratio NAPMPI RECPROUSM156N T10Y2YM
							houst ir TOTBUSSMSA TRFVOLUSM227NFWA VMT_STLFed TRUCKD11 TSITTL TTLCONS Con_Sent_STLFed 
							UMTMVS UNRATE USSLIND LV_SAAR__M__Wards Comm_SAAR__M__Wards ISRatio_STLFed Gas_Price_STLFed,
						y=shipments,
						time_var=start_dt,
						time_int=month,
						enddate='01FEB2015'd,
						run_association=1, 
						stat=RSQ, 
						pw=1,
						threshold=0.05, 
						maxvar=7,
						quantile=	
					);   

/*==================================================================================================================================*/
/* Modeling Step */
/*==================================================================================================================================*/
/*
%model_step(libn=ss,
			outlibn=ss_out,
			dsn_var_sel=ss.var_&ext,
			dsn_ts_train=ss.&ext._ts,
			dsn_ts_score=ss.forecast_x_&ext,
			outdsn=&ext._final,
			ycol=y,
			xcol=x,
			y=shipments,
			byvar=&by_var,
			time_var=start_dt
			);

/*==================================================================================================================================*/
/* Reconciliation */
/*==================================================================================================================================*/

%recon(	libn=ss, 
		outlibn=ss_out, 
		dsn_disagg=ss.v_final, 
		dsn_agg=ss.d_final, 
		outdsn_forecast=d_v_recon,
		y=shipments,
		prediction=prediction, 
		byvar_leaf=region material, 
		datevar=start_dt, 
		time_int=month
		);
	
/*==================================================================================================================================*/
/* Delete intermediate files */ 
/*==================================================================================================================================*/

/*	PROC DATASETS library=&outlibn memtype=data nolist;*/
/*		delete	t1*/
/*				;*/
/*	RUN;QUIT;*/

/*%mend;*/



									