docker buildx build -t immauss/ovasbase:latest  --platform linux/amd64 .
docker buildx build -t immauss/ovasbase:latest  --platform linux/arm64 .
docker buildx build -t immauss/ovasbase:latest  --platform linux/amd64,linux/arm64 --push .
