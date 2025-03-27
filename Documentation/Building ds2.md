# Building the ds2 Debug Server

The Edge CLI uses the [`ds2` debug server](https://github.com/compnerd/ds2) to debug EdgeOS applications.

The included `ds2` binary was built using the following command:

```sh
cmake -B out -G Ninja -S . -DSTATIC=ON
ninja -C out
```

This builds a static binary that can be used in the containerized environment.
