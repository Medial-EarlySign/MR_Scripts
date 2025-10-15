## How to Wrap AlgoMarker

### Step 1: Prepare Files
1. Compile the `AlgoMarker_Server` wrapper (located in the `Tools` directory), and copy the resulting executable into `data/app`.
2. Copy the entire `AlgoMarker` directory into `data/app/$ALGOMARKER_NAME`.
3. If the AlgoMarker model is large and split into multiple parts, extract it using 7-Zip with the following command: `7z x data/app/LungFlag/LungFlag_1.2.0/resources/lungflag.model.gz.001`
4. Compile the AlgoMarker library and place the shared library in: `data/app/$ALGOMARKER_NAME/${AM_NAME}_${AM_VERSION}/lib`


### Step 2: Build and Run Docker

#### Build the Docker image
Please use the script `create_image.sh` and provide it with the path to the AM_CONFIG file of the AlgoMarker and choose an IMAGE_NAME to name this image.
You can optionally pass also the port number as 3rd argument. Default is 1234

```bash
./create_image.sh data/app/path_to_am_config_file  IMAGE_NAME
```

#### Run the Docker container
```bash
podman run --name X_container -p 1234:1234 -id IMAGE_NAME
```
Your application should now be accessible on port 1234.


#### Debug/Stop/Remove container:

##### See logs:
```bash
podman logs X_container
```

##### Access the running container
```bash
podman exec -it X_container /bin/bash
```
##### stop and remove container
```bash
podman stop X_container && podman rm X_container
```

##### Remove the Docker image
```bash
podman image rm IMAGE_NAME
```

The commands are also fully compitible for `docker`