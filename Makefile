build: 
	hugo

release: build
	rclone sync  public minio:blogs-rescoure

