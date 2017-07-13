#!/bin/bash
#made by Will's laziness

#CHECK ARGS
if [[ $# -eq 0 ]] ; then
   echo "Usage: launchQE.sh version, where version is in the format \"v2.0.0\""
   exit 0
fi

QUAYVER=$1
echo Installing $QUAYVER

#CREATE CONFIG DIRS
if [ -d "config"]
then
 echo "Config dir existsi, skipping"
else
 mkdir config
fi

if [ -d "storage"]
then 
 echo "Storage dir exists, skipping"
else
 mkdir storage
fi


#GENERATE, PLACE, AND DELETE CERTS
openssl genrsa -out rootCA.key 2048
openssl req -x509 -new -nodes -key rootCA.key -sha256 -days 1024 -out rootCA.pem


#GET IP AND WRITE OPENSSL.CNF
MYIP=$(curl ifconfig.co)

cat << EOF > openssl.cnf
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
IP.1 = $MYIP 
IP.2 = 172.17.0.1
IP.3 = 172.17.0.2
IP.4 = 172.17.0.3
IP.5 = 172.17.0.4
IP.6 = 172.17.0.5
EOF

openssl genrsa -out ssl.key 2048
openssl req -new -key ssl.key -out ssl.csr -subj "/CN=quay-enterprise" -config openssl.cnf
openssl x509 -req -in ssl.csr -CA rootCA.pem -CAkey rootCA.key -CAcreateserial \
   -out ssl.cert -days 356 -extensions v3_req -extfile openssl.cnf

cp ssl.key config
cp ssl.cert config
cp rootCA.pem config
cp rootCA.key config
cp ssl.csr config
cp rootCA.srl config

mkdir /etc/docker/certs.d
mkdir /etc/docker/certs.d/$MYIP

cp rootCA.pem /etc/docker/certs.d/$MYIP/ca.crt

#rm ssl.key
#rm ssl.cert
#rm rootCA.key
#rm rootCA.pem
#rm ssl.csr


#RESTART DOCKER
systemctl restart docker.service

sleep 10


#PULL MYSQL, SET VARIABLES, AND LAUNCH
docker pull mysql:5.7

MYSQL_USER="coreosuser"

MYSQL_DATABASE="enterpriseregistrydb"

MYSQL_CONTAINER_NAME="mysql"

MYSQL_ROOT_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | sed 1q)

MYSQL_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | sed 1q)

docker \
  run \
  --detach \
  --restart=always \
  --env MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD} \
  --env MYSQL_USER=${MYSQL_USER} \
  --env MYSQL_PASSWORD=${MYSQL_PASSWORD} \
  --env MYSQL_DATABASE=${MYSQL_DATABASE} \
  --name ${MYSQL_CONTAINER_NAME} \
  --publish 3306:3306 \
  mysql:5.7;


#PULL AND LAUNCH REDIS
docker pull quay.io/quay/redis

docker run -d --restart=always -p 6379:6379 quay.io/quay/redis

sleep 30


#PULL AND LAUNCH QUAY
docker run --restart=always -p 443:443 -p 80:80 --privileged=true -v $PWD/config:/conf/stack -v $PWD/storage:/datastorage -d quay.io/coreos/quay:$QUAYVER


#SET VARS AND LAUNCH QUAY-BUILDER
QUAYCONTAINER=$(docker ps | grep "quay.io/coreos/quay:" | awk '{print $1}')

QUAYIP=$(docker inspect $QUAYCONTAINER | grep "IPAddress\"" | awk 'BEGIN { FS="\"";}{print $4}' | head -1)

REDISCONTAINER=$(docker ps | grep "redis" | awk '{print $1}')

REDISIP=$(docker inspect $REDISCONTAINER | grep "IPAddress\"" | awk 'BEGIN { FS="\"";}{print $4}' | head -1)
 
MYSQLCONTAINER=$(docker ps | grep "mysql" | awk '{print $1}')

MYSQLIP=$(docker inspect $MYSQLCONTAINER | grep "IPAddress\"" | awk 'BEGIN { FS="\"";}{print $4}' | head -1)

#NEED TO CREATE CONFIG FILE AND PULL IT TO SET HTTPS FROM COMMAND LINE
#docker run -d --restart on-failure -e SERVER=wss://$QUAYIP -v /var/run/docker.sock:/var/run/docker.sock quay.io/coreos/quay-builder:$1


#OUTPUT INSTALLED VERSION, DB VARS AND USEFUL IPs
echo
echo

docker inspect $QUAYCONTAINER | grep "Image\": \"quay.io/coreos/quay:"

echo "USER " $MYSQL_USER " in database " $MYSQL_DATABASE " with password " $MYSQL_PASSWORD "at IP" $MYSQLIP

echo "Redis is running on" $REDISIP
