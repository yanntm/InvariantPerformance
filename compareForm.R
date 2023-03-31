

library(dplyr,lib='~/usr/localR/library')
library(ggplot2,lib='~/usr/localR/library')
library(ggbeeswarm,lib='~/usr/localR/library')

data <- read.csv(file = "invar.csv",  dec = ".", sep = ",",  header = TRUE, stringsAsFactors = FALSE)

fvA <- subset(data, Tool=="itstools")
#fvB <- subset(data, Tool=="tina4ti2")
fvB <- subset(data, Tool=="tina")

colnames(fvA) <- paste(colnames(fvA), "its", sep = "_")
colnames(fvB) <- paste(colnames(fvB), "tina", sep = "_")

fvA <- dplyr::rename(fvA, Model = Model_its)
fvB <- dplyr::rename(fvB, Model = Model_tina)

fperf = inner_join(fvA, fvB)

fperf <- mutate(fperf, verdict.color = ifelse(
    Status_its == "OK" & Status_tina != "OK","Only ITS solves", 
    ifelse(Status_tina == "OK" & Status_its != "OK","Only Tina solves", 
    ifelse(Status_tina == "OK" & Status_its == "OK","Both tools solve",
    "Both tools fail"))));

# fperf <- mutate(fperf, techAgree = ifelse(ConstP_its + NBP_its == NBP_tina,"same", "different"));

fperf <- subset(fperf, grepl("-PT-",Model,fixed=TRUE))


timereal <- ggplot(fperf, 
                   aes(x=Time_its, y=Time_tina, color=verdict.color)) + 
  geom_point() + 
  scale_y_continuous(trans='log10', labels = function(x) format(x, scientific = FALSE)) +
  scale_x_continuous(trans='log10', labels = function(x) format(x, scientific = FALSE))  + 
  geom_abline(intercept = 0, slope = 1)  + 
  scale_color_manual(values = c("orange", "blue","green","red")) +
  scale_fill_hue(l=45) +
#  annotate("text", x=1200, y=10, label= nrow(subset(perf, Test.fin_vA < Test.fin_vB))) + 
#  annotate("text", x=10, y=1200, label= nrow(subset(perf, Test.fin_vA > Test.fin_vB))) + 
  guides(color=guide_legend(element_blank())) +  
#  theme(legend.position = c(30.0, 3.0)) +
  xlab("Time for ITS") +
  ylab("Time for Tina") +
  ggtitle("Run time in as measured by time")

fperf <- mutate(fperf, RepTime_its = ifelse(
  Status_its == "OK",PTime_its+TTime_its, 120000));

fperf <- mutate(fperf, Mem_its = ifelse(
  Status_its == "OK",Mem_its, 16000000));


fperf <- mutate(fperf, RepTime_tina = ifelse(
  Status_tina == "OK",PTime_tina+TTime_tina, 120000));

fperf <- mutate(fperf, Mem_tina = ifelse(
  Status_tina == "OK",Mem_tina, 16000000));


timereal2 <- ggplot(fperf, 
                   aes(x=RepTime_its, y=RepTime_tina, color=verdict.color)) + 
  geom_point() + 
  scale_y_continuous(trans='log10', breaks=c(10,100,1000,10000,60000,120000),labels = c("0.01s","0.1s","1s","10s","1min","2min")) +
  scale_x_continuous(trans='log10', breaks=c(10,100,1000,10000,60000,120000),labels = c("0.01s","0.1s","1s","10s","1min","2min"))  + 
  geom_abline(intercept = 0, slope = 1)  + 
  scale_color_manual(values = c("orange", "blue","black")) +
  scale_fill_hue(l=45) +
  #  annotate("text", x=1200, y=10, label= nrow(subset(perf, Test.fin_vA < Test.fin_vB))) + 
  #  annotate("text", x=10, y=1200, label= nrow(subset(perf, Test.fin_vA > Test.fin_vB))) + 
  guides(color=guide_legend(element_blank())) +  
  theme(legend.position = c(0.9, 0.1)) +
  xlab("Time for ITS") +
  ylab("Time for Tina") +
  ggtitle("Run time to compute PFlow+TFlow as reported by tools")


memreal2 <- ggplot(fperf, 
                    aes(x=Mem_its, y=Mem_tina, color=verdict.color)) + 
  geom_point() + 
  scale_y_continuous(trans='log10', breaks=c(10000,100000,1000000,3000000,10000000,16000000),labels = c("10MB","100MB","1GB","3GB","10GB","16GB")) +
  scale_x_continuous(trans='log10', breaks=c(10000,100000,1000000,3000000,10000000,16000000),labels = c("10MB","100MB","1GB","3GB","10GB","16GB"))  + 
  geom_abline(intercept = 0, slope = 1)  + 
  scale_color_manual(values = c("orange", "blue","black")) +
  scale_fill_hue(l=45) +
  #  annotate("text", x=1200, y=10, label= nrow(subset(perf, Test.fin_vA < Test.fin_vB))) + 
  #  annotate("text", x=10, y=1200, label= nrow(subset(perf, Test.fin_vA > Test.fin_vB))) + 
  guides(color=guide_legend(element_blank())) +  
  theme(legend.position = c(0.9, 0.1)) +
  xlab("Mem for ITS") +
  ylab("Mem for Tina") +
  ggtitle("Resident shared size to compute PFlow+TFlow as reported by time")


#perf$deltatime<-perf$duration.ms._vA-perf$duration.ms._vB
#perf$deltatest<-perf$Test.fin_vA-perf$Test.fin_vB

message("Total problems :",nrow(fperf))
message("ITS solves :",sum(fperf$Status_its == "OK"))
message("ITS timeout :",sum(fperf$Status_its == "TO"))
message("Tina solves :",sum(fperf$Status_tina == "OK"))
message("Tina timeout :",sum(fperf$Status_tina == "TO"))
message("Tina mem overflow :",sum(fperf$Status_tina == "MOVF"))
message("Tina error :",sum(fperf$Status_tina == "ERR"))


svg("time.svg")
print(timereal2)
dev.off()

svg("mem.svg")
print(memreal2)
dev.off()

pdf(file = "time.pdf")    #paper = "a4r"
print(timereal2)
dev.off()

pdf(file = "mem.pdf")    #paper = "a4r"
print(memreal2)
dev.off()

pdf(file = "fplots.pdf")    #paper = "a4r"
# print(timereal)
print(timereal2)
print(memreal2)
dev.off()


pdf(file = "fplots.pdf")    #paper = "a4r"
# print(timereal)
print(timereal2)
print(memreal2)
dev.off()


