# Analysis Script

#---- Bootstrap inference ----
# #test directory
#directory <- "/Users/ehlarson/Box/KD_bootstrapping/hoffman_cluster/"
#Analysis function
analysis <- function(seed){
  #---- **load packages ----
  #pacman doesn't work on hoffman for one of these packages... I've installed all
  # of them already so we can just library them
  library("tidyverse") #1.3.1
  library("dplyr") #1.0.7
  library("Hmisc") #4.6.0
  library("rms") #6.2.0
  library("weights") #1.0.4
  library("survey") #4.1.1
  library("SuperLearner") #2.0.28
  library("arm") #1.12.2
  library("gam") #1.20
  library("earth") #5.3.1
  library("twang") #2.5
  library("gbm") #2.1.8
  
  #---- custom functions ----
  createInteractions <- function(df1){
    df1 <- df1 %>% mutate(
      blackXmale = black*male,
      blackXNage = black*Nage,
      blackXdiabetes = black*diabetes,
      blackXstroke = black*stroke,
      blackXBMI = black*BMI,
      blackXCholesterol = black*Cholesterol,
      blackXHeartDz = black*HeartDz,
      blackXCongestiveHeart = black*CongestiveHeart,
      blackXedu1_noed = black*edu1_noed,
      blackXedu1_elem = black*edu1_elem,
      blackXedu1_somehs = black*edu1_somehs,
      # blackXedu1_hs = black*edu1_hs,
      blackXedu1_somecol = black*edu1_somecol,
      blackXedu1_colpstgrad = black*edu1_colpstgrad,
      # blackXlang1_eng = black*lang1_eng,
      # blackXlang1_span = black*lang1_span,
      # blackXlang1_both = black*lang1_both,
      blackXmarry_bi = black*marry_bi,
      
      hispanicXmale = hispanic*male,
      hispanicXNage = hispanic*Nage,
      hispanicXdiabetes = hispanic*diabetes,
      hispanicXstroke = hispanic*stroke,
      hispanicXBMI = hispanic*BMI,
      hispanicCholesterol = hispanic*Cholesterol,
      hispanicXHeartDz = hispanic*HeartDz,
      hispanicXCongestiveHeart = hispanic*CongestiveHeart,
      hispanicXedu1_noed = hispanic*edu1_noed,
      hispanicXedu1_elem = hispanic*edu1_elem,
      hispanicXedu1_somehs = hispanic*edu1_somehs,
      # hispanicXedu1_hs = hispanic*edu1_hs,
      hispanicXedu1_somecol = hispanic*edu1_somecol,
      hispanicXedu1_colpstgrad = hispanic*edu1_colpstgrad,
      # hispanicXlang1_eng = hispanic*lang1_eng,
      # hispanicXlang1_span = hispanic*lang1_span,
      # hispanicXlang1_both = hispanic*lang1_both,
      hispanicXmarry_bi = hispanic*marry_bi
    )
    return(df1)
  }
  
  # Create separate wrappers for glm and step that will take manually provided 
  #   interactions
  SL.glm.KVD.manual.2interaction <- 
    function(Y, X, newX, family, obsWeights, model = TRUE, ...){
      if (is.matrix(X)) {
        X = as.data.frame(X)
      }
      X <- createInteractions(X)
      fit.glm <- glm(Y ~ ., data = X, family = family, weights = obsWeights, 
                     model = model)
      if (is.matrix(newX)) {
        
        newX = as.data.frame(newX)
        
      }
      newX <- createInteractions(newX)
      pred <- predict(fit.glm, newdata = newX, type = "response")
      fit <- list(object = fit.glm)
      class(fit) <- "SL.glm"
      out <- list(pred = pred, fit = fit)
      return(out)
    }
  
  SL.step.KVD.manual.2interaction <- 
    function (Y, X, newX, family, direction = "both", trace = 0, k = 2, ...){
      X <- createInteractions(X)
      fit.glm <- glm(Y ~ ., data = X, family = family)
      fit.step <- step(fit.glm, direction = direction, trace = trace, 
                       k = k)
      newX <- createInteractions(newX)
      pred <- predict(fit.step, newdata = newX, type = "response")
      fit <- list(object = fit.step)
      out <- list(pred = pred, fit = fit)
      class(out$fit) <- c("SL.step")
      return(out)
    }
  
  SL.step.forward.KVD.manual.2interaction <- 
    function (Y, X, newX, family, direction = "forward", trace = 0, k = 2, ...){
      X <- createInteractions(X)
      fit.glm <- glm(Y ~ ., data = X, family = family)
      fit.step <- step(glm(Y ~ 1, data = X, family = family), 
                       scope = formula(fit.glm), direction = direction, 
                       trace = trace, k = k)
      newX <- createInteractions(newX)
      pred <- predict(fit.step, newdata = newX, type = "response")
      fit <- list(object = fit.step)
      out <- list(pred = pred, fit = fit)
      class(out$fit) <- c("SL.step")
      return(out)
    }
  
  #---- directory start ----
  directory = "/u/home/c/cshaw343/KD_bootstrapping/"
  
  #---- read in the data ----
  data <- read_csv(paste0(directory, "data/adc_chis2_am_09_clean.csv")) %>% 
    as.data.frame()
  
  #---- define SL library ----
  # Updated library
  SL.library <- c(
    "SL.glm.KVD.manual.2interaction",
    "SL.step.KVD.manual.2interaction",
    "SL.step.forward.KVD.manual.2interaction",
    "SL.earth", 
    "SL.gam", 
    "SL.nnet", 
    "SL.mean", 
    "SL.bayesglm")
  
  #---- seed setting ----
  set.seed(seed)
  
  #---- bootstrap the sample ----
  boot_sample <- 
    rbind(sample_n(data[data$adc == 0, ], size = sum(data$adc == 0), 
                   replace = TRUE), 
          sample_n(data[data$adc == 1, ], size = sum(data$adc == 1), 
                   replace = TRUE))
  
  #---- EHL adding code to make race, education, and language1 factors with uniform ref groups
  boot_sample$Edu_harm1 <- factor(boot_sample$Edu_harm1, 
                                  levels = c(3, 0, 1, 2, 4, 5))
  boot_sample$race <- factor(boot_sample$race, levels = c(3, 1, 2))
  boot_sample$language1 <- factor(boot_sample$language1, levels = c(1, 2, 3))
  
  chis <- boot_sample[boot_sample$adc == 0, ]
  p_adc <- sum(boot_sample$adc)/sum(chis$RAKEDW0)
  
  #---- start time ----
  start <- Sys.time()
  
  #---- **Logistic regression model ----
  p2 <- glm(adc ~ race + male + Edu_harm1 + Cholesterol + diabetes +
              rcs(Nage, knots = c(61,71,84)) + 
              rcs(BMI, knots = c(20.99,25.76,33.31)) +
              race*male + race*Edu_harm1 + race*Cholesterol + race*diabetes +
              race*(rcs(Nage, knots = c(61,71,84))) + 
              race*(rcs(BMI, knots = c(20.99,25.76,33.31))), 
            data = boot_sample, family = binomial(link = logit), 
            weights = boot_sample$RAKEDW0)
  
  #---- **GBM model ----
  p3 <- ps(chis ~ race + male + Nage + diabetes + stroke + BMI + Cholesterol + 
             HeartDz + CongestiveHeart + Edu_harm1 + language1 + marry_bi,
           data = boot_sample, 
           n.trees = 10000,
           interaction.depth = 2, 
           shrinkage = 0.01,
           stop.method="es.mean",
           estimand = "ATT",
           sampw = boot_sample$RAKEDW0, version = "legacy")
  
  #---- **Superlearner model ----
  # Put this in the bootstrap because we want X and Y to change throughout the 1,000 iterations
  df2 <- subset(boot_sample, select = c("adc", 
                                        "black", 
                                        "hispanic", 
                                        #"White", 
                                        "male",
                                        "Nage",
                                        "diabetes", 
                                        "stroke", 
                                        "BMI", 
                                        "Cholesterol",
                                        "HeartDz",
                                        "CongestiveHeart",
                                        "edu1_noed",
                                        "edu1_elem",
                                        "edu1_somehs",
                                        #"edu1_hs",
                                        "edu1_somecol",
                                        "edu1_colpstgrad",
                                        #"lang1_eng",
                                        "lang1_span",
                                        "lang1_both",
                                        "marry_bi",
                                        "RAKEDW0")) %>% na.omit()
  
  
  # Get data ready for SL
  # Outcome
  Y <- df2$adc
  # SL needs only independent vars for the X input
  X <- subset(df2, select= -c(adc, RAKEDW0))
  
  p4 <- SuperLearner(Y = Y, X = X, 
                     family = binomial(), SL.library = SL.library,
                     verbose = TRUE,
                     cvControl = list(stratifyCV = TRUE),
                     obsWeights = boot_sample$RAKEDW0)
  
  #generate conditional predicted probabilities for being in adc
  boot_sample$p2 <- predict.glm(p2, type = "response")
  boot_sample$p3_CHIS <- p3$ps[["es.mean.ATT"]]
  boot_sample$p3 <- 1 - boot_sample$p3_CHIS
  boot_sample$p4 <- p4$SL.predict
  
  #inverse odds weight is P(not adc|K=k) / P(adc|K=k)
  boot_sample$w2 <- (1 - boot_sample$p2)/(boot_sample$p2)
  boot_sample$w3 <- (1 - boot_sample$p3)/(boot_sample$p3)
  boot_sample$w4 <- (1 - boot_sample$p4)/(boot_sample$p4)
  
  #stabilized inverse odds weight is IOW * odds of being in adc
  boot_sample$sw2 <- (boot_sample$w2)*(p_adc/(1 - p_adc))
  boot_sample$sw2[boot_sample$adc == 0] <- 1
  
  boot_sample$sw3 <- (boot_sample$w3)*(p_adc/(1 - p_adc))
  boot_sample$sw3[boot_sample$adc == 0] <- 1 
  
  boot_sample$sw4 <- (boot_sample$w4)*(p_adc/(1 - p_adc))
  boot_sample$sw4[boot_sample$adc == 0] <- 1
  
  a <- boot_sample[boot_sample$adc == 1, ]
  
  #---- **Raking model ----
  adc.svy.unweighted <- svydesign(ids=~1, data = a)
  
  #---- ****sociodemographic factors ----
  
  chis_n_wtd<-sum(chis$RAKEDW0)
  adc_n<-sum(boot_sample$adc)
  
  race.dist <- data.frame(race = c("1", "2", "3"),
                            Freq = adc_n*c((crossprod(chis$black, chis$RAKEDW0)/chis_n_wtd), 
                                           (crossprod(chis$hispanic, chis$RAKEDW0)/chis_n_wtd), 
                                           (crossprod(chis$White, chis$RAKEDW0)/chis_n_wtd)))
  male.dist <- data.frame(male = c("0", "1"),
                          Freq =adc_n*c(((chis_n_wtd-crossprod(chis$male, chis$RAKEDW0))/chis_n_wtd), (crossprod(chis$male, chis$RAKEDW0)/chis_n_wtd)))
  agelt70.dist <- data.frame(agelt70 = c("0", "1"),
                          Freq =adc_n*c(((chis_n_wtd-crossprod(chis$agelt70, chis$RAKEDW0))/chis_n_wtd), (crossprod(chis$agelt70, chis$RAKEDW0)/chis_n_wtd)))
  age7080.dist <- data.frame(age7080 = c("0", "1"),
                          Freq =adc_n*c(((chis_n_wtd-crossprod(chis$age7080, chis$RAKEDW0))/chis_n_wtd), (crossprod(chis$age7080, chis$RAKEDW0)/chis_n_wtd)))
  agege80.dist <- data.frame(agege80 = c("0", "1"),
                          Freq =adc_n*c(((chis_n_wtd-crossprod(chis$agege80, chis$RAKEDW0))/chis_n_wtd), (crossprod(chis$agege80, chis$RAKEDW0)/chis_n_wtd)))
  
  Edu_harm1.dist <- data.frame(Edu_harm1 = c("0", "1", "2", "3", "4", "5"),
                               Freq = adc_n*c((sum(chis$RAKEDW0[chis$Edu_harm1==0])/chis_n_wtd), 
                                                             (sum(chis$RAKEDW0[chis$Edu_harm1==1])/chis_n_wtd), 
                                                             (sum(chis$RAKEDW0[chis$Edu_harm1==2])/chis_n_wtd), 
                                                             (sum(chis$RAKEDW0[chis$Edu_harm1==3])/chis_n_wtd), 
                                                             (sum(chis$RAKEDW0[chis$Edu_harm1==4])/chis_n_wtd), 
                                                             (sum(chis$RAKEDW0[chis$Edu_harm1==5])/chis_n_wtd)))
  
  #---- ****other covariates that had poor balance to rake on ----
  diabetes.dist <- data.frame(diabetes = c("0", "1"),
                          Freq =adc_n*c(((chis_n_wtd-crossprod(chis$diabetes, chis$RAKEDW0))/chis_n_wtd), (crossprod(chis$diabetes, chis$RAKEDW0)/chis_n_wtd)))
  Cholesterol.dist <- data.frame(Cholesterol = c("0", "1"),
                          Freq =adc_n*c(((chis_n_wtd-crossprod(chis$Cholesterol, chis$RAKEDW0))/chis_n_wtd), (crossprod(chis$Cholesterol, chis$RAKEDW0)/chis_n_wtd)))
  bmilt25.dist <- data.frame(bmilt25 = c("0", "1"),
                          Freq =adc_n*c(((chis_n_wtd-crossprod(chis$bmilt25, chis$RAKEDW0))/chis_n_wtd), (crossprod(chis$bmilt25, chis$RAKEDW0)/chis_n_wtd)))
  bmi2530.dist <- data.frame(bmi2530 = c("0", "1"),
                          Freq =adc_n*c(((chis_n_wtd-crossprod(chis$bmi2530, chis$RAKEDW0))/chis_n_wtd), (crossprod(chis$bmi2530, chis$RAKEDW0)/chis_n_wtd)))
  bmige30.dist <- data.frame(bmige30 = c("0", "1"),
                          Freq =adc_n*c(((chis_n_wtd-crossprod(chis$bmige30, chis$RAKEDW0))/chis_n_wtd), (crossprod(chis$bmige30, chis$RAKEDW0)/chis_n_wtd)))
  
  
  adc.svy.rake <- rake(design = adc.svy.unweighted,
                       sample.margins = list(~male, ~race,
                                             ~agelt70, ~age7080, ~agege80,
                                             ~Edu_harm1, ~diabetes, ~Cholesterol,
                                             ~bmilt25, ~bmi2530, ~bmige30),
                       population.margins = list(male.dist, race.dist,
                                                 agelt70.dist, age7080.dist, 
                                                 agege80.dist, Edu_harm1.dist, 
                                                 diabetes.dist, Cholesterol.dist,
                                                 bmilt25.dist, bmi2530.dist, 
                                                 bmige30.dist)
  )
  
  a$raked.weight <- adc.svy.rake$postStrata[[1]][[1]] %>% 
    attributes() %>%. [["weights"]]
  
  res <- as.numeric(rep(NA, 106))
  
  
  #EHL edit 5/18 to name vector:
    names(res)<-c("Overall_unw", "Black_unw", "Latino_unw", "White_unw",
                  "Overall_wtd_l", "Black_wtd_l", "Latino_wtd_l", "White_wtd_l",
                  "Overall_wtd_r", "Black_wtd_r", "Latino_wtd_r", "White_wtd_r",
                  "Overall_wtd_g", "Black_wtd_g", "Latino_wtd_g", "White_wtd_g",
                  "Overall_wtd_s", "Black_wtd_s", "Latino_wtd_s", "White_wtd_s",
                  "BW_PR_unw", "LW_PR_unw",
                  "BW_PD_unw", "LW_PD_unw",
                  "BW_OR_unw", "LW_OR_unw",
                  "BW_PR_wtd_l", "LW_PR_wtd_l",
                  "BW_PD_wtd_l", "LW_PD_wtd_l",
                  "BW_OR_wtd_l", "LW_OR_wtd_l",
                  "BW_PR_wtd_r", "LW_PR_wtd_r",
                  "BW_PD_wtd_r", "LW_PD_wtd_r",
                  "BW_OR_wtd_r", "LW_OR_wtd_r",
                  "BW_PR_wtd_g", "LW_PR_wtd_g",
                  "BW_PD_wtd_g", "LW_PD_wtd_g",
                  "BW_OR_wtd_g", "LW_OR_wtd_g",
                  "BW_PR_wtd_s", "LW_PR_wtd_s",
                  "BW_PD_wtd_s", "LW_PD_wtd_s",
                  "BW_OR_wtd_s", "LW_OR_wtd_s",
                  
                  "BW_PR_unw_chispop", "LW_PR_unw_chispop",
                  "BW_PD_unw_chispop", "LW_PD_unw_chispop",
                  "BW_OR_unw_chispop", "LW_OR_unw_chispop",
                  
                  "BW_PR_unw_unstd", "LW_PR_unw_unstd",
                  "BW_PD_unw_unstd", "LW_PD_unw_unstd",
                  "BW_OR_unw_unstd", "LW_OR_unw_unstd",
                  "BW_PR_wtd_unstd_l", "LW_PR_wtd_unstd_l",
                  "BW_PD_wtd_unstd_l", "LW_PD_wtd_unstd_l",
                  "BW_OR_wtd_unstd_l", "LW_OR_wtd_unstd_l",
                  "BW_PR_wtd_unstd_r", "LW_PR_wtd_unstd_r",
                  "BW_PD_wtd_unstd_r", "LW_PD_wtd_unstd_r",
                  "BW_OR_wtd_unstd_r", "LW_OR_wtd_unstd_r",
                  "BW_PR_wtd_unstd_g", "LW_PR_wtd_unstd_g",
                  "BW_PD_wtd_unstd_g", "LW_PD_wtd_unstd_g",
                  "BW_OR_wtd_unstd_g", "LW_OR_wtd_unstd_g",
                  "BW_PR_wtd_unstd_s", "LW_PR_wtd_unstd_s",
                  "BW_PD_wtd_unstd_s", "LW_PD_wtd_unstd_s",
                  "BW_OR_wtd_unstd_s", "LW_OR_wtd_unstd_s",
                  
                  "Black_unw_std", "Latino_unw_std", "White_unw_std",
                  "Black_unw_std_chispop", "Latino_unw_std_chispop", "White_unw_std_chispop",
                  "Black_wtd_std_l", "Latino_wtd_std_l", "White_wtd_std_l",
                  "Black_wtd_std_r", "Latino_wtd_std_r", "White_wtd_std_r",
                  "Black_wtd_std_g", "Latino_wtd_std_g", "White_wtd_std_g",
                  "Black_wtd_std_s", "Latino_wtd_std_s", "White_wtd_std_s", 
                  
                  "time_min", "seed")
    #End EHL edit 5/18
  
  #EHL releveling race to get correct reference comparison based on how below is coded
  a$race<-factor(a$race, levels=c(1,2,3))
  
  #unweighted
  res["Overall_unw"] <- data.frame(race = "overall", 
                       phyp = mean(a$Hypertension))[, "phyp"]
  res[c("Black_unw", "Latino_unw", "White_unw")] <- a %>% group_by(race) %>% summarise(phyp = mean(Hypertension)) %>% 
    data.frame() %>% dplyr::select("phyp") %>% t() %>% as.numeric()
  
  #weighted -- Logistic
  res["Overall_wtd_l"] <- data.frame(race = "overall", 
                       phyp = weighted.mean(a$Hypertension, a$sw2))[,"phyp"]
  res[c("Black_wtd_l", "Latino_wtd_l", "White_wtd_l")] <- a %>% group_by(race) %>% 
    summarise(phyp = weighted.mean(Hypertension, sw2)) %>% data.frame() %>% 
    dplyr::select("phyp") %>% t() %>% as.numeric()
  
  # weighted -- RAKING
  res["Overall_wtd_r"] <- data.frame(race = "overall", 
                       phyp = weighted.mean(a$Hypertension, 
                                            a$raked.weight))[, "phyp"]
  res[c("Black_wtd_r", "Latino_wtd_r", "White_wtd_r")] <- a %>% group_by(race) %>% 
    summarise(phyp = weighted.mean(Hypertension, raked.weight)) %>% 
    data.frame() %>% dplyr::select("phyp") %>% t() %>% as.numeric()
  
  # weighted -- GBM
  res["Overall_wtd_g"] <- data.frame(race = "overall", 
                        phyp = weighted.mean(a$Hypertension, a$sw3))[,"phyp"]
  res[c("Black_wtd_g", "Latino_wtd_g", "White_wtd_g")] <- a %>% group_by(race) %>% 
    summarise(phyp = weighted.mean(Hypertension, sw3)) %>% data.frame() %>% 
    dplyr::select("phyp") %>% t() %>% as.numeric()
  
  # weighted -- SUPERLEARNER
  res["Overall_wtd_s"] <- data.frame(race = "overall", 
                        phyp = weighted.mean(a$Hypertension, a$sw4))[,"phyp"]
  res[c("Black_wtd_s", "Latino_wtd_s", "White_wtd_s")] <- a %>% group_by(race) %>% 
    summarise(phyp = weighted.mean(Hypertension, sw4)) %>% data.frame() %>% 
    dplyr::select("phyp") %>% t() %>% as.numeric()
  
  #unweighted std
  #Define age/sex distribution of ADC (unweighted)
  #EHL update to come from original dataset, not bootstrap sample.
  adc_total <- sum(data$adc)
  agesex_totals_a <- data %>% filter(adc == 1) %>% 
    group_by(agecat_h2, male) %>% summarise(n = n())
  agesex_totals_a$prop_agesex<-agesex_totals_a$n/adc_total  
  
  by_race <- a %>% group_by(race, agecat_h2, male) %>% 
    summarise(est_prop_unw = mean(Hypertension)) %>%
    left_join(., agesex_totals_a, by = c("agecat_h2", "male")) %>% 
    group_by(race) %>%
    summarise(phyp = crossprod(est_prop_unw, prop_agesex)) %>% data.frame()
  
  #EHL edit 5/18 adding standardized prevalences
  
  res[c("Black_unw_std", "Latino_unw_std", "White_unw_std")]<-by_race$phyp
  
  #End EHL edit 5/18 
  
  res[c("BW_PR_unw", "LW_PR_unw")] <- by_race$phyp[1:2]/by_race$phyp[3]
  res[c("BW_PD_unw", "LW_PD_unw")] <- by_race$phyp[1:2] - by_race$phyp[3]
  res[c("BW_OR_unw", "LW_OR_unw")] <- (by_race$phyp[1:2]/(1 - by_race$phyp[1:2]))/
    (by_race$phyp[3]/(1 - by_race$phyp[3]))
  
  
  #EHL update to come from original dataset, not bootstrap sample, only 3 agecats (agecat_h2).
  chis_orig <- data %>% filter(adc == 0) 
  chis_total <- sum(chis_orig$RAKEDW0)
  agesex_totals <- chis_orig %>% group_by(agecat_h2, male) %>% 
    summarise(n = sum(RAKEDW0))
  agesex_totals$prop_agesex <- agesex_totals$n/chis_total
  
  #EHL 5/18 edit add ADC std to original CHIS
      by_race <- a %>% group_by(race, agecat_h2, male) %>% 
        summarise(est_prop_unw = mean(Hypertension)) %>%
        left_join(., agesex_totals, by = c("agecat_h2", "male")) %>% 
        group_by(race) %>%
        summarise(phyp = crossprod(est_prop_unw, prop_agesex)) %>% data.frame()
      
      #EHL edit 5/18 adding standardized prevalences
      
      res[c("Black_unw_std_chispop", "Latino_unw_std_chispop", "White_unw_std_chispop")]<-by_race$phyp
      
      
      res[c("BW_PR_unw_chispop", "LW_PR_unw_chispop")] <- by_race$phyp[1:2]/by_race$phyp[3]
      res[c("BW_PD_unw_chispop", "LW_PD_unw_chispop")] <- by_race$phyp[1:2] - by_race$phyp[3]
      res[c("BW_OR_unw_chispop", "LW_OR_unw_chispop")] <- (by_race$phyp[1:2]/(1 - by_race$phyp[1:2]))/
        (by_race$phyp[3]/(1 - by_race$phyp[3]))
  
      #End EHL edit 5/18 
      
  #weighted std to CHIS (original dataset)
  by_race_w <- a %>% group_by(race, agecat_h2, male) %>%  
    summarise(est_prop_wtd = weighted.mean(Hypertension, sw2)) %>%
    left_join(., agesex_totals, by = c("agecat_h2", "male")) %>% 
    group_by(race) %>%
    summarise(phyp = crossprod(est_prop_wtd, prop_agesex)) %>% data.frame()
  
  
  #EHL edit 5/18 adding standardized prevalences
  
    res[c("Black_wtd_std_l", "Latino_wtd_std_l", "White_wtd_std_l")]<-by_race_w$phyp
  
  #End EHL edit 5/18 
    
  res[c("BW_PR_wtd_l", "LW_PR_wtd_l")] <- by_race_w$phyp[1:2]/by_race_w$phyp[3]
  res[c("BW_PD_wtd_l", "LW_PD_wtd_l")] <- by_race_w$phyp[1:2] - by_race_w$phyp[3]
  res[c("BW_OR_wtd_l", "LW_OR_wtd_l")] <- (by_race_w$phyp[1:2]/(1 - by_race_w$phyp[1:2]))/
    (by_race_w$phyp[3]/(1 - by_race_w$phyp[3]))
  
  by_race_w <- a %>% group_by(race, agecat_h2, male) %>% 
    summarise(est_prop_wtd = weighted.mean(Hypertension, raked.weight)) %>%
    left_join(., agesex_totals, by = c("agecat_h2", "male")) %>% 
    group_by(race) %>%
    summarise(phyp = crossprod(est_prop_wtd, prop_agesex)) %>% data.frame()
  
  #EHL edit 5/18 adding standardized prevalences
  
  res[c("Black_wtd_std_r", "Latino_wtd_std_r", "White_wtd_std_r")]<-by_race_w$phyp
  
  #End EHL edit 5/18 
  
  res[c("BW_PR_wtd_r", "LW_PR_wtd_r")] <- by_race_w$phyp[1:2]/by_race_w$phyp[3]
  res[c("BW_PD_wtd_r", "LW_PD_wtd_r")] <- by_race_w$phyp[1:2] - by_race_w$phyp[3]
  res[c("BW_OR_wtd_r", "LW_OR_wtd_r")] <- (by_race_w$phyp[1:2]/(1 - by_race_w$phyp[1:2]))/
    (by_race_w$phyp[3]/(1-by_race_w$phyp[3]))
  
  by_race_w <- a %>% group_by(race, agecat_h2, male) %>% 
    summarise(est_prop_wtd = weighted.mean(Hypertension, sw3)) %>%
    left_join(., agesex_totals, by = c("agecat_h2", "male")) %>% 
    group_by(race) %>%
    summarise(phyp = crossprod(est_prop_wtd, prop_agesex)) %>% data.frame()
  
  #EHL edit 5/18 adding standardized prevalences
  
  res[c("Black_wtd_std_g", "Latino_wtd_std_g", "White_wtd_std_g")]<-by_race_w$phyp
  
  #End EHL edit 5/18 
  
  res[c("BW_PR_wtd_g", "LW_PR_wtd_g")] <- by_race_w$phyp[1:2]/by_race_w$phyp[3]
  res[c("BW_PD_wtd_g", "LW_PD_wtd_g")] <- by_race_w$phyp[1:2] - by_race_w$phyp[3]
  res[c("BW_OR_wtd_g", "LW_OR_wtd_g")] <- (by_race_w$phyp[1:2]/(1 - by_race_w$phyp[1:2]))/
    (by_race_w$phyp[3]/(1 - by_race_w$phyp[3]))
  
  by_race_w <- a %>% group_by(race, agecat_h2, male) %>%  
    summarise(est_prop_wtd = weighted.mean(Hypertension, sw4)) %>%
    left_join(., agesex_totals, by = c("agecat_h2", "male")) %>% 
    group_by(race) %>%
    summarise(phyp = crossprod(est_prop_wtd, prop_agesex)) %>% data.frame()
  
  
  #EHL edit 5/18 adding standardized prevalences
  
  res[c("Black_wtd_std_s", "Latino_wtd_std_s", "White_wtd_std_s")]<-by_race_w$phyp
  
  #End EHL edit 5/18 
  
  res[c("BW_PR_wtd_s", "LW_PR_wtd_s")] <- by_race_w$phyp[1:2]/by_race_w$phyp[3]
  res[c("BW_PD_wtd_s", "LW_PD_wtd_s")] <- by_race_w$phyp[1:2] - by_race_w$phyp[3]
  res[c("BW_OR_wtd_s", "LW_OR_wtd_s")] <- (by_race_w$phyp[1:2]/(1 - by_race_w$phyp[1:2]))/
    (by_race_w$phyp[3]/(1 - by_race_w$phyp[3]))
  
  
  #EHL edit 5/18 Adding unstandardized inequalities for all approaches
  
      res["BW_PR_unw_unstd"]<-res["Black_unw"]/res["White_unw"]
      res["LW_PR_unw_unstd"]<-res["Latino_unw"]/res["White_unw"]
      res["BW_PD_unw_unstd"]<-res["Black_unw"]-res["White_unw"]
      res["LW_PD_unw_unstd"]<-res["Latino_unw"]-res["White_unw"]
      res["BW_OR_unw_unstd"]<-(res["Black_unw"]/(1-res["Black_unw"]))/(res["White_unw"]/(1-res["White_unw"]))
      res["LW_OR_unw_unstd"]<-(res["Latino_unw"]/(1-res["Latino_unw"]))/(res["White_unw"]/(1-res["White_unw"]))
      
      res["BW_PR_wtd_unstd_l"]<-res["Black_wtd_l"]/res["White_wtd_l"]
      res["LW_PR_wtd_unstd_l"]<-res["Latino_wtd_l"]/res["White_wtd_l"]
      res["BW_PD_wtd_unstd_l"]<-res["Black_wtd_l"]-res["White_wtd_l"]
      res["LW_PD_wtd_unstd_l"]<-res["Latino_wtd_l"]-res["White_wtd_l"]
      res["BW_OR_wtd_unstd_l"]<-(res["Black_wtd_l"]/(1-res["Black_wtd_l"]))/(res["White_wtd_l"]/(1-res["White_wtd_l"]))
      res["LW_OR_wtd_unstd_l"]<-(res["Latino_wtd_l"]/(1-res["Latino_wtd_l"]))/(res["White_wtd_l"]/(1-res["White_wtd_l"]))
      
      res["BW_PR_wtd_unstd_r"]<-res["Black_wtd_r"]/res["White_wtd_r"]
      res["LW_PR_wtd_unstd_r"]<-res["Latino_wtd_r"]/res["White_wtd_r"]
      res["BW_PD_wtd_unstd_r"]<-res["Black_wtd_r"]-res["White_wtd_r"]
      res["LW_PD_wtd_unstd_r"]<-res["Latino_wtd_r"]-res["White_wtd_r"]
      res["BW_OR_wtd_unstd_r"]<-(res["Black_wtd_r"]/(1-res["Black_wtd_r"]))/(res["White_wtd_r"]/(1-res["White_wtd_r"]))
      res["LW_OR_wtd_unstd_r"]<-(res["Latino_wtd_r"]/(1-res["Latino_wtd_r"]))/(res["White_wtd_r"]/(1-res["White_wtd_r"]))
      
      res["BW_PR_wtd_unstd_g"]<-res["Black_wtd_g"]/res["White_wtd_g"]
      res["LW_PR_wtd_unstd_g"]<-res["Latino_wtd_g"]/res["White_wtd_g"]
      res["BW_PD_wtd_unstd_g"]<-res["Black_wtd_g"]-res["White_wtd_g"]
      res["LW_PD_wtd_unstd_g"]<-res["Latino_wtd_g"]-res["White_wtd_g"]
      res["BW_OR_wtd_unstd_g"]<-(res["Black_wtd_g"]/(1-res["Black_wtd_g"]))/(res["White_wtd_g"]/(1-res["White_wtd_g"]))
      res["LW_OR_wtd_unstd_g"]<-(res["Latino_wtd_g"]/(1-res["Latino_wtd_g"]))/(res["White_wtd_g"]/(1-res["White_wtd_g"]))
      
      res["BW_PR_wtd_unstd_s"]<-res["Black_wtd_s"]/res["White_wtd_s"]
      res["LW_PR_wtd_unstd_s"]<-res["Latino_wtd_s"]/res["White_wtd_s"]
      res["BW_PD_wtd_unstd_s"]<-res["Black_wtd_s"]-res["White_wtd_s"]
      res["LW_PD_wtd_unstd_s"]<-res["Latino_wtd_s"]-res["White_wtd_s"]
      res["BW_OR_wtd_unstd_s"]<-(res["Black_wtd_s"]/(1-res["Black_wtd_s"]))/(res["White_wtd_s"]/(1-res["White_wtd_s"]))
      res["LW_OR_wtd_unstd_s"]<-(res["Latino_wtd_s"]/(1-res["Latino_wtd_s"]))/(res["White_wtd_s"]/(1-res["White_wtd_s"]))

      
    #End EHL edit 5/18
      
  #---- total time in minutes ----
  res["time_min"] <- as.numeric(difftime(Sys.time(), start, units = "mins"))
  
  #---- save seed ----
  res["seed"] <- seed
  
  #---- save results ----
      
      #EHL edit 5/18. Crystal to check! Save CSV output, with column headers if file does not exist, without if it does.
      if (file.exists(paste0(directory, "results/bootstrap_runs.csv"))==F){ 
        write.table(as.data.frame(t(res)), paste0(directory, "results/bootstrap_runs.csv"), 
                    col.names=T, row.names=F, sep=",", append=TRUE)                            
      } else {
        
        write.table(as.data.frame(t(res)), 
                    paste0(directory, "results/bootstrap_runs.csv"), col.names=F, row.names=F, sep=",", append = TRUE)
      }                   
      
}



## Read in the arguments listed in the:
## R CMD BATCH --no-save --no-restore '--args ...'
## expression:
args=(commandArgs(TRUE))

## args is now a list of character vectors

## Check to see if arguments are passed and set default values if not,
## then cycle through each element of the list and evaluate the expressions.
if(length(args)==0){
  print("No arguments supplied.")
  ##supply default values
  seed = 123
}else{
  for(i in 1:length(args)){
    eval(parse(text=args[[i]]))
  }
}
## Now print values just to make sure:
print(seed)

#---- run code ----
analysis(seed = seed)
