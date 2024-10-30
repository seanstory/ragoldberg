install:
	./scripts/install.sh

run: install
	./scripts/start.sh

start:
	./scripts/start.sh

stop:
	./scripts/stop.sh

clean: stop
	./scripts/clean.sh
