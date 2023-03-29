

library(dplyr,lib='~/usr/localR/library')
library(ggplot2,lib='~/usr/localR/library')
library(ggbeeswarm,lib='~/usr/localR/library')

data <- read.csv(file = "invar.csv",  dec = ".", sep = ",",  header = TRUE, stringsAsFactors = FALSE)

fvA <- subset(data, Tool=="itstools")
fvB <- subset(data, Tool=="tina")

colnames(fvA) <- paste(colnames(fvA), "its", sep = "_")
colnames(fvB) <- paste(colnames(fvB), "tina", sep = "_")

fvA <- dplyr::rename(fvA, Model = Model_its)
fvB <- dplyr::rename(fvB, Model = Model_tina)

fperf = inner_join(fvA, fvB)

fperf <- mutate(fperf, verdict.color = ifelse(
  Status_its == "OK" & Status_tina != "OK","ITS wins", ifelse(Status_tina == "OK" & Status_its != "OK","Tina wins", "equal")));

# fperf <- mutate(fperf, techAgree = ifelse(ConstP_its + NBP_its == NBP_tina,"same", "different"));

fperf <- subset(fperf, grepl("-PT-",Model,fixed=TRUE))


timereal <- ggplot(fperf, 
                   aes(x=Time_its, y=Time_tina, color=verdict.color)) + 
  geom_point() + 
  scale_y_continuous(trans='log10', labels = function(x) format(x, scientific = FALSE)) +
  scale_x_continuous(trans='log10', labels = function(x) format(x, scientific = FALSE))  + 
  geom_abline(intercept = 0, slope = 1)  + 
  scale_color_manual(values = c("orange", "blue","black")) +
  scale_fill_hue(l=45) +
#  annotate("text", x=1200, y=10, label= nrow(subset(perf, Test.fin_vA < Test.fin_vB))) + 
#  annotate("text", x=10, y=1200, label= nrow(subset(perf, Test.fin_vA > Test.fin_vB))) + 
  guides(color=guide_legend(element_blank())) +  
  theme(legend.position = c(0.92, 0.05)) +
  xlab("Time (in msec.) for ITS") +
  ylab("Time (in msec.) for Tina") +
  ggtitle("Run time in mseconds as measured by time command")

fperf <- mutate(fperf, RepTime_its = ifelse(
  Status_its == "OK",PTime_its+TTime_its, 120000));

fperf <- mutate(fperf, RepTime_tina = ifelse(
  Status_tina == "OK",PTime_tina+TTime_tina, 120000));

timereal2 <- ggplot(fperf, 
                   aes(x=RepTime_its, y=RepTime_tina, color=verdict.color)) + 
  geom_point() + 
  scale_y_continuous(trans='log10', labels = function(x) format(x, scientific = FALSE)) +
  scale_x_continuous(trans='log10', labels = function(x) format(x, scientific = FALSE))  + 
  geom_abline(intercept = 0, slope = 1)  + 
  scale_color_manual(values = c("orange", "blue","black")) +
  scale_fill_hue(l=45) +
  #  annotate("text", x=1200, y=10, label= nrow(subset(perf, Test.fin_vA < Test.fin_vB))) + 
  #  annotate("text", x=10, y=1200, label= nrow(subset(perf, Test.fin_vA > Test.fin_vB))) + 
  guides(color=guide_legend(element_blank())) +  
  theme(legend.position = c(0.92, 0.05)) +
  xlab("Time (in msec.) for ITS") +
  ylab("Time (in msec.) for Tina") +
  ggtitle("Run time in mseconds for computing PFlow+TFlow as reported by tools")


memreal2 <- ggplot(fperf, 
                    aes(x=Mem_its, y=Mem_tina, color=verdict.color)) + 
  geom_point() + 
  scale_y_continuous(trans='log10', labels = function(x) format(x, scientific = FALSE)) +
  scale_x_continuous(trans='log10', labels = function(x) format(x, scientific = FALSE))  + 
  geom_abline(intercept = 0, slope = 1)  + 
  scale_color_manual(values = c("orange", "blue","black")) +
  scale_fill_hue(l=45) +
  #  annotate("text", x=1200, y=10, label= nrow(subset(perf, Test.fin_vA < Test.fin_vB))) + 
  #  annotate("text", x=10, y=1200, label= nrow(subset(perf, Test.fin_vA > Test.fin_vB))) + 
  guides(color=guide_legend(element_blank())) +  
  theme(legend.position = c(0.92, 0.05)) +
  xlab("Mem (in KB.) for ITS") +
  ylab("Mem (in KB.) for Tina") +
  ggtitle("Resident shared size in KB for computing PFlow+TFlow as reported by time command")


#perf$deltatime<-perf$duration.ms._vA-perf$duration.ms._vB
#perf$deltatest<-perf$Test.fin_vA-perf$Test.fin_vB

pdf(file = "fplots.pdf")    #paper = "a4r"
# print(timereal)
print(timereal2)
print(memreal2)
dev.off()

