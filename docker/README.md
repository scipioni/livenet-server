#### Repository originale
#### https://github.com/FlorentTomasin/docker_dhcp_nfs_tftp_server.git

Le directory tftp ed nfs ospitano i rispettivi files
La directory scripts ospita alcuni script di supporto
La directory src il necessario per costruire l'immagine
La directory etc i files di configurazione in binding con il container

.env contiene configurazione/path/variabili 

Per test viene creato un bridge che sarà il parent dell'interfaccia macvlan e in cui si innestano eventuali tap delle VM

```
sudo ip link add name br_test type bridge
sudo ip addr add 10.1.22.2/24 dev  br_test
sudo ip link set   br_test up
```

Il driver macvlan viene usato in modo simile a quanto segue

```
docker network create -d macvlan --subnet=10.1.22.0/24 --gateway=10.1.22.1 -o parent=br_test macvlan0
```