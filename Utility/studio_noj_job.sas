/*	This set of macros provides an interface to running Forecast Studio projects without using the JAVA midtier
*
*	studio_noj_job
*
*	proj 	- 	Name of the Forecast Studio Project to run
* 	method 	- 	The method to invoke (DESTRUCTIVE-DIAGNOSE, DIAGNOSE, SELECT, FIT, FORECAST or RECONCILE)
*	threads	- 	The number of threads to use. If you specify a number > 1 the script will invoke the multi_thread_fs macro
				which calls PROC LUA wiht the loa script multi_thread_fs.lua. This script parses the Forecast Studio 
				.sas file (e.g. DIAGNOSE_DESTRUCTIVE_IMPORT_DATA.sas) to create a version which uses mpconnect to segment
				the data in the project and spawn multiple processes for the HPFDIAGNOSE and HPFENGINE commands.
				If threads = 1, the process uses the original .sas files without modification.
* STUDIO_DIR_ROOT - The path to the Projects directory for Forecast Studio. Best practice is to update the default to the 
					desired path. 
*
* BEFORE USE UPDATE THE LUA_PATH VARIABLE TO THE APPROPRIATE LOCATION OF THE multi_thread_fs.lua file
*
*	EXAMPLE INVOCATION
*
*	%studio_noj_job(	proj 	= FS_Project1,
						method 	= DIAGNOSE,
						threads = 4);	
*
*
*/	

%let LUA_PATH = '/home/sasdemo/fes_macros';

%macro multi_thread_fs(	inFilename	= , /* The FS Studio program to parse into a multi-threaded program */
						threads		= 4,  /* Number of threads to use in new program */
						outFilename	= /tmp/LUA_TEST_out.sas /* Name of new sas program to create */
						);
	%put proc lua &inFilename output to &outFilename;
	filename LuaPath &LUA_PATH;
	proc lua infile='multi_thread_fs'; run;
%mend multi_thread_fs;


%macro studio_noj_job(	proj 	= , /* Name of the Forecast Studio Project */
						method 	= , /* The method to invoke (DESTRUCTIVE-DIAGNOSE, DIAGNOSE, SELECT, FIT, FORECAST or RECONCILE) */
						threads = 1,  /* Number of threads to use while running FS_Studio code */
						STUDIO_DIR_ROOT=/home/fs_env/Projects/ /* Directory path to Studio Projects */
					);
	%if 				"%upcase(&method)" = "DESTRUCTIVE-DIAGNOSE" 		%then %do;
		%if &threads > 1 %then %do;
			%let FS_prog_name = %sysfunc(cat(&STUDIO_DIR_ROOT, 
											&proj, 
											/DIAGNOSE_DESTRUCTIVE_IMPORT_DATA.sas));
			%multi_thread_fs(inFilename = &FS_prog_name,
								threads = &threads,
								outFilename = /tmp/MT_FS_PROG.sas);
			%include "/tmp/MT_FS_PROG.sas";	
		%end; %else %do;
			%let script = %sysfunc(quote(%sysfunc(cat(&STUDIO_DIR_ROOT, &proj, 
								/DIAGNOSE_DESTRUCTIVE_IMPORT_DATA.sas))));
			%include &script;
		%end;
	%end; %else %if		"%upcase(&method)" = "DIAGNOSE" 	%then %do;	
		%if &threads > 1 %then %do;
			%let FS_prog_name = %sysfunc(cat(&STUDIO_DIR_ROOT, 
											&proj, 
											/DIAGNOSE_NON_DESTRUCTIVE_IMPORT_DATA.sas));
			%multi_thread_fs(inFilename = &FS_prog_name,
								threads = &threads,
								outFilename = /tmp/MT_FS_PROG.sas);
			%include "/tmp/MT_FS_PROG.sas";	
		%end; %else %do;
			%let script = %sysfunc(quote(%sysfunc(cat(&STUDIO_DIR_ROOT, &proj, 
								/DIAGNOSE_NON_DESTRUCTIVE_IMPORT_DATA.sas))));
			%include &script;
		%end;
	%end; %else %if 	"%upcase(&method)" = "SELECT" 		%then %do;
		%if &threads > 1 %then %do;
			%let FS_prog_name = %sysfunc(cat(&STUDIO_DIR_ROOT, 
											&proj, 
											/SELECT_MODELS_IMPORT_DATA.sas));
			%multi_thread_fs(inFilename = &FS_prog_name,
								threads = &threads,
								outFilename = /tmp/MT_FS_PROG.sas);
			%include "/tmp/MT_FS_PROG.sas";	
		%end; %else %do;
			%let script = %sysfunc(quote(%sysfunc(cat(&STUDIO_DIR_ROOT, &proj, 
								/SELECT_MODELS_IMPORT_DATA.sas))));
			%include &script;
		%end;
	%end; %else %if 	"%upcase(&method)" = "FIT" 		%then %do;
		%if &threads > 1 %then %do;
			%let FS_prog_name = %sysfunc(cat(&STUDIO_DIR_ROOT, 
											&proj, 
											/FIT_MODELS_IMPORT_DATA.sas));
			%multi_thread_fs(inFilename = &FS_prog_name,
								threads = &threads,
								outFilename = /tmp/MT_FS_PROG.sas);
			%include "/tmp/MT_FS_PROG.sas";	
		%end; %else %do;
			%let script = %sysfunc(quote(%sysfunc(cat(&STUDIO_DIR_ROOT, &proj, 
								/FIT_MODELS_IMPORT_DATA.sas))));
			%include &script;
		%end;
	%end; %else %if 	"%upcase(&method)" = "FORECAST" 		%then %do;
		%if &threads > 1 %then %do;
			%let FS_prog_name = %sysfunc(cat(&STUDIO_DIR_ROOT, 
											&proj, 
											/FORECAST_IMPORT_DATA.sas));
			%multi_thread_fs(inFilename = &FS_prog_name,
								threads = &threads,
								outFilename = /tmp/MT_FS_PROG.sas);
			%include "/tmp/MT_FS_PROG.sas";	
		%end; %else %do;
			%let script = %sysfunc(quote(%sysfunc(cat(&STUDIO_DIR_ROOT, &proj, 
								/FORECAST_IMPORT_DATA.sas))));
			%include &script;
		%end;
	%end; %else %if 	"%upcase(&method)" = "RECONCILE" 		%then %do;
		%let script = %sysfunc(quote(%sysfunc(cat(&STUDIO_DIR_ROOT, &proj, 
								/RECONCILE_FORECASTS_AND_OVERRIDES_DO_NOT_IMPORT_DATA.sas))));
		%include &script;
	%end; %else %do;
		%put UNKNOWN JOB &proj &method;
	%end;
%mend studio_noj_job;

/*%studio_noj_job(proj 	= &smp_cproj, */
/*				method 	= &smp_cmethod,*/
/*				threads = 4);*/
