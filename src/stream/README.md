# Steps  

- Lets first prepare the benchmark.
- Get the source code for the STREAM benchmark from <https://github.com/jeffhammond/STREAM/tree/master>
- Update the makefile to link to `libm5.a` and add an `M5_ANNOTATION` flag. This flag will allow us to decide if we want to build the benchmark with or without m5 annotations. Make sure that we are compiling with `-no-pie` as `m5ops` is compiled with `no-pie`
- Add calls to `hypercall 4` before the main loop and `hypercall 5` after the main loop in `stream.c`.
- Now we have annotated the benchmark.

- Lets write a packer file following the same structure as the npb benchmark, as we are using the same base image but building a different benchmark.

- Copy the stream code from host to the disk by adding the following file provisioner

```hcl
  provisioner "file" {
    source      = "STREAM-master"
    destination = "/home/gem5/"
  }
```

- Update the `post-installation.sh` to make the STREAM benchmark

```bash
cd STREAM-master

make stream_c.exe
```

- run the packer script to build the disk image.

- You can use this disk image to run stream on gem5.