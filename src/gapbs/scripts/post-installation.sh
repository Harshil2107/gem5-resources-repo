# Install the necessary packages
apt-get install -y build-essential libboost-all-dev

echo "Installing GAP Benchmark Suite"
cd gapbs
# Build the benchmark suite
make clean
make

# Make the graphs
make -f ./benchmark/bench.mk bench-graphs