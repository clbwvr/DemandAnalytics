/********************************************************************************************************
*
*	PROGRAM:
*
*	MACRO PARAMETERS:
*	----Name-------------------Description-------------------------------------------------------------------
*	libn				name of SAS library where final output data set resides
*	outlibn				name of SAS library where temp output data sets resides
*	dsn					input dataset - libname.filname
*	outdsn		name of output file with statistics
*	y 					dependent variable
*	x					independent variable
*	byvar				by variable level
* 	time_var			date variable
*	time_int			time interval
*	==================================================================================================================
*   AUTHOR:	Christian Haxholdt, Ph.D. (christian.haxholdt@sas.com), SAS Professional Services & Delivery, Cary, NC, USA
*			Caleb Weaver (caleb.weaver@sas.com), SAS Professional Services & Delivery, Cary, NC, USA
*
*	CREATED:	July, 2016
*
********************************************************************************************************************/




/* ==== Variable time series correlation Macro === */


%MACRO var_ts_corr(	libn=,
					outlibn=,
					dsn=,
					outforecast=,
					outdsn=,
					byvar=,
					y=,
					x=,
					time_var=,
					time_int=,
					enddate=
				);


/*==================================================================================================================================*/
/* Pre-whitening step 1: Filter X																			 											                                                     	*/
/*==================================================================================================================================*/

	PROC hpfdiagnose data=&dsn. outest=&outlibn..est modelrepository=&outlibn..mycat;
		by &byvar;
		id &time_var interval= &time_int;
		forecast &x;
		arimax;
	RUN;QUIT;

	PROC hpfengine data=&dsn. out=_null_ inest=&outlibn..est outest=&outlibn..f_est modelrepository=&outlibn..mycat outfor=&outlibn..outfor_x
								lead=24;
		id &time_var interval= &time_int;
		by &byvar;
		forecast &x / task=select ;
	RUN;QUIT;

	DATA &outlibn..x_outfor(keep=&byvar error rename=(error=&x._pw)) &libn..&outforecast(keep=&byvar &time_var time_dummy predict rename=(predict=&x));
		set &outlibn..outfor_x;
		if (&time_var le &enddate) then do;
			if (error eq .) then delete;
			output &outlibn..x_outfor;
		end;
		else do;
			time_dummy=&time_int(&time_var);	
			output &libn..&outforecast;
		end;
	RUN;

/*==================================================================================================================================*/
/* Pre-whitening step 2: Filter Y with X filter																			 											                                                     	*/
/*==================================================================================================================================*/

	DATA &outlibn..f_est;
		set &outlibn..f_est;
		_NAME_ = "&y";
	RUN;

	PROC hpfengine data=&dsn. out=_null_ inest=&outlibn..f_est modelrepository=&outlibn..mycat outfor=&outlibn..outfor_y
					lead=0;
		id &time_var interval=&time_int;
		by &byvar;
		forecast &y / task=fit ;
	RUN;QUIT;

	DATA &outlibn..y_outfor(keep=&byvar error rename=(error=&y._pw));
		set &outlibn..outfor_y;
		where error ne .;
	RUN;

/*==================================================================================================================================*/
/* Pre-whitening step 3: Merge X-filter and Y-filter and estimate correlation																	 											                                                     	*/
/*==================================================================================================================================*/

	DATA &outlibn..x_y_filter_data;
		merge &outlibn..x_outfor &outlibn..y_outfor;
	RUN;

	PROC CORR DATA=&outlibn..x_y_filter_data PEARSON OUTP=&outlibn..pre_white_corr NOPRINT;
		by &byvar;
		var &x._pw;
		with &y._pw;
	RUN;QUIT;

	PROC REG DATA=&outlibn..x_y_filter_data noprint OUTEST=&outlibn..pre_white_reg EDF TABLEOUT NOPRINT;
		by &byvar;
		model &y._pw = &x._pw;
	RUN;QUIT;

	DATA &outlibn..pre_white_reg_rsq(keep=&byvar _type_ _name_ &x._pw );
		set &outlibn..pre_white_reg;
		if (_RSQ_=. ) then delete;
		_type_="RSQ";
		&x._pw=_RSQ_;
		_name_="&x._pw";
	RUN;

	DATA &outlibn..pre_white_stat(keep=&byvar _type_ _name_ &x._pw rename=(_type_=stat _name_=y));
		set &outlibn..pre_white_corr &outlibn..pre_white_reg &outlibn..pre_white_reg_rsq;
		if not (_type_="CORR" or _type_="T" or _type_="PVALUE" or _TYPE_="RSQ") then delete;
		_name_="&y._pw";
	RUN;

	PROC SORT data=&outlibn..pre_white_stat;
		by &byvar.;
	RUN;QUIT;

/*==================================================================================================================================*/
/* Correlation on original data y and x																	 											                                                     	*/
/*==================================================================================================================================*/

	PROC CORR DATA=&dsn. PEARSON OUTP=&outlibn..corr NOPRINT;
		by &byvar;
		var &x;
		with &y;
	RUN;QUIT;

	PROC REG DATA=&dsn. noprint OUTEST=&outlibn..reg EDF TABLEOUT noprint;
		by &byvar;
		model &y = &x;
	RUN;QUIT;

	DATA &outlibn..reg_rsq(keep=&byvar _type_ _name_ &x);
		set &outlibn..reg;
		if (_RSQ_=. ) then delete;
		_type_="RSQ";
		&x=_RSQ_;
		_name_="&x";
	RUN;

	DATA &outlibn..stat(keep=&byvar &x _type_ _name_ rename=(_type_=stat _name_=y));
		set &outlibn..corr &outlibn..reg &outlibn..reg_rsq;
		if not (_type_="CORR" or _type_="T" or _type_="PVALUE" or _TYPE_="RSQ") then delete;
		_name_="&y";
	RUN;

	PROC SORT data=&outlibn..stat;
		by &byvar.;
	RUN;QUIT;

/*==================================================================================================================================*/
/* Merge pre-white corrlation with correlation																	 											                                                     	*/
/*==================================================================================================================================*/

	DATA &outlibn..wide;
		merge &outlibn..pre_white_stat &outlibn..stat;
		by &byvar;
	RUN;

	PROC DATASETS library=&outlibn nolist;
	  modify wide;
	  attrib _all_ label='';
	RUN;QUIT;

	PROC SORT data=&outlibn..wide;
		by &byvar stat;
	RUN;QUIT;

	PROC TRANSPOSE data=&outlibn..wide out=&outlibn..long(rename=(_name_=x col1=value));
		by &byvar stat;
		var &x &x._pw;
	RUN;QUIT;

	DATA &libn..&outdsn;
		set &outlibn..long;
		if length(x) > length("_pw") then do;
			if substrn(x,length(x)-length("_pw")+1) = "_pw" then do;
				x = tranwrd(x,"_pw","");
				pw = "1";
			end;
			else do;
				pw = "0";
			end;
		end;
		else do;
			pw = 0;
		end;
		y = "&y";
	RUN;

/*==================================================================================*/
/*   delete intermediate files */
/*==================================================================================*/

	PROC DATASETS library=&outlibn memtype=data nolist;
		delete 	sort_data
				est
				f_est
				outfor_x
				outfor_y
				x_outfor
				y_outfor
				x_y_filter_data
				pre_white_corr
				pre_white_reg
				pre_white_reg_rsq
				corr
				reg
				reg_rsq 
				pre_white_stat
				stat
				wide
				long
				;
	RUN;QUIT;

%MEND var_ts_corr;

/*	%var_ts_corr(	libn=ss,
					outlibn=ss_out,
					dsn=ss.gy_ts,
					byvar=category,
					x=CFNAI,
					y=shipments,
					time_var=start_dt,
					time_int=month,
					outdsn=test
				);*/