build: 
	# go install github.com/gohugoio/hugo@latest
	# git clone https://github.com/xioyito/NewBee.git themes/NewBee
	hugo

release: build
	rclone sync  public minio:blogs-rescoure

