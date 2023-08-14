.PHONY: init 
.PHONY: select
.PHONY: test-local
.PHONY: push
.PHONY: push-and-test
.PHONY: clean

CURRENT_DIR := $(shell basename $(PWD))
HOST_NAME := $(shell hostname)

ifeq ($(findstring cog,$(CURRENT_DIR)),cog)
IMAGE_NAME := $(CURRENT_DIR)
else
IMAGE_NAME := cog-$(CURRENT_DIR)
endif

init:
	# Initialize directory for model
	mkdir -p models/$(model)
	cp -r model_templates/*  models/$(model)
	if [ -e model_templates/.env ]; then cp model_templates/.env models/$(model) ; fi
	if [ -e model_templates/.dockerignore ]; then cp model_templates/.dockerignore models/$(model) ; fi

	mkdir -p models/$(model)/model_artifacts/tokenizer
	cp -r llama_weights/tokenizer/* models/$(model)/model_artifacts/tokenizer

select:
	rsync -av --exclude 'model_artifacts/' models/$(model)/ .
	if [ -e models/$(model)/.env ]; then cp models/$(model)/.env . ; fi
	if [ -e models/$(model)/.dockerignore ]; then cp models/$(model)/.dockerignore . ; fi
	echo "/models/*/" >> .dockerignore
	echo "!/models/$(model)/" >> .dockerignore
	echo "/models/$(model)/model_artifacts/**" >> .dockerignore
	echo "!/models/$(model)/model_artifacts/tokenizer/" >> .dockerignore
	@echo "#########Selected model: $(model)########"

clean: select
	if [ -e models/$(model)/model_artifacts/default_inference_weights]; then sudo rm -rf models/$(model)/model_artifacts/default_inference_weights; fi
	if [ -e models/$(model)/model_artifacts/training_weights]; then  sudo rm -rf models/$(model)/model_artifacts/training_weights; fi
	if [ -e training_output.zip]; then sudo rm -rf training_output.zip; fi

build-local: select
	cog build

serve: build-local
	docker run \
	-ti \
	-p 5000:5000 \
	--gpus=all \
	$(IMAGE_NAME)

	# -e COG_WEIGHTS=http://$(HOST_NAME):8000/training_output.zip \
	# -v `pwd`/training_output.zip:/src/local_weights.zip \



test-local-predict: select build-local
	pytest ./tests/test_predict.py -s

test-local-train: select build-local
	rm -rf training_output.zip
	pytest ./tests/test_train.py -s

test-local-train-predict: select build-local
	pytest ./tests/test_train_predict.py -s 

test-local: test-local-predict test-local-train test-local-train-predict

push: select
	cog push r8.im/$(destination)

test-push: test-local push
	
test-live:
	python test/push_test.py

push-and-test: push test-live



help:
	@echo "Available targets:\n\n"
	@echo "init: Create the model directory."
	@echo "   e.g., \`make init dir=<model_dir>\`"

