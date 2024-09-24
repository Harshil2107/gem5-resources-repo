# Install the necessary packages


apt-get install -y build-essential libboost-all-dev

echo "Installing GAP Benchmark Suite"
cd gapbs

# Build the benchmark suite
make clean
make

cd ..
mkdir graphs
cd graphs
wget https://snap.stanford.edu/data/facebook_combined.txt.gz
gunzip facebook_combined.txt.gz
mv facebook_combined.txt facebook_combined.el

wget https://snap.stanford.edu/data/soc-LiveJournal1.txt.gz
gunzip soc-LiveJournal1.txt.gz
mv soc-LiveJournal1.txt soc-LiveJournal1.el

# Disable systemd service that waits for network to be online
systemctl disable systemd-networkd-wait-online.service
systemctl mask systemd-networkd-wait-online.service