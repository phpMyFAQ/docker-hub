# docker-hub

This image uses the multi-stage feature from docker. It's the one available on docker hub.

## Args

Available arguments to build a new image:

**PMF_BRANCH**: Specifie the Github branch to include in the release _(default: 3.0)_

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
