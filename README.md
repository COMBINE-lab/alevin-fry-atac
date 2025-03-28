# alevin-fry-atac

alevin-fry-atac is a suite of tools for the rapid, accurate and memory-frugal processing single-cell ATAC-seq data. It consumes RAD files generated by piscem, and performs common operations like generating permit lists, and deduplication. The code is written in [Rust](https://www.rust-lang.org) and C++.

## Getting started
While we provide below individually a list of steps to run `alevin-fry-atac` to get the deduplicated bed file containing the mapped fragments, we also provide a Snakefile that does these things for you. Alevin-fry-atac is now integrated into the [simpleaf](https://github.com/COMBINE-lab/simpleaf) workflow and provides a one-step command to process single-cell ATAC-seq data.

### Software to install

#### Piscem (dev branch)
```
  git clone --recursive https://github.com/COMBINE-lab/piscem.git -b dev
  cd piscem
  git branch ## this should point to dev
  cargo build --release
```

#### alevin-fry-atac (dev-atac)
```
    git clone https://github.com/COMBINE-lab/alevin-fry.git
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
```
Usage: piscem map-sc-atac [OPTIONS] --index <INDEX> --output <OUTPUT>

Options:
  -t, --threads <THREADS>                      number of threads to use [default: 16]
  -o, --output <OUTPUT>                        path to output directory
      --ignore-ambig-hits                      skip checking of the equivalence classes of k-mers that were too ambiguous to be otherwise considered (passing this flag can speed up mapping slightly, but may
                                               reduce specificity)
      --no-poison                              do not consider poison k-mers, even if the underlying index contains them. In this case, the mapping results will be identical to those obtained as if no poison
                                               table was added to the index
  -c, --struct-constraints                     apply structural constraints when performing mapping
      --skipping-strategy <SKIPPING_STRATEGY>  the skipping strategy to use for k-mer collection [default: permissive] [possible values: permissive, strict]
      --sam-format                             output mappings in sam format
      --bed-format                             output mappings in bed format
      --use-chr                                use chromosomes as color
      --thr <THR>                              threshold to be considered for pseudoalignment, default set to 0.7 [default: 0.7]
      --bin-size <BIN_SIZE>                    size of virtual color, default set to 1000 [default: 1000]
      --bin-overlap <BIN_OVERLAP>              size for bin overlap, default set to 300 [default: 300]
      --no-tn5-shift                           do not apply Tn5 shift to mapped positions
      --check-kmer-orphan                      Check if any mapping kmer exist for a mate which is not mapped, but there exists mapping for the other read. If set to true and a mapping kmer exists, then the
                                               pair would not be mapped (default false)
  -h, --help                                   Print help
  -V, --version                                Print version

Input:
  -i, --index <INDEX>      input index prefix
  -1, --read1 <READ1>      path to a ',' separated list of read 1 files
  -2, --read2 <READ2>      path to a ',' separated list of read 2 files
  -r, --reads <READS>
  -b, --barcode <BARCODE>  path to a ',' separated list of read 2 files
```
All the arguments are self explanatory. It outputs the file `map.rad` in the `--output` directory.

#### Barcode correction and sorting
---
These steps are handled by `alevin-fry` with `atac` argument. It starts by taking in the RAD file containing the mapping information and producing a BED file with the mapped fragments. The executable is `alevin-fry` under the `alevin-fry/target/release` directory.
```
  Usage: alevin-fry atac <COMMAND>
  Commands:
    generate-permit-list  Generate a permit list of barcodes from a whitelist file
    collate               Collate a RAD file with corrected cell barcode
    sort                  Produce coordinate sorted bed file
    deduplicate           Deduplicate the RAD file and output a BED file
    help                  Print this message or the help of the given subcommand(s)
```
##### Barcode correction
```
Usage:  alevin_fry atac generate-permit-list --input <INPUT> --output-dir <OUTPUTDIR> <--unfiltered-pl <UNFILTEREDPL>>
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

##### Sort
```
Usage: alevin-fry atac sort --input-dir <INPUTDIR> --rad-dir <RADDIR>
Options:
  -i, --input-dir <INPUTDIR>      output directory made by generate-permit-list
  -r, --rad-dir <RADDIR>          the directory containing the map.rad file which will be sorted (typically produced as an output of the mapping)
  -t, --threads <THREADS>         number of threads to use for processing [default: 4]
  -c, --compress                  compress the output of the sorted RAD file
  -m, --max-records <MAXRECORDS>  the maximum number of read records to keep in memory at once [default: 30000000]
  -h, --help                      Print help
  -V, --version                   Print version
```
