import zmq

class Manager:
    """Uses ZMQ Connection to manage client's requests"""

    con = None

    def __init__(self, zmqConnection):
        self.con = zmqConnection
    
    def getRates(self, symbol):
        """Gives rates for given symbol. Format: BID|ASK"""
        req = self.con.reqSocket
        pull = self.con.pullSocket
        query = "RATES|{}".format(symbol)
        self.con.send(req, query)
        res = self.con.pull(pull)
        return res

    def sendOrder(self, action, orderType, symbol):
        """Sends an order for specified symbol. action = <'OPEN' or 'CLOSE'>; orderType = <0 for BUY or 1 for SELL>"""
        req = self.con.reqSocket
        query = "TRADE|{}|{}|{}|0|50|50|Python-to-MT4".format(action, orderType, symbol)
        self.con.send(req, query)

class Connection:
    """Provides functionality to connect to ZMQ MT4 Server"""

    context     = None
    reqSocket   = None
    pullSocket  = None
    reqPort     = None
    pullPort    = None

    def __init__(self, reqPort, pullPort):
        self.context    = zmq.Context()
        self.reqSocket  = self.context.socket(zmq.REQ)
        self.pullSocket = self.context.socket(zmq.PULL)
        self.reqPort    = reqPort
        self.pullPort   = pullPort

    def connect(self):
        """Connects client to the server on given request and pull ports."""
        self.reqSocket.connect("tcp://localhost:{}".format(self.reqPort))
        self.pullSocket.connect("tcp://localhost:{}".format(self.pullPort))
        print "Connected to server on ports: {} and {}".format(self.reqPort, self.pullPort)

    def send(self, socket, data):
        """Tries to send a data message through given socket."""

        try:
            socket.send(data)
            msg = socket.recv_string()
            print msg
            
        except zmq.Again:
            print "Waiting for PUSH from MetaTrader 4.."
    
    def pull(self, socket):
        """Tries to pull a message from given socket."""
        try:
            msg = socket.recv(flags=zmq.NOBLOCK)
            return msg
            
        except zmq.Again:
            print "Waiting for PUSH from MetaTrader 4.."