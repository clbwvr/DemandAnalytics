%macro nearesttwo_missing(indsn=,x=,y=,byvar=,outdsn=);

proc sort data=&indsn out=sdsn;
	by &byvar &x;
run;

data sdsn;
	retain a .;
	set sdsn;
	by &byvar &x;
	%if not (&byvar=) %then %do; if first.&byvar then a = .; %end;
	group=1; if &y=. or &y=0 then group=0;
	output;
	if &y ne . and &y ne 0 then a = &y;
run;
proc sort data=sdsn;
	by &byvar descending &x;
run;

data sdsn;
	retain b .;
	set sdsn;
	by &byvar descending &x;
	%if not (&byvar=) %then %do;if first.&byvar then b = .; %end;
	group=1; if &y=. or &y=0 then group=0;
	output;
	if &y ne . and &y ne 0 then b = &y;
run;


/*data neighbors;*/
/*	retain neighborhood 0;*/
/*	set sdsn(keep=a b &y);*/
/*	neighborhood + 1;*/
/*		left = a;*/
/*		center = &y;*/
/*		right = b;*/
/*		output;*/
/*run;*/

data &outdsn;
	set sdsn;
	if &y = 0 or &y = . then &y = mean(a,b);
run;



%mend;
