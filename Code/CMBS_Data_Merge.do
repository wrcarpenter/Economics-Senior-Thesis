 
 *******************************************************************************
* Author: William Carpenter
* Created:     8.01.20 
* Last Edited: 5.15.21 
* Description: Merge external data with CMBS loan-level file for analysis. 
*******************************************************************************

 	* WINDOWS (OLGA) 
	if "`c(os)'"=="Windows" {
		local path "H:"
	}
	
	* MAC
	if "`c(os)'"=="MacOSX" {
		local path "/Volumes/CARPENTERW"
	}
	
	cd "`path'/Fixed Income Research/CMBS Data/universe_CMBS/"
	use "UNIVERSE_CMBS_07.dta", clear

	sort loanid beginDate
	
	drop if ltv > 100
	
	by loanid: generate idobs = _n
	egen maxobs = max(idobs), by(loanid)
	drop if maxobs < 4
	
	drop if strpos(loannum, "N") | strpos(loannum, "-") | strpos(loannum, "A") | strpos(loannum, "B") | ///
	strpos(loannum, "C") | strpos(loannum, "S")
	
	destring propertymostrecentdebtservicecov, gen(recentOp) ignore("-")
	sort loanid beginDate
	by loanid: replace recentOp = recentOp[_n-1] if recentOp==. 
	by loanid: replace recentOp = opDSCR if recentOp==. & opDSCR!=0 & opDSCR!=.
	by loanid: replace recentOp = . if recentOp==0
	by loanid: replace recentOp = recentOp[_n-1] if recentOp==.
	by loanid: replace recentOp = opDSCR if recentOp==. 
	drop if recentOp==0
	label var recentOp "Most Recent DSCR"
	
	* Occupancy 
	destring propertyphysicaloccupancysecurit, gen(oc) ignore("-")
	replace oc=oc*100 if oc <= 1
	by loanid: egen occu = max(oc)
	destring propertymostrecentphysicaloccupa, gen(occupancyRecent) ignore("-")
	gen occupancy = occupancyRecent
	replace occupancy = . if occupancy==0
	replace occupancy = occupancy*100 if occupancy <= 1
	replace occupancy = 100 if occupancy < 1.05
	// br assetnumber beginDate occu occupancyRecent occupancy if occupancy==0
	sort loanid beginDate 
	by loanid: replace occupancy = occupancy[_n-1] if occupancy==.
	by loanid: replace occupancy = occu if occupancy==. & occu!=.
	drop if occupancy==0 | occupancy==.
	label var occupancy "Most Recent Occupancy"
	
	drop if beginDate < td(1jan2019) 
	
	by loanid: generate ids = _n
	egen maxids = max(ids), by(loanid)
	drop if maxids < 4

	
	//////////////////////////////////////////////////////////////////////
	
	
	* ZIPS-to-COUNTIES
	merge m:1 syntheticZip using "`path'/Fixed Income Research/Tracker/uspsMappingZips.dta", ///
	keepusing(countyFips countyname stateabbrev)
	drop if _merge==2
	drop _merge
		
	* UNEMPLOYMENT
	merge m:1 countyFips modate using "`path'/Fixed Income Research/Tracker/countyUnemployment.dta", ///
	keepusing(unemployment)
	drop if _merge==2
	drop if _merge==1
	drop _merge
	// label var ue           "Unemployment Rate (Monthly)"
	label var unemployment "Unemployment"
		
	* MOBILITY
	merge m:1 countyFips date using "`path'/Fixed Income Research/Tracker/Trips_by_Distance.dta", ///
	keepusing(atHome trips trips5 trips10 trips25 mobility)
	drop if _merge==2
	drop _merge
	label var atHome   "Population at Home (\%)"
	label var trips    "Trips per Capita"
	label var trips5   "Trips per Capita (>= 5 miles)"
	label var trips10  "Trips per Capita (>= 10 miles)"
	label var trips25  "Trips per Capita (>= 25 miles)"
	label var mobility "Mobility"
		
	* Business Exposure
	merge m:1 countyFips using "`path'/Fixed Income Research/Tracker/businessCounts.dta", ///
	keepusing(exposureRetail exposureLeisure exposureManufacturing exposureHotel)
	drop if _merge==2
	drop _merge
	
    * PPP
	merge m:1 countyFips date using "`path'/Fixed Income Research/Tracker/PPP_Master_County_Daily.dta", ///
	keepusing(pppFunds pppLoans pppPayroll pppJobs ln_pppFunds ln_pppPayroll)
	label var pppFunds "PPP Funding Coverage"
	label var pppLoans "PPP Loan Coverage"
	label var pppJobs  "PPP Employment Coverage"
	label var ln_pppFunds "PPP Funding Coverage"
	label var ln_pppPayroll "PPP Payroll Coverage"
		
	replace pppFunds     = 0 if pppFunds==.
	replace pppLoans     = 0 if pppLoans==.
	replace pppPayroll   = 0 if pppPayroll==. 
	replace pppJobs      = 0 if pppJobs==.
	replace ln_pppFunds   = 0 if ln_pppFunds==.
	replace ln_pppPayroll = 0 if ln_pppPayroll==.
	
	drop if _merge==2
	drop _merge
	
	* EIDL
	merge m:1 countyFips date using "`path'/Fixed Income Research/Tracker/EIDL_Master_County_Daily.dta", ///
	keepusing(eidlFunds eidlLoans ln_eidlFunds)
	label var eidlFunds "EIDL Funding Coverage"
	label var eidlLoans "EIDL Loan Coverage"
	label var ln_eidlFunds "EIDL Funding Coverage"
	
	replace eidlFunds = 0 if eidlFunds==.
	replace ln_eidlFunds = 0 if ln_eidlFunds==.
	replace eidlLoans = 0 if eidlLoans==.
	
	drop if _merge==2
	drop _merge
	
	drop if securityid=="JPMDB-2017-C5" & fileDate=="2021.03.30"

	* Declare panel data structure
	encode loanid, gen(id)
	xtset id modate


	* Panel data date debugging 
// 	sort loanid date 
// 	by loanid: gen numy = _n 
// 	gen flag = 0 
// 	by loanid: replace flag = 1 if date==date[_n-1] & numy!=1
	
	
	
	
	
