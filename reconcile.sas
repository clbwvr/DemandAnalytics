/*********************************************************************************************************************
*
*	PROGRAM: 	reconcile.sas
*				Reconcile variables from high to low
*
*
*	MACRO PARAMETERS:
*	highdsn		recon from input dataset
*	highby		recon from by variables
*	highvar		high variable
*	lowdsn		recon to input dataset		
*	lowby		recon to by variables
*	lowvar		low variable
*	outdsn		output dataset name
*
*	==================================================================================================================
*
*	AUTHORS:	Caleb Weaver (caleb.weaver@sas.com)
*
********************************************************************************************************************/

%macro reconcile(
	highdsn=,
	highby=,
	highvar=,
	lowdsn=,
	lowby=,
	lowvar=,
	outdsn=
);

/* commas in macro names */
data _null_;
	call symputx("highbyc",tranwrd("&highby", ' ', ','));
run;
data _null_;
	call symputx("lowbyc",tranwrd("&lowby", ' ', ','));
run;
 
/* Create proportion table */
proc sql;
	create table highvars as select distinct
	&highbyc, &highvar 
	from &highdsn;
quit;
proc sql;
	create table lowvars as select distinct
	&lowbyc, &lowvar
	from &lowdsn order by &highbyc;
quit;
proc sql;
	create table lowsums as select
	&highbyc, sum(&lowvar) as s
	from lowvars group by &highbyc
	order by &highbyc;
quit;
data lowprops(keep=&lowby new&lowvar rename=(new&lowvar=&lowvar));
	merge lowvars(in=a) lowsums;
	by &highby;
	if a;
	prop = &lowvar / s;
	new&lowvar = &lowvar * prop;
run;
%mend;

/*%reconcile(*/
/*	highdsn=temp_cc,*/
/*	highby=prod_id_lvl8,*/
/*	highvar=prediction,*/
/*	lowdsn=temp_leaf,*/
/*	lowby=prod_id_lvl8 loc_id_lvl8,*/
/*	lowvar=prediction,*/
/*	outdsn=tester*/
/*);*/


