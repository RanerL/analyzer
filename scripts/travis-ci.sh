# This script is for either running in a Travis CI worker or the VM setup by vagrant. See .travis.yml and Vagrantfile
# Inspired by https://github.com/lunaryorn/flycheck

# setup base system and clone goblint if not running in travis-ci
if [[ "$TRAVIS_OS_NAME" == "osx" ]]; then
    # brew update # takes ~5min, travis VMs are updated from time to time; could also cache: https://discourse.brew.sh/t/best-practice-for-homebrew-on-travis-brew-update-is-5min-to-build-time/5215/13
    brew install opam gcc # this also triggers an update; tried installing via homebrew addon in .travis.yml which is supposed to not update, but it only works with update... see https://travis-ci.community/t/macos-build-fails-because-of-homebrew-bundle-unknown-command/7296/18
else
    if test -e "make.sh"; then # travis-ci
        echo "already in repository"
        # USER=`whoami`
    else # vagrant
        apt () {
            sudo apt-get install -yy --fix-missing "$@"
        }
        # update repositories to prevent errors caused by missing packages
        sudo apt-get update -qq
        apt gcc
        apt libgmp-ocaml-dev
        apt software-properties-common # needed for ppa
        apt make m4  # needed for compiling ocamlfind
        apt autoconf # needed for compiling cil
        apt git      # needed for cloning goblint source

        # USER=vagrant # provisioning is done as root, but ssh login is 'vagrant'
        cd /root # just do everything as root and later use 'sudo su -' for ssh
        if test ! -e "analyzer"; then # ignore if source already exists
            git clone https://github.com/goblint/analyzer.git
            # chown -hR $USER:$USER analyzer # make ssh user the owner
        fi
        pushd analyzer
    fi

    # install ocaml and friends, see http://anil.recoil.org/2013/09/30/travis-and-ocaml.html
    ppa=avsm/ppa

    echo 'yes' | sudo add-apt-repository ppa:$ppa
    sudo apt-get update -qq
    sudo apt-get install -qq opam

    sudo apt-get install -qq libmpfr-dev # for apron
fi

# install dependencies
if [[ -d "_opam/lib/ocaml" ]]; then # install deps into existing cached local switch
  ./make.sh deps
else # create a new local switch and install deps
  rm -rf _opam
  SANDBOXING=--disable-sandboxing ./make.sh setup
fi
eval `opam config env`
# compile
./make.sh nat
