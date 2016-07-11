%macro model_step(	libn=,
					outlibn=,
					dsn_var_sel=,
					dsn_ts=,
					ycol=,
					xcol=,
					y=,
					byvar=
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
/* Modeling */
/*==================================================================================*/

	%do i = 1 %to &lastid;
		PROC SQL noprint;
			select &xcol into : indeps separated  by ' ' from &outlibn..t1 where id=&i;
		QUIT;
		
		PROC HPREG data=&dsn_ts noprint;
			id &byvar;
			class month12;
			model &y=month12 /*&indeps*/;
		*	selection method=lasso;
			output out=test;
		RUN;QUIT;
	%end;

/*==================================================================================*/
/* Delete intermediate files */
/*==================================================================================*/

%mend;
