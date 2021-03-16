docker build -t immauss/openvas:$(git branch | awk /\*/'{print $2}') .
