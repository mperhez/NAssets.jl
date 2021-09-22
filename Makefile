TOK_FILE=.git_token
GIT_TOK=$(shell cat $(TOK_FILE))
IMG=mperhez/ntwctl-abm:latest
CONTAINER_WD=/network-fleet-abm

all: build run

build:
	docker build -t $(IMG) --build-arg GIT_TOK=$(GIT_TOK) .

run:
	 docker run -it --rm -v $(PWD):$(CONTAINER_WD) -w $(CONTAINER_WD) $(IMG)