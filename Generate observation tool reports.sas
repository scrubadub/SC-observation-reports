/*
	Import the latest clean file data.

	The date group classification for McLeod was done by first defining a natural breakpoint between 8/1/11 and 9/15/11. 
	I then took the remaining items and divided them in half. Since two observations were at 5/24, I grouped them in the first third. 
	Total thirds n=17, 16, 8.
 */

PROC IMPORT OUT= SINGER.OBS_TEAMWORK_20120605 
            DATAFILE= "C:\Documents and Settings\LHUANG\My Documents\Dro
pbox\Documents (Lyen)\Research\SC checklist implementation\Data analysis
\2012-06-05 Matched obs teamwork data, key, cleaned (FINAL).xls" 
            DBMS=EXCEL REPLACE;
     RANGE="match"; 
     GETNAMES=YES;
     MIXED=NO;
     SCANTEXT=YES;
     USEDATE=YES;
     SCANTIME=YES;
RUN;

/*
	This code takes in the matched data teamwork and observation data, strips out the teamwork data and generates the data
	for each hospital needed for the observation report.
	
	As the dataset gets updated, make sure to update the line at the top of the code to load the latest data.
	
	Coding scheme:
	0=No 1=Yes -9999=N/A .=missing
	
	For Q1-Q3:
	0=No 1=Yes, prompted by checklist 2=Yes w/o prompting -9999=N/A .=missing
 */ 
 
data singer.obs_cleaned;
	set SINGER.OBS_TEAMWORK_20120605 (keep = obs_hospid	obs_procdate obs_date_group obs_ptage obs_ptgender obs_inc_time obs_end_time
									 obs_surgspec_cat obs_procperf sig_ebl obs_urgent obs_noncdis obs_delay obs_inpatient obs_obsage
									 obs_obsgender obs_obsrole obs_obsrole_other obs_obsrole_other obs_yrsrole
									 obs_Q1-obs_Q3 obs_Q4A obs_Q4B obs_Q4C obs_Q4D obs_Q4E obs_Q5 obs_Q5A obs_Q6-obs_q14
									 obs_q15a obs_q15b obs_q15C obs_Q15D obs_q16-obs_q25 obs_comments obs_source201201 obs_nodupuid);

	/* 
		Delete all teamwork items which don't have a corresponding observation 
	 */
	if missing(obs_hospid) then delete;
	
	/*
		This section handles a few exceptional cases
		1. Collapse MUSC hospitals into one hospital
		2. McLeod used an older version of the form for some of the observations which did not query for surgical tech participation
			in the checklist. We'll give them credit for it.
	 */
	if obs_hospid=75 then obs_hospid=42;
	if obs_hospid=41 and missing(obs_q4d) then obs_q4d=1;

	/* If team members introduce themselves or the team is established, then give them credit for the intros */
	if obs_q5=1 or obs_q5a=1 then obs_q5_intro=1;
		else obs_q5_intro=0;

	/* 
		If an item is coded 1
		If an item is missing or has a 0, then it is considered not done 
	 */
	if (obs_q1=1 or obs_q1=2 or obs_q1=-9999) then obs_q1_done=1;
		else obs_q1_done=0;
	if (obs_q2=1 or obs_q2=2 or obs_q2=-9999) then obs_q2_done=1;
		else obs_q2_done=0;
	if (obs_q3=1 or obs_q3=2 or obs_q3=-9999) then obs_q3_done=1;
		else obs_q3_done=0;
	if (obs_q6=1 or obs_q6=-9999) then obs_q6_done=1;
		else obs_q6_done=0;
	if (obs_q7=1 or obs_q7=-9999) then obs_q7_done=1;
		else obs_q7_done=0;
	if (obs_q8=1 or obs_q8=-9999) then obs_q8_done=1;
		else obs_q8_done=0;
	if (obs_q9=1 or obs_q9=-9999) then obs_q9_done=1;
		else obs_q9_done=0;
	if (obs_q10=1 or obs_q10=-9999) then obs_q10_done=1;
		else obs_q10_done=0;
	if (obs_q12=1 or obs_q12=-9999) then obs_q12_done=1;
		else obs_q12_done=0;
	if (obs_q13=1 or obs_q13=-9999) then obs_q13_done=1;
		else obs_q13_done=0;
	if (obs_q14=1 or obs_q14=-9999) then obs_q14_done=1;
		else obs_q14_done=0;

	/* 
		2012-06-05
		Old rule: If at least 1 person (circulating nurse, anesthesia, or surgeon) does the timeout, credit is given for the whole timeout
		Now changed to match JC criteria: all people must participate to have it count. We will exclude surgical technicians since some of the
		older forms did not have a field for the surgical techs.

		2012-06-07
		Changed to count surgical techs. We will give credit for McLeod because they used older forms which were missing the surgical techs
	 */
	if (obs_q4a=1 and obs_q4b=1 and obs_q4c=1 and obs_q4d=1) then obs_timeout_complete=1;
		else obs_timeout_complete=0;

/* 
	Calculate overall checklist performance as a binary and count of number of items performed
 */
	if (obs_q1_done=1 and obs_q2_done=1 and obs_q3_done=1 and obs_timeout_complete=1 and 
		obs_q5_intro=1 and obs_q6_done=1 and obs_q7_done=1 and obs_q8_done=1 and obs_q9_done=1 and obs_q10_done=1 and 
		obs_q12_done=1 and obs_q13_done=1 and obs_q14_done=1) 
			then obs_checklist_complete=1;
			else obs_checklist_complete=0;

	obs_num_checklist = obs_q1_done + obs_q2_done + obs_q3_done + obs_timeout_complete + obs_q5_intro + 
						obs_q6_done + obs_q7_done + obs_q8_done + obs_q9_done + obs_q10_done + 
						obs_q12_done + obs_q13_done + obs_q14_done;

	/* 
		Create scoring for the overall weighted average for a hospital 

		Weighted equal average of SCIP measures (Q1-3), briefing (4-10) with 1/4 point for each participant in the time out, and debriefing (12-14)
	 */
	obsSCIPScore = sum(obs_q1_done, obs_q2_done, obs_q3_done);
	obsBriefingScore = sum(obs_q4a, obs_q4b, obs_q4c, obs_q4d)/4 + sum(obs_q5_intro, obs_q6_done, obs_q7_done, obs_q8_done, obs_q9_done, obs_q10_done);
	obsDebriefingScore = sum(obs_q12_done, obs_q13_done, obs_q14_done);
	obsOverallScore = (obsSCIPScore/3 + obsBriefingScore/7 + obsDebriefingScore/3)/3;

	/* Recode the N/As as missing so I can create tables only involving the applicable cases */
	if obs_q1=1 or obs_q1=2 then obs_q1_applicable=1;
		else if obs_q1=0 then obs_q1_applicable=0;
		else if obs_q1=. or obs_q1=-9999 then obs_q1_applicable=.;

	if obs_q2=1 or obs_q2=2 then obs_q2_applicable=1;
		else if obs_q2=0 then obs_q2_applicable=0;
		else if obs_q2=. or obs_q2=-9999 then obs_q2_applicable=.;

	if obs_q3=1 or obs_q3=2 then obs_q3_applicable=1;
		else if obs_q3=0 then obs_q3_applicable=0;
		else if obs_q3=. or obs_q3=-9999 then obs_q3_applicable=.;

	if obs_q12=-9999 then obs_q12_applicable=.;
		else obs_q12_applicable=obs_q12;
	
	if obs_q13=-9999 then obs_q13_applicable=.;
		else obs_q13_applicable=obs_q13;
		
	if obs_q14=-9999 then obs_q14_applicable=.;
		else obs_q14_applicable=obs_q14;

	/* Create Q23, Q24 versions which exclude the N/As */
	if obs_q23=-9999 then obs_q23_noNA=.;
		else obs_q23_noNA = obs_q23;
	if obs_q24=-9999 then obs_q24_noNA=.;
		else obs_q24_noNA = obs_q24;

	/* Need to recode some of the buy-in scores since the old McLeod data used 1-7 Likert scale 
		If old score was 7 then map to 5
		If old score was 5-6 then map to 4
		If old score was 4 then map to 3
		If old score was 2-3 then map to 2
		If old score was 1 then map to 1
	 */
	if missing(obs_q15a) and obs_hospid=41 then do;
		if obs_q16=7 then q16_new=5;
			else if obs_q16=5 or obs_q16=6 then obs_q16_new=4;
			else if obs_q16=4 then q16_new=3;
			else if obs_q16=2 or obs_q16=3 then q16_new=2;
			else if obs_q16=1 then q16_new=1;
		if obs_q17=7 then q17_new=5;
			else if obs_q17=5 or obs_q17=6 then q17_new=4;
			else if obs_q17=4 then q17_new=3;
			else if obs_q17=2 or obs_q17=3 then q17_new=2;
			else if obs_q17=1 then q17_new=1;
		if obs_q18=7 then q18_new=5;
			else if obs_q18=5 or obs_q18=6 then obs_q18_new=4;
			else if obs_q18=4 then q18_new=3;
			else if obs_q18=2 or obs_q18=3 then q18_new=2;
			else if obs_q18=1 then q18_new=1;
	end;
	else do;
		q16_new=obs_q16;
		q17_new=obs_q17;
		q18_new=obs_q18;
	end;

	drop obs_q16-obs_q18;
	rename q16_new = obs_q16;
	rename q17_new = obs_q17;
	rename q18_new = obs_q18;

	/* Calculate case duration EVERYTHING BELOW HERE IS BROKEN!!! */
	start_time = input(obs_inc_time, anydttme8.);
	end_time = input(obs_end_time, anydttme8.);
	format start_time end_time time.;

	if start_time > end_time then end_time = end_time + 43200;

	/* Manual fixes for errors in the data */
	if obs_nodupuid=71 then start_time=start_time + 43200; /* Change a start time of 2:36 AM for a RIH to 2:36 PM */
	if obs_nodupuid=96 then end_time=.; /* The end_time of this case doesn't make sense, cases don't take 12 hours */

	/* Calculate case duration and create binary variables */
	duration_min = (end_time - start_time) / 60;
	if duration_min ge 60 then case_1hr=1;
		else if missing(duration_min) then case_1hr=.;
		else case_1hr=0;
	if duration_min ge 120 then case_2hr=1;
		else if missing(duration_min) then case_2hr=.;
		else case_2hr=0;
run;

/* Calculate overall checklist score by hospital */
proc means data=singer.obs_cleaned mean;
	var obsOverallScore;
	class obs_hospid;
	output out=work.obs_hospscore mean=;
run;

data work.obs_hospscore (drop= _type_);
	set work.obs_hospscore;

	if obs_hospid=. then delete;
run;

proc sort data=work.obs_hospscore out=work.obs_hospscore;
	by obsOverallScore;
run;

/* At this point I find it easiest to cut and paste the numbers into the Excel file "Hospital performance on observation measures.xls" to keep the 
   graph formatting intact. 
 */

%macro createHospitalSet(in=,out=,hospid=);
	data &out;
		set &in;

		if obs_hospid=&hospid;
	run;
%mend;

%macro obsReport(in=);
	proc freq data=&in;
		tables obs_checklist_complete obs_q11 obs_timeout_complete obs_q4a obs_q4b obs_q4c obs_q4d obs_q1_applicable obs_q2_applicable obs_q3_applicable
			   obs_q5_intro obs_q6-obs_q10 obs_q12_done obs_q13_done obs_q14_done obs_q22;
	run;

	proc freq data=&in;
		tables (obs_checklist_complete obs_q11 obs_timeout_complete obs_q4a obs_q4b obs_q4c obs_q4d obs_q1_applicable obs_q2_applicable obs_q3_applicable
			   obs_q5_intro obs_q6-obs_q10 obs_q12_done obs_q13_done obs_q14_done)*obs_date_group / norow nocum nopercent;
	run;
%mend;

%createHospitalSet(in=singer.obs_cleaned, out=work.mcleod, hospid=41);
%obsReport(in=work.mcleod);

/* Calculate overall checklist performance by hospital over time */
proc means data=work.mcleod mean;
	var obsOverallScore;
	class obs_date_group;
	output out=work.mcleod_hospscore mean=;
run;

%createHospitalSet(in=singer.obs_cleaned, out=work.roper, hospid=56);
%obsReport(in=work.roper);

%createHospitalSet(in=singer.obs_cleaned, out=work.georgetown, hospid=23);
%obsReport(in=work.georgetown);

/* Keep in mind we merged the MUSC hospitals together in the original cleaning code */
%createHospitalSet(in=singer.obs_cleaned, out=work.musc_merged, hospid=42);
%obsReport(in=work.musc_merged);

%createHospitalSet(in=singer.obs_cleaned, out=work.palmetto_baptist, hospid=49);
%obsReport(in=work.palmetto_baptist);

%createHospitalSet(in=singer.obs_cleaned, out=work.waccamaw, hospid=70);
%obsReport(in=work.waccamaw);

/* Collapse McLeod from four date groups into two */
data work.mcleod_2groups;
	set work.mcleod;
	
	if obs_date_group=1 or obs_date_group=2 then obs_date_group=5;
	else if obs_date_group=3 or obs_date_group=4 then obs_date_group=6;
run;

%obsReport(in=work.mcleod_2groups);

/* Experiment to collapse the four date groups into two
data work.roper_2groups;
	set work.roper;
	
	if obs_date_group=1 or obs_date_group=2 then obs_date_group=5;
	else if obs_date_group=3 or obs_date_group=4 then obs_date_group=6;
run;

%obsReport(in=work.roper_2groups);

proc freq data=work.roper;
	tables obs_num_checklist;
run; */

proc freq data=singer.obs_cleaned;
	table obs_hospid;
run;
