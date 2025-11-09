// Create folder structure if it doesn't exist
capture mkdir "data"
capture mkdir "data/raw"
capture mkdir "data/clean"
capture mkdir "output"
capture mkdir "output/graphs"
capture mkdir "output/tables"
capture mkdir "code"

// Clear environment
clear all
set more off

// Read .csv data and fix data quality errors
import delimited "data/raw/SP500_2006_16_data.csv", clear varnames(1)

// Display first few observations to understand the data
list in 1/10

// Fix common data quality errors
describe value
codebook value

// Replace "#N/A" with missing values
destring value, replace force
// The "force" option converts non-numeric entries to missing (.)

// DATE variable needs to be converted to Stata date format
describe date
generate date_stata = date(date, "YMD")
format date_stata %td
label variable date_stata "Trading Date"

// Create additional time variables for analysis
generate year = year(date_stata)
generate month = month(date_stata)
generate quarter = quarter(date_stata)
generate day_of_week = dow(date_stata)

label variable year "Year"
label variable month "Month"
label variable quarter "Quarter"
label variable day_of_week "Day of Week (0=Sunday)"

// Filter observations
count if missing(value)
drop if missing(value)  // Remove missing trading days
keep if year >= 2007 & year <= 2015

// Filter variables
keep date_stata value year month quarter day_of_week
order date_stata value year month quarter day_of_week

// Create transformations of variables
// Create log of value
generate log_value = ln(value)
label variable log_value "Log of S&P 500 Value"

// Create daily returns (percentage change)
sort date_stata
generate daily_return = (value - value[_n-1]) / value[_n-1] * 100
label variable daily_return "Daily Return (%)"

// Create moving averages
tsset date_stata
generate ma_30 = (value + L1.value + L2.value + L3.value + L4.value + ///
                  L5.value + L6.value + L7.value + L8.value + L9.value + ///
                  L10.value + L11.value + L12.value + L13.value + L14.value + ///
                  L15.value + L16.value + L17.value + L18.value + L19.value + ///
                  L20.value + L21.value + L22.value + L23.value + L24.value + ///
                  L25.value + L26.value + L27.value + L28.value + L29.value) / 30
label variable ma_30 "30-Day Moving Average"
// Create volatility measure (rolling standard deviation of returns)
generate return_sq = daily_return^2
generate volatility = sqrt((return_sq + L1.return_sq + L2.return_sq + ///
                            L3.return_sq + L4.return_sq + L5.return_sq + ///
                            L6.return_sq + L7.return_sq + L8.return_sq + ///
                            L9.return_sq + L10.return_sq + L11.return_sq + ///
                            L12.return_sq + L13.return_sq + L14.return_sq + ///
                            L15.return_sq + L16.return_sq + L17.return_sq + ///
                            L18.return_sq + L19.return_sq + L20.return_sq + ///
                            L21.return_sq + L22.return_sq + L23.return_sq + ///
                            L24.return_sq + L25.return_sq + L26.return_sq + ///
                            L27.return_sq + L28.return_sq + L29.return_sq) / 30)
label variable volatility "30-Day Rolling Volatility"
drop return_sq

// Create crisis indicator (2008 financial crisis)
generate crisis = (year == 2008 | year == 2009)
label variable crisis "Financial Crisis Period (2008-2009)"

// Create year-over-year growth rate
generate value_lag_252 = L252.value  // Approximately 252 trading days per year
generate yoy_growth = (value - value_lag_252) / value_lag_252 * 100
label variable yoy_growth "Year-over-Year Growth (%)"

// Save cleaned/modified data
save "data/clean/sp500_cleaned.dta", replace
export delimited using "data/clean/sp500_cleaned.csv", replace


// Create summary statistics table
summarize value daily_return ma_30 volatility, detail


// Graph: Time series of S&P 500 value with moving average
twoway (line value date_stata, lcolor(navy) lwidth(thin)) ///
       (line ma_30 date_stata, lcolor(red) lwidth(medium) lpattern(dash)), ///
       title("S&P 500 Index: 2007-2015") ///
       subtitle("With 30-Day Moving Average") ///
       ytitle("Index Value") xtitle("Date") ///
       legend(order(1 "Daily Value" 2 "30-Day MA") position(6) rows(1)) ///
       scheme(s2color) ///
       note("Source: SP500_2006_16_data.csv")
graph export "output/graphs/sp500_timeseries.png", replace width(1200)

// Graph: Histogram of daily returns
histogram daily_return, ///
       bin(50) ///
       frequency ///
       fcolor(navy%60) lcolor(black) ///
       title("Distribution of Daily Returns") ///
       subtitle("S&P 500: 2007-2015") ///
       xtitle("Daily Return (%)") ytitle("Frequency") ///
       normal normopts(lcolor(red) lwidth(thick)) ///
       legend(order(2 "Normal Distribution") position(6)) ///
       scheme(s2color) ///
       note("Red line shows normal distribution for comparison")
graph export "output/graphs/return_distribution.png", replace width(1000)


// Graph: Box plot of returns by year
graph box daily_return, over(year) ///
       title("Distribution of Daily Returns by Year") ///
       ytitle("Daily Return (%)") ///
       box(1, fcolor(navy%50)) ///
       marker(1, mcolor(red%50) msize(tiny)) ///
       yline(0, lcolor(black)) ///
       scheme(s2color) ///
       note("2008-2009 show higher volatility during financial crisis")
graph export "output/graphs/returns_by_year.png", replace width(1200)

// Graph: Average monthly returns by month (seasonality check)
preserve
collapse (mean) avg_return=daily_return (count) n=daily_return, by(month)
label define month_lbl 1 "Jan" 2 "Feb" 3 "Mar" 4 "Apr" 5 "May" 6 "Jun" ///
                        7 "Jul" 8 "Aug" 9 "Sep" 10 "Oct" 11 "Nov" 12 "Dec"
label values month month_lbl

graph bar avg_return, over(month) ///
       title("Average Daily Returns by Month") ///
       subtitle("S&P 500: 2007-2015") ///
       ytitle("Average Daily Return (%)") ///
       bar(1, fcolor(navy) lcolor(black)) ///
       yline(0, lcolor(black)) ///
       scheme(s2color) ///
       note("Checking for seasonal patterns")
graph export "output/graphs/seasonal_pattern.png", replace width(1000)
restore
// Display completion message
display as text _n "Analysis complete!" _n ///
        "Cleaned data saved to: data/clean/" _n ///
        "Tables saved to: output/tables/" _n ///
        "Graphs saved to: output/graphs/" _n

// End of master do file
log close _all