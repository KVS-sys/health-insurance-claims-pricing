library(tidyverse)

health <- read.csv("health_analysis_base.csv")

dim(health)
 class(health)
names(health) 
glimpse(health)

health <- health %>%
  mutate(    across(      c(sex, region, urban_rural, education, marital_status,employment_status, smoker, alcohol_freq, plan_type, network_tier),as.factor ))

class(health$plan_type)
class(health$sex)

portfolio_summary <- health %>% 
 summarise(  num_of_people = n() , pct_people_with_atleast_one_claim = sum(has_claim)*100 /n()  ,total_number_of_claims =sum(claims_count) ,claim_per_person = sum(claims_count)/n()  ,  total_paid = sum(total_claims_paid), claim_payment_per_person = sum(total_claims_paid)/ n(), loss_ratio_pct =round(sum(total_claims_paid)*100 /sum(annual_premium),2))
 
portfolio_summary

claim_paid_summary <- health %>%
  summarise(Minimum = min(total_claims_paid),Median =median(total_claims_paid), Mean = mean(total_claims_paid), p75 = quantile(total_claims_paid,0.75),p90 = quantile(total_claims_paid,0.90),p95 = quantile(total_claims_paid,0.95),p99 = quantile(total_claims_paid,0.99),Maximum = max(total_claims_paid))

claim_paid_summary


health %>%
  filter(total_claims_paid>0) %>%
 ggplot(aes(total_claims_paid)) +
 geom_histogram(bins = 50)+
 labs(title = "Claims paid" , x = "Total claims paid", y = "Count")+
  scale_x_log10(breaks = c(1, 10, 100, 1000, 10000, 100000), labels = scales::label_dollar()  )

claims_count_summary <- health %>%
  summarise(Mean = mean(claims_count) ,Var =var(claims_count), pct_zero = mean(claims_count == 0)*100 , Max =max(claims_count))
  
claims_count_summary


poisson_expected_zero_pct <- exp(-mean(health$claims_count))*100

poisson_expected_zero_pct 

claim_mean <-mean(health$claims_count)
claim_variance <- var(health$claims_count)
nb_size <- claim_mean^2/(claim_variance- claim_mean)

nb_expected_zero_pct <- 
  dnbinom(0,size = nb_size, mu = claim_mean)*100

nb_expected_zero_pct
# The negative binomial expected zero-claim percentage is close to the observed zero-claim percentage.
# This supports testing negative binomial regression as a candidate; it does not establish the best conditional model.


set.seed(2026)

train_rows <- sample(seq_len(nrow(health)),size= 0.80* nrow(health), replace =FALSE)
health_train <- health[train_rows,]
health_test <- health[-train_rows,]

nrow(health_train)
nrow(health_test)

length(intersect(health_train$person_id, health_test$person_id))

# above we make two samples one for training the model and one for testing the model 

frequency_formula <- claims_count ~ age+sex+region+urban_rural+bmi+smoker+chronic_count+plan_type +network_tier+deductible +copay



frequency_poisson <- glm(frequency_formula, data =health_train, family = poisson(link = "log"))
frequency_nb <- MASS:: glm.nb(frequency_formula,data = health_train)
AIC(frequency_poisson, frequency_nb)
# NB model aic is far better compared to the poission model 


health_test <- health_test %>%
  mutate(pred_poission = predict(frequency_poisson,newdata = health_test,type = "response"),pred_nb =predict(frequency_nb,newdata =health_test, type = "response"))

health_test %>% 
  select(person_id, claims_count ,pred_poission, pred_nb) %>%
  head()


model_comparison <- health_test %>%
  summarise(actual_mean = mean(claims_count) ,poisson_mean = mean(pred_poission), nb_mean = mean(pred_nb), poisson_mae = mean(abs(claims_count -pred_poission)), nb_mae =  mean(abs(claims_count - pred_nb)), poisson_rmse = sqrt(mean((claims_count -pred_poission)^2)) , nb_rmse = sqrt(mean((claims_count -pred_nb)^2)))

model_comparison

baseline_prediction <- mean(health_train$claims_count)
baseline_comparison <- health_test %>%
  summarise(baseline_mean = baseline_prediction , baseline_mae = mean(abs(claims_count -baseline_prediction)), baseline_rmse = sqrt (mean((claims_count -baseline_prediction)^2)))

baseline_comparison

health_test <- health_test %>%
  mutate(risk_decile = ntile(pred_nb, 10))

calibration_summary <- health_test %>%
  group_by(risk_decile) %>%
  summarise(num_people = n() , avg_claim_count = mean(claims_count) , avg_pred_nb = mean(pred_nb)
  )

calibration_summary

severity_train <- health_train %>%
  filter(claims_count > 0)

severity_test <- health_test %>%
  filter(claims_count > 0)
severity_train_summary <- severity_train %>%
  summarise(
    num_claimants = n(),
    mean_person_claim_amount = mean(avg_claim_amount),
    median_person_claim_amount = median(avg_claim_amount),
    overall_payment_per_claim =
      sum(total_claims_paid) / sum(claims_count)
  )

severity_train_summary

severity_formula <-
  avg_claim_amount ~ age + sex + region + urban_rural + bmi + smoker + chronic_count +plan_type + network_tier + deductible + copay

severity_gamma <- glm(severity_formula,data = severity_train,family = Gamma(link = "log"),weights = claims_count
)

summary(severity_gamma)

severity_test <- severity_test %>%
  mutate(
    pred_severity_gamma = predict(
      severity_gamma,
      newdata = severity_test,
      type = "response"
    )
  )

severity_model_comparison <- severity_test %>%
  summarise(
    actual_weighted_mean = weighted.mean(
      avg_claim_amount,
      w = claims_count
    ),
    predicted_weighted_mean = weighted.mean(
      pred_severity_gamma,
      w = claims_count
    ),
    weighted_mae = weighted.mean(
      abs(avg_claim_amount - pred_severity_gamma),
      w = claims_count
    ),
    weighted_rmse = sqrt(
      weighted.mean(
        (avg_claim_amount - pred_severity_gamma)^2,
        w = claims_count
      )
    )
  )

severity_model_comparison



severity_baseline <- weighted.mean(
  severity_train$avg_claim_amount,
  w = severity_train$claims_count
)

severity_baseline_comparison <- severity_test %>%
  summarise(
    baseline_mean = severity_baseline,
    baseline_weighted_mae = weighted.mean(
      abs(avg_claim_amount - severity_baseline),
      w = claims_count
    ),
    baseline_weighted_rmse = sqrt(
      weighted.mean(
        (avg_claim_amount - severity_baseline)^2,
        w = claims_count
      )
    )
  )

severity_baseline_comparison


health_test <- health_test %>%
  mutate(
    pred_severity_gamma = predict(
      severity_gamma,
      newdata = health_test,
      type = "response"
    ),
    expected_cost_poisson =
      pred_poission * pred_severity_gamma,
    expected_cost_nb =
      pred_nb * pred_severity_gamma
  )

cost_model_comparison <- health_test %>%
  summarise(
    actual_mean_cost = mean(total_claims_paid),
    poisson_mean_cost = mean(expected_cost_poisson),
    nb_mean_cost = mean(expected_cost_nb),
    
    poisson_mae = mean(
      abs(total_claims_paid - expected_cost_poisson)
    ),
    nb_mae = mean(
      abs(total_claims_paid - expected_cost_nb)
    ),
    
    poisson_rmse = sqrt(
      mean((total_claims_paid - expected_cost_poisson)^2)
    ),
    nb_rmse = sqrt(
      mean((total_claims_paid - expected_cost_nb)^2)
    )
  )

cost_model_comparison


cost_baseline <- mean(health_train$total_claims_paid)

cost_baseline_comparison <- health_test %>%
  summarise(
    baseline_mean_cost = cost_baseline,
    baseline_mae = mean(
      abs(total_claims_paid - cost_baseline)
    ),
    baseline_rmse = sqrt(
      mean((total_claims_paid - cost_baseline)^2)
    )
  )

cost_baseline_comparison


# Create an output folder
dir.create("outputs", showWarnings = FALSE)


# 1. Frequency calibration table
frequency_calibration <- health_test %>%
  mutate(
    risk_decile = ntile(pred_nb, 10)
  ) %>%
  group_by(risk_decile) %>%
  summarise(
    num_people = n(),
    actual_claim_frequency = mean(claims_count),
    predicted_claim_frequency = mean(pred_nb),
    .groups = "drop"
  )


# 2. Expected-cost calibration table
cost_calibration <- health_test %>%
  mutate(
    cost_decile = ntile(expected_cost_poisson, 10)
  ) %>%
  group_by(cost_decile) %>%
  summarise(
    num_people = n(),
    actual_mean_cost = mean(total_claims_paid),
    predicted_mean_cost = mean(expected_cost_poisson),
    .groups = "drop"
  )


# 3. Claim-payment distribution chart
claims_distribution_plot <- health %>%
  filter(total_claims_paid > 0) %>%
  ggplot(aes(x = total_claims_paid)) +
  geom_histogram(
    bins = 50,
    fill = "#2C7FB8",
    color = "white"
  ) +
  scale_x_log10(
    breaks = c(100, 1000, 10000, 100000),
    labels = scales::label_dollar()
  ) +
  labs(
    title = "Distribution of Annual Claim Payments",
    subtitle = "Members with positive claim payments; logarithmic scale",
    x = "Annual claim payments",
    y = "Number of members"
  ) +
  theme_minimal()


# 4. Frequency-calibration chart
frequency_calibration_plot <- frequency_calibration %>%
  pivot_longer(
    cols = c(
      actual_claim_frequency,
      predicted_claim_frequency
    ),
    names_to = "series",
    values_to = "claim_frequency"
  ) %>%
  mutate(
    series = recode(
      series,
      actual_claim_frequency = "Actual",
      predicted_claim_frequency = "Predicted"
    )
  ) %>%
  ggplot(
    aes(
      x = risk_decile,
      y = claim_frequency,
      color = series
    )
  ) +
  geom_line(linewidth = 1) +
  geom_point(size = 2.5) +
  scale_x_continuous(breaks = 1:10) +
  scale_color_manual(
    values = c(
      "Actual" = "#D95F02",
      "Predicted" = "#1B9E77"
    )
  ) +
  labs(
    title = "Claim Frequency Calibration",
    subtitle = "Test-set results by predicted-risk decile",
    x = "Risk decile",
    y = "Average claims per member",
    color = NULL
  ) +
  theme_minimal() +
  theme(legend.position = "bottom")


# 5. Expected-cost calibration chart
cost_calibration_plot <- cost_calibration %>%
  pivot_longer(
    cols = c(actual_mean_cost, predicted_mean_cost),
    names_to = "series",
    values_to = "annual_cost"
  ) %>%
  mutate(
    series = recode(
      series,
      actual_mean_cost = "Actual",
      predicted_mean_cost = "Predicted"
    )
  ) %>%
  ggplot(
    aes(
      x = cost_decile,
      y = annual_cost,
      color = series
    )
  ) +
  geom_line(linewidth = 1) +
  geom_point(size = 2.5) +
  scale_x_continuous(breaks = 1:10) +
  scale_y_continuous(
    labels = scales::label_dollar()
  ) +
  scale_color_manual(
    values = c(
      "Actual" = "#D95F02",
      "Predicted" = "#1B9E77"
    )
  ) +
  labs(
    title = "Expected Claim Cost Calibration",
    subtitle = "Poisson–Gamma model on the test set",
    x = "Predicted-cost decile",
    y = "Average annual claim cost",
    color = NULL
  ) +
  theme_minimal() +
  theme(legend.position = "bottom")


# Display the charts
claims_distribution_plot
frequency_calibration_plot
cost_calibration_plot


# Save the charts
ggsave(
  "outputs/figure_1_claim_distribution.png",
  claims_distribution_plot,
  width = 9,
  height = 6,
  dpi = 300,
  bg = "white"
)

ggsave(
  "outputs/figure_2_frequency_calibration.png",
  frequency_calibration_plot,
  width = 9,
  height = 6,
  dpi = 300,
  bg = "white"
)

ggsave(
  "outputs/figure_3_cost_calibration.png",
  cost_calibration_plot,
  width = 9,
  height = 6,
  dpi = 300,
  bg = "white"
)


# Export the main result tables
write_csv(
  frequency_calibration,
  "outputs/frequency_calibration.csv"
)

write_csv(
  cost_calibration,
  "outputs/cost_calibration.csv"
)

write_csv(
  model_comparison,
  "outputs/frequency_model_comparison.csv"
)

write_csv(
  severity_model_comparison,
  "outputs/severity_model_comparison.csv"
)

write_csv(
  cost_model_comparison,
  "outputs/cost_model_comparison.csv"
)

# Export the baseline comparisons used to assess model improvement
write_csv(
  baseline_comparison,
  "outputs/frequency_baseline_comparison.csv"
)

write_csv(
  severity_baseline_comparison,
  "outputs/severity_baseline_comparison.csv"
)

write_csv(
  cost_baseline_comparison,
  "outputs/cost_baseline_comparison.csv"
)
