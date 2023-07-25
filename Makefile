GIT_BRANCH := $(shell git branch --show-current)
GIT_COMMIT = $(shell git rev-parse --short HEAD)
GIT_TAG=$(strip $(shell git describe --tags --abbrev=0))
BINARY_VERSION=$(GIT_BRANCH)-$(GIT_COMMIT)
BUILD_TIME=$(shell date "+%Y/%m/%d-%H:%M:%S")

ifeq ($(findstring $(GIT_BRANCH),$(GIT_TAG)),)
	IMAGE_VERSION=$(GIT_BRANCH)
else
	IMAGE_VERSION=$(GIT_TAG)
endif
# IMAGE_VERSION=latest

build: 
	# go install github.com/gohugoio/hugo@latest
	# git clone https://github.com/xioyito/NewBee.git themes/NewBee
	hugo

release: build
	rclone sync  public minio:blogs-rescoure

image: build

	docker build -t  swr.cn-north-4.myhuaweicloud.com/kelley/blogs:$(IMAGE_VERSION) -f Dockerfile .
	docker push swr.cn-north-4.myhuaweicloud.com/kelley/blogs:$(IMAGE_VERSION)


