
/******************************************************************************
*
* Name : kernelsmooth.sas
*
* Author : Caleb Weaver (caleb.weaver@sas.com)
*
* Description : Nadaraya-Watson kernel regression estimate
*
*
******************************************************************************/

%macro kernelsmooth(
	indsn=,
	outdsn=,
	bandwidth=,
	distr=,
	byvar=,
	y=,
	x=,
	smoothvar=smooth,
	forecast=0,
	plot=0
);

%if &bandwidth= %then %do;
	%let bandwidth = 1;
%end;

%if %upcase(&distr) ^= NORMAL and %upcase(&distr) ^= UNIFORM %then %do;
	%put WARNING:Use normal or uniform distribution;
	%return;
%end;

%if y= %then %do;
	proc kde data=channel;
		by &byvar;
    	univar x(bwm=&bandwidth) 
			method = sjpi 
			out = &outdsn;
	run;
%end;

%else %do;

	proc sort data=&indsn;
		by &byvar &x;
	run;
		
	proc means data=&indsn noprint;
		by &byvar &x;
		var &y;
		output out=sums sum=sy;
	run;

	data _null_;
		set sums end=eof nobs=nobs;
		if _n_ = 1 then call symputx("xmin",&x);
		if eof then do;
			call symputx("xmax",&x);
			call symputx("npoints",nobs);
		end;
	run;

	data kern(drop = w sw yj xj);
		do i = 1 to &npoints;
		retain &smoothvar 0;
		&smoothvar = 0;
		set sums point=i;
		w = 0;
		sw = 0;
		do j = 1 to &npoints;
		set &indsn(rename = (&y=yj &x=xj)) point=j;
		%if %upcase(&distr) = NORMAL %then %do;
			w = pdf("&distr", xj, &x, &bandwidth);
		%end;
		%if %upcase(&distr) = UNIFORM %then %do;
			w = pdf("&distr", xj, &x - &bandwidth, &x + &bandwidth);
		%end;
		sw + w;
		&smoothvar + w * yj;
		end;
		&smoothvar = &smoothvar / sw;
		output;
		end;
		stop;
	run;

	%if &forecast = 1 %then %do;
/*		%if not &by_var= %then %do;*/
/*			proc sort data=kern;*/
/*				by &byvar &x;*/
/*			run;*/
/*			*/
/*			%let lastby = %scan(&byvar,-1);*/
/*			data &outdsn;*/
/*				set kern;*/
/*				by &byvar;*/
/*				if last.&lastby then do;*/
/*					output;*/
/*				end;*/
/*			run;*/
/*		%end;*/
/*		%else %do;*/
/*			data &outdsn;*/
/*				set kern end=eof;*/
/*				by &byvar;*/
/*				if eof then do;*/
/*					output;*/
/*				end;*/
/*			run;*/
/*		%end;*/
	%end;

	%if &plot %then %do;
		proc sgplot data = &outdsn;
		scatter x=&x y=sy;
		series x=&x y=&smoothvar / lineattrs=(color="red");
		run;
	%end;

%mend;



data test;
do x=1 to 2 by .01;
y=x*x*x+.5*rannor(123);
output;
end;
run;
%kernelsmooth(
indsn=test,
outdsn=b,
bandwidth=.025,
distr=NORMAL,
byvar=,
y=y,
x=x,
forecast=1,
plot=1
)
