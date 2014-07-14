# compare-model-chart.R
# Main program to create charts from the results of running compare-models
# driven by command line arguments, which have this syntax
# Rscript compare-models.R --what cv   --choice NUM   -->  (OLD)
#   produce file OUTPUT/compare-models-cv-chart-chart-NUM.pdf
# Rscript compare-models-chart.R --what XXX -- choice YYY -->
#   produce file OUTPUT/compare-models-chart-XXX-YYY.pdf

library(ggplot2)

source('Require.R')  # read function definition file if function does not exist

Require('CommandArgs')
Require('InitializeR')
Require('ParseCommandLine')
Require('Printf')

ParseCommandLineArguments <- function(cl) {
    # parse command line into a list
    # ARGS
    # cl : chr vector of arguments in form --KEYWORD value
    #cat('starting ParseCommandLine\n'); browser()
    result <- ParseCommandLine( cl
                               ,keywords = c('what', 'choice')
                               ,ignoreUnexpected = TRUE
                               ,verbose = TRUE
                               )
    result
}

AugmentControlVariables <- function(control) {
    # add additional control variables to list of control variables
    #cat('starting AugmentControlVariables\n'); browser()
    result <- control
    result$me <- 'compare-models-chart'

    # input/output
    result$dir.output <- '../data/v6/output/'
    
    Prefix <- function(program.name) {
        paste0(result$dir.output,
               program.name,
               '-', control$what,
               '-', control$choice)
    }

    prefix.in <- Prefix('compare-models')
    prefix.out <-Prefix(result$me)

    result$path.in.driver.result <- paste0(prefix.in, '.rsave')

    result$path.out.log <- paste0(prefix.out, '-log.txt')
    result$path.out.chart1 <- paste0(prefix.out, '-chart1.pdf')

    # control variables for all the experiments

    result$testing <- TRUE
    result$testing <- FALSE
    result
}


AllSame <- function(values) {
    #cat('starting AllSame\n'); browser()
    result <- all(values == values[[1]])
    result
}

Varying <- function(descriptions) {
    # return chr vector of varying portions of names
    #cat('starting Varying\n'); browser()

    # pull out each field
    scenario <- lapply(descriptions, function(x) x$scenario)
    testing.period.first.date <- lapply(descriptions, function(x) x$testing.period$first.date)
    testing.period.last.date <- lapply(descriptions, function(x) x$testing.period$last.date)
    training.period <- lapply(descriptions, function(x) x$training.period)
    model <- lapply(descriptions, function(x) x$model)
    response <- lapply(descriptions, function(x) x$response)
    predictors <- lapply(descriptions, function(x) x$predictors)

    varying.values <- NULL
    varying.names <- NULL

    MaybeAppend <- function(name, values) {
        #cat('starting MaybeAppend\n'); browser()
        if (!AllSame(values)) {
            #cat('not all same'); browser()
            n <- length(values)
            if (is.null(varying.values)) {
                lapply(1:n, function(i) varying.values[[i]] <<- values[[i]])
            } else {
                lapply(1:n, function(i) varying.values[[i]] <<- paste(varying.values[[i]], values[[i]]))
            }
            varying.names <<- paste(varying.names, name)
            if (FALSE) {
                print('varying.values'); print(varying.values)
                print('varying.names'); print(varying.names)
            }
        }
    }

    # build up varying and varying.names to be just the fields that are not all the same
    MaybeAppend('scenario', scenario)
    MaybeAppend('testing.period.first.date', testing.period.first.date)
    MaybeAppend('testing.period.last.date', testing.period.last.date)
    MaybeAppend('training.period', training.period)
    MaybeAppend('model', model)
    MaybeAppend('response', response)
    MaybeAppend('predictors', predictors)

    result <- list(values = varying.values, names = varying.names)
    result
}

HasName <- function(description) {
    d1 <- description[[1]]
    !is.null(d1$name)
}

OnlyTrainingPeriodVary <- function(description) {
    AllSame(lapply(description, function(x) x$scenario)) &
    AllSame(lapply(description, function(x) x$testing.period$first.date)) &
    AllSame(lapply(description, function(x) x$testing.period$last.date)) &
    AllSame(lapply(description, function(x) x$model)) &
    AllSame(lapply(description, function(x) x$response)) &
    AllSame(lapply(description, function(x) x$predictors)) &
    !AllSame(lapply(description, function(x) x$training.period)) 
}


CvChart <- function(cv.result, description, choice) {
    # produce plot showing description, mean RMSEs, and fractions within 10 percent
    cat('starting CvChart', length(cv.result), length(description), '\n'); browser()

    # set point names
    if (HasName(description)) {
        point.name <- sapply(description, function(x) x$name)
    } else if (OnlyTrainingPeriodVary(description)) {
        point.name <- sapply(description, function(x) x$training.period)
    } else {
        # pull out each description component

        varying <- Varying(description)
        varying.values <- varying$values
        varying.names <- varying$names

        point.name <- varying.values
    }
    

    best.model.index <- cv.result$best.model.index
    fold.assessment <- cv.result$fold.assessment

    nmodels <- max(fold.assessment$model.index)

    mean.rmse <- 
        sapply(1:nmodels,
               function(x) mean(subset(fold.assessment,
                                       subset = model.index == x,
                                       select = 'assessment.rmse',
                                       drop = TRUE)))
    
    mean.within.10.percent <- 
        sapply(1:nmodels,
               function(x) mean(subset(fold.assessment,
                                       subset = model.index == x,
                                       select = 'assessment.within.10.percent',
                                       drop = TRUE)))

    
    Graphic <- function() {
        # scatterplot; show all labels;
        # RETURN graphic

        cat('starting cvChart::Graphic\n'); browser()
        # an earlier version created a text label only for the best model
        # the statement below is dead code
#        best.model.name <- ifelse(min(mean.rmse) == mean.rmse,
#                                  varying.values,
#                                  ' ')
        data <- data.frame(point.name = point.name,
                           mean.rmse = mean.rmse,
                           mean.fraction.within.10.percent = mean.within.10.percent)
        data$lowest.RMSE <- ifelse(mean.rmse == min(mean.rmse), TRUE, FALSE)
        # labeling points see RGC p. 105
        gg <- ggplot(data, aes(x = mean.rmse, 
                               y = mean.fraction.within.10.percent))

        g <- 
            gg +
            geom_point(shape = 19) +
            theme_bw() +
            theme(panel.grid.major.x = element_blank(),
                  panel.grid.minor.x = element_blank(),
                  panel.grid.major.y = element_blank())  #  no horizontal grid lines
        # add in the text labels, position depends on the data
        if (choice == 5) {
            g2 <- g + 
            geom_text(aes(x = mean.rmse + 2000,   # adjust plot point
                          y = mean.fraction.within.10.percent,
                          label = point.name), 
                      hjust = 0,
                      size = 3) +
            coord_cartesian(xlim = c(350000, 600000)) 
        } else {
            g2 <- g +
            geom_text(aes(x = mean.rmse - 1000,   # adjust plot point
                          y = mean.fraction.within.10.percent + 0.001,
                          label = point.name), 
                      hjust = 0,
                      size=3)
        }
            
        g2
    }


    g <- Graphic()
    
    # plot to a file
    #cat('in CvChart, g holds the plot\n'); browser()
    display <- FALSE
    display <-TRUE
    graphic.width <- 7  # inches
    graphic.height <- 5  # inches
    if (display) {
        X11(width = graphic.width, height = graphic.height)
        print(g)
        # leave the device on, so that the user can view the graphic
        #dev.off()
    }
    pdf(control$path.out.chart1, width = graphic.width, height = graphic.height)
    print(g)
    dev.off()

    #cat('in CvChart\n'); browser()
    NULL
    
}


Cv <- function(control) {
    # create all the charts for experiment control$what control$choice
    cat('starting Cv', control$choice, '\n'); browser()

    cv.result <- NULL
    description <- NULL
    variables.loaded <- load(control$path.in.driver.result)
    stopifnot(!is.null(cv.result))  # I expect cv.result to have been loaded
    stopifnot(!is.null(description))
    result <- CvChart(cv.result = cv.result,
                      description = description,
                      choice = control$choice)
    result
}

Bmpt <- function(control) {
    # create scatter plot: change in median price vs. # training days
    cat('starting Bmpt', control$choice, '\n'); browser()

    all.row <- NULL
    variables.loaded <- load(control$path.in.driver.result)
    stopifnot(!is.null(all.row))
    result <- BmptChart(all.row)
    result
}



Main <- function(control) {
    # execute one command, return NULL
    #cat('starting Main', control$what, '\n'); browser()

    driver <- switch( control$what
                     ,cv = Cv
                     ,bmpt = Bmpt
                     )
    stopifnot(!is.null(driver))
    driver(control)
}


###############################################################################
# EXECUTION STARTS HERE
###############################################################################

# handle command line and setup control variables
command.args <- CommandArgs(ifR = list('--what', 'cv', '--choice', '05'))
command.args <- CommandArgs(ifR = list('--what', 'bmpt', '--choice', 'assessor'))

control <- AugmentControlVariables(ParseCommandLineArguments(command.args))

# initilize R
InitializeR(start.JIT = FALSE,
            duplex.output.to = control$path.out.log)

# do the work
Main(control)

cat('control variables\n')
str(control)

if (control$testing) {
    cat('DISCARD RESULTS: TESTING\n')
}

cat('done\n')