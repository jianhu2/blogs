IMAGE_VERSION=latest

build: 
	# go install github.com/gohugoio/hugo@latest
	# git clone https://github.com/xioyito/NewBee.git themes/NewBee
	hugo

release: build
	rclone sync  public minio:blogs-rescoure

image: build

	docker build -t  swr.cn-north-4.myhuaweicloud.com/kelley/blogs:$(IMAGE_VERSION) -f Dockerfile .
	docker push swr.cn-north-4.myhuaweicloud.com/kelley/blogs:$(IMAGE_VERSION)


