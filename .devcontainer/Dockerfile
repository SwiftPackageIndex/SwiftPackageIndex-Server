FROM swift:5.6.1-focal

# Install SPM build dependencies
RUN apt-get update && apt-get install -y curl git make unzip \
    sqlite3 libsqlite3-dev

# Install front-end dependencies
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
RUN apt-get install -y nodejs
RUN npm install --global yarn

RUN apt-get update && apt-get install -y fish
RUN chsh -s $(which fish)
