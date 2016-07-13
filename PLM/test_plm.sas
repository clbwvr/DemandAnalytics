%include "C:\Users\calwea\Dropbox\DDPO\Code\plm\code\unravel_hier.sas";
%include "C:\Users\calwea\Dropbox\DDPO\Code\plm\code\incremental_plm.sas";
libname a "C:\Users\calwea\Dropbox\DDPO\Code\plm\data";

data adjtest;
format from $32. to $32. start_dt MONYY.;
input from $ to $ adjustment start_dt type $;
cards;
Product1 CALEB .5 15341 L
Product2 CALEB .5 15341 L
;

%unravel_hier(
	adjtest,
	adjtestout,
	from,
	to,
	adjustment,
	start_dt,
	type
)

%incremental_plm(
	dsn=sashelp.pricedata,
	adjustment_dsn=adjtestout,
	dim=productname,
	by_vars=regionName productLine,
	time_id=date,
	actuals=sale,
	outdsn=testplm
)

data test;
	set testplm;
	where productName in ('Product1','Product2','CALEB');
run;
proc sgplot data=test;
	series x=date y=sale / group=productname;
run;