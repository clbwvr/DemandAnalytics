/*
*	PARAMETERS:
*	indsn 			-	Input data. Contains variables: &from_id_var, &to_id_var, &adjustment_var, &start_dt_var, &type_var
*	outdsn 			-	Output dataset (the unraveled relationships)
*	from_id_var		-	From variable in the indsn
*	to_id_var		-	To variable in the indsn
*	adjustment_var	-	Adjustment variable in the indsn
*	start_dt_var	-	Start date variable in the indsn
*	type_var		-	Type variable in the indsn
*/

%macro unravel_hier(
	indsn,
	outdsn,
	from_id_var,
	to_id_var,
	adjustment_var,
	start_dt_var,
	type_var
/*	,fact_table=,*/
/*	fact_table_id,*/
/*	fact_table_date_var=,*/
);
	data adj;
		set &indsn;
	run;

	/* find first &start_dt_var for actual */
/*	%if not &fact_table= %then %do;
		data a b;
			set adj;
			if &start_dt_var is not missing then output a;
			else output b;
		run;
		proc sql;
			select distinct quote(&to_id_var) into : tos separated by ',' 
			from b 
			where &start_dt_var is missing;
	 	quit;
		proc sql;
			create table c as 
			select distinct &fact_table_id as &to_id_var, 
							min(&fact_table_date_var) as &start_dt_var 
			from &fact_table 
			where &fact_table_id in (&tos)
			group by &fact_table_id;
		quit;
		proc sql;
			create table d as 
			select 	b.&from_id_var, 
					b.&to_id_var,
					b.&adjustment_var, 
					c.&start_dt_var, 
					b.&type_var 
			from b, c 
			where b.&to_id_var = c.&to_id_var
		quit;
		data adj;
			set a d;
		run;
	%end;
*/	
		

	/* Remove &start_dt_var's from additives */
	data adj;
		set adj;
		&type_var = upcase(&type_var);
		if &type_var = 'A' then &start_dt_var = .;
	run;

	/* Make sure &to_id_var's have only one start date */
	proc sql;
		create table temp as select &to_id_var, count(*) as count from (
			select distinct &to_id_var, &start_dt_var from adj
		) group by &to_id_var;
	quit;
	data _null_;
		set temp;
		call symputx("error", '');
		if count > 1 then do;
			call symputx("error", &to_id_var);
			stop;
		end;
	run;
	%if &error= %then %do; %end;
	%else %do;
		%put WARNING: &error has multiple start dates ;
		%return;
	%end;

	/* Weighting */
/*	proc sql;*/
/*		create table temp as select * from adj;*/
/**/
/*		create table totals as*/
/*		select sum(&adjustment_var) as sum, &to_id_var, &type_var*/
/*		from temp*/
/*		group by &to_id_var, &type_var;*/
/**/
/*		create table adj as select*/
/*		t1., t1.&to_id_var, t1.&adjustment_var/t2.sum as &adjustment_var, t1.&start_dt_var, t1.&type_var*/
/*		from temp t1, totals t2 where t1.&to_id_var = t2.&to_id_var;*/
/*	quit;*/

	/* Delete old levels */
	proc datasets lib=work noprint;
		delete level:;
	run;

	/* Unravel */
	proc sql feedback;
		create table level_1 as
		select distinct t1.&from_id_var,
			t1.&to_id_var,
			t1.&adjustment_var,	/* PLM-specific variable */
			ifn(t1.&type_var = 'L', t2.&start_dt_var, .) as begin_dt,
			ifn(t1.&type_var = 'L', t1.&start_dt_var, .) as end_dt,
			t1.&type_var,
			1 as level
		from adj t1 left join adj t2 on t1.&from_id_var = t2.&to_id_var;

		%let level = 1;
		 %do %while(&sqlobs > 0);
			%let nlevel = %eval(&level + 1);
			%let lastlevel = %eval(&level - 1);
			create table level_&nlevel as
			select t2.&from_id_var as &from_id_var,
				t1.&to_id_var as &to_id_var,
				t1.&adjustment_var * t2.&adjustment_var as &adjustment_var,
				ifn(t1.&type_var = 'L', t2.begin_dt, .) as begin_dt,
				ifn(t1.&type_var = 'L', t2.end_dt, .) as end_dt,
				t1.&type_var as &type_var,
				&nlevel as level
			from adj t1
				inner join
				level_&level t2
				on t1.&from_id_var = t2.&to_id_var;
			%let level = &nlevel;
		%end;
	quit;
	data all;
		set level:;
	run;

	/* Create output */
	proc sql;
		create table &outdsn as
		select unique &from_id_var as from_id,
			&to_id_var as to_id,
			&adjustment_var as adjustment,
			begin_dt,
			end_dt,
			&type_var as type
		from all
		where &from_id_var is not missing and &to_id_var is not missing
		order by &from_id_var, &to_id_var;
	quit;
%mend;
