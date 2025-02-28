################################################################################
#### Simulation function ####

### Arguments
# climate_data : data frame of climate data; columns represent months, rows represent years. Data should be detrended.
# noise : vector containing noise values for each scenario, e.g., c(0.13, 0.27, 0.5, 1).
# pop_size : integer specifying population size, treated as infinite if set to "true"; e.g., 1000.
# N_tree_sample : vector of integers specifying the number of trees sampled per scenario, e.g., c(5, 10, 20).
# driver_season : vector of integers representing the month columns to use as the climate driver for analysis, e.g., c(3, 4) for March and April.
# analysis_season : vector of integers for months in the analysis, same structure as driver_season.
# target_cor : numeric target correlation value for determining population structure.
# target_rbt : numeric target Rbt value for determining population structure.
# rep_sub_core : integer; number of "core" subsamples for each tree, default = 100.
# rep_sub_pop : integer; number of population subsampling repetitions, default = 100.
# graph : logical; if TRUE, produces graphs in output.
# color1 : color name for plot gradient start, e.g., "white".
# color2 : color name for plot gradient end, e.g., "green".
# ylim : vector specifying y-axis limits for plots, e.g., c(-1, 1).
# xlim : vector specifying x-axis limits for plots, e.g., c(0, 1).
# p_value : numeric; significance threshold for correlation p-values, default = 0.01.

Climate_cor_simule <- function(climate_data,
                               noise,
                               pop_size,
                               N_tree_sample,
                               driver_season,
                               analysis_season,
                               target_cor,
                               target_rbt,
                               rep_sub_core = 100,
                               rep_sub_pop = 100,
                               graph = TRUE,
                               color1 = "white",
                               color2 = "green",
                               ylim = c(-1, 1),
                               xlim = c(0, 1),
                               p_value = 0.01) {
  require(dplR)

  sd_truth <- target_cor_to_sd(target_cor)
  sd_sub <- target_rbt_to_sd(target_rbt)
  climate <- data.frame(scale(climate_data))
  NROW <- nrow(climate)
  N_noise <- length(noise)

  if (length(driver_season) == 1) {
    data_truth <- climate[, driver_season] + rnorm(nrow(climate), sd = sd_truth)
  } else {
    data_truth <- scale(rowMeans(climate[, driver_season])) + rnorm(nrow(climate), sd = sd_truth)
  }

  data_truth <- scale(data_truth)

  data_pool <- matrix(NA, nrow = NROW, ncol = pop_size)

  for (i in 1:pop_size) {
    data_pool[, i] <- (data_truth + rnorm(n = NROW, sd = sd_sub))
  }

  data_pool <- scale(data_pool)
  truth_rbt <- mean(cor(data_pool))
  if (length(analysis_season) == 1) {
    truth_cor <- cor(rowMeans(data_pool), climate[, analysis_season])
  } else {
    truth_cor <- cor(rowMeans(data_pool), rowMeans(climate[, analysis_season]))
  }

  signific_cor <- N_pval_to_pearson(NROW, p_value)
  Output <- data.frame(N_tree = NA, noise = NA, Cor = NA, rbt = NA)

  for (n in N_tree_sample) {
    for (j in 1:length(noise)) {
      data_sub <- rep(list(matrix(NA, ncol = rep_sub_core, nrow = NROW)), pop_size)
      output <- NA
      for (s in 1:pop_size) {
        for (i in 1:rep_sub_core) {
          data_sub[[s]][, i] <- data_pool[, s] + rnorm(NROW, 0, noise[j])
        }
      }

      rbt <- NA
      COR2 <- NA
      COR <- NA

      for (i in 1:rep_sub_pop) {
        trees <- sample(pop_size, n)
        sub_pop <- matrix(NA, ncol = n, nrow = NROW)
        for (p in 1:n) {
          sub_pop[, p] <- data_sub[[trees[p]]][, sample(1:rep_sub_core, 1)]
        }
        CORsub_pop <- cor(sub_pop)
        diag(CORsub_pop) <- NA
        rbt[i] <- mean(CORsub_pop, na.rm = T)
        if (length(analysis_season) == 1) {
          COR[i] <- cor(rowMeans(sub_pop), climate[, analysis_season])
        } else {
          COR[i] <- cor(rowMeans(sub_pop), rowMeans(climate[, analysis_season]))
        }
      }
      output <- data.frame(
        N_tree = rep(n, rep_sub_pop),
        noise = rep(noise[j], rep_sub_pop),
        Cor = COR,
        rbt = rbt
      )
      Output <- rbind(Output, output)
    }
  }
  Output <- Output[-1, ]

  if (graph == TRUE) {
    graph_out <- simule_graph_multi(Output, color1 = color1, color2 = color2, ylim = ylim, xlim = xlim, truth_cor = truth_cor, signific_cor = signific_cor)
    O <- list()
    O[[1]] <- Output
    O[[2]] <- graph_out
    O[[3]] <- truth_rbt
    O[[4]] <- truth_cor
    O[[5]] <- signific_cor
    names(O) <- c("Ouput", "graph", "truth_rbt", "truth_cor", "signific_cor")
    O
  } else {
    Oo <- list()
    Oo[[1]] <- Output
    Oo[[2]] <- truth_rbt
    Oo[[3]] <- truth_cor
    Oo[[5]] <- signific_cor
    names(Oo) <- c("Ouput", "truth_rbt", "truth_cor", "signific_cor")
    Oo
  }
}

################################################################################
#### EPS, Rbt, and Pearson Correlation Helper Functions ####

### Arguments
# Rbar : numeric, mean inter-series correlation
# EPS : numeric, Expressed Population Signal.
# N : integer, sample size.
# p_value : numeric, significance threshold (e.g., 0.01).
# x : numeric, target correlation or Rbt value (between 0 and 1).

rbar_to_eps <- function(Rbar, N) {
  EPS <- (N * Rbar) / (1 + (N - 1) * Rbar)
  return(EPS)
}
eps_to_rbar <- function(EPS, N) {
  Rbar <- EPS / (N - EPS * (N - 1))
  return(Rbar)
}

N_pval_to_pearson <- function(N, p_value) {
  df <- N - 2
  t_stat <- qt(p_value / 2, df, lower.tail = FALSE)
  r <- sqrt(t_stat^2 / (t_stat^2 + df))
  return(r)
}

target_cor_to_sd <- function(x) {
  sqrt(1 - x^2) / x -> sd
  sd
}
target_rbt_to_sd <- function(x) {
  sqrt(1 - x) / sqrt(x) -> sd
  sd
}


################################################################################
#### graph function ####

### Arguments ###
# data : data frame containing the Rbt values and correlation coefficients - format of the simulation function output 1
# color1 : character, starting color for the plot gradient (default = "green").
# color2 : character, ending color for the plot gradient (default = "white").
# text_size : integer, size of axis and legend title text (default = 18).
# ax_text_size : integer, size of axis text labels (default = 15).
# ylim : numeric vector, limits for the y-axis, e.g., c(-1, 1).
# xlim : numeric vector, limits for the x-axis, e.g., c(0, 1).
# truth_cor : numeric, reference correlation value to highlight in the plot (default = 0).
# linewidth : numeric, line width for plot lines (default = 1.2).
# point_size : numeric, size of plot points (default = 4).
# signific_cor : numeric, correlation significance threshold to highlight in the plot (default = 0).

simule_graph_uniq <- function(data,
                              color1 = "green",
                              color2 = "white",
                              text_size = 18,
                              ax_text_size = 15,
                              ylim = c(-1, 1),
                              xlim = c(0, 1),
                              truth_cor = 0,
                              linewidth = 1.2,
                              point_size = 4,
                              signific_cor = 0) {
  require(tidyverse)

  Output_graph <- list()
  data$noise %>%
    as.factor() %>%
    levels() %>%
    length() -> N_noise
  color_grad <- colorRampPalette(c(color1, color2))(N_noise)
  data$N_tree[1] -> n


  data$rbt %>% rbar_to_eps(n) -> data$EPS
  eps_breaks <- round(rbar_to_eps(seq(xlim[1], xlim[2], 0.1), n), digits = 2)
  gold_stand <- eps_to_rbar(0.85, n)
  Noisy_lim <- eps_to_rbar(0.5, n)

  G <- data %>% ggplot(aes(x = rbt, y = Cor)) +
    geom_point(size = point_size, shape = 21, aes(fill = as.factor(noise))) +
    labs(x = "Rbt", y = "Correlation coefficient", fill = "noise") +
    geom_hline(yintercept = truth_cor, linetype = 1, color = "blue", linewidth = linewidth) +
    geom_hline(yintercept = signific_cor, linetype = 3, color = "black", linewidth = linewidth) +
    geom_vline(xintercept = Noisy_lim, , linetype = 3, color = "black", linewidth = linewidth) +
    geom_vline(xintercept = gold_stand, , linetype = 2, color = "red3", linewidth = linewidth) +
    scale_fill_manual(name = "Noise", values = color_grad) +
    scale_x_continuous(
      name = "Rbt",
      limits = xlim,
      sec.axis = sec_axis(~ rbar_to_eps(., n), name = "EPS", breaks = eps_breaks)
    ) +
    ylim(ylim) +
    theme_minimal() +
    theme(
      axis.title.x.bottom = element_text(size = text_size, color = "black"),
      axis.title.x.top = element_text(size = text_size, color = "black"),
      axis.title.y = element_text(size = text_size, color = "black"),
      axis.text = element_text(size = ax_text_size, color = "black"),
      legend.title = element_text(size = text_size),
      legend.text = element_text(size = ax_text_size)
    )
  G
}

###############################################################################
#### Multi-graph function ####
### Arguments ###
# see original graph function

simule_graph_multi <- function(Data,
                               color1 = "green",
                               color2 = "white",
                               text_size = 18,
                               ax_text_size = 15,
                               ylim = c(-1, 1),
                               xlim = c(0, 1),
                               truth_cor = 0,
                               linewidth = 1.2,
                               point_size = 4,
                               signific_cor = 0) {
  groupe_data <- split(Data, Data$N_tree)
  list_plot <- lapply(groupe_data, simule_graph_uniq,
    color1 = color1,
    color2 = color2,
    text_size = text_size,
    ax_text_size = ax_text_size,
    ylim = ylim,
    xlim = xlim,
    truth_cor = truth_cor,
    linewidth = linewidth,
    point_size = point_size,
    signific_cor = signific_cor
  )
  names(list_plot) <- paste0("_", levels(as.factor(Data$N_tree)), "_tree")
  list_plot
}

##############################################################################"
#### Tool graph ####
### Arguments ###
# data : data frame containing the Rbt values and correlation coefficients - format of the simulation function output 1
# text_size : integer, size of axis and legend text (default = 18).

Tool_graph <- function(Data,
                       text_size = 18) {
  require(tidyverse)
  require(reshape2)
  require(dplyr)

  Data$N_tree %>% unique() -> Ntree_values
  Data$rbt %>%
    quantile(probs = seq(0, 1, 0.2)) %>%
    round(digits = 2) -> borns


  RbarTot_ranges <- list()

  for (i in 1:(length(borns) - 1)) {
    range_name <- paste0(borns[i], "-", borns[i + 1])
    RbarTot_ranges[[range_name]] <- c(borns[i], borns[i + 1])
  }

  filter_data <- function(data, Ntree_value, RbarTot_min, RbarTot_max) {
    data %>%
      subset(N_tree == Ntree_value) %>%
      subset(rbt >= RbarTot_min & rbt < RbarTot_max)
  }

  filtered_data <- list()

  for (Ntree_value in Ntree_values) {
    for (range_name in names(RbarTot_ranges)) {
      RbarTot_min <- RbarTot_ranges[[range_name]][1]
      RbarTot_max <- RbarTot_ranges[[range_name]][2]


      filtered_data[[paste(Ntree_value, range_name, sep = "_")]] <-
        filter_data(Data, Ntree_value, RbarTot_min, RbarTot_max)
    }
  }

  table_tool <- data.frame(
    Trees = Ntree_values
  )


  for (range_name in names(RbarTot_ranges)) {
    table_tool[[paste(range_name, sep = "")]] <- sapply(Ntree_values, function(N) {
      data <- filtered_data[[paste(N, range_name, sep = "_")]]
      quantile(data$Cor, 0.975) - quantile(data$Cor, 0.025)
    })
  }


  table_tool

  data_long <- melt(table_tool, id.vars = "Trees", variable.name = "RbtType", value.name = "Value")

  data_long %>%
    mutate(Rbt = c(
      rep(mean(c(borns[1], borns[2])), length(Ntree_values)),
      rep(mean(c(borns[2], borns[3])), length(Ntree_values)),
      rep(mean(c(borns[3], borns[4])), length(Ntree_values)),
      rep(mean(c(borns[4], borns[5])), length(Ntree_values)),
      rep(mean(c(borns[5], borns[6])), length(Ntree_values))
    )) %>%
    mutate(EPS = rbar_to_eps(Rbt, Trees)) -> data_long



  data_long$Trees <- factor(data_long$Trees, levels = Ntree_values)


  (graph_tool <- ggplot(data_long, aes(x = RbtType, y = Trees, fill = Value)) +
    geom_tile(color = "white", linewidth = 2) + # White border for clarity
    scale_fill_stepsn(
      colors = c(
        "#053061",
        "#2166ac",
        "#4393c3",
        "#92c5de",
        "#f7f7f7",
        "#f4a582",
        "#d6604d",
        "#b2182b",
        "#67001f"
      ),
      breaks = seq(0, 0.4, 0.04),
      limits = c(0, 0.4)
    ) +
    scale_x_discrete() +
    labs(x = "Rbt", y = "Number of Trees", fill = "Cor spread") + # Labels
    geom_text(
      aes(
        label = round(EPS, 2),
        fontface = ifelse(EPS >= 0.85, "bold", "plain")
      ),
      color = "black", size = text_size / 3
    ) +
    theme_minimal() +
    theme(
      text = element_text(size = text_size),
      axis.text = element_text(size = text_size / 1.3),
      legend.key.size = unit(1, "cm")
    ))
}

