PACKER_VERSION="1.10.0"

if [ ! -f ./packer ]; then
    wget https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_arm64.zip;
    unzip packer_${PACKER_VERSION}_linux_arm64.zip;
    rm packer_${PACKER_VERSION}_linux_arm64.zip;
fi

wget https://storage.googleapis.com/dist.gem5.org/dist/develop/images/arm/ubuntu-24-04/arm-ubuntu-24.04-20240823.gz
gunzip arm-ubuntu-24.04-20240823.gz 

# Install the needed plugins
./packer init arm-ubuntu.pkr.hcl

# Build the image
./packer build arm-ubuntu.pkr.hcl

