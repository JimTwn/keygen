## Keygen

Bubble is a message board server.


### Usage

To acquire and install the program:

```
$ git clone https://github.com/jimtwn/keygen
$ cd keygen
$ zig build install
```

To generate a raw 32 byte random key:

```
$ keygen 32 > key.bin
```

To encode the key in a human-readable form, use one of `-base64` or `-hex` options.

```
$ keygen -base64 32
$ TBL9AmoWlJnaqxmZY46AEn3K3opwGLj8yZdiRwhdrP8=
```

```
$ keygen -hex 32
$ 697277201801029c721cefeac2c4ec4efd7658e40366f6585c7641704ddb42c9
```

### License

Unless otherwise stated, this project and its contents are provided under a 3-Clause BSD license. Refer to the LICENSE file for its contents.
