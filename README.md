# RAGoldberg
A brittle chaining together of household items to make a RAG app.

![](./docs/images/RAGolberg.png)

### Requirements
- homebrew
- python 3
- Docker (running)

### Usage

To start up all the pieces
```bash
make run
```

You can then ingest data into `search-rag-*` indices. Make sure to have a `title` and `text` field.

To ingest some sample data:
```bash
make ingest
```


### Cleanup

This will wipe everything. Don't worry, you can get it back with `make run ingest`

```bash
make clean
```
 