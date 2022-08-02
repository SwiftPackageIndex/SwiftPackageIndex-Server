FROM swift:5.6.1-focal

RUN apt-get update && apt-get install -y curl git make unzip \
    sqlite3 libsqlite3-dev  # dependencies for building SPM

RUN apt-get update && apt-get install -y fish
RUN chsh -s $(which fish)
