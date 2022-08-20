pacman::p_load(data.table, haven, glmnet)

# data = data.table(read_dta("merged_panel_official.dta"))
# fwrite(data, "merged_panel_official.csv")
data = fread("merged_panel_official.csv")


cols_I_want = c("elder_id", grep("mmse", names(data), value = TRUE))
mmse_data = data[, ..cols_I_want]


# baseline_cols = c(grep("B_.*", names(mmse_data), value = TRUE))
# w1_cols = c(grep("w1_.*", names(mmse_data), value = TRUE))
# mmse_var_names = gsub("^B_", "", baseline_cols)



# measure_var_list = mapply(c, baseline_cols, w1_cols, SIMPLIFY = F)
# names(measure_var_list) = mmse_var_names
#
# mmse_long =
#   melt(mmse_data,
#        id.vars = c("elder_id"),
#        measure.vars = measure_var_list
#   )
# mmse_long[, wave := fifelse(variable == 1, "B", "w1")][, variable := NULL]



baseline_cols = c("elder_id", grep("B_.*", names(mmse_data), value = TRUE))
w1_cols = c("elder_id", grep("w1_.*", names(mmse_data), value = TRUE))
mmse_var_names = gsub("^B_", "", baseline_cols)


mmse_long =
  rbind(
    setnames(mmse_data[, ..baseline_cols], mmse_var_names)[, wave := "B"],
    setnames(mmse_data[, ..w1_cols], mmse_var_names)[, wave := "w1"]
  )

mmse_qs = grep("[0-9]$", mmse_var_names, value = TRUE)

# rlasso(as.formula(paste0("mmse_score ~ ", paste(mmse_qs, collapse = " + "))), data = mmse_long)

x_matrix = mmse_long[!is.na(mmse_score), ..mmse_qs]
# NA_imputation_value = mean(as.matrix(x_matrix)[is.na(as.matrix(x_matrix))]) # Overall
# x_matrix[is.na(x_matrix)] = NA_imputation_value
y_vector = mmse_long[!is.na(mmse_score), mmse_score]
ymat = mmse_long[!is.na(mmse_score), .(mmse_score)]

lambda_initial_guess = 1
number_of_short_version_params = 6

count_nonzero_coefs = function(lambda_val) {
  whats_inside_the_function <<- lambda_val
  sum(glmnet(x = x_matrix, y = y_vector, lambda = lambda_val)$beta != 0)
}
number_of_nonzero_coefs_compared_to_criterion = function(lambda_val) {
  abs(count_nonzero_coefs(lambda_val) - number_of_short_version_params)
}


selected_lambda = optim(lambda_initial_guess, number_of_nonzero_coefs_compared_to_criterion)$par # , method = "L-BFGS-B", lower = 0)

post_lasso = function(selected_lambda) {
  lasso_coefs = glmnet(x = x_matrix, y = y_vector, lambda = selected_lambda)$beta
  non_zero_coef_names = row.names(lasso_coefs)[as.logical(lasso_coefs != 0)]
  post_formula = as.formula(paste0("mmse_score ~ ", paste(non_zero_coef_names, collapse = " + ")))
  post_model = lm(post_formula, data = cbind(x_matrix, ymat))
  post_model
}

mini_mmse = post_lasso(selected_lambda)

summary(mini_mmse)

mmse_long[, mini_mmse_score := predict(mini_mmse, newdata = mmse_long)]

# match the population proportion
# false positive vs. false negative cost function
# if costs are 1 is that the same as balanced accuracy?
# f1 score?

