# docker-registry-proxy-cache

A simple script + docker-compose setup to auto-deploy a local proxy (or mirror)
of the Docker Registry on Mac OS X hosts (and others).


# Registry Mirror Configuration

## Prepared Setup

You can clone the following repository to get a pre-configured setup, as
described in the next section:

    https://github.com/laurent-malvert/docker-registry-proxy-cache

Simply do:

    # clone repository
    git clone https://github.com/laurent-malvert/docker-registry-proxy-cache.git

    # If using docker-machines, invoke:
    ./docker-registry-proxy-cache/machine-create-registry.sh

    # If using native docker, invoke simply
    docker-compose up -d

## Manual / Explained Setup

These instructions explain how this setup was first created, if
you want to redo it from scratch.

### Structure

At the end of this configuration, we will have a local setup with the following
structure, which can be used to recreate a local-registry at will (similar to
what is on the repo mentioned in the previous section):


```
    docker-registry-proxy-cache
    |-- config/                # where your registry config will live
    |   `-- config.yml
    |-- data/                  # where your registry data (the images) will live
    |-- docker-compose.yml
    `-- machine-create-registry.sh
```

### Steps

Note: the steps show how to create a custom docker-machine for this setup.
You don't have to do this if you want your registry to be hosted
on your normal native environment, however generally it'd make
sense to want your mirror to be separate from your other containers.

 1. We set up a docker-machine to host our local docker registry (tweak
    disk/memory/cpu/driver settings as you wish following these examples):

           # w/ VirtualBox host-VM
           docker-machine create                           \
             --driver virtualbox                           \
             --engine-insecure-registry registry:5000      \
             --engine-registry-mirror http://registry:5000 \
             registry-proxy-cache

           # w/ hyve host-VM
           docker-machine create                            \
             --driver xhyve                                 \
             --xhyve-experimental-nfs-share                 \
             --engine-insecure-registry localhost:5000      \
             --engine-registry-mirror http://localhost:5000 \
             registry-proxy-cache

 2. We set our shell's environment variables to allow the docker daemon to talk
    to the machine:

        eval "$(docker-machine env registry-proxy-cache)"

 3. We grab the `config.yml` file from the official remote repository:

        # create folder structure
        mkdir docker-registry-proxy-cache
        mkdir docker-registry-proxy-cache/config

        # grab default registry configuration
        docker run -it --rm                                             \
            --entrypoint cat registry:2 /etc/docker/registry/config.yml \
          > docker-registry-proxy-cache/config/config.yml.template

        # copy configuration to tweak for our own local registry
        cp \
          docker-registry-proxy-cache/config/config.yml.template \
          docker-registry-proxy-cache/config/config.yml

 4. We update this registry-proxy-cache/config/config.yml file to add the
    following proxy instructions (provide credentials if you want to download
    images from private repositories, otherwise ignore):

        # config.yml (excerpt)
        proxy:
          remoteurl: https://registry-1.docker.io
        #  username: [username]
        #  password: [password]

 5. Then we setup a registry environment using this
    registry-proxy-cache/docker-compose.yml config:

```
###########################################################################
# Local Docker Registry Mirror
#
# Laurent Malvert <laurent.malvert@gmail.com>
# https://github.com/laurent-malvert/docker-registry-proxy-cache
###########################################################################

version: '2.1'


services:

  registry:
    restart: always
    image: registry:latest
    ports:
      - 5000:5000
    volumes:
      - ./config:/etc/docker/registry:ro
      - ./data:/var/lib/registry:rw
```

 6. We can then start our registry mirror:

        docker-compose up -d

# Execution

## For a Local Native Setup

Again, no need to use docker machines if you just want to run the registry
mirror in your native environment. Simply invoke `docker-compose up -d` then,
and go your merry way without tweaking much.

## For a Multi Machine Setup

Once you have the setup above, you can use this script to automate the tear-down
and recreation of a registry.


*Beware, it will kill any pre-existing machine first!*

        #!/bin/sh
        # machine-create-registry.sh
        #
        # Laurent Malvert <laurent.malvert@gmail.com>
        #
        # quick-n-dirty local registry proxy cache to speed up image retrieval
        # from disposable docker machines on a Mac OS X system.
        #

        DIR="${0%/*}"


        REGISTRY_MACHINE_NAME="${1:-registry-proxy-cache}"

        docker-machine rm "${REGISTRY_MACHINE_NAME}"

        docker-machine create                                \
          --engine-insecure-registry "http://localhost:5000" \
          --engine-registry-mirror "http://localhost:5000"   \
          "${REGISTRY_MACHINE_NAME}"

        eval "$(docker-machine env ${REGISTRY_MACHINE_NAME})"

        docker-compose -f "${DIR}/docker-compose.yml" up -d

Executing the script will produce an output similar to:

        $> ./machine-create-registry.sh
        About to remove registry-proxy-cache
        Are you sure? (y/n): y
        (registry-proxy-cache) Stopping registry-proxy-cache ...
        (registry-proxy-cache) "disk3" unmounted.
        (registry-proxy-cache) "disk3" ejected.
        (registry-proxy-cache) Remove NFS share folder must be root. Please insert root password.
        Password:
        Successfully removed registry-proxy-cache
        Running pre-create checks...
        Creating machine...
        (registry-proxy-cache) Copying /Users/i316748/.docker/machine/cache/boot2docker.iso to /Users/i316748/.docker/machine/machines/registry-proxy-cache/boot2docker.iso...
        (registry-proxy-cache) Creating VM...
        (registry-proxy-cache) Extracting vmlinuz64 and initrd.img from boot2docker.iso...
        (registry-proxy-cache) /dev/disk3                                           /Users/i316748/.docker/machine/machines/registry-proxy-cache/b2d-image
        (registry-proxy-cache) "disk3" unmounted.
        (registry-proxy-cache) "disk3" ejected.
        (registry-proxy-cache) Generating 20000MB disk image...
        (registry-proxy-cache) created: /Users/i316748/.docker/machine/machines/registry-proxy-cache/root-volume.sparsebundle
        (registry-proxy-cache) Creating SSH key...
        (registry-proxy-cache) Fix file permission...
        (registry-proxy-cache) Generate UUID...
        (registry-proxy-cache) Convert UUID to MAC address...
        (registry-proxy-cache) Starting registry-proxy-cache...
        (registry-proxy-cache) Waiting for VM to come online...
        (registry-proxy-cache) Waiting on a pseudo-terminal to be ready... done
        (registry-proxy-cache) Hook up your terminal emulator to /dev/ttys009 in order to connect to your VM
        (registry-proxy-cache) NFS share folder must be root. Please insert root password.
        Waiting for machine to be running, this may take a few minutes...
        Detecting operating system of created instance...
        Waiting for SSH to be available...
        Detecting the provisioner...
        Provisioning with boot2docker...
        Copying certs to the local machine directory...
        Copying certs to the remote machine...
        Setting Docker configuration on the remote daemon...
        Checking connection to Docker...
        Docker is up and running!
        To see how to connect your Docker Client to the Docker Engine running on this virtual machine, run: docker-machine env registry-proxy-cache
        Creating network "dockerregistryproxycache_default" with the default driver
        Pulling registry (registry:2)...
        2: Pulling from library/registry
        5c90d4a2d1a8: Pull complete
        fb8b2153aae6: Pull complete
        f719459a7672: Pull complete
        fa42982c9892: Pull complete
        Digest: sha256:504b44c0ca43f9243ffa6feaf3934dd57895aece36b87bc25713588cdad3dd10
        Status: Downloaded newer image for registry:2
        Creating dockerregistryproxycache_registry_1

# Usage (or How to Setup your Docker Machines to Use your Registry Proxy)

Finally we can now tell the docker daemons from other docker-machines to use our
local registry proxy:

## The Linux Way

    docker --insecure-registry --registry-mirror=https://localhost:5000 daemon

## The  Mac OS X Way (with docker tools)

### On an existing machine (get the REGISTRY_MACHINE_IP from `docker-machine ls`):

    docker-machine ssh <my_machine>
    sudo vi /var/lib/boot2docker/profile
    #    add these lines to EXTRA_ARGS:
    #       --insecure-registry REGISTRY_MACHINE_IP:5000
    #       --registry-mirror http://REGISTRY_MACHINE_IP:5000

#### On a new machine, by specifying these arguments to `docker-machine create`,
     as seen above:

          --engine-insecure-registry REGISTRY_MACHINE_IP:5000
          --engine-registry-mirror http://REGISTRY_MACHINE_IP:5000

## The Mac OS X Way (with Docker for Mac)

Simply configure your Docker for Mac setup via the GUI and setup a mirror with:

    http://localhost:5000 

# Verification

We can verify that this works accordingly by querying the
registry before and after pulling an image. If configured correctly,
after the pull the registry will hold your image.

 1. Check that the local registry is up and running

        curl http://REGISTRY_MACHINE_IP:5000/v2/_catalog
        # outputs -> {"repositories":[]}

 2. Setup docker host env (if using docker-machine, e.g. on Mac OS X)

        eval "$(docker-machine env A_MACHINE_WITH_PROXY_CONFIGURED)"

 3. Pull down some image

        docker pull busybox

 4. Check that the image is available in the local registry cache

        curl http://REGISTRY_MACHINE_IP:5000/v2/_catalog
        # outputs -> {"repositories":["library/busybox"]}

From then on, if you delete your local image (with `docker rmi`),
your next pull will be faster by querying your local regsitry.

Note that if you use Docker for Mac and do a reset (e.g. to avoid disk increase
issues in the current versions), you can simply restart the registry and the
/data volume will be used, so you won't have to re-download all images.

If disk usage becomes an issue overtime, prune images in /data,
or delete /data entirely and restart your mirror to start again
from scratch.


# References

 * Registry Configuration:
   * Registry Configuration Reference: https://docs.docker.com/registry/configuration/
   * Registry Deployment Guide: https://docs.docker.com/registry/deploying/
   * Insecure Registry Setup Addendum: https://docs.docker.com/registry/insecure/
   * Registry Proxy Cache / Registry Mirror Setup Tutorial: https://blog.docker.com/2015/10/registry-proxy-cache-docker-open-source/
 * Other useful things:
   * http://stackoverflow.com/questions/26424338/docker-daemon-config-file-on-boot2docker
