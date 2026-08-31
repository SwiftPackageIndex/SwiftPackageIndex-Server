FROM registry.gitlab.com/saguaro1/spi-base:e7382892eaa60763f723b362aa0b414a0a1bf52a

# Install SPM build dependencies
RUN apt-get update && apt-get install -y curl git make unzip \
    sqlite3 libsqlite3-dev  `# dependencies for building SPM` \
    libcurl4-openssl-dev    `# Foundation networking`

# Install front-end dependencies
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
RUN apt-get install -y nodejs

# Install shells
RUN apt-get install -y fish zsh

# Install zsh customisation
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
RUN curl https://gist.githubusercontent.com/daveverwer/73bd218b27181512f6252b59dc098610/raw/09ada460a7bd20bbf2c779e7747e193e5c38b028/zshrc > ~/.zshrc
