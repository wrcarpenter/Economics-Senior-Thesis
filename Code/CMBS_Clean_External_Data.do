
*******************************************************************************
* Author: William Carpenter
* Created:     8.01.20 
* Last Edited: 5.15.21 
* Description: Organize external data to be merged with CMBS data file. 
*******************************************************************************

*************************************************************************
* Determine operating system and set current directory
	
	* WINDOWS (OLGA) 
	if "`c(os)'"=="Windows" {
		local path "E:/"
	}
	* MAC
	if "`c(os)'"=="MacOSX" {
		local path "/Volumes/CARPENTERW"
	}
	
*******************************************************************************
*  Fips County Codes   
*******************************************************************************
	
	* County fips codes from Chetty et al. (2020)
	* 3.142 counties covered total
	import delimited "`path'/Fixed Income Research/Tracker/GeoIDs - County.csv", ///
	clear stringcols(_all) varnames(1)
	* County fips codes 
	gen countyFips = countyfips
	destring countyFips, replace
	* Save Tracker county code file 
	save "`path'/Fixed Income Research/Tracker/countyIDs.dta", replace

*******************************************************************************
* Zips to County Codes  
*******************************************************************************
	// ***Correct this .csv to make new zips with counties 
	// ***Add new counties 
	import delimited "`path'/Fixed Income Research/Tracker/counties.csv", ///
	clear stringcols(_all) varnames(1)
	
	drop if zcta5=="99999"
	destring pop10, replace

	// Organize data 
	gen countyName = cntyname
	replace countyName = substr(countyName, 1, length(countyName)-3)
	gen zip = zcta5
	destring zip, replace
	// Absorb duplicate zip codes in data by relative population size 
	sort zip
	by zip: gen idobs=_n
	by zip: egen maxObs = max(idobs)
	by zip: egen maxPop = max(pop10)
	drop if maxPop!=pop10
	
	* Synthetic zip variable for merging 
	gen syntheticZip = zip

	// Generate County-fips codes 
	gen countyFips = county
	destring countyFips, replace

	// Merge in county codes from Tracker (for accurate mapping)
	merge m:1 countyFips using "`path'/Fixed Income Research/Tracker/countyIDs.dta", ///
	keepusing(countyname stateabbrev)
	drop if _merge==2 // 6 counties not used from the Tracker codes
	rename _merge mergeCounties
	// Save master county/zip mapper 
	// 33,432 unique zips covered 
	save "`path'/Fixed Income Research/Tracker/countiesZips.dta", replace

	// Evaluate the impact of zip absorbtion
	// gen frac = pop10 / maxPop if maxObs>1
	// sum frac if frac!=1, detail // median difference is about 7.3%
	// drop frac
	// by zip: egen mp = min(pop10) if maxObs>1
	// gen fraction = mp /  if min

*******************************************************************************
* Zips to County Codes  
*******************************************************************************
	
	import delimited "`path'/Fixed Income Research/Tracker/ZIP_COUNTY_122020.csv", ///
	clear  varnames(1)
	
	sort zip 
	by zip: gen obs = _N
	by zip: egen largest = max(tot_ratio) if obs>1
	drop if tot_ratio!=largest & obs>1
	
	gen syntheticZip = zip 
	gen countyFips   = county
	merge m:1 countyFips using "`path'/Fixed Income Research/Tracker/countyIDs.dta", ///
	keepusing(countyname stateabbrev county_pop2019)
	drop if _merge==2
	
	sort zip
	by zip: gen cnt = _N
	drop if cnt>1
	
	save "`path'/Fixed Income Research/Tracker/uspsMappingZips.dta", replace 
	

*******************************************************************************
* National Unemployment Rates
*******************************************************************************	
	
	* Cleaning this data to use for generating figures only
	import delimited "`path'/Fixed Income Research/Tracker/UNRATE.csv", clear
	rename date Date 
	gen date = date(Date, "MDY")
	gen modate   = ym(year(date), month(date))
	gen nationalUe = unrate
	
	save "`path'/Fixed Income Research/Tracker/UNRATE.dta", replace
	
*******************************************************************************
* Mobility
*******************************************************************************

	import delimited "`path'/Fixed Income Research/Tracker/Trips_by_Distance.csv", clear 
	drop if level=="National" | level=="State"
	rename date Date
	gen date   = date(Date, "YMD")
	gen county = countyname
	drop countyname
	format date %td
	gen countyFips = countyfips
	sort countyFips date
	
	merge m:1 countyFips using "`path'/Fixed Income Research/Tracker/countyIDs.dta", ///
	keepusing(countyname stateabbrev county_pop2019)
	drop if _merge==2

	gen pop = populationstayingathome + populationnotstayingathome
	destring county_pop2019, gen(countyPop)

	* Generate relevant variables for people at home and trips taken per capita
	
	* Population away from home 
	gen countyMobility = populationnotstayingathome / countyPop * 100
	* Population at home 
	gen countyHome    = populationstayingathome / countyPop * 100
	
	* Any trip with a stay of at least 10 minutes 
	gen countyTrips    = numberoftrips / countyPop 
	
	* >= 5 miles 
	gen countyTrips5 = (numberoftrips510    + ///
	              numberoftrips1025   + ///
				  numberoftrips2550   + ///
				  numberoftrips50100  + ///
				  numberoftrips100250 + ///
				  numberoftrips250500 + ///
				  numberoftrips500)     ///
				  / countyPop
	* >= 10 miles  
	gen countyTrips10 = (numberoftrips1025  + ///
				  numberoftrips2550   + ///
				  numberoftrips50100  + ///
				  numberoftrips100250 + ///
				  numberoftrips250500 + ///
				  numberoftrips500)     ///
				  / countyPop
	
	* >= 25 miles	
    gen countyTrips25 = (numberoftrips2550  + ///
				  numberoftrips50100  + ///
				  numberoftrips100250 + ///
				  numberoftrips250500 + ///
				  numberoftrips500)     ///
				  / countyPop
	
	
	* Month-date variable
	gen    modate = ym(year(date), month(date))
	format modate %tm

	* Sorting 
	sort countyFips date modate
	sort countyFips modate

	* Testing dates for gaps 
	* by countyFips: gen num = _n
	* by countyFips: gen dateTest = Date - Date[_n-1] if num!=1

	* 30-day moving averages 
	xtset countyFips date
	egen mobility    = filter(countyMobility), lags(0/29) normalise
	egen atHome      = filter(countyHome),     lags(0/29) normalise
	egen trips       = filter(countyTrips),    lags(0/29) normalise
	egen trips5      = filter(countyTrips5),   lags(0/29) normalise
	egen trips10     = filter(countyTrips10),  lags(0/29) normalise
	egen trips25     = filter(countyTrips25),  lags(0/29) normalise
	
	egen homeFiller     = filter(countyHome)       if atHome==.,   lags(0/6) normalise	
	egen mobilityFiller = filter(countyMobility)   if mobility==., lags(0/6) normalise
	egen tripsFiller    = filter(countyTrips)      if trips==.,    lags(0/6) normalise
	egen trips5Filler   = filter(countyTrips5)     if trips5==.,   lags(0/6) normalise
	egen trips10Filler  = filter(countyTrips10)    if trips10==.,  lags(0/6) normalise
	egen trips25Filler  = filter(countyTrips25)    if trips25==.,  lags(0/6) normalise
	
	replace atHome   = homeFiller      if atHome==.
	replace mobility = mobilityFiller  if mobility==.
    replace trips    = tripsFiller     if trips==.
	replace trips5   = trips5Filler    if trips5==.
	replace trips10  = trips10Filler   if trips10==.
	replace trips25  = trips25Filler   if trips25==.
	
	replace trips25  = trips25*100
	
	* Labeling  
	label var trips       "Trips per Capita" 
	label var trips5      "Trips per Capita (>=5 miles)"
	label var trips10     "Trips per Capita (>=10 miles)"
	label var trips25     "Trips per Capita (>=25 miles)"
	label var mobility    "Mobility"
	label var atHome      "Population at Home"

	save "`path'/Fixed Income Research/Tracker/Trips_by_Distance.dta", replace


*******************************************************************************
* CMBS County Unemployment
*******************************************************************************
	
    * Codes from LAUS database 
	// measure_code	measure_text
	// 03	unemployment rate
	// 04	unemployment
	// 05	employment
	// 06	labor force
	// 07	employment-population ratio
	// 08	labor force participation rate
	// 09	civilian noninstitutional population
		
	* Import once to avoid long run-time 
	import delimited "`path'/Fixed Income Research/Tracker/la.data.64.County.txt", clear delimiters(" ")
	save "`path'/Fixed Income Research/Tracker/la.data.64.County.dta", replace 
	
	* Raw DTA file 
	use "`path'/Fixed Income Research/Tracker/la.data.64.County.dta", clear
	
	rename v11 dateString
	gen countyFips = substr(series_id, 6, 5)
	gen measure    = substr(series_id, -1, 2)
	destring countyFips, replace

	// Drop data older than 2015
	gen year = substr(dateString, 2, 4)
	destring year, replace
	drop if year < 2018 
	
	* Unemployment rates only 
	drop if measure!="3"

	gen month = substr(dateString, 7,3)
	// Drop annual average
	drop if month=="M13"

	gen m = substr(month, 2, 2)
	destring m, replace 

	gen modate = ym(year, m)
	format modate %tm

	rename v19 uer
	replace uer = v20 if uer==""
	* Creating unemployment variable
	gen ue = substr(uer, 1, 4)
	replace ue = subinstr(ue, " ", "",.)
	destring ue, replace
	* Dropping empty variables
	drop v2-v10
	drop v12-v18
	drop v21-v28
	drop v20
	sort countyFips modate
	* County-level merge 
	merge m:1 countyFips using "`path'/Fixed Income Research/Tracker/countyIDs.dta", ///
	keepusing(countyname stateabbrev)
	drop if _merge==2 // Kalawo, Hawaii 
	drop if _merge==1 // All Puerto Rico
	drop _merge
	* Sorting 
	sort countyFips modate
	**********************************************************************
	xtset countyFips modate
	by countyFips: gen extra = _n == _N
	expand 2 if extra == 1
	sort countyFips modate
	by countyFips: replace modate = modate[_n-1] + 1 if extra[_n-1]==1
	by countyFips: replace ue = . if extra[_n-1]==1
	***********************************************************************
	* Lagged unemployment (by one month)
	by countyFips: gen unemployment = ue[_n-1]
	* Save cleaned file 
	save "`path'/Fixed Income Research/Tracker/countyUnemployment.dta", replace

	use "`path'/Fixed Income Research/Tracker/countyUnemployment.dta", clear
	
	
///////////////////////////////////////////////////////////////////////////////
// Johns Hopkins COVID-19 by county
///////////////////////////////////////////////////////////////////////////////

	// Reshape Deaths file
	import delimited "`path'/Fixed Income Research/Tracker/johnsHopkinsDeaths.csv", clear 
	reshape long deaths, i(uid) j(date) string
	gen dateString = date
	drop date 
	gen date = date(dateString, "MDY") 
	format date %td
	sort fips date
	save "`path'/Fixed Income Research/Tracker/johnsHopkinsDeaths.dta", replace

	// Reshape Cases file 
	import delimited "`path'/Fixed Income Research/Tracker/johnsHopkinsCases.csv", clear 
	reshape long cases, i(uid) j(date) string
	gen dateString = date
	drop date 
	gen date = date(dateString, "MDY") 
	format date %td
	sort fips date
	save "`path'/Fixed Income Research/Tracker/johnsHopkinsCases.dta", replace

	// Generate death counts 
	* Current date : Jan 26th, 2021
	use "`path'/Fixed Income Research/Tracker/johnsHopkinsDeaths.dta", clear 
	
	* Clean data 
	drop if fips==.
	drop if iso2!="US"
	gen countyFips = fips 
	sort countyFips date
	by countyFips: gen num = _n
	
	* Change in daily total deaths 
	by countyFips: gen new_deaths = deaths - deaths[_n-1] 
	replace new_deaths = 0 if new_deaths < 0
	replace new_deaths = 0 if num==1 | new_deaths==.
	
	* Merge county-level 
	merge m:1 countyFips using "`path'/Fixed Income Research/Tracker/countyIDs.dta", ///
	keepusing(countyname stateabbrev county_pop2019)
	drop if _merge==1 | _merge==2
	drop _merge
	destring county_pop2019, replace

	gen newDeaths     = new_deaths / county_pop2019 * 100000

	gen modate = ym(year(date), month(date))
	format modate %tm
	sort countyFips date

	xtset countyFips date
	egen countyDeaths = filter(newDeaths), lags(0/29) normalise
	
	sort countyFips date
	gen fill      = newDeaths if countyDeaths==.
	
	by countyFips: gen sumation      = sum(fill) if fill!=.
	 
	gen movingAvg         = sumation / 30 if sumation!=.
	replace countyDeaths  = movingAvg if countyDeaths==.
	* Sort final data 
	sort countyFips date
	* Save file
	save "`path'/Fixed Income Research/Tracker/covidDeaths.dta", replace

	// Generate case counts 
	use "`path'/Fixed Income Research/Tracker/johnsHopkinsCases.dta", clear 
	drop if fips==.
	drop if iso2!="US"
	gen countyFips = fips 
	sort countyFips date
	by countyFips: gen num = _n
	by countyFips: gen new_cases = cases - cases[_n-1] 
	replace new_cases = 0 if new_cases < 0
	merge m:1 countyFips using "`path'/Fixed Income Research/Tracker/countyIDs.dta", ///
	keepusing(countyname stateabbrev county_pop2019)
	drop if _merge==1 | _merge==2
	drop _merge

	destring county_pop2019, replace
	gen newCases     = new_cases / county_pop2019 * 100000

	gen modate = ym(year(date), month(date))
	format modate %tm

	sort countyFips date	
	xtset countyFips date
	egen countyCases     = filter(newCases), lags(0/29) normalise
	
	sort countyFips date
	gen fill = newCases if countyCases==.
	by countyFips: gen sumation     = sum(fill) if fill!=.
	gen movingFill       = sumation / 30 if sumation!=.
	replace countyCases  = movingFill if countyCases==.

	sort countyFips date

	save "`path'/Fixed Income Research/Tracker/covidCases.dta", replace


// Raw with negatives
// 40,846    20.14302    36.26155  -552.7407    1595.84

// Adjusted for negatives 
// 40,846    20.39837    36.17153          0    1595.84


///////////////////////////////////////////////////////////////////////////////
// COVID-19 Testing 
///////////////////////////////////////////////////////////////////////////////

	// increases in test results on a daily basis --> control for testing rates 

	import delimited "`path'/Fixed Income Research/Tracker/all-states-history.csv", clear
	sort state date

	merge m:1 state using "`path'/Fixed Income Research/Tracker/geoIDs.dta", ///
	keepusing(statename state_pop2019 statefips)
	drop if _merge==2
	drop if _merge==1 // only dropping geographic areas outside of mainland 
	drop _merge

	gen newTests  = totaltestresultsincrease / state_pop2019 * 100000
	gen newDeaths = deathincrease            / state_pop2019 * 100000
	gen newCases  = positiveincrease         / state_pop2019 * 100000
	
	rename date dateString
	gen date   = date(dateString, "YMD")
	gen modate = ym(year(date), month(date))
	format date   %td
	format modate %tm
	
	* Testing dates for gaps
// 	sort statefips date
// 	by statefips: gen num = _n
// 	by statefips: gen dateTest = date - date[_n-1] if num!=1

	sort statefips date
	xtset statefips date
	egen stateTests = filter(newTests), lags(0/29) normalise
	egen stateDeaths = filter(newDeaths), lags(0/29) normalise 
	egen stateCases  = filter(newCases), lags(0/29) normalise
	
	* Testing Fill
	sort statefips date
	gen fill = newTests if stateTests==.
	by statefips: gen fillSum   = sum(fill) if fill!=.
	by statefips: gen movingAvg = fillSum / 30 if fillSum!=.
	replace stateTests = movingAvg if stateTests==. 
	
	* Cases Fill 
	drop fill fillSum movingAvg
	sort statefips date 
	gen fill = newCases if stateCases==.
	by statefips: gen fillSum = sum(fill) if fill!=.
	by statefips: gen movingAvg = fillSum / 30 if fillSum!=. 
	replace stateCases = movingAvg if stateCases==.
	
	* Deaths Fill 
	drop fill fillSum movingAvg
	sort statefips date 
	gen fill = newDeaths if stateDeaths==.
	by statefips: gen fillSum = sum(fill) if fill!=.
	by statefips: gen movingAvg = fillSum / 30 if fillSum!=. 
	replace stateDeaths = movingAvg if stateDeaths==.

	save "`path'/Fixed Income Research/Tracker/stateTesting.dta", replace
	
	
///////////////////////////////////////////////////////////////////////////////
// QCEW 2020 Q1(Business Counts) 
///////////////////////////////////////////////////////////////////////////////	
	
	import delimited "`path'/Fixed Income Research/Tracker/allhlcn201.csv", clear varnames(1)
	
	gen businessTotal = establishmentcount
	replace businessTotal = subinstr(businessTotal, ",", "",.)
	destring businessTotal, replace
	drop if own!=5
	drop if naics!=10
	
	* Cleaning out any undefined counties or state/MSA rows
	drop if areatype!="County"
	drop if cnty==999
	
	destring code, gen(countyFips)
	
	merge m:1 countyFips using "`path'/Fixed Income Research/Tracker/countyIDs.dta", ///
	keepusing(countyname stateabbrev county_pop2019)
	drop if _merge==1 | _merge==2
	drop _merge
	
	save "`path'/Fixed Income Research/Tracker/businessTotals2020.dta", replace


	
///////////////////////////////////////////////////////////////////////////////
// QCEW 2019 Averages (Business Counts and Industry Exposure) 
///////////////////////////////////////////////////////////////////////////////	

	import delimited "`path'/Fixed Income Research/Tracker/2019.q1-q4.singlefile.csv", clear varnames(1)
	save "`path'/Fixed Income Research/Tracker/qcew2019_Quarter_1.dta"
	
// 	import delimited "`path'/Fixed Income Research/Tracker/2019.annual.singlefile.csv", clear varnames(1)
// 	save "`path'/Fixed Income Research/Tracker/qcew2019.dta", replace
	
	* Business counts and industry exposures 
	use "`path'/Fixed Income Research/Tracker/qcew2019_Quarter_1.dta", clear 
	drop if strpos(area_fips, "C")
	drop if strpos(area_fips, "US")
	destring area_fips, gen(countyFips)
	
	merge m:1 countyFips using "`path'/Fixed Income Research/Tracker/countyIDs.dta", ///
	keepusing(countyname stateabbrev county_pop2019)
	drop if _merge==1 | _merge==2
	drop _merge
	
	* Private businesses 
	drop if own_code!=5

	* Total business count and targeted industries 
	drop if industry_code!="10"    & ///  
			industry_code!="44-45" & ///  
			industry_code!="1013"  & ///  
			industry_code!="1024"  & /// 
			industry_code!="1023"  & ///   
			industry_code!="1026"  & ///  
			industry_code!="72111" & ///  
			industry_code!="72112" & ///
			industry_code!="31-33"
	
	drop if qtr!=1
	
	sort countyFips
	gen businessCount         = qtrly_estabs if industry_code=="10" 
	by countyFips: egen temp  = max(businessCount)
	replace businessCount     = temp if businessCount==.
	drop temp
	
	gen retailCount           = qtrly_estabs if industry_code=="44-45"
	by countyFips: egen temp  = max(retailCount)
	replace retailCount       = temp if retailCount==.
	drop temp
	
	gen leisureCount          = qtrly_estabs if industry_code=="1026"
	by countyFips: egen temp  = max(leisureCount)
	replace leisureCount      = temp if leisureCount==.
	drop temp
	
	gen manufacturingCount     = qtrly_estabs if industry_code=="1013"
	by countyFips: egen temp   = max(manufacturingCount)
	replace manufacturingCount = temp if manufacturingCount==.
	drop temp
	
	gen hotelCount           = qtrly_estabs if industry_code=="72111" | industry_code=="72112"
	by countyFips: egen temp = sum(hotelCount)
	replace hotelCount       = temp if hotelCount==.
	drop temp 
	
	gen exposureRetail        = retailCount        / businessCount 
	gen exposureLeisure       = leisureCount       / businessCount
	gen exposureManufacturing = manufacturingCount / businessCount
	gen exposureHotel         = hotelCount         / businessCount

	* Compress the data 
	sort countyFips
	by countyFips: gen obs    = _n 
	drop if obs!=1
	
	save "`path'/Fixed Income Research/Tracker/businessCounts.dta", replace
	
///////////////////////////////////////////////////////////////////////////////
// LAUS 2019 Average Labor Force 
///////////////////////////////////////////////////////////////////////////////		
	
	import delimited "`path'/Fixed Income Research/Tracker/laucnty19.csv", clear stringcols(_all)
	
	rename countyname countyNameString
	gen countyFips = statecode + countycode
	destring countyFips, replace
	
	merge m:1 countyFips using "`path'/Fixed Income Research/Tracker/countyIDs.dta", ///
	keepusing(countyname stateabbrev county_pop2019)
	drop if _merge==1 | _merge==2
	drop _merge
	
	gen laborForce = subinstr(laborforce, ",", "", .)
	destring laborForce, replace
	
	save "`path'/Fixed Income Research/Tracker/laborForce.dta", replace 
	

///////////////////////////////////////////////////////////////////////////////
// PPP Data File (COUNTY-LEVEL)
///////////////////////////////////////////////////////////////////////////////

	 * Large raw PPP dataset 
	 use "C:\Users\wrc4\Desktop\PPP Data\PPP_MASTER.dta", clear
	 
	 * Drop irrelevant states 
	 drop if borrowerstate=="AS" | borrowerstate=="AE" | borrowerstate=="FI" | ///
	         borrowerstate=="MP" | borrowerstate=="VI" | borrowerstate=="GU" | ///
			 borrowerstate=="GU" | borrowerstate=="PR"
	 
	 * Loan approval date 
	 gen date   = date(dateapproved, "MDY")
	 gen modate = ym(year(date), month(date))
	 format modate %tm
	 format date   %td
	 
	 * Zip codes 
	 gen zip  = borrowerzip
	 replace zip = substr(zip, 1, strpos(zip, "-") - 1) if strpos(zip, "-")
	 destring zip, replace
	 drop if zip==.                     // only 197 zips missing 

	 
	 destring payroll_proceed,       gen(payroll)
	 destring jobsreported,          gen(jobs)
	 destring currentapprovalamount, gen(loan)
	 destring initialapprovalamount, gen(initialLoan)
	 
	 replace jobs = jobs * -1 if jobs<0   // 1 loan changed 
	 * drop if jobs == 0                  // 200 loans dropped
	 * drop if jobs == .
	 
	merge m:1 zip using "`path'/Fixed Income Research/Tracker/uspsMappingZips.dta", ///
	keepusing(countyFips countyname stateabbrev)
	drop if _merge==2
	drop if _merge==1 // 2,080 loans missed 
	drop _merge
	 	
	merge m:1 countyFips using "`path'/Fixed Income Research/Tracker/laborForce.dta", ///
	keepusing(laborForce)
	drop if _merge==2 
	drop if _merge==1
	drop _merge
	
	merge m:1 countyFips using "`path'/Fixed Income Research/Tracker/businessTotals2020.dta", ///
	keepusing(businessTotal)
	drop if _merge==2 | _merge==1
	drop _merge
	
	sort countyFips date 
	by countyFips date: gen obs           = _n
	by countyFips date: gen numberLoans   = _N
	by countyFips date: egen totalFunds   = total(loan)
	by countyFips date: egen totalJobs    = total(jobs)
	by countyFips date: egen totalPayroll = total(payroll)
	* Compress data by day 
	drop if obs!=1
	
	xtset countyFips date 
	tsfill, full
	* drop if date>td(15oct2020)
	
	by countyFips: egen businesses = max(businessTotal)
	by countyFips: egen laborforce = max(laborForce)
	
	sort countyFips date
	by countyFips: gen cumulativeFunds   = sum(totalFunds)
	by countyFips: gen cumulativeLoans   = sum(numberLoans)
	by countyFips: gen cumulativePayroll = sum(totalPayroll)
	by countyFips: gen cumulativeJobs    = sum(totalJobs)
	
	gen pppFunds   = cumulativeFunds   / businesses
	gen pppPayroll = cumulativePayroll / laborforce
	gen pppLoans   = cumulativeLoans   / businesses * 100
	gen pppJobs    = cumulativeJobs    / laborforce * 100
	
	replace pppFunds   = pppFunds + 1 
	replace pppPayroll = pppPayroll + 1
	
	gen ln_pppFunds   = ln(pppFunds)
	gen ln_pppPayroll = ln(pppPayroll)
	 
	save "`path'/Fixed Income Research/Tracker/PPP_Master_County_Daily.dta", replace
	
	
///////////////////////////////////////////////////////////////////////////////
// EIDL Data File (COUNTY-LEVEL)
///////////////////////////////////////////////////////////////////////////////
	
	* Large raw PPP dataset 
	use "C:\Users\wrc4\Desktop\EIDL Data\EIDL_MASTER.dta", clear
	
	drop awarddesc
	drop if v46=="NON" // 3 erroneously shifted observations 
	drop v46
	
	// drop non-relevant geographic locations 
	drop if legalentitystatecd=="AS"
	drop if legalentitystatecd=="GU"
	drop if legalentitystatecd=="MP"
	drop if legalentitystatecd=="VI"
	drop if legalentitystatecd=="PR"

	gen date = date(actiondate, "YMD")
	gen modate = ym(year(date), month(date))
	format date %td
	format modate %tm 
	
	// Force missing values onto non-numerical zip codes (states, etc.)
	destring legalentityzip5, gen(zip) force
	// drop missing zips
	drop if zip==.  // only 147 observations lost
	sort date zip
	
	destring facevalueofdirectloanorloanguara, gen(loan)
	replace loan = loan * -1 if loan < 0
	
	merge m:1 zip using "`path'/Fixed Income Research/Tracker/uspsMappingZips.dta", ///
	keepusing(countyFips countyname stateabbrev)
	drop if _merge==2
	drop if _merge==1 // 256 loans missed 
	drop _merge
	
	merge m:1 countyFips using "`path'/Fixed Income Research/Tracker/businessTotals2020.dta", ///
	keepusing(businessTotal)
	drop if _merge==2 | _merge==1
	drop _merge

	
	sort countyFips date 
	by countyFips date: gen obs           = _n
	by countyFips date: gen numberLoans     = _N
	by countyFips date: egen totalFunds   = total(loan)
	drop if obs!=1
	
	xtset countyFips date 
	tsfill, full
	
	xtset countyFips date
	by countyFips: gen extra = _n == _N
	expand 150 if extra == 1
	sort countyFips date
	by countyFips: replace date = date[_n-1] + 1 if extra[_n-1]==1
	
	by countyFips: egen businesses = max(businessTotal)
	
	by countyFips: gen cumulativeFunds   = sum(totalFunds)
	by countyFips: gen cumulativeLoans   = sum(numberLoans)
		
	gen eidlFunds = cumulativeFunds / businesses
	gen eidlLoans = cumulativeLoans / businesses * 100
	
	replace eidlFunds = eidlFunds + 1
	gen ln_eidlFunds = ln(eidlFunds)
	
	save "`path'/Fixed Income Research/Tracker/EIDL_Master_County_Daily.dta", replace
	

///////////////////////////////////////////////////////////////////////////////
// EIDL Advance Data (COUNTY-LEVEL)
///////////////////////////////////////////////////////////////////////////////	
	
	* Large raw PPP dataset 
	use "C:\Users\wrc4\Desktop\EIDL Advance Data\EIDL_ADVANCE_MASTER.dta", clear
	
	drop if legalentitystatecd=="AS"
	drop if legalentitystatecd=="GU"
	drop if legalentitystatecd=="MP"
	drop if legalentitystatecd=="VI"
	drop if legalentitystatecd=="PR"
	
	gen date = date(actiondate, "YMD")
	gen modate = ym(year(date), month(date))
	format date %td
	format modate %tm 
	
	// Force missing values onto non-numerical zip codes (states, etc.)
	destring legalentityzip5, gen(zip) force
	// drop missing zips
	drop if zip==.  // only 1 observations lost
	sort date zip
	
	destring federalactionobligation, gen(grant)
	replace grant = grant * -1 if grant < 0
	
	gen jobs = grant / 1000 
	replace jobs = ceil(jobs)
	
	merge m:1 zip using "`path'/Fixed Income Research/Tracker/uspsMappingZips.dta", ///
	keepusing(countyFips countyname stateabbrev)
	drop if _merge==2
	drop if _merge==1 // 1,056 loans missed 
	drop _merge
	
	merge m:1 countyFips using "`path'/Fixed Income Research/Tracker/laborForce.dta", ///
	keepusing(laborForce)
	drop if _merge==2 
	drop if _merge==1
	drop _merge
	
	sort countyFips date 
	by countyFips date: gen obs           = _n
	by countyFips date: egen totalJobs    = total(jobs)
	drop if obs!=1
	
	xtset countyFips date 
	tsfill, full
	
	xtset countyFips date
	by countyFips: gen extra = _n == _N
	expand 150 if extra == 1
	sort countyFips date
	by countyFips: replace date = date[_n-1] + 1 if extra[_n-1]==1
	
	by countyFips: egen laborforce    = max(laborForce)
	by countyFips: gen cumulativeJobs = sum(totalJobs)
	

	gen eidlJobs = cumulativeJobs / laborforce * 100
	
 
	save "`path'/Fixed Income Research/Tracker/EIDL_Advance_Master_County_Daily.dta", replace
	
	
	
	
