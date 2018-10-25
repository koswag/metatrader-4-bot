from threading import Thread
from time import sleep
from mt4 import Connection, Manager

BUY  = 0
SELL = 1

class Client(Thread):
    """ZMQ client connecting to the MQL server"""

    con         = None
    manager     = None

    def __init__(self, reqPort, pullPort):
        self.con        = Connection(reqPort, pullPort)
        self.manager    = Manager(self.con)
        super(Client, self).__init__()

    def run(self):
        self.con.connect()

        while True:
            try:
                rates = self.manager.getRates("USDCHF")
                print rates
                sleep(5)
            except Exception as e:
                print e.message
                continue

#/------------------------------------------------------------------------------------\#
# ================================== Main method ===================================== #
#\------------------------------------------------------------------------------------/#
def main():
    Client(5555, 5556).start()

if __name__ == '__main__':
    main()