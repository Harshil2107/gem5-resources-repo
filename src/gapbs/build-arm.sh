PACKER_VERSION="1.10.0"

if [ ! -f ./packer ]; then
    wget https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_arm64.zip;
    unzip packer_${PACKER_VERSION}_linux_arm64.zip;
    rm packer_${PACKER_VERSION}_linux_arm64.zip;
fi

./packer init arm-ubuntu-24-04-gapbs.pkr.hcl
./packer build arm-ubuntu-24-04-gapbs.pkr.hcl
