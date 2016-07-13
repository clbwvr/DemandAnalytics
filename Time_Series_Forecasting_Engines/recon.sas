/*********************************************************************************************************************
*
*	PROGRAM: Reconcile
*
*	PROJECT: Tractor Supply Company
*
*	MACRO PARAMETERS:
*	----Name------  -------------Description--------------------------------------------------------------------------
*	libn			name of SAS library where input data set resides
*	outlibn			name of SAS library where output data sets reside
*	dsn_disagg		input for file for forecast at disagg level
*	dsn_agg			input for file for forecast at agg level
*	y 				dependent
*	byvar_top		by variables
*	datevar			date variable
*	timeint			time interval 
*	==================================================================================================================
*
*   AUTHOR:	Christian Haxholdt, Ph.D. (christian.haxholdt@sas.com), SAS Professional Services & Delivery
*
*	CREATED:  	July, 2016
* 
********************************************************************************************************************/


/* ==== SAS Reconciliation Macro === */

%MACRO recon(	libn=, 
				outlibn=, 
				dsn_disagg=, 
				dsn_agg=, 
				y=,
				prediction=, 
				byvar_leaf=, 
				datevar=, 
				time_int=
				);

%let HPF_FORECAST_ALPHA=0.05;

/*==================================================================================*/
/* Reconcile forecasts top-down;
/*==================================================================================*/

	PROC SORT data=&dsn_disagg out=&outlibn..sort_leaf;
		by &byvar_leaf &datevar;
	RUN;

	PROC HPFRECONCILE disaggdata=&outlibn..sort_leaf aggdata=&dsn_agg 
		outfor=&outlibn..test(drop=lower upper error std _RECONSTATUS_)
		direction=td
		alpha=&HPF_FORECAST_ALPHA
		sign=NONNEGATIVE 
		disaggregation=proportion aggregate=total;
		aggdata actual=&y predict=&prediction;
		disaggdata actual=&y predict=&prediction;
		id &datevar interval=&time_int;
		by &byvar_leaf;
	RUN;QUIT; 

/*==================================================================================*/
/*   delete intermediate files */
/*==================================================================================*/

	PROC DATASETS library=&outlibn memtype=data nolist;
		delete 
			sort_leaf
				;
	RUN;QUIT;


%MEND;
