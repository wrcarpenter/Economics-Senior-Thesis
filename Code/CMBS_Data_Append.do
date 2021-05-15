///////////////////////////////////////////////////////////////////////////////
// Name: Will Carpenter 
// Purpose: Economics Senior Thesis
// Date Created: 08.01.20
// Last Edited: 02.01.21
//
// Description: A Stata program that creates a universe file for loan-level 
// data of CMBS securities issued 2016-2020. It iterates through files 
// that represent each security and contain a collect of the loan-level 
// performance data that is uploaded on a monthly basis to the SEC. These 
// CSV files are converted to DTA and appended together to create master 
// files for each security. These security master files are then appended 
// together to form a singular, universe file. 

///////////////////////////////////////////////////////////////////////////////

// Get a list of all folders 
// Loop through each folder 
// In each folder, get list of the files 
// Import each file, and save a .dta file into a DTA folder
// Go to that DTA folder, then append the files together
// drop out irrelevant loans  
// add a loanid, yearid, securityid 

// cd "E:\Fixed Income Research\CMBS Data\"
// mkdir "CMBS DTA"
// mkdir "masters_CMBS"

// local operatingSystem "`c(os)'"

*************************************************************************
* Determine operating system and set current directory
	
	* WINDOWS (OLGA) 
	if "`c(os)'"=="Windows" {
		local path "H:/"
	}
	* MAC
	if "`c(os)'"=="MacOSX" {
		local path "/Volumes/CARPENTERW/"
	}
	

*************************************************************************

	clear all 
	cls
	set more off
	
	* Generate a list of all folder names (i.e. security names)
	cd "`path'/Fixed Income Research/CMBS Data/CMBS Files/"
	local subdirs : dir "." dirs "*", respectcase	

* Loop over all folder names 
foreach folder of local subdirs {
		
		* New DTA directories only needed if new securities were added 
		cd "`path'/Fixed Income Research/CMBS Data/CMBS DTA/"
		mkdir "`folder' DTA" 
		
		* Generate a list of all monthly reporting files within a folder
		cd "`path'/Fixed Income Research/CMBS Data/CMBS Files"
		local filenames : dir "`folder'" files "*.csv", respectcase
		
		foreach file of local filenames { 
			
			cd "`path'/Fixed Income Research/CMBS Data/CMBS Files/"
			display "`file'"
			
			* Skip over erroneous (empty) file names added to the list 
			if substr("`file'",1,1)=="." {
			   display "SKIPPED"
				 } 
		
		* Import and save monthly security report files 		 
			else {
				import delimited "`folder'/`file'", clear stringcols(_all) varnames(1)
				* File date variable 
				gen fileDate = substr("`file'", 1, 10)
				gen fileName = "`file'"
				* Beginning and end reporting dates 
				gen bDate        = date(reportingperiodbeginningdate, "MDY")
				gen eDate        = date(reportingperiodenddate, "MDY")
				egen beginDate   = max(bDate)
				egen endDate     = max(eDate)
				gen  date        = beginDate
				gen  yearQuarter = qofd(date)
				* Temporary month-date variables
				gen m  = ym(year(beginDate), month(beginDate))
				gen mE = ym(year(endDate), month(endDate))
				* Month-date variables 
				egen modate    = max(m)
				egen modateEnd = max(mE)
				* Drop temporary variables 
				drop m mE 
				* Formatting dates
				format modate modateEnd %tmMon-DD-YY
				format beginDate endDate bDate eDate %td
				* Labelling created variables
				label var date        "Reporting Period Beginning Date (for merging)"
				label var fileDate    "Reporting File Date"
				label var fileName    "Reporting File Full Name"
				label var bDate       "Beginning Date (as reported)"
				label var eDate       "Ending Date (as reported)"
				label var beginDate   "Reporting Period Beginning Date"
				label var endDate     "Reporting Period Ending Date"
				label var modate      "Month-Date (Reporting Beginning Date)"
				label var modateEnd   "Month-Date (Reporting Ending Date)"
				label var yearQuarter "Beginning Period Year-Quarter"
				* Save DTA file 
				local name: subinstr local file ".csv" ""
				cd "`path'/Fixed Income Research/CMBS Data/CMBS DTA/"
				save "`folder' DTA/`name'.dta", replace 
				}
			}
		*********************************************
		* Create CMBS security master file 	
		
		clear all 
		cd "`path'/Fixed Income Research/CMBS Data/CMBS DTA/`folder' DTA" 
		local statafiles: dir . files "*Data Tape*", respectcase 
		append using `statafiles'
		
		* Get year identifier from folder name
		gen yearid = "NULL"
		replace yearid = regexs(0) if regexm(`"`folder'"', "[^ ]*[-][^ ]*")
		* replace yearid = subinstr(yearid, "-","",.) // RETAIN OLD CODE
		
		* Create loanid 
		gen loanid       = `"`folder'"'
		replace loanid   = substr(loanid, 1, strpos(loanid, " ") - 1) // get first word of folder name
		gen securityName = loanid
		gen securityid   = loanid + "-" + yearid
		
		* loan number - Need to adjust for new type of loan id 
		gen loannum     = assetnumber
		replace loannum = subinstr(loannum, "=", "",.)
		replace loannum = subinstr(loannum, `"""',"",.)
		
		* replace numberpropertiessecuritization="1" if numberproperties=="1" /// 
		* & securityid=="CITIGROUP-2016-P6"                                  ///
		* & (loannum=="26" | loannum=="40" | loannum=="21" | loannum=="30" | loannum=="24")
		
		* Clean out all properties labeled as multi-property
		drop if numberpropertiessecuritization != "1"
		
		* Esoteric Loan Number Corrections 
		******************************************
						
		* More general first-aid 
		drop if originalterm=="-"         & securityid=="Morgan-2017-H1"  & numberpropertiessecuritization=="1"
		drop if paymentfrequencycode=="-" & securityid=="UBS-2018-C15"    & numberpropertiessecuritization=="1"
		drop if paymentfrequencycode=="-" & securityid=="UBS-2018-C13"    & numberpropertiessecuritization=="1"
		* Specific file targets 
		drop if originalterm=="-"         & fileDate=="2019.11.13" & securityid=="CITIGROUP-2019-GC43" & numberproperties=="1"
		drop if originalterm=="-"         & fileDate=="2016.12.22" & securityid=="Wells-2016-C37"      & numberproperties=="1"
		
		* One instance of a erroneous numbering with added zeros 
		* Handling some instances of "3-000"
		replace loannum = substr(loannum, 1, strpos(loannum, "-") - 1) ///
		if strpos(loannum, "-000") & securityid=="CSAIL-2020-C19" & fileDate=="2020.03.03"
		
		* Handling some instances of "1.00"
		replace loannum = substr(loannum, 1, strpos(loannum, ".") - 1) ///
		if strpos(loannum, ".00") & securityid=="CD-2018-CD7" & fileDate=="2018.08.24"
		
		* Handling some instances of "1-001"
		replace loannum = substr(loannum, 1, strpos(loannum, "-") - 1) ///
		if strpos(loannum, "-001") & securityid=="UBS-2018-C11" & numberpropertiessecuritization=="1"
				
		replace loannum = substr(loannum, 1, strpos(loannum, "-") - 1) ///
		if strpos(loannum, "-001") & securityid=="UBS-2018-C12" & numberpropertiessecuritization=="1"
		
		replace loannum = substr(loannum, 1, strpos(loannum, "-") - 1) ///
		if strpos(loannum, "-001") & securityid=="UBS-2018-C13" & numberpropertiessecuritization=="1"
		
		replace loannum = substr(loannum, 1, strpos(loannum, "-") - 1) ///
		if strpos(loannum, "-001") & securityid=="CD-2017-CD4" & numberpropertiessecuritization=="1"
		
		replace loannum = substr(loannum, 1, strpos(loannum, "-") - 1) ///
		if loannum=="9-001" & securityid=="Morgan-2017-H1"
		
		replace loannum = substr(loannum, 1, strpos(loannum, "A") - 1) ///
		if strpos(loannum, "A") & securityid=="CITIGROUP-2016-P6"
		
		drop if strpos(loannum, "A") & securityid=="CFCRE-2016-C7"
		
		drop if loannum == "15 A-2-C5" & securityid=="BENCHMARK-2018-B2"
		drop if loannum == "6 A-3"     & securityid=="BENCHMARK-2018-B2"
		drop if loannum == "14 A-2"    & securityid=="BENCHMARK-2018-B2"
		drop if loannum == "10 A-2-C2" & securityid=="BENCHMARK-2018-B2"
		drop if loannum == "10 A-2-C1" & securityid=="BENCHMARK-2018-B2"
		replace loannum = substr(loannum, 1, strpos(loannum, " ") - 1) ///
		if strpos(loannum, " ") & securityid=="BENCHMARK-2018-B2"
		
		drop if loannum == "2-A-1F" & securityid=="BBCMS-2019-C5"
		drop if loannum == "2-A-1E" & securityid=="BBCMS-2019-C5"
		drop if loannum == "2-A-1D" & securityid=="BBCMS-2019-C5"
		drop if loannum == "4-A5"   & securityid=="BBCMS-2019-C5"
		replace loannum = substr(loannum, 1, strpos(loannum, "-") - 1) ///
		if strpos(loannum, "-") & securityid=="BBCMS-2019-C5"
		
		drop if loannum == "2a5" & securityid=="CD-2017-CD4"
		drop if loannum == "2a6" & securityid=="CD-2017-CD4"
		drop if loannum == "6a4" & securityid=="CD-2017-CD4"
		replace loannum = substr(loannum, 1, strpos(loannum, "a") - 1) ///
		if strpos(loannum, "a") & securityid=="CD-2017-CD4"
		
		* This is for CFRE 2016-C7 and Citi 2016-P6
		replace loannum = subinstr(loannum, "0", "", 1) if substr(loannum, 1, 1)=="0"
		
		* One loan was mis-labelled for some periods 
		replace loannum = "4" if loannum=="4-001" & securityid=="CD-2017-CD3"
		
		* Disrepancy between securitized as = 1 and number properties != 1
		* this might be flexible 
		drop if numberproperties!="1" & securityid=="BBCMS-2019-C5"
		drop if numberproperties!="1" & securityid=="CITIGROUP-2016-P6"

		******************************************
		
// 		local id = "4S"
// 		tab securityid if loannum=="`id'"
// 		tab fileDate   if loannum=="`id'"
//		
// 		tab loannum if securityid!="CFCRE-2016-C7" & securityid!="BBCMS-2019-C5" ///
// 		& securityid!="BENCHMARK-2018-B2" & securityid!="CD-2017-CD4"
//		
// 		tab loannum if securityid=="`sec'"
//		
// 		local sec = "CITIGROUP-2016-P6"
// 		tab loannum if securityid=="`sec'"
// 		tab fileDate if loannum=="48" & securityid=="`sec'"
		
		// 8A, 2A can be dropped from Wells-2017-C40
		// 41004-B , could be its own loan (re check)
		
		// BENCHMARK-2018-B2
		// BBCMS-2019-C5
		// CFCRE-2016-C7
		// CF-2019-CF1
		// CITIGROUP-2016-P6
				
		// 1-018    $ UBS-2018-C15
		// 2-044    $ UBS-2018-C15
		// 1.05     $ UBS-2018-C15
		// 1-A2A4A8   BBCMS-2019-C5
		// 6 A-3      BENCHMARK2-018-B2
		// 8-005    $
		// 9.26     $
		// 7-000    $
		// 38-014   $
		// 27.01    $
		// 6-A-1-C   BBCMS-2019-C5	
		// 27-001 $
		// 38-024 $
		// 6 A-3  $ from a benchmark security 
		// 7NP, 3NP think about just dropping these...
			
		* Testing code 
		* tab loannum
		* tab securityid if strpos(loannum, ".")
		* tab securityid if strpos(loannum, "-")
		* tab securityid if loannum=="1-001"
		
		* drop if strpos(loannum, "-")
		* drop if strpos(loannum, ".")
		
		* Generate the final loanid 
		replace loanid = loanid + "-" + yearid + "-" + loannum // ADDED the dash "-"
		
		// Labelling
		label var securityName "First Word of Security Name"
		label var yearid "Year ID"
		label var loanid "Loan ID"
		label var securityid "Security ID"
		label var loannum "Loan Number"
		
		* Sort by loanid and reporting period beginning date
		sort loanid beginDate
		
		*******************************************************************
		* Variable generation code 
		* Last copied: 02.01.20 @ 3:30 pm
		* Last edited: 02.02.20 @ 6:00 pm
				
			* Property state variable
			gen state = propertypropertystate
			label var state "Property State"
			
			* Dropping irrelevant states 
			* "-" is for one property in the Cayman Islands 
			* "NA" is for loans marked with letters, ex: "10A"
			drop if state=="CI" | state=="E9" | state=="FC" | state=="MX" | state=="VI" | state=="-" | state=="NA"
			
			encode state, gen(propertyState)
			label var propertyState "Property State (Stata Encoded)"
			
			* Drop any lettered loans 
			* These types of loans seem to be add-ons for other loans
			* These loans do not contain property data
			* Some other instances not handled can contain "S" or "R"
			* drop if strpos(loannum, "A") | strpos(loannum, "B") | strpos(loannum, "C") | ///
			* strpos(loannum, "D") | strpos(loannum, "E") | strpos(loannum, "F")
			
			* Minor property type fixes
			replace propertypropertytypecode="98" if propertypropertytypecode=="98.0"
			replace propertypropertytypecode="98" if propertypropertytypecode=="-"
			
			* Origination date variables
			gen origination = date(originationdate, "MDY")
			gen origQuarter = qofd(origination)
			gen origMonth   = ym(year(origination), month(origination))
			gen origYear    = year(origination)
			format origination %td 
			format origQuarter %tq
			format origMonth   %tm 
			label var origination "Origination Date"
			label var origQuarter "Origination Quarter"
			label var origMonth   "Origination Month"
			label var origYear    "Origination Year "
			
			* Maturity date variable 
			gen maturityDate  = date(maturitydate, "MDY")
			gen maturityMonth = ym(year(maturityDate), month(maturityDate))
			gen beginMonth    = ym(year(beginDate), month(beginDate))
			format maturityDate %td
			format maturityMonth beginMonth %tm
			
			* Destring variables 
			destring originalloanamount,               ignore("-")  gen(loan)    // Original loan amount 
			destring originalinterestratepercentage,   ignore("-")  gen(irate)   // Original interest rate
			destring reportperiodinterestratepercenta, ignore("-")  gen(rate)    // Current interest rate 
			destring originaltermloannumber,           ignore("-")  gen(term)    // Original loan term
			destring propertyvaluationsecuritizationa, ignore("-")  gen(pValue)  // Original property value
			destring propertydebtservicecoveragenetop, ignore("-")  gen(opRatio) // Operating income DSCR
			destring propertyrevenuesecuritizationamo, ignore("-")  gen(rev)     // Original revenue securitization
			destring propertydebtservicecoveragenetca, ignore("-")  gen(cfRatio) // Cash flow DSCR
			destring reportperiodbeginningscheduleloa, ignore("-")  gen(balance) // Current loan balance
			
			* Generate variables
			replace irate       = irate / 100 if irate > 1 
			replace rate        = rate  / 100 if rate  > 1
			replace irate       = irate * 100
			replace rate        = rate  * 100
			egen opDSCR         = max(opRatio), by(loanid)
			egen cfDSCR         = max(cfRatio), by(loanid)
			egen revenue        = max(rev),     by(loanid)
			egen propertyValue  = max(pValue),  by(loanid)
			gen  lnpValue       = ln(propertyValue)
			gen  lnloan         = ln(loan)
			gen  ltv            = (loan / propertyValue) * 100
			gen  remainingTerm  = maturityMonth - beginMonth
			* Labelling generated variables 
			label var irate         "Original Interest Rate"
			label var rate          "Current Interest Rate"
			label var term          "Original Loan Term"
			label var opDSCR        "Debt Service Coverage Ratio (by Net Operating Income)"
			label var cfDSCR        "Debt Service Coverage Ratio (by Net Cash Flow)"
			label var revenue       "Property Revenue Securitization"
			label var propertyValue "Property Value at Securitization"
			label var lnpValue      "Natural log of Property Value at Securitization"
			label var loan          "Original Loan Amount"
			label var lnloan        "Natural log of Original Loan Amount"
			label var ltv           "Original Loan-to-Value Ratio"
			label var remainingTerm "Loan Remaining Term"
				
			* Clean zip codes
			gen zip      = propertypropertyzip
			replace  zip = subinstr(zip, "-", "", .)
			replace  zip = subinstr(zip, ";", "", .)
			drop if  zip == "Various"
			replace  zip = substr(zip, 1, 5) if ustrlen(zip)>5 // this creates some problems 
			destring zip, replace
			replace  zip = . if zip == 99999
			label var zip "Property Zip Code (cleaned)"

			* Fill in any missing zips by loanid 
			sort loanid beginDate
			by loanid: replace zip = zip[_n-1] if zip==.
			sort loanid zip 
			by loanid: replace zip = zip[_n-1] if zip==.
			sort loanid beginDate
			
			* Most recent zip code variable 
			gen recentZip = zip
			label var recentZip "Property Zip Code (most recent)"
			
			**************************************************************************
			**************************************************************************
			* Sythetic Zip Variable 
			* Generate a variable that will be the most recent zip code for a loan. 
			sort loanid beginDate
			* Flag any zips that remain missing 
			replace recentZip=-77777 if recentZip==. // red flag marker for missing zips 
			* Identify the most recent loan observation 
			by loanid: gen zCounter = _n
			by loanid: egen maxCounter = max(zCounter)
			* Synthetic zip variable to be the most recent zip code by loanid 
			gen syntheticZip = .
			replace syntheticZip=zip if zCounter==maxCounter
			* Necessary sorting to position synthetic zip at top of each loanid 
			sort loanid syntheticZip
			* Fill in most recent zip for synthetic zip 
			by loanid: replace syntheticZip = syntheticZip[_n-1] if syntheticZip==.
			* Labelling 
			label var syntheticZip "Property Synthetic Zip Code"
			* Re-sort data back to normal format
			sort loanid beginDate 
			**************************************************************************
			**************************************************************************
			* Most recent property variable
			* Generate a variable that is the most recent property type by loanid
			* Identify most recent loan observation 
			by loanid: gen pCounter = _n
			by loanid: egen maxCount = max(pCounter)
			* Property type null value 
			gen  property = "ZZZ"
			* Identify most recent property type
			replace  property = propertypropertytype if pCounter==maxCount    ///
			& (propertypropertytype!="" | propertypropertytype!=" " | /// 
			propertypropertytype!="-" )
			* Sort to get most recent property as first observation by loanid 
			sort loanid property
			by loanid: replace property=property[_n-1] if property=="ZZZ"
			* Labelling 
			label var property "Synthetic Property Type"
			* Sort back to normal format 
			sort loanid beginDate
			**************************************************************************
			**************************************************************************
		
		* End of variable generation code 
		********************************************************************
		
		* Save Security Master File 
		cd "`path'/Fixed Income Research/CMBS Data/masters_CMBS/"
		save "master_`folder'", replace
}
	**********************************************************************
	* Create CMBS universe file

	* Append to generate universe file 
	clear all 
	cd "`path'/Fixed Income Research/CMBS Data/masters_CMBS/"
	local masterfiles : dir "." files "master*", respectcase
	append using `masterfiles'
	* Save CMBS universe file 
	cd "`path'/Fixed Income Research/CMBS Data/universe_CMBS/"
	* Universe file 
	* Change working date of the file here
	save "UNIVERSE_CMBS_07.dta", replace  // UNIVERSE NAME CHANGE HERE

**************************** End of program *********************************** 
*******************************************************************************
*******************************************************************************


cd "`path'/Fixed Income Research/CMBS Data/universe_CMBS/"
use "UNIVERSE_CMBS_07.dta", clear


