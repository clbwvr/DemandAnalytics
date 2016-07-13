infilename 	= sas.symget("inFilename")
outfilename 	= sas.symget("outFilename")
threads		= sas.symget("threads")

sasCommand 		= "/usr/local/SASHome/SASFoundation/9.4/sas -nosyntaxcheck -noterminal -nonews -memsize 4G -realmemsize 4G -sortsize 4G -append sasautos /home/sasdemo/fes_macros"

function doDiagnose(str, infp, outfp)
	dataName = string.match(str, "data=([%a%p%d]+)")
	basename = string.match(str, "basename=([%a%p%d]+)")

	local diagCode = {}
	local byvar = ""
	local lastby = ""
	local lib = string.match(dataName, "([%a%pi%d]+)%.")
	print("str = ", str, "dataName = ", dataName,"basename = ", basename, "lib= ", lib)

	nextline = infp:read()

	while string.match(nextline, "^run;")==nil do
		nextline = string.gsub(nextline, "outest="..lib..".est", "outest="..lib..".est&hpf_i.")
		nextline = string.gsub(nextline, "modelrepository="..lib..".LevModRep", "modelrepository="..lib..".MP_ModRep&hpf_i.")
		nextline = string.gsub(nextline, "outprocinfo="..lib..".hpfdiagnose_outprocinfo", "outprocinfo="..lib..".hpfdiagnose_outprocinfo&hpf_i.")
		table.insert(diagCode, nextline);
		if string.match(nextline, "by ([^;]+);") then byvar = string.match(nextline, "by ([^;]+);") end
		nextline = infp:read()
	end

	for w in string.gmatch(byvar, "[%a%p]+") do lastby = w end
	
	if byvar == "" then 
		datasplits = 0;

	else 
		datasplits = threads - 1;
	
	end 
	outfp:write("data	" .. dataName .. "0 (drop=c)\n")
	if datasplits > 1 then
		for i=1,datasplits do
			outfp:write("		" .. dataName .. i .. " (drop=c)\n")
		end
	end
	outfp:write("	;\n")
	outfp:write("	set " .. dataName .. " nobs=tot end=lastob;\n")
	if datasplits > 1 then 
		outfp:write("	by " .. byvar .. ";\n")
	end
	outfp:write("	retain c 0;\n")
	if datasplits > 1 then
		outfp:write("	if first." .. lastby .. "	then c = floor((_N_ * " .. threads .. ") / tot);\n")
	else
		outfp:write("	c = 0;\n")
	end
	outfp:write("   if lastob       then call symput('" .. lib .. "_cuts', c);\n")
	outfp:write("	select(c);\n")
	for i=0,datasplits do
		outfp:write("		when(" .. i .. ") output " .. dataName .. i .. ";\n")
	end
	outfp:write("		otherwise;\n")
	outfp:write("	end;\n")
	outfp:write("run;\n\n")

	outfp:write("%macro _tmp_diag_" .. lib .. ";\n")
	outfp:write("	%let task_names = ;\n")
	if datasplits > 1 then
		outfp:write("	%do hpf_i = 0 %to &" .. lib .. "_cuts;\n")
	else
		outfp:write("	%let hpf_i = 0;\n")
	end
	outfp:write("\t\tproc catalog catalog=" .. lib .. ".MP_ModRep&hpf_i.;\n")
	outfp:write("\t\t\tcopy in=" .. lib .. ".LevModRep out=" .. lib .. ".MP_ModRep&hpf_i. new; run;\n")
	outfp:write("\t\tquit;\n")
	if datasplits > 1 then
		outfp:write("		signon smp&hpf_i. inheritlib=(_project = _project " .. lib .. " = " .. lib .. ") sascmd=\"" .. sasCommand .. "\";\n")
		outfp:write("\t\t%syslput _ALL_;\n")
		outfp:write("\t\trsubmit smp&hpf_i. wait=no;\n")
	end
	outfp:write("		proc hpfdiagnose data=" .. lib .. ".DATA&hpf_i. basename=" .. basename .. "&hpf_i._\n")
	for k, v in next,diagCode,nil do
		outfp:write("			")
		outfp:write(v)
		outfp:write("\n")
	end
	outfp:write("		run;\n")
	if datasplits > 1 then
		outfp:write("		endrsubmit;\n")
		outfp:write("		%let task_names = &task_names smp&hpf_i.;\n")
		outfp:write("	%end;\n")
		outfp:write("	waitfor _all_ &task_names;\n")
		outfp:write("	signoff _ALL_;\n\n")
                outfp:write("   %do hpf_i = 0 %to &" .. lib .. "_cuts;\n")
        else
                outfp:write("   %let hpf_i = 0;\n")
        end
	if datasplits > 1 then 
		outfp:write("\t%end;\n") 
	end
	outfp:write("%mend _tmp_diag_" .. lib .. ";\n")
	outfp:write("%_tmp_diag_" .. lib .. ";\n")
end


function doEngine(str, infp, outfp)
	dataName = string.match(str, "data=([%a%p%d]+)")

	local diagCode = {}
	local lib = string.match(dataName, "([%a%p%d]+)%.")
 	byvar = "" 
	print("str = ", str, "dataName = ", dataName,"basename = ", basename, "lib= ", lib)

	nextline = infp:read()

	while string.match(nextline, "^run;")==nil do
		nextline = string.gsub(nextline, "modelrepository= "..lib..".LevModRep", "modelrepository="..lib..".MP_ModRep&hpf_i.")
		nextline = string.gsub(nextline, "inest="..lib..".est", "inest="..lib..".est&hpf_i.")
		nextline = string.gsub(nextline, "out="..lib..".out", "out="..lib..".out&hpf_i.")
		nextline = string.gsub(nextline, "outfor="..lib..".outfor", "outfor="..lib..".outfor&hpf_i.")
		nextline = string.gsub(nextline, "outstat="..lib..".outstat", "outstat="..lib..".outstat&hpf_i.")
		nextline = string.gsub(nextline, "outstat="..lib..".recstat", "outstat="..lib..".recstat&hpf_i.")
		nextline = string.gsub(nextline, "outstatselect="..lib..".outstatselect", "outstatselect="..lib..".outstatselect&hpf_i.")
		nextline = string.gsub(nextline, "outest="..lib..".outest", "outest="..lib..".outest&hpf_i.")
		nextline = string.gsub(nextline, "outsum="..lib..".outsum", "outsum="..lib..".outsum&hpf_i.")
		nextline = string.gsub(nextline, "outsum="..lib..".recsum", "outsum="..lib..".recsum&hpf_i.")
		nextline = string.gsub(nextline, "outcomponent="..lib..".outcomponent", "outcomponent="..lib..".outcomponent&hpf_i.")
		nextline = string.gsub(nextline, "outmodelinfo="..lib..".outmodelinfo", "outmodelinfo="..lib..".outmodelinfo&hpf_i.")
		nextline = string.gsub(nextline, "outprocinfo="..lib..".hpfengine_outprocinfo", "outprocinfo="..lib..".hpfengine_outprocinfo&hpf_i.")
		nextline = string.gsub(nextline, "scorerepository="..lib..".scorerepository", "scorerepository="..lib..".scorerepository&hpf_i.")

		if string.match(nextline, "by ([^;]+);") then byvar = string.match(nextline, "by ([^;]+);") end

		table.insert(diagCode, nextline);

		nextline = infp:read()
	end

	outfp:write("%macro _tmp_eng_" .. lib .. ";\n")
	outfp:write("	%let task_names = ;\n")
	if byvar == "" then 
		outfp:write("	%let hpf_i = 0;\n")
	else
		outfp:write("	%do hpf_i = 0 %to &" .. lib .. "_cuts;\n")
		outfp:write("		signon smp&hpf_i. inheritlib=(_project = _project " .. lib .. " = " .. lib .. ") sascmd=\"" .. sasCommand .. "\";\n")
		outfp:write("		%syslput _ALL_;\n")
		outfp:write("		rsubmit smp&hpf_i. wait=no;\n")
	end
	outfp:write("		proc hpfengine data=" .. lib .. ".DATA&hpf_i.\n")
	for k, v in next,diagCode,nil do
		outfp:write("			")
		outfp:write(v)
		outfp:write("\n")
	end
	outfp:write("		run;\n")
	if byvar ~="" then
		outfp:write("		endrsubmit;\n")
		outfp:write("		%let task_names = &task_names smp&hpf_i.;\n")
		outfp:write("	%end;\n")
		outfp:write("	waitfor _all_ &task_names;\n")
		outfp:write("	signoff _ALL_;\n\n")
		outfp:write("   %let i=0;\n")
		outfp:write("	%do %while (&i <= &" .. lib .. "_cuts);\n")
	else
		outfp:write("	%let i=0;\n")
	end
	outfp:write("		%if &i. = 0 %then %do;\n")
	outfp:write("\t\t\t data " .. lib .. ".hpfdiagnose_outprocinfo;\t\t set "..lib..".hpfdiagnose_outprocinfo&i.;\t\t run;\n")
	outfp:write("\t\t\t data " .. lib .. ".est;                    \t\t set "..lib..".est&i.;                    \t\t run;\n")
	outfp:write("\t\t\t data " .. lib .. ".out;                    \t\t set "..lib..".out&i.;                    \t\t run;\n")
	outfp:write("\t\t\t data " .. lib .. ".outfor;                 \t\t set "..lib..".outfor&i.;                 \t\t run;\n")
	outfp:write("\t\t\t data " .. lib .. ".outstat;                \t\t set "..lib..".outstat&i.;                \t\t run;\n")
	outfp:write("\t\t\t data " .. lib .. ".outstatselect;          \t\t set "..lib..".outstatselect&i.;          \t\t run;\n")
	outfp:write("\t\t\t data " .. lib .. ".outest;                 \t\t set "..lib..".outest&i.;                 \t\t run;\n")
	outfp:write("\t\t\t data " .. lib .. ".outsum;                 \t\t set "..lib..".outsum&i.;                 \t\t run;\n")
	outfp:write("\t\t\t data " .. lib .. ".outcomponent;           \t\t set "..lib..".outcomponent&i.;           \t\t run;\n")
	outfp:write("\t\t\t data " .. lib .. ".outmodelinfo;           \t\t set "..lib..".outmodelinfo&i.;           \t\t run;\n")
	outfp:write("\t\t\t data " .. lib .. ".hpfengine_outprocinfo;  \t\t set "..lib..".hpfengine_outprocinfo&i.;  \t\t run;\n")
	outfp:write("\t\t%end; %else %do;\n")
	outfp:write("\t\t\t proc append base=" .. lib .. ".hpfdiagnose_outprocinfo \t data= "..lib..".hpfdiagnose_outprocinfo&i. \t force; run;\n")
	outfp:write("\t\t\t proc append base=" .. lib .. ".est                     \t data= "..lib..".est&i.                     \t force; run;\n")
	outfp:write("\t\t\t proc append base=" .. lib .. ".out                     \t data= "..lib..".out&i.                     \t force; run;\n")
	outfp:write("\t\t\t proc append base=" .. lib .. ".outfor                  \t data= "..lib..".outfor&i.                  \t force; run;\n")
	outfp:write("\t\t\t proc append base=" .. lib .. ".outstat                 \t data= "..lib..".outstat&i.                 \t force; run;\n")
	outfp:write("\t\t\t proc append base=" .. lib .. ".outstatselect           \t data= "..lib..".outstatselect&i.           \t force; run;\n")
	outfp:write("\t\t\t proc append base=" .. lib .. ".outest                  \t data= "..lib..".outest&i.                  \t force; run;\n")
	outfp:write("\t\t\t proc append base=" .. lib .. ".outsum                  \t data= "..lib..".outsum&i.                  \t force; run;\n")
	outfp:write("\t\t\t proc append base=" .. lib .. ".outcomponent            \t data= "..lib..".outcomponent&i.            \t force; run;\n")
	outfp:write("\t\t\t proc append base=" .. lib .. ".outmodelinfo            \t data= "..lib..".outmodelinfo&i.            \t force; run;\n")
	outfp:write("\t\t\t proc append base=" .. lib .. ".hpfengine_outprocinfo  \t data= "..lib..".hpfengine_outprocinfo&i.  \t force; run;\n")
	outfp:write("\t\t%end;\n");
	outfp:write("\t\tproc datasets library = " .. lib .. " nolist nowarn;\n")
	outfp:write("\t\t\tdelete \t hpfdiagnose_outprocinfo&i.\n")
	outfp:write("\t\t\t       \t est&i.\n")
	outfp:write("\t\t\t       \t out&i.\n")
	outfp:write("\t\t\t       \t outfor&i.\n")
	outfp:write("\t\t\t       \t outstat&i.\n")  	
	outfp:write("\t\t\t       \t outstatselect&i.\n")  
	outfp:write("\t\t\t       \t outest&i.\n")  
	outfp:write("\t\t\t       \t outsum&i.\n")  
	outfp:write("\t\t\t       \t outcomponent&i.\n")  
	outfp:write("\t\t\t       \t outmodelinfo&i.\n")  
	outfp:write("\t\t\t       \t hpf_engine_outprocinfo&i.\n")  
	outfp:write("\t\t\trun; quit;\n")	

	outfp:write("\t\tproc catalog catalog=" .. lib .. ".MP_ModRep&i. ;\n")
        outfp:write("\t\t\tcopy in=" .. lib .. ".MP_ModRep&i. out=" .. lib .. ".LevModRep;\n")
        outfp:write("\t\trun; quit;\n")
        outfp:write("\t\tproc datasets library = " .. lib .. " nolist nowarn;\n")
        outfp:write("\t\t\tdelete  MP_ModRep&i.(mt=catalog);\n")
        outfp:write("\t\trun; quit;\n")


	outfp:write("\t\tproc catalog catalog=" .. lib .. ".scorerepository&i. ;\n")
        outfp:write("\t\t\tcopy in=" .. lib .. ".scorerepository&i. out=" .. lib .. ".scorerepository;\n")
        outfp:write("\t\trun; quit;\n")
        outfp:write("\t\tproc datasets library = " .. lib .. " nolist nowarn;\n")
        outfp:write("\t\t\tdelete  scorerepository&i.(mt=catalog);\n")
        outfp:write("\t\trun; quit;\n")

	outfp:write("		%let i	= %eval(&i+1);\n")
	if byvar ~= "" then
		outfp:write("	%end;\n")
	end
	outfp:write("%mend _tmp_eng_" .. lib .. ";\n")
	outfp:write("%_tmp_eng_" .. lib .. ";\n")
end

infp 	= assert(io.open(infilename, "r"))
outfp	= assert(io.open(outfilename, "w"))
foundReconcile = 0

if infp then
	str  	= infp:read()
	while str do
		if 	string.find(str, "^proc hpfdiagnose") then
			doDiagnose(str, infp, outfp)
		elseif 	string.find(str, "^proc hpfengine") and (foundReconcile==0) then
			doEngine(str, infp, outfp)
		elseif  string.find(str, "^proc hpfreconcile") then
			foundReconcile = 1
			outfp:write(str)
			outfp:write("\n")	
		else
			outfp:write(str)
			outfp:write("\n")
		end

		str = infp:read()
	end
	infp:close()
	outfp:close()
end
