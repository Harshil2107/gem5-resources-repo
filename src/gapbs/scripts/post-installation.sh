# Install the necessary packages
apt-get install -y build-essential libboost-all-dev

echo "Installing GAP Benchmark Suite"
cd gapbs
# Build the benchmark suite
make
