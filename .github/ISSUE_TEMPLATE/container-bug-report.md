---
name: Container Bug report
about: Create a report to help us improve
title: "[BUG]"
labels: ''
assignees: immauss

---

** Please attach large files to the report instead of pasting the contents into the report. **

**Describe the bug**
A clear and concise description of what the bug is.

**To Reproduce**
Steps to reproduce the behavior:
1. Include how you started the container. 
   - docker-compose.yml or command used to start the container with all options.
2. When did the issue occur? 
  - the container failed to start? 
  - Container stopped when performing some action? What was the action? 
  - Some other error in the GUI or the logs ? 

**Expected behavior**
A clear and concise description of what you expected to happen.

**Screenshots**
If applicable, add screenshots to help explain your problem.

**Environment (please complete the following information):**
 - OS: [e.g. Ubuntu 20.10]
 - Memory available to OS:  [ 4G ]
 - Container environment used with version: [ docker , podman, kubernets, etc ]

**logs** ( commands assume the container name is 'openvas' )
Please attach the output from one of the following commands:

# docker #
docker logs openvas > logfile.log 

# Podman #
podman logs openvas > logfile.log

# docker-compose #
docker-compose logs > logfile.log

Please "attach" the file instead of pasting the conents to the issue. 

**Additional context**
Add any other context about the problem here.
