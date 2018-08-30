/********************************************************************************************************
*
*	PURPOSE: 	Runs R&D Time Series Classification Macro
*
*	PROJECT: 	
*
*	MACRO PARAMETERS:
*	----Name-------------------Description-------------------------------------------------------------------
*	libn			file output lib
*	outlibn			data output location=WORK
*	SDL_use			use the SDL lib
*	dsn				input format: libname.filename
*	y 				dependent variable
* 	timeint			time interval used in forecasting week or month
* 	datevar			date variable
*	==================================================================================================================
*
*   AUTHOR:	Christian Haxholdt, Ph.D. (christian.haxholdt@sas.com), SAS Professional Services & Delivery, Cary, NC, USA
*
*	CREATED:	January, 2015
*
********************************************************************************************************************/;


%MACRO classification(	libn=,	
						outlibn=work, 
						SDL_use=0, 
						dsn=,
						outdsn_table=class_freq_table,
						outdsn_byvar_class=class_byvar,
						byvar_hier=,
						byvar_high=,
						byvar_low=, 
						timeint=, 
						datevar=, 
						y=
						);


/*====================================================================================================*/
/* Create in put data set */
/*====================================================================================================*/

%if (SDL_use=1) %then %do;
	PROC SQL;
	   CREATE TABLE &outlibn..QUERY_TS AS 
	   SELECT t2.PRODUCT_LVL_NM2, 
	          t2.PRODUCT_LVL_NM3, 
	          t2.PRODUCT_NM, 
	          t1.PRODUCT_ID,  
	          t3.STORE_LOCATION_NM, 
	          t1.STORE_LOCATION_ID, 
	          t4.CUSTOMER_LVL_NM2, 
	          t4.CUSTOMER_NM, 
	          t1.CUSTOMER_ID, 
	          t1.start_dt,  
	          t1.&y, 
	          t5.SOURCE_TYPE, 
	          t5.PRODUCT_GROUP, 
	          t5.PRODUCT_TYPE, 
	          t5.MFG_CD, 
	          t5.ITEM_STATUS_CODE
	      FROM &dsn. t1, SDL.PRODUCT t2, SDL.STORE_LOCATION t3, SDL.CUSTOMER t4, 
	          STG_DDPO.DDPO_STG_PRODUCT t5
	      WHERE (t1.PRODUCT_ID = t2.PRODUCT_ID AND t1.STORE_LOCATION_ID = t3.STORE_LOCATION_ID AND t1.CUSTOMER_ID = 
	           t4.CUSTOMER_ID AND t1.PRODUCT_ID = t5.PRODUCT_ID);
	QUIT;
%end;
%else %do;
	DATA &outlibn..QUERY_TS;
		set &dsn.;
	RUN;
%end;

/*====================================================================================================*/
/* Classification Macro */
/*====================================================================================================*/

%let syscc=0;

	%dc_class_wrapper(	indata_table=&outlibn..QUERY_TS,
						time_id_var=&datevar,
						demand_var=&y,
						input_vars=,
						process_lib=&outlibn,
						use_package=1,
						need_sort=1,
						hier_by_vars=&byvar_hier,
						class_process_by_vars=,
						class_low_by_var=&byvar_low,
						class_high_by_var=&byvar_high,
						class_time_interval=&timeint,
						short_reclass=1,
						horizontal_reclass_measure=Mode,
						classify_deactive=1,
						setmissing=0,
						zero_demand_flg=1,
						zero_demand_threshold=0,
						zero_demand_threshold_pct=,
						gap_period_threshold=3,
						short_series_period=3,
						low_volume_period_interval=Year,
						low_volume_period_max_tot=5,
						low_volume_period_max_occur=0,
						lts_min_demand_cyc_len=12,
						lts_seasontest_siglevel=0.01,
						intermit_measure=Median,
						intermit_threshold=2,
						deactive_threshold=52,
						deactive_buffer_period=2,
						calendar_cyc_period=12,
						out_arrays=0,
						out_class=Default,
						out_stats=All,
						out_profile=1,
						profile_type=Moy,
						class_logic_file=,
						debug=1,
						_input_lvl_result_table=input_lvl_result_table,
						_input_lvl_stats_table=input_lvl_stats_table,
						_class_merge_result_table=class_merge_result_table,
						_class_low_result_table=class_low_result_table,
						_class_high_result_table=class_high_result_table,
						_class_low_stats_table=class_low_stats_table,
						_class_high_stats_table=class_high_stats_table,
						_class_low_array_table=class_low_array_table,
						_class_high_array_table=class_high_array_table,
						_class_low_calib_table=class_low_calib_table,
						_class_high_calib_table=class_high_calib_table,
						_rc=
						);

/*====================================================================================================*/
/* Create a frequency table on classes */
/*====================================================================================================*/

	PROC SORT data=&outlibn..class_high_result_table;
		by DC_BY;
	RUN; QUIT;

	PROC FREQ DATA=&outlibn..class_high_result_table
		ORDER=INTERNAL
		NOPRINT;
		TABLES DC_BY / OUT=&outlibn..freq_tablename_high SCORES=TABLE;
	RUN;

	PROC SORT data=&outlibn..class_low_result_table;
		by DC_BY;
	RUN; QUIT;

	PROC FREQ DATA=&outlibn..class_low_result_table ORDER=INTERNAL NOPRINT;
		TABLES DC_BY / OUT=&libn..&outdsn_table. SCORES=TABLE;
	RUN;

	DATA &libn..&outdsn_byvar_class.;
		set &outlibn..class_low_result_table ;
	RUN;

/*====================================================================================================*/
/*  delete intermediate files  */
/*====================================================================================================*/	

	PROC DATASETS library=&outlibn. memtype=data nolist;
		delete	QUERY_TS
				_C:
				_G:
				_H:
				_P:
				_V:
				_T:
				class_merge_result_table
				class_low_result_table 
				class_high_result_table
				class_low_stats_table 
				class_low_array_table
				class_high_stats_table
				class_high_array_table
				class_low_calib_table
				class_high_calib_table
				input_lvl_result_table 
				input_lvl_stats_table
				T:
				freq_tablename_high
				;
	RUN;QUIT;

%MEND classification;
/*
%classification(libn=dm,	
				dsn=dm.return_TS, 
				timeint=week,
				byvar_hier=prod_id_lvl8 loc_id_lvl8, 
				byvar_high=prod_id_lvl8,
				byvar_low=loc_id_lvl8,  
				datevar=wk_start_dt, 
				y=return_QTY
				);*/

