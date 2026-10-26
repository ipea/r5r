# Download `R5.jar`

Downloads `R5.jar` and saves it locally, inside the package directory.

## Usage

``` r
download_r5(
  version = NULL,
  quiet = FALSE,
  force_update = FALSE,
  temp_dir = FALSE
)
```

## Arguments

- version:

  A string. The version of R5 to be downloaded. When `NULL`, it defaults
  to the latest version.

- quiet:

  A logical. Whether to show informative messages when downloading the
  file. Defaults to `FALSE`.

- force_update:

  A logical. Whether to overwrite a previously downloaded `R5.jar` in
  the local directory. Defaults to `FALSE`.

- temp_dir:

  A logical. Whether the file should be saved in a temporary directory.
  Defaults to `FALSE`.

## Value

The path to the downloaded file.

## See also

Other Build network:
[`build_network()`](https://ipea.github.io/r5r/dev/reference/build_network.md),
[`setup_r5()`](https://ipea.github.io/r5r/dev/reference/setup_r5.md)

## Examples

``` r
library(r5r)

download_r5(temp_dir = TRUE)
#> Downloading R5 jar file to /tmp/RtmptARcfX/r5-v7.6-all.jar
#> [1] "/tmp/RtmptARcfX/r5-v7.6-all.jar"
```
