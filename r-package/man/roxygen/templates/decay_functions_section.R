#' @section Decay functions:
#'
#' `R5` allows one to use different decay functions when calculating
#' accessibility. See the original `R5` documentation from Conveyal for
#' more information on each one
#' (<https://docs.conveyal.com/learn-more/decay-functions>). A summary of each
#' available option, as well as the value passed to `decay_function` to use it
#' (inside parentheses) are listed below:
#'
#' - **Step**, also known as cumulative opportunities (`"step"`): \cr
#' a binary decay function used to find the sum of available opportunities
#' within a specific travel time cutoff.
#'
#' - **Logistic CDF** (`"logistic"`): \cr
#' This is the logistic function, i.e. the cumulative distribution function of
#' the logistic distribution, expressed such that its parameters are the median
#' (inflection point) and standard deviation. This function applies a sigmoid
#' rolloff that has a convenient relationship to discrete choice theory. Its
#' parameters can be set to reflect a whole population's tolerance for making
#' trips with different travel times. The function's value represents the
#' probability that a randomly chosen member of the population would accept
#' making a trip, given its duration. Opportunities are then weighted by how
#' likely it is that a person would consider them "reachable".
#'   - Calibration: The median parameter is controlled by the `cutoff`
#'   parameter, leaving only the standard deviation to configure through the
#'   `decay_value` parameter.
#'
#' - **Fixed Exponential** (`"fixed_exponential"`): \cr
#' This function is of the form `exp(-Lt)` where L is a single fixed decay
#' constant in the range (0, 1) and t is the travel time in **seconds**. It is
#' constrained to be positive to ensure weights decrease (rather than grow)
#' with increasing travel time. Note that L is a per-second constant: to use a
#' decay constant expressed per minute (e.g. from the literature), pass it
#' divided by 60.
#'   - Calibration: This function is controlled exclusively by the `L` constant,
#'   given by the `decay_value` parameter. `cutoffs` must be `NULL`.
#'
#' - **Half-life Exponential Decay** (`"exponential"`): \cr
#' This is similar to the fixed-exponential option above, but in this case the
#' decay parameter is inferred from the `cutoffs` parameter values, which is
#' treated as the half-life of the decay.
#'
#' - **Linear** (`"linear"`): \cr
#' This is a simple, vaguely sigmoid option, which may be useful when you have
#' a sense of a maximum travel time that would be tolerated by any traveler,
#' and a minimum time below which all travel is perceived to be equally easy.
#'   - Calibration: The transition region is transposable and symmetric around
#'   the `cutoffs` parameter values, taking `decay_value` minutes to taper down
#'   from one to zero. `decay_value` must be a whole number of minutes between
#'   1 and 59.
