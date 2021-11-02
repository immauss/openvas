Various shell scripts used to make managing this easier. 

- base-rebuild.sh - Uses --no-cache and rebuild ovasbase and openvas in both archs

- build-branch.sh - builds only amd64 with current git branch name as tag 

- build-n-test.sh - Not done yet. Intended to do exactly what it says.

- check-gvm-release.sh - Attempte to verify the latest versions of moduels and bits from Greenbone (Run from repo root)

- debug-release.sh - Start the contianer with various debugging options.

- get-gvm-releases.sh - Update the build.rc with latest from greenbone. (Run from repo root)

- refresh.sh - Updates the archives on immauss.com web server.

- release-build.sh - Build both architechures and push to hub.docker.com with $1 as tag. If no $1, then uses latest.

- test-release.sh - pull and run the image with the tag $1

