from threading import Thread
from time import sleep
from datetime import datetime

from mt4 import Trader

now = datetime.now

BUY = 0
SELL = 1


class Client(Thread):
    """ZMQ client thread connecting to MQL server"""
    def __init__(self, push, pull):
        self.manager = Trader(push, pull)
        super(Client, self).__init__()

    def run(self):
        Thread(target=self.manager.push_listener).start()
        while True:
            try:
                self.manager.data("EURUSD", "H1")
                print '{}:{}:{} - Data request sent'.format(now().hour, now().minute, now().second)

                sleep(10)
            except:
                continue
        print 'Disconnecting sockets..'
        self.con.disconnect()
        print 'Done'
