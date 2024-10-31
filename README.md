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
$ keygen -size 32 > key.bin
```

To encode the key in a human-readable form, use one of `-base64` or `-hex` options.

```
$ keygen -size 32 -base64
$ TBL9AmoWlJnaqxmZY46AEn3K3opwGLj8yZdiRwhdrP8=
```

```
$ keygen -size 32 -hex
$ 697277201801029c721cefeac2c4ec4efd7658e40366f6585c7641704ddb42c9
```

To generate a sequence of known words, provide a word list:
```
$ keygen -size 5 -words mywords.txt
$ cake-winner-window-animal-three
```

The words can be amended with random digits:
```
$ keygen -size 5 -words mywords.txt -numbered
$ cheese4-zebra7-meat8-three6-door8
```

Use `keygen -help` for an overview all all available options.


### License

Unless otherwise stated, this project and its contents are provided under a 3-Clause BSD license. Refer to the LICENSE file for its contents.
