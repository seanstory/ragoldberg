install:
	./scripts/install.sh

run: install
	./scripts/start.sh

start:
	./scripts/start.sh

ingest:
	./scripts/ingest.sh

stop:
	./scripts/stop.sh

restart: stop start


clean: stop
	./scripts/clean.sh
