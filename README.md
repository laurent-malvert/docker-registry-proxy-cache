# docker-registry-proxy-cache

A simple script + docker-compose setup to auto-deploy a local proxy of the
Docker Registry on Mac OS X hosts (and others).


# Configuration

## Registry Proxy Setup

###Prepared Setup

You can clone the following repository to get a pre-configured setup, as described in the next section:

```
    https://github.com/laurent-malvert/docker-registry-proxy-cache
```


Simply do:

```
  # clone repository
  git clone https://github.com/laurent-malvert/docker-registry-proxy-cache.git

  # invoke auto-deployment script
  ./docker-registry-proxy-cache/machine-create-registry.sh
```

### Manual / Explained Setup

#### Structure

At the end of this configuration, we will have a local setup with the following
structure, which can be used to recreate a local-registry at will (similar to
what is on the repo mentioned in the previous section):


    docker-registry-proxy-cache
    |-- config/
    |   `-- config.yml
    |-- docker-compose.yml
    `-- machine-create-registry.sh

#### Steps

 1. We set up a docker-machine to host our local docker registry (pick either
    approach, and tweak disk/memory/cpu settings as you wish):

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

 3. We grab the config.yml file from the official remote repository:

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

        #docker-compose.yml
        ###########################################################################
        # Local Docker Registry Mirror
        ###########################################################################
        version: '2'
        services:
          registry:
            restart: always
            image: registry:2
            ports:
              - 5000:5000
            volumes:
              - ./config:/etc/docker/registry:rw

 6. We can then start our registry mirror:

        docker-compose up -d

#### Automated Script

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
        
        docker-machine create                              \
          --driver "xhyve"                                 \
          --xhyve-experimental-nfs-share                   \
          --engine-insecure-registry "localhost:5000"      \
          --engine-registry-mirror "http://localhost:5000" \
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

## Docker Machines Setup with Registry Proxy

Finally we can now tell the docker daemons from other docker-machines to use our
local registry proxy:

### The Linux Way

    docker --insecure-registry --registry-mirror=https://localhost:5000 daemon
 
### The  Mac OS X way:

#### On an existing machine (get the REGISTRY_MACHINE_IP from `docker-machine ls`):

    docker-machine ssh <my_machine>
    sudo vi /var/lib/boot2docker/profile
    #    add these lines to EXTRA_ARGS:
    #       --insecure-registry REGISTRY_MACHINE_IP:5000
    #       --registry-mirror http://REGISTRY_MACHINE_IP:5000
 
#### On a new machine, by specifying these arguments to `docker-machine create`,
     as seen above:

          --engine-insecure-registry REGISTRY_MACHINE_IP:5000
          --engine-registry-mirror http://REGISTRY_MACHINE_IP:5000

### Verification

We can verify that this works accordingly:

#### Check that the local registry is up and running

    curl http://REGISTRY_MACHINE_IP:5000/v2/_catalog
    # outputs -> {"repositories":[]}
 
#### Setup docker host env (if using docker-machine, e.g. on Mac OS X)

    eval "$(docker-machine env A_MACHINE_WITH_PROXY_CONFIGURED)"
 
#### Pull down some image

    docker pull busybox
 
#### Check that the image is available in the local registry cache

       curl http://REGISTRY_MACHINE_IP:5000/v2/_catalog
       # outputs -> {"repositories":["library/busybox"]}

# References

 * Registry Configuration:
 ** Registry Configuration Reference: https://docs.docker.com/registry/configuration/
 ** Registry Deployment Guide: https://docs.docker.com/registry/deploying/
 ** Insecure Registry Setup Addendum: https://docs.docker.com/registry/insecure/
 ** Registry Proxy Cache / Registry Mirror Setup Tutorial: https://blog.docker.com/2015/10/registry-proxy-cache-docker-open-source/
 * Other useful things:
 ** http://stackoverflow.com/questions/26424338/docker-daemon-config-file-on-boot2docker
