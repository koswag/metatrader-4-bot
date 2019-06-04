from trading import Strategy
import zmq


class Trader:
    def __init__(self, push, pull):
        self.connection = Connection()
        self.connection.connect(push, pull)
        self.strategy = Strategy('H1', 10)
        self.Tickets = []

    def rates(self, symbol):
        query = "RATES|{}".format(symbol)
        self.connection.push(query)

    def data(self, symbol, time_frame):
        query = "DATA|{}|{}".format(symbol, time_frame)
        self.connection.push(query)

    def order(self, action, order_type, symbol, tick_id=None):
        query = 'TRADE|{}|{}|{}|0|50|50|Python-to-MT4'.format(action, order_type, symbol)
        if tick_id:
            query += "|{}".format(tick_id)
        self.connection.push(query)
    
    def push_listener(self):
        while True:
            msg = str(self.connection.pull())
            if msg is None or msg == "":     
                continue
            self.process(msg)

    def process(self, msg):
        print "Processing message : {}".format(msg)
        values = parse(msg)

        if values[0] == "TRADE":
            print values[1]
            self.add_ticket(values[2])
        elif values[0] == "RATES":
            bid, ask = values[1], values[2]
            # do sth with bid and ask
        elif values[0] == "DATA":
            op, cl, high, low = values[1], values[2], values[3], values[4]
            self.strategy.add_bar(op, cl, high, low)

    def add_ticket(self, tick):
        try:
            ticket = int(tick)
            if ticket > 0:
                self.Tickets.append(ticket)
        except ValueError:
            pass


class Connection:
    def __init__(self):
        self.context = zmq.Context()
        self.pushSocket = self.context.socket(zmq.PUSH)
        self.pullSocket = self.context.socket(zmq.PULL)

    def connect(self, pushPort, pullPort):
        self.pushSocket.connect("tcp://localhost:{}".format(pushPort))
        self.pullSocket.connect("tcp://localhost:{}".format(pullPort))
        print "Connected to ports: {} and {}".format(pushPort, pullPort)

    def disconnect(self):
        "Terminates the connection."
        print "Disconnecting push socket.."
        self.pushSocket.close()
        print "Done"
        
        print "Disconnecting pull socket.."
        self.pullSocket.close()
        print "Done"

    def push(self, msg):
        "Sends a string message."
        self.pushSocket.send_string(unicode(msg))

    def pull(self):
        """Tries to retrieve a message.
        
        Returns message as byte-string if there's any in the buffer."""
        pull = self.pullSocket
        
        try:
            msg = pull.recv(flags=zmq.NOBLOCK)
            return msg
        except zmq.Again:
            return None


def parse(msg, sep='|'):
    components = msg.split(sep)
    vals = []

    for val in components:
        try:
            vals.append(int(val))
        except ValueError:
            try:
                vals.append(float(val))
            except ValueError:
                vals.append(val)
    
    return vals
