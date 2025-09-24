REPO=karanocave/ascendcanntoolkit
TAG=8.1.RC1

docker run --rm $REPO:$TAG bash -lc 'echo $ASCEND_CANN_VERSION; uname -m'