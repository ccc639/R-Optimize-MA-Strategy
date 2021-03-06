rm(list=ls())  
library("quantmod")
library("PerformanceAnalytics")
library ("timeSeries")
library ("timeDate")

nameOfStrategy <- "GSPC Moving Average Strategy"

#Specify dates for downloading data, training models and running simulation
trainingStartDate = as.Date("2000-01-01")
trainingEndDate = as.Date("2010-01-01")
outofSampleStartDate = as.Date("2010-01-02")
outofSampleEndDate = as.Date("2012-12-31")

#Download the data
symbolData <- new.env() #Make a new environment for quantmod to store data in
getSymbols("^GSPC", env = symbolData, src = "yahoo", from = trainingStartDate)
trainingData <- window(symbolData$GSPC, start = trainingStartDate, end = trainingEndDate)
testData <- window(symbolData$GSPC, start = outofSampleStartDate, end = outofSampleEndDate)

# Calculate the benchmark - basic buy and hold strategy
indexReturns <- Delt(Cl(window(symbolData$GSPC, start = outofSampleStartDate, end = outofSampleEndDate)))
colnames(indexReturns) <- "GSPC Buy&Hold"

TradingStrategy <- function(mktdata,mavga_period,mavgb_period){
  #This is where we define the trading strategy
  #Check moving averages at start of the day and use as the direciton signal
  #Enter trade at the start of the day and exit at the close
  
  #Lets print the name of whats running
  runName <- paste("MAVG a",mavga_period,"over b ",mavgb_period,sep="")
  print(paste("Running Strategy: ",runName))
  
  #Calculate the Open Close return
  returns <- (Cl(mktdata)/Op(mktdata))-1
  
  #Calculate the moving averages
  mavga <- SMA(Op(mktdata),n=mavga_period)
  mavgb <- SMA(Op(mktdata),n=mavgb_period)
  
  signal <- mavga / mavgb
  #If mavga > mavgb go long
  signal <- apply(signal,1,function (x) { if(is.na(x)){ return (0) } else { if(x>1){return (1)} else {return (-1)}}})
  
  tradingreturns <- signal * returns
  colnames(tradingreturns) <- runName
  
  return (tradingreturns)
}

RunIterativeStrategy <- function(mktdata){
  #This function will run the TradingStrategy
  #It will iterate over a given set of input variables
  #In this case we try lots of different periods for the moving average
  firstRun <- TRUE
  for(a in seq(from = 25, to = 125, by=25)){
    for(b in seq(from = 100, to= 500, by=100)){
      
      runResult <- TradingStrategy(mktdata,a,b)

      if(firstRun){
        firstRun <- FALSE
        results <- runResult
      } else {
        results <- cbind(results,runResult)
      }
    }
  }
  
  return(results)
}

CalculatePerformanceMetric <- function(returns,metric){
  #Get given some returns in columns
  #Apply the function metric to the data
  
  print (paste("Calculating Performance Metric:",metric))
  
  metricFunction <- match.fun(metric)
  metricData <- as.matrix(metricFunction(returns))
  #Some functions return the data the wrong way round
  #Hence cant label columns to need to check and transpose it
  if(nrow(metricData) == 1){
    metricData <- t(metricData)
  }
  colnames(metricData) <- metric
  
  return (metricData)
}



PerformanceTable <- function(returns){
  pMetric <- CalculatePerformanceMetric(returns,"colSums")
  pMetric <- cbind(pMetric,CalculatePerformanceMetric(returns,"SharpeRatio.annualized"))
  pMetric <- cbind(pMetric,CalculatePerformanceMetric(returns,"maxDrawdown"))
  colnames(pMetric) <- c("Profit","SharpeRatio","MaxDrawDown")
  
  print("Performance Table")
  print(pMetric)
  return (pMetric)
}

OrderPerformanceTable <- function(performanceTable,metric){
  return (performanceTable[order(performanceTable[,metric],decreasing=TRUE),])
}

SelectTopNStrategies <- function(returns,performanceTable,metric,n){
  #Metric is the name of the function to apply to the column to select the Top N
  #n is the number of strategies to select
  pTab <- OrderPerformanceTable(performanceTable,metric)
  
  if(n > ncol(returns)){
    n <- ncol(returns)
  }
  strategyNames <- rownames(pTab)[1:n]
  topNMetrics <- returns[,strategyNames]
  return (topNMetrics)
}

FindOptimumStrategy <- function(trainingData){
  #Optimise the strategy
  trainingReturns <- RunIterativeStrategy(trainingData)
  pTab <- PerformanceTable(trainingReturns)
  toptrainingReturns <- SelectTopNStrategies(trainingReturns,pTab,"SharpeRatio",5)
  charts.PerformanceSummary(toptrainingReturns,main=paste(nameOfStrategy,"- Training"),geometric=FALSE)
  return (pTab)
}

pTab <- FindOptimumStrategy(trainingData) #pTab is the performance table of the various parameters tested

#Test out of sample
dev.new()
#Manually specify the parameter that we want to trade here, just because a strategy is at the top of
#pTab it might not be good (maybe due to overfit)
outOfSampleReturns <- TradingStrategy(testData,mavga_period=50,mavgb_period=200)
finalReturns <- cbind(outOfSampleReturns,indexReturns)
charts.PerformanceSummary(finalReturns,main=paste(nameOfStrategy,"- Out of Sample"),geometric=FALSE)


