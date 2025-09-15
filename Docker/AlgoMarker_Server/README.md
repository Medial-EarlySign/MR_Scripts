## How to Wrap AlgoMarker

### Step 1: Prepare Files
1. Compile the `AlgoMarker_Server` wrapper (located in the `Tools` directory), and copy the resulting executable into `data/app`.
2. Copy the entire `AlgoMarker` directory into `data/app/$ALGOMARKER_NAME`.
3. If the AlgoMarker model is large and split into multiple parts, extract it using 7-Zip with the following command: `7z x data/app/LungFlag/LungFlag_1.2.0/resources/lungflag.model.gz.001`
4. Compile the AlgoMarker library and place the shared library in: `data/app/$ALGOMARKER_NAME/${AM_NAME}_${AM_VERSION}/lib`


### Step 2: Build and Run Docker

#### Build the Docker image
Edit the Dockerfile and put AM_NAME, AM_VERSION directly.
It doesn't work with ENTRYPOINT.

```bash
docker build -t lungflag_app --no-cache .
```

#### Run the Docker container
```bash
docker run --name lungflag_container -p 1234:1234 -id lungflag_app
```
Your application should now be accessible on port 1234.


#### Debug/Stop/Remove container:

##### See logs:
```bash
docker logs lungflag_container
```

##### Access the running container
```bash
docker exec -it lungflag_container /bin/bash
```
##### stop and remove container
```bash
docker stop lungflag_container && docker rm lungflag_container
```

##### Remove the Docker image
```bash
docker image rm lungflag_app
```