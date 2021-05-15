*******************************************************************************
*******************************************************************************
// COMMERCIAL MORTGAGE DISTRESS DURING COVID-19: 
// EVIDENCE FROM LOAN-LEVEL DATA                 
*******************************************************************************
* Author: W. Carpenter 
* Date Created: 7.28.20
* Last Edited: 05.05.21

* Description: Analyzing loan-level data for commercial mortgage-backed 
* securities (CMBS). Data is acquired from ABS-EE filings. The focus is on
* determining the impact of COVID-19 factors on delinquency rates.   

*******************************************************************************

	
	* Upload dataset 
	clear all
	set more off 
	cls	
	
 	* WINDOWS (OLGA) 
	if "`c(os)'"=="Windows" {
		local path "E:/"
	}
	* MAC
	if "`c(os)'"=="MacOSX" {
		local path "/Volumes/CARPENTERW"
	}

    cd "`path'/Fixed Income Research/CMBS Data/universe_CMBS/"
    use "UNIVERSE_CMBS_07.dta", clear
	
	* sort dataset 
	sort loanid beginDate

	* Generate various date variables
	gen figureBeginDate = mdy(month(beginDate), 15, year(beginDate))
	gen figureEndDate = mdy(month(endDate), 15, year(endDate))
	gen figureEndMonth = ym(year(endDate), month(endDate))
	format figureBeginDate figureEndDate %td
	format figureEndMonth %tm
	
*******************************************************************************
	
	* Encoding property type 
	encode property, gen(ptype)
	
	* Determine year of securitization for summary statistics only 
	gen securitizationYear = substr(yearid, 1, 4)
	destring securitizationYear, replace
	label var securitizationYear "Securitization Year" 
	
	* Defining CMBS delinquency by thresholds given in data 
	gen delinquency     = 0
	replace delinquency = 1  if paymentstatusloancode=="B"
	replace delinquency = 30 if paymentstatusloancode=="1"
	replace delinquency = 60 if paymentstatusloancode=="2"
	replace delinquency = 90 if paymentstatusloancode=="3"

	* Main binary delinquency variables 
	gen byte late     = (delinquency==1)
	gen byte distress = (delinquency>=30)
	gen byte thirty   = (delinquency==30)
	gen byte sixty    = (delinquency==60)
	gen byte default  = (delinquency>=60)
	gen byte ninety   = (delinquency==90)
	
	* Property type markers 
	* Define property markers based on synthetic property type 
	gen retail             = (property=="RT")
	gen lodging            = (property=="LO")
	gen multifamily        = (property=="MF")
	gen industrial         = (property=="IN")
	gen office             = (property=="OF")
	gen cooperativehousing = (property=="CH")
	gen selfstorage        = (property=="SS")
	gen warehouse          = (property=="WH")
	gen mobilehome         = (property=="MH")
	gen mixeduse           = (property=="MU")
	gen healthcare         = (property=="HC")
	gen securities         = (property=="SE")
	gen othertype          = (property=="98")
    							 
	* Browse loans with special servicing events 
	// 	sort loanid beginDate
	// 	gen specialService = (mostrecentspecialservicertransfe!="-" & mostrecentspecialservicertransfe!="")
	// 	by loanid: egen specMarker = max(specialService)
	// 	br loanid assetnumber reportingperiodbeginningdate reportingperiodenddate ///
	// 	mostrecentspecialservicertransfe mostrecentmasterservicerreturnda special paymentstatusloancode /// 
	// 	if specMarker==1
	
	* Evaluate special service date mismatches 
	// 	gen flag = 0
	// 	replace flag = 1 if beginSpec > endSpec & beginSpec!=. & endSpec!=.
	// 	by loanid: egen m = max(flag)
	// 	br loanid assetnumber reportingperiodbeginningdate reportingperiodenddate transfer return if m == 1
	
	sort loanid beginDate
	* Special Servicing variable
	gen beginSpec = date(mostrecentspecialservicertransfe, "MDY")
	gen endSpec   = date(mostrecentmasterservicerreturnda, "MDY")
	* Fill in subsequent cells with most recent special service information
	by loanid: replace beginSpec = beginSpec[_n-1] if beginSpec==.
	by loanid: replace endSpec   = endSpec[_n-1] if endSpec==.
	format beginSpec endSpec %td
	replace endSpec = . if beginSpec > endSpec & beginSpec!=. & endSpec!=.
	* Infinitely large data to replace missing values 
	replace beginSpec = td(01jan2050) if beginSpec==.
	replace endSpec = td(01jan2050) if endSpec==.
	gen special = (beginSpec <= endDate & endSpec >= beginDate)
	label var special "Loan in Special Service"
	
	sort loanid beginDate
	by loanid: gen newThirty = 0 
	by loanid: replace newThirty = 1 if delinquency==30 & (delinquency[_n-1]==1 | ///
	delinquency[_n-1]==0)
	
	by loanid: gen newSixty = 0 
	by loanid: replace newSixty = 1 if delinquency==60 & (delinquency[_n-1]==30 | ///
	delinquency[_n-1]==0 | delinquency[_n-1]==1)
	
	by loanid: gen newNinety = 0
	by loanid: replace newNinety = 1 if delinquency==90 & (delinquency[_n-1]==60 | /// 
	delinquency[_n-1]==30 | delinquency[_n-1]==1 | delinquency[_n-1]==0)
	
	by loanid: gen newLate = 0 
	by loanid: replace newLate = 1 if delinquency==1 & delinquency[_n-1]==0

	* Delinquency transition variable 
	gen transition = (newNinety==1 | newSixty==1 | newThirty==1 | newLate==1)

	// NOTE THIS CLEANING
	drop if ltv==0 | ltv==.       // no drops 
	* drop if opDSCR==. | opDSCR==0 // 3 securities are lost...!

	gen covid = (beginDate > td(01apr2020))
	label var covid "COVID-19 Period"
	
*******************************************************************************
	* Labelling variables 
	label var unemployment  "Unemployment"
	label var opDSCR        "DSCR"
	label var remainingTerm "Remaining Term"
	label var atHome        "Population at Home"
	label var trips25       "Trips per Capita"

*******************************************************************************
	* Regressions
	drop if property=="HC" | property=="SE" | property=="98" | property=="CH" | property=="SS" | property=="MH"
		
	gen covid_unemployment = covid * unemployment
	gen covid_atHome       = covid * atHome
    gen covid_mobility     = covid * mobility	
	gen covid_trips        = covid * trips 
	gen covid_trips5       = covid * trips5
	gen covid_trips10      = covid * trips10
	gen covid_trips25      = covid * trips25
	
	gen covid_leisure       = covid * exposureLeisure
	gen covid_retail        = covid * exposureRetail
	gen covid_manufacturing = covid * exposureManufacturing
	gen covid_hotel         = covid * exposureHotel
	
	label var covid_leisure "Leisure \& Hospitality Exposure"

		
	label var trips25        "Mobility" 
	label var covid_trips25  "Mobility $\times$ COVID"
	label var covid_mobility "Mobility $\times$ COVID"
	
	cd "`path'/Fixed Income Research/CMBS Data/CMBS Latex/"
	
	****************************************************************************
	****************************************************************************
	local regressors  ///
	ln_pppFunds pppLoans ln_eidlFunds eidlLoans covid_trips25 trips25 unemployment
               
	****************************************************************************
	eststo clear
	cd "`path'/Fixed Income Research/CMBS Data/CMBS Latex/"
	
	eststo: reghdfe distress `regressors', a(modate id) cluster(id)
	estadd local ptype    = "All"
	estadd local clusters = e(N_clust)
	estadd local time     = "Yes"
	
	local regressors  ///
	ln_pppFunds pppLoans ln_eidlFunds eidlLoans covid_trips25 trips25 unemployment remainingTerm recentOp occupancy
	
	eststo: reghdfe distress `regressors', a(modate id) cluster(id)
	estadd local ptype    = "All"
	estadd local clusters = e(N_clust)
	estadd local time     = "Yes"
	
	****************************************************************************
	
	local regressors  ///
	ln_pppFunds pppLoans ln_eidlFunds eidlLoans covid_trips25 trips25 unemployment
	
	eststo: reghdfe special `regressors', a(modate id) cluster(id)
	estadd local ptype    = "All"
	estadd local clusters = e(N_clust)
	estadd local time     = "Yes"
	
	local regressors  ///
	ln_pppFunds pppLoans ln_eidlFunds eidlLoans covid_trips25 trips25 unemployment remainingTerm recentOp occupancy
	
	eststo: reghdfe special `regressors', a(modate id) cluster(id)
	estadd local ptype    = "All"
	estadd local clusters = e(N_clust)
	estadd local time     = "Yes"
	
	****************************************************************************
	
	local regressors  ///
	ln_pppFunds pppLoans ln_eidlFunds eidlLoans covid_trips25 trips25 unemployment
	
	eststo: reghdfe transition `regressors', a(modate id) cluster(id)
	estadd local ptype    = "All"
	estadd local clusters = e(N_clust)
	estadd local time     = "Yes"
	
	local regressors  ///
	ln_pppFunds pppLoans ln_eidlFunds eidlLoans covid_trips25 trips25 unemployment remainingTerm recentOp occupancy
	
	eststo: reghdfe transition `regressors', a(modate id) cluster(id)
	estadd local ptype    = "All"
	estadd local clusters = e(N_clust)
	estadd local time     = "Yes"
	
	****************************************************************************
	
	esttab using cmbs_Full_Sample.tex, label replace b(a3) t(2) r2(3) booktabs ///
	drop()         ///
	star(* 0.10 ** 0.05 *** 0.01)       ///
	scalars("ptype Property Type"       ///
	        "clusters Number of Loans"  /// 
			"time Month-Year FE")            ///
	alignment(center) modelwidth(9) page(dcolumn) nonotes ///
	mtitles("$\mathbb{D}$" "$\mathbb{D}$" "$\mathbb{S}$" "$\mathbb{S}$" "$\mathbb{T}$" "$\mathbb{T}$")
	
	eststo clear
	
	
	****************************************************************************
	****************************************************************************
	* Without state cases/deaths 
	local regressors  ///
	ln_pppFunds pppLoans ln_eidlFunds eidlLoans covid_trips25 trips25 unemployment remainingTerm recentOp occupancy

	****************************************************************************
	eststo clear
	cd "`path'/Fixed Income Research/CMBS Data/CMBS Latex/"
	
	// 	eststo: reghdfe distress `regressors', a(modate id) cluster(id)
	// 	estadd local ptype    = "All"
	// 	estadd local clusters = e(N_clust)
	// 	estadd local time     = "Yes"
	****************************************************************************
	eststo: reghdfe distress `regressors' if property=="RT", a(modate id) cluster(id)
	estadd local ptype = "Retail"
	estadd local clusters = e(N_clust)
	estadd local time     = "Yes"
	****************************************************************************
	eststo: reghdfe distress `regressors' if property=="OF", a(modate id) cluster(id)
	estadd local ptype = "Office"
	estadd local clusters = e(N_clust)
	estadd local time     = "Yes"
	****************************************************************************
	eststo: reghdfe distress `regressors' if property=="LO", a(modate id) cluster(id)
	estadd local ptype = "Lodging"
	estadd local clusters = e(N_clust)
	estadd local time     = "Yes"
	****************************************************************************
	eststo: reghdfe distress `regressors' if property=="MF", a(modate id) cluster(id)
	estadd local ptype = "Multi-Family"
	estadd local clusters = e(N_clust)
	estadd local time     = "Yes"
	****************************************************************************
	eststo: reghdfe distress `regressors' if property=="MU", a(modate id) cluster(id)
	estadd local ptype = "Mixed-Use"
	estadd local clusters = e(N_clust)
	estadd local time     = "Yes"
	****************************************************************************
	eststo: reghdfe distress `regressors' if property=="IN" | property=="WH", a(modate id) cluster(id)
	estadd local ptype = "Industrial"
	estadd local clusters = e(N_clust)
	estadd local time     = "Yes"
	
	
	esttab using cmbs_Distress.tex, label replace b(a3) t(2) r2(3) booktabs ///
	drop()         ///
	star(* 0.10 ** 0.05 *** 0.01)       ///
	scalars("ptype Property Type"       ///
	        "clusters Number of Loans"  /// 
			"time Month-Year FE")            ///
	alignment(center) modelwidth(9) page(dcolumn) nonotes ///
	mtitles("$\mathbb{D}$" "$\mathbb{D}$" "$\mathbb{D}$" "$\mathbb{D}$" "$\mathbb{D}$" "$\mathbb{D}$")
	
	eststo clear
  	****************************************************************************
	****************************************************************************
	****************************************************************************
	

	****************************************************************************
	****************************************************************************
* Without state cases/deaths 
	local regressors  ///
	ln_pppFunds pppLoans ln_eidlFunds eidlLoans covid_trips25 trips25 unemployment remainingTerm recentOp occupancy  
		                   
	****************************************************************************
	eststo clear
	cd "`path'/Fixed Income Research/CMBS Data/CMBS Latex/"
	
	// 	eststo: reghdfe special `regressors', a(modate id) cluster(id)
	// 	estadd local ptype    = "All"
	// 	estadd local clusters = e(N_clust)
	// 	estadd local time     = "Yes"
	// 	estadd local cov      = "Yes"
	****************************************************************************
	eststo: reghdfe special `regressors' if property=="RT", a(modate id) cluster(id)
	estadd local ptype = "Retail"
	estadd local clusters = e(N_clust)
	estadd local time     = "Yes"
	****************************************************************************
	eststo: reghdfe special `regressors' if property=="OF", a(modate id) cluster(id)
	estadd local ptype = "Office"
	estadd local clusters = e(N_clust)
	estadd local time     = "Yes"
	****************************************************************************
	eststo: reghdfe special `regressors' if property=="LO", a(modate id) cluster(id)
	estadd local ptype = "Lodging"
	estadd local clusters = e(N_clust)
	estadd local time     = "Yes"
	****************************************************************************
	eststo: reghdfe special `regressors' if property=="MF", a(modate id) cluster(id)
	estadd local ptype = "Multi-Family"
	estadd local clusters = e(N_clust)
	estadd local time     = "Yes"
	****************************************************************************
	eststo: reghdfe special `regressors' if property=="MU", a(modate id) cluster(id)
	estadd local ptype = "Mixed-Use"
	estadd local clusters = e(N_clust)
	estadd local time     = "Yes"
	****************************************************************************
	eststo: reghdfe special `regressors' if property=="IN" | property=="WH", a(modate id) cluster(id)
	estadd local ptype = "Industrial"
	estadd local clusters = e(N_clust)
	estadd local time     = "Yes"

	esttab using cmbs_Special.tex, label replace b(a3) t(2) r2(3) booktabs ///
	drop()                    ///
	star(* 0.10 ** 0.05 *** 0.01)       ///
	scalars("ptype Property Type"       ///
	        "clusters Number of Loans"  /// 
			"time Month-Year FE")            ///
	alignment(center) modelwidth(9) page(dcolumn) nonotes ///
	mtitles("$\mathbb{S}$" "$\mathbb{S}$" "$\mathbb{S}$" "$\mathbb{S}$" "$\mathbb{S}$" "$\mathbb{S}$")

	
    eststo clear
	****************************************************************************
	****************************************************************************
    ****************************************************************************
	
	****************************************************************************
	****************************************************************************


	local regressors  ///
	ln_pppFunds pppLoans ln_eidlFunds eidlLoans covid_trips25 trips25 unemployment remainingTerm recentOp occupancy                    
	                   
	****************************************************************************
	eststo clear
	cd "`path'/Fixed Income Research/CMBS Data/CMBS Latex/"
	
	// 	eststo: reghdfe transition `regressors', a(modate id) cluster(id)
	// 	estadd local ptype    = "All"
	// 	estadd local clusters = e(N_clust)
	// 	estadd local time     = "Yes"
	// 	estadd local cov      = "Yes"
	****************************************************************************
	eststo: reghdfe transition `regressors' if property=="RT", a(modate id) cluster(id)
	estadd local ptype = "Retail"
	estadd local clusters = e(N_clust)
	estadd local time     = "Yes"
	****************************************************************************
	eststo: reghdfe transition `regressors' if property=="OF", a(modate id) cluster(id)
	estadd local ptype = "Office"
	estadd local clusters = e(N_clust)
	estadd local time     = "Yes"
	****************************************************************************
	eststo: reghdfe transition `regressors' if property=="LO", a(modate id) cluster(id)
	estadd local ptype = "Lodging"
	estadd local clusters = e(N_clust)
	estadd local time     = "Yes"
	****************************************************************************
	eststo: reghdfe transition `regressors' if property=="MF", a(modate id) cluster(id)
	estadd local ptype = "Multi-Family"
	estadd local clusters = e(N_clust)
	estadd local time     = "Yes"
	****************************************************************************
	eststo: reghdfe transition `regressors' if property=="MU", a(modate id) cluster(id)
	estadd local ptype = "Mixed-Use"
	estadd local clusters = e(N_clust)
	estadd local time     = "Yes"
	****************************************************************************
	eststo: reghdfe transition `regressors' if property=="IN" | property=="WH", a(modate id) cluster(id)
	estadd local ptype = "Industrial"
	estadd local clusters = e(N_clust)
	estadd local time     = "Yes"

	esttab using cmbs_Transition.tex, label replace b(a3) t(2) r2(3) booktabs ///
	drop()         ///
	star(* 0.10 ** 0.05 *** 0.01)       ///
	scalars("ptype Property Type"       ///
	        "clusters Number of Loans"  /// 
			"time Month-Year FE")            ///
	alignment(center) modelwidth(8) page(dcolumn) nonotes ///
	mtitles("$\mathbb{T}$" "$\mathbb{T}$" "$\mathbb{T}$" "$\mathbb{T}$" "$\mathbb{T}$" "$\mathbb{T}$")
	
    eststo clear
	**************************************************
	
	
	

******************************************************************************
	
	* Summary Statistics
	cd "H:/Fixed Income Research/CMBS Data/CMBS Latex/"
	
	label var distress "Default ($\mathbb{D}$)"
	label var special  "Special Service ($\mathbb{S}$)"
	label var transition "Delinquency Transition ($\mathbb{T}$)"
	label var propertyValue "Original Property Value"
	label var ltv "Original LTV"
	
	* Generate summary statistics 
	eststo clear 
	estpost summarize irate loan term remainingTerm origYear securitizationYear ///
	propertyValue ltv recentOp occupancy distress special transition, listwise detail
	
	* Tabulate and save results 
	esttab using cmbs_sumstats.tex,                      ///
	replace label noobs nonumber nomtitle booktabs b(a3) ///
	cell((                               ///
	count(label(N))                      ///
	mean(fmt(%15.3fc) label(Mean))       ///
	p50(fmt(%15.3fc)  label(Median))     ///
	sd(fmt(%15.3fc)   label(Std. Dev.))  ///  
	min(fmt(%15.3fc)  label(Min))        ///
	max(fmt(%15.3fc)  label(Max))        ///
	))
	
	
	
	gen ppp_fund_sum = pppFunds 
	replace ppp_fund_sum = . if covid==0
	label var ppp_fund_sum "PPP Funding Coverage"
	
	gen ppp_cov_sum = pppLoans 
	replace ppp_cov_sum = . if covid==0
	label var ppp_cov_sum "PPP Loan Coverage"
	
	gen eidl_fund_sum = eidlFunds 
	replace eidl_fund_sum =. if covid==0
	label var eidl_fund_sum "EIDL Funding Coverage"
	
	gen eidl_cov_sum = eidlLoans 
	replace eidl_cov_sum = . if covid==0
	label var eidl_cov_sum "EIDL Loan Coverage"
	
	// Generate summary statistics 
	eststo clear 
	estpost summarize ppp_fund_sum ppp_cov_sum eidl_fund_sum eidl_cov_sum, listwise detail
	
	cd "H:/Fixed Income Research/CMBS Data/CMBS Latex/"
	// Tabulate and save results 
	esttab using cmbs_sumstats_PPP.tex,                      ///
	replace label noobs nonumber nomtitle booktabs b(a3) ///
	cell((                               ///
	count(label(N))                      ///
	mean(fmt(%15.3fc) label(Mean))       ///
	p50(fmt(%15.3fc)  label(Median))     ///
	sd(fmt(%15.3fc)   label(Std. Dev.))  ///  
	min(fmt(%15.3fc)  label(Min))        ///
	max(fmt(%15.3fc)  label(Max))        ///
	))
	
	eststo clear
	estpost summarize trips25 unemployment , listwise detail
	
	cd "H:/Fixed Income Research/CMBS Data/CMBS Latex/"
	// Tabulate and save results 
	esttab using cmbs_sumstats_Mobility.tex,                      ///
	replace label noobs nonumber nomtitle booktabs b(a3) ///
	cell((                               ///
	count(label(N))                      ///
	mean(fmt(%15.3fc) label(Mean))       ///
	p50(fmt(%15.3fc)  label(Median))     ///
	sd(fmt(%15.3fc)   label(Std. Dev.))  ///  
	min(fmt(%15.3fc)  label(Min))        ///
	max(fmt(%15.3fc)  label(Max))        ///
	))

****************************************************************************

	gen general = (distress==1 | special==1)

	drop rt lo it mf of all mu all
	drop ot 

	local dependent distress
	
	egen all = mean(`dependent'), by(modateEnd)
	egen rt  = mean(`dependent') if property=="RT", by(figureEndMonth) 
	egen lo  = mean(`dependent') if property=="LO", by(figureEndMonth) 
	egen it  = mean(`dependent') if property=="IN" | property=="WH", by(figureEndMonth) 
	egen mf  = mean(`dependent') if property=="MF", by(figureEndMonth) 
	egen of  = mean(`dependent') if property=="OF", by(figureEndMonth) 
	egen mu  = mean(`dependent') if property=="MU", by(figureEndMonth)
	egen ot  = mean(`dependent') if other==1, by(figureEndMonth)
	* egen WH  = mean(`dependent') if property=="WH", by(figureEndMonth) 
	* egen mh  = mean(`dependent') if property=="MH", by(figureEndMonth)
    * egen ch  = mean(`dependent') if property=="CH", by(figureEndMonth) 
	* egen ss  = mean(`dependent') if property=="SS", by(figureEndMonth) 
	
	
	label var all "All Properties"
	label var rt  "Retail"
	label var lo  "Lodging"
	label var it  "Industrial"
	label var mf  "Multi-Family"
	label var of  "Office"
	label var mu  "Mixed Use"
	*label var ch  "Cooperative Housing"
	*label var ss  "Self-Storage"
	*label var WH  "Warehouse"
	*label var mh  "Mobile Home"
	
	
	line all rt lo it mf of mu ot figureEndMonth if figureEndMonth>=tm(2019m2), sort      ///
	ytitle("Special Service Rate (%)", size(small)) xtitle("Month", size(small))          /// 
	xsize(6.0) xlabel(#8, labsize(tiny)) ylabel(#6, labsize(vsmall))yscale(titlegap(*+5)) /// 
	xscale(titlegap(*+5)) ///
	legend(size(vsmall)) 
	
	
	
	
	cd "`path'/Fixed Income Research/CMBS Data/CMBS Figures/"

	local dependent distress
	
	egen all = mean(`dependent'), by(modateEnd)
	egen rt  = mean(`dependent') if property=="RT", by(figureEndMonth) 
	egen lo  = mean(`dependent') if property=="LO", by(figureEndMonth) 
	egen it  = mean(`dependent') if property=="IN" | property=="WH", by(figureEndMonth) 
	egen mf  = mean(`dependent') if property=="MF", by(figureEndMonth) 
	egen of  = mean(`dependent') if property=="OF", by(figureEndMonth) 
	*egen ch  = mean(`dependent') if property=="CH", by(figureEndMonth) 
	* egen ss  = mean(`dependent') if property=="SS", by(figureEndMonth) 
	egen mu  = mean(`dependent') if property=="MU", by(figureEndMonth)
	*egen WH  = mean(`dependent') if property=="WH", by(figureEndMonth) 
	*egen mh  = mean(`dependent') if property=="MH", by(figureEndMonth)
	*egen ot  = mean(`dependent') if property=="98", by(figureEndMonth)
	
	
	label var all "All Properties"
	label var rt  "Retail"
	label var lo  "Lodging"
	label var it  "Industrial"
	label var mf  "Multi-Family"
	label var of  "Office"
	*label var ch  "Cooperative Housing"
	*label var ss  "Self-Storage"
	label var mu  "Mixed Use"
	*label var WH  "Warehouse"
	*label var mh  "Mobile Home"
	
	
	line all rt lo it mf of mu figureEndMonth if figureEndMonth>=tm(2019m2), sort ///
	ytitle("Default Rate (%)", size(small)) xtitle("Year-Month", size(small)) xsize(6.0) xlabel(#8, labsize(tiny)) ylabel(#6, labsize(vsmall))yscale(titlegap(*+5)) /// 
	xscale(titlegap(*+5)) ///
	legend(size(vsmall)) 
	
	cd "`path'/Fixed Income Research/CMBS Data/CMBS Figures/"
	
	graph export cmbs_default.png, replace
	
	
	
	
	
	
	drop rt lo it mf of all mu all

	local dependent special
	
	egen all = mean(`dependent'), by(modateEnd)
	egen rt  = mean(`dependent') if property=="RT", by(figureEndMonth) 
	egen lo  = mean(`dependent') if property=="LO", by(figureEndMonth) 
	egen it  = mean(`dependent') if property=="IN" | property=="WH", by(figureEndMonth) 
	egen mf  = mean(`dependent') if property=="MF", by(figureEndMonth) 
	egen of  = mean(`dependent') if property=="OF", by(figureEndMonth) 
	*egen ch  = mean(`dependent') if property=="CH", by(figureEndMonth) 
	* egen ss  = mean(`dependent') if property=="SS", by(figureEndMonth) 
	egen mu  = mean(`dependent') if property=="MU", by(figureEndMonth)
	*egen WH  = mean(`dependent') if property=="WH", by(figureEndMonth) 
	*egen mh  = mean(`dependent') if property=="MH", by(figureEndMonth)
	*egen ot  = mean(`dependent') if property=="98", by(figureEndMonth)
	
	
	label var all "All Properties"
	label var rt  "Retail"
	label var lo  "Lodging"
	label var it  "Industrial"
	label var mf  "Multi-Family"
	label var of  "Office"
	*label var ch  "Cooperative Housing"
	*label var ss  "Self-Storage"
	label var mu  "Mixed Use"
	*label var WH  "Warehouse"
	*label var mh  "Mobile Home"
	
	
	line all rt lo it mf of mu figureEndMonth if figureEndMonth>=tm(2019m2), sort ///
	ytitle("Special Service Rate (%)", size(small)) xtitle("Year-Month", size(small)) xsize(6.0) xlabel(#8, labsize(tiny)) ylabel(#6, labsize(vsmall))yscale(titlegap(*+5)) /// 
	xscale(titlegap(*+5)) ///
	legend(size(vsmall)) 
	
	cd "`path'/Fixed Income Research/CMBS Data/CMBS Figures/"
	
	graph export cmbs_special.png, replace

 	
	
	drop rt lo it mf of all mu all

	local dependent transition
	
	egen all = mean(`dependent'), by(modateEnd)
	egen rt  = mean(`dependent') if property=="RT", by(figureEndMonth) 
	egen lo  = mean(`dependent') if property=="LO", by(figureEndMonth) 
	egen it  = mean(`dependent') if property=="IN" | property=="WH", by(figureEndMonth) 
	egen mf  = mean(`dependent') if property=="MF", by(figureEndMonth) 
	egen of  = mean(`dependent') if property=="OF", by(figureEndMonth) 
	*egen ch  = mean(`dependent') if property=="CH", by(figureEndMonth) 
	* egen ss  = mean(`dependent') if property=="SS", by(figureEndMonth) 
	egen mu  = mean(`dependent') if property=="MU", by(figureEndMonth)
	*egen WH  = mean(`dependent') if property=="WH", by(figureEndMonth) 
	*egen mh  = mean(`dependent') if property=="MH", by(figureEndMonth)
	*egen ot  = mean(`dependent') if property=="98", by(figureEndMonth)
	
	
	label var all "All Properties"
	label var rt  "Retail"
	label var lo  "Lodging"
	label var it  "Industrial"
	label var mf  "Multi-Family"
	label var of  "Office"
	*label var ch  "Cooperative Housing"
	*label var ss  "Self-Storage"
	label var mu  "Mixed Use"
	*label var WH  "Warehouse"
	*label var mh  "Mobile Home"
	
	
	line all rt lo it mf of mu figureEndMonth if figureEndMonth>=tm(2019m2), sort ///
	ytitle("Transition Rate (%)", size(small)) xtitle("Year-Month", size(small)) xsize(6.0) xlabel(#8, labsize(tiny)) ylabel(#6, labsize(vsmall))yscale(titlegap(*+5)) /// 
	xscale(titlegap(*+5)) ///
	legend(size(vsmall)) 
	
	cd "`path'/Fixed Income Research/CMBS Data/CMBS Figures/"

	graph export cmbs_transition.png, replace
	
	drop rt lo it mf of all mu all




* End of file * 
****************************************************************************