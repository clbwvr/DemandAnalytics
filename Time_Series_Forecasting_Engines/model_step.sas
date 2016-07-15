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
					ycol=,
					xcol=,
					y=,
					byvar=,
					time_var=
					);

/*==================================================================================*/
/* Incude statements */
/*==================================================================================*/

	PROC SORT data=&dsn_var_sel. out=&outlibn..t1(keep=&ycol &byvar &xcol) nodupkey;
		by &ycol &byvar &xcol;
	RUN;

	DATA _null_;
		call symputx("lastby", scan("&byvar",-1));
	RUN;

	DATA &outlibn..t1;
		retain id 0;
		set &outlibn..t1 end=e;
		by &ycol &byvar;
		if first.&lastby then id+1;
		if e then call symputx("lastid",id);
	RUN;

/*==================================================================================*/
/* Combine train and score */
/*==================================================================================*/

	DATA &outlibn..train_score;
		set &dsn_ts_train &dsn_ts_score;
		if (missing(&y)) then data_type=1;
		else data_type=0;
	RUN;

	PROC SORT data=&outlibn..train_score;
		by &byvar &time_var;
	RUN;

/*==================================================================================*/
/* Modeling */
/*==================================================================================*/

	%do i = 1 %to &lastid;
		PROC SQL noprint;
			select &xcol into : indeps separated  by ' ' from &outlibn..t1 where id=&i;
		QUIT;
		

		%let col=%scan(&byvar,-1);

		PROC SQL noprint;
			select distinct &col into : col_vals separated by '#' from &outlibn..train_score;
		QUIT;

		%let j=1;
		%let col_val = %scan(&col_vals,&j,#);
		%do %until(&col_val eq %nrstr( ));
			
			DATA &outlibn..vals_&j;
				set &outlibn..train_score;
				where &col = "&col_val";
			RUN;

			PROC HPREG data=&outlibn..vals_&j noprint;
				partition roleVar=data_type(train='0' test='1');
				id &byvar. &time_var. &y.;
				class time_dummy;
				model &y.=time_dummy &indeps.;
				*selection method=lasso;
				output out=&outlibn..r_p_&j pred=prediction;
			RUN;QUIT; 

			%let j=%eval(&j+1);
			%let col_val = %scan(&col_vals,&j,#);
		%end;

		DATA &outlibn..reg_prediction;
			set	&outlibn..r_p_:;
		RUN;

		* do not allow negative forecasts ;
		DATA &libn..&outdsn.;
			 set &outlibn..reg_prediction;
			 if ^missing(prediction) and prediction < 0 then do;
			  prediction = 0;
			 end;
		RUN;
	%end;

/*==================================================================================*/
/* Delete intermediate files */
/*==================================================================================*/

	PROC DATASETS library=&outlibn memtype=data nolist;
		delete	t1
				train_score
				reg_prediction
				vals_:
				r_p_:
				;
	RUN;QUIT;

%mend;