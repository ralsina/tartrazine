all: build

build: $(wildcard src/**/*.cr) $(wildcard lexers/*xml) $(wildcard styles/*xml) shard.yml
	shards build -Dstrict_multi_assign -Dno_number_autocast -d --error-trace
release: $(wildcard src/**/*.cr) $(wildcard lexers/*xml) $(wildcard styles/*xml) shard.yml
	shards build --release
static: $(wildcard src/**/*.cr) $(wildcard lexers/*xml) $(wildcard styles/*xml) shard.yml
	shards build --release --static
	strip bin/tartrazine


clean:
        rm -rf bin lib shard.lock

test:
        crystal spec

lint:
        ameba --fix src spec

.PHONY: clean all test bin lint
