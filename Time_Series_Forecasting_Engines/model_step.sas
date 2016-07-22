/*
*	model_step.sas
*
*	AUTHORS: 		Christian Haxholdt, PhD. (christian.haxholdt@sas.com)
*					Caleb Weaver (caleb.weaver@sas.com)
*
*	PARAMETERS:
*
*/
%macro model_step(	libn=,
					outlibn=,
					dsn_var_sel=,
					dsn_ts_train=,
					dsn_ts_score=,
					outdsn=,
					by_var=,
					ycol=,
					xcol=,
					y=,
					predict_var_name=,
					time_var=
					);

/*==================================================================================*/
/* Incude statements */
/*==================================================================================*/

	PROC SORT data=&dsn_var_sel. out=&outlibn..t1(keep=&ycol. &by_var. &xcol.) nodupkey;
		by &ycol. &by_var. &xcol.;
	RUN;

	DATA _null_;
		call symputx("lastby", scan("&by_var",-1));
	RUN;

	DATA &outlibn..t1;
		retain id 0;
		set &outlibn..t1 end=e;
		by &ycol &by_var.;
		if first.&lastby then id+1;
		if e then call symputx("lastid",id);
	RUN;

/*==================================================================================*/
/* Combine train and score */
/*==================================================================================*/

	DATA &outlibn..train_score;
		set &dsn_ts_train. &dsn_ts_score.;
		if (missing(&y.)) then data_type=1;
		else data_type=0;
		time_dummy=month(start_dt);
		format start_dt date9.;
	RUN;

	PROC SORT data=&outlibn..train_score;
		by &by_var. &time_var.;
	RUN;

/*==================================================================================*/
/* Modeling */
/*==================================================================================*/

	%let col=%scan(&by_var.,-1);

	PROC SORT data=&outlibn..train_score;
		by &col.;
	RUN;QUIT;

	DATA &outlibn..train_score;
		set &outlibn..train_score end=eof;
		by &col.;
		retain colid 0;
		if first.&col. then colid + 1;
		if eof then call symputx("last_colid",colid);
	RUN;

	%do j = 1 %to &last_colid;
	PROC SQL noprint;
		select &xcol. into : indeps separated  by ' ' from &outlibn..t1 where id=&j;
	QUIT;
		DATA &outlibn..vals_&j;
			set &outlibn..train_score;
			where colid = &j;
		RUN;

		PROC HPREG data=&outlibn..vals_&j noprint;
			partition roleVar=data_type(train='0' test='1');
			id &by_var. &time_var. &y.;
			class time_dummy;
			model &y.= time_dummy &indeps.;
			output out=&outlibn..r_p_&j pred=predict;
		RUN;QUIT;

	%end;

	DATA &outlibn..reg_prediction;
		set	&outlibn..r_p_:;
		res=&y-predict;
	RUN;

	* Forecast server on residuals;
	PROC SORT data=&outlibn..reg_prediction;
		by &by_var. &time_var.;
	RUN;QUIT;

	PROC HPFDIAGNOSE data=&outlibn..reg_prediction
		outest=&outlibn..in_est
		modelrepository=mycat
		prefilter=extreme 
		errorcontrol=(severity=HIGH stage=(PROCEDURELEVEL)) 
		EXCEPTIONS=CATCH
		errorcontrol=(severity=none stage=all);
		by &by_var.;
		forecast res / accumulate=total;
		id &time_var. interval=&time_int.;
		arimax;
		esm method=best;
	RUN;QUIT;

	PROC HPFENGINE data=&outlibn..reg_prediction
		inest=&outlibn..in_est
		modelrepository=mycat
		out=_NULL_
		outfor=&outlibn..hpf_prediction(keep=&by_var &time_var. predict rename=(predict=predict_res))
		lead=24
		errorcontrol=(severity=HIGH, stage=(PROCEDURELEVEL))
		EXCEPTIONS=CATCH;
		by &by_var.;
		id &time_var. interval=&time_int.;
		forecast res  / accumulate=total;
	RUN;QUIT;


	* sum reg+hpf forecast ;
	DATA &outlibn..model_prediciton;
		merge &outlibn..hpf_prediction &outlibn..reg_prediction;
		by &by_var;		 
		if missing(predict) then predict= 0;
		if missing(predict_res) then predict_res= 0;
		&predict_var_name=predict+predict_res;
	RUN;

	* do not allow negative forecasts ;
	DATA &libn..&outdsn.(drop=predict predict_res res);
		 set &outlibn..model_prediciton;
		 if &predict_var_name < 0 then &predict_var_name = 0;
		 diff=abs(&predict_var_name-&y);
	RUN;

/*==================================================================================*/
/* Delete intermediate files */
/*==================================================================================*/

	PROC DATASETS library=&outlibn memtype=data nolist;
		delete	t1
				train_score
				reg_prediction
				hpf_prediction
				model_prediciton
				vals_:
				r_p_:
				;
	RUN;QUIT;

%MEND model_step;
