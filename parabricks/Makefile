include ../_scripts/common.mk

# gatk workflows all use the same containers which can be pulled with omx-ecr-helper
build/sfn-container-puller: build/config.json build/omx-ecr-helper
	python3 $(scripts)/build.py -c $(config) sfn -t container-puller containers/container_image_manifest.json

run-%: build/config.json build/workflow-% build/iam-workflow-role
	python3 $(scripts)/build.py -c $(config) run $*
