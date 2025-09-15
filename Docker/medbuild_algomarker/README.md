## build the image
```bash
docker build -t build_test --no-cache .
```

## Run the Docker container
```bash
docker run --name test_container -id build_test
```
## Access the running container
```bash
docker exec -it test_container /bin/bash
```

## copy git
```bash
docker cp  /tmp/MR_Libs test_container:/earlysign
```