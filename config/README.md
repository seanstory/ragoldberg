# RAGoldberg Configuration

This directory exists to provide a dumping ground for configuration files. 

### config/crawls/

This directory should contain YAML files to describe Open Crawler behavior.

You can add/remove/change these files, and running `make ingest` will loop over them in order.

### config/shared/

This directory contains a YAML file that's used for all crawls. Currently, it's just Elasticsearch settings.
This keeps you from having to update numerous files in `config/crawls/` if you want to adjust your pipeline, or batch settings, etc. 

### config/stack/

This directory contains the YAML files for our Elasticsearch and Kibana settings. They're copied during `make install` to the unpacked tarballs.
