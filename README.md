# alevin-fry-atac

alevin-fry-atac is a suite of tools for the rapid, accurate and memory-frugal processing single-cell ATAC-Seq data. It consumes RAD files generated by piscem, and performs common operations like generating permit lists, and deduplication. The code is written in [Rust](https://www.rust-lang.org) and C++.

## Getting started
While we provide below individually a list of steps to run `alevin-fry-atac` to get the deduplicated bed file containing the mapped fragments, we also provide a Snakefile that does these things for you. A [simpleaf](https://github.com/COMBINE-lab/simpleaf) workflow is currently under preparation, which would make the task even easier.

### Software to install

#### Piscem (dev-atac branch)
```
  git clone --recursive https://github.com/COMBINE-lab/piscem.git -b dev-atac
  cd piscem
  git branch ## this should point to dev-atac
  cargo build --release
  cd piscem-cpp
  mkdir build
  cd build
  cmake ..
  make
```

#### alevin-fry-atac (dev-atac)
```
    git clone https://github.com/COMBINE-lab/alevin-fry.git -b dev-atac
    cd alevin-fry
    git branch ## check it is the dev-atac branch
    cargo build --release
```

#### Snakemake
If you want to skip running each step individually, the instructions to download `Snakemake` are available on their [website](https://snakemake.readthedocs.io/en/stable/getting_started/installation.html). Personally, I prefer `mamba`. Note that you have to install the softwares above irrespective since you will be required to provide the above path in `config.yml` for snakemake.


### Enumerating each step

#### Building the index

> **Note**
> Since the build process makes use of [KMC3](https://github.com/refresh-bio/KMC) for a k-mer enumeration step, which, in turn, makes use of intermediate files to keep memory usage low, **you will likely need to increase the default number of file handles that can be open at once**.  Before running the `build` command, you can run `ulimit -n 2048` in the terminal where you execute the `build` command.  You can also put this command in any script that you will use to run `piscem build`, or add it to your shell initalization scripts / profiles so that it is the default for new shells that you start

---
Index a reference sequence
```
Usage: piscem build [OPTIONS] --klen <KLEN> --mlen <MLEN> --threads <THREADS> --output <OUTPUT> <--ref-seqs <REF_SEQS>|--ref-lists <REF_LISTS>|--ref-dirs <REF_DIRS>>

Options:
  -s, --ref-seqs <REF_SEQS>    ',' separated list of reference FASTA files
  -l, --ref-lists <REF_LISTS>  ',' separated list of files (each listing input FASTA files)
  -d, --ref-dirs <REF_DIRS>    ',' separated list of directories (all FASTA files in each directory will be indexed, but not recursively)
  -k, --klen <KLEN>            length of k-mer to use
  -m, --mlen <MLEN>            length of minimizer to use
  -t, --threads <THREADS>      number of threads to use
  -o, --output <OUTPUT>        output file stem
      --keep-intermediate-dbg  retain the reduced format GFA files produced by cuttlefish that describe the reference cDBG (the default is to remove these)
  -w, --work-dir <WORK_DIR>    working directory where temporary files should be placed [default: .]
      --overwrite              overwite an existing index if the output path is the same
      --no-ec-table            skip the construction of the equivalence class lookup table when building the index
  -h, --help                   Print help
  -V, --version                Print version
```

The parameters should be reasonably self-expalanatory.  The `-k` parameter is the k-mer size for the underlying colored compacted de Bruijn graph, and the `-m` parameter is the minimizer size used to build the [`sshash`](https://github.com/jermp/sshash) data structure.  The quiet `-q` flag applies to the `sshash` indexing step (not yet the CdBG construction step) and will prevent extra output being written to `stderr`.

Finally, the `-r` argument takes a list of `FASTA` format files containing the references to be indexed.  Here, if there is more than one reference, they should be provided to `-r` in the form of a `,` separated list.  For example, if you wish to index `ref1.fa`, `ref2.fa`, `ref3.fa` then your invocation should include `-r ref1.fa,ref2.fa,ref3.fa`.  The references present within all of the `FASTA` files will be indexed by the `build` command.

> **Note**
> You should ensure that the `-t` parameter is less than the number of physical cores that you have on your system. _Specifically_, if you are running on an Apple silicon machine, it is highly recommended that you set `-t` to be less than or equal to the number of **high performance** cores that you have (rather than the total number of cores including efficiency cores), as using efficiency cores in the `piscem build` step has been observed to severely degrade performance.

#### Mapping ATAC-Seq reads
---
The executable for this task is `pesc-sc-atac` and can be found in the directory `piscem-cpp/build`. The default output is a RAD file.
```
Usage: pesc-ac-atac [OPTIONS] --index <IND> --read1 <READ1> --read2 <READ2> --barcode <BARCODE> --threads <THREADS> --output <OUTPUT>

Options:
  -h,--help                   Print this help message and exit
  -i,--index TEXT REQUIRED    input index prefix
  -1,--read1 TEXT ... REQUIRED
                              path to list of read 1 files
  -2,--read2 TEXT ...         path to list of read 2 files
  -b,--barcode TEXT ... REQUIRED
                              path to list of barcodes
  -o,--output TEXT REQUIRED   path to output directory
  -t,--threads UINT [16]      An integer that specifies the number of threads to use
  --sam-format                Write SAM format output rather than bulk RAD.
  --kmers-orphans             Check if any mapping kmer exist for a mate, if there exists mapping for the other read (default false)
  --bed-format                Dump output to bed.
  --use-chr                   use chromosomes as virtual color.
  --tn5-shift BOOLEAN         Tn5 shift
  --no-poison BOOLEAN [1]     Do not filter reads for poison k-mers, even if a poison table exists for the index
  -c,--struct-constraints     Apply structural constraints when performing mapping
  --skipping-strategy TEXT [permissive]
                              Which skipping rule to use for pseudoalignment ({strict, permissive, strict})
  --quiet                     Try to be quiet in terms of console output
  --thr FLOAT [0.7]           threshold for psa
  --bin-size UINT [1000]      size for binning
  --bin-overlap UINT [300]    size for bin overlap
  --check-ambig-hits          check the existence of highly-frequent hits in mapped targets, rather than ignoring them.
```
All the arguments are self explanatory. It outputs the file `map.rad` in the `--output` directory.

#### Barcode correction, Collate and Deduplicate
---
These steps are handled by `alevin-fry`. It starts with taking in the RAD file that contains the mapping information and producing a BED file with the mapped fragments. The executable is `alevin_fry_atac` under `alevin-fry/target/release` directory.
```
  Usage: alevin_fry_atac <COMMAND>
  Commands:
    generate-permit-list  Generate a permit list of barcodes from a whitelist file
    collate               Collate a RAD file by corrected cell barcode
    deduplicate           Deduplicate the RAD file and output a BED file
    help                  Print this message or the help of the given subcommand(s)
```
##### Barcode correction
```
Usage:  alevin_fry_atac generate-permit-list --input <INPUT> --output-dir <OUTPUTDIR> <--unfiltered-pl <UNFILTEREDPL>>
Options:
  -i, --input <INPUT>                 input directory containing the map.rad file
  -o, --output-dir <OUTPUTDIR>        output directory
  -u, --unfiltered-pl <UNFILTEREDPL>  uses an unfiltered external permit list
  -m, --min-reads <MINREADS>          minimum read count threshold; only used with --unfiltered-pl [default: 10]
  -r, --rev-comp <REVERSECOMPLEMENT>  reverse complement the barcode [default: true] [possible values: true, false]
  -h, --help                          Print help
  -V, --version                       Print version
```
`unfiltered-pl` is the permit list of the barcodes which will be a superset of the barcodes in a sample
`--rev-comp` Whether the reverse complement has to be taken before trying to find a matching between the barcode of a mapped record to that of the barcode in the whitelist file

##### Collate
```
Usage: alevin_fry_atac collate --input-dir <INPUTDIR> --rad-dir <RADDIR>
Options:
  -i, --input-dir <INPUTDIR>      output directory made by `generate-permit-list`
  -r, --rad-dir <RADDIR>          the directory containing the map.rad file which will be collated (typically produced as an output of the mapping)
  -t, --threads <THREADS>         number of threads to use for processing [default: 8]
  -c, --compress                  compress the output collated RAD file
  -m, --max-records <MAXRECORDS>  the maximum number of read records to keep in memory at once [default: 30000000]
  -h, --help                      Print help
  -V, --version                   Print version
```

##### Deduplicate
```
Usage: alevin_fry_atac deduplicate --input-dir <INPUTDIR>
Options:
  -i, --input-dir <INPUTDIR>          input directory made by generate-permit-list that also contains the output of collate
  -t, --threads <THREADS>             number of threads to use for processing [default: 8]
  -r, --rev-comp <REVERSECOMPLEMENT>  reverse complement [default: true] [possible values: true, false]
  -h, --help                          Print help
  -V, --version                       Print version
```
