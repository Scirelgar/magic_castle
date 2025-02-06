#!/bin/bash
set -e
usage() {
    echo "Usage: $0 [-c CLOUD...]"
    echo ""
    echo "  -c CLOUD...     Specify the cloud providers to include in the release"
    exit 2
}

CLOUD=(aws azure gcp openstack ovh)

while getopts "sc:" opt; do
    case "$opt" in
        c) 
            if [ -z "$OPTARG" ] || [[ "$OPTARG" = -* ]]; then
                echo "Error: the -c flag requires an argument"
                usage
                exit 2
            fi
            CLOUD=($OPTARG)
            shift $((OPTIND-1))
            while [ "$1" != "" ] && [[ "$1" != -* ]]; do
                CLOUD+=("$1")
                shift
            done
            OPTIND=$((OPTIND-1))
            ;;
        *) usage ;;
    esac
done

if [ "$(uname)" == "Linux" ]; then
    sed_i () {
        sed -i "$@"
    }
elif [ "$(uname)" == "Darwin" ]; then
    sed_i () {
        sed -i "" "$@"
    }
fi

VERSION=scan

FOLDER=magic_castle-$VERSION

mkdir -p $FOLDER
for provider in "${CLOUD[@]}"; do
    cur_folder=$FOLDER/magic_castle-$provider-$VERSION
    mkdir -p $cur_folder
    cp -RfL common $cur_folder/
    rm $cur_folder/common/{variables,outputs}.tf
    cp -RfL dns $cur_folder/
    cp -RfL $provider $cur_folder/
    cp -fL examples/$provider/main.tf $cur_folder
    mv $cur_folder/$provider/README.md $cur_folder
    sed_i 's;git::https://github.com/ComputeCanada/magic_castle.git//;./;g' $cur_folder/main.tf
    sed_i "s;\"main\";\"$VERSION\";" $cur_folder/main.tf
    cp LICENSE $cur_folder

    ## Initialize to create .terraform.lock.hcl file
    cd $cur_folder
    ## Make sure only one module is named "dns"
    sed_i '1,/dns/s/dns/cloudflare/' main.tf
    ## Uncomment DNS modules
    sed_i 's/^#\ //g' main.tf
    cd -

    ## Recreate a new unmodified main.tf
    cp -fL examples/$provider/main.tf $cur_folder
    sed_i 's;git::https://github.com/ComputeCanada/magic_castle.git//;./;g' $cur_folder/main.tf
    sed_i "s;\"main\";\"$VERSION\";" $cur_folder/main.tf
done
rm -rf $TMPDIR


