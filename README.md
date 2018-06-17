# docker-hub

This image uses the multi-stage feature from docker. It's the one available on docker hub.

## Args

Available arguments to build a new image:

**PMF_BRANCH**: Specifie the Github branch to include in the release _(default: 3.0)_

#How to use

To build an image containing the current code in the specified branch:

    # Example with the 3.0 branch
    git clone https://github.com/phpMyFAQ/docker-hub.git && cd docker-hub
    git checkout 3.0
    docker build -t phpmyfaq .

To build a specific tag of the PMF repo:

    # Example with the 3.0.0-alpha.2 tag
    git clone https://github.com/phpMyFAQ/docker-hub.git && cd docker-hub
    git checkout 3.0
    docker build -t phpmyfaq:3.0.0-alpha.2 --build-arg PMF_BRANCH=3.0.0-alpha.2 .

## To run

Use docker compose:

    docker-compose up

The command above starts 4 containers as following.

_Running using volumes:_
- **mariadb**: image with xtrabackup support
- **elasticsearch**: Open Source Software image (it means it does not have XPack installed)
- **phpmyadmin**: a PHP tool to have a look on your database.

_Running apache web server with PHP support:_
- **phpmyfaq**: mounts the ressources folders in `./volumes`.

Then services will be available at following addresses:

- phpMyFAQ: (http://localhost:8080)
- phpMyAdmin: (http://localhost:8000)
