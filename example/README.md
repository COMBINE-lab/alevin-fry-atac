#### Download the data from the following URL
##### Example data
```curl -L "https://umd.box.com/shared/static/2qwx1v5vsmifmbleczn9bxed54fuuhhg" --output example_data.zip```
##### Expected output for data using piscem
```curl -L "https://umd.box.com/shared/static/tlj7nhlz706hbpo90u05jqrme90z0auv" --output example_out.zip```


##### Decompress
```unzip example_data.zip```
```unzip example_out.zip```

#### Running the toy example
```snakemake -j1 --configfile config.yml```
