
%MACRO life_cycle_fit(	libn=, 
						outlibn=, 
						dsn=,
						outdsn=,
						y=,
						by_var=,
						time_var=, 
						time_int=, 
						end_date=,
						predict_name=,
						indep_var=,
						expand_ma=9,
						loess_smth=0.6
						);

ods noresults;
/*==================================================================================================================================*/
/* Set end horizon end */
/*==================================================================================================================================*/

	DATA _null_;
		%if (&time_int=month) %then %do; a=intnx("&time_int",&end_date,24); %end;
		%if (&time_int=week) %then %do; a=intnx("&time_int",&end_date,104); %end;
		call symput ("horizon_end",put(a,date9.));
	RUN;

/*==================================================================================================================================*/
/* Sort data set and add index and season */
/*==================================================================================================================================*/

	PROC SORT data=&dsn.  out=&outlibn..dsn_sort;
		by &by_var. &time_var.;
	RUN;QUIT; 


	PROC TIMEDATA data=&outlibn..dsn_sort out=_null_ outarray=&outlibn..timedata(drop=_season_);
      by &by_var.;
      id &time_var. interval=&time_int. ACCUMULATE=total end="&horizon_end"d;;
      var &y. / acc=total setmissing=0 ;
   	RUN;QUIT;


/*==================================================================================================================================*/
/* EXPAND, LOESS, TPSPLINE, HPFENGINE */	
/*==================================================================================================================================*/

* EXPAND;
*------------------------------------------------------------------------------------------------------;
/*	PROC EXPAND data=&outlibn..timedata out=&outlibn..expand_result(drop=_SERIES_ _STATUS_);*/
/*		by &by_var;*/
/*		id &time_var;*/
/*		convert &y.=predict_ma /  transformout=( cmovave &expand_ma. );*/
/*	RUN;QUIT;*/
/**/
/*	DATA &outlibn..expand_result;*/
/*		set &outlibn..expand_result;*/
/*		if (predict_ma<0) then predict_ma=0;*/
/*	RUN;*/

* LOESS;
*------------------------------------------------------------------------------------------------------;
	PROC LOESS data=&outlibn..timedata;
		by &by_var.;
		model &y.=_cycle_ / smooth=&loess_smth. direct;
		output out=&outlibn..Loess_result predicted=Predict_loess;
	RUN;QUIT;

	DATA &outlibn..Loess_result(drop=SmoothingParameter DepVar obs);
		set &outlibn..Loess_result;
		if (Predict_loess<0) then Predict_loess=0;
	RUN;

* TPSPLINE;
*------------------------------------------------------------------------------------------------------;
/*	PROC TPSPLINE data=&outlibn..Loess_result;*/
/*		by &by_var.;*/
/*		model &y. =(_CYCLE_);*/
/*		output out=&outlibn..tpspline_result(rename=(p_&y.=predict_tpspline));*/
/*	RUN;QUIT;*/
/**/
/*	DATA &outlibn..tpspline_result;*/
/*		set &outlibn..tpspline_result;*/
/*		if (predict_tpspline<0) then predict_tpspline=0;*/
/*	RUN;*/

* HPFENGINE;
*------------------------------------------------------------------------------------------------------;
	%let HPF_SETMISSING=0;
	%let HPF_ZEROMISS=NONE;
	%let HPF_TRIMMISS=NONE;
	%let HPF_BACK=0;

/*	%let HPF_HORIZON_START="&horstart"d;*/

	%let HPF_HORIZON_START_ENABLED=0;
	%let HPF_SELECT_MINOBS_TREND=2;
	%let HPF_SELECT_MINOBS_SEASONAL=2;
	%let HPF_SELECT_MINOBS_NON_MEAN=2;
	%let HPF_DIAGNOSE_INTERMITTENT=2.0;
	%let HPF_SELECT_CRITERION=MAPE;
	%let HPF_COMPONENTS=INTEGRATE;
	%let HPF_FORECAST_ALPHA=0.05;

	PROC HPFENGINE data=&outlibn..Loess_result out=_null_
		outfor=&outlibn..esm_prediction
		/* inest=_HPF2.est  modelrepository= _HPF2.LevModRep*/
		task = select( alpha=&HPF_FORECAST_ALPHA criterion=&HPF_SELECT_CRITERION minobs=&HPF_SELECT_MINOBS_NON_MEAN  minobs=(season=&HPF_SELECT_MINOBS_SEASONAL) minobs=(trend=&HPF_SELECT_MINOBS_TREND)
		seasontest=none intermittent=&HPF_DIAGNOSE_INTERMITTENT override)
		back=&HPF_BACK 
		components=&HPF_COMPONENTS 
		lead=0
		seasonality=12 errorcontrol=(severity=HIGH, stage=(PROCEDURELEVEL))
		EXCEPTIONS=CATCH;
		by &by_var;
		id &time_var. interval=&time_int. acc=total notsorted /*horizonstart=&HPF_HORIZON_START*/;
		forecast &y  /  setmissing=&HPF_SETMISSING trimmiss=&HPF_TRIMMISS zeromiss=&HPF_ZEROMISS;
		%if not (&indep_var.=) %then %do;	
			stochastic &indep_var. /  required=YES setmissing=MISSING trimmiss=RIGHT zeromiss=NONE REPLACEMISSING ;
		%end;
	RUN;QUIT;

	DATA &outlibn..esm_prediction(drop= lower--std _name_ rename=(ACTUAL=&y));
		set &outlibn..esm_prediction;
		if predict ne . and predict < 0 then predict=0;
		rename predict=predict_esm;
	RUN;

/*==================================================================================================================================*/
/* Merge forecsats */	
/*==================================================================================================================================*/

	DATA &outlibn..&outdsn(drop=&time_var.);
		merge &outlibn..esm_prediction &outlibn..Loess_result;
		&predict_name. = mean(predict_loess,predict_esm);
	RUN;

/*==================================================================================*/
/*  END Add Loess probabilities */
/*==================================================================================*/

	PROC DATASETS library=&outlibn memtype=data nolist;
		delete	dsn_sort
				timedata
/*				expand_result*/
				Loess_result
/*				tpspline_result*/
				esm_prediction
				;
	RUN;QUIT;

%MEND life_cycle_fit;
