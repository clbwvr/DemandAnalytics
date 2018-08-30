/*****************************************************************************/
/* This is a high level explanation of time series regression. */ 
/* The same ideas are used for the reconciliation level forecasting */
/* at Gap. At Gap, we're doing model selection, regressing on other */ 
/* calculated effects, and using different procs, but the use of */
/* time variables is very similar. */
/* - Caleb Weaver (SAS) */
/*****************************************************************************/

/* model selection method */
/* Gap currently using lasso, but backward makes it easier to see effect */
/* in output results */
%let selection = backward;

/* path to regsales.dat */
%let path = C:\Users\calwea\Desktop;

/*****************************************************************************/
/* Read dataset */
/*****************************************************************************/

data regsales;
	format date date9.;
	informat date date9.;
	infile "&path.\regsales.dat" dlm='09'x missover dsd;
	input date : date7. sales : best3.;
run;

/*****************************************************************************/
/* Data for time series regression */
/*****************************************************************************/

/* Regression is good for modeling seasonal time series with strong patterns */
/* It also makes modeling independent variable effects simpler and more efficient */

proc sgplot data=regsales;
	title "Seasonal Time Series";
	series x=date y=sales / lineattrs=(thickness=2); 
run;

/****************************************************************************/
/* Predictors */
/****************************************************************************/

/* We use a repeating numeric to account for trend. */
/* Generally, for the recon levels we're using at Gap, there is no significant */
/* trend, so the variable is generally removed in model selection. */

/* Seasonality is accounted for with season definitions, provided by Gap. */
/* Here, we'll use quarter as season. */

/* Cycle is the week of the year. We'll use these as categorical dummy variables. */
/* Note that there isn't a variable for every week in the dataset. This would result */
/* in n = p. The dummy variables are for each week number within a year
/* and account for discrete relative values within time periods. */
/* We'll discuss why this isn't overfitting. */

/* Create time predictor variables */
data regts;
	set regsales;
	trend = _n_;
	season = qtr(date);
	cycle = week(date);
run;

/****************************************************************************/
/* TS Regression */
/****************************************************************************/

/* Split to train and score datasets */
data train score;
	set regts;
	if date < '01jan2016'd then do;
		output train;
	end;
	else do;
		output score;
	end;
run;

/* At Gap, we use High-Performance procs, like hpreg, and we do model selection and weighting, */
/* and model calculated effects, but the ideas are similar, this is just a simpler version. */
/* Look at the glm output to see estimated coefficients and fit statistics */
proc glm data=train;
	class cycle;
	model sales=season cycle trend;
	store score;
run;quit;

/* Score the score dataset */
proc plm restore=score;
   score data=score out=preds; 
run;

/* Plot predicted against actuals */
data final;
	set train preds;
run;
proc sgplot data=final;
	title "Simple TS Regression";
	title2 "Scored Forecast over Test Actuals";
	series x=date y=sales;
	series x=date y=predicted; 
run;

/* Let's zoom in on just the scoring time frame */
/* We can see that most of the jumps and falls are captured, */
/* but there is noise in the out of sample that is impossible to fit */ 
/* But it's very good for a prediction. */
proc sgplot data=final(where=(date>='01jan2016'd));
	series x=date y=sales;
	series x=date y=predicted; 
run;

/* What about trend? */
/* In the last one there was no trend. But look at this example: */
data trend;
	set regts;
	if year(date) = 2014 then sales = sales + 20;
	else if year(date) = 2015 then sales = sales + 40;
	else if year(date) = 2016 then sales = sales + 60;
run;
proc sgplot data=trend(where=(year(date)<2016));
	title "Seasonal Data with Trend";
	series x=date y=sales / lineattrs=(thickness=2);
run;

/* There is trend. So our trend variable will be significant to the model */
data train score;
	set trend;
	if date < '01jan2016'd then do;
		output train;
	end;
	else do;
		output score;
	end;
run;

/* Fit model with trend */
/* Look at the glm output to see estimated coefficients and fit statistics */
proc glm data=train;
	class cycle;
	model sales=season cycle trend;
	store score;
run;quit;

/* Score score data */
proc plm restore=score;
   score data=score out=preds; 
run;

/* Plot scored forecast against test actuals */
data final;
	set train preds;
run;
proc sgplot data=final;
	title "Simple TS Regression with Significant Trend";
	title2 "Scored Forecast over Test Actuals";
	series x=date y=sales;
	series x=date y=predicted; 
run;

/* What about overfitting with all these time predictors and */
/* holiday and effects, etc? We're doing variable selection with */
/* penalizations on overfitting. To see this, let's generate fifty */
/* predictors and see if any remain after variable selection */
/* We get that only x11 and x19 are significant in the model */
/* Look at the glm output to see the significant vars */
%macro m;
/* Generate garbage dummy vars */
data garbage;
	set work.regts;
	%do i = 1 %to 50;
		if ranuni(123) < .05 then x&i = 1;
		else x&i = 0;
	%end;
run;

/* Split train and score datasets */
data train score;
	set garbage;
	if date < '01jan2016'd then do;
		output train;
	end;
	else do;
		output score;
	end;
run;

/* Fit model with garbage dummies */
/* Note from the output that model selection */
/* Chooses a model with two of the generated effects */
/* Looking at the data, we can see that these effects */
/* are correlated with bumps in the data that don't */
/* exist in other years for their week nums */
proc glmselect data=train;
	class cycle; 
	model sales = season cycle 
		%do i=1 %to 50; 
			x&i 
		%end; 
		/ selection=&selection;
	store store;
run; 

/* Score score dataset */
proc plm restore=store;
	score data=score out=preds; 
run;

/* Plot forecast against actuals */
data final;
	set train preds;
run;
proc sgplot data=final;
	title "Garbage Dummies";
	title2 "Scored Forecast over Test Actuals";
	series x=date y=sales;
	series x=date y=predicted; 
run;
%mend;
%m

/* What if we have moving holidays? */
/* We can model them using dummy variables */
/* Let's make up a moving holiday: */
data movingholiday;
	format date date9.;
	set work.regts;
	if date in ('05may2013'd, '11may2014'd, '03may2015'd, '08may2016'd) then do;
		sales = sales + 20;
		isholiday = 1;
	end;
	else isholiday = 0;
run;

/* Plot sales with holiday indicator */
proc sgplot data=movingholiday(where=(date<'01jan2016'd));
	title "Moving Holidays";
	title2 "Holiday Weeks in Red";
	series x=date y=sales;
	scatter x=date y=sales / group=isholiday markerattrs=(symbol=circlefilled size=7);
run;

/* Create train score datasets */
data train score;
	set movingholiday;
	if date < '01jan2016'd then do;
	output train;
	end;
	else do;
	output score;
	end;
run;

/* Model fit with holiday effect */
/* Note that it is significant to the model */
/* Look at the glm output to see estimated coefficients and fit statistics */
proc glmselect data=train;
	class cycle; 
	model sales = season cycle isholiday / selection=&selection;
	store store;
run; 

/* Score score data */
proc plm restore=store;
	score data=score out=preds; 
run;

/* Plot scored forecast over test actuals */
data final;
	set train preds;
run;

/* Note that even though the holiday moves within different week id's,
/* we model the effect correctly every cycle */
proc sgplot data=final;
	title "Moving Holidays";
	title2 "Holidays indicated by grey ref line";
	series x=date y=sales / lineattrs=(color=black) markerattrs=(symbol=circlefilled color=black) ;
	series x=date y=predicted / lineattrs=(color=red) ;
	refline '05may2013'd / axis=x  lineattrs=(color=grey pattern=dash) ;
	refline '11may2014'd / axis=x  lineattrs=(color=grey pattern=dash) ;
	refline '03may2015'd / axis=x  lineattrs=(color=grey pattern=dash) ;
	refline '08may2016'd / axis=x  lineattrs=(color=grey pattern=dash) ;
run;


/* What if we have events? */
/* Made up event that isn't on a specific day: */
data events;
	format date date9.;
	set work.regts;
	if date in ('07apr2013'd, '07jul2013'd, '10nov2013'd, '20jul2014'd ,'25jan2015'd, '11oct2015'd, '21feb2016'd) then do;
		sales = sales + 30;
		isevent = 1;
	end;
	else isevent = 0;
run;

/* Events are marked in red. Notice sales go up on event weeks */
proc sgplot data=events(where=(date<'01jan2016'd));
	title "Event Effect";
	series x=date y=sales;
	scatter x=date y=sales / group=isevent markerattrs=(symbol=circlefilled size=5);
run;

/* Create train score data */
data train score;
	set events;
	if date < '01jan2016'd then do;
		output train;
	end;
	else do;
		output score;
	end;
run;

/* Model fit with event effect */
/* Note that it is significant in the model */
/* Also note that is estimates correctly (we created an artificial 30 sales bump for events */
/* Look at the glm output to see estimated coefficients and fit statistics */
proc glmselect data=train;
	class cycle; 
	model sales = season cycle isevent / selection=&selection;
	store store;
run; 

/* Score score data */
proc plm restore=store;
	score data=score out=preds; 
run;

/* Plot the scored forecast against test actuals */
data final;
	set train preds;
run;

/* Note that our forecast correctly picks up on the future event effect (the one in 2016) */
proc sgplot data=final;
	title "Event Effect";
	title2 "Event indicated by grey ref line";
	series x=date y=sales / lineattrs=(color=black) markerattrs=(symbol=circlefilled color=black) ;
	series x=date y=predicted / lineattrs=(color=red) ;
	refline '07apr2013'd / axis=x  lineattrs=(color=grey pattern=dashed) ;
	refline '07jul2013'd / axis=x  lineattrs=(color=grey pattern=dashed) ;
	refline '10nov2013'd / axis=x  lineattrs=(color=grey pattern=dashed) ;
	refline '20jul2014'd / axis=x  lineattrs=(color=grey pattern=dashed) ;
	refline '25jan2015'd / axis=x  lineattrs=(color=grey pattern=dashed) ;
	refline '11oct2015'd / axis=x  lineattrs=(color=grey pattern=dashed) ;
	refline '21feb2016'd / axis=x  lineattrs=(color=grey pattern=dashed) ;
run;
