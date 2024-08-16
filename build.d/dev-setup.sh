. /build.rc
echo "Downloading latest gsa code"  
GSA_VERSION=$(echo $gsa| sed "s/^v\(.*$\)/\1/")
mkdir -p /gsa
cd /gsa
curl -f -L https://github.com/greenbone/gsa/archive/refs/tags/v$GSA_VERSION.tar.gz -o $gsa.tar.gz
tar -xf $gsa.tar.gz
cd *
SRCDIR=$(pwd)
echo "$SRCDIR" > /sourcedir
echo "Source directory is $SRCDIR"
mv $SRCDIR /gsa/gsa.latest
cd /gsa/gsa.latest
apt update && apt install npm -y
npm install vite
npm audit fix 
echo "Updating npm"
npm install -g npm@10.1.0
echo "Updating npm browserlist"
npm install
