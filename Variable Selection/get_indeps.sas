%macro get_indeps(	libn=,
					outlibn=,
					dsn_var_sel=,
					dsn_ts=,
					ycol=,
					xcol=,
					byvar=
					);

	PROC SORT data=&dsn out=&outlibn..t1(keep=&ycol &byvar &xcol) nodupkey;
		by &ycol &byvar &xcol;
	RUN;

	DATA _null_;
		call symputx("lastby", scan("&byvar",-1));
	RUN;

	DATA &outlibn..t1;
		retain id 0;
		set t1 end=e;
		by &ycol &byvar;
		if first.&lastby then id+1;
		if e then call symputx("lastid",id);
	RUN;

	%do i = 1 %to &lastid;
		PROC SQL;
			select &xcol into : indeps separated  by ' ' from &outlibn..t1 where id=&i;
		QUIT;

	/*	proc reg data=&dsn_ts;*/
	/*		model &ycol=&indeps;*/
	/*	run;*/

	%end;

%mend;
