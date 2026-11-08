# Generate an r5r situation report to help debug errors

The function reports a list with the following information:

- The package version of `{r5r}` in use.

- The installed version of `R5.jar`.

- The Java version in use.

- The amount of memory set to Java through the `java.parameters` option.

- The user's Session Info.

## Usage

``` r
r5r_sitrep()
```

## Value

A `list` with information of the versions of the r5r package, Java and
R5 Jar in use, the memory set to Java and user's Session Info.

## Examples

``` r
r5r_sitrep()
#> $r5r_package_version
#> [1] ‘2.5.0’
#> 
#> $r5_jar_version
#> [1] "7.6"
#> 
#> $java_version
#> [1] "21.0.13"
#> 
#> $set_memory
#> NULL
#> 
#> $session_info
#> R version 4.6.2 (2026-10-29)
#> Platform: x86_64-pc-linux-gnu
#> Running under: Ubuntu 22.04.5 LTS
#> 
#> Matrix products: default
#> BLAS:   /usr/lib/x86_64-linux-gnu/openblas-pthread/libblas.so.3 
#> LAPACK: /usr/lib/x86_64-linux-gnu/openblas-pthread/libopenblasp-r0.3.20.so;  LAPACK version 3.10.0
#> 
#> locale:
#>  [1] LC_CTYPE=C.UTF-8          LC_NUMERIC=C             
#>  [3] LC_TIME=C.UTF-8           LC_COLLATE=C             
#>  [5] LC_MONETARY=C.UTF-8       LC_MESSAGES=C.UTF-8      
#>  [7] LC_PAPER=C.UTF-8          LC_NAME=C.UTF-8          
#>  [9] LC_ADDRESS=C.UTF-8        LC_TELEPHONE=C.UTF-8     
#> [11] LC_MEASUREMENT=C.UTF-8    LC_IDENTIFICATION=C.UTF-8
#> 
#> time zone: UTC
#> tzcode source: system (glibc)
#> 
#> attached base packages:
#> [1] stats     graphics  grDevices utils     datasets  methods   base     
#> 
#> other attached packages:
#> [1] ggplot2_4.0.3 r5r_2.5.0    
#> 
#> loaded via a namespace (and not attached):
#>  [1] gtable_0.3.6        xfun_0.62           bslib_0.12.0       
#>  [4] httr2_1.3.0         htmlwidgets_1.6.4   processx_3.9.0     
#>  [7] rJava_1.0-18        callr_3.8.0         vctrs_0.7.3        
#> [10] tools_4.6.2         ps_1.9.3            generics_0.1.4     
#> [13] curl_8.1.0          proxy_0.4-29        tibble_3.3.1       
#> [16] fansi_1.0.7         sfheaders_0.4.5     pkgconfig_2.0.3    
#> [19] KernSmooth_2.23-27  data.table_1.18.6.1 checkmate_2.3.4    
#> [22] RColorBrewer_1.1-3  S7_0.2.2            desc_1.4.3         
#> [25] lifecycle_1.0.5     compiler_4.6.2      farver_2.1.2       
#> [28] brio_1.1.5          textshaping_1.0.5   fontawesome_0.5.3  
#> [31] class_7.3-24        htmltools_0.5.9     sass_0.4.10        
#> [34] yaml_2.3.12         pillar_1.11.1       pkgdown_2.2.1      
#> [37] jquerylib_0.1.4     whisker_0.4.1       openssl_2.5.0      
#> [40] classInt_0.4-11     cachem_1.1.0        wk_0.9.5           
#> [43] zip_3.0.2           tidyselect_1.2.1    digest_0.6.39      
#> [46] sf_1.1-3            dplyr_1.2.1         purrr_1.2.2        
#> [49] labeling_0.4.3      fastmap_1.2.0       grid_4.6.2         
#> [52] cli_3.6.6           magrittr_2.0.5      e1071_1.7-17       
#> [55] withr_3.0.3         scales_1.4.0        backports_1.5.1    
#> [58] rmarkdown_2.32      otel_0.3.0          askpass_1.2.1      
#> [61] ragg_1.5.2          memoise_2.0.1       evaluate_1.0.5     
#> [64] knitr_1.52          testthat_3.3.2      s2_1.1.13          
#> [67] rlang_1.3.0         isoband_0.3.0       Rcpp_1.1.2         
#> [70] downlit_0.4.5       glue_1.8.1          DBI_1.3.0          
#> [73] xml2_1.6.0          rstudioapi_0.19.0   jsonlite_2.0.0     
#> [76] R6_2.6.1            rJavaEnv_0.3.0      units_1.0-1        
#> [79] systemfonts_1.3.2   fs_2.1.0           
#> 
```
