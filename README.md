# Parsing 1 billion lines of data in Zig

The goal is to parse as fast as possible. Currently
the speed of processing is around 40/50 seconds for
`ReleaseFast` compilation, on a Macbook M2 Air.

## Building

Debug Build
```sh
zig build-exe ./main.zig
```

Release Build
```sh
zig build-exe ./main.zig -O ReleaseFast
```

## Running the executable

After building, running the executable with a file argument
will start the executable. E.g.
```sh
./main ./small_measurements.txt
```

## Testing files

Currently the large 1 billion line text file is not in git,
as it is quite large (14GB).

The smaller file `small_measurements.txt` can be used for
profiling and performance measuring, and is commited to the
repo.
