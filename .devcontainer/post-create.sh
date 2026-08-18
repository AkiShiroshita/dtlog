#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

# System dependencies
sudo apt-get update
sudo apt-get install -y \
  build-essential \
  git \
  libcurl4-openssl-dev \
  libssl-dev \
  libxml2-dev \
  libfontconfig1-dev \
  libharfbuzz-dev \
  libfribidi-dev \
  libfreetype6-dev \
  libpng-dev \
  libtiff5-dev \
  libjpeg-dev \
  zlib1g-dev \
  libgit2-dev \
  libuv1-dev \
  pandoc \
  make \
  gcc \
  g++

mkdir -p "$HOME/.R/library"

cat > "$HOME/.Rprofile" <<'EOF'
options(repos = c(CRAN = "https://cloud.r-project.org"))
options(stringsAsFactors = FALSE)
options(encoding = "UTF-8")
if (interactive()) {
  options(editor = "nano")
}
EOF

cat > "$HOME/.Renviron" <<EOF
R_LIBS_USER=$HOME/.R/library
EOF

export R_LIBS_USER="$HOME/.R/library"
Rscript -e "options(repos = c(CRAN = 'https://cloud.r-project.org')); install.packages(c('usethis','devtools','roxygen2','testthat','pkgdown','fs','sass','pkgload','profvis','bslib','shiny','rmarkdown','htmlwidgets','miniUI','textshaping'), lib = Sys.getenv('R_LIBS_USER'), Ncpus = 2)"

# Quarto install if needed
if ! command -v quarto >/dev/null 2>&1; then
  curl -fsSL "https://quarto.org/download/latest/quarto-linux-amd64.deb" -o /tmp/quarto.deb
  sudo apt-get install -y /tmp/quarto.deb || sudo dpkg -i /tmp/quarto.deb
  sudo apt-get -f install -y
fi

# Install Codex CLI if needed
if ! command -v codex >/dev/null 2>&1; then
  npm install -g @openai/codex
fi

# Friendly final check
Rscript -e "pkgs <- c('usethis','devtools','roxygen2','testthat','pkgdown','fs','sass','pkgload','profvis','bslib','shiny','rmarkdown','htmlwidgets','miniUI','textshaping'); print(sapply(pkgs, function(p) if (requireNamespace(p, quietly=TRUE)) as.character(packageVersion(p)) else 'MISSING'))"
command -v codex
codex --version
