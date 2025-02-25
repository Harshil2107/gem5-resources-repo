# Steps  

- Lets first prepare the benchmark.
- Get the source code for the STREAM benchmark from <https://github.com/jeffhammond/STREAM/tree/master>
- Update the makefile to link to `libm5.a` and add an `M5_ANNOTATION` flag. This flag will allow us to decide if we want to build the benchmark with or without m5 annotations. Make sure that we are compiling with `-no-pie` as `m5ops` is compiled with `no-pie`
- Add calls to `hypercall 4` before the main loop and `hypercall 5` after the main loop in `stream.c`.

```C
    /*	--- MAIN LOOP --- repeat test cases NTIMES times --- */
#ifdef M5ANNOTATION
	map_m5_mem();
	printf(" -------------------- ROI BEGIN -------------------- \n");
	m5_hypercall_addr(4);
#endif

    scalar = 3.0;
    for (k=0; k<NTIMES; k++)
	{
	times[0][k] = mysecond();
#ifdef TUNED
        tuned_STREAM_Copy();
#else
#pragma omp parallel for
	for (j=0; j<STREAM_ARRAY_SIZE; j++)
	    c[j] = a[j];
#endif
	times[0][k] = mysecond() - times[0][k];
	
	times[1][k] = mysecond();
#ifdef TUNED
        tuned_STREAM_Scale(scalar);
#else
#pragma omp parallel for
	for (j=0; j<STREAM_ARRAY_SIZE; j++)
	    b[j] = scalar*c[j];
#endif
	times[1][k] = mysecond() - times[1][k];
	
	times[2][k] = mysecond();
#ifdef TUNED
        tuned_STREAM_Add();
#else
#pragma omp parallel for
	for (j=0; j<STREAM_ARRAY_SIZE; j++)
	    c[j] = a[j]+b[j];
#endif
	times[2][k] = mysecond() - times[2][k];
	
	times[3][k] = mysecond();
#ifdef TUNED
        tuned_STREAM_Triad(scalar);
#else
#pragma omp parallel for
	for (j=0; j<STREAM_ARRAY_SIZE; j++)
	    a[j] = b[j]+scalar*c[j];
#endif
	times[3][k] = mysecond() - times[3][k];
	}
#ifdef M5ANNOTATION
	m5_hypercall_addr(5);
	printf(" -------------------- ROI END -------------------- \n");
#endif
```

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
