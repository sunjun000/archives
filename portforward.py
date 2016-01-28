import socket
import asyncore
import urllib2
import json
import threading

cds_server = '127.0.0.1'
settings = {
    'mysql': (23306, 3306),
    'etcd': (24001, 4001),
    'gnatsd': (24222, 4222),
}

class CDSClient:
    def __init__(self, server):
        self.server = server

    def get_deployments(self):
        resp = urllib2.urlopen('http://%s/api/deployments' % self.server)
        return json.loads(resp.read())['deployments']

    def get_dbaas_deployment_name(self):
        deployments = self.get_deployments()
        for deployment in deployments:
            if deployment['release']['name'] == 'dbaas':
                return deployment['name']

    def get_services(self, deployment):
        resp = urllib2.urlopen('http://%s/api/deployments/%s/services' % (self.server, deployment))
        return json.loads(resp.read())['services']

    def get_ip_for_dbaas_services(self):
        ret = {}
        dbaas_dep_name = self.get_dbaas_deployment_name()
        services = self.get_services(dbaas_dep_name)
        for service in services:
            name = service['name']
            if name not in ret:
                for interface in service['interfaces']:
                    ip = interface['ip']
                    if ip.startswith('192.168.80.'):
                        ret[name] = ip
                        break
        return ret

class RemoteManager:
    AVAILABLE, UPDATING, NONE = 0, 1, 2

    def __init__(self, server):
        self.status = self.NONE
        self.lock = threading.Lock()
        self.cdsclient = CDSClient(server)
        self.data = {}

    def update(self):
        with self.lock:
            if self.status == self.UPDATING:
                return
            self.status = self.UPDATING

        thread = threading.Thread(target=self.do_update)
        thread.daemon = True
        thread.start()

    def do_update(self):
        self.data = self.cdsclient.get_ip_for_dbaas_services()

        with self.lock:
            self.status = self.AVAILABLE

    def get_addr(self, service):
        if self.status == self.NONE:
            self.update()
        elif self.status == self.UPDATING:
            pass
        else:
            return (self.data.get(service), settings.get(service)[1])

class Peer(asyncore.dispatcher):
    def __init__(self, sock=None):
        asyncore.dispatcher.__init__(self, sock=sock)
        self.peer = None
        self.__buff = ''

    def handle_close(self):
        self.peer.close()
        self.close()

    def handle_write(self):
        sent = self.send(self.__buff)
        self.__buff = self.__buff[sent:]

    def handle_read(self):
        data = self.recv(8192)
        self.peer.forward(data)

    def forward(self, data):
        self.__buff += data

class Server(asyncore.dispatcher):
    def __init__(self, name, port, remote_manager):
        asyncore.dispatcher.__init__(self)
        self.name = name
        self.port = port
        self.remote_manager = remote_manager

    def start(self):
        self.create_socket(socket.AF_INET, socket.SOCK_STREAM)
        self.set_reuse_addr()
        self.bind(('', self.port))
        self.listen(5)

    def handle_accept(self):
        addr = self.remote_manager.get_addr(self.name)
        if addr is None: return

        s2 = Peer()
        s2.create_socket(socket.AF_INET, socket.SOCK_STREAM)
        try:
            s2.connect(addr)
        except socket.error:
            self.remote_manager.update()
            return

        sock, _ = self.accept()
        s1 = Peer(sock)
        s1.peer = s2
        s2.peer = s1

def main():
    for service in settings:
        s = Server(service, settings[service][0], RemoteManager(cds_server))
        s.start()
    try:
        asyncore.loop()
    except KeyboardInterrupt:
        pass

main()
